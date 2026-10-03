extends SceneTree

const NOTES := preload("res://scripts/systems/reality_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ENTRY := preload("res://scripts/ui/ending_gallery_texts.gd")
const WAKE := preload("res://scripts/ui/reality_wake_texts.gd")
const FIELD := preload("res://scripts/ui/field_notebook_texts.gd")
const SURFACE := preload("res://scripts/ui/reality_surface_texts.gd")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
var contents := {}
var failed := false


func _initialize() -> void:
	var path := "res://data/notebook/reality_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for node in ENTRY.ENTRIES:
		for mode in ["SCREEN", "READ"]:
			_add("ENTRY_%s_%s" % [mode, node], ENTRY.entry(node,"ko-KR"), ENTRY.entry(node,"en-US"), [node], "dialogue" if mode == "READ" else "document_segment")
	for key in ["identity_neutral", "signature_guide"]:
		_add("CEREMONY_" + key.to_upper(), ENTRY.text(key,"ko-KR"), ENTRY.text(key,"en-US"), ["ED_ALL_CEREMONY"], "document_segment")
	for index in range(ENTRY.ENTRY.OWNERS.size()):
		var owner: String = ENTRY.ENTRY.OWNERS[index]
		var speakers := [WAKE.name_for(owner,"ko-KR"), WAKE.name_for(owner,"en-US")]
		_add("IDENTITY_" + owner.to_upper(), ENTRY.identity(index,"ko-KR"), ENTRY.identity(index,"en-US"), ["ED_ALL_CEREMONY"], "dialogue", speakers, owner.to_upper())
		_add("CEREMONY_PROGRESS_" + owner.to_upper(), ENTRY.text("identity_progress","ko-KR") % [index + 1, speakers[0]], ENTRY.text("identity_progress","en-US") % [index + 1, speakers[1]], ["ED_ALL_CEREMONY"], "document_segment")
	_add("AUTHORITY", ENTRY.text("authority","ko-KR"), ENTRY.text("authority","en-US"), ["ED_ALL_CEREMONY"], "dialogue", [WAKE.name_for("edgar","ko-KR"), WAKE.name_for("edgar","en-US")], "EDGAR")
	for branch in NOTES.SIGNATURE:
		_add("SIGN_" + String(branch).to_upper(), NOTES.SIGNATURE[branch][0], NOTES.SIGNATURE[branch][1], ["ED_ALL_CEREMONY"])
	# Run canonical branch selection only at authoring time to freeze its bilingual IDs.
	for owner in WAKE.RULES.OWNERS:
		for complete in [false, true]:
			for outcome in WAKE.RULES.OVERLAYS[owner]:
				for band in [0, 2, 4]:
					var state := _state()
					state.meta_progress.servants[owner].core_event_complete = complete
					state.meta_progress.servants[owner].bond = band
					state.meta_progress.servants[owner].alert = band
					state.meta_progress.event_history[WAKE.RULES.EVENTS[owner]] = {"lifecycle":"completed", "outcome_id":outcome}
					_farewell(state, owner)
		_add("HANDOFF_BOARD_" + String(owner).to_upper(), WAKE.text("handoff_board","ko-KR") % WAKE.name_for(owner,"ko-KR"), WAKE.text("handoff_board","en-US") % WAKE.name_for(owner,"en-US"), ["EDR_FAREWELL"], "document_segment")
	for mode in ["public", "direct_private", "indirect", "denied", "withheld", "inferred_only"]:
		var state := _state()
		for servant in state.meta_progress.servants.values(): servant.core_event_complete = mode == "public"
		state.meta_progress.servants.iris.core_event_complete = mode != "inferred_only"
		state.meta_progress.servants.iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		state.meta_progress.servants.iris.alert = 4 if mode == "denied" else 0
		_farewell(state, "iris")
	for id in ["disconnect_heat", "disconnect_pressure", "disconnect_taste", "wake_body", "wake_board"]:
		_add(id.to_upper(), WAKE.text(id,"ko-KR"), WAKE.text(id,"en-US"), ["EDR_DISCONNECT" if id.begins_with("disconnect") else "EDR_WAKE_BODY"], "document_segment" if id == "wake_board" else "dialogue")
	for object in WAKE.RULES.BODY:
		for repeated in [false,true]:
			var suffix := "REPEAT" if repeated else "FIRST"
			_add("BODY_%s_%s" % [object,suffix], WAKE.body(object,"ko-KR")[2 if repeated else 1], WAKE.body(object,"en-US")[2 if repeated else 1], ["EDR_BODY_CHECK"], "dialogue", [WAKE.text("protagonist","ko-KR"), WAKE.text("protagonist","en-US")] if repeated else ["SYSTEM","SYSTEM"], "SUBJECT" if repeated else "SYSTEM")
			_add("BODY_LABEL_%s_%s" % [object,suffix], WAKE.body(object,"ko-KR")[0] + (WAKE.text("checked","ko-KR") if repeated else ""), WAKE.body(object,"en-US")[0] + (WAKE.text("checked","en-US") if repeated else ""), ["EDR_BODY_CHECK"], "document_segment")
	for page in FIELD.RULES.PAGES:
		for expanded in [false,true]: _field(page,expanded)
		for read in [false,true]:
			var flag := "read" if read else "required" if page in FIELD.RULES.REQUIRED else ""
			_add("FIELD_LABEL_%s_%s" % [page,"READ" if read else "UNREAD"], FIELD.title(page,"ko-KR") + (FIELD.text(flag,"ko-KR") if flag != "" else ""), FIELD.title(page,"en-US") + (FIELD.text(flag,"en-US") if flag != "" else ""), ["EDR_FIELD_NOTEBOOK"], "document_segment")
	for id in FIELD.RULES.EXIT:
		_add("EXIT_READ_" + id, FIELD.exit_text(id,1,"ko-KR"), FIELD.exit_text(id,1,"en-US"), ["EDR_EXIT_PANEL"])
		for checked in [false,true]:
			_add("EXIT_LABEL_%s_%s" % [id,"CHECKED" if checked else "UNCHECKED"], FIELD.exit_text(id,0,"ko-KR") + (FIELD.text("checked","ko-KR") if checked else ""), FIELD.exit_text(id,0,"en-US") + (FIELD.text("checked","en-US") if checked else ""), ["EDR_EXIT_PANEL"], "document_segment")
	for id in SURFACE.RULES.OBJECTS:
		var nodes := ["EDR_SURFACE_THRESHOLD"] if id == "signal" else ["EDR_FACILITY_FREE_LOOK"]
		_add("OBJECT_READ_" + String(id).to_upper(), SURFACE.object_text(id,1,"ko-KR"), SURFACE.object_text(id,1,"en-US"), nodes)
		for checked in [false,true]:
			_add("OBJECT_LABEL_%s_%s" % [String(id).to_upper(),"CHECKED" if checked else "UNCHECKED"], SURFACE.object_text(id,0,"ko-KR") + (SURFACE.text("checked","ko-KR") if checked else ""), SURFACE.object_text(id,0,"en-US") + (SURFACE.text("checked","en-US") if checked else ""), nodes, "document_segment")
	_add("AIRLOCK_BOARD", SURFACE.text("airlock_board","ko-KR"), SURFACE.text("airlock_board","en-US"), ["EDR_AIRLOCK_CONFIRM"], "document_segment")
	_choices("AIRLOCK", ["cancel","enter"], ["EDR_AIRLOCK_CONFIRM"])
	_choices("LOOK", ["left","center","right"], ["EDR_FINAL_FRAME"])
	for direction in SURFACE.VIEWS:
		_add("FINAL_FRAME_" + String(direction).to_upper(), SURFACE.final_frame(direction,"ko-KR"), SURFACE.final_frame(direction,"en-US"), ["EDR_FINAL_FRAME"], "document_segment")
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not CONTENT._valid_row(row):
			failed = true
			push_error("Invalid reality row: " + id)
		for segment in row.visible_segment_ids:
			if RegEx.create_from_string("[가-힣]").search(row.locales["en-US"][segment]) != null:
				failed = true
				push_error("Untranslated reality row: " + id + ":" + segment)
		count += row.visible_segment_ids.size()
	if failed:
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1,"contents":contents},"\t",true) + "\n")
	file.close()
	print("NOTEBOOK_REALITY_SEED: %d IDs / %d segments" % [contents.size(),count])
	quit()


