extends Button

var key_clicked = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	
	$"../drawer".drawer_open_close.connect(key_visible)

func _on_button_down() -> void:
	key_clicked = 1
	#열쇠가 인벤으로 이동하는 코드

func key_visible(key_visible_index: int) -> void:
	if key_visible_index == 0 or key_clicked == 1:
		visible = true
	else:
		visible = false
