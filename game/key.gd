extends Button

const KEY_ITEM_ID: StringName = &"practice_key"
const TARGET_BACKGROUND_INDEX := 0

var is_acquired := false
var is_drawer_open := false
var current_background_index := 1

signal key_acquired(item_id: StringName)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"../drawer".drawer_state_changed.connect(_on_drawer_state_changed)
	$"../background".background_number.connect(_on_background_changed)
	_refresh_visibility()

func _on_pressed() -> void:
	if is_acquired:
		return

	if not $"../inventory".add_item(KEY_ITEM_ID):
		return

	is_acquired = true
	disabled = true
	visible = false
	key_acquired.emit(KEY_ITEM_ID)

func _on_drawer_state_changed(opened: bool) -> void:
	is_drawer_open = opened
	_refresh_visibility()


func _on_background_changed(background_index: int) -> void:
	current_background_index = background_index
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = (
		not is_acquired
		and is_drawer_open
		and current_background_index == TARGET_BACKGROUND_INDEX
	)
	focus_mode = Control.FOCUS_ALL if visible else Control.FOCUS_NONE
