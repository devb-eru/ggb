class_name StateWriter
extends RefCounted

const STATE_PATH_REGISTRY := "res://data/states/state_path_registry.json"
const TYPE_NAME_MAP := {
	"bool": TYPE_BOOL,
	"int": TYPE_INT,
	"float": TYPE_FLOAT,
	"string": TYPE_STRING,
	"array": TYPE_ARRAY,
	"dictionary": TYPE_DICTIONARY,
}
const ALLOWED_OPERATIONS := ["set", "increment", "add", "remove"]

var _game_state: Node
var _path_specs: Dictionary = {}
var _registry_error: StringName = &""
var _snapshot_validator := StateSnapshotValidator.new()


func _init(game_state: Node) -> void:
	_game_state = game_state
	_load_path_registry()


func commit_atomic(
	write_requests: Array,
	expected_revision: int,
	transaction_id: StringName
) -> Dictionary:
	if _registry_error != &"":
		return _failure(_registry_error)
	if expected_revision != _game_state.revision:
		return _failure(&"ERR_STATE_STALE_REVISION")
	if write_requests.is_empty():
		return _failure(&"ERR_STATE_EMPTY_TRANSACTION")

	var previous_snapshot: Dictionary = _game_state.get_snapshot()
	var staged_snapshot := previous_snapshot.duplicate(true)
	var changed_paths := PackedStringArray()

	for request_value in write_requests:
		if not request_value is Dictionary:
			return _failure(&"ERR_STATE_INVALID_WRITE")
		var request: Dictionary = request_value
		var state_path := String(request.get("state_path", ""))
		var operation := String(request.get("operation", "set"))
		var value: Variant = request.get("value")
		if not _path_specs.has(state_path):
			return _failure(&"ERR_STATE_PATH_NOT_REGISTERED")
		var spec: Dictionary = _path_specs[state_path]
		if String(spec.get("writer", "StateWriter")) != "StateWriter":
			return _failure(&"ERR_STATE_WRITER_NOT_ALLOWED")
		if operation not in ALLOWED_OPERATIONS:
			return _failure(&"ERR_STATE_OPERATION_NOT_ALLOWED")
		var operation_error := _apply_operation(staged_snapshot, state_path, operation, value, spec)
		if operation_error != &"":
			return _failure(operation_error)
		changed_paths.append(state_path)

	var validation := _snapshot_validator.validate(staged_snapshot)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"error_ids": validation.get("error_ids", PackedStringArray()),
		}

	var committed_revision: int = _game_state.commit_validated_snapshot(
		staged_snapshot,
		expected_revision,
		transaction_id,
		changed_paths
	)
	if committed_revision < 0:
		return _failure(&"ERR_STATE_STALE_REVISION")

	return {
		"ok": true,
		"revision": committed_revision,
		"changed_paths": changed_paths,
		"previous_snapshot": previous_snapshot,
	}


func install_snapshot(
	next_snapshot: Dictionary,
	expected_revision: int,
	transaction_id: StringName
) -> Dictionary:
	if expected_revision != _game_state.revision:
		return _failure(&"ERR_STATE_STALE_REVISION")
	var validation := _snapshot_validator.validate(next_snapshot)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"error_ids": validation.get("error_ids", PackedStringArray()),
		}
	var previous_snapshot: Dictionary = _game_state.get_snapshot()
	var changed_paths := PackedStringArray()
	for root_key in StateSnapshotValidator.ROOT_KEYS:
		if previous_snapshot.get(root_key) != next_snapshot.get(root_key):
			changed_paths.append(root_key)
	var committed_revision: int = _game_state.commit_validated_snapshot(
		next_snapshot,
		expected_revision,
		transaction_id,
		changed_paths
	)
	if committed_revision < 0:
		return _failure(&"ERR_STATE_STALE_REVISION")
	return {
		"ok": true,
		"revision": committed_revision,
		"changed_paths": changed_paths,
		"previous_snapshot": previous_snapshot,
	}


func _value_matches_spec(value: Variant, spec: Dictionary) -> bool:
	if typeof(value) != int(spec["type"]):
		return false
	if typeof(value) == TYPE_INT:
		return int(value) >= int(spec.get("min", value)) and int(value) <= int(spec.get("max", value))
	return true


