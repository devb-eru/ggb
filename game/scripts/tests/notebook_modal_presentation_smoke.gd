extends RefCounted

const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const VIEWS := [preload("res://scripts/chapters/chapter_one_controller.gd"), preload("res://scripts/chapters/black_mirror_controller.gd"), preload("res://scripts/chapters/basement_controller.gd")]
const SLOT := "__test_notebook_modal_cursor"
const EXPECTED := "user://__test_notebook_modal_cursor.json"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class ControlledSave extends Node:
	var reject := false
	var reject_game := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject or (reject_game and not transaction.begins_with("HISTORY_")): return {"ok": false, "error_ids": ["TEST_MODAL_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_MODAL_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var phase := "seed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor-phase="): phase = arg.trim_prefix("--cursor-phase=")
	TranslationServer.set_locale("ko-KR" if phase == "seed" else "en-US")
	if "--utility-only" in OS.get_cmdline_user_args():
		if phase == "seed": await _utilities(tree)
		await _utility_process(tree, phase)
		print("NOTEBOOK_UTILITY_CHECKS: ", checks)
		return {"ok": errors.is_empty(), "errors": errors}
	if "--modal-diagram-only" in OS.get_cmdline_user_args():
		await _diagrams(tree)
		return {"ok": errors.is_empty(), "errors": errors}
	if phase == "seed":
		await _cases(tree)
		if not errors.is_empty(): return {"ok": false, "errors": errors}
		_seed("A1")
		var view = _view(tree, 0)
		view._open_mark_choices()
		var controlled := ControlledSave.new()
		controlled.reject_game = true
		view.session._save = controlled
		view._recorded_choice_pressed(view._recorded_modal_request, 0)
		var state := GameState.get_snapshot()
		_expect(CURSOR.read(state).phase == "selection_pending" and view._modal_active, "pending answer restored after gameplay save failure")
		var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "state": state}))
		file.close()
		view.session._save = SaveManager
		controlled.free()
		view.queue_free()
		await tree.process_frame
	elif phase in ["resume", "completed"]:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		_expect(int(expected.pid) != OS.get_process_id(), "separate process restores modal")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload real saved slot")
		var before := GameState.get_snapshot()
		var view = _view(tree, 0)
		_expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.dialogue_history, GameState.get_snapshot().meta_progress.dialogue_history), "reload appends no prompt or answer")
		if phase == "resume":
			_expect(view._modal_active and not GameState.get_snapshot().meta_progress.knowledge_entries.has("self_authored_mark"), "saved answer is not auto executed")
			var request: Dictionary = view._recorded_modal_request
			_expect(request.selection_recorded and request.selection_token == CURSOR.read(expected.state).modal.selection_token, "same pending answer token")
			_expect(request.actions[0].label == CONTENT.definition("NB_MODAL_CH1_MARK_OPTIONS", 1).locales["en-US"].option_0, "current language renders exact choices")
			var count := _selected_count()
			view._recorded_choice_pressed(request, 0)
			_expect(GameState.get_snapshot().meta_progress.knowledge_entries.has("self_authored_mark") and _selected_count() == count, "explicit retry executes gameplay without duplicate selected record")
			while view._dialogue_active: view._advance_dialogue()
		else:
			_expect(GameState.get_snapshot().meta_progress.knowledge_entries.has("self_authored_mark") and not view._modal_active, "successful action never reopens original prompt")
			SaveManager.delete_test_slot(SLOT)
		view.queue_free()
		await tree.process_frame
	else: _expect(false, "unknown phase")
	print("NOTEBOOK_MODAL_PRESENTATION_CHECKS: ", phase, " ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _cases(tree: SceneTree) -> void:
	for spec in [
		["A1", 0, "_open_mark_choices", []], ["B1", 0, "_open_schedule_board", []], ["B3_B", 0, "_confirm_clock", []],
		["AS", 0, "_confirm_sleep", []], ["D6", 2, "_confirm_d6_rest", ["capsule"]],
		["D1", 2, "_confirm_axis", ["line"]], ["D4", 2, "_confirm_auxiliary", []],
		["C4", 1, "_open_patrol", []], ["C4", 1, "_confirm_wet_trace", []],
		["E3_1", 2, "_show_mara1_choice", []], ["E3_2", 2, "_show_iris_choice", []], ["E3_3", 2, "_show_luca_choice", []],
		["E3_4", 2, "_show_edgar_choice", []], ["E3_5", 2, "_show_mara2_choice", []],
		["E3_3", 2, "_show_luca_slot", [0]], ["E3_4", 2, "_show_edgar_owner", ["PROTECTION"]],
		["E3_5", 2, "_show_mara2_source", ["A", "EDGAR"]], ["E3_5", 2, "_show_mara2_alignment", ["A", "start"]],
		["E3_5", 2, "_show_mara2_cell", [2]], ["E_HUB", 2, "_show_j4_confirmation", []],
		["EDC", 2, "_confirm_ending", ["reality"]], ["EDC", 2, "_confirm_ending", ["stay"]],
		["EDR_FIELD_NOTEBOOK", 2, "_open_field_page", ["FIELD_NOTEBOOK_PREFACE", false]],
	]:
		_seed(spec[0])
		var view = _view(tree, spec[1])
		view.callv(spec[2], spec[3])
		var state := GameState.get_snapshot()
		var cursor := CURSOR.read(state)
		_expect(cursor.get("kind") == "modal" and CURSOR.matches(cursor, state) and CURSOR.observed(cursor, state), "durable observed modal " + spec[2])
		if cursor.get("kind") != "modal":
			view.queue_free()
			await tree.process_frame
			continue
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "JSON reload " + spec[2])
		view = _view(tree, spec[1])
		_expect(view._modal_active and not view._dialogue_active, "exact modal restored " + spec[2])
		_expect(StateSnapshotValidator.same_persisted_value(state.meta_progress.dialogue_history, GameState.get_snapshot().meta_progress.dialogue_history), "restore does not redisclose " + spec[2])
		_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "restore preserves full gameplay snapshot " + spec[2])
		_expect(view._recorded_modal_request.history_context.presentation_token == cursor.lines[0].presentation_token, "stable prompt token " + spec[2])
		if spec[2] == "_show_j4_confirmation":
			_expect(view._modal_body.get_child(4).disabled, "restored J4 confirm delay is not bypassed")
		view._close_modal()
		_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "dismissal completion stored")
		view.queue_free()
		await tree.process_frame
	await _failures(tree)
	await _utilities(tree)
	await _idempotent_field_read(tree)
	await _diagrams(tree)


