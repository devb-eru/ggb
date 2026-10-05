extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const TRANSITION := preload("res://scripts/ui/fracture_transition_texts.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")
const SLOT := "__test_notebook_fracture"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var serial := 0
var rest_recovery_cases := 0
var view: BasementController
var checkpoints := CHECKPOINTS.new()

class ControlledSave extends Node:
	var delegate: Node
	var reject := false
	var reject_game := false
	var rejected_game_saves := 0
	var lose_ack := false
	func get_build_flavor() -> String: return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject_game and not transaction.begins_with("HISTORY_"):
			rejected_game_saves += 1
			return {"ok": false, "error_ids": ["ERR_TEST_FRACTURE_GAME_SAVE"]}
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_FRACTURE_NOTE_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_FRACTURE_NOTE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return {"ok": false, "errors": diagnostic.error_ids}
	var ids: Array = diagnostic.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP09" and not id.begins_with("NB_FRACTURE_SURFACE_"))
	_seed("D5")
	view = VIEW.new()
	view.configure_session(SLOT, "D5")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for route in ["bedroom", "capsule"]: await _route(tree, route)
		await _reactions(tree)
		await _branches(tree)
		await _failures(tree)
		await _rest_recovery(tree)
		for id in ids:
			_expect(covered.has(id + ":" + locale), "unexecuted fracture ID: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "unseen fracture segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(),
		"rest_recovery_cases": rest_recovery_cases, "not_covered": ["timed_panel_and_guidance_disclosure", "world_question_choice_capture", "static_board_disclosure", "app_restart_cursor", "OS_input", "shared_notebook_UI"]}


