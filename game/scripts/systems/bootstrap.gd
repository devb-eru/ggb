extends Control

const EXPECTED_ENGINE_MAJOR := 4
const EXPECTED_ENGINE_MINOR := 7
const FOUNDATION_TEST_ARG := "--foundation-smoke"
const START_SCREEN_TEST_ARG := "--start-screen-smoke"
const PROLOGUE_TEST_ARG := "--prologue-smoke"
const FOCUS_RECOVERY_DELAY_SECONDS := 0.15
const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const PROLOGUE_SMOKE_RUNNER := preload("res://scripts/tests/prologue_scene_smoke.gd")
const CHAPTER_ONE_SCRIPT := preload("res://scripts/chapters/chapter_one_controller.gd")
const CHAPTER_ONE_SMOKE := preload("res://scripts/tests/chapter_one_smoke.gd")
const BLACK_MIRROR_SCRIPT := preload("res://scripts/chapters/black_mirror_controller.gd")
const BASEMENT_SCRIPT := preload("res://scripts/chapters/basement_controller.gd")
const BASEMENT_SMOKE := preload("res://scripts/tests/basement_session_smoke.gd")
const BLACK_MIRROR_SMOKE := preload("res://scripts/tests/black_mirror_smoke.gd")
const FULL_CAMPAIGN_SMOKE := preload("res://scripts/tests/full_campaign_smoke.gd")

@onready var _start_screen: StartScreen = %StartScreen

var _load_coordinator: LoadCoordinator
var _reset_coordinator: ResetCoordinator
var _writer: StateWriter
var _focus_resume_serial := 0
var _focus_suspended := false
var _paused_before_focus := false
var _focus_before_pause: WeakRef
var _held_inputs: Dictionary = {}
var _discard_releases: Dictionary = {}
var _window_minimized := false
var _developer_panel
var _developer_catalog := preload("res://scripts/systems/developer_checkpoints.gd").new()
var _developer_paused_nodes: Array[Dictionary] = []
var _developer_active := false
var _developer_previous_flavor: Variant
var _prologue
var _audio := preload("res://scripts/systems/game_audio.gd").new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	_audio.name = "GameAudio"
	add_child(_audio)
	_start_screen.audio_settings_changed.connect(_apply_audio_settings)
	_apply_audio_settings(_start_screen.get_audio_settings())
	_audio.request_cue(&"BGM_TITLE")
	_validate_engine_version()
	if "--generate-developer-checkpoints" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_generate_developer_checkpoints")
	_load_coordinator = LoadCoordinator.new(GameState, SaveManager)
	_reset_coordinator = ResetCoordinator.new(GameState, SaveManager)
	_writer = StateWriter.new(GameState)
	_start_screen.new_game_requested.connect(_on_new_game_requested)
	_start_screen.load_game_requested.connect(_on_load_game_requested)
	_start_screen.quit_requested.connect(_on_quit_requested)
	if OS.is_debug_build() and not "--generate-developer-checkpoints" in OS.get_cmdline_user_args():
		var testing := false
		for argument in OS.get_cmdline_user_args():
			if argument.ends_with("-smoke"): testing = true
		if not testing or "--developer-checkpoint-smoke" in OS.get_cmdline_user_args():
			_setup_developer_panel()
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--dev-jump="):
					call_deferred("_developer_jump", argument.trim_prefix("--dev-jump="))
		if "--developer-checkpoint-smoke" in OS.get_cmdline_user_args():
			call_deferred("_run_developer_checkpoint_smoke")
	print("GGB title bootstrap initialized.")
	if FOUNDATION_TEST_ARG in OS.get_cmdline_user_args():
		if OS.is_debug_build():
			call_deferred("_run_foundation_smoke")
		else:
			push_warning("Foundation smoke is unavailable in release builds.")
	elif START_SCREEN_TEST_ARG in OS.get_cmdline_user_args():
		if OS.is_debug_build():
			call_deferred("_run_start_screen_smoke")
		else:
			push_warning("Start screen smoke is unavailable in release builds.")
	elif PROLOGUE_TEST_ARG in OS.get_cmdline_user_args():
		if OS.is_debug_build():
			call_deferred("_run_prologue_smoke")
		else:
			push_warning("Prologue smoke is unavailable in release builds.")
	elif "--chapter-one-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_chapter_one_smoke")
	elif "--black-mirror-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_black_mirror_smoke")
	elif "--basement-session-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_basement_smoke")
	elif "--full-campaign-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_full_campaign_smoke")
	elif "--application-focus-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_application_focus_smoke")
	elif "--dialogue-history-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_dialogue_history_smoke")
	elif "--notebook-migration-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_notebook_migration_smoke")
	elif "--notebook-content-smoke" in OS.get_cmdline_user_args() and OS.is_debug_build():
		call_deferred("_run_notebook_content_smoke")


