class_name TypedStateValue
extends Resource

@export_enum("null", "bool", "int", "float", "string", "string_name")
var value_type: String = "null"
@export var bool_value := false
@export var int_value := 0
@export var float_value := 0.0
@export var string_value := ""
@export var string_name_value: StringName = &""


func get_value() -> Variant:
	match value_type:
		"bool":
			return bool_value
		"int":
			return int_value
		"float":
			return float_value
		"string":
			return string_value
		"string_name":
			return string_name_value
		_:
			return null
