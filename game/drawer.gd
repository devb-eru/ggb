class_name PracticeDrawer
extends Button

const TARGET_BACKGROUND_INDEX := 0
const OPEN_INDEX := 0
const CLOSED_INDEX := 1

var drawer_list: Array[Texture2D] = [
	preload("res://drawer_open.png"),
	preload("res://drawer_close.png")
]

var drawer_index := CLOSED_INDEX
signal drawer_state_changed(is_open: bool)

func _ready() -> void:
	icon = drawer_list[drawer_index]
	visible = false


func apply_background(background_number: int) -> void:
	visible = background_number == TARGET_BACKGROUND_INDEX
	focus_mode = Control.FOCUS_ALL if visible else Control.FOCUS_NONE


func toggle() -> void:
	print("drawer")
	drawer_index = OPEN_INDEX if drawer_index == CLOSED_INDEX else CLOSED_INDEX
	icon = drawer_list[drawer_index]
	drawer_state_changed.emit(drawer_index == OPEN_INDEX)


func is_open() -> bool:
	return drawer_index == OPEN_INDEX
