extends Sprite2D

var background_list = [ 
	preload("res://background1.png"), 
	preload("res://background2.png"), 
	preload("res://background3.png") 
	]
	
var background_index: int = 1

signal background_number(number: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"../next_button".next_page_signal.connect(next_page)
	$"../previous_button".previous_page_signal.connect(previous_page)
	
	texture = background_list[background_index]

func next_page() -> void:
	if background_index < 2:
		print("next page")
		background_index += 1
		texture = background_list[background_index]
	else:
		print("last page")
	
	background_number.emit(background_index)
	
func previous_page() -> void:
	if background_index > 0:
		print("previous page")
		background_index -= 1
		texture = background_list[background_index]
	else:
		print("first page")
	
	background_number.emit(background_index)
