extends SceneTree

const NOTES := preload("res://scripts/systems/journal_four_notebook.gd")
const DISPLAY := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")


func _initialize() -> void:
	var path := "res://data/notebook/journal_four_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var row := {
		"producer_id": "NP15", "source_file": "scripts/systems/journal_four.gd", "source_symbol": "apply.read",
		"event_id": "J4", "node_ids": ["J4"], "action_or_variant": "restored", "speaker_id": "SUBJECT",
		"location_source": "captured_before_commit", "entry_kind": "document_segment", "disclosure_owner": "event_note_commit",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": ["clue_source"],
		"localization_keys": {}, "variables": {}, "original_only_segments": [], "source_content_ids": [],
		"knowledge": {"knowledge_id": "J4", "category": "journal", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"},
		"locales": {"ko-KR": {"speaker": "수첩", "title": "네 번째 일지 · 약속과 권한", "summary": "복원한 일지와 획득한 기록의 인용"}, "en-US": {"speaker": "Notebook", "title": "Journal IV · Promises and Authority", "summary": "The restored journal and quotations from acquired records"}},
	}
	var body: String = NOTES.RULES.INDEX_TEXT + "\n\n" + NOTES.RULES.BASE_TEXT
	_segment(row, "body", body, DISPLAY.text(body, "en-US"))
	for owner in NOTES.RULES.OWNERS:
		for id in NOTES.QUOTES[owner]:
			var source := CONTENT.definition(id, 1)
			if source.is_empty():
				push_error("Missing frozen researcher source: " + id)
				quit(1)
				return
			_segment(row, NOTES.QUOTES[owner][id], "\n" + source.locales["ko-KR"].body, "\n" + source.locales["en-US"].body)
			row.source_content_ids.append(id)
		var original: String = owner + "_original"
		_segment(row, original, "\n{original_text}", "\n{original_text}")
		row.variables[original] = {"original_text": "string"}
		row.original_only_segments.append(original)
		var key := "REC_" + String(owner).to_upper()
		_segment(row, owner + "_index", "\n" + key + " · 획득한 기록 인덱스", "\n" + key + " · Acquired Record Index")
	_segment(row, "full", "\n" + NOTES.RULES.FULL_TEXT, "\n" + DISPLAY.text(NOTES.RULES.FULL_TEXT, "en-US"))
	_segment(row, "last", "\n" + NOTES.RULES.LAST_TEXT, "\n" + DISPLAY.text(NOTES.RULES.LAST_TEXT, "en-US"))
	if not CONTENT._valid_row(row):
		push_error("Invalid composed J4 catalog")
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": {NOTES.ID: {"1": row}}}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_J4_SEED: 1 ID / 19 conditional segments")
	quit()


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = NOTES.ID + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en