func _route(tree: SceneTree, route: String) -> void:
	_seed("D5")
	view._show_full_fracture_transition()
	_expect(_has("NB_FRACTURE_TRANSITION_01") and not _has("NB_FRACTURE_TRANSITION_02") and not view.session.known("d5_complete"), "the first displayed beat cannot reveal the next beat or complete D5")
	_drain()
	_expect(view.session.stage() == "D6" and not GameState.get_snapshot().fracture_state.broken_reset_triggered, "acknowledging the last transition commits D5, not the broken sleep")
	var note := _latest("FRACTURE_D5")
	_expect(note.source_refs.size() >= 14, "D5 note cites only the actually displayed transition beats")
	for reference in note.source_refs:
		var entry: Dictionary = ARCHIVE.resolve(_archive(), reference).entry
		_expect(not entry.observation.content_id.begins_with("NB_FRACTURE_REACTION_"), "no frozen companion means no invented reaction source")
	# Initialization may replay the committed summary; the original callback does not display it.
	_expect(not _has("NB_FRACTURE_D5_COMPLETE"), "suppressed completion feedback is not a displayed observation")
	var replayed := view.session.initialize()
	view._feedback(replayed)
	_drain()
	_expect(_entry("NB_FRACTURE_D5_COMPLETE").observation.node_id == "D5", "replayed summary retains the source D5 node after moving into D6")
	_act("d6_move", "H0_SERVICE_SPINE")
	for object_id in ["wall", "sign", "trace", "capsule", "notebook"]: _act("d6_inspect", object_id)
	var before_repeat: int = _ledger().revisions.size()
	_act("d6_inspect", "notebook")
	_expect(_ledger().revisions.size() == before_repeat, "reinspection does not reacquire the same corridor document")
	if route == "bedroom": _act("d6_move", "M2_BEDROOM")
	view._confirm_d6_rest(route)
	var before_cancel := GameState.get_snapshot()
	view._cancel_prologue_modal()
	_expect(not view._modal_active and not GameState.get_snapshot().loop_state.event_local_states.get("D6", {}).has("fracture_rest_route"), "Esc records explicit rest cancellation without choosing a route")
	_expect(not before_cancel.fracture_state.broken_reset_triggered, "rest preview does not perform a reset")
	view._confirm_d6_rest(route)
	view._modal_body.get_child(4).pressed.emit()
	_expect(view._d6_sleep_transition_active and not _has("NB_FRACTURE_D6_REST"), "confirmed rest starts the existing transition without inventing suppressed dialogue")
	# This result is visible when reconstructing an in-progress rest after a load.
	replayed = view.session.initialize()
	view._feedback(replayed)
	_drain()
	_expect(_has("NB_FRACTURE_D6_REST"), "the same summary becomes observed only when actually replayed")
	view._tick_d6_sleep_transition(6.0)
	_expect(view.session.stage() == "E1_ENTRY" and _has("NB_FRACTURE_NOTE_E1_WAKE"), "both rest routes perform the broken reset and acquire the wake note")
	_expect(_has("NB_FRACTURE_E1_WAKE"), "first wake paragraph is displayed")
	var wake := _entry("NB_FRACTURE_E1_WAKE")
	var future := ARCHIVE.make_reference(wake, "line_01")
	_expect(ARCHIVE.resolve(_archive(), future).ok, "the visible wake paragraph has a valid source reference")
	future.segment_id = "line_02"
	var hidden := ARCHIVE.resolve(_archive(), future)
	_expect(not hidden.ok and hidden.get("error_id") == "NB_REFERENCE_SEGMENT", "the well-formed reference is rejected because the wake continuation is not displayed")
	_drain()
	var stored_d5: Dictionary = note.observation_ref
	_expect(ARCHIVE.resolve(_archive(), stored_d5).ok, "broken reset preserves the earlier D5 observation reference")
	_act("e1_inspect", "bed")
	_act("e1_inspect", "bed")
	_expect(not view.session.known("E1_complete"), "repeating an object does not meet the three-distinct-objects gate")
	_act("e1_inspect", "window")
	_act("e1_inspect", "mirror")
	_expect(_has("NB_FRACTURE_NOTE_E1_DIFFERENT") and view.session.known("E1_complete"), "the third distinct object acquires the changed-morning record")
	_act("e1_inspect", "call_cord")
	_act("move", "M1_CENTRAL_HALL")
	_act("move", "M1_KITCHEN")
	_act("e2_luca", "ask")
	var bond: int = GameState.get_snapshot().meta_progress.servants.luca.bond
	_act("e2_luca", "hold" if route == "bedroom" else "withdraw")
	var response := _entry("NB_FRACTURE_LUCA_HOLD" if route == "bedroom" else "NB_FRACTURE_LUCA_WITHDRAW")
	_expect(response.observation.node_id == "LUCA_S2" and response.observation.location_id == "M1_KITCHEN", "Luca's answer keeps the original kitchen source after returning to the hall")
	_expect(int(GameState.get_snapshot().meta_progress.servants.luca.bond) == mini(5, bond + (1 if route == "bedroom" else 0)), "notebook wiring does not change the original relationship delta")
	_act("e2_report")
	for question in ["house", "body", "memory"]: _act("e2_question", question)
	_act("e2_finish")
	var report := _latest("FRACTURE_REPORT")
	_expect(report.source_refs.size() == 6, "report sources contain its own note, the morning, latest report paragraph and three displayed answers")
	_expect(_has("NB_FRACTURE_NOTE_INDEX_ANONYMOUS") and not _has("NB_FRACTURE_NOTE_INDEX_KNOWN"), "anonymous archive index cannot reveal its owner")
	_act("move", "M2_BEDROOM")
	var rested := view.session.sleep()
	_expect(rested.ok, "post-broken rest remains available")
	view._feedback(rested)
	_drain()
	var before_read := GameState.get_snapshot()
	for id in ["MOVE_CORRIDOR", "D6_MOVE", "D6_REST"]:
		_expect(_entry("NB_FRACTURE_" + id).protection_reasons.is_empty(), "routine navigation/anticipation remains ordinary history instead of automatic permanent evidence")
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	for entry in _archive().entries:
		if entry.get("record_class") == "authored":
			var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
			_expect(rendered.ok and not rendered.entry.fallback, "fracture observations render in the other language")
	_expect(GameState.get_snapshot() == before_read, "reading the notebook cannot redo the sleep or relationship action")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(before_read, GameState.get_snapshot()), "fracture notes and source references survive real JSON reload")
	_collect()
	await tree.process_frame


func _reactions(tree: SceneTree) -> void:
	for owner in TRANSITION.REACTIONS:
		for mode in ["bond", "alert"]:
			if not TRANSITION.REACTIONS[owner].has(mode + "_ko"): continue
			var state := _seed("D5")
			state.loop_state.event_local_states.D5 = {"D4_REACTION": {"owner": owner, "mode": mode, "bond": 4 if mode == "bond" else 0, "alert": 4 if mode == "alert" else 0}}
			_install(state)
			view._show_full_fracture_transition()
			var id := "NB_FRACTURE_" + TRANSITION.reaction_key(view._basement().d5_reaction())
			_expect(not _has(id), "a frozen reaction is not yet a displayed reaction")
			for index in range(6): view._advance_dialogue()
			_expect(view._dialogue_index == 6, "six acknowledged beats reach the focus controls")
			view._select_d5_focus("LUCA" if owner != "LUCA" else "IRIS")
			_expect(view._dialogue_lines[11].notebook_content.content_id == id and not _has(id), "changing visual focus neither replaces nor discloses the frozen voice")
			_drain()
			_expect(_has(id) and _entry(id).observation.chapter_id == "CHAPTER_3", "actual companion response is attributed to the fracture")
			var found := 0
			for reference in _latest("FRACTURE_D5").source_refs:
				if ARCHIVE.resolve(_archive(), reference).entry.observation.content_id == id: found += 1
			_expect(found == 1, "completed fracture cites the single observed companion response")
			_collect()
			await tree.process_frame