func _utility_process(tree: SceneTree, phase: String) -> void:
	var path := EXPECTED.trim_suffix(".json") + "_utility.json"
	if phase == "seed":
		_seed("C3")
		var view = _view(tree, 1)
		_expect(view._notebook_surface_allowed(), "process fixture captures board")
		view._open_cleaner_quantity_table()
		view._modal_body.get_node("QuantityWaterDifference").button_pressed = true
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "state": GameState.get_snapshot()}))
		file.close()
		view.queue_free()
		await tree.process_frame
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(int(expected.pid) != OS.get_process_id(), "utility resumes in another process")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "utility process loads actual save")
	var view = _view(tree, 1)
	if phase == "resume":
		_expect(view._modal_active and view._modal_body.get_child(0).text == "Compare quantities", "utility reconstructs current-language UI")
		_expect(not view._modal_body.get_node("QuantityRatio").button_pressed and view._modal_body.get_node("QuantityWaterDifference").button_pressed, "utility process retains exact checkbox state")
		_expect(StateSnapshotValidator.same_persisted_value(expected.state, GameState.get_snapshot()), "utility process writes no observation or gameplay")
		view._close_modal()
		_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "utility process explicitly closes")
	elif phase == "completed":
		_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "closed utility never auto-opens in next process")
		SaveManager.delete_test_slot(SLOT)
	else: _expect(false, "unknown utility phase")
	view.queue_free()
	await tree.process_frame


