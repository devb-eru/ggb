extends RefCounted

const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const FEEDBACK := preload("res://scripts/systems/chapter_one_notebook.gd")
const SLOT := "__test_notebook_chapter_one"
var errors := PackedStringArray()
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()
var covered := {}
var observed_tuples := {}
var covered_segments := {}
var excluded_guard_paths: Array = []
var pressure_paths: Array = []
var cross_reset_paths: Array = []
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
	_report_tuples()
	print("NOTEBOOK_NP04_GUARD_AUDIT: " + JSON.stringify({"paths": excluded_guard_paths, "errors": errors}))
	print("NOTEBOOK_NP04_PRESSURE_AUDIT: " + JSON.stringify({"paths": pressure_paths, "errors": errors}))
	_expect(cross_reset_paths.size() == 8, "two alert boundaries and two initial responses survive reset in both languages")
	print("NOTEBOOK_NP04_CROSS_RESET_AUDIT: " + JSON.stringify({"paths": cross_reset_paths, "errors": errors}))
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_expect(runtime_audit.emit("chapter-one", errors.is_empty()).ok, "runtime trace validates")
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
	_first_schedule_context(view)
	_natural_pressure_paths(view, language)
	_collect(language)
	_cross_reset_visits(view, language)
	_guard_exclusions(view, language)
	_schedule_combinations(view, language)
	_shortcut_conditions(view, language, shortcut)
	await _persistence(view, tree)
	view.queue_free()
	await tree.process_frame


func _cross_reset_visits(view: Node, language: String) -> void:
	for alert in [0, 4]:
		for first_response in ["talk", "hide"]:
			var initial := base.duplicate(true)
			initial.meta_progress.dialogue_history = ARCHIVE.create()
			initial.meta_progress.knowledge_entries.erase("notebook_knowledge")
			initial.meta_progress.servants.edgar.alert = alert
			initial.loop_state.location_id = "M2_BEDROOM"
			_install(initial)
			_act(view, "mark", "sentence")
			_act(view, "routine")
			_retained_reset(view)
			_act(view, "confirm_mark")
			_act(view, "routine")
			_act(view, "move", "M1_CENTRAL_HALL")
			_act(view, "move", "M1_SERVANT_COMMON")
			for owner in ["edgar", "luca"]: _act(view, "read_schedule", owner)
			_act(view, "schedule_window", "after_tea_before_bell")
			_act(view, "move", "M1_CENTRAL_HALL")
			_enter_and_visit(view, first_response)
			var first := GameState.get_snapshot()
			_expect(first.meta_progress.servants.edgar.residual_memory.count("B2_CAUGHT") == (1 if first_response == "talk" else 0), "first hiding cannot fabricate a caught memory")
			var old_entries: Array = first.meta_progress.dialogue_history.entries.duplicate(true)
			for room in ["M1_LIBRARY_OUTER", "M1_CENTRAL_HALL", "M2_BEDROOM"]: _act(view, "move", room)
			_retained_reset(view)
			var morning := GameState.get_snapshot()
			_expect(morning.meta_progress.servants == first.meta_progress.servants, "actual reset preserves servant memory and relationship values")
			_expect(not view.session.local_state().routine_done and view.session.local_state().attention == 0 and view.session.local_state().edgar_state == "absent" and not view.session.local_state().edgar_visit_done, "actual reset clears daily work, noise and visit state")
			_act(view, "routine")
			_act(view, "move", "M1_CENTRAL_HALL")
			_enter_and_visit(view, "talk")
			var after := GameState.get_snapshot()
			_expect(after.meta_progress.servants.edgar.residual_memory.count("B2_CAUGHT") == 1, "next-day conversation preserves exactly one caught memory")
			_expect(after.meta_progress.servants.edgar.alert == alert and after.meta_progress.servants.edgar.bond == first.meta_progress.servants.edgar.bond, "revisiting is not a relationship award")
			var by_uid := {}
			for entry in after.meta_progress.dialogue_history.entries: by_uid[entry.entry_uid] = entry
			for entry in old_entries:
				var saved: Dictionary = by_uid.get(entry.entry_uid, {})
				_expect(not saved.is_empty() and saved.observation == entry.observation and saved.sequence == entry.sequence, "next morning cannot rewrite earlier observations or their order")
			var id := "NB_CH1_CH1_B2_ALERT" if alert == 4 else "NB_CH1_CH1_B2_NORMAL"
			var visits: Array = after.meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.observation.content_id == id)
			var paragraphs := 2 if alert == 4 else 1
			_expect(visits.size() == paragraphs * (2 if first_response == "talk" else 1), "only actual conversations disclose the correct number of paragraphs")
			if first_response == "talk" and visits.size() >= paragraphs * 2:
				_expect(visits[0].observation.event_occurrence_id != visits[paragraphs].observation.event_occurrence_id and visits[0].observation.presentation_token != visits[paragraphs].observation.presentation_token, "a new-day conversation is a new event, not a rerender")
			_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "cross-reset visit reloads the actual saved JSON")
			_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), after), "JSON reload preserves both mornings and exact memory")
			_collect(language)
			cross_reset_paths.append({"locale":language, "initial_alert":alert, "first_response":first_response, "second_response":"talk", "normal_resets":2, "caught_memory_count":1})


