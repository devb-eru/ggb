extends SceneTree

const OUTPUT := "res://data/notebook/basement_v1.json"
const NOTES := preload("res://scripts/systems/basement_notebook.gd")
const DISPLAY := preload("res://scripts/ui/basement_display_texts.gd")
const RULES := preload("res://data/puzzles/puzzle_basement.tres")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const TITLES := {"D0": ["평면도 발견", "Finding the Floorplan"], "D0_A": ["도면 방향 검증", "Verifying the Plan"], "D1": ["지하 압력 장치", "Basement Pressure Mechanism"], "D2": ["지하창고 조사", "Basement Storage Investigation"], "D4": ["태엽 심장", "Clockwork Heart"]}
var contents := {}
var failed := false


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	_feedback("FLOORPLAN", "D0", NOTES.FIXED.FLOORPLAN)
	_note("FLOORPLAN", "D0", "BASEMENT_PLAN", "document", "observed", ["아직 방향을 검증하지 않은 도면", "The plan before orientation verification"], NOTES.FIXED.FLOORPLAN, ["MIRROR_TRACING", "MIRROR_J3"])
	contents.NB_BASEMENT_NOTE_FLOORPLAN["1"].superseded_by_content_ids = ["NB_BASEMENT_NOTE_PLAN"]
	for valid in [false, true]:
		var result := RULES.inspect_overlay(270 if valid else 0, valid, "great_clock" if valid else "")
		_feedback("OVERLAY_SUCCESS" if valid else "OVERLAY_MISMATCH", "D0_A", result.text)
		if valid: _note("PLAN", "D0_A", "BASEMENT_PLAN", "hypothesis", "verified", ["검증한 도면 방향과 깊이", "Verified plan orientation and depths"], result.text, ["BASEMENT_PLAN", "MIRROR_TRACING", "MIRROR_J3"])
	var axes := RULES.axis_default()
	axes.depths = RULES.DEPTHS.duplicate()
	for axis in RULES.AXES:
		var result := RULES.axis_action(axes, "push", axis, true)
		_feedback(result.feedback_key, "D1", result.text)
		axes = result.state
	var warning := RULES.axis_action(axes, "central", "counterclockwise", true)
	_feedback(warning.feedback_key, "D1", warning.text)
	var release := RULES.axis_action(warning.state, "central", "counterclockwise", false)
	_feedback(release.feedback_key, "D1", release.text)
	var opened := RULES.axis_action(axes, "central", "clockwise", true)
	_feedback(opened.feedback_key, "D1", opened.text)
	for failure in [RULES.axis_action(RULES.axis_default(), "push", "branch", true), RULES.axis_action(RULES.axis_default(), "push", "line", true), RULES.axis_action(warning.state, "central", "counterclockwise", true)]:
		_feedback(failure.feedback_key, "D1", failure.text)
		var key := "FAILURE_" + String(failure.state.failure.category).to_upper()
		_note(key, "D1", "BASEMENT_FAILURE", "failure", "observed", ["당일 압력핀 잠김", "The pressure pins locked for the day"], failure.text + "\n" + NOTES.FIXED.FAILURE_SUFFIX, ["BASEMENT_PLAN", "BASEMENT_FAILURE"])
		contents["NB_BASEMENT_NOTE_" + key]["1"].new_attempt = true
	_note("ACCESS", "D1", "BASEMENT_ACCESS", "hypothesis", "verified", ["직접 검증한 지하창고 접근", "Manually verified access to the basement"], NOTES.FIXED.ACCESS, ["BASEMENT_PLAN"])
	_note("RESOLVED", "D1", "BASEMENT_FAILURE", "failure", "observed", ["압력핀 절차 해결", "The pressure-pin procedure resolved"], NOTES.RESOLVED, ["BASEMENT_FAILURE", "BASEMENT_ACCESS"], "I verified the procedure for opening the basement storage. The previously locked pressure pins and their failure records remain.")
	_feedback("SHORTCUT", "D1", NOTES.FIXED.SHORTCUT)
	_feedback("FASTPATH", "D2", NOTES.FIXED.FASTPATH)
	for object_id in NOTES.STORAGE:
		_feedback("STORAGE_" + String(object_id).to_upper(), "D2", NOTES.STORAGE[object_id])
		_feedback("STORAGE_" + String(object_id).to_upper() + "_DOOR", "D2", NOTES.STORAGE[object_id] + "\n" + NOTES.FIXED.DOOR)
	var heart := RULES.heart_default()
	for handle in ["A", "B", "C", "C"]:
		var turned := RULES.heart_action(heart, "turn", handle)
		_feedback(turned.feedback_key, "D4", turned.text)
		heart = turned.state
	for action in ["fix", "wind", "stabilize", "inspect_auxiliary", "pull_auxiliary"]:
		if action == "stabilize": heart.wind = 12
		var result := RULES.heart_action(heart, action, null, true)
		_feedback(result.feedback_key, "D4", result.text)
		heart = result.state
	_note("D4", "D4", "BASEMENT_HEART", "observation", "observed", ["XII 다음 입력의 결과", "The result of the input after XII"], NOTES.FIXED.D4, ["BASEMENT_PLAN", "BASEMENT_ACCESS", "MIRROR_TRACING", "CH1_WAVEFORM"])
	contents.NB_BASEMENT_NOTE_D4["1"].source_content_ids = ["NB_BASEMENT_HEART_STABILIZE", "NB_BASEMENT_HEART_INSPECT_AUXILIARY", "NB_MODAL_BASEMENT_AUXILIARY_OPTIONS", "NB_MODAL_BASEMENT_AUXILIARY_SELECT_2"]
	_modals()
	if failed or contents.size() != 56:
		push_error("Incomplete basement catalog: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_BASEMENT_SEED: ", contents.size())
	quit()


