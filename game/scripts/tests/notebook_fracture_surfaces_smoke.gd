extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const TEXTS := preload("res://scripts/ui/fracture_surface_texts.gd")
const SLOT := "__test_notebook_fracture_surfaces"
var errors := PackedStringArray()
var covered := {}
var view: BasementController
var serial := 0
var checkpoints := CHECKPOINTS.new()

class ControlledSave extends Node:
	var delegate: Node
	var reject_history := false
	var reject_game := false
	var lose_ack := false
	var history_attempts := 0
	func get_build_flavor() -> String: return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if transaction.begins_with("HISTORY_"): history_attempts += 1
		if (reject_history and transaction.begins_with("HISTORY_")) or (reject_game and transaction.begins_with("CH1_")):
			return {"ok": false, "error_ids": ["ERR_TEST_SURFACE_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_SURFACE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_seed("D5")
	view = VIEW.new()
	view.configure_session(SLOT, "D5")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		_full_hold()
		for route in ["bedroom", "capsule"]: _sleep(route)
		_guidance()
		_demo()
		await _questions()
		await _failures(tree)
		for key in TEXTS.authored_rows(): _expect(covered.has(TEXTS.PREFIX + key + ":" + locale), "unexecuted surface: " + key + ":" + locale)
	view.queue_free()
	await tree.process_frame
	for flavor in ["full", "demo"]:
		ProjectSettings.set_setting("ggb/build_flavor", flavor)
		SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": TEXTS.authored_rows().size(), "covered_id_locales": covered.size(),
		"not_covered": ["durable_app_restart_cursor", "OS_input", "shared_notebook_UI", "other_producers_static_panels"]}


func _full_hold() -> void:
	_seed("D5")
	_present()
	_expect(_count("D5_IDLE") == 1 and _count("HOLD_0") == 0, "idle does not reveal the first timed beat")
	var before := GameState.get_snapshot()
	view._render_room()
	_present()
	_expect(GameState.get_snapshot() == before, "a room redraw is not another observation")
	view._begin_full_fracture_hold()
	_present()
	_expect(_count("HOLD_0") == 1 and _count("HOLD_1") == 0, "only the first hold beat has appeared")
	view._tick_full_d5_hold(3.0)
	_present()
	_expect(_count("HOLD_1") == 1 and _count("HOLD_2") == 0, "the second beat does not disclose the third")
	view._tick_full_d5_hold(4.0)
	_present()
	var first: Dictionary = view._notebook_surfaces.requests[TEXTS.PREFIX + "HOLD_0"].context
	var third: Dictionary = view._notebook_surfaces.requests[TEXTS.PREFIX + "HOLD_2"].context
	_expect(first.event_occurrence_id == third.event_occurrence_id and first.conversation_session_id == third.conversation_session_id and first.presentation_token != third.presentation_token, "successive panels share an occurrence/session while retaining distinct display tokens")
	view._tick_full_d5_hold(3.0)
	_drain()
	_expect(view.session.stage() == "D6" and not GameState.get_snapshot().fracture_state.broken_reset_triggered, "all displayed hold beats lead to dialogue, not an early reset")
	_present()
	_expect(_count("D6_ENTRY") == 1, "the newly exposed rest directions are a separate displayed board")
	_collect()


func _sleep(route: String) -> void:
	_seed("D6")
	_present()
	view._do("d6_move", "H0_SERVICE_SPINE", false)
	if route == "bedroom": view._do("d6_move", "M2_BEDROOM", false)
	view._confirm_d6_rest(route)
	view._modal_body.get_child(4).pressed.emit()
	_present()
	var prefix := "SLEEP_" + route.to_upper() + "_"
	_expect(_count(prefix + "0") == 1 and _count(prefix + "1") == 0, "rest confirmation only discloses the first displayed sleep beat")
	view._tick_d6_sleep_transition(2.0)
	_present()
	_expect(_count(prefix + "1") == 1 and _count(prefix + "2") == 0, "future baseline information remains hidden")
	view._tick_d6_sleep_transition(2.0)
	_present()
	view._tick_d6_sleep_transition(2.0)
	_drain()
	_expect(view.session.stage() == "E1_ENTRY", "both unchanged rest routes reach the different morning")
	for index in range(3): _expect(_count(prefix + str(index)) == 1, "one observation per actually displayed sleep beat")
	_collect()


func _guidance() -> void:
	_seed("D6")
	_present()
	for delta in [180.0, 120.0, 180.0]: view._tick_d6_guidance(delta)
	for key in ["GUIDANCE_180", "GUIDANCE_300_DEFAULT", "GUIDANCE_480"]: _expect(_count(key) == 1, "actual default guidance: " + key)
	_collect()
	for owner in TEXTS.REST.GUIDANCE_300:
		for mode in ["bond", "alert"]:
			_seed("D6", "full", {"owner": owner, "mode": mode})
			_present()
			view._tick_d6_guidance(180.0)
			view._tick_d6_guidance(120.0)
			var key := TEXTS.guidance_key(300, {"owner": owner, "mode": mode})
			_expect(_count(key) == 1 and _count("GUIDANCE_300_DEFAULT") == 0, "guidance uses only the frozen companion and mode")
			_expect(view._status_label.text == TEXTS.guidance_text(300, {"owner": owner, "mode": mode}, TranslationServer.get_locale()), "captured guidance is the actual status text")
			_collect()


func _demo() -> void:
	_seed("D5", "demo")
	_present()
	for index in range(1, 6):
		_expect(_count("DEMO_%d" % index) == 0, "future demo beat remains undisclosed")
		view._tick_demo_stinger(10.0)
		_present()
	view._tick_demo_stinger(10.0)
	_expect(view.session.stage() == "DEMO_END", "actual six-beat demo still terminates normally")
	for entry in _archive().entries:
		if entry.get("record_class") == "authored": _expect(not entry.observation.content_id.begins_with("NB_FRACTURE_TRANSITION_"), "demo cannot disclose full-game transition dialogue")
	_collect()
	for owner in TEXTS.TRANSITION.REACTIONS:
		for mode in ["bond", "alert"]:
			if not TEXTS.TRANSITION.REACTIONS[owner].has(mode + "_ko"): continue
			_seed("D5", "demo", {"owner": owner, "mode": mode})
			view._demo_stinger_seconds = 30.0
			view._render_room()
			_present()
			_expect(_count(TEXTS.demo_key(3, {"owner": owner, "mode": mode})) == 1 and _count("DEMO_3") == 0, "demo captures the actually displayed combined reaction, not an invented default")
			_collect()


func _questions() -> void:
	_seed("LUCA_GUIDE")
	_present()
	view._do("move", "M1_KITCHEN", false)
	_present()
	_expect(_count("LUCA_GUIDE") == 1 and _count("LUCA_S2") == 1 and _count("OPTIONS_LUCA") == 1, "boards and presented actions are separate observations")
	_expect(_count("SELECT_LUCA_0") == 0, "showing the question is not asking it")
	_press("LUCA_S2_0")
	_drain()
	_press("LUCA_S2_0")
	_drain()
	_expect(_count("SELECT_LUCA_0") == 2 and _count("OPTIONS_LUCA") == 1, "genuinely repeated questions are new selections, redraws are not")
	var bond: int = GameState.get_snapshot().meta_progress.servants.luca.bond
	_press("LUCA_S2_1")
	_drain()
	_expect(int(GameState.get_snapshot().meta_progress.servants.luca.bond) == mini(5, bond + 1), "handholding applies its original relationship change once")
	_collect()
	_seed("LUCA_S2")
	_present()
	_press("LUCA_S2_2")
	_drain()
	_collect()
	_seed("E2_INTRO")
	_present()
	_expect(_count("OPTIONS_E2") == 0, "report questions are absent before the report")
	view._do("e2_report")
	_expect(_count("OPTIONS_E2") == 0, "the dialogue overlay does not prematurely disclose questions behind it")
	_drain()
	_expect(_count("OPTIONS_E2") == 1, "questions become observed after the report overlay closes")
	for index in range(3):
		_press("E2_Q_%d" % index)
		_drain()
	view._do("e2_finish")
	_drain()
	_expect(_count("E_HUB") == 1 and view.session.stage() == "E_HUB", "destination board appears only after the report has finished")
	var before := GameState.get_snapshot()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == before, "notebook re-reading does not create board observations or replay actions")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "surface evidence survives real JSON reload")
	_collect()


