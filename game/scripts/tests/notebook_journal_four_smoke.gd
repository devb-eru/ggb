extends RefCounted

const NOTES := preload("res://scripts/systems/journal_four_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const SLOT := "__test_notebook_journal_four"
var errors := PackedStringArray()
var cases := 0
var segments := {}
var base: Dictionary

class ControlledSave extends Node:
	var reject := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_J4_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_J4_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run() -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var fixture := CHECKPOINTS.new().snapshot_for("J4")
	if not fixture.ok: return fixture
	base = fixture.snapshot
	base.meta_progress.dialogue_history = ARCHIVE.create()
	base.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	base.loop_state.event_local_states.J4 = {"pages": NOTES.RULES.ORDER.duplicate(), "ordered": true}
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		for outcome in range(2):
			var acquired := _acquired(outcome)
			for mask in range(32): _check_matrix(_mask(acquired, mask), language)
		_legacy_cases(language)
		_atomic_session(language)
	_multisegment_guards()
	for segment in CONTENT.definition(NOTES.ID, 1).visible_segment_ids:
		_expect(segments.has(segment), "uncovered J4 segment: " + segment)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "document_cases": cases, "covered_segments": segments.size(), "not_covered": ["J4_confirmation_and_feedback_IDs", "E3_4M_display_IDs", "unified_notebook_UI", "OS_input"]}


func _context(node: String = "J4") -> Dictionary:
	return {"chapter_id": "CHAPTER_3", "node_id": node, "location_id": "M1_CENTRAL_HALL", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}


func _acquired(outcome: int) -> Dictionary:
	var state := base.duplicate(true)
	var notes: Dictionary = state.meta_progress.knowledge_entries.get("chapter_notebook", {})
	for owner in NOTES.RULES.OWNERS:
		var ids: Array = NOTES.QUOTES[owner].keys()
		var id: String = ids[outcome if owner == "mara1" else 0]
		var definition := CONTENT.definition(id, 1)
		notes["REC_" + String(owner).to_upper()] = definition.locales["ko-KR"].body
		var result := EVENT_NOTES.write(state, id, definition.locales["ko-KR"].body, _context(definition.node_ids[0]), TranslationServer.get_locale())
		_expect(result.ok, "source acquisition: " + id)
	state.meta_progress.knowledge_entries.chapter_notebook = notes
	return state


func _mask(source: Dictionary, mask: int) -> Dictionary:
	var state := source.duplicate(true)
	for index in range(5):
		var complete := (mask & (1 << index)) != 0
		var owner: String = NOTES.RULES.OWNERS[index]
		state.meta_progress.servants[owner].core_event_complete = complete
		state.meta_progress.servants[owner].researcher_record_acquired = complete
	return state


func _check_matrix(state: Dictionary, locale: String) -> void:
	var before := state.duplicate(true)
	var composed := NOTES.compose(state)
	_expect(composed.ok and state == before, "composition is pure")
	if not composed.ok: return
	var restored := NOTES.RULES.apply(state, "read", null)
	_expect(restored.ok, "original journal read accepts fixture")
	if not restored.ok: return
	var shown := CONTENT.presentation(composed.descriptor, "ko-KR")
	_expect(shown.ok and shown.text == restored.text, "every quoted source, separator and original sentence preserved")
	var result := NOTES.write(restored.state, restored.text, _context(), locale)
	_expect(result.ok, "composed document acquired: " + str(result))
	if not result.ok: return
	var archive: Dictionary = restored.state.meta_progress.dialogue_history
	var ledger: Dictionary = restored.state.meta_progress.knowledge_entries[KNOWLEDGE.KEY]
	var revision: Dictionary = ledger.revisions.back()
	var entry: Dictionary = ARCHIVE.resolve(archive, revision.observation_ref).entry
	_expect(entry.observation.node_id == "J4" and entry.observation.chapter_id == "CHAPTER_3", "read event not post-read minimum-access stage")
	var translated := CONTENT.render_entry(entry, "en-US" if locale == "ko-KR" else "ko-KR")
	_expect(translated.ok, "opposite-language rendering")
	var originals := false
	for segment in entry.observation.segments:
		segments[segment.segment_id] = true
		originals = originals or segment.segment_id.ends_with("_original")
		_expect(ARCHIVE.make_reference(entry, segment.segment_id) in revision.source_refs, "each disclosed own segment protected")
	_expect(translated.entry.fallback == originals, "only unidentified old quotations use original-only notice")
	var total := NOTES.RULES.summary(state)
	for owner in NOTES.RULES.OWNERS:
		var included := false
		for key in composed.descriptor.segments:
			if String(key).begins_with(owner + "_"): included = true
		_expect(included == (total.researcher_record_count >= 2 and state.meta_progress.servants[owner].researcher_record_acquired), "no unacquired quotation: " + owner)
	_expect(composed.descriptor.segments.has("full") == (total.researcher_record_count == 5 and total.core_complete_ids.size() == 5), "full passage requires both five records and five completions")
	var persisted: Dictionary = JSON.parse_string(JSON.stringify({"archive": archive, "ledger": ledger}))
	_expect(KNOWLEDGE.validate(persisted.ledger, persisted.archive).ok, "multi-segment JSON round trip")
	var retry := KNOWLEDGE.acquire(ledger, archive, entry.observation, revision.revision_uid, composed.source_refs)
	_expect(retry.ok and not retry.changed and retry.archive == archive and retry.ledger == ledger, "exact composed retry does not append")
	_expect(restored.state.meta_progress.servants == state.meta_progress.servants, "document acquisition awards no relationships")
	cases += 1


