extends SceneTree
## Both states share the same crop, slices and text inset to prevent label movement.
func _initialize() -> void:
	var folder := "res://assets/ui/dialogue_editor/"
	var source := "res://assets/ui/design_2026_10/"
	var theme := Theme.new()
	for state in ["idle", "selected"]:
		var file := "choice_button__r01.png" if state == "selected" else "choice_button_no_diamond__r01.png"
		var texture: Texture2D = load(source + file)
		var pixels := texture.get_image().get_region(Rect2i(65, 226, 2042, 263))
		pixels.resize(700, 96, Image.INTERPOLATE_LANCZOS)
		var path: String = folder + "choice_" + state + ".res"
		ResourceSaver.save(ImageTexture.create_from_image(pixels), path, ResourceSaver.FLAG_COMPRESS)
		var type := "DialogueChoiceSelectedButton" if state == "selected" else "DialogueChoiceButton"
		theme.set_type_variation(type, "Button")
		for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			theme.set_color(key, type, Color("f5f0e5"))
		for key in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style := StyleBoxTexture.new()
			style.texture = load(path)
			style.texture_margin_left = 112
			style.texture_margin_right = 32
			style.texture_margin_top = 16
			style.texture_margin_bottom = 16
			style.content_margin_left = 104
			style.content_margin_right = 32
			style.content_margin_top = 12
			style.content_margin_bottom = 12
			if key == "hover": style.modulate_color = Color(1.12, 1.08, 1.16)
			if key in ["pressed", "hover_pressed"]: style.modulate_color = Color(0.86, 0.81, 0.92)
			if key == "disabled": style.modulate_color = Color(0.7, 0.7, 0.7, 0.65)
			theme.set_stylebox(key, type, style)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	var result := ResourceSaver.save(theme, folder + "choice_window_theme.tres")
	print("CHOICE_WINDOW_THEME: ", result)
	quit(0 if result == OK else 1)
