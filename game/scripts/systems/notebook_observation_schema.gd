extends RefCounted

# Shared shape validation keeps content disclosure independent of archive retention.
const CONTEXT := preload("res://scripts/systems/dialogue_history_context.gd")
const KINDS := ["dialogue", "options_presented", "choice_confirmed", "choice_cancelled", "document_segment", "hint_revealed"]


static func validate(value: Variant) -> Dictionary:
	var fields := ["producer_id", "event_id", "node_id", "location_id", "chapter_id", "event_occurrence_id", "conversation_session_id", "presentation_token", "entry_kind", "content_id", "content_version", "variant_id", "speaker_id", "segments", "content_protection"]
	if not value is Dictionary or not _keys(value, fields): return _error("NB_OBSERVATION_FIELDS")
	for field in ["producer_id", "event_id", "node_id", "location_id", "content_id", "variant_id", "speaker_id"]:
		if not value[field] is String or value[field].is_empty(): return _error("NB_OBSERVATION_ID")
	for field in ["event_occurrence_id", "conversation_session_id", "presentation_token"]:
		if not _uid(value[field]): return _error("NB_OBSERVATION_TOKEN")
	if value.entry_kind not in KINDS or value.chapter_id not in CONTEXT.CHAPTERS: return _error("NB_OBSERVATION_KIND")
	if not _integer(value.content_version) or int(value.content_version) < 1: return _error("NB_CONTENT_VERSION")
	if not _strings(value.content_protection): return _error("NB_CONTENT_PROTECTION")
	if not value.segments is Array or value.segments.is_empty(): return _error("NB_SEGMENTS")
	var ids := {}
	for segment in value.segments:
		if not segment is Dictionary or not _keys(segment, ["segment_id", "disclosure", "localization_key", "safe_variables", "captured_text", "viewed_locale"]): return _error("NB_SEGMENT_FIELDS")
		for field in ["segment_id", "localization_key", "captured_text", "viewed_locale"]:
			if not segment[field] is String or segment[field].is_empty(): return _error("NB_SEGMENT_TEXT")
		if segment.disclosure not in ["displayed", "replay_committed"] or ids.has(segment.segment_id): return _error("NB_SEGMENT_DISCLOSURE")
		ids[segment.segment_id] = true
		if not segment.safe_variables is Dictionary: return _error("NB_SEGMENT_VARIABLES")
		for key in segment.safe_variables:
			if not key is String or typeof(segment.safe_variables[key]) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]: return _error("NB_SEGMENT_VARIABLES")
			if typeof(segment.safe_variables[key]) == TYPE_FLOAT and not is_finite(segment.safe_variables[key]): return _error("NB_SEGMENT_VARIABLES")
	return {"ok": true}


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for field in expected:
		if not value.has(field): return false
	return true


static func _uid(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number() and value == value.to_lower()


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0)


static func _strings(value: Variant) -> bool:
	if not value is Array: return false
	var found := {}
	for item in value:
		if not item is String or item.is_empty() or found.has(item): return false
		found[item] = true
	return true


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id}
