extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CATALOGS := ["res://data/notebook/hints_v1.json", "res://data/notebook/prologue_v1.json", "res://data/notebook/prologue_notes_v1.json", "res://data/notebook/chapter_one_v1.json", "res://data/notebook/chapter_one_notes_v1.json", "res://data/notebook/modals_v1.json", "res://data/notebook/mirror_v1.json"]
const ALIASES := {"BF": "B3_B", "CF": "C4", "DF": "D1"}
const TYPES := {"string": TYPE_STRING, "int": TYPE_INT, "float": TYPE_FLOAT, "bool": TYPE_BOOL}
static var _contents: Dictionary = {}
static var _errors := PackedStringArray()
static var _loaded := false


static func hint_descriptor(stage: String, level: int) -> Dictionary:
	if level < 0 or level >= 5: return {}
	var id := "NB_HINT_%s_H%d" % [ALIASES.get(stage, stage), level + 1]
	return descriptor(id, 1, {"body": {}})


static func descriptor(id: String, version: int, segments: Dictionary) -> Dictionary:
	var row := definition(id, version)
	if row.is_empty(): return {}
	return {"content_id": id, "content_version": version, "variant_id": row.action_or_variant, "segments": segments.duplicate(true)}


static func definition(id: String, version: int) -> Dictionary:
	_load()
	return _contents.get(id, {}).get(str(version), {}).duplicate(true)


static func diagnostics() -> Dictionary:
	_load()
	return {"ok": _errors.is_empty(), "error_ids": _errors.duplicate(), "content_ids": _contents.keys(), "authored_ids": _contents.size()}


static func observe(descriptor: Dictionary, context: Dictionary, speaker: String, text: String, locale: String, disclosure: String = "displayed") -> Dictionary:
	_load()
	if not _errors.is_empty(): return _error("NB_CONTENT_CATALOG")
	if not descriptor.get("content_id") is String or not descriptor.get("variant_id") is String or not _integer(descriptor.get("content_version")) or not descriptor.get("segments") is Dictionary:
		return _error("NB_CONTENT_DESCRIPTOR")
	var row := definition(descriptor.content_id, int(descriptor.content_version))
	if row.is_empty(): return _error("NB_CONTENT_VERSION_UNAVAILABLE")
	if disclosure not in ["displayed", "replay_committed"]: return _error("NB_CONTENT_DISCLOSURE")
	if disclosure == "replay_committed" and (row.disclosure_owner != "event_note_commit" or not row.has("knowledge")):
		return _error("NB_CONTENT_DISCLOSURE_OWNER")
	if descriptor.get("variant_id") != row.action_or_variant or context.get("node_id") not in row.node_ids:
		return _error("NB_CONTENT_CONTEXT")
	if context.get("chapter_id") not in preload("res://scripts/systems/dialogue_history_context.gd").CHAPTERS:
		return _error("NB_CONTENT_CHAPTER")
	if not context.get("location_id") is String or context.location_id.is_empty(): return _error("NB_CONTENT_LOCATION")
	var language := _locale(locale)
	if not row.locales.has(language) or speaker != row.locales[language].speaker: return _error("NB_CONTENT_SPEAKER")
	var segments: Array = []
	var paragraphs := PackedStringArray()
	for id in row.visible_segment_ids:
		if not descriptor.segments.has(id): continue
		var variables: Variant = descriptor.segments[id]
		if not _variables_match(row.variables[id], variables): return _error("NB_CONTENT_VARIABLES")
		var serialized := _serialized_variables(variables)
		var body := _substitute(row.locales[language][id], serialized, row.variables[id])
		segments.append({"segment_id": id, "disclosure": disclosure, "localization_key": row.localization_keys[id], "safe_variables": serialized, "captured_text": body, "viewed_locale": language})
		paragraphs.append(body)
	if segments.is_empty() or segments.size() != descriptor.segments.size(): return _error("NB_CONTENT_SEGMENT")
	if "\n".join(paragraphs) != text: return _error("NB_CONTENT_DISPLAY_MISMATCH")
	return {"ok": true, "observation": {
		"producer_id": row.producer_id, "event_id": row.event_id, "node_id": context.node_id, "location_id": context.location_id, "chapter_id": context.chapter_id,
		"event_occurrence_id": context.get("event_occurrence_id", ""), "conversation_session_id": context.get("conversation_session_id", ""), "presentation_token": context.get("presentation_token", ""),
		"entry_kind": row.entry_kind, "content_id": descriptor.content_id, "content_version": int(descriptor.content_version), "variant_id": descriptor.variant_id,
		"speaker_id": row.speaker_id, "segments": segments, "content_protection": row.protection_reasons.duplicate(),
	}}


