extends RefCounted

const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const NOTES := preload("res://scripts/systems/chapter_one_notes.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const SLOT := "__test_notebook_chapter_one_notes"
var errors := PackedStringArray()
var covered := {}
var serial := 0

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": ["ERR_TEST_NOTE_SAVE"]}

class LostAcknowledgement extends Node:
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_ACK"]} if result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var language := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostics := CONTENT.diagnostics()
	if not diagnostics.ok: return {"ok": false, "errors": diagnostics.error_ids}
	var ids: Array = diagnostics.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP06")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		_route(locale)
		for id in ids: _expect(covered.has(id + ":" + locale), "missing acquisition: " + id + ":" + locale)
	await _persistence_and_legacy(tree)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(language)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "guard_fixture": "BF_PHASE_UNSET", "not_covered": ["NP05", "NP07+", "new_notebook_UI", "OS_input"]}


func _seed() -> ChapterOneSession:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var state := GameState.get_snapshot()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.loop_state.day_index = 1
	_install(state)
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().ok, "session initializes")
	return session


func _route(locale: String) -> void:
	var session: ChapterOneSession
	for mark in SESSION.MARKS:
		session = _seed()
		_act(session, "mark", mark)
		var first: Dictionary = _latest("CH1_SELF_MARK").duplicate(true)
		_expect(first.metadata.epistemic_state == "hypothesis", "unconfirmed mark remains a hypothesis")
		_act(session, "routine")
		var ledger := _ledger().duplicate(true)
		_expect(session.sleep().ok and _ledger() == ledger, "physical reset preserves mark revision without acquiring anything")
		_act(session, "confirm_mark")
		var confirmed := _latest("CH1_SELF_MARK")
		_expect(confirmed.knowledge_uid == first.knowledge_uid and confirmed.previous_revision_uid == first.revision_uid and confirmed.metadata.epistemic_state == "verified", "A2 verifies the same card through a new revision")
		_expect(_ledger().revisions[0] == first and first.observation_ref in confirmed.source_refs, "verification protects the immutable A1 source")
		_collect(locale)
	_travel(session, "M1_SERVANT_COMMON")
	for owner in ["edgar", "luca", "mara1", "mara2"]: _act(session, "read_schedule", owner)
	var unchanged := _ledger().duplicate(true)
	_act(session, "read_schedule", "edgar")
	_expect(_ledger() == unchanged, "reinspecting unchanged schedule does not acquire a revision")
	_act(session, "schedule_window", "after_tea_before_bell")
	_expect(_latest("CH1_LIBRARY_WINDOW").source_refs.size() == 5, "library inference cites the four actually acquired schedules and its own text")
	_act(session, "routine")
	_travel(session, "M1_LIBRARY_OUTER")
	_act(session, "move", "M1_LIBRARY_INNER")
	_act(session, "inspect_inner", "desk")
	for index in range(3):
		_act(session, "j1_piece", index)
		_act(session, "j1_flip", index)
	_act(session, "j1_restore")
	var first_journal: Dictionary = ARCHIVE.resolve(GameState.get_snapshot().meta_progress.dialogue_history, _latest("CH1_J1").observation_ref).entry
	_expect(first_journal.observation.segments[0].disclosure == "replay_committed" and _latest("CH1_J1").metadata.provenance_state == "unverified", "restored journal is authored text, not a claim about its writer or a viewed dialogue")
	for room in SESSION.CLOCK_ROOMS:
		_travel(session, room)
		_act(session, "rub_clock")
		var card := _latest("CH1_CLOCK_" + String(SESSION.CLOCK_ROOMS[room]).to_upper())
		_expect(card.metadata.lifetime == "persistent", "clock observation is not the expendable physical rubbing")
	_solve_board(session)
	_act(session, "board_check")
	_expect(_latest("CH1_CLOCK_LAYOUT").source_refs.size() == 5, "layout cites four disclosed clock observations")
	var failure_rows: Array = []
	for role in CLOCK.ROLES:
		var roles := CLOCK.SOLUTION.duplicate()
		roles.erase(role)
		_set_clock(session, roles, "0")
		var before_test := _ledger().duplicate(true)
		_act(session, "test_clock")
		_expect(_ledger() == before_test, "weak check does not write a failure note")
		_act(session, "activate_clock", true)
		failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
		var locked_ledger := _ledger().duplicate(true)
		_expect(not session.act("activate_clock", true).ok and _ledger() == locked_ledger, "locked same-day retry cannot manufacture a new failure record")
	for phase in ["-1", "0", "HALF", "unset"]:
		_set_clock(session, CLOCK.SOLUTION, phase)
		_act(session, "activate_clock", true)
		failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
	# A distinct same-diagnosis attempt must not be deduplicated as rereading.
	_set_clock(session, CLOCK.SOLUTION, "0")
	_act(session, "activate_clock", true)
	failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
	for index in range(1, failure_rows.size()):
		_expect(failure_rows[index].knowledge_uid == failure_rows[0].knowledge_uid and failure_rows[index].previous_revision_uid == failure_rows[index - 1].revision_uid, "every actual failure keeps its own immutable attempt")
	_travel(session, "M2_BEDROOM")
	var before_sleep := _ledger().duplicate(true)
	_expect(session.sleep().ok and _ledger() == before_sleep, "sleep keeps all failure records and sources")
	_expect(session.local_state().rubbed.is_empty(), "physical rubbings still reset")
	_act(session, "shortcut")
	_act(session, "phase", "+1")
	_act(session, "activate_clock", true)
	var before_wave := _ledger().duplicate(true)
	var before_wave_state := GameState.get_snapshot()
	var rejecting := RejectingSave.new()
	var rejected := SESSION.new(GameState, rejecting, SLOT)
	_expect(not rejected.act("record_wave").ok and GameState.get_snapshot() == before_wave_state, "failed waveform save rolls back both new revisions and the resolved gameplay flag")
	rejecting.free()
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = SaveManager
	var recovering := SESSION.new(GameState, lost_ack, SLOT)
	_expect(recovering.act("record_wave").ok, "lost acknowledgement confirms the two-note transaction")
	lost_ack.free()
	_expect(_ledger().revision == before_wave.revision + 2, "waveform and resolved failure are committed together")
	var resolved := _latest("CH1_CLOCK_FAILURE")
	_expect(resolved.previous_revision_uid == failure_rows.back().revision_uid and failure_rows.back().observation_ref in resolved.source_refs and _latest("CH1_WAVEFORM").observation_ref in resolved.source_refs, "resolution links previous failure and actual waveform without erasing history")
	var archive: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history
	var wave_observation: Dictionary = ARCHIVE.resolve(archive, _latest("CH1_WAVEFORM").observation_ref).entry.observation
	var resolved_observation: Dictionary = ARCHIVE.resolve(archive, resolved.observation_ref).entry.observation
	_expect(wave_observation.event_occurrence_id == resolved_observation.event_occurrence_id and wave_observation.conversation_session_id == resolved_observation.conversation_session_id and wave_observation.presentation_token != resolved_observation.presentation_token, "B4 notes share one event and writing batch but distinct observation tokens")
	var after_wave := _ledger().duplicate(true)
	_act(session, "record_wave")
	_expect(_ledger() == after_wave, "repeated waveform recording does not duplicate resolution")
	_travel(session, "M1_LIBRARY_OUTER")
	_act(session, "move", "M1_LIBRARY_INNER")
	for index in range(3): _act(session, "wave_rotate")
	_act(session, "restore_j2")
	_expect(_latest("CH1_J2").source_refs.size() == 3, "J2 cites the first page and the recorded waveform")
	for previous in before_wave.revisions:
		_expect(previous in _ledger().revisions, "all old revisions survive success and restoration")
	_collect(locale)
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "actual slot round-trip preserves cards and typed source links")


