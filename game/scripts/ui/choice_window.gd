@tool
extends PanelContainer

@export_range(0, 2) var preview_selected_index := 0:
	set(value):
		preview_selected_index = value
		if Engine.is_editor_hint() and is_node_ready(): set_selected_index(value)

func _ready() -> void:
	set_selected_index(preview_selected_index)
	if Engine.is_editor_hint(): return
	for index in range(3):
		var button: Button = get_node("Margin/Choices/DialogueChoice%d" % (index + 1))
		button.focus_entered.connect(set_selected_index.bind(index))
		button.mouse_entered.connect(_select_with_mouse.bind(index))

func set_selected_index(index: int) -> void:
	for item in range(3):
		var button: Button = get_node("Margin/Choices/DialogueChoice%d" % (item + 1))
		button.theme_type_variation = &"DialogueChoiceSelectedButton" if item == index else &"DialogueChoiceButton"

func _select_with_mouse(index: int) -> void:
	var button: Button = get_node("Margin/Choices/DialogueChoice%d" % (index + 1))
	if button.disabled or not button.is_visible_in_tree(): return
	set_selected_index(index)
	button.grab_focus()