func _retained_reset(view: Node) -> void:
	var before := GameState.get_snapshot()
	var result: Dictionary = view.session.sleep()
	_expect(result.ok, "connected visit route accepts sleep in the same bedroom")
	var after := GameState.get_snapshot()
	_expect(int(after.loop_state.day_index) == int(before.loop_state.day_index) + 1 and after.loop_state.location_id == "M2_BEDROOM", "actual reset advances the day at the same starting room")
	_expect(after.meta_progress.dialogue_history.entries == before.meta_progress.dialogue_history.entries, "sleep itself never publishes unseen dialogue")
	_expect(after.meta_progress.knowledge_entries.get("notebook_knowledge", {}) == before.meta_progress.knowledge_entries.get("notebook_knowledge", {}), "actual reset keeps acquired notes and sources")
	view._feedback(result)
	_drain(view)


func _enter_and_visit(view: Node, response: String) -> void:
	_act(view, "move", "M1_LIBRARY_OUTER")
	_act(view, "move", "M1_LIBRARY_INNER")
	_act(view, "inspect_inner", "alcove")
	_act(view, "inspect_inner", "index")
	if view.session.local_state().edgar_state != "entering": _act(view, "inspect_inner", "drawer")
	_expect(view.session.local_state().edgar_state == "entering", "natural inspection triggers the next visit")
	_act(view, "edgar_" + response)
	if response == "hide": _act(view, "edgar_leave")
	_expect(view.session.local_state().edgar_state == "absent" and view.session.local_state().edgar_visit_done, "visit leaves the puzzle available")


func _natural_pressure_paths(view: Node, language: String) -> void:
	for alert in [0, 4]:
		for schedule_known in [false, true]:
			for response in ["talk", "hide"]:
				var state := _fixture("M1_LIBRARY_INNER")
				state.meta_progress.servants.edgar.alert = alert
				state.meta_progress.knowledge_entries.schedule_mara2 = schedule_known
				_install(state)
				_act(view, "inspect_inner", "alcove")
				_act(view, "inspect_inner", "index")
				var first_visit: bool = alert == 4 and not schedule_known
				_expect(view.session.local_state().attention == 1 and (view.session.local_state().edgar_state == "entering") == first_visit, "first noisy inspection respects alert and archive schedule")
				if not first_visit:
					_act(view, "inspect_inner", "index")
					_expect(view.session.local_state().attention == 1 and view.session.local_state().edgar_state == "absent", "reinspection cannot manufacture another attention increment")
					_act(view, "inspect_inner", "drawer")
				var expected_visit: bool = alert == 4 or not schedule_known
				_expect((view.session.local_state().edgar_state == "entering") == expected_visit, "natural noise sequence respects the documented threshold")
				if expected_visit:
					if response == "talk":
						_act(view, "edgar_talk")
						_expect(view.session.snapshot().meta_progress.servants.edgar.residual_memory.count("B2_CAUGHT") == 1, "actual conversation adds exactly one caught memory")
					else:
						_act(view, "edgar_hide")
						_act(view, "edgar_leave")
						_expect(not "B2_CAUGHT" in view.session.snapshot().meta_progress.servants.edgar.residual_memory, "hiding cannot disclose the unchosen conversation memory")
					_expect(view.session.local_state().edgar_visit_done and view.session.local_state().edgar_state == "absent", "visit resolves without failing the puzzle")
				var attention: int = view.session.local_state().attention
				var memory: Array = view.session.snapshot().meta_progress.servants.edgar.residual_memory.duplicate()
				var ledger: Dictionary = view.session.snapshot().meta_progress.knowledge_entries.get("notebook_knowledge", {}).duplicate(true)
				_act(view, "inspect_inner", "index")
				var first: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back().duplicate(true)
				var count: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
				_act(view, "inspect_inner", "index")
				var archive: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history
				var second: Dictionary = archive.entries.back()
				_expect(archive.entries.size() == count + 1 and archive.entries[count - 1].observation == first.observation, "distinct inspection appends one visible line without rewriting its previous observation")
				_expect(second.observation.content_id == first.observation.content_id and second.observation.event_occurrence_id != first.observation.event_occurrence_id and second.observation.presentation_token != first.observation.presentation_token, "new action is not mistaken for an idempotent rerender")
				_expect(view.session.local_state().attention == attention and view.session.local_state().edgar_state == "absent", "repeated inspection cannot restart or fabricate the visit")
				_expect(view.session.snapshot().meta_progress.servants.edgar.residual_memory == memory and view.session.snapshot().meta_progress.knowledge_entries.get("notebook_knowledge", {}) == ledger, "repeated dialogue leaves memory and knowledge revisions unchanged")
				pressure_paths.append({"alert": alert, "mara2_schedule": schedule_known, "requested_response": response, "response_executed": expected_visit, "locale": language, "visit_after_index": first_visit, "visit_triggered": expected_visit})


