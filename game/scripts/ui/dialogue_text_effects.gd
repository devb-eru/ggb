extends Node

const FONT_COLORS := [&"font_color", &"font_pressed_color", &"font_hover_color",
	&"font_focus_color", &"font_hover_pressed_color", &"font_disabled_color", &"font_outline_color"]

var _reveals: Dictionary = {}
var _suspended := false


func _ready() -> void:
	set_process(false)


func present(label: Label, content: String, effect: Dictionary = {}, motion_mode: String = "standard") -> void:
	_clear(label)
	label.text = content
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	var reveal := _plan(content, effect)
	reveal.label = label
	var emphasis := String(effect.get("emphasis", ""))
	if not emphasis.is_empty() and content.contains(emphasis):
		_add_emphasis(reveal, label, content, emphasis)
		reveal.animate_emphasis = motion_mode == "standard"
	_reveals[label] = reveal
	if content.is_empty() or effect.get("kind") == "instant" or motion_mode == "static":
		_complete(label, reveal)
		return
	_set_visible(reveal, 0)
	set_process(true)


func present_button(button: Button, motion_mode: String = "standard") -> void:
	_clear(button)
	if motion_mode == "static" or button.text.is_empty():
		return
	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.accessibility_name = ""
	caption.text = button.text
	caption.horizontal_alignment = button.alignment
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = button.autowrap_mode
	caption.text_direction = button.text_direction
	caption.language = button.language
	caption.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	caption.add_theme_font_override("font", button.get_theme_font("font"))
	caption.add_theme_font_size_override("font_size", button.get_theme_font_size("font_size"))
	caption.add_theme_constant_override("outline_size", button.get_theme_constant("outline_size"))
	caption.add_theme_color_override("font_outline_color", button.get_theme_color("font_outline_color"))
	button.add_child(caption, false, Node.INTERNAL_MODE_BACK)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := button.get_theme_stylebox("normal")
	caption.offset_left = style.get_margin(SIDE_LEFT)
	caption.offset_right = -style.get_margin(SIDE_RIGHT)
	caption.offset_top = style.get_margin(SIDE_TOP)
	caption.offset_bottom = -style.get_margin(SIDE_BOTTOM)
	var reveal := _plan(button.text, {})
	reveal.label = caption
	reveal.caption = caption
	reveal.colors = {}
	for name: StringName in FONT_COLORS:
		if button.has_theme_color_override(name):
			reveal.colors[name] = button.get_theme_color(name)
		button.add_theme_color_override(name, Color.TRANSPARENT)
	_reveals[button] = reveal
	_update_button_color(button, reveal)
	_set_visible(reveal, 0)
	set_process(true)


func finish() -> bool:
	var unfinished := false
	for target in _reveals.keys():
		if not is_instance_valid(target):
			_reveals.erase(target)
			continue
		var reveal: Dictionary = _reveals[target]
		if not reveal.finished:
			unfinished = unfinished or reveal.step < reveal.times.size()
			_complete(target, reveal)
	return unfinished


func reset() -> void:
	for target in _reveals.keys():
		_clear(target)
	set_process(false)


func set_suspended(value: bool) -> void:
	_suspended = value


func _plan(content: String, effect: Dictionary) -> Dictionary:
	var time := 0.0
	var previous := 0
	var characters := PackedInt32Array()
	var times := PackedFloat32Array()
	var graphemes := TextServerManager.get_primary_interface().string_get_character_breaks(content)
	var rate := clampf(float(effect.get("cps", 30.0)), 5.0, 120.0)
	var pauses: Dictionary = effect.get("pause_after", {})
	var words := 0
	var chunk_words := clampi(int(effect.get("chunk_words", 3)), 1, 12)
	var chunks: bool = effect.get("kind") == "chunks"
	var has_word := false
	for end in graphemes:
		var span := content.substr(previous, end - previous)
		previous = end
		time += 1.0 / rate
		var word_end := span.strip_edges().is_empty() and has_word
		if word_end:
			words += 1
			has_word = false
		elif not span.strip_edges().is_empty():
			has_word = true
		var delay := 0.0
		for suffix: String in pauses:
			if not suffix.is_empty() and end >= suffix.length() and content.substr(end - suffix.length(), suffix.length()) == suffix:
				delay = maxf(delay, clampf(float(pauses[suffix]), 0.0, 1.0))
		if not chunks or words >= chunk_words or delay > 0.0 or end == content.length():
			characters.append(end)
			times.append(time)
			words = 0
			has_word = false
		time += delay
	return {"characters": characters, "times": times, "step": 0, "elapsed": 0.0, "finished": false}


