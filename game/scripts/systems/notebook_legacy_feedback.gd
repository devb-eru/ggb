extends RefCounted

const STAMP := "producer_contract_version"
const VERSION := 1
const ORIGIN := "legacy_feedback_origin"
const REPLAY := "legacy_feedback_replay"
const MARKER := "legacy_feedback_source"


static func prepare(last: Dictionary, archive: Dictionary) -> Dictionary:
	if last.has(STAMP) and (not _integer(last[STAMP]) or last[STAMP] != VERSION): return _error()
	if not archive.has("schema_version") or last.is_empty(): return {"ok": true, "origin": {}}
	if last.has(ORIGIN):
		if not valid_origin(last[ORIGIN]) or last[ORIGIN].source_origin_id != archive.source_origin_id: return _error()
		return {"ok": true, "origin": last[ORIGIN].duplicate(true)}
	if last.has(STAMP): return {"ok": true, "origin": {}}
	if last.has("notebook_feedback"):
		if not last.notebook_feedback is Array: return _error()
		if not last.notebook_feedback.is_empty(): return {"ok": true, "origin": {}}
	var origin := {"schema_version": VERSION, "source_origin_id": archive.source_origin_id, "feedback": last.duplicate(true)}
	origin.source_id = _digest(origin)
	return {"ok": true, "origin": origin} if valid_origin(origin) else _error()


static func valid_origin(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["schema_version", "source_origin_id", "feedback", "source_id"]): return false
	if not _integer(value.schema_version) or value.schema_version != VERSION or not _hex(value.source_origin_id, 32) or not _hex(value.source_id, 64): return false
	var last: Variant = value.feedback
	if not last is Dictionary or not _json(last) or last.has(STAMP) or last.has(ORIGIN): return false
	if not last.get("text") is String or last.text.is_empty() or not last.get("speaker", "주인공") is String or not last.get("text_id", "") is String: return false
	if not last.get("history_context", {}) is Dictionary: return false
	var context: Dictionary = last.get("history_context", {})
	if context.has(REPLAY) or context.has("notebook_content"): return false
	if last.has("notebook_feedback") and (not last.notebook_feedback is Array or not last.notebook_feedback.is_empty()): return false
	var source: Dictionary = value.duplicate(true)
	source.erase("source_id")
	return value.source_id == _digest(source) and not paragraphs(value).is_empty()


static func paragraphs(origin: Dictionary) -> Array:
	return Array(String(origin.feedback.text).split("\n")).filter(func(line: String) -> bool: return not line.is_empty())


static func context_for(origin: Dictionary) -> Dictionary:
	var context: Dictionary = origin.feedback.get("history_context", {}).duplicate(true)
	# Missing historical metadata stays unknown; current stage/room is not its source.
	for field in ["node_id", "chapter_id", "location_id"]:
		if not context.get(field) is String or context[field].is_empty(): context[field] = "LEGACY" if field == "chapter_id" else "LEGACY_UNKNOWN"
	for field in ["event_occurrence_id", "conversation_session_id"]:
		if not _hex(context.get(field), 32): context[field] = ("legacy-feedback:" + origin.source_id + ":" + field).sha256_text().left(32)
	context.erase("presentation_token")
	context.erase("presentation_cursor")
	context.erase("surface_receipt")
	context.erase("observed_fact_ids")
	return context


static func line_context(origin: Dictionary, index: int) -> Dictionary:
	var context := context_for(origin)
	context[REPLAY] = {"source_id": origin.source_id, "paragraph_index": index}
	context.presentation_token = ("legacy-feedback-token:" + origin.source_origin_id + ":" + origin.source_id + ":%d" % index).sha256_text().left(32)
	return context


static func verify(state: Dictionary, context: Dictionary, speaker: String, text: String, facts: Variant) -> Dictionary:
	var last: Dictionary = state.get("loop_state", {}).get("event_local_states", {}).get("CHAPTER_ONE", {}).get("last_feedback", {})
	var origin: Variant = last.get(ORIGIN)
	if not valid_origin(origin) or origin.source_origin_id != state.meta_progress.dialogue_history.source_origin_id: return _error()
	if last.get(STAMP) != VERSION or last.has("notebook_feedback") or not facts is Array or not facts.is_empty(): return _error()
	for field in ["text", "speaker", "text_id"]:
		if last.get(field, "주인공" if field == "speaker" else "") != origin.feedback.get(field, "주인공" if field == "speaker" else ""): return _error()
	if _canonical(last.get("history_context", {})) != _canonical(context_for(origin)): return _error()
	if not matches(origin, context, speaker, text): return _error()
	return {"ok": true, "origin": origin.duplicate(true)}


static func matches(origin: Dictionary, context: Dictionary, speaker: String, text: String) -> bool:
	if not valid_origin(origin) or context.has("notebook_content") or context.has("surface_receipt"): return false
	var proof: Variant = context.get(REPLAY)
	if not proof is Dictionary or not _keys(proof, ["source_id", "paragraph_index"]) or proof.source_id != origin.source_id or not _integer(proof.paragraph_index): return false
	var lines := paragraphs(origin)
	var index := int(proof.paragraph_index)
	if index < 0 or index >= lines.size() or lines[index] != text or speaker != origin.feedback.get("speaker", "주인공"): return false
	var actual := context.duplicate(true)
	actual.erase("presentation_cursor")
	if actual.has("observed_fact_ids"):
		if not actual.observed_fact_ids is Array or not actual.observed_fact_ids.is_empty(): return false
		actual.erase("observed_fact_ids")
	return _canonical(actual) == _canonical(line_context(origin, index))


static func valid_entry(entry: Dictionary) -> bool:
	var origin: Variant = entry.get(MARKER)
	if not valid_origin(origin) or entry.get("record_class") != "legacy" or entry.get("source_origin_id") != origin.source_origin_id: return false
	var payload: Variant = entry.get("legacy_payload")
	var context: Variant = entry.get("snapshot_context")
	if not payload is Dictionary or not context is Dictionary or not payload.get("variables") is Dictionary: return false
	if payload.get("line_id") != "CH1_HISTORY_TRANSCRIPT" or payload.get("speaker_id") != "SYSTEM" or payload.get("viewed_locale") not in ["ko-KR", "en-US"]: return false
	if not _keys(payload.variables, ["speaker", "text"]) or not payload.variables.speaker is String or not payload.variables.text is String: return false
	var chapter := preload("res://scripts/systems/dialogue_history_context.gd").normalize_chapter(context_for(origin).chapter_id)
	return payload.get("chapter_id") == chapter and entry.get("chapter_id") == chapter and matches(origin, context, payload.variables.speaker, payload.variables.text)


static func _digest(value: Dictionary) -> String:
	return JSON.stringify(_canonical(value), "", true).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _canonical(value[key])
		return result
	if value is Array: return value.map(_canonical)
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value): return int(value)
	return value


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))


static func _hex(value: Variant, size: int) -> bool:
	return value is String and value.length() == size and value.is_valid_hex_number()


static func _keys(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and fields.all(func(key: String) -> bool: return value.has(key))


static func _json(value: Variant) -> bool:
	if value == null or value is String or value is bool or typeof(value) == TYPE_INT: return true
	if typeof(value) == TYPE_FLOAT: return is_finite(value)
	if value is Array: return value.all(_json)
	if value is Dictionary: return value.keys().all(func(key: Variant) -> bool: return (key is String or key is StringName) and _json(value[key]))
	return false


static func _error() -> Dictionary:
	return {"ok": false, "error_ids": ["NB_LEGACY_FEEDBACK_PROVENANCE"]}