func _apply_audio_settings(settings: Dictionary) -> void:
	_audio.set_levels(settings.master, settings.bgm, settings.ambience, settings.effects, settings.muted)


func _run_dialogue_history_smoke() -> void:
	var result: Dictionary = await preload("res://scripts/tests/dialogue_history_smoke.gd").new().run(get_tree())
	print("DIALOGUE_HISTORY_SMOKE: " + ("PASS" if result.ok else str(result)))
	get_tree().quit(0 if result.ok else 1)


func _run_notebook_migration_smoke() -> void:
	var result: Dictionary = preload("res://scripts/tests/notebook_migration_smoke.gd").new().run()
	print("NOTEBOOK_MIGRATION_SMOKE: " + ("PASS" if result.ok else str(result)))
	get_tree().quit(0 if result.ok else 1)


func _run_notebook_content_smoke() -> void:
	var result: Dictionary = await preload("res://scripts/tests/notebook_content_smoke.gd").new().run(get_tree())
	print("NOTEBOOK_CONTENT_SMOKE: " + ("PASS " + str(result) if result.ok else str(result)))
	get_tree().quit(0 if result.ok else 1)


func _generate_developer_checkpoints() -> void:
	var result: Dictionary = await preload("res://scripts/tests/developer_checkpoint_generator.gd").new().generate(get_tree())
	print("DEVELOPER_CHECKPOINT_GENERATION: " + str(result))
	get_tree().quit(0 if result.get("ok", false) else 1)


func _setup_developer_panel() -> void:
	_developer_panel = preload("res://scripts/ui/developer_panel.gd").new()
	_developer_panel.rows = _developer_catalog.entries()
	_developer_panel.jump_requested.connect(_developer_jump)
	_developer_panel.resume_requested.connect(_developer_resume)
	_developer_panel.menu_opened.connect(_developer_pause)
	_developer_panel.menu_closed.connect(_developer_unpause)
	add_child(_developer_panel)
	if not _developer_catalog.error.is_empty():
		_developer_panel.detail.text = _developer_catalog.error


func _developer_pause() -> void:
	_developer_paused_nodes.clear()
	for node in [_start_screen, _prologue]:
		if is_instance_valid(node):
			_developer_paused_nodes.append({"node":weakref(node),"mode":node.process_mode})
			node.process_mode = Node.PROCESS_MODE_DISABLED
	_audio.set_pause_reason(&"developer", true)


func _developer_unpause() -> void:
	for entry in _developer_paused_nodes:
		var node = entry.node.get_ref()
		if is_instance_valid(node): node.process_mode = entry.mode
	_developer_paused_nodes.clear()
	_audio.set_pause_reason(&"developer", false)


func _developer_jump(id: String) -> void:
	_developer_enter(id, false)


func _developer_resume() -> void:
	_developer_enter("", true)


func _developer_enter(id: String, resume: bool) -> void:
	if not OS.is_debug_build(): return
	var previous_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor", null)
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var result: Dictionary = _load_coordinator.load_and_install(_developer_catalog.SLOT) if resume else _developer_catalog.activate(id, GameState, SaveManager)
	if not result.get("ok", false):
		ProjectSettings.set_setting("ggb/build_flavor", previous_flavor)
		_developer_panel.detail.text = "개발 시점 진입 실패. 현재 진행을 유지합니다.\n" + str(result.get("error_ids", result))
		return
	if not _developer_active: _developer_previous_flavor = previous_flavor
	_developer_active = true
	_developer_panel.close()
	# Remove the old controller before a new one can write into the selected snapshot.
	if is_instance_valid(_prologue):
		remove_child(_prologue)
		_prologue.queue_free()
		_prologue = null
	_launch_prologue(_developer_catalog.SLOT, "DEV_CHECKPOINT")
	_developer_panel.launch_button.text = "개발 테스트 · F10"


func _run_developer_checkpoint_smoke() -> void:
	var result: Dictionary = await preload("res://scripts/tests/developer_checkpoint_smoke.gd").new().run(self)
	print("DEVELOPER_CHECKPOINT_SMOKE: " + ("PASS" if result.ok else str(result)))
	get_tree().quit(0 if result.ok else 1)