func _state() -> Dictionary:
	var servants := {}
	for owner in WAKE.RULES.OWNERS:
		servants[owner] = {"core_event_complete":false, "researcher_record_acquired":true, "bond":0, "alert":0}
	return {"meta_progress":{"servants":servants, "event_history":{}, "knowledge_entries":{"mara2_name_written":true}}}


func _farewell(state: Dictionary, owner: String) -> void:
	var ko := WAKE.farewell(state,owner,"ko-KR")
	var en := WAKE.farewell(state,owner,"en-US")
	for index in range(ko.lines.size()):
		_add(ko.notebook_keys[index], ko.lines[index].text, en.lines[index].text, ["EDR_FAREWELL"], "dialogue", [ko.lines[index].speaker,en.lines[index].speaker], owner.to_upper() if ko.lines[index].speaker != "SYSTEM" else "SYSTEM")


func _field(page: String, expanded: bool) -> void:
	var suffix := "FULL" if expanded else "SUMMARY"
	var source := CONTENT.definition("NB_MODAL_FIELD_%s_%s_OPTIONS" % [page,suffix],1)
	var key := "FIELD_%s_%s" % [page,suffix]
	var row := _base(key, NOTES.FIELD_NODES, "document_segment", ["현장 수첩","Field notebook"], "SYSTEM")
	row.disclosure_owner = "event_note_commit"
	row.knowledge = {"knowledge_id":"REALITY_" + page, "category":"document", "epistemic_state":"observed", "provenance_state":"identified", "lifetime":"physical"}
	row.protection_reasons = ["knowledge"]
	for segment in source.visible_segment_ids:
		if segment != "body" and not String(segment).begins_with("addendum_") and not String(segment).begins_with("sources_"): continue
		_segment(row,segment,source.locales["ko-KR"][segment],source.locales["en-US"][segment])
		row.variables[segment] = source.variables[segment].duplicate(true)
	for locale in row.locales:
		row.locales[locale].title = FIELD.title(page,locale)
		row.locales[locale].summary = FIELD.RULES.PAGES[page][1] if locale == "ko-KR" else FIELD.PAGES[page][1]
	contents[NOTES.PREFIX + key] = {"1":row}


