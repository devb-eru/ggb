extends Node

var errors: Array[String] = []
var panel: PanelContainer
var buttons: Array[Button] = []
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/choice-background-fix/")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var window := get_tree().root
	window.content_scale_size = Vector2i(1280, 720)
	window.size = Vector2i(1280, 720)
	panel = preload("res://scenes/ui/choice_window.tscn").instantiate()
	window.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(40, 60)
	panel.size = Vector2(700, 365)
	for index in range(3): buttons.append(panel.get_node("Margin/Choices/DialogueChoice%d" % (index + 1)))
	await _frames()
	_check_frame_and_sources()
	_check_selection(0)
	await _shot("01-selected-first")
	buttons[0].grab_focus()
	await _key(KEY_DOWN)
	_check_selection(1)
	await _shot("02-keyboard-second")
	var motion := InputEventMouseMotion.new()
	motion.position = buttons[2].get_global_rect().get_center()
	window.push_input(motion, true)
	await _frames()
	_check_selection(2)
	_expect(buttons[2].has_focus(), "mouse selection follows keyboard focus")
	await _shot("03-mouse-third")
	for button in buttons: button.add_theme_font_size_override("font_size", 46)
	panel.size.x = 470
	await _frames()
	_check_selection(2)
	for button in buttons:
		_expect(button.get_global_rect().end.x <= panel.get_global_rect().end.x, "large text wraps inside the choice window")
	await _shot("04-large-text")
	panel.queue_free()
	await _frames()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(stage)
	var game = preload("res://scripts/prologue/prologue_controller.gd").new()
	game._test_mode = true
	stage.add_child(game)
	game._show_dialogue_choice_set("p4_father", "차가 식기 전에 묻는다", "주인공", "", "PROTAGONIST", game.P4_FATHER_CHOICE_ORDER, game._localized_p4_choices())
	panel = game._dialogue_choice_panel
	buttons = game._dialogue_choice_buttons
	await _frames()
	_check_frame_and_sources()
	_check_selection(0)
	await _key(KEY_DOWN)
	_check_selection(1)
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(output + "05-gameplay-second.png")
	_expect(game._dialogue_choice_active, "focus navigation does not commit a choice")
	var report := {"ok": errors.is_empty(), "errors": errors}
	var file := FileAccess.open(output + "audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CHOICE_BACKGROUND_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _check_selection(index: int) -> void:
	for item in range(3):
		var button := buttons[item]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style: StyleBoxTexture = button.get_theme_stylebox(state)
			var path := style.texture.resource_path
			_expect(path.ends_with("choice_selected.res" if item == index else "choice_idle.res"), "only current choice uses diamond: " + str(item) + " " + state)
			# The source diamond lies wholly within the fixed 112px left slice.
			_expect(style.content_margin_left == 104 and style.texture_margin_left == 112, "text inset stays clear of diamond and stable across states")

func _check_frame_and_sources() -> void:
	_expect(panel.get_node_or_null("Margin/Choices/DialogueChoiceHeader") == null, "header removed from scene")
	_expect(panel.get_theme_stylebox("panel") is StyleBoxEmpty, "no outer frame or panel background")
	for pair in [
		[preload("res://assets/ui/dialogue_editor/choice_idle.res"), preload("res://assets/ui/design_2026_10/choice_button_no_diamond__r01.png")],
		[preload("res://assets/ui/dialogue_editor/choice_selected.res"), preload("res://assets/ui/design_2026_10/choice_button__r01.png")],
	]:
		var source: Texture2D = pair[1]
		var expected := source.get_image().get_region(Rect2i(65, 226, 2042, 263))
		expected.resize(700, 96, Image.INTERPOLATE_LANCZOS)
		var actual: Texture2D = pair[0]
		_expect(actual.get_image().get_data() == expected.get_data(), "texture pixels match correct source: " + actual.resource_path)

func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var rect := Rect2i(panel.get_global_rect())
	rect = rect.intersection(Rect2i(Vector2i.ZERO, get_tree().root.size))
	get_tree().root.get_texture().get_image().get_region(rect).save_png(output + name + ".png")

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await _frames()

func _frames() -> void:
	for index in range(5): await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