func _set_menu_audio_pause(paused: bool) -> void:
	_audio.set_pause_reason(&"menu", paused)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_audio.set_pause_reason(&"focus", true)
		_focus_resume_serial += 1
		_suspend_for_focus()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_resume_serial += 1
		var resume_serial := _focus_resume_serial
		_suspend_for_focus()
		get_tree().create_timer(FOCUS_RECOVERY_DELAY_SECONDS).timeout.connect(
			_on_focus_recovery_timeout.bind(resume_serial),
			CONNECT_ONE_SHOT
		)


func _input(event: InputEvent) -> void:
	var token := ""
	if event is InputEventMouseButton:
		token = "mouse:%d" % event.button_index
	elif event is InputEventKey:
		token = "key:%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if _focus_suspended:
		if not token.is_empty():
			if event.is_pressed(): _discard_releases[token] = true
			else: _discard_releases.erase(token)
		get_viewport().set_input_as_handled()
		return
	if token.is_empty(): return
	if _discard_releases.has(token):
		if not event.is_pressed() or event.is_echo():
			if not event.is_pressed(): _discard_releases.erase(token)
			get_viewport().set_input_as_handled()
			return
		_discard_releases.erase(token)
	if event.is_pressed(): _held_inputs[token] = true
	else: _held_inputs.erase(token)


func _process(_delta: float) -> void:
	var minimized := _is_window_minimized()
	if minimized == _window_minimized: return
	_window_minimized = minimized
	if minimized:
		_focus_resume_serial += 1
		_suspend_for_focus()
	elif get_window().has_focus():
		_notification(NOTIFICATION_APPLICATION_FOCUS_IN)


func _is_window_minimized() -> bool:
	# The headless display reports a minimized window even though no OS window exists.
	return DisplayServer.get_name() != "headless" and get_window().mode == Window.MODE_MINIMIZED


func _exit_tree() -> void:
	if _focus_suspended:
		get_tree().paused = _paused_before_focus
		_focus_suspended = false


func _suspend_for_focus() -> void:
	if _focus_suspended: return
	_focus_suspended = true
	_audio.set_pause_reason(&"focus", true)
	_paused_before_focus = get_tree().paused
	for token in _held_inputs: _discard_releases[token] = true
	_held_inputs.clear()
	var control := get_viewport().gui_get_focus_owner()
	_focus_before_pause = weakref(control) if control != null else null
	get_viewport().gui_release_focus()
	_cancel_pending_controls(self)
	if get_viewport().has_method("gui_cancel_drag"):
		get_viewport().call("gui_cancel_drag")
	get_tree().paused = true


func _cancel_pending_controls(node: Node) -> void:
	if node is BaseButton and not node.toggle_mode:
		node.set_pressed_no_signal(false)
	if node is OptionButton:
		node.get_popup().hide()
	for child: Node in node.get_children():
		_cancel_pending_controls(child)


func load_progress_slot(slot_id: String) -> Dictionary:
	return _load_coordinator.load_and_install(slot_id)


func request_sleep_transition(slot_id: String) -> Dictionary:
	match _reset_coordinator.resolve_sleep_route():
		&"NORMAL_RESET":
			return _reset_coordinator.request_normal_reset(slot_id)
		&"BROKEN_RESET":
			return _reset_coordinator.request_broken_reset(slot_id)
		&"RESUME_PENDING_RESET":
			return _reset_coordinator.resume_pending_reset(slot_id)
		&"POST_BROKEN_REST":
			return {"ok": true, "route_id": "POST_BROKEN_REST"}
	return {"ok": false, "error_ids": PackedStringArray(["ERR_RESET_SLEEP_ROUTE"])}


func _on_new_game_requested(slot_id: String) -> void:
	var transaction_id := StringName("NEW_GAME_%s_R%06d" % [slot_id, GameState.revision + 1])
	var commit_result := _writer.install_snapshot(
		GameState.make_default_snapshot(),
		GameState.revision,
		transaction_id
	)
	if not bool(commit_result.get("ok", false)):
		_start_screen.show_save_error(commit_result.get("error_ids", PackedStringArray()))
		return
	var save_result := SaveManager.save_snapshot(
		slot_id,
		"SAVE_NEW_GAME",
		GameState.get_snapshot(),
		GameState.revision,
		String(transaction_id)
	)
	if not bool(save_result.get("ok", false)):
		GameState.rollback_failed_persistence(
			commit_result["previous_snapshot"],
			int(commit_result["revision"]),
			transaction_id,
			StringName(save_result.get("error_id", &"ERR_SAVE_UNKNOWN"))
		)
		_start_screen.show_save_error(save_result.get("error_ids", PackedStringArray()))
		return
	_launch_prologue(slot_id, "P1_ENTRY")


