class_name DialogueRepository
extends RefCounted

const TEXT_REGISTRY := "res://data/registries/text_registry.json"
const TEXT_CATALOG := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const VARIABLE_TYPES := {
	"string": TYPE_STRING,
	"int": TYPE_INT,
	"float": TYPE_FLOAT,
	"bool": TYPE_BOOL,
}

var _entries: Dictionary = {}
var _localized_text: Dictionary = {}
var _supported_locales: Array[String] = []
var _fallback_locale := "ko-KR"
var _errors := PackedStringArray()


func _init() -> void:
	_load_registry()
	if _errors.is_empty():
		_load_sources()
	if _errors.is_empty():
		_validate_parity()


func is_ready() -> bool:
	return _errors.is_empty()


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_supported_locales() -> Array[String]:
	return _supported_locales.duplicate()


func get_text(line_id: StringName, locale: String, variables: Dictionary = {}) -> String:
	var id := String(line_id)
	if not is_ready() or not _entries.has(id):
		return "[%s]" % id
	var resolved_locale := _normalize_locale(locale)
	var locale_table: Dictionary = _localized_text.get(resolved_locale, {})
	if not locale_table.has(id):
		locale_table = _localized_text.get(_fallback_locale, {})
	if not locale_table.has(id):
		return "[%s]" % id
	var definition: Dictionary = _entries[id]
	var variable_specs: Dictionary = definition.get("variables", {})
	if not _variables_match(variable_specs, variables):
		return "[%s:ERR_TEXT_VARIABLES]" % id
	var rendered := String(locale_table[id])
	for variable_name in variable_specs.keys():
		var variable_value: Variant = variables[variable_name]
		if String(variable_specs[variable_name]) == "int":
			variable_value = int(variable_value)
		rendered = rendered.replace("{%s}" % variable_name, str(variable_value))
	return rendered


func render_history(history_value: Variant, locale: String) -> Dictionary:
	var errors := PackedStringArray()
	var rendered_entries: Array = []
	if not history_value is Dictionary or not history_value.get("entries") is Array:
		return {"ok": false, "entries": rendered_entries, "error_ids": PackedStringArray(["ERR_DIALOGUE_HISTORY_TYPE"])}
	for history_entry_value in history_value["entries"]:
		if not history_entry_value is Dictionary:
			errors.append("ERR_DIALOGUE_HISTORY_ENTRY_TYPE")
			continue
		var history_entry: Dictionary = history_entry_value
		var line_id := String(history_entry.get("line_id", ""))
		if not _entries.has(line_id):
			errors.append("ERR_DIALOGUE_HISTORY_LINE_ID")
			continue
		var definition: Dictionary = _entries[line_id]
		if String(history_entry.get("speaker_id", "")) != String(definition.get("speaker_id", "")):
			errors.append("ERR_DIALOGUE_HISTORY_SPEAKER_ID")
			continue
		rendered_entries.append({
			"sequence": int(history_entry.get("sequence", -1)),
			"line_id": line_id,
			"speaker_id": String(definition["speaker_id"]),
			"text": get_text(StringName(line_id), locale, history_entry.get("variables", {})),
		})
	return {"ok": errors.is_empty(), "entries": rendered_entries, "error_ids": errors}


func _load_registry() -> void:
	var file := FileAccess.open(TEXT_REGISTRY, FileAccess.READ)
	if file == null:
		_errors.append("ERR_TEXT_REGISTRY_MISSING")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("schema_version", -1)) != 1:
		_errors.append("ERR_TEXT_REGISTRY_INVALID")
		return
	if not parsed.get("entries") is Dictionary or not parsed.get("supported_locales") is Array:
		_errors.append("ERR_TEXT_REGISTRY_INVALID")
		return
	_entries = parsed["entries"].duplicate(true)
	_fallback_locale = String(parsed.get("fallback_locale", "ko-KR"))
	for locale_value in parsed["supported_locales"]:
		var locale := String(locale_value)
		if locale.is_empty() or locale in _supported_locales:
			_errors.append("ERR_TEXT_LOCALE_REGISTRY")
			continue
		_supported_locales.append(locale)
		_localized_text[locale] = {}
	if _fallback_locale not in _supported_locales:
		_errors.append("ERR_TEXT_FALLBACK_LOCALE")
	for line_id in _entries.keys():
		var definition: Variant = _entries[line_id]
		if not definition is Dictionary or String(definition.get("speaker_id", "")).is_empty():
			_errors.append("ERR_TEXT_ENTRY_INVALID")
			continue
		if not definition.get("variables", {}) is Dictionary:
			_errors.append("ERR_TEXT_VARIABLE_SPEC")
			continue
		for type_name in definition.get("variables", {}).values():
			if String(type_name) not in VARIABLE_TYPES:
				_errors.append("ERR_TEXT_VARIABLE_TYPE")


func _load_sources() -> void:
	if TEXT_CATALOG == null or TEXT_CATALOG.schema_version != 1:
		_errors.append("ERR_TEXT_SOURCE_INVALID")
		return
	for locale in _supported_locales:
		var source_locale: Variant = TEXT_CATALOG.localized_text.get(locale)
		if not source_locale is Dictionary:
			_errors.append("ERR_TEXT_SOURCE_LOCALE_MISSING")
			continue
		var locale_table: Dictionary = _localized_text[locale]
		for line_id in source_locale.keys():
			if not _entries.has(line_id):
				_errors.append("ERR_TEXT_SOURCE_UNKNOWN_ID")
				continue
			if locale_table.has(line_id):
				_errors.append("ERR_TEXT_SOURCE_DUPLICATE_ID")
				continue
			locale_table[String(line_id)] = String(source_locale[line_id])


func _validate_parity() -> void:
	for line_id in _entries.keys():
		var definition: Dictionary = _entries[line_id]
		var expected_placeholders: Array = definition.get("variables", {}).keys()
		expected_placeholders.sort()
		for locale in _supported_locales:
			var locale_table: Dictionary = _localized_text[locale]
			if not locale_table.has(line_id) or String(locale_table[line_id]).is_empty():
				_errors.append("ERR_TEXT_TRANSLATION_MISSING")
				continue
			var actual_placeholders := _extract_placeholders(String(locale_table[line_id]))
			if actual_placeholders != expected_placeholders:
				_errors.append("ERR_TEXT_PLACEHOLDER_PARITY")


func _extract_placeholders(text: String) -> Array:
	var found := {}
	var regex := RegEx.new()
	if regex.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}") != OK:
		return []
	for match_result in regex.search_all(text):
		found[match_result.get_string(1)] = true
	var names: Array = found.keys()
	names.sort()
	return names


func _variables_match(specs: Dictionary, variables: Dictionary) -> bool:
	if specs.size() != variables.size():
		return false
	for variable_name in specs.keys():
		if not variables.has(variable_name):
			return false
		var expected_type := int(VARIABLE_TYPES[String(specs[variable_name])])
		var actual_type := typeof(variables[variable_name])
		if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
			if not is_equal_approx(float(variables[variable_name]), roundf(float(variables[variable_name]))):
				return false
		elif actual_type != expected_type:
			return false
	return true


func _normalize_locale(locale: String) -> String:
	if locale in _supported_locales:
		return locale
	if locale.begins_with("ko") and "ko-KR" in _supported_locales:
		return "ko-KR"
	if locale.begins_with("en") and "en-US" in _supported_locales:
		return "en-US"
	return _fallback_locale
