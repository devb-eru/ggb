extends SceneTree

const OUTPUT := "res://data/notebook/chapter_one_v1.json"
const TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const COMMON := preload("res://data/dialogue/prologue/prologue_text.tres")
const DISPLAY := preload("res://scripts/ui/chapter_one_display_texts.gd")
const FEEDBACK := preload("res://scripts/systems/chapter_one_notebook.gd")
const FIXED_EVENTS := {"WAKE": "MORNING", "MOVE": "MOVE", "MARK": "A1", "CONFIRM_MARK": "A2", "ROUTINE": "AS", "LAYOUT_SOLVED": "B3_A"}
const RESOURCE_GROUPS := {
	"B1": ["CH1_B1_TEXT_EDGAR", "CH1_B1_TEXT_LUCA", "CH1_B1_TEXT_MARA1", "CH1_B1_TEXT_MARA2", "CH1_B1_SOLVED"],
	"B2": ["CH1_B2_HIDDEN", "CH1_B2_NORMAL", "CH1_B2_ALERT", "CH1_B2_LEFT"],
	"J1": ["CH1_J1_RESTORED"],
	"B3_A": ["CH1_CLOCK_BEDROOM", "CH1_CLOCK_PARLOR", "CH1_CLOCK_LIBRARY_OUTER", "CH1_CLOCK_GREAT_CLOCK"],
	"B3_B": ["CH1_CLOCK_TEST_OK", "CH1_CLOCK_ACTIVATION_OK"],
	"BSHORT": ["CH1_BSHORT_COMPLETE"],
	"B4": ["CH1_B4_RECORDED"],
	"J2": ["CH1_J2_RESTORED"],
}
var contents := {}
var failed := false


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-source-project="):
			var root := argument.trim_prefix("--verify-source-project=")
			for catalog in [TEXT, COMMON]:
				var external := ResourceLoader.load(root.path_join(catalog.resource_path.trim_prefix("res://")), "", ResourceLoader.CACHE_MODE_IGNORE)
				if external == null or external.localized_text != catalog.localized_text:
					push_error("Source text differs: " + catalog.resource_path)
					quit(1)
					return
	for id in FEEDBACK.FIXED:
		_add(id, FIXED_EVENTS[id], FEEDBACK.FIXED[id], DISPLAY.feedback(FEEDBACK.FIXED[id], "en-US"), "SUBJECT", "act:" + id.to_lower())
	for event in RESOURCE_GROUPS:
		for id in RESOURCE_GROUPS[event]: _resource(id, event)
	for object in ["DESK", "INDEX", "DRAWER", "ALCOVE", "GAP", "LINK", "LINK_OPEN"]:
		_resource("CH1_INNER_" + object, "B2")
		_resource("CH1_INNER_" + object + "_VISIT", "B2")
	for category in ["REFERENCE", "RELAY", "OUTPUT", "EXCLUDED", "PHASE_TOO_EARLY", "PHASE_SIMULTANEOUS", "PHASE_BETWEEN", "PHASE_UNSET"]:
		# Test mode only inspects roles; timing categories are activation-only.
		if category in ["REFERENCE", "RELAY", "OUTPUT", "EXCLUDED"]: _resource("CH1_CLOCK_RESULT_" + category, "B3_B")
		_resource("CH1_CLOCK_FAILURE_" + category, "B3_B")
	_add("MARA2_MEMORY", "MARA2_S1", DISPLAY.ui("mara2_memory_line", "ko-KR"), DISPLAY.ui("mara2_memory_line", "en-US"), "MARA2", "_show_mara2_memory")
	_add("LAYOUT_COUNT", "B3_A", "일치한 구간: {matched} / 4", "Matched sections: {matched} / 4", "SUBJECT", "act:board_check", {"matched": "int"})
	_add("LAYOUT_PIECE", "B3_A", "{position}번 자리의 배선이 옆 조각과 이어지지 않는다.", "The wiring in position {position} does not connect to the neighboring piece.", "SUBJECT", "act:board_check/piece", {"position": "int"})
	_add("LAYOUT_ROTATION", "B3_A", "{position}번 자리의 모서리 홈과 나사 구멍이 어긋난다.", "The corner groove and screw hole in position {position} do not align.", "SUBJECT", "act:board_check/rotation", {"position": "int"})
	for spec in [["BACK", "외부 서고의 선이 서쪽 공명통이 아닌 동쪽으로 향한다. 뒷면에도 흑연이 묻어 있다."], ["MISSING", "네 탁본과 방향을 모두 확인해야 한다."]]:
		_add("LAYOUT_" + spec[0], "B3_A", spec[1], DISPLAY._layout_line(spec[1]), "SUBJECT", "act:board_check/" + spec[0].to_lower())
	if failed or contents.size() != 57:
		push_error("Chapter-one content generation was incomplete.")
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_CHAPTER_ONE_SEED: ", contents.size())
	quit()


func _resource(id: String, event: String) -> void:
	for locale in ["ko-KR", "en-US"]:
		if not TEXT.localized_text[locale].has(id):
			push_error("Missing explicit source " + id)
			failed = true
			return
	var speaker := "EDGAR" if id in ["CH1_B2_NORMAL", "CH1_B2_ALERT"] else "SUBJECT"
	_add(id, event, TEXT.localized_text["ko-KR"][id], TEXT.localized_text["en-US"][id], speaker, "act:text_id=" + id)
	if not contents.has("NB_CH1_" + id): return
	var row: Dictionary = contents["NB_CH1_" + id]["1"]
	row.source_text_id = id
	row.text_source = TEXT.resource_path


func _add(id: String, event: String, ko: String, en: String, speaker: String, symbol: String, variables: Dictionary = {}) -> void:
	var korean := Array(ko.split("\n", false))
	var english := Array(en.split("\n", false))
	if korean.size() != english.size() or korean.is_empty():
		push_error("Unequal localized segment boundaries " + id)
		failed = true
		return
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	var source := "scripts/chapters/chapter_one_controller.gd" if id == "MARA2_MEMORY" else "scripts/systems/chapter_one_session.gd"
	var row := {"producer_id": "NP04", "source_file": source, "source_symbol": symbol, "event_id": event, "node_ids": nodes, "action_or_variant": "feedback", "speaker_id": speaker, "location_source": "history_context:captured_before_commit", "entry_kind": "dialogue", "disclosure_owner": "actual_display_or_choice_press", "visible_segment_ids": [], "knowledge_ref": "", "protection_reasons": [] if id in ["MOVE", "ROUTINE"] else ["clue_source"], "mapping_status": "AUTHORED_ID", "owner": "development/content", "localization_keys": {}, "variables": {}, "locales": {}}
	for locale in ["ko-KR", "en-US"]:
		if not COMMON.localized_text[locale].has("UI_SPEAKER_" + speaker):
			push_error("Missing speaker source " + speaker)
			failed = true
			return
		row.locales[locale] = {"title": "저택 조사: " + event if locale == "ko-KR" else "Mansion investigation: " + event, "summary": "그때 확인한 말과 조사 결과" if locale == "ko-KR" else "Words and results observed then", "speaker": COMMON.localized_text[locale]["UI_SPEAKER_" + speaker]}
	for index in range(korean.size()):
		var segment := "line_%02d" % (index + 1)
		row.visible_segment_ids.append(segment)
		row.localization_keys[segment] = "NB_CH1_" + id + ":" + segment
		row.variables[segment] = variables.duplicate(true)
		row.locales["ko-KR"][segment] = korean[index]
		row.locales["en-US"][segment] = english[index]
	contents["NB_CH1_" + id] = {"1": row}
