class_name StateWriter
extends RefCounted

const STATE_PATH_REGISTRY := "res://data/states/state_path_registry.json"
const TYPE_NAME_MAP := {
	"bool": TYPE_BOOL,
	"int": TYPE_INT,
	"float": TYPE_FLOAT,
	"string": TYPE_STRING,
	"dictionary": TYPE_DICTIONARY,
}

var _game_state: Node
var _path_specs: Dictionary = {}
var _registry_error: StringName = &""


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
		if operation != "set":
			return _failure(&"ERR_STATE_OPERATION_NOT_ALLOWED")
		if not _value_matches_spec(value, _path_specs[state_path]):
			return _failure(&"ERR_STATE_TYPE_OR_RANGE")
		if not _set_path(staged_snapshot, state_path, value):
			return _failure(&"ERR_STATE_PARENT_MISSING")
		changed_paths.append(state_path)

	var invariant_error := _validate_invariants(staged_snapshot)
	if invariant_error != &"":
		return _failure(invariant_error)

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
		if source_spec.has("minimum"):
			runtime_spec["min"] = int(source_spec["minimum"])
		if source_spec.has("maximum"):
			runtime_spec["max"] = int(source_spec["maximum"])
		_path_specs[String(state_path)] = runtime_spec


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


func _validate_invariants(snapshot: Dictionary) -> StringName:
	var fracture: Dictionary = snapshot["fracture_state"]
	var is_broken := bool(fracture["broken_reset_triggered"])
	var filter_is_broken := String(fracture["camouflage_filter"]) == "broken"
	if is_broken != filter_is_broken:
		return &"ERR_STATE_FRACTURE_FILTER_INVARIANT"

	var ending: Dictionary = snapshot["ending_run"]
	var final_decision := String(ending["final_decision"])
	var selected_ending := String(ending["selected_ending"])
	if final_decision == "unset" and not selected_ending.is_empty():
		return &"ERR_STATE_ENDING_INVARIANT"
	if final_decision in ["reality", "remain"] and selected_ending != final_decision:
		return &"ERR_STATE_ENDING_INVARIANT"
	return &""


func _failure(error_id: StringName) -> Dictionary:
	return {"ok": false, "error_ids": PackedStringArray([String(error_id)])}
