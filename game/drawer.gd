extends Button

var drawer_list = [
	preload("res://drawer_open.png"),
	preload("res://drawer_close.png")
]

var drawer_visible_index: int = 0
var drawer_index: int = 1
signal drawer_open_close(open_close_index: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	icon = drawer_list[drawer_index]
	visible = false
	
	$"../background".background_number.connect(drawer_visible)

func drawer_visible(background_number: int) -> void:
	if background_number == 0:
		visible = true
	else:
		visible = false

func _on_button_down() -> void:
	print("drawer")
	if drawer_index == 1:
		drawer_index = 0
		icon = drawer_list[drawer_index]
		drawer_open_close.emit(drawer_index)
	else: 
		drawer_index = 1
		icon = drawer_list[drawer_index]
		drawer_open_close.emit(drawer_index)
