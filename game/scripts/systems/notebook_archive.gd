extends RefCounted

# Pure candidate transformations. Persistence and UI must not treat a candidate as committed.
const VERSION := 2
const NORMAL_LIMIT := 2000
const BOOKMARK_LIMIT := 50
const COMPARISON_LIMIT := 12
const CONTEXT := preload("res://scripts/systems/dialogue_history_context.gd")
const LEGACY_NOTES := preload("res://scripts/systems/notebook_legacy_notes.gd")
const OBSERVATION := preload("res://scripts/systems/notebook_observation_schema.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const LABELS := preload("res://scripts/systems/notebook_browse_labels.gd")
const KINDS := OBSERVATION.KINDS
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
	if not value is Dictionary or not _keys(value, ROOT_KEYS) or not _integer(value.get("schema_version")) or value.schema_version != VERSION:
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
		if entry.has(LEGACY_NOTES.MARKER) and not LEGACY_NOTES.validate_entry(entry): return _error("NB_LEGACY_NOTE_SNAPSHOT")
		if entry.get("record_class") in ["legacy", "unmapped"]:
			if not entry.get("legacy_payload") is Dictionary: return _error("NB_LEGACY_PAYLOAD")
			if not _integer(entry.legacy_payload.get("sequence")) or int(entry.legacy_payload.sequence) != int(entry.sequence): return _error("NB_LEGACY_SEQUENCE")
			if entry.record_class == "unmapped":
				if not entry.get("snapshot_context") is Dictionary or not _uid(entry.snapshot_context.get("presentation_token")): return _error("NB_UNMAPPED_CONTEXT")
				var token: String = entry.snapshot_context.presentation_token
				if tokens.has(token): return _error("NB_DUPLICATE_PRESENTATION")
				tokens[token] = true
		elif entry.get("record_class") == "authored":
			var checked := validate_observation(entry.get("observation"))
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
	var reference_reasons := _reference_reason_index(archive)
	for entry in archive.entries:
		if entry.protection_reasons != _entry_reasons(entry, reference_reasons): return _error("NB_PROTECTION_MISMATCH")
	return {"ok": true}


static func append_observation(archive: Dictionary, observation: Dictionary, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	var checked := validate_observation(observation)
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
	if entry.get("record_class") in ["legacy", "unmapped"]:
		return {"kind": entry.record_class, "source_origin_id": entry.source_origin_id, "uid": entry.entry_uid, "content_version": 0, "segment_id": segment_id}
	var observation: Dictionary = entry.observation
	return {"kind": observation.entry_kind, "source_origin_id": entry.source_origin_id, "uid": entry.entry_uid, "content_version": observation.content_version, "segment_id": segment_id}


static func resolve(archive: Dictionary, reference: Dictionary) -> Dictionary:
	var ready := validate(archive)
	if not ready.ok: return ready
	return _resolve_in(_index(archive), reference)


static func resolve_many(archive: Dictionary, references: Array) -> Dictionary:
	var ready := validate(archive)
	if not ready.ok: return ready
	var index := _index(archive)
	var resolved: Array = []
	for reference in references:
		var result := _resolve_in(index, reference)
		if not result.ok: return result
		resolved.append(result)
	return {"ok": true, "items": resolved}


static func set_reference(archive: Dictionary, collection: String, reference: Dictionary, enabled: bool, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if collection not in ["bookmarks", "comparison"]: return _error("NB_REFERENCE_COLLECTION")
	if not _reference_shape(reference): return _error("NB_REFERENCE_FIELDS")
	var exists: bool = reference in archive[collection]
	# An acknowledged removal can prune the now-unprotected target in the same commit.
	if not enabled and not exists: return {"ok": true, "archive": archive.duplicate(true), "changed": false, "pruned_uids": []}
	if not _resolve_in(_index(archive), reference).ok: return _error("NB_REFERENCE_UNAVAILABLE")
	if exists == enabled: return {"ok": true, "archive": archive.duplicate(true), "changed": false, "pruned_uids": []}
	var limit := BOOKMARK_LIMIT if collection == "bookmarks" else COMPARISON_LIMIT
	if enabled and archive[collection].size() >= limit: return _error("NB_REFERENCE_LIMIT")
	var candidate := archive.duplicate(true)
	if enabled: candidate[collection].append(reference.duplicate(true))
	else: candidate[collection].erase(reference)
	return _finish(candidate)


static func add_source_link(archive: Dictionary, consumer_kind: String, consumer_uid: String, target: Dictionary, expected_revision: int) -> Dictionary:
	return add_source_links(archive, consumer_kind, consumer_uid, [target], expected_revision)


static func capture_legacy_note_reference(archive: Dictionary, collection: String, note: Dictionary, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if collection not in ["bookmarks", "comparison"]: return _error("NB_REFERENCE_COLLECTION")
	if not LEGACY_NOTES.validate_entry(note) or note.source_origin_id != archive.source_origin_id: return _error("NB_LEGACY_NOTE_SNAPSHOT")
	var ref := make_reference(note, "legacy")
	if _index(archive).has(note.entry_uid): return set_reference(archive, collection, ref, true, expected_revision)
	var limit := BOOKMARK_LIMIT if collection == "bookmarks" else COMPARISON_LIMIT
	if archive[collection].size() >= limit: return _error("NB_REFERENCE_LIMIT")
	var candidate := archive.duplicate(true)
	var captured := note.duplicate(true)
	captured.sequence = int(candidate.next_sequence)
	captured.legacy_payload.sequence = captured.sequence
	candidate.next_sequence = int(candidate.next_sequence) + 1
	candidate.entries.append(captured)
	candidate[collection].append(ref)
	# The original value and its protection become durable in the same commit.
	return _finish(candidate)


static func add_source_links(archive: Dictionary, consumer_kind: String, consumer_uid: String, targets: Array, expected_revision: int) -> Dictionary:
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if consumer_kind not in SOURCE_KINDS or not _uid(consumer_uid):
		return _error("NB_SOURCE_LINK")
	var candidate := archive.duplicate(true)
	var index := _index(archive)
	for target in targets:
		if not _resolve_in(index, target).ok: return _error("NB_SOURCE_LINK")
		var link := {"consumer_kind": consumer_kind, "consumer_uid": consumer_uid, "target": target.duplicate(true)}
		if link not in candidate.source_links: candidate.source_links.append(link)
	if candidate.source_links == archive.source_links: return {"ok": true, "archive": candidate, "changed": false, "pruned_uids": []}
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


static func append_unmapped(archive: Dictionary, payload: Dictionary, context: Dictionary, expected_revision: int) -> Dictionary:
	# Transitional producer bridge, not legacy migration or authored-content coverage.
	var ready := _ready(archive, expected_revision)
	if not ready.ok: return ready
	if not _uid(context.get("presentation_token")): return _error("NB_UNMAPPED_CONTEXT")
	for entry in archive.entries:
		if entry.record_class == "unmapped" and entry.snapshot_context.presentation_token == context.presentation_token:
			var previous: Dictionary = entry.legacy_payload.duplicate(true)
			previous.erase("sequence")
			if previous != payload or entry.snapshot_context != context: return _error("NB_PRESENTATION_CONFLICT")
			return {"ok": true, "archive": archive.duplicate(true), "entry_uid": entry.entry_uid, "changed": false, "pruned_uids": []}
	var candidate := archive.duplicate(true)
	var raw := payload.duplicate(true)
	raw.sequence = int(candidate.next_sequence)
	var entry := {"entry_uid": new_uid(), "source_origin_id": archive.source_origin_id, "sequence": raw.sequence, "record_class": "unmapped", "chapter_id": CONTEXT.normalize_chapter(payload.get("chapter_id")), "legacy_payload": raw, "snapshot_context": context.duplicate(true), "protection_reasons": []}
	candidate.entries.append(entry)
	candidate.next_sequence = int(candidate.next_sequence) + 1
	var result := _finish(candidate)
	result["entry_uid"] = entry.entry_uid
	return result


static func display_payload(entry: Dictionary) -> Dictionary:
	if entry.get("record_class") in ["legacy", "unmapped"]:
		return entry.legacy_payload.duplicate(true)
	return entry.duplicate(true)


static func _finish(candidate: Dictionary) -> Dictionary:
	_protect_first_people(candidate)
	var normal: Array = []
	var reference_reasons := _reference_reason_index(candidate)
	for entry in candidate.entries:
		entry.protection_reasons = _entry_reasons(entry, reference_reasons)
		if entry.record_class == "authored" and entry.protection_reasons.is_empty(): normal.append(entry.entry_uid)
	var pruned: Array = normal.slice(0, maxi(normal.size() - NORMAL_LIMIT, 0))
	var dropped := {}
	for uid in pruned: dropped[uid] = true
	candidate.entries = candidate.entries.filter(func(entry: Dictionary) -> bool: return not dropped.has(entry.entry_uid))
	candidate.revision = int(candidate.revision) + 1
	var checked := validate(candidate)
	if not checked.ok: return checked
	return {"ok": true, "archive": candidate, "changed": true, "pruned_uids": pruned}


static func _protect_first_people(candidate: Dictionary) -> void:
	var missing := {}
	for person in LABELS.PEOPLE:
		missing[person] = ("notebook-person:" + candidate.source_origin_id + ":" + person).sha256_text().left(32)
	for link in candidate.source_links:
		if link.consumer_kind != "person_source": continue
		for person in missing.keys():
			if link.consumer_uid == missing[person]: missing.erase(person)
	# Protect the earliest still-provable utterance before any normal entry is pruned.
	for entry in candidate.entries:
		if missing.is_empty(): break
		if entry.record_class != "authored": continue
		var person := LABELS.person(entry.observation.speaker_id)
		if not missing.has(person): continue
		var metadata := CONTENT.review_metadata(entry.observation, "ko-KR")
		if not metadata.ok or metadata.fallback or metadata.speaker.is_empty(): continue
		candidate.source_links.append({"consumer_kind": "person_source", "consumer_uid": missing[person], "target": make_reference(entry, entry.observation.segments[0].segment_id)})
		missing.erase(person)


static func _reasons(archive: Dictionary, entry: Dictionary) -> Array:
	return _entry_reasons(entry, _reference_reason_index(archive))


static func _reference_reason_index(archive: Dictionary) -> Dictionary:
	# Transaction-local only; callers validate references before deriving protection.
	var indexed := {}
	for collection in ["bookmarks", "comparison"]:
		for ref in archive[collection]:
			if not indexed.has(ref.uid): indexed[ref.uid] = {}
			indexed[ref.uid][("bookmark:" if collection == "bookmarks" else "comparison:") + ref.segment_id] = true
	for link in archive.source_links:
		if not indexed.has(link.target.uid): indexed[link.target.uid] = {}
		indexed[link.target.uid][link.consumer_kind + ":" + link.consumer_uid] = true
	return indexed


static func _entry_reasons(entry: Dictionary, reference_reasons: Dictionary) -> Array:
	var reasons: Dictionary = reference_reasons.get(entry.entry_uid, {}).duplicate()
	if entry.get("record_class") == "authored":
		for reason in entry.observation.content_protection: reasons["content:" + reason] = true
	var values := reasons.keys()
	values.sort()
	return values


static func validate_observation(value: Variant) -> Dictionary:
	return OBSERVATION.validate(value)


static func _resolve_in(index: Dictionary, value: Variant) -> Dictionary:
	if not _reference_shape(value): return _error("NB_REFERENCE_FIELDS")
	if not index.has(value.uid): return _error("NB_REFERENCE_UNAVAILABLE")
	var entry: Dictionary = index[value.uid]
	if entry.source_origin_id != value.source_origin_id: return _error("NB_REFERENCE_ORIGIN")
	if entry.record_class in ["legacy", "unmapped"]:
		if value.kind != entry.record_class or int(value.content_version) != 0 or value.segment_id != "legacy": return _error("NB_REFERENCE_SEGMENT")
		return {"ok": true, "entry": entry.duplicate(true), "legacy": true}
	var observation: Dictionary = entry.observation
	if observation.entry_kind != value.kind or int(observation.content_version) != int(value.content_version): return _error("NB_REFERENCE_VERSION")
	for segment in observation.segments:
		if segment.segment_id == value.segment_id: return {"ok": true, "entry": entry.duplicate(true), "segment": segment.duplicate(true), "legacy": false}
	return _error("NB_REFERENCE_SEGMENT")


static func _reference_shape(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["kind", "source_origin_id", "uid", "content_version", "segment_id"]): return false
	if not _uid(value.uid) or not _uid(value.source_origin_id) or not value.kind is String or not value.segment_id is String or not _integer(value.content_version): return false
	if value.kind in ["legacy", "unmapped"]: return int(value.content_version) == 0 and value.segment_id == "legacy"
	return value.kind in KINDS and int(value.content_version) > 0 and not value.segment_id.is_empty()


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
