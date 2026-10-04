extends RefCounted

const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const FEEDBACK := preload("res://scripts/systems/chapter_one_notebook.gd")
const SLOT := "__test_notebook_chapter_one"
var errors := PackedStringArray()
var covered := {}
var covered_segments := {}
var base: Dictionary
var serial := 0

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": ["ERR_TEST_DISK"]}

class LostAcknowledgement extends Node:
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_ACK"]} if result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return {"ok": false, "errors": diagnostic.error_ids}
	var ids: Array = diagnostic.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP04")
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		await _route(tree, language)
		for id in ids:
			_expect(covered.has(id + ":" + language), "unexecuted CH1 ID " + id + ":" + language)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(covered_segments.has(id + ":" + segment + ":" + language), "unobserved segment " + id + ":" + segment + ":" + language)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "covered_segment_locales": covered_segments.size(), "producer_paths": ["NP04"], "guard_fixtures": ["LAYOUT_MISSING", "PHASE_UNSET", "DESK_VISIT", "ALCOVE_VISIT", "GAP_VISIT", "LINK_VISIT", "LINK_OPEN_VISIT"], "not_covered": ["NP05", "NP06", "app_restart_cursor", "OS_input"]}


func _route(tree: SceneTree, language: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	base = GameState.get_snapshot()
	base.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	base.loop_state.day_index = 2
	_install(base)
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	_drain(view)
	_act(view, "move", "M1_CENTRAL_HALL")
	var marking := _fixture("M2_BEDROOM")
	marking.meta_progress.notebook_persistence_confirmed = false
	marking.meta_progress.knowledge_entries.erase("KN_B1_LIBRARY_WINDOW")
	_install(marking)
	_act(view, "mark", "sentence")
	_act(view, "routine")
	var before_reset: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.duplicate(true)
	var reset := view.session.sleep()
	_expect(reset.ok, "actual normal reset")
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries == before_reset, "reset alone never declares a displayed line")
	view._feedback(reset)
	_drain(view)
	_act(view, "confirm_mark")
	var schedule := _fixture("M1_SERVANT_COMMON")
	schedule.meta_progress.notebook_persistence_confirmed = true
	_install(schedule)
	for id in SESSION.DOCUMENTS: _act(view, "read_schedule", id)
	_act(view, "schedule_window", "after_tea_before_bell")
	for visit in [false, true]:
		for object in ["desk", "index", "drawer", "alcove", "gap", "link", "link_open"]:
			var state := _fixture("M1_LIBRARY_INNER", 1 if object == "link_open" else 0)
			if visit and object in ["index", "drawer"]:
				state.meta_progress.servants.edgar.alert = 4
			else:
				# Only index/drawer raise attention. Other visit variants need a loaded threshold guard.
				state.loop_state.event_local_states.CHAPTER_ONE.attention = 4 if visit else 0
			_install(state)
			_act(view, "inspect_inner", "link" if object == "link_open" else object)
	for alert in [0, 4]:
		var state := _fixture("M1_LIBRARY_INNER")
		state.meta_progress.servants.edgar.alert = alert
		state.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "entering"
		_install(state)
		_act(view, "edgar_talk")
	var hidden := _fixture("M1_LIBRARY_INNER")
	hidden.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "entering"
	hidden.loop_state.event_local_states.CHAPTER_ONE.inspected = ["alcove"]
	_install(hidden)
	_act(view, "edgar_hide")
	_act(view, "edgar_leave")
	var journal := _fixture("M1_LIBRARY_INNER")
	journal.loop_state.event_local_states.CHAPTER_ONE.inspected = ["desk"]
	journal.loop_state.event_local_states.CHAPTER_ONE.j1_order = [0, 1, 2]
	journal.loop_state.event_local_states.CHAPTER_ONE.j1_front = [true, true, true]
	_install(journal)
	var before_journal: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
	var restored := view.session.act("j1_restore")
	_expect(restored.ok, "J1 restoration")
	var written_entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.slice(before_journal)
	_expect(written_entries.size() == 1 and written_entries[0].observation.producer_id == "NP06" and written_entries[0].observation.segments[0].disclosure == "replay_committed", "J1 event writes one complete note, not a dialogue display")
	view._feedback(restored)
	var first: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
	_expect(first.observation.content_id == "NB_CH1_CH1_J1_RESTORED" and first.observation.segments.size() == 1, "only first J1 paragraph is disclosed")
	_expect(first.observation.event_occurrence_id == written_entries[0].observation.event_occurrence_id and first.observation.conversation_session_id != written_entries[0].observation.conversation_session_id, "restored text and first spoken line share an occurrence but not a writing session")
	var hidden_ref := ARCHIVE.make_reference(first, "line_02")
	var hidden_segment := ARCHIVE.resolve(GameState.get_snapshot().meta_progress.dialogue_history, hidden_ref)
	_expect(not hidden_segment.ok and hidden_segment.get("error_id") == "NB_REFERENCE_SEGMENT", "well-formed reference cannot disclose unread J1 paragraph")
	_drain(view)
	for room in SESSION.CLOCK_ROOMS:
		_install(_fixture(room, 1))
		_act(view, "rub_clock")
	var board := _clock_fixture()
	_install(board)
	_act(view, "board_check")
	_act(view, "board_check")
	board = _clock_fixture()
	board.loop_state.event_local_states.CHAPTER_ONE.board = _solved_board()
	board.loop_state.event_local_states.CHAPTER_ONE.board.rotations = [90, 90, 90, 90]
	board.loop_state.event_local_states.CHAPTER_ONE.layout_attempts = 1
	_install(board)
	_act(view, "board_check")
	board = _clock_fixture()
	board.loop_state.event_local_states.CHAPTER_ONE.board = _solved_board()
	board.loop_state.event_local_states.CHAPTER_ONE.board.library_back = false
	board.loop_state.event_local_states.CHAPTER_ONE.layout_attempts = 1
	_install(board)
	_act(view, "board_check")
	_act(view, "board_flip")
	_act(view, "board_check")
	# Invalid legacy board guard, not an ordinary reachable puzzle configuration.
	var malformed := CLOCK.inspect_layout({})
	view._feedback({"ok": true, "text": "일치한 구간: 0 / 4\n" + malformed.reason, "history_context": view.session.history_context(), "notebook_feedback": FEEDBACK.layout(malformed, true)})
	_drain(view)
	for role in CLOCK.ROLES:
		var state := _clock_fixture(true)
		state.loop_state.event_local_states.CHAPTER_ONE.roles.erase(role)
		_install(state)
		_act(view, "test_clock")
		_act(view, "activate_clock", true)
	for phase in ["-1", "0", "HALF", "unset", "+1"]:
		var state := _clock_fixture(true)
		state.loop_state.event_local_states.CHAPTER_ONE.phase = phase
		_install(state)
		_act(view, "test_clock")
		_act(view, "activate_clock", true)
	_act(view, "record_wave")
	var second := _fixture("M1_LIBRARY_INNER", 1)
	second.meta_progress.knowledge_entries.b4_waveform_acquired = true
	second.loop_state.event_local_states.CHAPTER_ONE.wave_rotation = 0
	_install(second)
	_act(view, "restore_j2")
	var j2_feedback: Dictionary = view.session.local_state().last_feedback.duplicate(true)
	var mirror := preload("res://scripts/systems/black_mirror_session.gd").new(GameState, SaveManager, SLOT)
	var inherited: Dictionary = mirror.initialize()
	_expect(inherited.ok and inherited.notebook_feedback == j2_feedback.notebook_feedback and inherited.history_context == j2_feedback.history_context, "next chapter initialization preserves the original J2 descriptor and context")
	var shortcut := _fixture("M2_BEDROOM", 1)
	shortcut.meta_progress.knowledge_entries.clock_network_layout_solved = true
	shortcut.meta_progress.knowledge_entries.clock_verified_board = _solved_board()
	shortcut.meta_progress.failure_knowledge.B3_B = {"source_event_id": "B3_B", "status": "active", "attempts": 1, "category": "phase_simultaneous", "verified_roles": CLOCK.SOLUTION.duplicate(), "submitted_phase": "0", "text": "fixture"}
	_install(shortcut)
	_act(view, "shortcut")
	var short_entry: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
	_expect(short_entry.observation.location_id == "M2_BEDROOM" and GameState.get_snapshot().loop_state.location_id == "M1_GREAT_CLOCK", "shortcut keeps source room before movement")
	_install(_fixture("M1_NORTH_ARCHIVE_HALL"))
	view._render_room()
	view._hotspot_layer.get_node("MARA2_MEMORY").pressed.emit()
	_drain(view)
	_collect(language)
	await _persistence(view, tree)
	view.queue_free()
	await tree.process_frame