func _utilities(tree: SceneTree) -> void:
	for version in [1, 2, 3]:
		_seed("A1")
		var old_view = _view(tree, 0)
		if version == 3: old_view._open_mark_choices()
		else: old_view._show_dialogue([{"speaker": "SYSTEM", "text": "Historical presentation fixture."}])
		var old_state := GameState.get_snapshot()
		old_state.loop_state.event_local_states[CURSOR.KEY].schema_version = version
		_expect(CURSOR.valid(CURSOR.read(old_state)), "old schema validates: " + str(version))
		_expect(StateWriter.new(GameState).install_snapshot(old_state, GameState.revision, &"UTILITY_OLD_CURSOR_FIXTURE").ok, "old schema installs")
		_expect(SaveManager.save_snapshot(SLOT, old_view.session._save_point(old_state), old_state, GameState.revision, "UTILITY_OLD_CURSOR").ok, "old schema saves to actual slot")
		old_view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "old schema JSON reloads")
		old_view = VIEWS[0].new()
		old_view.configure_session(SLOT, "MORNING_ROUTE")
		tree.current_scene.add_child(old_view)
		_expect(old_view._modal_active if version == 3 else old_view._dialogue_active, "old modal/dialogue restored without manual reopening")
		_expect(StateSnapshotValidator.same_persisted_value(old_state, GameState.get_snapshot()), "old schema restore does not rewrite or disclose")
		old_view.queue_free()
		await tree.process_frame
	for spec in [["B3_B", 0], ["C3", 1], ["C4", 1], ["D1", 2], ["F0_A", 2]]:
		_seed(spec[0])
		var view = _view(tree, spec[1])
		_expect(view._notebook_surface_allowed(), "utility baseline captures world labels")
		var before := GameState.get_snapshot()
		view._show_clock_hint_menu(0)
		var state := GameState.get_snapshot()
		var cursor := CURSOR.read(state)
		_expect(cursor.get("kind") == "utility" and CURSOR.matches(cursor, state), "hint menu has durable display state " + spec[0])
		_expect(_without_cursor(before) == _without_cursor(state), "hint menu reveals no content or game change")
		view._open_menu()
		_expect(not view._utility_request.is_empty() and GameState.get_snapshot() == state, "another menu cannot discard the active utility layer")
		var invalid := cursor.duplicate(true)
		invalid.schema_version = 3
		_expect(not CURSOR.valid(invalid), "utility cannot masquerade as old schema")
		invalid = cursor.duplicate(true)
		invalid.after = {"method": "_do", "args": ["sleep", null, false]}
		_expect(not CURSOR.valid(invalid), "utility cannot carry an executable continuation")
		invalid = cursor.duplicate(true)
		invalid.utility.level = 5
		_expect(not CURSOR.observed(invalid, state), "unseen final hint cannot authorize resumed menu")
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "hint utility JSON reload")
		view = _view(tree, spec[1])
		_expect(view._modal_active and not view._dialogue_active and view._utility_request.utility.level == 0, "hint menu restored without requesting hint")
		_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "hint restore no writes")
		view._modal_body.get_child(4).pressed.emit()
		_expect(view._dialogue_active, "explicit button requests H1")
		view._advance_dialogue()
		_expect(view._modal_active and view._utility_request.utility.level == 1, "acknowledgement returns to next request menu")
		state = GameState.get_snapshot()
		_expect(CURSOR.observed(CURSOR.read(state), state), "H1 authorizes resumed next request")
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "H1 menu reload")
		view = _view(tree, spec[1])
		_expect(view._modal_active and view._utility_request.utility.level == 1 and not view._dialogue_active, "no automatic H2 disclosure after reload")
		_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "H1 restore preserves archive and puzzle")
		var stale = view._modal_body.get_child(4)
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload while old utility remains")
		before = GameState.get_snapshot()
		stale.pressed.emit()
		_expect(GameState.get_snapshot() == before and not view._dialogue_active, "old utility button cannot disclose after reload")
		view.queue_free()
		await tree.process_frame
	_seed("C3")
	var view = _view(tree, 1)
	_expect(view._notebook_surface_allowed(), "quantity baseline captures labels")
	var before := GameState.get_snapshot()
	view._open_cleaner_quantity_table()
	var ratio = view._modal_body.get_node("QuantityRatio")
	ratio.button_pressed = true
	var state := GameState.get_snapshot()
	_expect(CURSOR.read(state).utility.ratio and not CURSOR.read(state).utility.difference, "quantity toggle persists")
	_expect(_without_cursor(before) == _without_cursor(state), "quantity toggle leaves actual amounts, relationship and observations unchanged")
	var controlled := ControlledSave.new()
	controlled.reject = true
	view.session._save = controlled
	var difference = view._modal_body.get_node("QuantityWaterDifference")
	difference.button_pressed = true
	_expect(not difference.button_pressed and GameState.get_snapshot() == state, "failed quantity save restores previous check state")
	view._close_modal()
	_expect(view._modal_active and GameState.get_snapshot() == state, "failed dismissal retains utility and game state")
	view.session._save = SaveManager
	controlled.free()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "quantity JSON reload")
	view = _view(tree, 1)
	_expect(view._modal_active and view._modal_body.get_node("QuantityRatio").button_pressed and not view._modal_body.get_node("QuantityWaterDifference").button_pressed, "quantity filters restored without applying mixture")
	_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "quantity restore no writes")
	var stale_ratio = view._modal_body.get_node("QuantityRatio")
	view._open_cleaner_quantity_table()
	state = GameState.get_snapshot()
	stale_ratio.button_pressed = false
	_expect(GameState.get_snapshot() == state and not view._modal_body.get_node("QuantityRatio").button_pressed, "old quantity toggle cannot overwrite a newer tool")
	view._close_modal()
	_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "utility dismissal durable")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "closed utility reload")
	view = _view(tree, 1)
	_expect(not view._modal_active, "closed utility is not reopened")
	view.queue_free()
	await tree.process_frame
	_seed("BF")
	state = GameState.get_snapshot()
	state.meta_progress.failure_knowledge.B3_B.attempts = 2
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"UTILITY_FAILURE_FIXTURE").ok, "repeated failure fixture")
	view = _view(tree, 0)
	view._offer_clock_failure_support()
	_expect(view._modal_active and CURSOR.read(GameState.get_snapshot()).get("utility", {}).get("type") == "failure", "repeated failure support persisted")
	state = GameState.get_snapshot()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "failure support reload")
	view = _view(tree, 0)
	_expect(view._modal_active and not view._dialogue_active and StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "failure support restores without stronger hint or repairing pins")
	view.queue_free()
	await tree.process_frame


