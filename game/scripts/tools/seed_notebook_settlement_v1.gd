extends SceneTree

const NOTES := preload("res://scripts/systems/settlement_notebook.gd")
const DISPLAY := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var failed := false


func _initialize() -> void:
	var path := "res://data/notebook/settlement_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var contents := {}
	for key in NOTES.authored_rows():
		var source: Dictionary = NOTES.authored_rows()[key]
		var row := _base(key, source.kind, source.variant)
		var note: bool = source.variant == "recorded"
		var spoken: bool = source.kind == "dialogue"
		row.speaker_id = "SUBJECT" if spoken or note else "SYSTEM"
		row.disclosure_owner = "event_note_commit" if note else "actual_display"
		row.protection_reasons = ["clue_source"]
		var ko: String = source.text
		var en := DISPLAY.text(ko, "en-US")
		if ko == en:
			failed = true
			push_error("Missing translation: " + key)
		var ko_parts: PackedStringArray = ko.split("\n", false) if spoken else PackedStringArray([ko])
		var en_parts: PackedStringArray = en.split("\n", false) if spoken else PackedStringArray([en])
		if ko_parts.size() != en_parts.size():
			failed = true
			continue
		for locale in row.locales:
			row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale) if spoken else ("수첩" if locale == "ko-KR" else "Notebook") if note else ("장면" if locale == "ko-KR" else "Scene")
		for index in range(ko_parts.size()):
			_segment(row, "line_%02d" % (index + 1) if spoken else "body", ko_parts[index], en_parts[index])
		if note:
			row.knowledge = {"knowledge_id": "MARA2_NAME", "category": "person", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"}
			row.source_knowledge_ids = ["REC_MARA2"]
			row.source_content_ids = [NOTES.PREFIX + "SCREEN_MARA2", NOTES.PREFIX + "MARA2_OPTIONS", NOTES.PREFIX + "MARA2_SELECT_0"]
		contents[NOTES.PREFIX + key] = {"1": row}
	for group in NOTES.CHOICES:
		_choices(contents, group, NOTES.CHOICES[group], {})
	for group in NOTES.MODALS:
		_choices(contents, group, NOTES.MODALS[group].labels, NOTES.MODALS[group])
	if failed or contents.size() != 75:
		push_error("Invalid settlement catalog: %d" % contents.size())
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_SETTLEMENT_SEED: 75")
	quit()


func _choices(contents: Dictionary, group: String, labels: Array, modal: Dictionary) -> void:
	var row := _base(group + "_OPTIONS", "options_presented", "shown")
	row.source_file = "scripts/chapters/basement_controller.gd"
	row.protection_reasons = ["choice_context"]
	if not modal.is_empty():
		row.choices = []
		row.cancel_index = 0
		_segment(row, "header", modal.title, DISPLAY.text(modal.title, "en-US"))
		_segment(row, "body", modal.body, DISPLAY.text(modal.body, "en-US"))
	for locale in row.locales: row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	for index in range(labels.size()):
		var label: String = labels[index]
		_segment(row, "option_%d" % index, label, DISPLAY.text(label, "en-US"))
		var key := group + "_SELECT_%d" % index
		var cancelled := not modal.is_empty() and index == 0
		if not modal.is_empty(): row.choices.append({"content_id": NOTES.PREFIX + key, "kind": "cancel" if cancelled else "confirm"})
		var selected := _base(key, "choice_cancelled" if cancelled else "choice_confirmed", "option_%d" % index)
		selected.source_file = row.source_file
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", label, DISPLAY.text(label, "en-US"))
		contents[NOTES.PREFIX + key] = {"1": selected}
	row.default_segments = row.visible_segment_ids.duplicate()
	contents[NOTES.PREFIX + group + "_OPTIONS"] = {"1": row}


func _base(key: String, kind: String, variant: String) -> Dictionary:
	var event: String = NOTES.event_for(key)
	var ko := "마지막 저녁의 기록" if event == "E5" else "코어 문턱의 기록"
	var en := "Records of the Last Evening" if event == "E5" else "Records at the Core Threshold"
	if key == "NAME_RECORD":
		ko = "적어 둔 이름"
		en = "The Name I Wrote Down"
	return {"producer_id": "NP15", "source_file": "scripts/systems/last_evening.gd" if event == "E5" else "scripts/systems/core_approach.gd",
		"source_symbol": key, "event_id": event, "node_ids": [NOTES.node_for(key)], "action_or_variant": variant, "speaker_id": "SYSTEM",
		"location_source": "captured_before_commit_or_actual_display", "entry_kind": kind, "disclosure_owner": "actual_display",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": [],
		"localization_keys": {}, "variables": {}, "locales": {"ko-KR": {"speaker": "", "title": ko, "summary": ko}, "en-US": {"speaker": "", "title": en, "summary": en}}}


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