func _first_schedule_context(view: Node) -> void:
	var state := _fixture("M1_SERVANT_COMMON")
	state.meta_progress.knowledge_entries.erase("KN_B1_LIBRARY_WINDOW")
	_install(state)
	_expect(view.session.stage() == "B1", "first schedule investigation starts before library window knowledge")
	for owner in SESSION.DOCUMENTS:
		_act(view, "read_schedule", owner)
		var entry: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
		_expect(entry.observation.content_id == "NB_CH1_CH1_B1_TEXT_" + String(owner).to_upper() and entry.observation.node_id == "B1", "first schedule feedback retains B1 source " + owner)
	var result: Dictionary = view.session.act("schedule_window", "after_tea_before_bell")
	_expect(result.ok and result.history_context.node_id == "B1" and view.session.stage() == "B2", "schedule solution captures source B1 before advancing to B2")
	view._feedback(result)
	_drain(view)
	var solved: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
	_expect(solved.observation.content_id == "NB_CH1_CH1_B1_SOLVED" and solved.observation.node_id == "B1", "display after transition cannot relabel the schedule solution B2")


func _guard_exclusions(view: Node, language: String) -> void:
	var inner := _fixture("M1_LIBRARY_INNER")
	_guard_case(view, language, "schedule_missing", _fixture("M1_SERVANT_COMMON"), "schedule_window", "after_tea_before_bell", "CH1_B1_NEED_DOCS")
	var schedule := _fixture("M1_SERVANT_COMMON")
	schedule.meta_progress.knowledge_entries.schedule_edgar = true
	schedule.meta_progress.knowledge_entries.schedule_luca = true
	_guard_case(view, language, "schedule_wrong", schedule, "schedule_window", "wrong", "CH1_B1_WRONG")
	_guard_case(view, language, "inner_unknown", inner, "inspect_inner", "unknown", "CH1_INNER_UNKNOWN")
	var pressure := inner.duplicate(true)
	pressure.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "entering"
	_guard_case(view, language, "inner_pressure", pressure, "inspect_inner", "desk", "CH1_INNER_PRESSURE")
	_guard_case(view, language, "edgar_absent_room", _fixture("M1_CENTRAL_HALL"), "edgar_talk", null, "CH1_B2_ABSENT")
	_guard_case(view, language, "hide_missing_alcove", pressure, "edgar_hide", null, "CH1_B2_NEED_ALCOVE")
	_guard_case(view, language, "edgar_finished", inner, "edgar_talk", null, "CH1_B2_FINISHED")
	_guard_case(view, language, "leave_not_hidden", pressure, "edgar_leave", null, "CH1_B2_WAITING")
	_guard_case(view, language, "j1_missing_desk", inner, "j1_restore", null, "CH1_J1_NEED_DESK")
	var desk := inner.duplicate(true)
	desk.loop_state.event_local_states.CHAPTER_ONE.inspected = ["desk"]
	_guard_case(view, language, "j1_invalid_piece", desk, "j1_piece", 3, "CH1_J1_NEED_PIECE")
	_guard_case(view, language, "j1_wrong_order", desk, "j1_restore", null, "CH1_J1_WRONG_ORDER")
	desk.loop_state.event_local_states.CHAPTER_ONE.j1_order = [0, 1, 2]
	_guard_case(view, language, "j1_wrong_face", desk, "j1_restore", null, "CH1_J1_WRONG_FACE")
	desk.meta_progress.journal_stage = 1
	_guard_case(view, language, "j1_already", desk, "j1_restore", null, "CH1_J1_ALREADY")
	_guard_case(view, language, "clock_missing_j1", inner, "rub_clock", null, "CH1_CLOCK_NEED_J1")
	_guard_case(view, language, "board_missing_rubbings", _fixture("M1_GREAT_CLOCK", 1), "board_check")
	_guard_case(view, language, "board_invalid_swap", _clock_fixture(), "board_swap", [0, 4])
	_guard_case(view, language, "board_invalid_rotation", _clock_fixture(), "board_rotate", 4)
	_guard_case(view, language, "role_missing_layout", _clock_fixture(), "test_clock")
	_guard_case(view, language, "role_invalid_pair", _clock_fixture(true), "role", ["invalid", "bedroom"])
	_guard_case(view, language, "phase_invalid", _clock_fixture(true), "phase", "invalid")
	_guard_case(view, language, "activation_unconfirmed", _clock_fixture(true), "activate_clock", false)
	var locked := _clock_fixture(true)
	locked.loop_state.event_local_states.CHAPTER_ONE.clock_locked = true
	_guard_case(view, language, "activation_locked", locked, "activate_clock", true)
	_guard_case(view, language, "shortcut_wrong_room", inner, "shortcut", null, "CH1_BSHORT_BEDROOM")
	_guard_case(view, language, "shortcut_missing_failure", _fixture("M2_BEDROOM", 1), "shortcut", null, "CH1_BSHORT_UNAVAILABLE")
	_guard_case(view, language, "wave_missing_signal", _clock_fixture(true), "record_wave", null, "CH1_B4_NEED_SIGNAL")
	_guard_case(view, language, "j2_missing_wave", inner, "restore_j2", null, "CH1_J2_NEED_PAGE")
	var wave := _fixture("M1_LIBRARY_INNER", 1)
	wave.meta_progress.knowledge_entries.b4_waveform_acquired = true
	_guard_case(view, language, "j2_misaligned", wave, "restore_j2", null, "CH1_J2_MISALIGNED")
	wave.meta_progress.journal_stage = 2
	_guard_case(view, language, "j2_already", wave, "restore_j2", null, "CH1_J2_ALREADY")


