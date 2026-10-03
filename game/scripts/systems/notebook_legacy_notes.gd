extends RefCounted

# Read only the two public notebook stores, never arbitrary knowledge flags.
const MARKER := "notebook_legacy_source"
const PROLOGUE := "prologue_notebook_entries"
const CHAPTER := "chapter_notebook"


static func project(knowledge: Dictionary, origin: String) -> Dictionary:
	var entries: Array = []
	var errors: Array = []
	var early: Variant = knowledge.get(PROLOGUE, [])
	if early is Array:
		for index in range(early.size()):
			if early[index] is String: entries.append(_entry(origin, PROLOGUE, str(index), early[index]))
			else: errors.append("NB_LEGACY_NOTE_VALUE")
	else: errors.append("NB_LEGACY_NOTE_CONTAINER")
	var later: Variant = knowledge.get(CHAPTER, {})
	if later is Dictionary:
		var keys: Array[String] = []
		for key in later:
			if key is String and later[key] is String: keys.append(key)
			else: errors.append("NB_LEGACY_NOTE_VALUE")
		keys.sort()
		for key in keys: entries.append(_entry(origin, CHAPTER, key, later[key]))
	else: errors.append("NB_LEGACY_NOTE_CONTAINER")
	return {"entries": entries, "errors": errors}


static func find(knowledge: Dictionary, origin: String, reference: Dictionary) -> Dictionary:
	for field in ["kind", "source_origin_id", "segment_id", "uid"]:
		if not reference.get(field) is String: return {}
	if typeof(reference.get("content_version")) not in [TYPE_INT, TYPE_FLOAT]: return {}
	if reference.get("kind") != "legacy" or reference.get("source_origin_id") != origin or reference.get("content_version") != 0 or reference.get("segment_id") != "legacy": return {}
	for entry in project(knowledge, origin).entries:
		if entry.entry_uid == reference.get("uid"): return entry
	return {}


static func validate_entry(entry: Dictionary) -> bool:
	for field in ["record_class", "chapter_id", "source_origin_id", "entry_uid"]:
		if not entry.get(field) is String: return false
	if entry.get("record_class") != "legacy" or entry.get("chapter_id") != "LEGACY": return false
	var source: Variant = entry.get(MARKER)
	if not source is Dictionary or not _keys(source, ["version", "container", "locator", "text_sha256"]): return false
	if typeof(source.version) not in [TYPE_INT, TYPE_FLOAT] or source.version != 1: return false
	if not source.container is String or not source.text_sha256 is String: return false
	if source.container not in [PROLOGUE, CHAPTER] or not source.locator is String: return false
	if source.container == PROLOGUE and (not source.locator.is_valid_int() or source.locator.to_int() < 0 or str(source.locator.to_int()) != source.locator): return false
	var payload: Variant = entry.get("legacy_payload")
	if not payload is Dictionary or not _keys(payload, ["sequence", "chapter_id", "line_id", "speaker_id", "variables"]): return false
	for field in ["chapter_id", "line_id", "speaker_id"]:
		if not payload[field] is String: return false
	if payload.chapter_id != "LEGACY" or payload.line_id != "CH1_HISTORY_TRANSCRIPT" or payload.speaker_id != "SYSTEM": return false
	if not payload.variables is Dictionary or not _keys(payload.variables, ["speaker", "text"]): return false
	if not payload.variables.speaker is String or payload.variables.speaker != "" or not payload.variables.text is String: return false
	var original: String = payload.variables.text
	return source.text_sha256 == original.sha256_text() and entry.get("entry_uid") == _uid(entry.source_origin_id, source.container, source.locator, original)


static func _entry(origin: String, container: String, locator: String, original: String) -> Dictionary:
	return {
		"entry_uid": _uid(origin, container, locator, original), "source_origin_id": origin,
		"sequence": 0, "record_class": "legacy", "chapter_id": "LEGACY", "protection_reasons": [],
		MARKER: {"version": 1, "container": container, "locator": locator, "text_sha256": original.sha256_text()},
		"legacy_payload": {"sequence": 0, "chapter_id": "LEGACY", "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "", "text": original}},
	}


static func _uid(origin: String, container: String, locator: String, original: String) -> String:
	return JSON.stringify(["notebook-legacy-note-v1", origin, container, locator, original]).sha256_text().left(32)


static func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true
