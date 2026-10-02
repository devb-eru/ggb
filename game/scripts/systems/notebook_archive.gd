extends RefCounted

# Pure candidate transformations. Persistence and UI must not treat a candidate as committed.
const VERSION := 2
const NORMAL_LIMIT := 2000
const BOOKMARK_LIMIT := 50
const COMPARISON_LIMIT := 12
const CONTEXT := preload("res://scripts/systems/dialogue_history_context.gd")
const KINDS := ["dialogue", "options_presented", "choice_confirmed", "choice_cancelled", "document_segment", "hint_revealed"]
const SOURCE_KINDS := ["knowledge_source", "person_source", "document_source"]
const ROOT_KEYS := ["schema_version", "source_origin_id", "branch_id", "revision", "next_sequence", "entries", "bookmarks", "comparison", "source_links"]


static func new_uid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func create() -> Dictionary:
	return {"schema_version": VERSION, "source_origin_id": new_uid(), "branch_id": new_uid(), "revision": 0, "next_sequence": 0, "entries": [], "bookmarks": [], "comparison": [], "source_links": []}


static func migrate_verified_legacy(history: Dictionary, verified_source_id: String) -> Dictionary:
	# The caller must verify the source envelope before supplying its immutable digest.
	if verified_source_id.length() != 64 or not verified_source_id.is_valid_hex_number() or history.has("schema_version") or not history.get("entries") is Array or not _integer(history.get("next_sequence")):
		return _error("NB_MIGRATION_SOURCE")
	var result := create()
	result.source_origin_id = ("legacy-origin:" + verified_source_id).sha256_text().left(32)
	result.branch_id = ("legacy-branch:" + verified_source_id).sha256_text().left(32)
	result.next_sequence = int(history.next_sequence)
	var previous := -1
	for index in range(history.entries.size()):
		var raw: Variant = history.entries[index]
		if not raw is Dictionary or not _integer(raw.get("sequence")) or int(raw.sequence) <= previous:
			return _error("NB_MIGRATION_SEQUENCE")
		previous = int(raw.sequence)
		var uid: String = (result.source_origin_id + ":%d:%s" % [index, JSON.stringify(raw, "", true)]).sha256_text().left(32)
		result.entries.append({
			"entry_uid": uid, "source_origin_id": result.source_origin_id, "sequence": previous,
			"record_class": "legacy", "chapter_id": CONTEXT.normalize_chapter(raw.get("chapter_id")),
			"legacy_payload": raw.duplicate(true), "protection_reasons": [],
		})
	var checked := validate(result)
	return {"ok": true, "archive": result} if checked.ok else checked


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or not _keys(value, ROOT_KEYS) or value.get("schema_version") != VERSION:
		return _error("NB_ARCHIVE_SCHEMA")
	var archive: Dictionary = value
	for field in ["source_origin_id", "branch_id"]:
		if not _uid(archive[field]): return _error("NB_ARCHIVE_ID")
	for field in ["revision", "next_sequence"]:
		if not _integer(archive[field]) or int(archive[field]) < 0: return _error("NB_ARCHIVE_SEQUENCE")
	for field in ["entries", "bookmarks", "comparison", "source_links"]:
		if not archive[field] is Array: return _error("NB_ARCHIVE_COLLECTION")
	var ids := {}
	var tokens := {}
	var previous := -1
	for entry in archive.entries:
		if not entry is Dictionary or not _uid(entry.get("entry_uid")) or not _uid(entry.get("source_origin_id")):
			return _error("NB_ENTRY_ID")
		if ids.has(entry.entry_uid) or not _integer(entry.get("sequence")) or int(entry.sequence) <= previous:
			return _error("NB_ENTRY_SEQUENCE")
		ids[entry.entry_uid] = entry
		previous = int(entry.sequence)
		if not _strings(entry.get("protection_reasons"), true): return _error("NB_ENTRY_PROTECTION")
		if entry.get("record_class") == "legacy":
			if not entry.get("legacy_payload") is Dictionary: return _error("NB_LEGACY_PAYLOAD")
		elif entry.get("record_class") == "authored":
			var checked := _validate_observation(entry.get("observation"))
			if not checked.ok: return checked
			var token: String = entry.observation.presentation_token
			if tokens.has(token): return _error("NB_DUPLICATE_PRESENTATION")
			tokens[token] = true
		else:
			return _error("NB_RECORD_CLASS")
	if int(archive.next_sequence) <= previous: return _error("NB_ARCHIVE_SEQUENCE")
	for collection in ["bookmarks", "comparison"]:
		var limit := BOOKMARK_LIMIT if collection == "bookmarks" else COMPARISON_LIMIT
		if archive[collection].size() > limit: return _error("NB_REFERENCE_LIMIT")
		var seen := []
		for ref in archive[collection]:
			if ref in seen or not _resolve_in(ids, ref).ok: return _error("NB_REFERENCE_INVALID")
			seen.append(ref)
	var links := []
	for link in archive.source_links:
		if not link is Dictionary or not _keys(link, ["consumer_kind", "consumer_uid", "target"]): return _error("NB_SOURCE_LINK")
		if link.consumer_kind not in SOURCE_KINDS or not _uid(link.consumer_uid) or link in links or not _resolve_in(ids, link.target).ok:
			return _error("NB_SOURCE_LINK")
		links.append(link)
	for entry in archive.entries:
		if entry.protection_reasons != _reasons(archive, entry): return _error("NB_PROTECTION_MISMATCH")
	return {"ok": true}


