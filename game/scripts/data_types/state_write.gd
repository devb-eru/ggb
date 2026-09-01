class_name StateWrite
extends Resource

@export var state_path: StringName = &""
@export_enum("set", "increment", "add", "remove") var operation: String = "set"
@export var value: TypedStateValue


func to_request() -> Dictionary:
	return {
		"state_path": String(state_path),
		"operation": operation,
		"value": null if value == null else value.get_value(),
	}