func _schedule_combinations(view: Node, language: String) -> void:
	var owners := ["edgar", "luca", "mara1", "mara2"]
	for mask in range(16):
		var state := _fixture("M1_SERVANT_COMMON")
		state.meta_progress.knowledge_entries.erase("KN_B1_LIBRARY_WINDOW")
		_install(state)
		var core_count := 0
		for index in range(4):
			if mask & (1 << index):
				_act(view, "read_schedule", owners[index])
				if index < 3: core_count += 1
		state = GameState.get_snapshot()
		if core_count < 2:
			_guard_case(view, language, "schedule_subset_%d" % mask, state, "schedule_window", "after_tea_before_bell", "CH1_B1_NEED_DOCS")
		else:
			for wrong in ["morning", "after_bell"]:
				_guard_case(view, language, "schedule_subset_%d_%s" % [mask, wrong], state, "schedule_window", wrong, "CH1_B1_WRONG")
			_act(view, "schedule_window", "after_tea_before_bell")
			var entry: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
			_expect(entry.observation.node_id == "B1" and entry.observation.content_id == "NB_CH1_CH1_B1_SOLVED", "schedule subset retains original source %d" % mask)
			_expect(view.session.stage() == "B2", "schedule subset unlocks B2 %d" % mask)
	print("NOTEBOOK_NP04_SCHEDULE_MATRIX: " + language + " 16 subsets")


