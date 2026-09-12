class_name EndingGalleryPages
extends RefCounted

const SURFACE := preload("res://scripts/systems/reality_surface.gd")
const STAY := preload("res://scripts/systems/stay_story.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const NOTEBOOK := preload("res://scripts/systems/field_notebook.gd")
const CHARTER := preload("res://scripts/systems/stay_charter.gd")

static func build(state: Dictionary) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var run: Dictionary = state.get("ending_run", {})
	if run.get("branch_id") == "reality" and "EDR_FINAL_FRAME" in run.get("completed_nodes", []):
		var farewell_count := clampi(WAKE.index(state), 0, WAKE.OWNERS.size())
		for index in range(farewell_count):
			var owner: String = WAKE.OWNERS[index]
			for line in WAKE.farewell(state, owner)["lines"]:
				pages.append({"title":"작별 · " + WAKE.NAMES[owner],"text":str(line["speaker"]) + "\n" + str(line["text"])})
		for id in WAKE.BODY:
			if id in run.get("required_interactions_seen", []):
				pages.append({"title":"신체 확인 · " + WAKE.BODY[id][0],"text":WAKE.BODY[id][1] + "\n" + WAKE.BODY[id][2]})
		var notebook: Dictionary = state["loop_state"]["event_local_states"].get("FIELD_NOTEBOOK", {})
		for id in NOTEBOOK.PAGES:
			if id in notebook.get("pages", []):
				var expanded: bool = id in notebook.get("expanded_pages", [])
				pages.append({"title":"현장 수첩 · " + NOTEBOOK.PAGES[id][0],"text":NOTEBOOK.page_text(state, id, expanded)})
		for id in NOTEBOOK.EXIT:
			if id in run.get("required_interactions_seen", []):
				pages.append({"title":"출입 점검 · " + NOTEBOOK.EXIT[id][0],"text":NOTEBOOK.EXIT[id][1]})
		var local := SURFACE.local(state)
		for id in SURFACE.OBJECTS:
			if id in local["seen"]: pages.append({"title":SURFACE.OBJECTS[id][1],"text":SURFACE.OBJECTS[id][2]})
		var views := {"left":"문틀의 거친 면에 바람의 압력이 실린다.","center":"회갈색 지표 위로 젖은 흑연선이 선명하다.","right":"먼 빛이 보인다. 무엇인지 알 수 없다. 확대하지 않는다."}
		pages.append({"title":"현실 기상 · 마지막 시선","text":"한 손에 현실 수첩을 들고, 다른 손으로 시설 문틀을 잡는다.\n" + str(views.get(local["look"], views["center"])) + "\n이 시선이 앞으로 갈 방향을 확정하지는 않는다."})
	elif run.get("branch_id") == "stay" and "EDS_FINAL_FRAME" in run.get("completed_nodes", []):
		var charter := CHARTER.progress(state)
		for index in charter["principles"]:
			pages.append({"title":"잔류 합의 · 기억 원칙","text":CHARTER.PRINCIPLES[int(index)]})
		var appearance: String = run.get("ending_appearance_mode", "unset")
		if "OBJ_STAY_APPEARANCE_CONTROL" in run.get("required_interactions_seen", []) and appearance in CHARTER.MODES:
			pages.append({"title":"잔류 합의 · 외형 표시","text":CHARTER.MODES[appearance]})
		for owner in CHARTER.OWNERS:
			if owner in charter["proposed"]:
				pages.append({"title":"잔류 합의 · 자율성","text":CHARTER.OWNERS[owner] + "의 역할을 강제가 아닌 제안으로 전환했다."})
		var local := STAY.progress(state)
		for id in STAY.HALL:
			if id in local["hall"]: pages.append({"title":STAY.HALL[id][0],"text":STAY.HALL[id][1]})
		for owner in STAY.TABLE:
			if owner not in local["table"]: continue
			for line in STAY.table_lines(state, owner): pages.append({"title":STAY.TABLE[owner][0],"text":str(line["speaker"]) + "\n" + str(line["text"])})
		for index in local["written"]: pages.append({"title":"주인공 수첩","text":STAY.SENTENCES[int(index)]})
		pages.append({"title":"안정화 잔류 · 마지막 자리","text":STAY.seating(state)})
	return pages