func _legacy_cases(locale: String) -> void:
	var state := _mask(base, 31)
	state.meta_progress.knowledge_entries.chapter_notebook = {}
	_check_matrix(state, locale)
	for owner in NOTES.RULES.OWNERS:
		state.meta_progress.knowledge_entries.chapter_notebook["REC_" + String(owner).to_upper()] = "옛 원문 {original_text} / " + owner + "\nSecond line <not markup>"
	_check_matrix(state, locale)
	var composed := NOTES.compose(state)
	var rendered := CONTENT.presentation(composed.descriptor, "en-US")
	_expect(rendered.text.contains("옛 원문 {original_text}") and rendered.text.contains("Second line <not markup>"), "original is not retokenized or silently translated")
	_expect(composed.source_refs.is_empty(), "old prose cannot invent source acquisitions")
	var known := _acquired(0)
	state = _mask(known, 31)
	state.meta_progress.knowledge_entries.chapter_notebook.REC_MARA1 = "수정된 옛 기록"
	composed = NOTES.compose(state)
	_expect(composed.descriptor.segments.has("mara1_original") and composed.source_refs.size() == 4, "mismatched old prose cannot quote the stale identified source")
	_check_matrix(state, locale)
	state = _mask(known, 31)
	state.meta_progress.servants.edgar.core_event_complete = false
	_check_matrix(state, locale)
	state = _mask(known, 31)
	state.meta_progress.servants.edgar.researcher_record_acquired = false
	_check_matrix(state, locale)
	# Matching prose without provenance remains an explicitly unidentified original.
	state = _mask(known, 31)
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	composed = NOTES.compose(state)
	_expect(composed.descriptor.segments.has("mara1_original") and composed.source_refs.is_empty(), "never reverse-match known prose to a research identity")
	_check_matrix(state, locale)
	var old := state.duplicate(true)
	old.meta_progress.dialogue_history = {"next_sequence": 0, "entries": []}
	var before := old.duplicate(true)
	_expect(NOTES.write(old, "legacy", _context(), locale).ok and old == before, "legacy-only mode neither migrates nor backfills")


