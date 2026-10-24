extends Node

var errors: Array[String] = []
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/ui-hud-2026-10-22")
var stage: Control

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hud-output="): output = argument.trim_prefix("--hud-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(stage)
	var game = preload("res://scripts/prologue/prologue_controller.gd").new()
	game._test_mode = true
	stage.add_child(game)
	await _frames()
	game._enter_room("M1_CENTRAL_HALL")
	game._show_dialogue([
		{"speaker": "주인공", "portrait": "PROTAGONIST", "text": "이 종이는 어디에서 찾았나요?\n위쪽에 작은 홈이 있네요."},
		{"speaker": "에드가", "portrait": "EDGAR", "text": "서고에서 발견했습니다. 종이의 모서리를 살펴보시겠습니까?"}
	])
	await _frames()
	_expect(game._notebook_button.text == "수첩", "notebook caption omits N")
	_expect(game._notebook_button.size == Vector2(120, 136) and game._notebook_button.position == Vector2(18, 926), "compact vertical notebook at bottom left")
	_expect(not "ESC" in game._menu_button.text.to_upper(), "menu omits Escape caption")
	_expect(game.get_node_or_null("InventoryReadOnlyHint") == null, "no inventory unavailability text")
	_expect(game._inventory_panel.find_children("*", "Label", true, false).is_empty(), "inventory has no title or state label")
	_expect(game._dialogue_next.text.is_empty() and game._dialogue_next.icon == null, "no visible next label or icon")
	for hud in [game._menu_button, game._location_label, game._notebook_button, game._inventory_panel]:
		_expect(hud.get_index() > game._dialogue_layer.get_index() and hud.get_index() < game._modal_layer.get_index(), "HUD above dialogue and below modal: " + hud.name)
	var rail: Rect2 = game._inventory_panel.get_global_rect()
	_check_inventory_edges(game)
	var ornament: TextureRect = game._dialogue_layer.get_node("DialogueOrnament")
	_expect(is_equal_approx(ornament.self_modulate.a, 0.8), "dialogue ornament is twenty percent fainter")
	_expect(ornament.get_global_rect().position.x < 0 and ornament.get_global_rect().end.x >= rail.position.x, "ornaments reach both playfield edges")
	_expect(game._dialogue_label.get_theme_font_size("font_size") == 44 and game._dialogue_label.global_position.x > 400, "dialogue text size and rightward inset match reference")
	_expect(game._background.get_global_rect() == game.get_global_rect(), "background fills viewport including header")
	game._notebook_button.grab_focus()
	var focus = game._notebook_button.get_theme_stylebox("focus")
	_expect(focus is StyleBoxFlat and focus.border_width_left == 0 and focus.bg_color.a == 0, "focus rectangle invisible while keyboard focus retained")
	await _shot("01-dialogue-protagonist")
	# Actual GUI click hits the unobtrusive dialogue body, never the HUD behind it.
	await _click(game._dialogue_next.get_global_rect().get_center())
	_expect(game._dialogue_index == 1, "clicking dialogue body advances exactly one line")
	await _shot("02-dialogue-edgar")
	await _key(KEY_ENTER)
	_expect(not game._dialogue_active, "Enter finishes through the focused body control")
	var developer := preload("res://scripts/ui/developer_panel.gd").new()
	add_child(developer)
	await _frames()
	_expect(not developer.launch_button.get_global_rect().intersects(rail), "developer control does not overlap inventory")
	await _shot("03-exploration")
	developer.queue_free()
	await _frames()
	game._show_dialogue([{"speaker": "주인공", "portrait": "PROTAGONIST", "text": "긴 문장을 읽는 중에도 수첩과 대화기록을 사용할 수 있습니다.\n".repeat(15)}])
	game._apply_reading_text_scale(2.0)
	await _frames()
	_expect(game._dialogue_layer.get_node("SpeakerNameplateArt").get_global_rect().get_center().y > game._speaker_label.get_global_rect().end.y, "speaker rule remains below enlarged name")
	await _shot("04-dialogue-200")
	var before: int = game._dialogue_index
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = game._dialogue_next.get_global_rect().get_center()
	get_tree().root.push_input(wheel, true)
	await _frames()
	_expect(game._dialogue_scroll.scroll_vertical > 0 and game._dialogue_index == before, "wheel scrolls long dialogue without advancing")
	TranslationServer.set_locale("en-US")
	game._show_dialogue([{"speaker": "주인공", "portrait": "PROTAGONIST", "text": "Where did you find this paper?\nThere is a small notch at the top."}])
	game._apply_reading_text_scale(1.0)
	await _shot("05-dialogue-english")
	_expect(game._notebook_button.text == "Notebook" and game._dialogue_history_button.text == "History (H)", "HUD follows language")
	get_tree().root.size = Vector2i(1600, 720)
	await _frames()
	_check_inventory_edges(game)
	await _shot("07-wide-window")
	get_tree().root.size = Vector2i(1280, 900)
	await _frames()
	_check_inventory_edges(game)
	await _shot("08-tall-window")
	get_tree().root.size = Vector2i(1280, 720)
	await _frames()
	game.queue_free()
	await _frames()
	# A real chapter session verifies the shortcut and click open durable history.
	TranslationServer.set_locale("ko-KR")
	var fixture = preload("res://scripts/tests/notebook_presentation_smoke.gd").new()
	fixture._seed("A1")
	var chapter = fixture._view(get_tree(), 0)
	chapter.reparent(stage)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter._show_dialogue(fixture._lines())
	await _frames()
	var current_line: int = chapter._dialogue_index
	await _key(KEY_H)
	_expect(is_instance_valid(chapter._notebook_host), "H opens unified dialogue history")
	if is_instance_valid(chapter._notebook_host):
		var host = chapter._notebook_host
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(get_tree(), host), "history model ready")
		await _shot("06-history-from-h")
		host.request_close()
		await preload("res://scripts/tests/notebook_test_wait.gd").closed(get_tree(), host)
	await _frames()
	_expect(chapter._dialogue_index == current_line and chapter._dialogue_active, "history returns to same dialogue line")
	await _click(chapter._dialogue_history_button.get_global_rect().get_center())
	_expect(is_instance_valid(chapter._notebook_host), "history button opens same durable history")
	if is_instance_valid(chapter._notebook_host):
		var host = chapter._notebook_host
		await preload("res://scripts/tests/notebook_test_wait.gd").ready(get_tree(), host)
		host.request_close()
		await preload("res://scripts/tests/notebook_test_wait.gd").closed(get_tree(), host)
	chapter.queue_free()
	await _frames()
	get_node("/root/SaveManager").delete_test_slot("__test_notebook_presentation")
	var report := {"ok": errors.is_empty(), "errors": errors}
	var file := FileAccess.open(output + "/audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DIALOGUE_HUD_AUDIT: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _frames() -> void:
	for index in range(5): await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output + "/" + name + ".png")

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_tree().root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		get_tree().root.push_input(event, true)
		await _frames()

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await _frames()

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _check_inventory_edges(game) -> void:
	var rail: Rect2 = game._inventory_panel.get_global_rect()
	var screen: Rect2 = game.get_global_rect()
	_expect(rail.end.is_equal_approx(screen.end) and is_equal_approx(rail.position.y, screen.position.y), "inventory touches screen top, right and bottom")
	var edge: float = rail.position.y
	for slot in game._inventory_slots:
		var rect: Rect2 = slot.get_global_rect()
		_expect(is_equal_approx(rect.position.y, edge) and is_equal_approx(rect.position.x, rail.position.x) and is_equal_approx(rect.end.x, rail.end.x), "inventory slots join without inner margins")
		edge = rect.end.y
	_expect(is_equal_approx(edge, screen.end.y), "last slot reaches actual screen bottom")