func _fixture(room: String, journal: int = 0) -> Dictionary:
	var state := base.duplicate(true)
	state.meta_progress.dialogue_history = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
	var ledger: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries.get("notebook_knowledge", {})
	if not ledger.is_empty(): state.meta_progress.knowledge_entries.notebook_knowledge = ledger.duplicate(true)
	state.meta_progress.journal_stage = journal
	state.meta_progress.notebook_persistence_confirmed = true
	state.meta_progress.knowledge_entries.KN_B1_LIBRARY_WINDOW = true
	state.loop_state.location_id = room
	state.loop_state.event_local_states.CHAPTER_ONE = {"routine_done": true}
	return state


func _clock_fixture(solved: bool = false) -> Dictionary:
	var state := _fixture("M1_GREAT_CLOCK", 1)
	state.loop_state.event_local_states.CHAPTER_ONE.rubbed = CLOCK.CLOCKS.duplicate()
	if solved:
		state.meta_progress.knowledge_entries.clock_network_layout_solved = true
		state.loop_state.event_local_states.CHAPTER_ONE.roles = CLOCK.SOLUTION.duplicate()
	return state


func _solved_board() -> Dictionary:
	return {"pieces": ["parlor", "library_outer", "great_clock", "bedroom"], "rotations": [0, 0, 0, 0], "library_back": true}


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_CH1_FIXTURE_%d" % serial)).ok, "fixture install")