static func render_entry(entry: Dictionary, locale: String) -> Dictionary:
	if entry.get("record_class") != "authored" or not entry.get("observation") is Dictionary: return _error("NB_CONTENT_ENTRY")
	var observation: Dictionary = entry.observation
	var valid := ARCHIVE.validate_observation(observation)
	if not valid.ok: return valid
	_load()
	var row := definition(observation.content_id, int(observation.content_version))
	var language := _locale(locale)
	var available: bool = not row.is_empty() and row.locales.has(language)
	if not row.is_empty() and not _matches_identity(row, observation): return _error("NB_CONTENT_IDENTITY")
	var rendered: Array = []
	var paragraphs := PackedStringArray()
	var used_fallback := false
	for segment in observation.segments:
		var id: String = segment.segment_id
		var body: String = segment.captured_text
		var fallback: bool = not available
		if not row.is_empty():
			if id not in row.visible_segment_ids or row.localization_keys[id] != segment.localization_key or not _variables_match(row.variables[id], segment.safe_variables):
				return _error("NB_CONTENT_SEGMENT_IDENTITY")
		if available:
			body = _substitute(row.locales[language][id], segment.safe_variables, row.variables[id])
		used_fallback = used_fallback or fallback
		rendered.append({"segment_id": id, "text": body, "fallback": fallback, "viewed_locale": segment.viewed_locale})
		paragraphs.append(body)
	var speaker: String = row.locales[language].speaker if available else ("당시 화자" if language == "ko-KR" else "Recorded speaker")
	var title: String = row.locales[language].title if available else ("보관된 기록" if language == "ko-KR" else "Archived record")
	var fallback_note := ""
	if used_fallback:
		fallback_note = "\n[당시 보관된 원문 · 번역할 내용 버전을 찾지 못했습니다.]" if language == "ko-KR" else "\n[Original recorded text; its translation version is unavailable.]"
	return {"ok": true, "entry": {
		"entry_uid": entry.get("entry_uid", ""), "sequence": int(entry.get("sequence", -1)), "chapter_id": observation.chapter_id,
		"line_id": observation.content_id, "content_version": int(observation.content_version), "speaker_id": observation.speaker_id,
		"entry_kind": observation.entry_kind, "title": title, "text": speaker + ": " + "\n".join(paragraphs) + fallback_note, "segments": rendered,
		"record_class": "authored", "fallback": used_fallback,
	}}


static func _matches_identity(row: Dictionary, observation: Dictionary) -> bool:
	return observation.producer_id == row.producer_id and observation.event_id == row.event_id and observation.node_id in row.node_ids and observation.entry_kind == row.entry_kind and observation.speaker_id == row.speaker_id and observation.variant_id == row.action_or_variant and observation.content_protection == row.protection_reasons