func _on_load_game_requested(slot_id: String) -> void:
	var result := _load_coordinator.load_and_install(slot_id)
	if not bool(result.get("ok", false)):
		_start_screen.show_load_error(result.get("error_ids", PackedStringArray()))
		return
	var resume_id := "%s / %s" % [result["resume_event_id"], result["resume_node_id"]]
	_launch_prologue(slot_id, resume_id)


func _on_quit_requested() -> void:
	get_tree().quit(0)


func _launch_prologue(slot_id: String, resume_id: String) -> void:
	_audio.stop_all()
	_set_menu_audio_pause(false)
	var knowledge: Dictionary = GameState.get_value(&"meta_progress.knowledge_entries", {})
	if bool(knowledge.get("PROLOGUE_COMPLETE", false)):
		if String(GameState.get_value(&"reset_state.phase", "idle")) != "idle" or int(GameState.get_value(&"loop_state.day_index", 0)) == 0:
			var reset_result := request_sleep_transition(slot_id)
			if not reset_result.get("ok", false):
				_start_screen.show_load_error(reset_result.get("error_ids", PackedStringArray()))
				return
		_launch_campaign(slot_id)
		return
	if is_instance_valid(_prologue):
		_prologue.queue_free()
	_prologue = PROLOGUE_SCENE.instantiate()
	_prologue.process_mode = Node.PROCESS_MODE_PAUSABLE
	_prologue.configure_session(slot_id, resume_id)
	_prologue.audio_settings_changed.connect(_apply_audio_settings)
	_prologue.menu_audio_pause_requested.connect(_set_menu_audio_pause)
	_prologue.audio_cue_requested.connect(_audio.request_cue)
	_prologue.audio_room_requested.connect(_audio.enter_room)
	_prologue.return_to_title_requested.connect(_on_prologue_return_to_title)
	_prologue.campaign_requested.connect(_on_campaign_requested.bind(weakref(_prologue)), CONNECT_DEFERRED)
	_start_screen.visible = false
	add_child(_prologue)


func _on_campaign_requested(slot_id: String, source: WeakRef) -> void:
	# A queued transition from a replaced controller must not reuse its old save slot.
	var origin = source.get_ref()
	if is_instance_valid(origin) and origin == _prologue:
		_launch_campaign(slot_id)


func _launch_campaign(slot_id: String) -> void:
	_audio.stop_all()
	_set_menu_audio_pause(false)
	if is_instance_valid(_prologue):
		remove_child(_prologue)
		_prologue.queue_free()
	var mirror_chapter := int(GameState.get_value(&"meta_progress.journal_stage", 0)) >= 2
	var basement_chapter := int(GameState.get_value(&"meta_progress.journal_stage", 0)) >= 3
	_prologue = BASEMENT_SCRIPT.new() if basement_chapter else (BLACK_MIRROR_SCRIPT.new() if mirror_chapter else CHAPTER_ONE_SCRIPT.new())
	_prologue.process_mode = Node.PROCESS_MODE_PAUSABLE
	_prologue.name = "Basement" if basement_chapter else ("BlackMirror" if mirror_chapter else "ChapterOne")
	_prologue.configure_session(slot_id, "MORNING_ROUTE")
	_prologue.audio_settings_changed.connect(_apply_audio_settings)
	_prologue.menu_audio_pause_requested.connect(_set_menu_audio_pause)
	_prologue.audio_cue_requested.connect(_audio.request_cue)
	_prologue.audio_room_requested.connect(_audio.enter_room)
	_prologue.return_to_title_requested.connect(_on_prologue_return_to_title)
	_prologue.campaign_requested.connect(_on_campaign_requested.bind(weakref(_prologue)), CONNECT_DEFERRED)
	_start_screen.visible = false
	add_child(_prologue)