func _act(view: Node, action: String, value: Variant = null) -> void:
	var result: Dictionary = view.session.act(action, value)
	_expect(result.get("ok", false), "action " + action + ":" + str(value))
	view._feedback(result)
	_drain(view)


func _drain(view: Node) -> void:
	for index in range(30):
		if not view._dialogue_active: return
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		var before := GameState.get_snapshot()
		view._present_dialogue_line()
		_expect(GameState.get_snapshot() == before, "rerender is idempotent")
		view._dialogue_next.pressed.emit()
		if view._dialogue_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			_expect(false, "line blocked: " + str(view._dialogue_lines[view._dialogue_index]))
			view._dismiss_dialogue_for_test()
			return
	_expect(false, "dialogue did not terminate")


func _collect(language: String) -> void:
	var state := GameState.get_snapshot()
	_expect(ARCHIVE.validate(state.meta_progress.dialogue_history).ok, "CH1 archive validates")
	for entry in state.meta_progress.dialogue_history.entries:
		_expect(entry.record_class == "authored", "actual producer cannot silently become unmapped")
		if entry.record_class != "authored": continue
		var observed: Dictionary = entry.observation
		_expect(observed.chapter_id == "CHAPTER_1" and observed.producer_id in ["NP04", "NP05", "NP06", "NP21"], "CH1 source context: %s / %s / %s" % [observed.content_id, observed.producer_id, observed.chapter_id])
		if observed.producer_id != "NP04": continue
		covered[observed.content_id + ":" + language] = true
		for segment in observed.segments:
			covered_segments[observed.content_id + ":" + segment.segment_id + ":" + language] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if language == "ko-KR" else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "exact CH1 version translates")
	_expect(GameState.get_snapshot() == state, "reading does not change gameplay or archived variables")


func _persistence(view: Node, tree: SceneTree) -> void:
	var board := _clock_fixture()
	_install(board)
	var fail_event := RejectingSave.new()
	var saved: Node = view.session._save
	view.session._save = fail_event
	var before_event := GameState.get_snapshot()
	_expect(not view.session.act("board_check").ok and GameState.get_snapshot() == before_event, "failed event save rolls back attempt and descriptor together")
	fail_event.free()
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = saved
	view.session._save = lost_ack
	var accepted: Dictionary = view.session.act("board_check")
	_expect(accepted.ok and view.session.local_state().layout_attempts == 1, "confirmed lost acknowledgement keeps exact committed event")
	view.session._save = saved
	lost_ack.free()
	var after_event := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "lost acknowledgement save reloads")
	_expect(StateSnapshotValidator.same_persisted_value(after_event, GameState.get_snapshot()), "numeric descriptor and event are identical after acknowledgement recovery")
	var state := _fixture("M1_LIBRARY_INNER")
	state.loop_state.event_local_states.CHAPTER_ONE.attention = 4
	_install(state)
	var result: Dictionary = view.session.act("inspect_inner", "drawer")
	var committed := GameState.get_snapshot()
	var failing := RejectingSave.new()
	view.session._save = failing
	view._feedback(result)
	_expect(view._dialogue_active and view._dialogue_index == 0 and GameState.get_snapshot() == committed, "failed display stays on first segment and rolls back archive")
	view._advance_dialogue()
	_expect(view._dialogue_index == 0 and GameState.get_snapshot() == committed, "failed retry cannot reveal next paragraph")
	view.session._save = saved
	_expect(view._record_current_history_line(), "same token retry succeeds")
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.size() == committed.meta_progress.dialogue_history.entries.size() + 1, "retry adds one observed paragraph")
	_drain(view)
	failing.free()
	var before := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real slot reload")
	_expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "UIDs and frozen feedback survive JSON reload")
	var resumed: Dictionary = view.session.initialize()
	_expect(StateSnapshotValidator.same_persisted_value(result.notebook_feedback, resumed.notebook_feedback) and resumed.history_context == result.history_context, "new saved feedback retains explicit version and context")
	view._feedback(resumed)
	_drain(view)
	# Older last_feedback has no explicit descriptor. Never infer one from text_id.
	var legacy := GameState.get_snapshot()
	legacy.loop_state.event_local_states.CHAPTER_ONE.last_feedback.erase("notebook_feedback")
	_install(legacy)
	var old: Dictionary = view.session.initialize()
	_expect(old.notebook_feedback.is_empty(), "legacy feedback is not retroactively mapped")
	view._feedback(old)
	_drain(view)
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.back().record_class == "unmapped", "old displayed feedback remains explicitly unmapped")
	var before_read := GameState.get_snapshot()
	view._open_notebook()
	view._close_modal()
	_expect(GameState.get_snapshot() == before_read, "old notebook viewing never backfills source IDs")
	await tree.process_frame


func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)