func _load_path_registry() -> void:
	var file := FileAccess.open(STATE_PATH_REGISTRY, FileAccess.READ)
	if file == null:
		_registry_error = &"ERR_STATE_REGISTRY_MISSING"
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.has("paths") or not parsed["paths"] is Dictionary:
		_registry_error = &"ERR_STATE_REGISTRY_INVALID"
		return
	if int(parsed.get("schema_version", -1)) != 1:
		_registry_error = &"ERR_STATE_REGISTRY_SCHEMA"
		return

	for state_path in parsed["paths"].keys():
		var source_spec: Variant = parsed["paths"][state_path]
		if not source_spec is Dictionary:
			_registry_error = &"ERR_STATE_REGISTRY_INVALID"
			return
		var type_name := String(source_spec.get("type", ""))
		if not TYPE_NAME_MAP.has(type_name):
			_registry_error = &"ERR_STATE_REGISTRY_TYPE"
			return
		var runtime_spec := {"type": TYPE_NAME_MAP[type_name]}
		runtime_spec["writer"] = String(source_spec.get("writer", "StateWriter"))
		if source_spec.has("minimum"):
			runtime_spec["min"] = int(source_spec["minimum"])
		if source_spec.has("maximum"):
			runtime_spec["max"] = int(source_spec["maximum"])
		_path_specs[String(state_path)] = runtime_spec


func _apply_operation(
	snapshot: Dictionary,
	state_path: String,
	operation: String,
	value: Variant,
	spec: Dictionary
) -> StringName:
	if operation == "set":
		if not _value_matches_spec(value, spec):
			return &"ERR_STATE_TYPE_OR_RANGE"
		return &"" if _set_path(snapshot, state_path, value) else &"ERR_STATE_PARENT_MISSING"

	var current_result := _get_path(snapshot, state_path)
	if not bool(current_result.get("ok", false)):
		return &"ERR_STATE_PARENT_MISSING"
	var current: Variant = current_result.get("value")
	var next_value: Variant

	match operation:
		"increment":
			if typeof(current) not in [TYPE_INT, TYPE_FLOAT] or typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				return &"ERR_STATE_OPERATION_TYPE"
			next_value = current + value
		"add":
			if current is Array and typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
				next_value = current.duplicate(true)
				if String(value) not in next_value:
					next_value.append(String(value))
			elif current is Dictionary and value is Dictionary:
				next_value = current.duplicate(true)
				next_value.merge(value, true)
			else:
				return &"ERR_STATE_OPERATION_TYPE"
		"remove":
			if current is Array and typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
				next_value = current.duplicate(true)
				next_value.erase(String(value))
			elif current is Dictionary and typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
				next_value = current.duplicate(true)
				next_value.erase(String(value))
			else:
				return &"ERR_STATE_OPERATION_TYPE"
		_:
			return &"ERR_STATE_OPERATION_NOT_ALLOWED"

	if not _value_matches_spec(next_value, spec):
		return &"ERR_STATE_TYPE_OR_RANGE"
	return &"" if _set_path(snapshot, state_path, next_value) else &"ERR_STATE_PARENT_MISSING"


func _get_path(snapshot: Dictionary, state_path: String) -> Dictionary:
	var cursor: Variant = snapshot
	for segment in state_path.split("."):
		if not cursor is Dictionary or not cursor.has(segment):
			return {"ok": false}
		cursor = cursor[segment]
	return {"ok": true, "value": cursor}


func _set_path(snapshot: Dictionary, state_path: String, value: Variant) -> bool:
	var segments := state_path.split(".")
	var cursor := snapshot
	for index in range(segments.size() - 1):
		var segment := segments[index]
		if not cursor.has(segment) or not cursor[segment] is Dictionary:
			return false
		cursor = cursor[segment]
	cursor[segments[-1]] = value
	return true


func _failure(error_id: StringName) -> Dictionary:
	return {"ok": false, "error_ids": PackedStringArray([String(error_id)])}