func _failures(tree: SceneTree) -> void:
	_seed("D5")
	_present()
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	view.session._save = controlled
	view._begin_full_fracture_hold()
	controlled.reject_history = true
	view._tick_full_d5_hold(4.0)
	_expect(view._d5_hold_seconds == 0.0 and _count("HOLD_0") == 0, "history failure freezes the timer before any further beat")
	_expect(view._hotspot_layer.get_node_or_null("NOTEBOOK_SURFACE_RETRY") != null, "failed visible surface has an explicit retry control")
	var attempts := controlled.history_attempts
	for index in range(5): view._tick_full_d5_hold(1.0)
	_expect(controlled.history_attempts == attempts and view._d5_hold_seconds == 0.0, "failed surface waits for explicit input without a per-frame disk retry loop")
	var token: String = view._notebook_surfaces.requests[TEXTS.PREFIX + "HOLD_0"].context.presentation_token
	view._render_room()
	view.set_process(false)
	_expect(not view._notebook_surface_allowed(), "redraw retains the pending failed observation")
	var retry := view._hotspot_layer.get_node("NOTEBOOK_SURFACE_RETRY") as Button
	var retry_id := retry.get_instance_id()
	retry.grab_focus()
	_expect(retry.has_focus(), "keyboard user can focus the explicit history retry")
	controlled.reject_history = false
	controlled.lose_ack = true
	retry.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var restored := view.get_viewport().gui_get_focus_owner()
	_expect(restored != null and restored.get_instance_id() != retry_id and restored.is_visible_in_tree(), "successful retry restores keyboard focus to a live world control")
	_expect(_count("HOLD_0") == 1 and view._notebook_surfaces.requests[TEXTS.PREFIX + "HOLD_0"].context.presentation_token == token, "redraw and lost acknowledgement reuse the same presentation token")
	var before := GameState.get_snapshot()
	_present()
	_expect(GameState.get_snapshot() == before, "acknowledged surface retry is idempotent")
	_collect()
	_seed("D6")
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	view._tick_d6_guidance(180.0)
	_expect(int(GameState.get_snapshot().loop_state.event_local_states.D6.guidance_checkpoint) == 180 and _count("GUIDANCE_180") == 0, "guidance checkpoint is not evidence of a failed display save")
	view._tick_d6_guidance(120.0)
	view._do("d6_move", "H0_SERVICE_SPINE", false)
	_expect(view._d6_guidance_seconds == 180.0 and view.session.snapshot().loop_state.location_id != "H0_SERVICE_SPINE", "failed guidance cannot be skipped by time or world input")
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en-US" if original_locale.begins_with("ko") else "ko-KR")
	view._render_room()
	controlled.reject_history = false
	_expect(not view._notebook_surface_allowed(), "language change does not silently retry a failed surface")
	_press("NOTEBOOK_SURFACE_RETRY")
	_present()
	var guidance: Dictionary = view._notebook_surfaces.requests[TEXTS.PREFIX + "GUIDANCE_180"]
	_expect(guidance.locale == original_locale and _count("GUIDANCE_180") == 1, "language change and redraw retain the failed observation's original locale")
	TranslationServer.set_locale(original_locale)
	_collect()
	_seed("LUCA_S2")
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	_press("LUCA_S2_1")
	_expect(not view.session.known("LUCA_S2_complete") and _count("SELECT_LUCA_1") == 0, "selection save failure cannot execute handholding")
	controlled.reject_history = false
	controlled.reject_game = true
	_press("LUCA_S2_1")
	_expect(not view.session.known("LUCA_S2_complete") and _count("SELECT_LUCA_1") == 1, "saved input is not proof of a failed gameplay commit")
	controlled.reject_game = false
	_press("LUCA_S2_1")
	_drain()
	_expect(view.session.known("LUCA_S2_complete") and _count("SELECT_LUCA_1") == 1, "retrying the failed gameplay commit does not duplicate the successful input record")
	_collect()
	_seed("LUCA_S2")
	_present()
	var callback := _callback("LUCA_S2_1")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "actual slot reload")
	before = GameState.get_snapshot()
	callback.call()
	_expect(GameState.get_snapshot() == before, "pre-load world callback cannot change the new state")
	view._render_room()
	_present()
	callback = _callback("LUCA_S2_1")
	view._render_room()
	before = GameState.get_snapshot()
	callback.call()
	_expect(GameState.get_snapshot() == before, "a superseded button generation cannot execute a selection")
	_present()
	callback = _callback("LUCA_S2_1")
	for field in ["view_slot", "session_slot", "namespace"]:
		var old_slot := view._slot_id
		var old_session_slot := view.session.slot_id
		var old_namespace: Variant = ProjectSettings.get_setting("ggb/build_flavor")
		if field == "view_slot": view._slot_id = SLOT + "_other"
		elif field == "session_slot": view.session.slot_id = SLOT + "_other"
		else: ProjectSettings.set_setting("ggb/build_flavor", "demo")
		before = GameState.get_snapshot()
		callback.call()
		_expect(GameState.get_snapshot() == before, "changed " + field + " invalidates the old world callback")
		view._slot_id = old_slot
		view.session.slot_id = old_session_slot
		ProjectSettings.set_setting("ggb/build_flavor", old_namespace)
	var forked := GameState.get_snapshot()
	forked.meta_progress.dialogue_history = ARCHIVE.fork(forked.meta_progress.dialogue_history).archive
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(forked, GameState.revision, StringName("NB_SURFACE_FORK_%d" % serial)).ok, "branch fixture install")
	before = GameState.get_snapshot()
	callback.call()
	_expect(GameState.get_snapshot() == before, "a different archive branch rejects the old world callback")
	_collect()
	view.session._save = SaveManager
	controlled.free()


