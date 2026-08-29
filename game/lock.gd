extends Sprite2D

const TARGET_BACKGROUND_INDEX := 0


func _ready() -> void:
	visible = false
	$"../background".background_number.connect(_on_background_changed)


func _on_background_changed(background_index: int) -> void:
	visible = background_index == TARGET_BACKGROUND_INDEX