func _without_cursor(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.loop_state.event_local_states.erase(CURSOR.KEY)
	return result


func _idempotent_field_read(tree: SceneTree) -> void:
	_seed("EDR_FIELD_NOTEBOOK")
	var view = _view(tree, 2)
	var page := "FIELD_NOTEBOOK_PREFACE"
	view._open_field_page(page, true)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "first field acknowledgement completes its modal atomically")
	var read_state: Dictionary = GameState.get_snapshot().loop_state.event_local_states.FIELD_NOTEBOOK.duplicate(true)
	view._open_field_page(page, true)
	var controlled := ControlledSave.new()
	controlled.reject_game = true
	view.session._save = controlled
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	var pending := CURSOR.read(GameState.get_snapshot())
	_expect(view._modal_active and pending.phase == "selection_pending", "failed reread retains pending modal even though read state was already satisfied")
	var selected := _selected_count()
	view.session._save = SaveManager
	controlled.free()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "failed reread reloads")
	view = _view(tree, 2)
	_expect(view._modal_active and view._recorded_modal_request.selection_token == pending.modal.selection_token, "failed reread resumes original explicit choice")
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "successful idempotent reread does not reopen pending choices")
	_expect(_selected_count() == selected and StateSnapshotValidator.same_persisted_value(read_state, GameState.get_snapshot().loop_state.event_local_states.FIELD_NOTEBOOK), "reread retry does not duplicate selection or game reading state")
	_expect(CURSOR.read(SaveManager.load_slot(SLOT).snapshot).phase == "completed", "successful reread completion is on disk, not only dismissed in memory")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "completed reread reloads")
	view = _view(tree, 2)
	_expect(not view._modal_active and _selected_count() == selected, "completed reread is not replayed on reload")
	view._open_field_page(page, true)
	view._recorded_choice_pressed(view._recorded_modal_request, 2)
	_expect(view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "choosing" and view._recorded_modal_request.title != view.FIELD_TEXTS.title(page, TranslationServer.get_locale()), "idempotent next-page acknowledgement opens only the explicitly requested next page")
	view.queue_free()
	await tree.process_frame


func _failures(tree: SceneTree) -> void:
	_seed("A1")
	var view = _view(tree, 0)
	var controlled := ControlledSave.new()
	view.session._save = controlled
	controlled.reject = true
	var before := GameState.get_snapshot()
	view._open_mark_choices()
	_expect(GameState.get_snapshot() == before and not view._recorded_modal_request.recorded, "prompt failure rolls back cursor and history")
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(GameState.get_snapshot() == before, "failed prompt cannot execute")
	controlled.reject = false
	controlled.lose_ack = true
	_expect(view._record_modal_options(view._recorded_modal_request), "lost prompt acknowledgement reconciled")
	controlled.lose_ack = false
	controlled.reject_game = true
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	var token: String = view._recorded_modal_request.selection_token
	var count := _selected_count()
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(_selected_count() == count and view._recorded_modal_request.selection_token == token and view._modal_active, "same failed action retries same answer")
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(_selected_count() == count + 2 and view._recorded_modal_request.selection_token != token, "A-B-A is distinct explicit selection history")
	controlled.reject_game = false
	controlled.reject = true
	before = GameState.get_snapshot()
	view._close_modal()
	_expect(view._modal_active and GameState.get_snapshot() == before, "failed dismissal does not close modal")
	controlled.reject = false
	var stale: Dictionary = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "new load epoch")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(stale, 0)
	_expect(GameState.get_snapshot() == before, "stale callback cannot execute")
	view.session._save = SaveManager
	controlled.free()
	view.queue_free()
	await tree.process_frame
	_expect(not CURSOR.MODAL.valid_route({"method": "queue_free", "args": []}), "arbitrary controller callback rejected")
	var bad := CURSOR.read(before)
	bad.modal.routes[0] = {"method": "_modal_act", "args": [null]}
	_expect(not CURSOR.valid(bad), "malformed action rejected")


