extends SceneTree
## Run once after intentionally changing the shared generated-image theme.
func _initialize() -> void:
	var design = load("res://scripts/ui/design_theme.gd")
	DirAccess.make_dir_recursive_absolute("res://assets/ui/dialogue_editor")
	ResourceSaver.save(design.icon("icon_notebook", 60), "res://assets/ui/dialogue_editor/notebook_icon.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(design.icon("icon_menu", 38), "res://assets/ui/dialogue_editor/menu_icon.res", ResourceSaver.FLAG_COMPRESS)
	var theme := Theme.new()
	theme.default_font_size = 19
	for type in ["Label", "Button"]:
		for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			theme.set_color(key, type, design.IVORY)
	theme.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	for pair in [["DialogueNotebookButton", "button_dark"], ["DialogueChoiceButton", "choice_button"]]:
		var texture_path: String = "res://assets/ui/dialogue_editor/" + pair[1] + ".res"
		ResourceSaver.save(design.component(pair[1]), texture_path, ResourceSaver.FLAG_COMPRESS)
		var button := Button.new()
		design.button(button, false, pair[1])
		theme.set_type_variation(pair[0], "Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style: StyleBox = button.get_theme_stylebox(state)
			if style is StyleBoxTexture: style.texture = load(texture_path)
			theme.set_stylebox(state, pair[0], style)
		button.free()
	var result := ResourceSaver.save(theme, "res://assets/ui/dialogue_editor/dialogue_theme.tres")
	print("DIALOGUE_SCENE_THEME: ", result)
	quit(0 if result == OK else 1)
