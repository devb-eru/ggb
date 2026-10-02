extends SceneTree

const OUTPUT := "res://data/notebook/fracture_v1.json"
const NOTES := preload("res://scripts/systems/fracture_notebook.gd")
const SESSION := preload("res://scripts/systems/basement_session.gd")
const TRANSITION := preload("res://scripts/ui/fracture_transition_texts.gd")
const REST := preload("res://scripts/ui/fracture_rest_texts.gd")
const COMMON := preload("res://scripts/ui/fracture_common_display_texts.gd")
const BASEMENT := preload("res://scripts/ui/basement_display_texts.gd")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const TITLES := {"D5": ["드러난 저택", "The Exposed Mansion"], "D6": ["파열 이후의 휴식", "Rest After the Fracture"], "E1": ["돌아오지 않은 아침", "The Morning That Did Not Return"], "LUCA_S2": ["루카의 차가운 손", "Luca's Cold Hand"], "E2": ["사용인들의 보고와 합의", "The Servants' Report and Agreement"], "E_MOVE": ["달라진 저택의 이동", "Moving Through the Changed Mansion"], "POST_BROKEN_REST": ["균열 이후의 짧은 휴식", "A Short Rest After the Fracture"]}
var contents := {}
var failed := false


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for key in NOTES.TEXT:
		var event := "D5" if key.begins_with("D5") else "D6" if key.begins_with("D6") else "E1" if key.begins_with("E1") else "LUCA_S2" if key.begins_with("LUCA") else "E_MOVE" if key.begins_with("MOVE") else "POST_BROKEN_REST" if key == "POST_REST" else "E2"
		var speaker := "LUCA" if key.begins_with("LUCA") else "EDGAR" if key == "E2_FINISH" else "SUBJECT"
		_feedback(key, event, NOTES.TEXT[key], speaker)
	for key in SESSION.E1_OBJECTS: _feedback("E1_" + String(key).to_upper(), "E1", SESSION.E1_OBJECTS[key])
	for key in SESSION.E2_ANSWERS: _feedback("E2_ANSWER_" + String(key).to_upper(), "E2", SESSION.E2_ANSWERS[key], "LUCA" if key == "body" else "EDGAR")
	for key in NOTES.INSPECTIONS:
		var id := "D6_" + String(key).to_upper()
		_feedback(id, "D6", NOTES.INSPECTIONS[key])
		_note(id, "D6", "FRACTURE_" + id, ["파열 뒤의 조사 · " + ["벽지", "서비스 표지", "진단 잔상", "캡슐", "낙서와 배선"][NOTES.INSPECTIONS.keys().find(key)], "After the fracture: " + String(key)], NOTES.INSPECTIONS[key], ["FRACTURE_D5"])
	_note("D5", "D5", "FRACTURE_D5", TITLES.D5, NOTES.TEXT.D5_COMPLETE, ["BASEMENT_HEART"])
	_note("E1_WAKE", "E1", "FRACTURE_WAKE", ["남아 있는 흑연 글씨", "The Graphite Writing That Remains"], NOTES.NOTES.E1_WAKE, ["FRACTURE_D5"])
	_note("E1_DIFFERENT", "E1", "FRACTURE_DIFFERENT_MORNING", TITLES.E1, NOTES.NOTES.E1_DIFFERENT, ["FRACTURE_WAKE"])
	_note("E2_REPORT", "E2", "FRACTURE_REPORT", TITLES.E2, NOTES.NOTES.E2_REPORT, ["FRACTURE_DIFFERENT_MORNING"])
	for key in ["INDEX_KNOWN", "INDEX_ANONYMOUS"]:
		_note(key, "E2", "FRACTURE_ARCHIVE_INDEX", ["인격 아카이브 색인", "Personality Archive Index"], NOTES.NOTES[key], ["FRACTURE_REPORT"])
	contents.NB_FRACTURE_NOTE_INDEX_ANONYMOUS["1"].knowledge.provenance_state = "unverified"
	contents.NB_FRACTURE_NOTE_INDEX_ANONYMOUS["1"].superseded_by_content_ids = ["NB_FRACTURE_NOTE_INDEX_KNOWN"]
	for index in range(TRANSITION.KO.size()):
		var row := _base("TRANSITION_%02d" % (index + 1), "D5", "dialogue", "SUBJECT" if index == 5 else "SYSTEM")
		row.source_file = "scripts/ui/fracture_transition_texts.gd"
		row.source_symbol = "lines:" + str(index)
		_segment(row, "body", TRANSITION.KO[index], TRANSITION.EN[index])
		contents["NB_FRACTURE_TRANSITION_%02d" % (index + 1)] = {"1": row}
	for owner in TRANSITION.REACTIONS:
		for mode in ["bond", "alert"]:
			if not TRANSITION.REACTIONS[owner].has(mode + "_ko"): continue
			var key := TRANSITION.reaction_key({"owner": owner, "mode": mode})
			var row := _base(key, "D5", "dialogue", owner)
			row.source_file = "scripts/ui/fracture_transition_texts.gd"
			row.source_symbol = "reaction:" + owner + ":" + mode
			_segment(row, "body", TRANSITION.REACTIONS[owner][mode + "_ko"], TRANSITION.REACTIONS[owner][mode + "_en"])
			contents["NB_FRACTURE_" + key] = {"1": row}
	var transition_sources: Array = []
	for id in contents:
		if id.begins_with("NB_FRACTURE_TRANSITION_") or id.begins_with("NB_FRACTURE_REACTION_"): transition_sources.append(id)
	contents.NB_FRACTURE_NOTE_D5["1"].source_content_ids = transition_sources
	contents.NB_FRACTURE_NOTE_E1_DIFFERENT["1"].source_content_ids = ["NB_FRACTURE_E1_BED", "NB_FRACTURE_E1_WINDOW", "NB_FRACTURE_E1_MIRROR", "NB_FRACTURE_E1_CALL_CORD"]
	contents.NB_FRACTURE_NOTE_E2_REPORT["1"].source_content_ids = ["NB_FRACTURE_E2_REPORT", "NB_FRACTURE_E2_ANSWER_HOUSE", "NB_FRACTURE_E2_ANSWER_BODY", "NB_FRACTURE_E2_ANSWER_MEMORY"]
	for route in ["bedroom", "capsule"]: _modal(route)
	if failed or contents.size() != 67:
		push_error("Incomplete fracture catalog: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_FRACTURE_SEED: ", contents.size())
	quit()


