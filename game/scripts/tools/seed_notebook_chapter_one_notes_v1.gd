extends SceneTree

const OUTPUT := "res://data/notebook/chapter_one_notes_v1.json"
const TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const MARKS := preload("res://scripts/systems/chapter_one_session.gd").MARKS
const NOTES := preload("res://scripts/systems/chapter_one_notes.gd")
const DISPLAY := preload("res://scripts/ui/chapter_one_display_texts.gd")
const FEEDBACK := preload("res://scripts/systems/chapter_one_notebook.gd")
var contents := {}


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-source-project="):
			var path := argument.trim_prefix("--verify-source-project=").path_join("data/dialogue/chapter_one/chapter_one_text.tres")
			var actual := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if actual == null or actual.localized_text != TEXT.localized_text:
				push_error("Chapter-one source differs.")
				quit(1)
				return
	for mark in MARKS:
		_add("A1_" + String(mark).to_upper(), "A1", "A1", "CH1_SELF_MARK", "hypothesis", "hypothesis", ["표식 실험", "The mark experiment"], "자기 표식: %s\n다음 아침에 동일성을 확인한다." % MARKS[mark], "My mark: %s\nCheck that it is unchanged the following morning." % TEXT.localized_text["en-US"]["CH1_MARK_" + String(mark).to_upper()])
	_add("A2", "A2", "A2", "CH1_SELF_MARK", "hypothesis", "verified", ["남아 있는 표식", "The mark remains"], NOTES.SELF_MARK_VERIFIED, "The same mark remains. The room's physical state returns to the beginning, but the notebook keeps its records.", ["CH1_SELF_MARK"])
	for owner in ["EDGAR", "LUCA", "MARA1", "MARA2"]:
		var names := {"EDGAR": ["에드가의 업무 장부", "Edgar's work ledger"], "LUCA": ["루카의 전달 쪽지", "Luca's delivery note"], "MARA1": ["마라 1의 청소 기록", "Mara 1's cleaning record"], "MARA2": ["마라 2의 반출 기록", "Mara 2's checkout record"]}
		_resource("B1_" + owner, "B1_" + owner.to_lower(), "B1", "CH1_SCHEDULE_" + owner, "document", "observed", names[owner], "CH1_B1_TEXT_" + owner)
	_resource("B1", "B1", "B1", "CH1_LIBRARY_WINDOW", "hypothesis", "verified", ["기록 내실이 비는 시간", "When the inner library is empty"], "CH1_B1_SOLVED", ["CH1_SCHEDULE_EDGAR", "CH1_SCHEDULE_LUCA", "CH1_SCHEDULE_MARA1", "CH1_SCHEDULE_MARA2"])
	_resource("J1", "J1", "J1", "CH1_J1", "journal", "observed", ["일지 첫 페이지", "The first journal page"], "CH1_J1_RESTORED", [], "unverified")
	var clock_names := {"BEDROOM": ["침실 시계 탁본", "Bedroom clock rubbing"], "PARLOR": ["대응접실 시계 탁본", "Parlor clock rubbing"], "LIBRARY_OUTER": ["외부 서고 시계 탁본", "Outer-library clock rubbing"], "GREAT_CLOCK": ["서쪽 대시계 탁본", "Western clock rubbing"]}
	for clock in clock_names:
		_resource("CLOCK_" + clock, "CLOCK_" + clock.to_lower(), "B3_A", "CH1_CLOCK_" + clock, "observation", "observed", clock_names[clock], "CH1_CLOCK_" + clock, ["CH1_J1"])
	_add("B3_A", "B3_A", "B3_A", "CH1_CLOCK_LAYOUT", "hypothesis", "verified", ["시계망 배선 검증", "Verified clock-network wiring"], FEEDBACK.FIXED.LAYOUT_SOLVED, DISPLAY.feedback(FEEDBACK.FIXED.LAYOUT_SOLVED, "en-US"), ["CH1_CLOCK_BEDROOM", "CH1_CLOCK_PARLOR", "CH1_CLOCK_LIBRARY_OUTER", "CH1_CLOCK_GREAT_CLOCK"])
	for category in ["REFERENCE", "RELAY", "OUTPUT", "EXCLUDED", "PHASE_TOO_EARLY", "PHASE_SIMULTANEOUS", "PHASE_BETWEEN", "PHASE_UNSET"]:
		_resource("BF_" + category, "BF", "B3_B", "CH1_CLOCK_FAILURE", "failure", "observed", ["시계망 작동 실패", "A failed clock-network activation"], "CH1_CLOCK_FAILURE_" + category + "_NOTE", ["CH1_CLOCK_LAYOUT", "CH1_CLOCK_FAILURE"])
		contents["NB_CH1_NOTE_BF_" + category]["1"].new_attempt = true
	_resource("B4", "B4", "B4", "CH1_WAVEFORM", "observation", "observed", ["열세 번째 소리의 파형", "The waveform of the thirteenth sound"], "CH1_B4_RECORDED", ["CH1_CLOCK_LAYOUT", "CH1_CLOCK_FAILURE"])
	_add("BF_RESOLVED", "", "B4", "CH1_CLOCK_FAILURE", "failure", "observed", ["시계망의 재작동", "The clock network works again"], NOTES.FAILURE_RESOLVED, "I recorded the clock-network signal as a waveform. I will keep the previous diagnosis and the record of the bent pin.", ["CH1_CLOCK_FAILURE", "CH1_WAVEFORM"])
	_resource("J2", "J2", "J2", "CH1_J2", "journal", "observed", ["일지 두 번째 페이지", "The second journal page"], "CH1_J2_RESTORED", ["CH1_J1", "CH1_WAVEFORM"], "unverified")
	if contents.size() != 26:
		push_error("Incomplete chapter-one notes catalog.")
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_CHAPTER_ONE_NOTES_SEED: ", contents.size())
	quit()


