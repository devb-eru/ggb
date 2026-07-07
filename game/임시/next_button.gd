extends Button

signal next_page_signal()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_button_down() -> void:
	next_page_signal.emit()
