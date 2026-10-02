extends SceneTree

const EDGAR := preload("res://scripts/systems/edgar_notebook.gd")
const MARA2 := preload("res://scripts/systems/mara2_notebook.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var failed := false
var producer := ""
var event := ""
var source_file := ""
var prefix := ""


func _initialize() -> void:
	var outputs := ["res://data/notebook/edgar_v1.json", "res://data/notebook/mara2_v1.json"]
	for path in outputs:
		if FileAccess.file_exists(path):
			push_error("Refusing to overwrite a frozen notebook content version.")
			quit(1)
			return
	var catalogs := [
		_build(EDGAR, "NP13", "E3_4", "edgar_relationship.gd"),
		_build(MARA2, "NP14", "E3_5", "mara2_relationship.gd"),
	]
	if failed or catalogs[0].size() != 45 or catalogs[1].size() != 103:
		push_error("Invalid authority/archive catalogs: %d / %d" % [catalogs[0].size(), catalogs[1].size()])
		quit(1)
		return
	for index in range(2):
		var file := FileAccess.open(outputs[index], FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify({"format_version": 1, "contents": catalogs[index]}, "\t", true) + "\n")
		file.close()
	print("NOTEBOOK_AUTHORITY_ARCHIVE_SEED: 45 / 103")
	quit()


func _build(notes: Script, producer_id: String, event_id: String, filename: String) -> Dictionary:
	producer = producer_id
	event = event_id
	source_file = "scripts/systems/" + filename
	prefix = notes.PREFIX
	var contents := {}
	var sources: Dictionary = notes.authored_rows()
	for key in sources:
		var source: Dictionary = sources[key]
		var note: bool = source.variant == "recorded"
		var spoken: bool = source.kind == "dialogue"
		var row := _base(key, source.kind, source.variant, source.titles)
		row.speaker_id = "SUBJECT" if spoken or note else "SYSTEM"
		row.disclosure_owner = "event_note_commit" if note else "actual_display"
		row.protection_reasons = [] if key in ["CLEAR", "OWNER", "PORTRAIT", "ALIGN", "CELL"] else ["relationship_record" if note else "clue_source"]
		for locale in row.locales:
			row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale) if spoken else ("수첩" if locale == "ko-KR" else "Notebook") if note else ("장면" if locale == "ko-KR" else "Scene")
		var ko: String = source.text
		var en := DISPLAY.text(ko, "en-US")
		if ko == en:
			failed = true
			push_error("Missing translation: " + prefix + key)
		var ko_parts: PackedStringArray = ko.split("\n", false) if spoken else PackedStringArray([ko])
		var en_parts: PackedStringArray = en.split("\n", false) if spoken else PackedStringArray([en])
		if ko_parts.size() != en_parts.size():
			failed = true
			continue
		for index in range(ko_parts.size()):
			_segment(row, "line_%02d" % (index + 1) if spoken else "body", ko_parts[index], en_parts[index])
		if source.has("variables"): row.variables = source.variables.duplicate(true)
		if note:
			row.knowledge = {"knowledge_id": "REC_EDGAR" if producer == "NP13" else "REC_MARA2", "category": "document", "epistemic_state": "observed", "provenance_state": "identified", "lifetime": "persistent"}
			row.source_knowledge_ids = ["FRACTURE_REPORT"]
			row.source_content_ids = notes.source_ids()
		contents[prefix + key] = {"1": row}
	var modals: Dictionary = notes.modal_rows()
	for key in modals: _modal(contents, key, modals[key])
	return contents


func _modal(contents: Dictionary, key: String, spec: Dictionary) -> void:
	var row := _base(key + "_OPTIONS", "options_presented", "shown", spec.titles)
	row.source_file = "scripts/chapters/basement_controller.gd"
	row.protection_reasons = ["choice_context"]
	row.choices = []
	row.cancel_index = 0
	for locale in row.locales: row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	_segment(row, "header", spec.title, DISPLAY.text(spec.title, "en-US"))
	_segment(row, "body", spec.body, DISPLAY.text(spec.body, "en-US"))
	for index in range(spec.labels.size()):
		var label: String = spec.labels[index]
		var selected_key: String = spec.choice_group + "_SELECT_%d" % index
		var id := prefix + selected_key
		_segment(row, "option_%d" % index, label, DISPLAY.text(label, "en-US"))
		row.choices.append({"content_id": id, "kind": "cancel" if index == 0 else "confirm"})
		var selected := _base(selected_key, "choice_cancelled" if index == 0 else "choice_confirmed", "option_%d" % index, spec.titles)
		selected.source_file = row.source_file
		selected.source_symbol = spec.choice_group
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", label, DISPLAY.text(label, "en-US"))
		# Shared labels retain the displayed modal's occurrence/session context.
		if contents.has(id) and contents[id]["1"] != selected: failed = true
		contents[id] = {"1": selected}
	row.default_segments = row.visible_segment_ids.duplicate()
	contents[prefix + key + "_OPTIONS"] = {"1": row}


func _base(key: String, kind: String, variant: String, titles: Array) -> Dictionary:
	return {"producer_id": producer, "source_file": source_file, "source_symbol": key,
		"event_id": event, "node_ids": [event], "action_or_variant": variant, "speaker_id": "SYSTEM",
		"location_source": "captured_before_commit_or_actual_display", "entry_kind": kind, "disclosure_owner": "actual_display",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": [], "localization_keys": {}, "variables": {},
		"locales": {"ko-KR": {"speaker": "", "title": titles[0], "summary": titles[0]}, "en-US": {"speaker": "", "title": titles[1], "summary": titles[1]}}}


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
