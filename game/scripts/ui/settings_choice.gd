@tool
extends HFlowContainer
## Buttons and their geometry are authored in the scene.
signal item_selected(index: int)
@export var selected := 0:
	set(value):
		selected = value
		_sync()
var disabled := false:
	set(value):
		disabled = value
		_sync()
var item_count: int:
	get: return get_child_count()
var button_pressed: bool:
	get: return selected == 0
	set(value): select(0 if value else 1)

func _ready() -> void:
	for index in get_child_count():
		get_child(index).pressed.connect(_pressed.bind(index))
	_sync()

func select(index: int) -> void:
	selected = index

func _pressed(index: int) -> void:
	select(index)
	item_selected.emit(index)

func _sync() -> void:
	for index in get_child_count():
		var button := get_child(index) as Button
		if button != null:
			button.set_pressed_no_signal(index == selected)
			button.disabled = disabled
