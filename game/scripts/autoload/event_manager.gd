extends Node

signal event_started(event_id: StringName, node_id: StringName)
signal event_completed(event_id: StringName, result_id: StringName)
signal event_rejected(event_id: StringName, error_ids: PackedStringArray)

const EVENT_REGISTRY := {
	&"FOUNDATION_SMOKE": preload("res://data/events/system/event_foundation_smoke.tres"),
}

var _writer: StateWriter
var _current_event_id: StringName = &""


func _ready() -> void:
	_writer = StateWriter.new(GameState)


func is_busy() -> bool:
	return _current_event_id != &""


func request_event(
	event_id: StringName,
	source_id: StringName = &"",
	runtime_context: Dictionary = {}
) -> bool:
	if is_busy():
		_reject(event_id, &"ERR_EVENT_BUSY")
		return false
	if not EVENT_REGISTRY.has(event_id):
		_reject(event_id, &"ERR_EVENT_NOT_REGISTERED")
		return false

	var definition: EventDefinition = EVENT_REGISTRY[event_id]
	var node := definition.find_node(definition.entry_node_id)
	if node == null:
		_reject(event_id, &"ERR_EVENT_ENTRY_NODE_MISSING")
		return false
	if GameState.get_value("meta_progress.event_history.%s" % event_id, {}).get("lifecycle", "") == "completed":
		_reject(event_id, &"ERR_EVENT_ALREADY_COMPLETED")
		return false

	_current_event_id = event_id
	event_started.emit(event_id, node.node_id)

	var write_requests: Array = []
	for state_write in node.writes:
		write_requests.append(state_write.to_request())
	write_requests.append({
		"state_path": "meta_progress.event_history.%s" % event_id,
		"operation": "set",
		"value": {
			"lifecycle": "completed",
			"result_id": String(node.result_id),
			"source_id": String(source_id),
		},
	})

	var transaction_id := StringName("EVT_%s_R%06d" % [event_id, GameState.revision + 1])
	var commit_result := _writer.commit_atomic(write_requests, GameState.revision, transaction_id)
	if not bool(commit_result.get("ok", false)):
		_current_event_id = &""
		event_rejected.emit(event_id, commit_result.get("error_ids", PackedStringArray()))
		return false

	var slot_id := String(runtime_context.get("slot_id", "slot_01"))
	var save_result := SaveManager.save_snapshot(
		slot_id,
		String(definition.save_point_id),
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
		_current_event_id = &""
		event_rejected.emit(event_id, save_result.get("error_ids", PackedStringArray()))
		return false

	_current_event_id = &""
	event_completed.emit(event_id, node.result_id)
	return true


func _reject(event_id: StringName, error_id: StringName) -> void:
	event_rejected.emit(event_id, PackedStringArray([String(error_id)]))
