extends SceneTree

const OUTPUT := "res://data/notebook/iris_v1.json"
const NOTES := preload("res://scripts/systems/iris_notebook.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var contents := {}
var failed := false


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for key in NOTES.authored_rows():
		var source: Dictionary = NOTES.authored_rows()[key]
		var note: bool = source.variant == "recorded"
		var spoken: bool = source.kind == "dialogue"
		var row := _base(key, source.kind, source.variant, source.titles)
		row.speaker_id = "SUBJECT" if spoken or note else "SYSTEM"
		row.disclosure_owner = "event_note_commit" if note else "actual_display"
		row.protection_reasons = ["relationship_record" if note else "clue_source"] if key != "CLEAR" else []
		for locale in row.locales:
			row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale) if spoken else ("수첩" if locale == "ko-KR" else "Notebook") if note else ("장면" if locale == "ko-KR" else "Scene")
		var ko: String = source.text
		var en := DISPLAY.text(ko, "en-US")
		if ko == en: failed = true
		var ko_parts: PackedStringArray = ko.split("\n", false) if spoken else PackedStringArray([ko])
		var en_parts: PackedStringArray = en.split("\n", false) if spoken else PackedStringArray([en])
		if ko_parts.size() != en_parts.size():
			failed = true
			continue
		for index in range(ko_parts.size()):
			_segment(row, "line_%02d" % (index + 1) if spoken else "body", ko_parts[index], en_parts[index])
		if note:
			row.knowledge = {"knowledge_id": "REC_IRIS", "category": "document", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"}
			row.source_knowledge_ids = ["FRACTURE_REPORT"]
			row.source_content_ids = ["NB_IRIS_RESTORE", "NB_IRIS_AUDIT", "NB_IRIS_CONFRONT", "NB_MODAL_IRIS_SELECT_1", "NB_MODAL_IRIS_SELECT_2"]
			for log_id in NOTES.RULES.LOGS:
				row.source_content_ids.append("NB_IRIS_LOG_" + String(log_id).to_upper())
				row.source_content_ids.append("NB_IRIS_SCREEN_LOG_" + String(log_id).to_upper())
		contents[NOTES.PREFIX + key] = {"1": row}
	_channel_modal()
	if failed or contents.size() != 45:
		push_error("Invalid Iris catalog or missing translation: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_IRIS_SEED: ", contents.size())
	quit()


func _base(key: String, kind: String, variant: String, titles: Array) -> Dictionary:
	return {"producer_id": "NP11", "source_file": "scripts/systems/iris_relationship.gd", "source_symbol": key,
		"event_id": "E3_2", "node_ids": ["E3_2"], "action_or_variant": variant, "speaker_id": "SYSTEM",
		"location_source": "captured_before_commit_or_actual_display", "entry_kind": kind, "disclosure_owner": "actual_display",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": [], "localization_keys": {}, "variables": {},
		"locales": {"ko-KR": {"speaker": "", "title": titles[0], "summary": titles[0]}, "en-US": {"speaker": "", "title": titles[1], "summary": titles[1]}}}


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _channel_modal() -> void:
	var titles := ["계절 입력 출처 대조", "Comparing Seasonal Input Sources"]
	var row := _base("CHANNEL_OPTIONS", "options_presented", "shown", titles)
	row.source_file = "scripts/chapters/basement_controller.gd"
	row.source_symbol = "_show_iris_channel"
	row.protection_reasons = ["choice_context"]
	row.choices = []
	row.cancel_index = 0
	for locale in row.locales: row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	_segment(row, "header", NOTES.CHANNEL_TITLE, DISPLAY.text(NOTES.CHANNEL_TITLE, "en-US"))
	_segment(row, "body", NOTES.CHANNEL_BODY, DISPLAY.text(NOTES.CHANNEL_BODY, "en-US"))
	for index in range(NOTES.CHANNEL_LABELS.size()):
		var label: String = NOTES.CHANNEL_LABELS[index]
		var id := NOTES.PREFIX + "CHANNEL_SELECT_%d" % index
		_segment(row, "option_%d" % index, label, DISPLAY.text(label, "en-US"))
		row.choices.append({"content_id": id, "kind": "cancel" if index == 0 else "confirm"})
		var selected := _base("CHANNEL_SELECT_%d" % index, "choice_cancelled" if index == 0 else "choice_confirmed", "option_%d" % index, titles)
		selected.source_file = row.source_file
		selected.source_symbol = row.source_symbol
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", label, DISPLAY.text(label, "en-US"))
		contents[id] = {"1": selected}
	row.default_segments = row.visible_segment_ids.duplicate()
	contents[NOTES.PREFIX + "CHANNEL_OPTIONS"] = {"1": row}


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
