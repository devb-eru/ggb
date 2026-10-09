extends RefCounted

const LEGACY := preload("res://scripts/systems/notebook_legacy_feedback.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const SLOT := "__test_notebook_legacy_feedback"
const RAW := {"text": "예전 첫 문단.\n예전 둘째 문단.", "speaker": "주인공", "text_id": "CH1_HISTORY_SAVE_ERROR"}
var errors := PackedStringArray()
var assertions := 0
var serial := 0

class AcceptSave extends Node:
	var calls := 0
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		calls += 1
		return {"ok": true}

class RejectSave extends Node:
	var calls := 0
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		calls += 1
		return {"ok": false, "error_ids": ["TEST_DISK_REJECTION"]}

class LostAck extends Node:
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_ACK"]} if result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		_session_sources(language)
		_rejections(language)
		_historical_context(language)
		_ordinary_then_migrate()
		_unsupported_versions()
		await _display_and_reload(tree, language)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	var result := {"ok": errors.is_empty(), "errors": errors, "assertions": assertions, "strict": WRITER.requires_authored(), "scope": "LEGACY_FEEDBACK_ONLY_NOT_FULL_PRODUCER_OR_OS_ACCEPTANCE"}
	print("NOTEBOOK_LEGACY_FEEDBACK_AUDIT: " + JSON.stringify(result))
	return result


func _fixture(journal: int = 0) -> Dictionary:
	GameState.reset_for_test()
	var state: Dictionary = GameState.get_snapshot()
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.meta_progress.journal_stage = journal
	state.loop_state.location_id = "M2_BEDROOM"
	state.loop_state.event_local_states.CHAPTER_ONE = {"last_feedback": RAW.duplicate(true)}
	return state


func _install(state: Dictionary) -> void:
	serial += 1
	var result := StateWriter.new(GameState).install_snapshot(StateSnapshotValidator.new().normalize(state), GameState.revision, StringName("NB_LEGACY_FIXTURE_%d" % serial))
	_expect(result.ok, "fixture install " + str(result.get("error_ids", [])))


func _session_sources(language: String) -> void:
	var save := AcceptSave.new()
	var scripts := [ChapterOneSession, BlackMirrorSession, BasementSession]
	for index in range(scripts.size()):
		var state := _fixture([0, 2, 3][index])
		_install(state)
		var session: ChapterOneSession = scripts[index].new(GameState, save, SLOT)
		var result := session.initialize()
		_expect(result.ok and result.has(LEGACY.ORIGIN), "old source retained across session hooks " + language)
		if not result.ok or not result.has(LEGACY.ORIGIN): continue
		var origin: Dictionary = result[LEGACY.ORIGIN]
		_expect(origin.feedback == RAW, "raw source preserved without guessed ID")
		_expect(result.history_context.node_id == "LEGACY_UNKNOWN" and result.history_context.location_id == "LEGACY_UNKNOWN", "unknown past metadata is not current stage")
		_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.is_empty(), "initialization is not disclosure")
		var reopened := session.initialize()
		_expect(reopened.get(LEGACY.ORIGIN) == origin, "repeated initialization preserves source identity")
		var encoded: Variant = JSON.parse_string(JSON.stringify(GameState.get_snapshot()))
		_install(encoded)
		var reloaded := session.initialize()
		_expect(StateSnapshotValidator.same_persisted_value(reloaded.get(LEGACY.ORIGIN), origin), "JSON reload preserves origin")
		var candidate := GameState.get_snapshot()
		var context := LEGACY.line_context(origin, 0)
		var first := WRITER.append_to_snapshot(candidate, RAW.speaker, "예전 첫 문단.", language, "LEGACY", [], context)
		_expect(first.ok and first.changed, "old actually displayed paragraph records")
		if not first.ok: continue
		var entry: Dictionary = candidate.meta_progress.dialogue_history.entries.back()
		_expect(entry.record_class == "legacy" and not entry.has("observation"), "no authored ID backfill or new unmapped")
		var before := candidate.duplicate(true)
		var retry := WRITER.append_to_snapshot(candidate, RAW.speaker, "예전 첫 문단.", "en-US" if language == "ko-KR" else "ko-KR", "LEGACY", [], context)
		_expect(retry.ok and not retry.changed and retry.entry_uid == first.entry_uid and candidate == before, "cross-language redisplay deduplicates without translating source")
		var fork := ARCHIVE.fork(candidate.meta_progress.dialogue_history)
		_expect(fork.ok, "legacy source survives archive fork")
		candidate.meta_progress.dialogue_history = fork.archive
		retry = WRITER.append_to_snapshot(candidate, RAW.speaker, "예전 첫 문단.", language, "LEGACY", [], context)
		_expect(retry.ok and not retry.changed and retry.entry_uid == first.entry_uid, "branch change does not rewrite original source")
		for mutation in ["text", "token", "source", "chapter"]:
			var corrupt: Dictionary = candidate.meta_progress.dialogue_history.duplicate(true)
			match mutation:
				"text": corrupt.entries.back().legacy_payload.variables.text += " forged"
				"token": corrupt.entries.back().snapshot_context.presentation_token = ARCHIVE.new_uid()
				"source": corrupt.entries.back()[LEGACY.MARKER].source_origin_id = ARCHIVE.new_uid()
				"chapter": corrupt.entries.back().chapter_id = "CHAPTER_4"
			_expect(not ARCHIVE.validate(corrupt).ok, "marked legacy rejects tampering " + mutation)
		if index == 0:
			var fresh := session.act("mark", "sentence")
			_expect(fresh.ok and not fresh.has(LEGACY.ORIGIN), "new action clears legacy exception")
			var current := GameState.get_snapshot()
			var last: Dictionary = current.loop_state.event_local_states.CHAPTER_ONE.last_feedback
			_expect(last.get(LEGACY.STAMP) == 1 and not last.has(LEGACY.ORIGIN), "new producer stamped permanently")
			last.erase("notebook_feedback")
			_install(JSON.parse_string(JSON.stringify(current)))
			var new_resume := session.initialize()
			_expect(new_resume.ok and not new_resume.has(LEGACY.ORIGIN), "new missing ID cannot become old after reload")
			var raw_context: Dictionary = new_resume.history_context.duplicate(true)
			var missing := WRITER.append_to_snapshot(current, new_resume.speaker, new_resume.text, language, "CHAPTER_1", [], raw_context)
			_expect(missing.ok != WRITER.requires_authored(), "new missing ID follows strict policy, not legacy exception")
	save.free()