func _seed(id: String, flavor: String = "full", reaction: Dictionary = {}) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
		view.set_process(false)
		view._d5_hold_active = false
		view._d5_hold_seconds = 0.0
		view._demo_stinger_seconds = 0.0
		view._demo_stinger_save_failed = false
		view._d6_guidance_seconds = 0.0
		view._d6_guidance_failed = false
		view._d6_sleep_transition_active = false
		view._d6_sleep_transition_failed = false
		view._d6_sleep_transition_route = ""
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	var fixture := checkpoints.snapshot_for(id)
	_expect(fixture.ok, "checkpoint " + id)
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase("notebook_knowledge")
	state.loop_state.event_local_states.D5 = {"D4_REACTION": reaction} if not reaction.is_empty() else {}
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_SURFACE_FIXTURE_%d" % serial)).ok, "fixture install")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual surface capture")
	view.set_process(false)


func _press(id: String) -> void: _callback(id).call()


func _callback(id: String) -> Callable:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	if button == null:
		_expect(false, "missing world button: " + id)
		return func() -> void: pass
	return button.pressed.get_connections()[0].callable


func _drain() -> void:
	for index in range(30):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false, "dialogue remains blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _count(key: String) -> int:
	var found := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == TEXTS.PREFIX + key: found += 1
	return found


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored" or not entry.observation.content_id.begins_with(TEXTS.PREFIX): continue
		var observed: Dictionary = entry.observation
		covered[observed.content_id + ":" + observed.segments[0].viewed_locale] = true
		var translated := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(translated.ok and not translated.entry.fallback, "surface has a fixed translation without fallback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("FRACTURE_SURFACE_ASSERT: ", message)