func _branches(tree: SceneTree) -> void:
	var state := _seed("E2_INTRO")
	state.meta_progress.knowledge_entries.mara2_archive_index_known = true
	_install(state)
	_act("e2_report")
	_act("e2_finish")
	_expect(_has("NB_FRACTURE_NOTE_INDEX_KNOWN"), "a previously identified index keeps its authorized identity")
	for reference in _latest("FRACTURE_REPORT").source_refs:
		_expect(not ARCHIVE.resolve(_archive(), reference).entry.observation.content_id.begins_with("NB_FRACTURE_E2_ANSWER_"), "skipped optional questions are not fabricated as report sources")
	_collect()
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	_seed("D5")
	var result := view.session.act("d_fracture")
	_expect(result.ok and _has("NB_FRACTURE_NOTE_D5"), "demo still commits the existing event-written fracture summary")
	var before := _archive()
	view._feedback(result)
	_expect(_archive() == before and not _has("NB_FRACTURE_TRANSITION_01"), "suppressed full transition is not disclosed in the demo")
	var demo_note := _latest("FRACTURE_D5")
	_expect(demo_note.source_refs == [demo_note.observation_ref], "demo note cites only itself, not old flags or unavailable full-game scenes")
	_collect()
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	await tree.process_frame


func _failures(tree: SceneTree) -> void:
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	view.session._save = controlled
	_seed("D5")
	controlled.reject = true
	var before := GameState.get_snapshot()
	_expect(not view.session.act("d_fracture").ok and GameState.get_snapshot() == before, "D5 completion and its note roll back together")
	controlled.reject = false
	controlled.lose_ack = true
	_expect(view.session.act("d_fracture").ok and _ledger().revisions.size() == 1, "lost acknowledgement does not duplicate the fracture note")
	controlled.lose_ack = false
	_seed("E2_INTRO")
	_act("e2_report")
	controlled.reject = true
	before = GameState.get_snapshot()
	_expect(not view.session.act("e2_finish").ok and GameState.get_snapshot() == before, "report/index notes and hub opening are one atomic candidate")
	controlled.reject = false
	controlled.lose_ack = true
	var finished := view.session.act("e2_finish")
	_expect(finished.ok and _ledger().revisions.size() == 2, "lost report acknowledgement creates exactly two note revisions")
	controlled.lose_ack = false
	controlled.reject = true
	before = GameState.get_snapshot()
	view._feedback(finished)
	var token: String = view._dialogue_lines[0].presentation_token
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == before and view._dialogue_lines[0].presentation_token == token, "failed first report display retains the same token and blocks the next paragraph")
	controlled.reject = false
	view._advance_dialogue()
	_drain()
	_collect()
	for route in ["bedroom", "capsule"]:
		var state := _seed("D6")
		state.loop_state.location_id = "M2_BEDROOM" if route == "bedroom" else "H0_SERVICE_SPINE"
		_install(state)
		view._render_room()
		controlled.reject = true
		view._confirm_d6_rest(route)
		var request := view._recorded_modal_request
		before = GameState.get_snapshot()
		view._modal_body.get_child(4).pressed.emit()
		view._cancel_prologue_modal()
		_expect(view._modal_active and not view._d6_sleep_transition_active and GameState.get_snapshot() == before, "unsaved rest preview cannot confirm or silently discard through Esc")
		controlled.reject = false
		controlled.lose_ack = true
		view._cancel_prologue_modal()
		_expect(not view._modal_active and _archive().entries.size() == 2, "lost cancellation acknowledgement records preview and cancellation once")
		controlled.lose_ack = false
		view._confirm_d6_rest(route)
		request = view._recorded_modal_request
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "actual reload invalidates a rest confirmation")
		before = GameState.get_snapshot()
		view._recorded_choice_pressed(request, 1)
		_expect(GameState.get_snapshot() == before and not view._d6_sleep_transition_active, "a pre-load callback cannot start the new state's sleep")
		view._cancel_prologue_modal()
		_collect()
	view.session._save = SaveManager
	controlled.free()
	await tree.process_frame