func _add_emphasis(reveal: Dictionary, label: Label, content: String, emphasis: String) -> void:
	var rich := RichTextLabel.new()
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.scroll_active = false
	rich.autowrap_mode = label.autowrap_mode
	rich.horizontal_alignment = label.horizontal_alignment
	rich.vertical_alignment = label.vertical_alignment
	rich.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	var font := label.get_theme_font("font")
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.55
	rich.add_theme_font_override("normal_font", font)
	rich.add_theme_font_override("bold_font", bold)
	for font_size in ["normal_font_size", "bold_font_size"]:
		rich.add_theme_font_size_override(font_size, label.get_theme_font_size("font_size"))
	rich.add_theme_constant_override("line_separation", label.get_theme_constant("line_spacing"))
	rich.add_theme_color_override("default_color", label.get_theme_color("font_color"))
	label.add_child(rich, false, Node.INTERNAL_MODE_BACK)
	rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reveal.rich = rich
	reveal.content = content
	reveal.emphasis = emphasis
	reveal.emphasis_start = content.find(emphasis)
	reveal.tint = label.self_modulate
	reveal.emphasis_color = label.get_theme_color("font_color")
	label.self_modulate.a = 0.0
	_style_emphasis(reveal, 0.0)


func _style_emphasis(reveal: Dictionary, brightness: float) -> void:
	var rich: RichTextLabel = reveal.rich
	var source: String = reveal.content
	var emphasis: String = reveal.emphasis
	var start: int = reveal.emphasis_start
	var color: Color = reveal.emphasis_color
	rich.clear()
	rich.add_text(source.left(start))
	rich.push_bold()
	rich.push_color(color.lerp(Color.WHITE, brightness))
	rich.add_text(emphasis)
	rich.pop()
	rich.pop()
	rich.add_text(source.substr(start + emphasis.length()))


func _update_button_color(button: Button, reveal: Dictionary) -> void:
	var name := &"font_color"
	match button.get_draw_mode():
		BaseButton.DRAW_PRESSED: name = &"font_pressed_color"
		BaseButton.DRAW_HOVER: name = &"font_hover_color"
		BaseButton.DRAW_HOVER_PRESSED: name = &"font_hover_pressed_color"
		BaseButton.DRAW_DISABLED: name = &"font_disabled_color"
		_:
			if button.has_focus(): name = &"font_focus_color"
	if reveal.get("font_state") == name and reveal.get("theme_type") == button.theme_type_variation:
		return
	reveal.font_state = name
	reveal.theme_type = button.theme_type_variation
	var color: Color = reveal.colors.get(name, Color.WHITE)
	if not reveal.colors.has(name):
		button.remove_theme_color_override(name)
		color = button.get_theme_color(name)
		button.add_theme_color_override(name, Color.TRANSPARENT)
	reveal.caption.add_theme_color_override("font_color", color)


func _set_visible(reveal: Dictionary, amount: int) -> void:
	reveal.label.visible_characters = amount
	if reveal.has("rich"):
		reveal.rich.visible_characters = amount


func _complete(target: Control, reveal: Dictionary) -> void:
	reveal.finished = true
	_set_visible(reveal, -1)
	if reveal.has("rich"):
		_style_emphasis(reveal, 0.0)
	elif reveal.has("caption"):
		_clear(target)
	else:
		_reveals.erase(target)


func _clear(target: Variant) -> void:
	var reveal: Dictionary = _reveals.get(target, {})
	_reveals.erase(target)
	if reveal.is_empty() or not is_instance_valid(target):
		return
	if reveal.has("rich"):
		reveal.rich.hide()
		reveal.rich.queue_free()
		target.self_modulate = reveal.tint
	if reveal.has("caption"):
		reveal.caption.hide()
		reveal.caption.queue_free()
		for name: StringName in FONT_COLORS:
			if reveal.colors.has(name):
				target.add_theme_color_override(name, reveal.colors[name])
			else:
				target.remove_theme_color_override(name)
	elif target is Label:
		target.visible_characters = -1


func _process(delta: float) -> void:
	if _suspended:
		return
	var running := false
	for target in _reveals.keys():
		if not is_instance_valid(target):
			_reveals.erase(target)
			continue
		var reveal: Dictionary = _reveals[target]
		if reveal.finished: continue
		reveal.elapsed += delta
		while reveal.step < reveal.times.size() and reveal.elapsed >= reveal.times[reveal.step]:
			var amount: int = reveal.characters[reveal.step]
			reveal.step += 1
			if reveal.get("animate_emphasis", false) and amount > reveal.emphasis_start and not reveal.has("emphasis_time"):
				reveal.emphasis_time = reveal.elapsed
			_set_visible(reveal, amount)
		if reveal.has("caption"):
			_update_button_color(target, reveal)
		var pulse := 0.0
		if reveal.has("emphasis_time"):
			pulse = maxf(0.0, 1.0 - (reveal.elapsed - reveal.emphasis_time) / 0.18)
			if pulse > 0.0 or reveal.get("pulsing", false):
				_style_emphasis(reveal, pulse * 0.8)
				_set_visible(reveal, reveal.characters[reveal.step - 1])
			reveal.pulsing = pulse > 0.0
		if reveal.step >= reveal.times.size() and pulse <= 0.0:
			_complete(target, reveal)
		else:
			running = true
	set_process(running)