func _choices(group: String, options: Array, nodes: Array) -> void:
	var row := _base(group + "_OPTIONS", nodes, "options_presented", [_common("HISTORY_OPTIONS","ko-KR"),_common("HISTORY_OPTIONS","en-US")])
	row.protection_reasons = ["choice_context"]
	for index in range(options.size()):
		var id: String = options[index]
		var ko := SURFACE.text(id,"ko-KR") if group == "AIRLOCK" else SURFACE.view_text(id,0,"ko-KR")
		var en := SURFACE.text(id,"en-US") if group == "AIRLOCK" else SURFACE.view_text(id,0,"en-US")
		_segment(row,"option_%d" % index,ko,en)
		var key := "%s_SELECT_%d" % [group,index]
		var cancelled := group == "AIRLOCK" and index == 0
		_add(key,ko,en,nodes,"choice_cancelled" if cancelled else "choice_confirmed",[_common("HISTORY_SELECTED","ko-KR"),_common("HISTORY_SELECTED","en-US")])
		contents[NOTES.PREFIX + key]["1"].protection_reasons = ["choice"]
	contents[NOTES.PREFIX + group + "_OPTIONS"] = {"1":row}


func _add(key: String, ko: String, en: String, nodes: Array, kind: String = "dialogue", speakers: Array = [], speaker_id: String = "SYSTEM") -> void:
	var row := _base(key,nodes,kind,speakers,speaker_id)
	_segment(row,"body",ko,en)
	var id := NOTES.PREFIX + key
	if contents.has(id) and contents[id]["1"] != row:
		failed = true
		push_error("Conflicting reality authoring ID: " + id)
	contents[id] = {"1":row}


func _base(key: String, nodes: Array, kind: String, speakers: Array, speaker_id: String = "SYSTEM") -> Dictionary:
	if speakers.is_empty(): speakers = ["장면","Scene"] if kind == "document_segment" else ["SYSTEM","SYSTEM"]
	var common: bool = nodes[0] == "ED_ALL_CEREMONY" or String(nodes[0]).begins_with("EDS_")
	return {"producer_id":"NP18", "source_file":"scripts/chapters/basement_controller.gd", "source_symbol":key,
		"event_id":nodes[0], "node_ids":nodes.duplicate(), "action_or_variant":key, "speaker_id":speaker_id,
		"location_source":"actual_ending_node_before_commit_or_display", "entry_kind":kind, "disclosure_owner":"actual_display",
		"mapping_status":"AUTHORED_ID", "owner":"planning/engineering", "visible_segment_ids":[], "variables":{}, "localization_keys":{},
		"protection_reasons":["clue_source"], "locales":{"ko-KR":{"speaker":speakers[0],"title":"엔딩 절차와 인계 기록" if common else "현실 기상과 인계 기록","summary":"당시 확인한 장면과 인계 내용"},
		"en-US":{"speaker":speakers[1],"title":"Ending Procedure and Handoff Records" if common else "Waking and Handoff Records","summary":"Scenes and handoff material observed at that time"}}}


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE,CH1,SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	push_error("Missing common text: " + id)
	return ""