func _rest_recovery(tree: SceneTree) -> void:
	for route in ["bedroom", "capsule"]:
		for follow_up in ["retry", "cancel"]:
			var old_errors := errors.size()
			var state := _seed("D6")
			state.loop_state.location_id = "M2_BEDROOM" if route == "bedroom" else "H0_SERVICE_SPINE"
			_install(state)
			_expect(view.session.initialize().ok, "rest recovery fixture initializes normally")
			view._render_room()
			view._confirm_d6_rest(route)
			var request: Dictionary = view._recorded_modal_request
			_expect(request.get("recorded", false), "rest prompt is observed before confirmation")
			var shown := GameState.get_snapshot()
			var saver := ControlledSave.new()
			saver.delegate = SaveManager
			saver.reject_game = true
			view.session._save = saver
			view._recorded_choice_pressed(request, 1)
			view.set_process(false)
			var pending := GameState.get_snapshot()
			var cursor := CURSOR.read(pending)
			_expect(saver.rejected_game_saves == 1, "rest choice reaches one rejected game save")
			_expect(view._modal_active and not view._d6_sleep_transition_active and cursor.get("phase") == "selection_pending" and CURSOR.matches(cursor, pending), "failed rest stays at its pending choice")
			_expect(_same_rest_gameplay(shown, pending), "saved answer cannot choose a physical rest route or reset")
			var answer_id: String = request.row.choices[1].content_id
			var answers := _rest_answers(answer_id)
			_expect(answers.size() == 1, "one attempted rest answer")
			view.session._save = SaveManager
			view.queue_free()
			await tree.process_frame
			_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "pending rest reloads from disk")
			view = VIEW.new()
			view.configure_session(SLOT, "D6")
			tree.current_scene.add_child(view)
			view.set_process(false)
			await tree.process_frame
			_expect(view._modal_active and not view._d6_sleep_transition_active and StateSnapshotValidator.same_persisted_value(pending, GameState.get_snapshot()), "rest reload does not replay the selected action")
			var restored: Dictionary = view._recorded_modal_request
			_expect(restored.get("selection_recorded", false) and restored.get("selection_token") == cursor.get("modal", {}).get("selection_token"), "rest reload preserves exact answer token")
			saver.reject_game = false
			saver.lose_ack = true
			view.session._save = saver
			if follow_up == "cancel":
				view._cancel_prologue_modal()
				_expect(not view._modal_active and not view._d6_sleep_transition_active and _same_rest_gameplay(shown, GameState.get_snapshot()), "cancel leaves physical rest unselected")
			else:
				view._recorded_choice_pressed(restored, 1)
				view.set_process(false)
				var expected_route := "bedroom" if route == "bedroom" else "emergency_capsule"
				_expect(view._d6_sleep_transition_active and GameState.get_snapshot().loop_state.event_local_states.get("D6", {}).get("fracture_rest_route") == expected_route and not GameState.get_snapshot().fracture_state.broken_reset_triggered, "explicit retry starts only the selected rest transition")
				view._tick_d6_sleep_transition(2.0)
				view._tick_d6_sleep_transition(2.0)
				view.set_process(false)
				var before_sleep := GameState.get_snapshot()
				saver.reject_game = true
				view._tick_d6_sleep_transition(2.0)
				view.set_process(false)
				_expect(view._d6_sleep_transition_failed and not view._d6_sleep_transition_active and _same_rest_gameplay(before_sleep, GameState.get_snapshot()), "failed reset commit preserves the selected route and physical state")
				saver.reject_game = false
				view._retry_d6_sleep_transition()
				for beat in range(3): view._tick_d6_sleep_transition(2.0)
				view.set_process(false)
				_expect(not view._d6_sleep_transition_failed and view.session.stage() == "E1_ENTRY" and GameState.get_snapshot().fracture_state.broken_reset_triggered, "reset retry reconciles lost acknowledgements and reaches the changed morning")
				_expect(GameState.get_snapshot().loop_state.day_index == shown.loop_state.day_index + 1 and _has("NB_FRACTURE_NOTE_E1_WAKE"), "rest produces exactly one new morning and its wake note")
			var after := GameState.get_snapshot()
			_expect(StateSnapshotValidator.same_persisted_value(answers, _rest_answers(answer_id)), "rest retry/cancel retains one unchanged attempted answer")
			view._recorded_choice_pressed(restored, 1)
			_expect(GameState.get_snapshot() == after, "old rest callback cannot start another sleep")
			view.session._save = SaveManager
			saver.free()
			rest_recovery_cases += 1
			print("NOTEBOOK_REST_RECOVERY: ", TranslationServer.get_locale(), " ", route, " ", follow_up, " ", "PASS" if errors.size() == old_errors else errors.slice(old_errors))