func _shortcut_conditions(view: Node, language: String, eligible: Dictionary) -> void:
	_install(eligible)
	_expect(view.session.can_prepare_clock_shortcut(), "shortcut independent baseline eligible")
	for condition in ["room", "journal_zero", "journal_two", "layout", "failure_missing", "failure_resolved", "locked", "signal", "waveform"]:
		var state := eligible.duplicate(true)
		match condition:
			"room": state.loop_state.location_id = "M1_CENTRAL_HALL"
			"journal_zero": state.meta_progress.journal_stage = 0
			"journal_two": state.meta_progress.journal_stage = 2
			"layout": state.meta_progress.knowledge_entries.clock_network_layout_solved = false
			"failure_missing": state.meta_progress.failure_knowledge.erase("B3_B")
			"failure_resolved": state.meta_progress.failure_knowledge.B3_B.status = "resolved"
			"locked": state.loop_state.event_local_states.CHAPTER_ONE.clock_locked = true
			"signal": state.loop_state.event_local_states.CHAPTER_ONE.signal_generated = true
			"waveform": state.meta_progress.knowledge_entries.b4_waveform_acquired = true
		_install(state)
		_expect(not view.session.can_prepare_clock_shortcut(), "shortcut independent condition " + condition)
		_guard_case(view, language, "shortcut_independent_" + condition, state, "shortcut", null, "CH1_BSHORT_BEDROOM" if condition == "room" else "CH1_BSHORT_UNAVAILABLE")
	print("NOTEBOOK_NP04_SHORTCUT_MATRIX: " + language + " 9 independent conditions")


func _guard_case(view: Node, language: String, id: String, state: Dictionary, action: String, value: Variant = null, text_id: String = "") -> void:
	_install(state)
	var before := GameState.get_snapshot()
	var revision: int = GameState.revision
	var result: Dictionary = view.session.act(action, value)
	_expect(not result.get("ok", true) and result.get("text_id", "") == text_id, "guard dispatch " + id)
	_expect(not result.has("notebook_feedback"), "guard has no authored descriptor " + id)
	view._feedback(result)
	_expect(not view._dialogue_active and not view._status_label.text.is_empty(), "guard is status UI, not dialogue " + id)
	_expect(not view._status_label.text.contains("CH1_"), "guard does not expose text ID " + id)
	_expect(GameState.get_snapshot() == before and GameState.revision == revision, "guard cannot mutate gameplay, ledger, or history " + id)
	excluded_guard_paths.append({"id": id, "action": action, "text_id": text_id, "locale": language, "classification": "EXCLUDED_UI", "reason": "precondition_or_manipulation_status_not_dialogue"})


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


func _report_tuples() -> void:
	var keys := observed_tuples.keys()
	keys.sort()
	print("NOTEBOOK_NP04_PATH_AUDIT: " + JSON.stringify({"scope":"OBSERVED_RUNTIME_PATHS_NOT_EXHAUSTIVE_ALLOWED_NODE_PRODUCT", "tuple_fields":["producer", "content", "version", "node", "variant", "segment", "locale"], "observed":keys.map(func(key: String) -> Array: return JSON.parse_string(key)), "errors":errors}))


func _collect(language: String) -> void:
	var state := GameState.get_snapshot()
	runtime_audit.capture(state.meta_progress.dialogue_history)
	_expect(ARCHIVE.validate(state.meta_progress.dialogue_history).ok, "CH1 archive validates")
	for entry in state.meta_progress.dialogue_history.entries:
		_expect(entry.record_class == "authored", "actual producer cannot silently become unmapped")
		if entry.record_class != "authored": continue
		var observed: Dictionary = entry.observation
		_expect(observed.chapter_id == "CHAPTER_1" and observed.producer_id in ["NP04", "NP05", "NP06", "NP21"], "CH1 source context: %s / %s / %s" % [observed.content_id, observed.producer_id, observed.chapter_id])
		if observed.producer_id != "NP04": continue
		covered[observed.content_id + ":" + language] = true
		var definition := CONTENT.definition(observed.content_id, 1)
		_expect(int(observed.content_version) == 1 and observed.variant_id == definition.action_or_variant and observed.node_id in definition.node_ids, "actual CH1 feedback version/variant/node is registered")
		for segment in observed.segments:
			var tuple := JSON.stringify([observed.producer_id, observed.content_id, int(observed.content_version), observed.node_id, observed.variant_id, segment.segment_id, segment.viewed_locale])
			observed_tuples[tuple] = true
			_expect(segment.viewed_locale == language and segment.segment_id in definition.visible_segment_ids, "actual feedback segment and capture locale agree with the executed path")
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
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_read, "old notebook viewing never backfills source IDs")
	await tree.process_frame


func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)
