class_name PracticeLock
extends Sprite2D

const TARGET_BACKGROUND_INDEX := 0


func _ready() -> void:
	visible = false


func apply_background(background_index: int) -> void:
	visible = background_index == TARGET_BACKGROUND_INDEX
