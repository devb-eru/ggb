extends RefCounted
## Shared image components. Text, focus and game state remain native controls.
const ROOT := "res://assets/ui/design_2026_10/"
const INK := Color("29252e")
const IVORY := Color("f5f0e5")
static var _assets: Dictionary = {}
static var _textures: Dictionary = {}
static var _icons: Dictionary = {}
static var _components: Dictionary = {}

static func component(id: String) -> Texture2D:
	if _components.has(id): return _components[id]
	var atlas: AtlasTexture = texture(id)
	var source := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	var logical: Array = _assets[id].logical_size
	source.resize(logical[0], logical[1], Image.INTERPOLATE_LANCZOS)
	_components[id] = ImageTexture.create_from_image(source)
	return _components[id]

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if _assets.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
		for asset: Dictionary in manifest.assets: _assets[asset.id] = asset
	var asset: Dictionary = _assets[id]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ROOT + String(asset.file).get_file())
	var bounds: Array = asset.get("runtime_bbox", asset.content_bbox)
	atlas.region = Rect2(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1])
	_textures[id] = atlas
	return atlas

static func box(id: String, tint: Color = Color.WHITE, inset: float = 20.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = component(id)
	style.modulate_color = tint
	var dim := style.texture.get_size()
	var edge := minf(dim.x, dim.y) * 0.17
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, edge)
		style.set_content_margin(side, inset)
	return style

static func focus(paper: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	# Keep keyboard focus behaviour without a rectangular overlay on the artwork.
	return style

static func button(control: Button, paper: bool = false, asset: String = "") -> void:
	var id := asset if not asset.is_empty() else ("button_paper" if paper else "button_dark")
	control.add_theme_stylebox_override("normal", box(id, Color.WHITE, 12))
	control.add_theme_stylebox_override("hover", box(id, Color(1.12, 1.08, 1.16), 12))
	control.add_theme_stylebox_override("pressed", box(id, Color(0.82, 0.77, 0.88), 12))
	control.add_theme_stylebox_override("hover_pressed", box(id, Color(0.9, 0.83, 0.95), 12))
	control.add_theme_stylebox_override("disabled", box(id, Color(0.7, 0.7, 0.7, 0.65), 12))
	control.add_theme_stylebox_override("focus", focus(paper))
	var color := INK if paper else IVORY
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		control.add_theme_color_override(key, color)
	control.add_theme_color_override("font_disabled_color", Color("817888"))
	control.custom_minimum_size.y = maxf(44, control.custom_minimum_size.y)
	control.add_theme_constant_override("outline_size", 0)

static func make_theme(paper: bool = false, font_size: int = 18) -> Theme:
	var result := Theme.new()
	result.default_font_size = font_size
	var color := INK if paper else IVORY
	for type in ["Label", "RichTextLabel", "Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit"]:
		for key in ["font_color", "default_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			result.set_color(key, type, color)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			result.set_stylebox(state, type, box("button_paper" if paper else "button_dark", Color.WHITE, 12))
		result.set_stylebox("focus", type, focus(paper))
	result.set_stylebox("panel", "PanelContainer", box("panel_paper" if paper else "panel_dark", Color.WHITE, 24))
	result.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	for state in ["normal", "focus", "read_only"]: result.set_stylebox(state, "LineEdit", box("search_field", Color.WHITE, 12))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", Color("62596b"))
	result.set_color("caret_color", "LineEdit", INK)
	for type in ["CheckBox", "CheckButton"]:
		result.set_icon("checked", type, icon("checkbox_checked", 28))
		result.set_icon("unchecked", type, icon("checkbox_empty", 28))
		result.set_stylebox("focus", type, focus(paper))
	for type in ["HSlider", "VSlider"]:
		result.set_stylebox("slider", type, box("slider_track", Color.WHITE, 2))
		result.set_icon("grabber", type, icon("slider_thumb", 30))
		result.set_icon("grabber_highlight", type, icon("slider_thumb", 34))
	for type in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", type, box("scroll_track", Color.WHITE, 3))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]: result.set_stylebox(state, type, box("scroll_thumb", Color.WHITE, 6))
	result.set_stylebox("panel", "TooltipPanel", box("tooltip", Color.WHITE, 16))
	result.set_color("font_color", "TooltipLabel", IVORY)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 12)
	return result

static func icon(id: String, width: int = 32) -> Texture2D:
	var key := id + str(width)
	if _icons.has(key): return _icons[key]
	var atlas: AtlasTexture = texture(id)
	var bitmap := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	bitmap.resize(width, width, Image.INTERPOLATE_LANCZOS)
	_icons[key] = ImageTexture.create_from_image(bitmap)
	return _icons[key]

static func skin_tree(node: Node, paper: bool = false) -> void:
	if node is Button: button(node, paper)
	if node is PanelContainer: node.add_theme_stylebox_override("panel", box("panel_paper" if paper else "panel_dark", Color.WHITE, 24))
	for child in node.get_children(): skin_tree(child, paper)