func _persistence_and_legacy(tree: SceneTree) -> void:
	var session := _seed()
	var legacy := GameState.get_snapshot()
	legacy.meta_progress.notebook_persistence_confirmed = true
	legacy.meta_progress.knowledge_entries.chapter_notebook = {"A1": "기존 표식: 작성 시점 미상", "BF": "예전의 마지막 실패 메모"}
	legacy.loop_state.location_id = "M1_SERVANT_COMMON"
	_install(legacy)
	_expect(session.initialize().ok and not GameState.get_snapshot().meta_progress.knowledge_entries.has(KNOWLEDGE.KEY), "old strings do not create invented acquisition histories")
	var before := GameState.get_snapshot()
	var rejecting := RejectingSave.new()
	var failed := SESSION.new(GameState, rejecting, SLOT)
	_expect(not failed.act("read_schedule", "edgar").ok and GameState.get_snapshot() == before, "failure rolls back legacy note, schedule flag, source protection and revision atomically")
	rejecting.free()
	_act(session, "read_schedule", "edgar")
	_expect(_ledger().revision == 1 and _latest("CH1_SELF_MARK").is_empty(), "retry acquires only the new actual document")
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = SaveManager
	var recovering := SESSION.new(GameState, lost_ack, SLOT)
	_expect(recovering.act("read_schedule", "luca").ok, "lost acknowledgement confirms complete note transaction")
	lost_ack.free()
	var committed := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(committed, GameState.get_snapshot()), "confirmed note transaction survives reload")
	var bad := GameState.get_snapshot()
	_expect(not NOTES.write(bad, "J1", "not the authored source", session.history_context(), "ko-KR").ok and bad == GameState.get_snapshot(), "mismatching source cannot write a candidate")
	var unobserved := _latest("CH1_LIBRARY_WINDOW")
	_expect(unobserved.is_empty(), "loading documents does not auto-solve the inference")
	_act(session, "schedule_window", "after_tea_before_bell")
	_expect(_latest("CH1_LIBRARY_WINDOW").source_refs.size() == 3, "inference cites only actually acquired documents, not other catalog entries")
	var view := preload("res://scripts/chapters/chapter_one_controller.gd").new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	var before_read := GameState.get_snapshot()
	view._open_notebook()
	view._close_modal()
	_expect(GameState.get_snapshot() == before_read, "existing notebook consumer never writes acquisition or resolves hypotheses")
	view.queue_free()
	await tree.process_frame


