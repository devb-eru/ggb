extends Control

const EXPECTED_ENGINE_MAJOR := 4
const EXPECTED_ENGINE_MINOR := 7
const FOUNDATION_TEST_ARG := "--foundation-smoke"
const START_SCREEN_TEST_ARG := "--start-screen-smoke"
const PROLOGUE_TEST_ARG := "--prologue-smoke"
const FOCUS_RECOVERY_DELAY_SECONDS := 0.15
const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const PROLOGUE_SMOKE_RUNNER := preload("res://scripts/tests/prologue_scene_smoke.gd")

@onready var _start_screen: StartScreen = %StartScreen

var _load_coordinator: LoadCoordinator
var _reset_coordinator: ResetCoordinator
var _writer: StateWriter
var _focus_resume_serial := 0
var _prologue


func _ready() -> void:
	_validate_engine_version()
	_load_coordinator = LoadCoordinator.new(GameState, SaveManager)
	_reset_coordinator = ResetCoordinator.new(GameState, SaveManager)
	_writer = StateWriter.new(GameState)
	_start_screen.new_game_requested.connect(_on_new_game_requested)
	_start_screen.load_game_requested.connect(_on_load_game_requested)
	_start_screen.quit_requested.connect(_on_quit_requested)
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


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_resume_serial += 1
		_start_screen.set_input_suspended(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_resume_serial += 1
		var resume_serial := _focus_resume_serial
		_start_screen.set_input_suspended(true)
		get_tree().create_timer(FOCUS_RECOVERY_DELAY_SECONDS).timeout.connect(
			_on_focus_recovery_timeout.bind(resume_serial),
			CONNECT_ONE_SHOT
		)


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
	if is_instance_valid(_prologue):
		_prologue.queue_free()
	_prologue = PROLOGUE_SCENE.instantiate()
	_prologue.configure_session(slot_id, resume_id)
	_prologue.return_to_title_requested.connect(_on_prologue_return_to_title)
	_start_screen.visible = false
	add_child(_prologue)


func _on_prologue_return_to_title() -> void:
	if is_instance_valid(_prologue):
		_prologue.queue_free()
	_prologue = null
	_start_screen.visible = true
	_start_screen.refresh_slots()


func _on_focus_recovery_timeout(resume_serial: int) -> void:
	if resume_serial == _focus_resume_serial:
		_start_screen.set_input_suspended(false)


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