func _base(key: String, event: String, kind: String, speaker: String = "SUBJECT", variant: String = "feedback") -> Dictionary:
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	return {"producer_id": "NP09", "source_file": "scripts/systems/basement_session.gd", "source_symbol": key, "event_id": event, "node_ids": nodes,
		"action_or_variant": variant, "speaker_id": speaker, "location_source": "history_context:captured_before_commit_or_display", "entry_kind": kind,
		"disclosure_owner": "event_note_commit" if kind == "document_segment" else "actual_display_or_choice_press", "mapping_status": "AUTHORED_ID", "owner": "planning/engineering",
		"visible_segment_ids": [], "protection_reasons": ["knowledge" if kind == "document_segment" else "clue_source"], "localization_keys": {}, "variables": {},
		"locales": {"ko-KR": {"title": TITLES[event][0], "summary": TITLES[event][0], "speaker": _speaker(speaker, "ko-KR")}, "en-US": {"title": TITLES[event][1], "summary": TITLES[event][1], "speaker": _speaker(speaker, "en-US")}}}


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _english(ko: String) -> String:
	return REST.text(COMMON.feedback(BASEMENT.feedback(ko, "en-US"), "en-US"), "en-US")


func _feedback(id: String, event: String, ko: String, speaker: String = "SUBJECT") -> void:
	var row := _base(id, event, "dialogue", speaker)
	if id in ["MOVE_CORRIDOR", "D6_MOVE", "D6_REST"]: row.protection_reasons = []
	var en := _english(ko)
	var korean := ko.split("\n", false)
	var english := en.split("\n", false)
	if korean.size() != english.size() or en == ko:
		failed = true
		push_error("Missing fracture translation: " + id)
		return
	for index in range(korean.size()): _segment(row, "line_%02d" % (index + 1), korean[index], english[index])
	contents["NB_FRACTURE_" + id] = {"1": row}


func _note(id: String, event: String, knowledge_id: String, titles: Array, ko: String, sources: Array) -> void:
	var row := _base(id, event, "document_segment", "SUBJECT", "recorded")
	var en := _english(ko)
	if en == ko and id != "INDEX_KNOWN":
		failed = true
		push_error("Missing fracture note: " + id)
	_segment(row, "body", ko, en)
	row.locales["ko-KR"].merge({"title": titles[0], "summary": titles[0], "speaker": "수첩"}, true)
	row.locales["en-US"].merge({"title": titles[1], "summary": titles[1], "speaker": "Notebook"}, true)
	row.knowledge = {"knowledge_id": knowledge_id, "category": "document" if id.begins_with("INDEX") else "observation", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"}
	row.source_knowledge_ids = sources
	contents["NB_FRACTURE_NOTE_" + id] = {"1": row}


func _modal(route: String) -> void:
	var key := "FRACTURE_REST_" + route.to_upper()
	var ko := REST.confirmation(route, "ko-KR")
	var en := REST.confirmation(route, "en-US")
	var row := _base(key, "D6", "options_presented", "SYSTEM", "shown")
	row.source_file = "scripts/chapters/basement_controller.gd"
	row.source_symbol = "_confirm_d6_rest:" + route
	row.protection_reasons = ["choice_context"]
	for locale in row.locales: row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	_segment(row, "header", ko.title, en.title)
	_segment(row, "body", ko.body, en.body)
	row.choices = []
	row.cancel_index = 0
	for index in range(2):
		_segment(row, "option_%d" % index, ko.labels[index], en.labels[index])
		var id := "NB_MODAL_%s_SELECT_%d" % [key, index]
		row.choices.append({"content_id": id, "kind": "cancel" if index == 0 else "confirm"})
		var choice := _base(key, "D6", "choice_cancelled" if index == 0 else "choice_confirmed", "SUBJECT", "option_%d" % index)
		choice.source_file = row.source_file
		choice.source_symbol = row.source_symbol
		choice.protection_reasons = ["choice"]
		for locale in choice.locales: choice.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(choice, "body", ko.labels[index], en.labels[index])
		contents[id] = {"1": choice}
	row.default_segments = row.visible_segment_ids.duplicate()
	contents["NB_MODAL_" + key + "_OPTIONS"] = {"1": row}


func _speaker(id: String, locale: String) -> String:
	if id == "LUCA" and locale == "en-US": return "Luca"
	return PROLOGUE.localized_text[locale]["UI_SPEAKER_" + ("LUKA" if id == "LUCA" else id)]


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
