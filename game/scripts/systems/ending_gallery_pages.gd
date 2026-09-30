class_name EndingGalleryPages
extends RefCounted

const SURFACE := preload("res://scripts/systems/reality_surface.gd")
const STAY := preload("res://scripts/systems/stay_story.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const NOTEBOOK := preload("res://scripts/systems/field_notebook.gd")
const CHARTER := preload("res://scripts/systems/stay_charter.gd")
const ENTRY := preload("res://scripts/systems/ending_entry.gd")
const WAKE_TEXTS := preload("res://scripts/ui/reality_wake_texts.gd")
const TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")

static func build(state: Dictionary, locale: String = "ko") -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var run: Dictionary = state.get("ending_run", {})
	var branch: String = run.get("branch_id", "")
	if branch not in ["reality", "stay"]: return pages
	var final_node := "EDR_FINAL_FRAME" if branch == "reality" else "EDS_FINAL_FRAME"
	if final_node not in run.get("completed_nodes", []): return pages
	var ceremony := ENTRY.progress(state)
	if run.get("all_ceremony_seen",false) and "ED_ALL_CEREMONY" in run.get("completed_nodes",[]) and int(ceremony["identity_index"]) == 5 and ceremony["authority_seen"]:
		var all_complete := true
		for owner in ENTRY.OWNERS:
			if not state["meta_progress"]["servants"][owner]["core_event_complete"]: all_complete = false
		if all_complete:
			for index in range(ENTRY.IDENTITIES.size()): pages.append({"title":TEXTS.text("identity",locale) % TEXTS.WAKE.name_for(ENTRY.OWNERS[index],locale),"text":TEXTS.identity(index,locale)})
			pages.append({"title":TEXTS.text("authority_title",locale),"text":TEXTS.text("authority",locale)})
	for id in ENTRY.TEXT:
		if id in run.get("completed_nodes", []) and id.begins_with("EDR_" if branch == "reality" else "EDS_"):
			pages.append({"title":TEXTS.text("entry",locale) % TEXTS.text(branch,locale),"text":TEXTS.entry(id,locale)})
	if run.get("branch_id") == "reality" and "EDR_FINAL_FRAME" in run.get("completed_nodes", []):
		var farewell_count := clampi(WAKE.index(state), 0, WAKE.OWNERS.size())
		for index in range(farewell_count):
			var owner: String = WAKE.OWNERS[index]
			for line in TEXTS.WAKE.farewell(state, owner,locale)["lines"]:
				pages.append({"title":TEXTS.text("farewell",locale) % TEXTS.WAKE.name_for(owner,locale),"text":str(line["speaker"]) + "\n" + str(line["text"])})
		for id in WAKE.BODY:
			if id in run.get("required_interactions_seen", []):
				var data: Array = TEXTS.WAKE.body(id,locale)
				var body_text: String = data[1]
				if _body_repeat_seen(state,id): body_text += "\n" + data[2]
				pages.append({"title":TEXTS.text("body",locale) % data[0],"text":body_text})
		var notebook: Dictionary = state["loop_state"]["event_local_states"].get("FIELD_NOTEBOOK", {})
		for id in NOTEBOOK.PAGES:
			if id in notebook.get("pages", []):
				var expanded: bool = id in notebook.get("expanded_pages", [])
				pages.append({"title":TEXTS.text("notebook",locale) % TEXTS.FIELD.title(id,locale),"text":TEXTS.FIELD.page_text(state, id, expanded,locale)})
		for id in NOTEBOOK.EXIT:
			if id in run.get("required_interactions_seen", []):
				pages.append({"title":TEXTS.text("exit",locale) % TEXTS.FIELD.exit_text(id,0,locale),"text":TEXTS.FIELD.exit_text(id,1,locale)})
		var local := SURFACE.local(state)
		for id in SURFACE.OBJECTS:
			if id in local["seen"]: pages.append({"title":TEXTS.SURFACE.object_text(id,0,locale),"text":TEXTS.SURFACE.object_text(id,1,locale)})
		pages.append({"title":TEXTS.text("reality_final",locale),"text":TEXTS.SURFACE.final_frame(local["look"],locale)})
	elif run.get("branch_id") == "stay" and "EDS_FINAL_FRAME" in run.get("completed_nodes", []):
		var charter := CHARTER.progress(state)
		for index in charter["principles"]:
			pages.append({"title":TEXTS.text("memory",locale),"text":TEXTS.CHARTER.principle(int(index),locale)})
		var appearance: String = run.get("ending_appearance_mode", "unset")
		if "OBJ_STAY_APPEARANCE_CONTROL" in run.get("required_interactions_seen", []) and appearance in CHARTER.MODES:
			pages.append({"title":TEXTS.text("appearance",locale),"text":TEXTS.CHARTER.mode(appearance,locale)})
		for owner in CHARTER.OWNERS:
			if owner in charter["proposed"]:
				pages.append({"title":TEXTS.text("autonomy",locale),"text":TEXTS.text("proposed",locale) % TEXTS.CHARTER.owner(owner,locale)})
		var local := STAY.progress(state)
		for id in STAY.HALL:
			if id in local["hall"]: pages.append({"title":TEXTS.STORY.hall(id,0,locale),"text":TEXTS.STORY.hall(id,1,locale)})
		for owner in STAY.TABLE:
			if owner not in local["table"]: continue
			for line in TEXTS.STORY.table_lines(state, owner,locale): pages.append({"title":TEXTS.STORY.table_title(owner,locale),"text":str(line["speaker"]) + "\n" + str(line["text"])})
		for index in local["written"]: pages.append({"title":TEXTS.text("written",locale),"text":TEXTS.STORY.sentence(int(index),locale)})
		pages.append({"title":TEXTS.text("stay_final",locale),"text":TEXTS.STORY.seating(state,locale)})
	return pages


static func _body_repeat_seen(state: Dictionary, id: String) -> bool:
	# The required-interaction flag proves the first reading, not a repeat reading.
	var known_texts := [WAKE.BODY[id][2], WAKE_TEXTS.body(id,"en")[2]]
	for entry in state.get("meta_progress",{}).get("dialogue_history",{}).get("entries",[]):
		if entry.get("line_id","") != "CH1_HISTORY_TRANSCRIPT": continue
		if entry.get("variables",{}).get("text","") in known_texts: return true
	return false
