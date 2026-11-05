extends Node


func _ready() -> void:
	var test := preload("res://scripts/tests/inventory_drag_feedback_cases.gd").new()
	var result: Dictionary = await test.run(get_tree())
	print("INVENTORY_DRAG_FEEDBACK_RESULT: ", JSON.stringify(result))
	get_tree().quit(0 if result.get("ok", false) else 1)
