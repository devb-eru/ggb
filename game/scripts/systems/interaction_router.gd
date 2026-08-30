class_name InteractionRouter
extends Node

var _last_consumed_frame := -1


func request_interaction(target_id: StringName, event_id: StringName) -> bool:
	var current_frame := Engine.get_process_frames()
	if current_frame == _last_consumed_frame or EventManager.is_busy():
		return false

	_last_consumed_frame = current_frame
	return EventManager.request_event(event_id, target_id)