func _same_rest_gameplay(before: Dictionary, after: Dictionary) -> bool:
	var left := before.duplicate(true)
	var right := after.duplicate(true)
	left.loop_state.event_local_states.erase(CURSOR.KEY)
	right.loop_state.event_local_states.erase(CURSOR.KEY)
	if left.loop_state.event_local_states.has("NOTEBOOK_SURFACE_RECEIPT") or right.loop_state.event_local_states.has("NOTEBOOK_SURFACE_RECEIPT"):
		return STATE_ASSERTIONS.same_surface_gameplay(left, right)
	# Some rest rooms expose only labels, so neither snapshot has a surface receipt.
	var old: Dictionary = left.meta_progress.dialogue_history
	var current: Dictionary = right.meta_progress.dialogue_history
	if not ARCHIVE.validate(current).ok: return false
	var added: int = current.entries.size() - old.entries.size()
	if added < 0 or not StateSnapshotValidator.same_persisted_value(old.entries, current.entries.slice(0, old.entries.size())): return false
	var history := current.duplicate(true)
	history.entries = old.entries.duplicate(true)
	history.next_sequence -= added
	history.revision -= added
	if not StateSnapshotValidator.same_persisted_value(old, history): return false
	right.meta_progress.dialogue_history = old.duplicate(true)
	return StateSnapshotValidator.same_persisted_value(left, right)


func _rest_answers(id: String) -> Array:
	return _archive().entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id", "") == id)


func _act(action: String, value: Variant = null) -> Dictionary:
	var result := view.session.act(action, value)
	_expect(result.ok, "actual fracture action " + action + ": " + str(result))
	if result.ok:
		view._render_room()
		view._feedback(result)
		_drain()
	_collect()
	return result


func _drain() -> void:
	for index in range(25):
		if not view._dialogue_active: return
		var before := GameState.get_snapshot()
		view._present_dialogue_line()
		_expect(GameState.get_snapshot() == before, "dialogue redraw is idempotent")
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		view._advance_dialogue()
		if view._dialogue_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			_expect(false, "blocked fracture dialogue: " + str(view._dialogue_lines[view._dialogue_index]))
			view._dismiss_dialogue_for_test()
			return
	_expect(false, "fracture dialogue did not terminate")


func _seed(id: String) -> Dictionary:
	if view != null:
		view._close_modal()
		view._dismiss_dialogue_for_test()
		view.set_process(false)
		view._d5_hold_active = false
		view._d6_sleep_transition_active = false
		view._d6_sleep_transition_failed = false
		view._d6_sleep_transition_route = ""
	var fixture := checkpoints.snapshot_for(id)
	_expect(fixture.ok, "checkpoint " + id)
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.loop_state.event_local_states.erase("D5")
	GameState.reset_for_test()
	_install(state)
	if view != null: view._render_room()
	return state


func _install(state: Dictionary) -> void:
	serial += 1
	var result := StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_FRACTURE_FIXTURE_%d" % serial))
	_expect(result.ok, "fixture install: " + str(result.get("error_ids", [])))


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _latest(id: String) -> Dictionary:
	var revisions: Array = _ledger().revisions
	for index in range(revisions.size() - 1, -1, -1):
		if revisions[index].metadata.knowledge_id == id: return revisions[index]
	_expect(false, "missing fracture note: " + id)
	return {}


func _has(id: String) -> bool:
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: return true
	return false


func _entry(id: String) -> Dictionary:
	var entries: Array = _archive().entries
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].get("record_class") == "authored" and entries[index].observation.content_id == id: return entries[index]
	_expect(false, "missing fracture observation: " + id)
	return {}


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "mapped fracture paths cannot silently become unmapped")
			continue
		if entry.observation.producer_id != "NP09" or entry.observation.content_id.begins_with("NB_FRACTURE_SURFACE_"): continue
		for segment in entry.observation.segments:
			covered[entry.observation.content_id + ":" + segment.viewed_locale] = true
			segments[entry.observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("FRACTURE_NOTE_ASSERT: ", message)
