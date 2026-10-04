extends RefCounted

# Pure revision candidates; the event owner persists these together with gameplay.
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KEY := "notebook_knowledge"
const META_KEYS := ["knowledge_id", "category", "epistemic_state", "provenance_state", "lifetime"]
const REVISION_KEYS := ["knowledge_uid", "revision_uid", "previous_revision_uid", "sequence", "metadata", "observation_ref", "source_refs"]


static func create() -> Dictionary:
	return {"schema_version": 1, "revision": 0, "revisions": []}


static func valid_metadata(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, META_KEYS): return false
	for key in META_KEYS:
		if not value[key] is String: return false
	return not value.knowledge_id.is_empty() and value.category in ["observation", "hypothesis", "failure", "document", "journal", "person"] and value.epistemic_state in ["observed", "hypothesis", "verified", "refuted"] and value.provenance_state in ["unverified", "identified", "authenticated"] and value.lifetime in ["persistent", "physical"]


static func validate(value: Variant, archive: Dictionary) -> Dictionary:
	var archive_check := ARCHIVE.validate(archive)
	if not archive_check.ok: return archive_check
	if not value is Dictionary or not _keys(value, ["schema_version", "revision", "revisions"]) or not _integer(value.schema_version) or value.schema_version != 1 or not _integer(value.revision) or not value.revisions is Array or value.revision != value.revisions.size():
		return _error("NB_KNOWLEDGE_SCHEMA")
	var latest := {}
	var owners := {}
	var revisions := {}
	var expected_links: Array = []
	var references: Array = []
	var own_indices: Array = []
	for index in range(value.revisions.size()):
		var row: Variant = value.revisions[index]
		if not row is Dictionary or not _keys(row, REVISION_KEYS) or not _uid(row.knowledge_uid) or not _uid(row.revision_uid) or revisions.has(row.revision_uid) or not _integer(row.sequence) or row.sequence != index or not valid_metadata(row.metadata):
			return _error("NB_KNOWLEDGE_REVISION")
		if not row.previous_revision_uid is String or (not row.previous_revision_uid.is_empty() and not _uid(row.previous_revision_uid)):
			return _error("NB_KNOWLEDGE_CHAIN")
		var id: String = row.metadata.knowledge_id
		if owners.has(row.knowledge_uid) and owners[row.knowledge_uid] != id: return _error("NB_KNOWLEDGE_OWNER")
		if latest.has(id):
			if row.knowledge_uid != latest[id].knowledge_uid or row.previous_revision_uid != latest[id].revision_uid: return _error("NB_KNOWLEDGE_CHAIN")
		elif row.previous_revision_uid != "": return _error("NB_KNOWLEDGE_CHAIN")
		if not row.observation_ref is Dictionary or not row.source_refs is Array or row.source_refs.is_empty() or row.observation_ref not in row.source_refs:
			return _error("NB_KNOWLEDGE_SOURCE")
		var unique: Array = []
		for reference in row.source_refs:
			if not reference is Dictionary or reference in unique: return _error("NB_KNOWLEDGE_SOURCE")
			if reference == row.observation_ref: own_indices.append(references.size())
			references.append(reference)
			unique.append(reference)
			expected_links.append({"consumer_kind": "knowledge_source", "consumer_uid": row.revision_uid, "target": reference})
		latest[id] = row
		owners[row.knowledge_uid] = id
		revisions[row.revision_uid] = row
	var actual: Array = archive.source_links.filter(func(link: Dictionary) -> bool: return link.consumer_kind == "knowledge_source")
	if actual.size() != expected_links.size(): return _error("NB_KNOWLEDGE_PROTECTION")
	for link in expected_links:
		if link not in actual: return _error("NB_KNOWLEDGE_PROTECTION")
	# The archive and empty ledger were already validated, including orphan links.
	if references.is_empty(): return {"ok":true}
	# Validate/index the archive once for all sources, not once per revision.
	var resolved := ARCHIVE.resolve_many(archive, references)
	if not resolved.ok: return resolved
	var own_ids := {}
	for index in range(own_indices.size()):
		var own: Dictionary = resolved.items[own_indices[index]]
		if own.get("legacy", true) or own.entry.observation.entry_kind != "document_segment": return _error("NB_KNOWLEDGE_OBSERVATION")
		if own_ids.has(own.entry.entry_uid): return _error("NB_KNOWLEDGE_OBSERVATION_REUSED")
		own_ids[own.entry.entry_uid] = true
		var definition := CONTENT.definition(own.entry.observation.content_id, int(own.entry.observation.content_version))
		if not definition.is_empty() and definition.get("knowledge") != value.revisions[index].metadata:
			return _error("NB_KNOWLEDGE_IDENTITY")
		var revision: Dictionary = value.revisions[index]
		if revision.observation_ref.segment_id != own.entry.observation.segments[0].segment_id:
			return _error("NB_KNOWLEDGE_OBSERVATION")
		for segment in own.entry.observation.segments:
			if ARCHIVE.make_reference(own.entry, segment.segment_id) not in revision.source_refs:
				return _error("NB_KNOWLEDGE_SOURCE")
	return {"ok": true}


