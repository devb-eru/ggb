extends Control

const EXPECTED_ENGINE_MAJOR := 4
const EXPECTED_ENGINE_MINOR := 7
const FOUNDATION_EVENT_ID := &"FOUNDATION_SMOKE"
const FOUNDATION_TARGET_ID := &"OBJ_FOUNDATION_CONSOLE"
const FOUNDATION_TEST_ARG := "--foundation-smoke"
const FOCUS_RECOVERY_DELAY_SECONDS := 0.15

@onready var _input_router: InputRouter = $InputRouter
@onready var _interaction_router: InteractionRouter = $InteractionRouter
@onready var _run_event_button: Button = %RunFoundationEvent
@onready var _notebook_button: Button = %OpenNotebook
@onready var _inventory_button: Button = %OpenInventory
@onready var _status: Label = %Status

var _focus_resume_serial := 0
var _focus_before_suspend: Control


func _ready() -> void:
	var version := Engine.get_version_info()
	var major := int(version.get("major", 0))
	var minor := int(version.get("minor", 0))

	if major != EXPECTED_ENGINE_MAJOR or minor != EXPECTED_ENGINE_MINOR:
		push_warning(
			"GGB expects Godot %d.%d.x, but the current runtime is %d.%d.x."
			% [EXPECTED_ENGINE_MAJOR, EXPECTED_ENGINE_MINOR, major, minor]
		)

	_input_router.confirm_requested.connect(_on_confirm_requested)
	_input_router.focus_move_requested.connect(_on_focus_move_requested)
	_input_router.toggle_requested.connect(_on_toggle_requested)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_completed.connect(_on_event_completed)
	EventManager.event_rejected.connect(_on_event_rejected)
	_run_event_button.grab_focus()

	print("GGB production bootstrap initialized.")
	if FOUNDATION_TEST_ARG in OS.get_cmdline_user_args():
		if OS.is_debug_build():
			call_deferred("_run_foundation_smoke")
		else:
			push_warning("Foundation smoke is unavailable in release builds.")


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_resume_serial += 1
		_set_ui_input_suspended(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_resume_serial += 1
		var resume_serial := _focus_resume_serial
		_set_ui_input_suspended(true)
		get_tree().create_timer(FOCUS_RECOVERY_DELAY_SECONDS).timeout.connect(
			_on_focus_recovery_timeout.bind(resume_serial),
			CONNECT_ONE_SHOT
		)


func _on_run_foundation_event_pressed() -> void:
	_request_foundation_event()


func _on_open_notebook_pressed() -> void:
	_status.text = "Notebook fixture opened. Press Escape to return."


func _on_open_inventory_pressed() -> void:
	_status.text = "Inventory fixture opened. Press Escape to return."


func _on_confirm_requested() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == _run_event_button:
		_request_foundation_event()
	elif focus_owner is Button:
		(focus_owner as Button).pressed.emit()


func _on_focus_move_requested(direction: int) -> void:
	var controls: Array[Control] = [_run_event_button, _notebook_button, _inventory_button]
	var focus_owner := get_viewport().gui_get_focus_owner()
	var current_index := controls.find(focus_owner)
	if current_index < 0:
		current_index = 0
	else:
		current_index = posmod(current_index + direction, controls.size())
	controls[current_index].grab_focus()


func _on_toggle_requested(action_id: StringName) -> void:
	match action_id:
		&"notebook_toggle":
			_on_open_notebook_pressed()
			_notebook_button.grab_focus()
		&"inventory_toggle":
			_on_open_inventory_pressed()
			_inventory_button.grab_focus()
		&"ui_cancel":
			_status.text = "Ready."
			_run_event_button.grab_focus()


func _request_foundation_event() -> void:
	if not _interaction_router.request_interaction(FOUNDATION_TARGET_ID, FOUNDATION_EVENT_ID):
		_status.text = "The interaction is already running or was consumed this frame."


func _set_ui_input_suspended(suspended: bool) -> void:
	var buttons: Array[Button] = [_run_event_button, _notebook_button, _inventory_button]
	if suspended:
		var focus_owner := get_viewport().gui_get_focus_owner()
		_focus_before_suspend = focus_owner if focus_owner is Control else _run_event_button
	for button in buttons:
		button.disabled = suspended
		button.focus_mode = Control.FOCUS_NONE if suspended else Control.FOCUS_ALL
	if suspended:
		get_viewport().gui_release_focus()
	elif is_instance_valid(_focus_before_suspend):
		_focus_before_suspend.grab_focus()
	else:
		_run_event_button.grab_focus()


func _on_focus_recovery_timeout(resume_serial: int) -> void:
	if resume_serial == _focus_resume_serial:
		_set_ui_input_suspended(false)


func _on_event_started(event_id: StringName, _node_id: StringName) -> void:
	_status.text = "Started: %s" % event_id


func _on_event_completed(event_id: StringName, _result_id: StringName) -> void:
	_status.text = "Completed: %s (revision %d)" % [event_id, GameState.revision]


func _on_event_rejected(event_id: StringName, error_ids: PackedStringArray) -> void:
	_status.text = "Rejected: %s [%s]" % [event_id, ", ".join(error_ids)]


func _run_foundation_smoke() -> void:
	var runner := FoundationSmokeRunner.new()
	var result := runner.run()
	if bool(result.get("ok", false)):
		print("FOUNDATION_SMOKE: PASS")
		get_tree().quit(0)
	else:
		push_error("FOUNDATION_SMOKE: FAIL %s" % result.get("errors", []))
		get_tree().quit(1)