func _resource(id: String, legacy: String, event: String, knowledge: String, category: String, status: String, titles: Array, text_id: String, sources: Array = [], provenance: String = "identified") -> void:
	_add(id, legacy, event, knowledge, category, status, titles, TEXT.localized_text["ko-KR"][text_id], TEXT.localized_text["en-US"][text_id], sources, provenance)
	contents["NB_CH1_NOTE_" + id]["1"].source_text_id = text_id
	contents["NB_CH1_NOTE_" + id]["1"].text_source = TEXT.resource_path


func _add(id: String, legacy: String, event: String, knowledge: String, category: String, status: String, titles: Array, ko: String, en: String, sources: Array = [], provenance: String = "identified") -> void:
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	contents["NB_CH1_NOTE_" + id] = {"1": {
		"producer_id": "NP06", "source_file": "scripts/systems/chapter_one_session.gd", "source_symbol": "act/_write_note:" + id,
		"event_id": event, "node_ids": nodes, "action_or_variant": "recorded", "speaker_id": "SUBJECT", "location_source": "history_context:captured_before_commit",
		"entry_kind": "document_segment", "disclosure_owner": "event_note_commit", "mapping_status": "AUTHORED_ID", "owner": "planning/engineering",
		"visible_segment_ids": ["body"], "protection_reasons": ["knowledge"], "localization_keys": {"body": "NB_CH1_NOTE_" + id}, "variables": {"body": {}},
		"locales": {"ko-KR": {"title": titles[0], "summary": titles[0], "speaker": "수첩", "body": ko}, "en-US": {"title": titles[1], "summary": titles[1], "speaker": "Notebook", "body": en}},
		"knowledge": {"knowledge_id": knowledge, "category": category, "epistemic_state": status, "provenance_state": provenance, "lifetime": "persistent"},
		"source_knowledge_ids": sources, "legacy_key": legacy,
	}}