static func _load() -> void:
	if _loaded: return
	_loaded = true
	for path in CATALOGS:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or not _integer(data.get("format_version")) or int(data.format_version) != 1 or not data.get("contents") is Dictionary:
			_errors.append("NB_CATALOG_FORMAT")
			continue
		for id in data.contents:
			if not data.contents[id] is Dictionary:
				_errors.append("NB_CATALOG_VERSIONS")
				continue
			if not _contents.has(id): _contents[id] = {}
			for version in data.contents[id]:
				if not String(version).is_valid_int() or int(version) < 1 or _contents[id].has(version):
					_errors.append("NB_CATALOG_VERSION_DUPLICATE")
					continue
				var row: Variant = data.contents[id][version]
				if not _valid_row(row):
					_errors.append("NB_CATALOG_ROW:" + id + ":" + version)
					continue
				_contents[id][version] = row


static func _valid_row(row: Variant) -> bool:
	if not row is Dictionary: return false
	for field in ["producer_id", "source_file", "source_symbol", "event_id", "action_or_variant", "speaker_id", "location_source", "entry_kind", "disclosure_owner", "mapping_status", "owner"]:
		if not row.get(field) is String or row[field].is_empty(): return false
	if row.mapping_status != "AUTHORED_ID" or row.entry_kind not in ARCHIVE.KINDS: return false
	for field in ["node_ids", "visible_segment_ids", "protection_reasons"]:
		if not row.get(field) is Array: return false
		var seen := {}
		for value in row[field]:
			if not value is String or value.is_empty() or seen.has(value): return false
			seen[value] = true
	if row.node_ids.is_empty() or row.visible_segment_ids.is_empty(): return false
	for field in ["locales", "variables", "localization_keys"]:
		if not row.get(field) is Dictionary: return false
	for locale in ["ko-KR", "en-US"]:
		if not row.locales.get(locale) is Dictionary: return false
		for field in ["title", "summary", "speaker"]:
			if not row.locales[locale].get(field) is String or row.locales[locale][field].is_empty(): return false
		for segment in row.visible_segment_ids:
			if not row.localization_keys.get(segment) is String or row.localization_keys[segment].is_empty() or not row.variables.get(segment) is Dictionary: return false
			if not row.locales[locale].get(segment) is String or row.locales[locale][segment].is_empty(): return false
			var specs: Dictionary = row.variables[segment]
			for key in specs:
				if not key is String or specs[key] not in TYPES: return false
			var expected := specs.keys()
			expected.sort()
			if _placeholders(row.locales[locale][segment]) != expected: return false
	return true


static func _variables_match(specs: Dictionary, values: Variant) -> bool:
	if not values is Dictionary or values.size() != specs.size(): return false
	for key in specs:
		if not values.has(key): return false
		if specs[key] == "int":
			if not _integer(values[key]): return false
		elif typeof(values[key]) != TYPES[specs[key]]: return false
		if values[key] is float and not is_finite(values[key]): return false
	return true


static func _placeholders(text: String) -> Array:
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var names := {}
	for found in regex.search_all(text): names[found.get_string(1)] = true
	var keys := names.keys()
	keys.sort()
	return keys


static func _serialized_variables(variables: Dictionary) -> Dictionary:
	var result := variables.duplicate(true)
	# JSON numbers decode as floats; freeze that representation before the first save.
	for key in result:
		if result[key] is int: result[key] = float(result[key])
	return result


static func _substitute(template: String, variables: Dictionary, specs: Dictionary) -> String:
	# A callback-like single pass prevents variable values from becoming new templates.
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var result := ""
	var offset := 0
	for found in regex.search_all(template):
		var key := found.get_string(1)
		var value: Variant = int(variables[key]) if specs[key] == "int" else variables[key]
		result += template.substr(offset, found.get_start() - offset) + str(value)
		offset = found.get_end()
	return result + template.substr(offset)


static func _integer(value: Variant) -> bool:
	return (value is int and absf(float(value)) < 9007199254740992.0) or (value is float and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0)


static func _locale(value: String) -> String:
	return "en-US" if value.begins_with("en") else "ko-KR"


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id, "error_ids": [id]}