func _on_prologue_return_to_title() -> void:
	if _developer_active:
		ProjectSettings.set_setting("ggb/build_flavor", _developer_previous_flavor)
		_developer_active = false
		_developer_panel.launch_button.text = "개발자 · F10"
	_audio.stop_all()
	_set_menu_audio_pause(false)
	if is_instance_valid(_prologue):
		_prologue.queue_free()
	_prologue = null
	_start_screen.refresh_profile()
	_audio.request_cue(&"BGM_TITLE")
	_start_screen.visible = true
	_start_screen.refresh_slots()


func _on_focus_recovery_timeout(resume_serial: int) -> void:
	if resume_serial == _focus_resume_serial and _focus_suspended and not _is_window_minimized():
		_focus_suspended = false
		get_tree().paused = _paused_before_focus
		_audio.set_pause_reason(&"focus", false)
		var previous: Control = _focus_before_pause.get_ref() as Control if _focus_before_pause != null else null
		_focus_before_pause = null
		if is_instance_valid(previous) and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE:
			if not (previous is BaseButton and previous.disabled):
				previous.grab_focus()
				return
		if _start_screen.visible:
			var modal: Control = _start_screen._active_modal()
			if modal != null:
				_focus_first_control(modal)
			else:
				_start_screen.set_input_suspended(false)
		elif is_instance_valid(_prologue) and is_instance_valid(_prologue._menu_button):
			for field in ["_display_settings_panel", "_key_settings_panel", "_audio_settings_panel", "_modal_body", "_dialogue_layer"]:
				var region: Control = _prologue.get(field)
				if is_instance_valid(region) and region.is_visible_in_tree() and _focus_first_control(region): return
			_prologue._menu_button.grab_focus()


func _focus_first_control(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree(): return false
	if node is Control and node.focus_mode == Control.FOCUS_ALL:
		if not (node is BaseButton and node.disabled):
			node.grab_focus()
			return true
	for child: Node in node.get_children():
		if _focus_first_control(child): return true
	return false


func _validate_engine_version() -> void:
	var version := Engine.get_version_info()
	var major := int(version.get("major", 0))
	var minor := int(version.get("minor", 0))
	if major != EXPECTED_ENGINE_MAJOR or minor != EXPECTED_ENGINE_MINOR:
		push_warning(
			"GGB expects Godot %d.%d.x, but the current runtime is %d.%d.x."
			% [EXPECTED_ENGINE_MAJOR, EXPECTED_ENGINE_MINOR, major, minor]
		)


func _run_foundation_smoke() -> void:
	var runner := FoundationSmokeRunner.new()
	var result := runner.run()
	if bool(result.get("ok", false)):
		print("FOUNDATION_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("FOUNDATION_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_start_screen_smoke() -> void:
	var result := await StartScreenSmokeRunner.new().run(get_tree())
	if bool(result.get("ok", false)):
		print("START_SCREEN_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("START_SCREEN_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_prologue_smoke() -> void:
	var result: Dictionary = await PROLOGUE_SMOKE_RUNNER.new().run(get_tree())
	if bool(result.get("ok", false)):
		print("PROLOGUE_SCENE_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("PROLOGUE_SCENE_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_chapter_one_smoke() -> void:
	var result: Dictionary = await CHAPTER_ONE_SMOKE.new().run(get_tree())
	if bool(result.get("ok", false)):
		print("CHAPTER_ONE_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("CHAPTER_ONE_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_basement_smoke() -> void:
	var result: Dictionary = await BASEMENT_SMOKE.new().run(get_tree())
	if result.get("ok", false):
		print("BASEMENT_SESSION_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("BASEMENT_SESSION_SMOKE: FAIL " + str(result.get("errors", [])))
		get_tree().quit(1)


func _run_black_mirror_smoke() -> void:
	var result: Dictionary = await BLACK_MIRROR_SMOKE.new().run(get_tree())
	if bool(result.get("ok", false)):
		print("BLACK_MIRROR_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("BLACK_MIRROR_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_full_campaign_smoke() -> void:
	var result: Dictionary = await FULL_CAMPAIGN_SMOKE.new().run(get_tree())
	if bool(result.get("ok", false)):
		print("FULL_CAMPAIGN_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("FULL_CAMPAIGN_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)


func _run_application_focus_smoke() -> void:
	var result: Dictionary = await preload("res://scripts/tests/application_focus_smoke.gd").new().run(self)
	if result.ok:
		print("APPLICATION_FOCUS_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("APPLICATION_FOCUS_SMOKE: FAIL " + str(result.errors))
		get_tree().quit(1)