func _diagrams(tree: SceneTree) -> void:
	_seed("C4")
	var view = _view(tree, 1)
	var local: Dictionary = view.session.mirror_local().duplicate(true)
	local.path = ["entry", "long_branch"]
	view._show_route_feedback(local)
	var state := GameState.get_snapshot()
	_expect(view._recorded_modal_request.recorded, "route observation saved: " + view._status_label.text)
	var captured := CURSOR.read(state)
	_expect(captured.get("kind") == "modal", "route cursor stored: " + str(captured.get("kind")))
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "diagram reload")
	view = _view(tree, 1)
	_expect(view._modal_active and view._modal_body.has_node("MirrorRouteFeedback"), "route diagram rebuilt")
	var restored := CURSOR.read(GameState.get_snapshot())
	_expect(restored.get("modal", {}).get("view", {}).get("local", {}).get("path") == local.path, "pre-dry path retained, not rebuilt from current world; " + str(restored.get("kind")))
	if not view._modal_active:
		view.queue_free()
		await tree.process_frame
		return
	var before := GameState.get_snapshot()
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_expect(GameState.get_snapshot() == before, "diagram replay is UI-only")
	_expect(StateSnapshotValidator.same_persisted_value(state.meta_progress.dialogue_history, before.meta_progress.dialogue_history), "diagram restore no observation")
	view.queue_free()
	await tree.process_frame
	await _overlay(tree)


func _overlay(tree: SceneTree) -> void:
	_seed("C4")
	var view = _view(tree, 1)
	var state := GameState.get_snapshot()
	var local: Dictionary = view.session.mirror_local().duplicate(true)
	local.rotation = 270
	local.flipped = true
	local.anchored = true
	state.loop_state.event_local_states[view.session.MIRROR_KEY] = local
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"OVERLAY_CURSOR_FIXTURE").ok, "nondefault overlay fixture")
	view._render_room()
	view._open_trace_overlay()
	state = GameState.get_snapshot()
	_expect(view._recorded_modal_request.recorded and CURSOR.read(state).get("kind") == "modal", "overlay observation and cursor saved together")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "overlay JSON reload")
	view = _view(tree, 1)
	var overlay = view._modal_body.get_node_or_null("MirrorOverlayDiagram")
	_expect(view._modal_active and overlay != null, "overlay view recreated")
	if overlay != null:
		_expect(overlay.turn_degrees == 270 and overlay.mirrored and overlay.fixed_anchor, "rotation, reflection and anchor preserved")
	_expect(StateSnapshotValidator.same_persisted_value(state, GameState.get_snapshot()), "overlay restore leaves world, read state and archive unchanged")
	view._close_modal()
	_expect(CURSOR.read(GameState.get_snapshot()).phase == "completed", "overlay dismissal persisted")
	view.queue_free()
	await tree.process_frame


func _seed(checkpoint: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	var fixture := CHECKPOINTS.new().snapshot_for(checkpoint)
	_expect(fixture.ok, "checkpoint " + checkpoint)
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase("notebook_knowledge")
	state.meta_progress.knowledge_entries.erase("chapter_notebook")
	state.loop_state.event_local_states.erase(CURSOR.KEY)
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("MODAL_CURSOR_%d" % serial)).ok, "fixture install")


func _view(tree: SceneTree, index: int):
	var view = VIEWS[index].new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	if CURSOR.read(GameState.get_snapshot()).get("kind") != "modal": view._dismiss_dialogue_for_test()
	return view


func _selected_count() -> int:
	return GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("entry_kind", "") == "choice_confirmed").size()


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition: errors.append(label)
