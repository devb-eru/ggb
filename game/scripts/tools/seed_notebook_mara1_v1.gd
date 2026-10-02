extends SceneTree

const OUTPUT := "res://data/notebook/mara1_v1.json"
const NOTES := preload("res://scripts/systems/mara1_notebook.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const SPEAKERS := preload("res://data/dialogue/prologue/prologue_text.tres")


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var contents := {}
	var sources := NOTES.authored_rows()
	for key in sources:
		var source: Dictionary = sources[key]
		var note: bool = source.variant == "recorded"
		var spoken: bool = source.kind == "dialogue"
		var ko: String = source.text
		var en := DISPLAY.text(ko, "en-US")
		if ko == en:
			push_error("Missing Mara 1 translation: " + key)
			quit(1)
			return
		var row := {"producer_id": "NP10", "source_file": "scripts/systems/mara1_relationship.gd", "source_symbol": key,
			"event_id": "E3_1", "node_ids": ["E3_1"], "action_or_variant": source.variant,
			"speaker_id": "SUBJECT" if spoken or note else "SYSTEM", "location_source": "captured_before_commit_or_actual_display", "entry_kind": source.kind,
			"disclosure_owner": "event_note_commit" if note else "actual_display", "mapping_status": "AUTHORED_ID", "owner": "planning/engineering",
			"visible_segment_ids": [], "protection_reasons": ["relationship_record" if note else "clue_source"], "localization_keys": {}, "variables": {}, "locales": {}}
		if key in ["CLEAR"]: row.protection_reasons = []
		var ko_parts: PackedStringArray = ko.split("\n", false) if spoken else PackedStringArray([ko])
		var en_parts: PackedStringArray = en.split("\n", false) if spoken else PackedStringArray([en])
		if ko_parts.size() != en_parts.size():
			push_error("Mara 1 segment mismatch: " + key)
			quit(1)
			return
		for language in ["ko-KR", "en-US"]:
			var speaker: String = SPEAKERS.localized_text[language].UI_SPEAKER_SUBJECT if spoken else ("수첩" if language == "ko-KR" else "Notebook") if note else ("장면" if language == "ko-KR" else "Scene")
			row.locales[language] = {"speaker": speaker, "title": source.titles[0 if language == "ko-KR" else 1], "summary": source.titles[0 if language == "ko-KR" else 1]}
		for index in range(ko_parts.size()):
			var segment := "line_%02d" % (index + 1) if spoken else "body"
			row.visible_segment_ids.append(segment)
			row.variables[segment] = {}
			row.localization_keys[segment] = key + ":" + segment
			row.locales["ko-KR"][segment] = ko_parts[index]
			row.locales["en-US"][segment] = en_parts[index]
		if note:
			row.knowledge = {"knowledge_id": "REC_MARA1", "category": "document", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"}
			row.source_knowledge_ids = ["FRACTURE_REPORT"]
			row.source_content_ids = ["NB_MARA1_CONFESS", "NB_MARA1_RESTORE", "NB_MODAL_MARA1_SELECT_" + ("1" if key.ends_with("ORIGINAL_ATTRIBUTION") else "2")]
			for log_id in NOTES.RULES.LOGS:
				row.source_content_ids.append("NB_MARA1_LOG_" + String(log_id).to_upper())
				row.source_content_ids.append("NB_MARA1_SCREEN_LOG_" + String(log_id).to_upper())
		contents[NOTES.PREFIX + key] = {"1": row}
	if contents.size() != 27:
		push_error("Unexpected Mara 1 catalog size: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_MARA1_SEED: ", contents.size())
	quit()