func _atomic_session(locale: String) -> void:
	var state := _mask(_acquired(0), 0)
	GameState.reset_for_test()
	var installed := StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"J4_ATOMIC_FIXTURE")
	_expect(installed.ok, "valid atomic fixture: " + str(installed))
	if not installed.ok: return
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "J4_ATOMIC_FIXTURE").ok, "initial disk save")
	var saver := ControlledSave.new()
	var session := BasementSession.new(GameState, saver, SLOT)
	var before := session.snapshot()
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var bytes := FileAccess.get_file_as_bytes(paths.main)
	saver.reject = true
	_expect(not session.act("j4_read").ok and session.snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == bytes, "failed save rolls back journal stage, raw note, ledger and archive")
	saver.reject = false
	saver.lose_ack = true
	var result := session.act("j4_read")
	_expect(result.ok and session.stage() == "E3_4M", "disk-confirmed lost acknowledgement commits J4 exactly once")
	var committed := session.snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(committed, GameState.get_snapshot()), "actual JSON save reload")
	var ledger: Dictionary = committed.meta_progress.knowledge_entries[KNOWLEDGE.KEY]
	_expect(ledger.revisions.filter(func(row: Dictionary) -> bool: return row.metadata.knowledge_id == "J4").size() == 1, "single acquired J4 revision")
	var entry: Dictionary = ARCHIVE.resolve(committed.meta_progress.dialogue_history, ledger.revisions.back().observation_ref).entry
	_expect(entry.observation.location_id == before.loop_state.location_id and entry.observation.segments[0].viewed_locale == locale, "acquisition freezes pre-transition location and language")
	_expect(not session.act("j4_read").ok and session.snapshot() == committed, "repeat restored read cannot duplicate the note")
	var servants: Dictionary = committed.meta_progress.servants.duplicate(true)
	_expect(session.act("j4_minimum").ok and session.stage() == "E5", "zero-record path still reaches evening")
	_expect(session.snapshot().meta_progress.servants == servants and session.snapshot().meta_progress.knowledge_entries[KNOWLEDGE.KEY] == ledger, "minimum access does not add a relationship or researcher record")
	saver.free()


func _multisegment_guards() -> void:
	var state := _mask(_acquired(0), 31)
	var restored := NOTES.RULES.apply(state, "read", null)
	_expect(NOTES.write(restored.state, restored.text, _context(), "ko-KR").ok, "guard fixture")
	var archive: Dictionary = restored.state.meta_progress.dialogue_history
	var ledger: Dictionary = restored.state.meta_progress.knowledge_entries[KNOWLEDGE.KEY]
	var revision: Dictionary = ledger.revisions.back()
	var entry: Dictionary = ARCHIVE.resolve(archive, revision.observation_ref).entry
	for mode in ["text", "locale", "order", "disclosure"]:
		var observed: Dictionary = entry.observation.duplicate(true)
		observed.presentation_token = ARCHIVE.new_uid()
		match mode:
			"text": observed.segments[1].captured_text += " forged"
			"locale": observed.segments[1].viewed_locale = "en-US"
			"order": observed.segments.reverse()
			"disclosure": observed.segments[1].disclosure = "displayed"
		_expect(not KNOWLEDGE.acquire(ledger, archive, observed, ARCHIVE.new_uid()).ok, "reject changed composed " + mode)
	var lost := ledger.duplicate(true)
	lost.revisions.back().source_refs.remove_at(1)
	var unlinked := archive.duplicate(true)
	var target: Dictionary = revision.source_refs[1]
	unlinked.source_links = unlinked.source_links.filter(func(link: Dictionary) -> bool: return not (link.consumer_uid == revision.revision_uid and link.target == target))
	# Even matching link removal must not leave an unprotected own segment.
	_expect(not KNOWLEDGE.validate(lost, unlinked).ok, "reject missing disclosed own segment source")
	var before := state.duplicate(true)
	_expect(not NOTES.write(state, "wrong source", _context(), "ko-KR").ok and state == before, "source mismatch fails before any mutation")
	var row := CONTENT.definition(NOTES.ID, 1)
	_expect(not EVENT_NOTES.write(state, NOTES.ID, row.locales["ko-KR"].body, _context(), "ko-KR").ok and state == before, "single-body writer cannot truncate a composed document")
	var source_id := "NB_MARA1_RECORD_ORIGINAL_ATTRIBUTION"
	var source := CONTENT.definition(source_id, 1)
	var observed_source: Dictionary = state.meta_progress.dialogue_history.entries[0].observation.duplicate(true)
	observed_source.segments[0].captured_text = "changed"
	_expect(not NOTES._source_matches(observed_source, source, "REC_MARA1", source.locales["ko-KR"].body), "changed source capture cannot authenticate a quote")
	for invalid in ["mara1_original", ["unknown"], ["mara1_original", "mara1_original"], [false]]:
		var broken := row.duplicate(true)
		broken.original_only_segments = invalid
		_expect(not CONTENT._valid_row(broken), "invalid original-only metadata rejected")


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
