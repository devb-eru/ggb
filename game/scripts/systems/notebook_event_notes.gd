extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func write(state: Dictionary, content_id: String, source_text: String, context: Dictionary, locale: String) -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	if not archive.has("schema_version"): return {"ok": true}
	var row := CONTENT.definition(content_id, 1)
	if row.is_empty(): return {"ok": false, "error_ids": ["NB_EVENT_NOTE_UNMAPPED"]}
	if row.locales["ko-KR"].body != source_text:
		return {"ok": false, "error_ids": ["NB_EVENT_NOTE_SOURCE_MISMATCH"]}
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	var ledger: Dictionary = knowledge.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
	var checked := KNOWLEDGE.validate(ledger, archive)
	if not checked.ok: return checked
	var latest := {}
	for revision in ledger.revisions: latest[revision.metadata.knowledge_id] = revision
	if latest.has(row.knowledge.knowledge_id) and not row.get("new_attempt", false):
		var previous := ARCHIVE.resolve(archive, latest[row.knowledge.knowledge_id].observation_ref)
		if not previous.ok: return previous
		var observed: Dictionary = previous.entry.observation
		if observed.content_id in row.get("superseded_by_content_ids", []):
			return {"ok": true, "changed": false}
		if observed.content_id == content_id and int(observed.content_version) == 1:
			return {"ok": true, "changed": false}
	var sources: Array = []
	for source_id in row.source_knowledge_ids:
		if latest.has(source_id): sources.append(latest[source_id].observation_ref.duplicate(true))
	# Only already-disclosed observations may supplement an event-written source.
	var displayed := {}
	if row.has("source_content_ids"):
		for entry in archive.entries:
			if entry.get("record_class") != "authored": continue
			if entry.observation.content_id in row.source_content_ids:
				displayed[entry.observation.content_id] = entry
	for entry in displayed.values():
		for segment in entry.observation.segments:
			var reference := ARCHIVE.make_reference(entry, segment.segment_id)
			if reference not in sources: sources.append(reference)
	var frozen := context.duplicate(true)
	if not frozen.has("event_occurrence_id"): frozen.event_occurrence_id = ARCHIVE.new_uid()
	if not frozen.has("conversation_session_id"): frozen.conversation_session_id = ARCHIVE.new_uid()
	frozen.presentation_token = ARCHIVE.new_uid()
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	var observation := CONTENT.observe(CONTENT.descriptor(content_id, 1, {"body": {}}), frozen, row.locales[language].speaker, row.locales[language].body, language, "replay_committed")
	if not observation.ok: return observation
	var acquired := KNOWLEDGE.acquire(ledger, archive, observation.observation, ARCHIVE.new_uid(), sources)
	if not acquired.ok: return acquired
	knowledge[KNOWLEDGE.KEY] = acquired.ledger
	state.meta_progress.dialogue_history = acquired.archive
	return {"ok": true, "changed": acquired.changed}
