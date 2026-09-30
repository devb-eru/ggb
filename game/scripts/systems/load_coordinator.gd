class_name LoadCoordinator
extends RefCounted

signal load_installed(slot_id: StringName, resume_event_id: StringName, resume_node_id: StringName)
signal load_rejected(slot_id: StringName, error_ids: PackedStringArray)

const SAVE_POINT_REGISTRY := "res://data/registries/save_point_registry.json"
const RESET_RESUME_NODES := {
	"sleep_confirmed": "SYS_COMMIT",
	"player_committed": "SYS_MEMORY",
	"memory_committed": "NORMAL_RESET",
	"physical_reset_complete": "MORNING_LOAD",
	"morning_loaded": "ROUTE_SELECT",
	"route_selected": "ROUTE_RESUME",
	"complete": "RESET_FINALIZE",
}

var _game_state: Node
var _save_manager: Node
var _writer: StateWriter
var _snapshot_validator := StateSnapshotValidator.new()
var _registry: Dictionary = {}
var _registry_error: StringName = &""


func _init(game_state: Node, save_manager: Node) -> void:
	_game_state = game_state
	_save_manager = save_manager
	_writer = StateWriter.new(game_state)
	_load_registry()


func load_and_install(slot_id: String) -> Dictionary:
	if _registry_error != &"":
		return _reject(slot_id, PackedStringArray([String(_registry_error)]))
	var loaded: Dictionary = _save_manager.load_slot(slot_id)
	if not bool(loaded.get("ok", false)):
		return _reject(slot_id, loaded.get("error_ids", PackedStringArray()))

	var header_validation := validate_header(loaded.get("header", {}))
	if not bool(header_validation.get("ok", false)):
		return _reject(slot_id, header_validation.get("error_ids", PackedStringArray()))

	var normalized_snapshot := _snapshot_validator.normalize(loaded.get("snapshot", {}))
	var install_result := _writer.install_snapshot(
		normalized_snapshot,
		_game_state.revision,
		StringName("LOAD_%s_R%06d" % [slot_id, _game_state.revision + 1])
	)
	if not bool(install_result.get("ok", false)):
		return _reject(slot_id, install_result.get("error_ids", PackedStringArray()))

	var resume := _resolve_resume(loaded["header"], normalized_snapshot)
	var result := {
		"ok": true,
		"source": loaded.get("source", "main"),
		"recovered": String(loaded.get("source", "main")) == "backup",
		"revision": install_result.get("revision", _game_state.revision),
		"resume_event_id": resume["resume_event_id"],
		"resume_node_id": resume["resume_node_id"],
		"save_point_id": String(loaded["header"].get("save_point_id", "")),
	}
	load_installed.emit(
		StringName(slot_id),
		StringName(result["resume_event_id"]),
		StringName(result["resume_node_id"])
	)
	return result


func validate_header(header_value: Variant) -> Dictionary:
	var errors := PackedStringArray()
	if not header_value is Dictionary:
		return {"ok": false, "error_ids": PackedStringArray(["ERR_LOAD_HEADER_TYPE"])}
	var header: Dictionary = header_value
	for field in ["build_flavor", "content_boundary_id", "source_app_id", "save_point_id"]:
		if String(header.get(field, "")).is_empty():
			errors.append("ERR_LOAD_HEADER_FIELD")
	if String(header.get("build_flavor", "")) != String(_save_manager.get_build_flavor()):
		errors.append("ERR_LOAD_BUILD_FLAVOR")
	if String(header.get("source_app_id", "")) not in _registry.get("source_app_ids", []):
		errors.append("ERR_LOAD_SOURCE_APP")
	var save_point_id := String(header.get("save_point_id", ""))
	if save_point_id != String(header.get("content_boundary_id", "")):
		errors.append("ERR_LOAD_BOUNDARY_MISMATCH")
	var save_points: Dictionary = _registry.get("save_points", {})
	if not save_points.has(save_point_id):
		errors.append("ERR_LOAD_SAVE_POINT_UNREGISTERED")
	else:
		var definition: Dictionary = save_points[save_point_id]
		if String(header.get("build_flavor", "")) not in definition.get("build_flavors", []):
			errors.append("ERR_LOAD_SAVE_POINT_FLAVOR")
		if bool(definition.get("debug_only", false)) and not OS.is_debug_build():
			errors.append("ERR_LOAD_DEBUG_SAVE_POINT")
	return {"ok": errors.is_empty(), "error_ids": errors}


func _resolve_resume(header: Dictionary, snapshot: Dictionary) -> Dictionary:
	var reset: Dictionary = snapshot.get("reset_state", {})
	var phase := String(reset.get("phase", "idle"))
	if phase != "idle":
		return {
			"resume_event_id": "SYS_RESET",
			"resume_node_id": RESET_RESUME_NODES.get(phase, "RESET_RECOVERY"),
		}
	var save_point: Dictionary = _registry["save_points"][String(header["save_point_id"])]
	return {
		"resume_event_id": String(save_point["resume_event_id"]),
		"resume_node_id": String(save_point["resume_node_id"]),
	}


func _load_registry() -> void:
	var file := FileAccess.open(SAVE_POINT_REGISTRY, FileAccess.READ)
	if file == null:
		_registry_error = &"ERR_LOAD_REGISTRY_MISSING"
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_registry_error = &"ERR_LOAD_REGISTRY_INVALID"
		return
	_registry = parsed
	if int(_registry.get("schema_version", -1)) != 1:
		_registry_error = &"ERR_LOAD_REGISTRY_SCHEMA"
		return
	if not _registry.get("save_points") is Dictionary or _registry["save_points"].is_empty():
		_registry_error = &"ERR_LOAD_REGISTRY_INVALID"
		return
	for save_point_id in _registry["save_points"].keys():
		var definition: Variant = _registry["save_points"][save_point_id]
		if not definition is Dictionary:
			_registry_error = &"ERR_LOAD_REGISTRY_INVALID"
			return
		if String(definition.get("resume_event_id", "")).is_empty() or String(definition.get("resume_node_id", "")).is_empty():
			_registry_error = &"ERR_LOAD_REGISTRY_RESUME_MISSING"
			return


func _reject(slot_id: String, errors: PackedStringArray) -> Dictionary:
	load_rejected.emit(StringName(slot_id), errors)
	return {"ok": false, "error_ids": errors}
