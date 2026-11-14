extends SceneTree
## One-time export of the existing image theme for native scene editing.
const DESIGN := preload("res://scripts/ui/design_theme.gd")
const ROOT := "res://assets/ui/notebook/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "themes")
	DirAccess.make_dir_recursive_absolute(ROOT + "textures")
	for id in ["button_paper", "search_field", "slider_track", "scroll_track", "scroll_thumb", "tooltip", "tab_idle", "tab_selected", "list_row"]:
		var path: String = ROOT + "textures/" + id + ".res"
		_save(DESIGN.component(id), path, ResourceSaver.FLAG_COMPRESS)
		DESIGN._components[id] = load(path)
	for id in ["notebook_open", "panel_paper"]:
		_save(DESIGN.texture(id), ROOT + "textures/" + id + ".tres")
	var theme := DESIGN.make_theme(true)
	for spec in [["Button", "button_paper", true], ["NotebookBookmark", "tab_idle", false], ["NotebookRow", "list_row", false]]:
		if spec[0] != "Button": theme.set_type_variation(spec[0], "Button")
		var button := Button.new()
		DESIGN.button(button, spec[2], spec[1])
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			theme.set_stylebox(state, spec[0], button.get_theme_stylebox(state))
		for color in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
			theme.set_color(color, spec[0], button.get_theme_color(color))
		theme.set_constant("outline_size", spec[0], 0)
		button.free()
	for state in ["pressed", "hover_pressed"]:
		theme.set_stylebox(state, "NotebookBookmark", DESIGN.box("tab_selected", Color.WHITE, 12))
	# The root draws its native artwork below the controls.
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	# Native resources replace transient ImageTextures inside the Theme as well.
	for type in theme.get_icon_type_list():
		for item in theme.get_icon_list(type):
			var path: String = ROOT + "textures/native_icon_" + type.to_lower() + "_" + item + ".res"
			_save(theme.get_icon(item, type), path, ResourceSaver.FLAG_COMPRESS)
			theme.set_icon(item, type, load(path))
	_save(theme, ROOT + "themes/notebook.tres")
	for id in ["icon_close", "icon_pin", "icon_compare", "icon_refresh", "icon_filter", "icon_back", "icon_swap"]:
		_save(DESIGN.icon(id, 24), ROOT + "textures/" + id + ".res", ResourceSaver.FLAG_COMPRESS)
	print("NOTEBOOK_SCENE_RESOURCES: PASS")
	quit()

func _save(resource: Resource, path: String, flags: int = 0) -> void:
	var result := ResourceSaver.save(resource, path, flags)
	if result != OK:
		push_error("Failed to export %s (%s)" % [path, result])
		quit(1)