static func acquire(ledger: Dictionary, archive: Dictionary, observation: Dictionary, revision_uid: String, source_refs: Array = []) -> Dictionary:
	var checked := validate(ledger, archive)
	if not checked.ok: return checked
	checked = ARCHIVE.validate_observation(observation)
	if not checked.ok: return checked
	if not _uid(revision_uid): return _error("NB_KNOWLEDGE_REVISION")
	var definition := CONTENT.definition(observation.content_id, int(observation.content_version))
	if definition.is_empty() or not valid_metadata(definition.get("knowledge")) or observation.entry_kind != "document_segment":
		return _error("NB_KNOWLEDGE_DEFINITION")
	checked = CONTENT.render_entry({"record_class": "authored", "observation": observation}, "ko-KR")
	if not checked.ok: return checked
	var segment: Dictionary = observation.segments[0]
	if not definition.locales.has(segment.viewed_locale): return _error("NB_KNOWLEDGE_LOCALE")
	var disclosed := {}
	var texts := PackedStringArray()
	for part in observation.segments:
		if part.viewed_locale != segment.viewed_locale or part.disclosure != segment.disclosure:
			return _error("NB_KNOWLEDGE_DISCLOSURE")
		disclosed[part.segment_id] = part.safe_variables
		texts.append(part.captured_text)
	var descriptor := CONTENT.descriptor(observation.content_id, int(observation.content_version), disclosed)
	checked = CONTENT.observe(descriptor, observation, definition.locales[segment.viewed_locale].speaker, "\n".join(texts), segment.viewed_locale, segment.disclosure)
	if not checked.ok: return checked
	if checked.observation != observation: return _error("NB_KNOWLEDGE_OBSERVATION")
	# Reuse is idempotent only for the same immutable observation and exact sources.
	var latest: Dictionary = {}
	for previous in ledger.revisions:
		if previous.revision_uid == revision_uid:
			var resolved := ARCHIVE.resolve(archive, previous.observation_ref)
			var refs: Array = []
			for part in observation.segments: refs.append(ARCHIVE.make_reference(resolved.entry, part.segment_id))
			for ref in source_refs:
				if ref not in refs: refs.append(ref)
			if resolved.entry.observation != observation or previous.metadata != definition.knowledge or previous.source_refs != refs:
				return _error("NB_KNOWLEDGE_RETRY_CONFLICT")
			return {"ok": true, "ledger": ledger.duplicate(true), "archive": archive.duplicate(true), "changed": false, "revision_uid": revision_uid}
		if previous.metadata.knowledge_id == definition.knowledge.knowledge_id: latest = previous
	var next_archive := archive.duplicate(true)
	# Protect already disclosed sources before append can prune an old normal entry.
	if not source_refs.is_empty():
		var protected_sources := ARCHIVE.add_source_links(next_archive, "knowledge_source", revision_uid, source_refs, int(next_archive.revision))
		if not protected_sources.ok: return protected_sources
		next_archive = protected_sources.archive
	var appended := ARCHIVE.append_observation(next_archive, observation, int(next_archive.revision))
	if not appended.ok: return appended
	if not appended.changed: return _error("NB_KNOWLEDGE_OBSERVATION_REUSED")
	next_archive = appended.archive
	var entry: Dictionary = next_archive.entries.back()
	if entry.entry_uid != appended.entry_uid: return _error("NB_KNOWLEDGE_OBSERVATION")
	var own := ARCHIVE.make_reference(entry, observation.segments[0].segment_id)
	var own_references: Array = []
	for part in observation.segments: own_references.append(ARCHIVE.make_reference(entry, part.segment_id))
	var references: Array = own_references.duplicate(true)
	for ref in source_refs:
		if ref not in references: references.append(ref.duplicate(true))
	var linked := ARCHIVE.add_source_links(next_archive, "knowledge_source", revision_uid, own_references, int(next_archive.revision))
	if not linked.ok: return linked
	next_archive = linked.archive
	var next_ledger := ledger.duplicate(true)
	next_ledger.revisions.append({
		"knowledge_uid": latest.get("knowledge_uid", ARCHIVE.new_uid()), "revision_uid": revision_uid,
		"previous_revision_uid": latest.get("revision_uid", ""), "sequence": int(ledger.revision),
		"metadata": definition.knowledge.duplicate(true), "observation_ref": own, "source_refs": references,
	})
	next_ledger.revision = int(next_ledger.revision) + 1
	checked = validate(next_ledger, next_archive)
	return {"ok": true, "ledger": next_ledger, "archive": next_archive, "changed": true, "revision_uid": revision_uid} if checked.ok else checked


static func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


static func _uid(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number() and value == value.to_lower()


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) < 9007199254740992.0


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id, "error_ids": [id]}