func _rejections(language: String) -> void:
	var save := AcceptSave.new()
	_install(_fixture())
	var session := ChapterOneSession.new(GameState, save, SLOT)
	var result := session.initialize()
	if not result.ok or not result.has(LEGACY.ORIGIN):
		_expect(false, "rejection fixture initializes")
		save.free()
		return
	var origin: Dictionary = result[LEGACY.ORIGIN]
	for mutation in ["bool", "id", "index", "token", "node", "event", "location", "text", "speaker", "facts", "descriptor", "receipt", "source", "last_text", "stamp"]:
		var state := GameState.get_snapshot()
		var context := LEGACY.line_context(origin, 0)
		var text := "예전 첫 문단."
		var speaker: String = RAW.speaker
		var facts := []
		match mutation:
			"bool": context[LEGACY.REPLAY] = true
			"id": context[LEGACY.REPLAY].source_id = "f".repeat(64)
			"index": context[LEGACY.REPLAY].paragraph_index = 99
			"token": context.presentation_token = ARCHIVE.new_uid()
			"node": context.node_id = "A1"
			"event": context.event_occurrence_id = ARCHIVE.new_uid()
			"location": context.location_id = "M2_BEDROOM"
			"text": text += " forged"
			"speaker": speaker = "루카"
			"facts": facts = ["FACT_UNSUPPORTED_TEST"]
			"descriptor": context.notebook_content = {}
			"receipt": context.surface_receipt = {}
			"source": state.meta_progress.dialogue_history.source_origin_id = ARCHIVE.new_uid()
			"last_text": state.loop_state.event_local_states.CHAPTER_ONE.last_feedback.text += " new action"
			"stamp": state.loop_state.event_local_states.CHAPTER_ONE.last_feedback[LEGACY.STAMP] = 2
		var before := state.duplicate(true)
		var rejected := WRITER.append_to_snapshot(state, speaker, text, language, "LEGACY", facts, context)
		_expect(not rejected.ok and "NB_LEGACY_FEEDBACK_PROVENANCE" in rejected.get("error_ids", []), "bad provenance rejected " + mutation)
		_expect(state == before, "rejected proof never mutates candidate " + mutation)
	var rejecting := RejectSave.new()
	var before := GameState.get_snapshot()
	var revision: int = GameState.revision
	var bad := LEGACY.line_context(origin, 0)
	bad[LEGACY.REPLAY] = true
	_expect(not WRITER.record(GameState, rejecting, SLOT, "SAVE_CAMPAIGN_PROGRESS", RAW.speaker, "예전 첫 문단.", language, "LEGACY", [], bad).ok, "invalid proof rejects before persistence")
	_expect(rejecting.calls == 0 and GameState.get_snapshot() == before and GameState.revision == revision, "invalid proof never installs or saves")
	rejecting.free()
	save.free()


