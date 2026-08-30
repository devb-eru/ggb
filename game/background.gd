class_name PracticeBackground
extends Sprite2D

var background_list: Array[Texture2D] = [
	preload("res://background1.png"), 
	preload("res://background2.png"), 
	preload("res://background3.png") 
	]
	
var background_index: int = 1

signal background_number(number: int)

func _ready() -> void:
	texture = background_list[background_index]
	background_number.emit(background_index)

func next_page() -> void:
	if background_index < background_list.size() - 1:
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
