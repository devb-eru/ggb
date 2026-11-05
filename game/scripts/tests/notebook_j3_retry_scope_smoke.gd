extends Node


func _ready() -> void:
	var test := preload("res://scripts/tests/notebook_j3_retry_scope_cases.gd").new()
	var result: Dictionary = await test.run(get_tree())
	print("NOTEBOOK_J3_RETRY_SCOPE_RESULT: ", JSON.stringify(result))
	get_tree().quit(0 if result.get("ok", false) else 1)
