extends Node

const EXPECTED_ENGINE_MAJOR := 4
const EXPECTED_ENGINE_MINOR := 7


func _ready() -> void:
	var version := Engine.get_version_info()
	var major := int(version.get("major", 0))
	var minor := int(version.get("minor", 0))

	if major != EXPECTED_ENGINE_MAJOR or minor != EXPECTED_ENGINE_MINOR:
		push_warning(
			"GGB expects Godot %d.%d.x, but the current runtime is %d.%d.x."
			% [EXPECTED_ENGINE_MAJOR, EXPECTED_ENGINE_MINOR, major, minor]
		)

	print("GGB production bootstrap initialized.")
