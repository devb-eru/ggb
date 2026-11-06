@tool
extends PanelContainer

@export_range(0, 2) var preview_selected_index := 0:
	set(value):
		preview_selected_index = value
		if Engine.is_editor_hint() and is_node_ready(): set_selected_index(value)

var _button_scene: PackedScene

func _ready() -> void:
	set_selected_index(preview_selected_index)
	if Engine.is_editor_hint(): return
	_button_scene = PackedScene.new()
	_button_scene.pack(get_node("Margin/Choices/DialogueChoice1"))
	for button in choice_buttons(): _connect_choice(button)

func choice_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in get_node("Margin/Choices").get_children():
		if child is Button and (child.get_meta("authored_choice", false) or String(child.name).begins_with("DialogueChoice")): result.append(child)
	return result

func create_choice_button(connect_selection: bool = true) -> Button:
	var button := _button_scene.instantiate() as Button
	button.set_meta("authored_choice", true)
	button.theme_type_variation = &"DialogueChoiceButton"
	if connect_selection: _connect_choice(button)
	return button

func _connect_choice(button: Button) -> void:
	button.focus_entered.connect(_select_button.bind(button))
	button.mouse_entered.connect(_hover_button.bind(button))

func _select_button(button: Button) -> void:
	set_selected_index(choice_buttons().find(button))

func _hover_button(button: Button) -> void:
	if button.disabled or not button.is_visible_in_tree(): return
	_select_button(button)
	button.grab_focus()

func set_selected_index(index: int) -> void:
	var buttons := choice_buttons()
	for item in range(buttons.size()):
		var button := buttons[item]
		button.theme_type_variation = &"DialogueChoiceSelectedButton" if item == index else &"DialogueChoiceButton"

func _select_with_mouse(index: int) -> void:
	var buttons := choice_buttons()
	if index in range(buttons.size()): _hover_button(buttons[index])
