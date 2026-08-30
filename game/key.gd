class_name PracticeKey
extends Button

const KEY_ITEM_ID: StringName = &"practice_key"
const TARGET_BACKGROUND_INDEX := 0

var is_acquired := false
var is_drawer_open := false
var current_background_index := -1

signal key_acquired(item_id: StringName)

func _ready() -> void:
	disabled = false
	_refresh_visibility()


func acquire(inventory: PracticeInventory) -> bool:
	if is_acquired:
		return false

	if not inventory.add_item(KEY_ITEM_ID):
		return false

	is_acquired = true
	disabled = true
	visible = false
	key_acquired.emit(KEY_ITEM_ID)
	return true


func apply_snapshot(background_index: int, drawer_opened: bool) -> void:
	current_background_index = background_index
	is_drawer_open = drawer_opened
	_refresh_visibility()


func set_drawer_open(opened: bool) -> void:
	is_drawer_open = opened
	_refresh_visibility()


func set_background(background_index: int) -> void:
	current_background_index = background_index
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = (
		not is_acquired
		and is_drawer_open
		and current_background_index == TARGET_BACKGROUND_INDEX
	)
	focus_mode = Control.FOCUS_ALL if visible else Control.FOCUS_NONE
