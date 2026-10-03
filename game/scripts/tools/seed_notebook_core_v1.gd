extends SceneTree

const NOTES := preload("res://scripts/systems/core_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
var failed := false
var contents := {}


func _initialize() -> void:
	var path := "res://data/notebook/core_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var specs := NOTES.rows()
	var enums := NOTES.enums()
	for key in specs:
		var spec: Dictionary = specs[key]
		var row := _base(key, "dialogue" if spec.spoken else "document_segment")
		if spec.has("knowledge_id"):
			row.disclosure_owner = "event_note_commit"
			row.action_or_variant = "recorded"
			row.knowledge = {"knowledge_id":spec.knowledge_id, "category":"person" if key == "D_INDEX_RECORD" else "document", "epistemic_state":"observed", "provenance_state":"identified", "lifetime":"persistent"}
			row.source_knowledge_ids = spec.source_knowledge_ids
			row.source_content_ids = spec.source_content_ids
			row.protection_reasons = ["knowledge"]
		if spec.has("visual"): row.visual = spec.visual.duplicate(true)
		if spec.get("original_only", false): row.original_only_segments = ["body"]
		for locale in row.locales:
			row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale) if spec.spoken else ("수첩" if locale == "ko-KR" else "Notebook") if spec.has("knowledge_id") else ("장면" if locale == "ko-KR" else "Scene")
		row.speaker_id = "SUBJECT" if spec.spoken else "SYSTEM"
		var left: PackedStringArray = String(spec.ko).split("\n", false) if spec.spoken else PackedStringArray([spec.ko])
		var right: PackedStringArray = String(spec.en).split("\n", false) if spec.spoken else PackedStringArray([spec.en])
		if left.size() != right.size():
			failed = true
			push_error("Core paragraph mismatch: " + key)
			continue
		for index in range(left.size()):
			var variables := {}
			for name in spec.vars:
				if left[index].contains("{" + name + "}"): variables[name] = spec.vars[name]
			_segment(row, "line_%02d" % (index + 1) if spec.spoken else "body", left[index], right[index], variables)
		row.enums = {}
		for type in spec.vars.values():
			if String(type).begins_with("enum:"): row.enums[String(type).trim_prefix("enum:")] = enums[String(type).trim_prefix("enum:")]
		contents[NOTES.PREFIX + key] = {"1":row}
	_choices("E_AUTHOR", NOTES.OWNERS)
	_choices("E_INTENT", NOTES.INTENTS)
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not CONTENT._valid_row(row):
			failed = true
			push_error("Invalid core row: " + id)
		var regex := RegEx.create_from_string("[가-힣]")
		if not row.get("original_only_segments", []).is_empty(): pass
		else:
			for segment in row.visible_segment_ids:
				if regex.search(row.locales["en-US"][segment]) != null:
					failed = true
					push_error("Untranslated core row: " + id + ":" + segment)
		count += row.visible_segment_ids.size()
	if failed:
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1, "contents":contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_CORE_SEED: %d IDs / %d segments" % [contents.size(), count])
	quit()


func _choices(group: String, values: Array) -> void:
	var options := _base(group + "_OPTIONS", "options_presented")
	options.protection_reasons = ["choice_context"]
	for locale in options.locales: options.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	for index in range(values.size()):
		var value: String = values[index]
		var ko: String = NOTES.DISPLAY.UI["author_" + value][0] if group == "E_AUTHOR" else NOTES.E.INTENTS[value]
		var en: String = NOTES.DISPLAY.UI["author_" + value][1] if group == "E_AUTHOR" else NOTES.DISPLAY.INTENTS_EN[value]
		_segment(options, "option_%d" % index, ko, en)
		var key := group + "_SELECT_%d" % index
		var selected := _base(key, "choice_confirmed")
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", ko, en)
		contents[NOTES.PREFIX + key] = {"1":selected}
	contents[NOTES.PREFIX + group + "_OPTIONS"] = {"1":options}


func _base(key: String, kind: String) -> Dictionary:
	var event := NOTES.event_for(key)
	return {"producer_id":"NP16", "source_file":"scripts/chapters/basement_controller.gd", "source_symbol":key,
		"event_id":event, "node_ids":[event], "action_or_variant":key, "speaker_id":"SYSTEM", "location_source":"captured_before_commit_or_actual_display",
		"entry_kind":kind, "disclosure_owner":"actual_display", "mapping_status":"AUTHORED_ID", "owner":"planning/engineering",
		"visible_segment_ids":[], "variables":{}, "localization_keys":{}, "protection_reasons":["clue_source"],
		"locales":{"ko-KR":{"speaker":"", "title":"코어에서 확인한 자료", "summary":"표시된 자료와 당시의 응답"}, "en-US":{"speaker":"", "title":"Evidence Observed at the Core", "summary":"The displayed evidence and response at that time"}}}


func _segment(row: Dictionary, id: String, ko: String, en: String, variables: Dictionary = {}) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = variables
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