static func append_observation(archive: Dictionary, observation: Dictionary, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	var checked := _validate_observation(observation)
	if not checked.ok: return checked
	for entry in archive.entries:
		if entry.get("record_class") == "authored" and entry.observation.presentation_token == observation.presentation_token:
			if entry.observation != observation: return _error("NB_PRESENTATION_CONFLICT")
			return {"ok": true, "archive": archive.duplicate(true), "entry_uid": entry.entry_uid, "changed": false, "pruned_uids": []}
	var candidate := archive.duplicate(true)
	var entry := {
		"entry_uid": new_uid(), "source_origin_id": archive.source_origin_id, "sequence": int(archive.next_sequence),
		"record_class": "authored", "observation": observation.duplicate(true), "protection_reasons": [],
	}
	candidate.entries.append(entry)
	candidate.next_sequence = int(candidate.next_sequence) + 1
	var result := _finish(candidate)
	result["entry_uid"] = entry.entry_uid
	return result


static func make_reference(entry: Dictionary, segment_id: String) -> Dictionary:
	if entry.get("record_class") == "legacy":
		return {"kind": "legacy", "source_origin_id": entry.source_origin_id, "uid": entry.entry_uid, "content_version": 0, "segment_id": segment_id}
	var observation: Dictionary = entry.observation
	return {"kind": observation.entry_kind, "source_origin_id": entry.source_origin_id, "uid": entry.entry_uid, "content_version": observation.content_version, "segment_id": segment_id}


static func resolve(archive: Dictionary, reference: Dictionary) -> Dictionary:
	var ready := validate(archive)
	if not ready.ok: return ready
	return _resolve_in(_index(archive), reference)


static func set_reference(archive: Dictionary, collection: String, reference: Dictionary, enabled: bool, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if collection not in ["bookmarks", "comparison"]: return _error("NB_REFERENCE_COLLECTION")
	if not _resolve_in(_index(archive), reference).ok: return _error("NB_REFERENCE_UNAVAILABLE")
	var exists: bool = reference in archive[collection]
	if exists == enabled: return {"ok": true, "archive": archive.duplicate(true), "changed": false, "pruned_uids": []}
	var limit := BOOKMARK_LIMIT if collection == "bookmarks" else COMPARISON_LIMIT
	if enabled and archive[collection].size() >= limit: return _error("NB_REFERENCE_LIMIT")
	var candidate := archive.duplicate(true)
	if enabled: candidate[collection].append(reference.duplicate(true))
	else: candidate[collection].erase(reference)
	return _finish(candidate)


static func add_source_link(archive: Dictionary, consumer_kind: String, consumer_uid: String, target: Dictionary, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if consumer_kind not in SOURCE_KINDS or not _uid(consumer_uid) or not _resolve_in(_index(archive), target).ok:
		return _error("NB_SOURCE_LINK")
	var link := {"consumer_kind": consumer_kind, "consumer_uid": consumer_uid, "target": target.duplicate(true)}
	if link in archive.source_links: return {"ok": true, "archive": archive.duplicate(true), "changed": false, "pruned_uids": []}
	var candidate := archive.duplicate(true)
	candidate.source_links.append(link)
	return _finish(candidate)


static func fork(archive: Dictionary) -> Dictionary:
	var checked := validate(archive)
	if not checked.ok: return checked
	var candidate := archive.duplicate(true)
	candidate.branch_id = new_uid()
	candidate.revision = int(candidate.revision) + 1
	return {"ok": true, "archive": candidate}


static func maintain(archive: Dictionary, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	return _finish(archive.duplicate(true)) if ready.ok else ready


static func _finish(candidate: Dictionary) -> Dictionary:
	var normal: Array = []
	for entry in candidate.entries:
		entry.protection_reasons = _reasons(candidate, entry)
		if entry.record_class == "authored" and entry.protection_reasons.is_empty(): normal.append(entry.entry_uid)
	var pruned: Array = normal.slice(0, maxi(normal.size() - NORMAL_LIMIT, 0))
	var dropped := {}
	for uid in pruned: dropped[uid] = true
	candidate.entries = candidate.entries.filter(func(entry: Dictionary) -> bool: return not dropped.has(entry.entry_uid))
	candidate.revision = int(candidate.revision) + 1
	var checked := validate(candidate)
	if not checked.ok: return checked
	return {"ok": true, "archive": candidate, "changed": true, "pruned_uids": pruned}


static func _reasons(archive: Dictionary, entry: Dictionary) -> Array:
	var reasons := {}
	if entry.get("record_class") == "authored":
		for reason in entry.observation.content_protection: reasons["content:" + reason] = true
	for collection in ["bookmarks", "comparison"]:
		for ref in archive[collection]:
			if ref.uid == entry.entry_uid:
				reasons[("bookmark:" if collection == "bookmarks" else "comparison:") + ref.segment_id] = true
	for link in archive.source_links:
		if link.target.uid == entry.entry_uid: reasons[link.consumer_kind + ":" + link.consumer_uid] = true
	var values := reasons.keys()
	values.sort()
	return values


static func _validate_observation(value: Variant) -> Dictionary:
	var fields := ["producer_id", "event_id", "node_id", "location_id", "chapter_id", "event_occurrence_id", "conversation_session_id", "presentation_token", "entry_kind", "content_id", "content_version", "variant_id", "speaker_id", "segments", "content_protection"]
	if not value is Dictionary or not _keys(value, fields): return _error("NB_OBSERVATION_FIELDS")
	for field in ["producer_id", "event_id", "node_id", "location_id", "content_id", "variant_id", "speaker_id"]:
		if not value[field] is String or value[field].is_empty(): return _error("NB_OBSERVATION_ID")
	for field in ["event_occurrence_id", "conversation_session_id", "presentation_token"]:
		if not _uid(value[field]): return _error("NB_OBSERVATION_TOKEN")
	if value.entry_kind not in KINDS or value.chapter_id not in CONTEXT.CHAPTERS: return _error("NB_OBSERVATION_KIND")
	if not _integer(value.content_version) or int(value.content_version) < 1: return _error("NB_CONTENT_VERSION")
	if not _strings(value.content_protection, true): return _error("NB_CONTENT_PROTECTION")
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


static func _resolve_in(index: Dictionary, value: Variant) -> Dictionary:
	if not value is Dictionary or not _keys(value, ["kind", "source_origin_id", "uid", "content_version", "segment_id"]): return _error("NB_REFERENCE_FIELDS")
	if not _uid(value.uid) or not _uid(value.source_origin_id) or not value.kind is String or not value.segment_id is String or not _integer(value.content_version): return _error("NB_REFERENCE_FIELDS")
	if not index.has(value.uid): return _error("NB_REFERENCE_UNAVAILABLE")
	var entry: Dictionary = index[value.uid]
	if entry.source_origin_id != value.source_origin_id: return _error("NB_REFERENCE_ORIGIN")
	if entry.record_class == "legacy":
		if value.kind != "legacy" or int(value.content_version) != 0 or value.segment_id != "legacy": return _error("NB_REFERENCE_SEGMENT")
		return {"ok": true, "entry": entry.duplicate(true), "legacy": true}
	var observation: Dictionary = entry.observation
	if observation.entry_kind != value.kind or int(observation.content_version) != int(value.content_version): return _error("NB_REFERENCE_VERSION")
	for segment in observation.segments:
		if segment.segment_id == value.segment_id: return {"ok": true, "entry": entry.duplicate(true), "segment": segment.duplicate(true), "legacy": false}
	return _error("NB_REFERENCE_SEGMENT")


static func _ready(archive: Dictionary, revision: int) -> Dictionary:
	var checked := validate(archive)
	if not checked.ok: return checked
	return {"ok": true} if int(archive.revision) == revision else _error("NB_STALE_REVISION")


static func _index(archive: Dictionary) -> Dictionary:
	var index := {}
	for entry in archive.entries: index[entry.entry_uid] = entry
	return index


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for field in expected:
		if not value.has(field): return false
	return true


static func _uid(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number() and value == value.to_lower()


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0)


static func _strings(value: Variant, unique: bool) -> bool:
	if not value is Array: return false
	var found := {}
	for item in value:
		if not item is String or item.is_empty() or (unique and found.has(item)): return false
		found[item] = true
	return true


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id}
