extends RefCounted

const RULES := preload("res://scripts/systems/journal_four.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const ID := "NB_J4_DOCUMENT"
const QUOTES := {
	"mara1": {"NB_MARA1_RECORD_ORIGINAL_ATTRIBUTION": "mara1_attribution", "NB_MARA1_RECORD_PROTECTED_IDENTIFIERS": "mara1_protected"},
	"iris": {"NB_IRIS_RECORD": "iris_record"},
	"luca": {"NB_LUCA_RECORD": "luca_record"},
	"edgar": {"NB_EDGAR_RECORD": "edgar_record"},
	"mara2": {"NB_MARA2_RECORD": "mara2_record"},
}


static func compose(state: Dictionary) -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	var ledger: Dictionary = knowledge.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
	var checked := KNOWLEDGE.validate(ledger, archive)
	if not checked.ok: return checked
	var latest := {}
	for revision in ledger.revisions: latest[revision.metadata.knowledge_id] = revision
	var totals := RULES.summary(state)
	var segments := {"body": {}}
	var sources: Array = []
	if latest.has("J3"): sources.append(latest.J3.observation_ref.duplicate(true))
	if int(totals.researcher_record_count) >= 2:
		var notes: Dictionary = knowledge.get("chapter_notebook", {})
		for owner in RULES.OWNERS:
			if not state.meta_progress.servants[owner].researcher_record_acquired: continue
			var key := "REC_" + String(owner).to_upper()
			if not notes.has(key):
				segments[owner + "_index"] = {}
				continue
			var original := str(notes[key])
			var quoted := false
			# Identity comes from an acquired revision, never from reverse-matching prose.
			if latest.has(key):
				var resolved := ARCHIVE.resolve(archive, latest[key].observation_ref)
				if not resolved.ok: return resolved
				var observation: Dictionary = resolved.entry.observation
				if int(observation.content_version) == 1 and QUOTES[owner].has(observation.content_id):
					var definition := CONTENT.definition(observation.content_id, 1)
					var segment: String = QUOTES[owner][observation.content_id]
					var document := CONTENT.definition(ID, 1)
					if _source_matches(observation, definition, key, original) and document.locales["ko-KR"][segment] == "\n" + original:
						segments[segment] = {}
						sources.append(latest[key].observation_ref.duplicate(true))
						quoted = true
			if not quoted: segments[owner + "_original"] = {"original_text": original}
	if int(totals.researcher_record_count) == 5 and totals.core_complete_ids.size() == 5: segments.full = {}
	segments.last = {}
	return {"ok": true, "descriptor": CONTENT.descriptor(ID, 1, segments), "source_refs": sources}


static func _source_matches(observation: Dictionary, definition: Dictionary, key: String, original: String) -> bool:
	if definition.is_empty() or definition.knowledge.knowledge_id != key or definition.locales["ko-KR"].body != original or observation.segments.size() != 1:
		return false
	var segment: Dictionary = observation.segments[0]
	return segment.segment_id == "body" and segment.safe_variables.is_empty() and segment.disclosure == "replay_committed" and definition.locales.has(segment.viewed_locale) and segment.captured_text == definition.locales[segment.viewed_locale].body


static func write(state: Dictionary, source_text: String, context: Dictionary, locale: String) -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	if not archive.has("schema_version"): return {"ok": true}
	var composed := compose(state)
	if not composed.ok: return composed
	var original := CONTENT.presentation(composed.descriptor, "ko-KR")
	if not original.ok: return original
	if original.text != source_text: return {"ok": false, "error_ids": ["NB_J4_SOURCE_MISMATCH"]}
	var shown := CONTENT.presentation(composed.descriptor, locale)
	if not shown.ok: return shown
	var frozen := context.duplicate(true)
	for key in ["event_occurrence_id", "conversation_session_id", "presentation_token"]:
		if not frozen.has(key): frozen[key] = ARCHIVE.new_uid()
	var observed := CONTENT.observe(composed.descriptor, frozen, shown.speaker, shown.text, locale, "replay_committed")
	if not observed.ok: return observed
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	var ledger: Dictionary = knowledge.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
	var acquired := KNOWLEDGE.acquire(ledger, archive, observed.observation, ARCHIVE.new_uid(), composed.source_refs)
	if not acquired.ok: return acquired
	knowledge[KNOWLEDGE.KEY] = acquired.ledger
	state.meta_progress.dialogue_history = acquired.archive
	return {"ok": true, "changed": acquired.changed}