func _display_and_reload(tree: SceneTree, language: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	_install(_fixture())
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	_expect(view._dialogue_active and view._dialogue_label.text == "예전 첫 문단.", "controller preserves raw body despite text_id and UI language")
	var state := GameState.get_snapshot()
	var entries: Array = state.meta_progress.dialogue_history.entries
	var legacy: Array = entries.filter(func(entry: Dictionary) -> bool: return entry.has(LEGACY.MARKER))
	_expect(legacy.size() == 1 and legacy[0].legacy_payload.variables.text == "예전 첫 문단.", "only first visible paragraph archived")
	_expect(entries.all(func(entry: Dictionary) -> bool: return entry.record_class != "unmapped"), "controller creates no new unmapped")
	var cursor := PRESENTATION.read(state)
	_expect(not cursor.is_empty() and PRESENTATION.observed(cursor, state), "legacy token participates in observed presentation cursor")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real disk reload succeeds")
	_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "raw origin and first paragraph survive disk roundtrip")
	var after_load := view.session.initialize()
	_expect(after_load.ok and view._restore_presentation(), "saved presentation restores without source regeneration")
	view._advance_dialogue()
	_expect(view._dialogue_index == 1 and view._dialogue_label.text == "예전 둘째 문단.", "next old paragraph shown after restore")
	legacy = GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.has(LEGACY.MARKER))
	_expect(legacy.size() == 2 and legacy[0].entry_uid != legacy[1].entry_uid, "paragraphs have distinct stable observation identities")
	view._advance_dialogue()
	var before := GameState.get_snapshot()
	view._feedback(view.session.initialize())
	var rejecting := RejectSave.new()
	var saved: Node = view.session._save
	# Existing observed paragraphs are retries, so use an unobserved third-party old source.
	var another := _fixture()
	another.loop_state.event_local_states.CHAPTER_ONE.last_feedback.text = "미표시 원문.\n다음 원문."
	_install(another)
	var pending := view.session.initialize()
	before = GameState.get_snapshot()
	view.session._save = rejecting
	view._feedback(pending)
	_expect(view._dialogue_index == 0 and GameState.get_snapshot() == before, "save rejection preserves pending origin and archive")
	view._advance_dialogue()
	_expect(view._dialogue_index == 0 and GameState.get_snapshot() == before, "failed retry cannot disclose next paragraph")
	view.session._save = saved
	var lost := LostAck.new()
	lost.delegate = saved
	view.session._save = lost
	_expect(view._record_current_history_line(), "confirmed lost acknowledgement records old visible paragraph")
	var acknowledged := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "lost acknowledgement reloads committed value")
	_expect(StateSnapshotValidator.same_persisted_value(acknowledged, GameState.get_snapshot()), "lost acknowledgement retains exact origin and UID")
	view.session._save = saved
	view._advance_dialogue()
	view._advance_dialogue()
	rejecting.free()
	lost.free()
	view.queue_free()
	await tree.process_frame


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value: errors.append(message)


