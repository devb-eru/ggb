extends SceneTree

const OUTPUT := "res://data/notebook/prologue_notes_v1.json"
const TEXTS := preload("res://data/dialogue/prologue/prologue_text.tres")
const NOTES := [
	["DUTIES", "P1", "_load_progress", "오늘의 일과", "Today's duties"],
	["IMPRESSIONS", "P1", "_inspect_bedroom", "종이에 남은 필압", "Impressions in the paper"],
	["BIRD", "P2", "_apply_window_tool", "반복되는 궤도", "A repeating flight path"],
	["WINDOWS", "P2", "_complete_p2", "창문을 닦은 뒤", "After cleaning the windows"],
	["JOURNAL", "P3", "_on_shelf_pressed", "장부 속 낙서", "The sketch in the ledger"],
	["SIGNATURES", "P3B", "_on_portrait_pressed", "다섯 문양", "Five patterns"],
	["PULSE", "P4", "_record_p4_life_support_pulse", "주방의 규칙적인 진동", "The kitchen's rhythmic vibration"],
	["WEATHER", "P5", "_complete_p5", "서로 다른 날씨", "Different weather"],
	["SLEEP", "P6", "_begin_first_sleep", "오늘의 끝", "The end of today"],
]


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-source-project="):
			var path := argument.trim_prefix("--verify-source-project=").path_join("data/dialogue/prologue/prologue_text.tres")
			var source := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if source == null or source.localized_text != TEXTS.localized_text:
				push_error("Source prologue text differs.")
				quit(1)
				return
	var contents := {}
	for spec in NOTES:
		var id: String = "NOTE_P_" + spec[0]
		var locales := {}
		for index in range(2):
			var locale: String = ["ko-KR", "en-US"][index]
			var body: String = TEXTS.localized_text[locale][id]
			locales[locale] = {"title": spec[3 + index], "summary": body, "speaker": "수첩" if index == 0 else "Notebook", "body": body}
		contents["NB_" + id] = {"1": {
			"producer_id": "NP03", "source_file": "game/scripts/prologue/prologue_controller.gd", "source_symbol": spec[2],
			"source_text_id": id, "text_source": TEXTS.resource_path, "event_id": spec[1], "node_ids": [spec[1]],
			"action_or_variant": "recorded", "speaker_id": "SUBJECT", "location_source": "event_current_room",
			"entry_kind": "document_segment", "disclosure_owner": "event_note_commit", "mapping_status": "AUTHORED_ID",
			"owner": "planning/engineering", "visible_segment_ids": ["body"], "protection_reasons": ["knowledge"],
			"localization_keys": {"body": id}, "variables": {"body": {}}, "locales": locales,
			"knowledge": {"knowledge_id": id, "category": "observation", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"},
		}}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_PROLOGUE_NOTES_SEED: ", contents.size())
	quit()
