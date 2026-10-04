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
	if not value is Dictionary or not _keys(value, ["schema_version", "revision", "revisions"]) or not _integer(value.schema_version) or value.schema_version != 1 or not _integer(value.revision) or not value.revisions is Array or value.revision != value.revisions.size():
		return _error("NB_KNOWLEDGE_SCHEMA")
	var latest := {}
	var owners := {}
	var revisions := {}
	var expected_links := {}
	var own_references: Array = []
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
		var own_identity := ARCHIVE.reference_identity(row.observation_ref)
		if own_identity.is_empty() or not row.source_refs is Array or row.source_refs.is_empty():
			return _error("NB_KNOWLEDGE_SOURCE")
		var unique := {}
		for reference in row.source_refs:
			var identity := ARCHIVE.reference_identity(reference)
			if identity.is_empty() or unique.has(identity): return _error("NB_KNOWLEDGE_SOURCE")
			unique[identity] = true
			expected_links[ARCHIVE.source_link_identity({"consumer_kind": "knowledge_source", "consumer_uid": row.revision_uid, "target": reference})] = true
		if not unique.has(own_identity): return _error("NB_KNOWLEDGE_SOURCE")
		own_references.append(row.observation_ref)
		latest[id] = row
		owners[row.knowledge_uid] = id
		revisions[row.revision_uid] = row
	# This validates the whole archive, including every source target, exactly once.
	# Only owning documents need copied bodies for the checks below.
	var resolved := ARCHIVE.resolve_many(archive, own_references)
	if not resolved.ok: return resolved
	var actual := {}
	for link in archive.source_links:
		if link.consumer_kind == "knowledge_source": actual[ARCHIVE.source_link_identity(link)] = true
	if actual.size() != expected_links.size(): return _error("NB_KNOWLEDGE_PROTECTION")
	for link in expected_links:
		if not actual.has(link): return _error("NB_KNOWLEDGE_PROTECTION")
	var own_ids := {}
	for index in range(own_references.size()):
		var own: Dictionary = resolved.items[index]
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
			var link := {"consumer_kind":"knowledge_source", "consumer_uid":revision.revision_uid, "target":ARCHIVE.make_reference(own.entry, segment.segment_id)}
			if not expected_links.has(ARCHIVE.source_link_identity(link)):
				return _error("NB_KNOWLEDGE_SOURCE")
	return {"ok": true}


static func acquire(ledger: Dictionary, archive: Dictionary, observation: Dictionary, revision_uid: String, source_refs: Array = []) -> Dictionary:
	var checked := validate(ledger, archive)
	if not checked.ok: return checked
	checked = ARCHIVE.validate_observation(observation)
	if not checked.ok: return checked
	if not _uid(revision_uid): return _error("NB_KNOWLEDGE_REVISION")
	for ref in source_refs:
		if ARCHIVE.reference_identity(ref).is_empty(): return _error("NB_KNOWLEDGE_SOURCE")
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
			refs = _merge_sources(refs, source_refs)
			if resolved.entry.observation != observation or previous.metadata != definition.knowledge or previous.source_refs.map(ARCHIVE.reference_identity) != refs.map(ARCHIVE.reference_identity):
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
	var references := _merge_sources(own_references, source_refs)
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


static func _merge_sources(own: Array, sources: Array) -> Array:
	var result := own.duplicate(true)
	var ids := {}
	for ref in own: ids[ARCHIVE.reference_identity(ref)] = true
	for ref in sources:
		var identity := ARCHIVE.reference_identity(ref)
		if not ids.has(identity):
			result.append(ref.duplicate(true))
			ids[identity] = true
	return result


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