func _base(id: String, event: String, kind: String, variant: String = "feedback") -> Dictionary:
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	return {"producer_id": "NP08", "source_file": "scripts/systems/basement_session.gd", "source_symbol": "act:" + id, "event_id": event,
		"node_ids": nodes, "action_or_variant": variant, "speaker_id": "SUBJECT", "location_source": "history_context:captured_before_commit",
		"entry_kind": kind, "disclosure_owner": "event_note_commit" if kind == "document_segment" else "actual_display_or_choice_press",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": ["knowledge" if kind == "document_segment" else "clue_source"],
		"localization_keys": {}, "variables": {}, "locales": {
			"ko-KR": {"title": TITLES[event][0], "summary": "그때 확인한 지하 조사", "speaker": "주인공"},
			"en-US": {"title": TITLES[event][1], "summary": "The basement investigation observed then", "speaker": "Protagonist"}}}


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _feedback(id: String, event: String, ko: String) -> void:
	var row := _base(id, event, "dialogue")
	var en := DISPLAY.feedback(ko, "en-US")
	var korean := ko.split("\n", false)
	var english := en.split("\n", false)
	if korean.size() != english.size() or en == ko or ko.is_empty():
		failed = true
		push_error("Missing basement feedback: " + id)
		return
	for locale in row.locales: row.locales[locale].speaker = PROLOGUE.localized_text[locale]["UI_SPEAKER_SUBJECT"]
	for index in range(korean.size()): _segment(row, "line_%02d" % (index + 1), korean[index], english[index])
	contents["NB_BASEMENT_" + id] = {"1": row}


func _note(id: String, event: String, knowledge_id: String, category: String, status: String, titles: Array, ko: String, sources: Array, english: String = "") -> void:
	var row := _base(id, event, "document_segment", "recorded")
	var en := DISPLAY.feedback(ko, "en-US") if english.is_empty() else english
	if en == ko:
		failed = true
		push_error("Missing basement note translation: " + id)
	_segment(row, "body", ko, en)
	row.locales["ko-KR"].merge({"title": titles[0], "summary": titles[0], "speaker": "수첩"}, true)
	row.locales["en-US"].merge({"title": titles[1], "summary": titles[1], "speaker": "Notebook"}, true)
	row.knowledge = {"knowledge_id": knowledge_id, "category": category, "epistemic_state": status, "provenance_state": "identified", "lifetime": "persistent"}
	row.source_knowledge_ids = sources
	contents["NB_BASEMENT_NOTE_" + id] = {"1": row}


func _modals() -> void:
	for axis in RULES.AXES:
		_modal("BASEMENT_AXIS_" + String(axis).to_upper(), "D1", "axis", axis, "axis_modal_body", ["review_plan", "review_depth", "axis_push"], ["ui", "cancel", "confirm"], 1)
	for direction in ["clockwise", "counterclockwise"]:
		_modal("BASEMENT_CENTRAL_" + direction.to_upper(), "D1", "central", direction, "central_modal_body", ["review_direction", "move_selected"], ["cancel", "confirm"], 0)
	_modal("BASEMENT_AUXILIARY", "D4", "auxiliary", "", "auxiliary_modal_body", ["do_not_pull", "review_record", "pull_auxiliary"], ["cancel", "ui", "confirm"], 0)


func _modal(key: String, event: String, kind: String, target: String, body: String, labels: Array, kinds: Array, cancel: int) -> void:
	var row := _base(key, event, "options_presented", "shown")
	row.source_file = "scripts/chapters/basement_controller.gd"
	row.source_symbol = "_confirm_" + kind + ":" + target
	row.location_source = "history_context:captured_before_modal"
	row.speaker_id = "SYSTEM"
	row.protection_reasons = ["choice_context"]
	var titles := []
	for locale in ["ko-KR", "en-US"]:
		row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
		titles.append(DISPLAY.axis_confirmation_title(target, locale) if kind == "axis" else DISPLAY.central_confirmation_title(target, locale) if kind == "central" else DISPLAY.ui("auxiliary_modal_title", locale))
	_segment(row, "header", titles[0], titles[1])
	_segment(row, "body", DISPLAY.ui(body, "ko-KR"), DISPLAY.ui(body, "en-US"))
	row.choices = []
	row.cancel_index = cancel
	for index in range(labels.size()):
		var option := "option_%d" % index
		_segment(row, option, DISPLAY.ui(labels[index], "ko-KR"), DISPLAY.ui(labels[index], "en-US"))
		var id := "NB_MODAL_%s_SELECT_%d" % [key, index]
		row.choices.append({"content_id": id if kinds[index] != "ui" else "", "kind": kinds[index]})
		if kinds[index] == "ui": continue
		var selected := _base(key, event, "choice_cancelled" if kinds[index] == "cancel" else "choice_confirmed", option)
		selected.source_file = row.source_file
		selected.source_symbol = row.source_symbol
		selected.location_source = row.location_source
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", DISPLAY.ui(labels[index], "ko-KR"), DISPLAY.ui(labels[index], "en-US"))
		contents[id] = {"1": selected}
	row.default_segments = row.visible_segment_ids.duplicate()
	contents["NB_MODAL_" + key + "_OPTIONS"] = {"1": row}


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
