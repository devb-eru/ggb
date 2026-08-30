class_name InputRouter
extends Node

signal confirm_requested
signal focus_move_requested(direction: int)
signal toggle_requested(action_id: StringName)

const FOCUS_RECOVERY_DELAY_MSEC := 150

var _window_has_focus := true
var _accept_input_after_msec := 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_has_focus = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_has_focus = true
		_accept_input_after_msec = Time.get_ticks_msec() + FOCUS_RECOVERY_DELAY_MSEC


func _unhandled_input(event: InputEvent) -> void:
	if not _can_consume_input() or event.is_echo():
		return

	if event.is_action_pressed("focus_next"):
		focus_move_requested.emit(1)
	elif event.is_action_pressed("focus_previous"):
		focus_move_requested.emit(-1)
	elif event.is_action_pressed("notebook_toggle"):
		toggle_requested.emit(&"notebook_toggle")
	elif event.is_action_pressed("inventory_toggle"):
		toggle_requested.emit(&"inventory_toggle")
	elif event.is_action_pressed("ui_cancel"):
		toggle_requested.emit(&"ui_cancel")
	elif event.is_action_pressed("interact_confirm"):
		if event is InputEventKey:
			confirm_requested.emit()
		else:
			# Pointer confirmation is owned by the clicked interaction target.
			return
	else:
		return

	get_viewport().set_input_as_handled()


func _can_consume_input() -> bool:
	return _window_has_focus and Time.get_ticks_msec() >= _accept_input_after_msec