func _historical_context(language: String) -> void:
	var save := AcceptSave.new()
	var state := _fixture()
	state.loop_state.event_local_states.CHAPTER_ONE.last_feedback.history_context = {"node_id": "D4", "chapter_id": "CHAPTER_2", "location_id": "M0_CLOCK_HEART", "old_detail": "보관한 출처"}
	_install(state)
	var session := ChapterOneSession.new(GameState, save, SLOT)
	var resumed := session.initialize()
	_expect(resumed.ok and resumed.has(LEGACY.ORIGIN), "explicit old context accepted")
	if not resumed.ok or not resumed.has(LEGACY.ORIGIN):
		save.free()
		return
	var origin: Dictionary = resumed[LEGACY.ORIGIN]
	_expect(origin.feedback.history_context == state.loop_state.event_local_states.CHAPTER_ONE.last_feedback.history_context, "original historical metadata preserved exactly")
	var context := LEGACY.line_context(origin, 0)
	state = GameState.get_snapshot()
	var result := WRITER.append_to_snapshot(state, RAW.speaker, "예전 첫 문단.", language, "CHAPTER_2", [], context)
	_expect(result.ok and state.meta_progress.dialogue_history.entries.back().chapter_id == "CHAPTER_2", "old node chapter used instead of current A1")
	if not result.ok:
		save.free()
		return
	var archive: Dictionary = state.meta_progress.dialogue_history
	var ref := ARCHIVE.make_reference(archive.entries.back(), "legacy")
	var marked := ARCHIVE.set_reference(archive, "bookmarks", ref, true, int(archive.revision))
	_expect(marked.ok and not marked.archive.entries.back().protection_reasons.is_empty(), "legacy replay uses existing bookmark protection")
	var compared := ARCHIVE.set_reference(marked.archive, "comparison", ref, true, int(marked.archive.revision))
	_expect(compared.ok and ARCHIVE.resolve(compared.archive, ref).ok, "legacy source can be compared and resolved")
	var unmapped_context := context.duplicate(true)
	unmapped_context.erase(LEGACY.REPLAY)
	unmapped_context.presentation_token = ARCHIVE.new_uid()
	var payload := {"chapter_id": "CHAPTER_2", "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": RAW.speaker, "text": "以前の既存記録"}, "viewed_locale": language}
	var existing := ARCHIVE.append_unmapped(compared.archive, payload, unmapped_context, int(compared.archive.revision))
	_expect(existing.ok, "existing transitional archive fixture accepted")
	if existing.ok:
		var maintained := ARCHIVE.maintain(existing.archive, int(existing.archive.revision))
		_expect(maintained.ok and maintained.archive.entries.back().record_class == "unmapped" and maintained.archive.entries.back().legacy_payload == existing.archive.entries.back().legacy_payload, "preexisting unmapped is never retroactively reclassified")
		var collision := ARCHIVE.append_unmapped(existing.archive, payload, context, int(existing.archive.revision))
		_expect(not collision.ok, "new token cannot collide with legacy replay")
	save.free()


func _ordinary_then_migrate() -> void:
	var save := AcceptSave.new()
	var scripts := [ChapterOneSession, BlackMirrorSession, BasementSession]
	for index in range(scripts.size()):
		var state := _fixture([0, 2, 3][index])
		state.meta_progress.dialogue_history = {"next_sequence": 0, "entries": []}
		_install(state)
		var session: ChapterOneSession = scripts[index].new(GameState, save, SLOT)
		var old := session.initialize()
		_expect(old.ok and not old.has(LEGACY.ORIGIN), "ordinary replay does not introduce v2 provenance")
		state = GameState.get_snapshot()
		_expect(state.loop_state.event_local_states.CHAPTER_ONE.last_feedback == RAW, "ordinary initialization preserves old pending bytes/metadata")
		var converted := ARCHIVE.migrate_verified_legacy(state.meta_progress.dialogue_history, JSON.stringify(state, "", true).sha256_text())
		_expect(converted.ok, "ordinary replay archive migrates")
		state.meta_progress.dialogue_history = converted.archive
		_install(state)
		var migrated := session.initialize()
		_expect(migrated.ok and migrated.has(LEGACY.ORIGIN) and migrated[LEGACY.ORIGIN].feedback == RAW, "later v2 migration recognizes original old source without guessed current room")
	save.free()


func _unsupported_versions() -> void:
	var save := AcceptSave.new()
	for versioned in [false, true]:
		for value in [2, "1", true]:
			var state := _fixture()
			if not versioned: state.meta_progress.dialogue_history = {"next_sequence": 0, "entries": []}
			state.loop_state.event_local_states.CHAPTER_ONE.last_feedback[LEGACY.STAMP] = value
			_install(state)
			var before := GameState.get_snapshot()
			var revision: int = GameState.revision
			var result := ChapterOneSession.new(GameState, save, SLOT).initialize()
			_expect(not result.ok and "NB_LEGACY_FEEDBACK_PROVENANCE" in result.get("error_ids", []), "unsupported producer stamp rejects")
			_expect(GameState.get_snapshot() == before and GameState.revision == revision and save.calls == 0, "unsupported producer metadata is not downgraded or saved")
	save.free()