func _set_clock(session: ChapterOneSession, roles: Dictionary, phase: String) -> void:
	var state := GameState.get_snapshot()
	var local := session.local_state(state)
	local.clock_locked = false
	local.signal_generated = false
	local.roles = roles.duplicate()
	local.phase = phase
	state.loop_state.event_local_states.CHAPTER_ONE = local
	state.loop_state.location_id = "M1_GREAT_CLOCK"
	_install(state)


func _solve_board(session: ChapterOneSession) -> void:
	for index in range(4):
		var board := session.local_state().board as Dictionary
		var target: String = CLOCK.SOLUTION[CLOCK.ROLES[index]]
		var other: int = board.pieces.find(target)
		if other != index: _act(session, "board_swap", [index, other])
		for turn in range(4):
			if session.local_state().board.rotations[index] == 0: break
			_act(session, "board_rotate", index)
	_act(session, "board_flip")


func _travel(session: ChapterOneSession, destination: String) -> void:
	var room: String = GameState.get_snapshot().loop_state.location_id
	if room == destination: return
	if room == "M1_LIBRARY_INNER": _act(session, "move", "M1_LIBRARY_OUTER")
	if GameState.get_snapshot().loop_state.location_id != "M1_CENTRAL_HALL": _act(session, "move", "M1_CENTRAL_HALL")
	_act(session, "move", destination)


func _ledger() -> Dictionary:
	return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _latest(id: String) -> Dictionary:
	var result := {}
	for row in _ledger().revisions:
		if row.metadata.knowledge_id == id: result = row
	return result


func _collect(locale: String) -> void:
	var state := GameState.get_snapshot()
	_expect(KNOWLEDGE.validate(_ledger(), state.meta_progress.dialogue_history).ok, "complete source graph validates")
	for row in _ledger().revisions:
		var entry: Dictionary = ARCHIVE.resolve(state.meta_progress.dialogue_history, row.observation_ref).entry
		var observation: Dictionary = entry.observation
		_expect(observation.producer_id == "NP06" and observation.entry_kind == "document_segment" and observation.segments[0].disclosure == "replay_committed", "acquired note has explicit production and disclosure owner")
		covered[observation.content_id + ":" + locale] = true
		var read := CONTENT.render_entry(entry, "en-US" if locale == "ko-KR" else "ko-KR")
		_expect(read.ok and not read.entry.fallback, "source exact version is readable in the other locale")
	_expect(GameState.get_snapshot() == state, "reading the revision graph is side-effect free")


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_NOTES_FIXTURE_%d" % serial)).ok, "valid scenario fixture")


func _act(session: ChapterOneSession, action: String, value: Variant = null) -> void:
	var result := session.act(action, value)
	_expect(result.get("ok", false), action + ":" + str(value) + " " + str(result.get("error_ids", [])))


func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)
