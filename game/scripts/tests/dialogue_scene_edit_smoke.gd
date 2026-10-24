extends Node

var errors: Array[String] = []
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/dialogue-scene-editor")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var window := get_tree().root
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(stage)
	var scene := preload("res://scenes/ui/dialogue_hud.tscn")
	var preview := scene.instantiate()
	stage.add_child(preview)
	await _frames()
	_expect(preview.get_node("PreviewBackground").visible, "standalone scene includes preview background")
	_expect(preview.get_node("StandingPortrait").texture != null, "standalone scene includes sample character")
	_expect(preview.get_node("MenuButton").visible and preview.get_node("LocationLabel").text == "주인공의 침실", "standalone scene includes editable top HUD")
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(output + "/editor-scene-preview.png")
	preview.queue_free()
	await _frames()
	# Simulate visual Inspector edits, then actually serialize and reload the scene.
	var edited := scene.instantiate()
	var body: Control = edited.get_node("DialogueBacking")
	body.offset_left = 32
	body.offset_top = -350
	body.offset_bottom = -105
	var text: Label = body.get_node("Margin/Body/DialogueScroll/DialogueText")
	text.add_theme_font_size_override("font_size", 40)
	text.add_theme_color_override("font_color", Color("f4d8b8"))
	edited.get_node("StandingPortrait").offset_left = -90
	edited.get_node("StandingPortrait").offset_right = 950
	edited.get_node("DialogueOrnament").self_modulate.a = 0.6
	edited.get_node("NotebookButton").offset_left = 30
	edited.get_node("NotebookButton").offset_right = 150
	edited.get_node("SpeakerNameplateArt").offset_top = -355
	edited.get_node("SpeakerNameplateArt").offset_bottom = -195
	var menu: Button = edited.get_node("MenuButton")
	menu.offset_left = 70
	menu.offset_top = 40
	menu.offset_right = 320
	menu.offset_bottom = 116
	menu.add_theme_font_size_override("font_size", 31)
	menu.add_theme_color_override("font_color", Color("d9c6a0"))
	menu.icon = null
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color("382648")
	menu.add_theme_stylebox_override("normal", menu_style)
	edited.get_node("MenuButton/IconDivider").offset_left = 20
	edited.get_node("MenuButton/IconDivider").offset_right = 21
	var location: Label = edited.get_node("LocationLabel")
	location.offset_left = 390
	location.offset_top = 50
	location.offset_right = 1110
	location.offset_bottom = 130
	location.add_theme_font_size_override("font_size", 38)
	location.add_theme_color_override("font_color", Color("f4d8b8"))
	edited.get_node("LocationDivider").offset_left = 365
	edited.get_node("LocationDivider").offset_right = 367
	edited.get_node("LocationDivider").color = Color("ae84cf")
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "pack designer edits")
	_expect(ResourceSaver.save(packed, "user://__test_dialogue_edited.tscn") == OK, "save edited scene")
	edited.free()
	var game = preload("res://scripts/prologue/prologue_controller.gd").new()
	game.dialogue_hud_scene = load("user://__test_dialogue_edited.tscn")
	game._test_mode = true
	stage.add_child(game)
	_expect(game._dialogue_choice_panel.scene_file_path == "res://scenes/ui/choice_window.tscn", "game instantiates the editable choice-window scene")
	game._show_dialogue([{"speaker": "주인공", "portrait": "PROTAGONIST", "text": "씬에서 바꾼 위치와 폰트가 게임에도 그대로 적용됩니다."}])
	await _frames()
	_expect(game._dialogue_label.get_theme_font_size("font_size") == 40, "scene font size survives gameplay setup")
	_expect(game._dialogue_label.get_theme_color("font_color") == Color("f4d8b8"), "scene text color survives gameplay setup")
	_expect(game._portrait.offset_left == -90, "scene character position survives gameplay setup")
	_expect(game._notebook_button.offset_left == 30, "scene notebook position survives gameplay reparenting")
	_expect(game._dialogue_layer.get_node("DialogueBacking").offset_top == -350, "scene body position survives gameplay setup")
	_expect(game._dialogue_layer.get_node("SpeakerNameplateArt").offset_top == -355, "scene nameplate position preserved at normal text size")
	_expect(is_equal_approx(game._dialogue_layer.get_node("DialogueOrnament").self_modulate.a, 0.6), "scene ornament opacity survives gameplay setup")
	_validate_top_hud(game, "prologue")
	_expect(game._menu_button.is_visible_in_tree() and game._location_label.is_visible_in_tree(), "top HUD remains visible above active dialogue")
	game._menu_button.pressed.emit()
	_expect(game._modal_active, "authored menu button retains gameplay connection")
	game._close_modal()
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	game._unhandled_input(cancel)
	_expect(game._modal_active, "Escape still opens in-game menu")
	game._close_modal()
	game._apply_reading_text_scale(2.0)
	await _frames()
	_expect(game._dialogue_label.get_theme_font_size("font_size") == 80, "large text scales designer font size")
	game._apply_reading_text_scale(1.0)
	await _frames()
	_expect(game._dialogue_label.get_theme_font_size("font_size") == 40, "font size restores without accumulating scale")
	_expect(game._dialogue_layer.get_node("SpeakerNameplateArt").offset_top == -355 and game._dialogue_layer.get_node("SpeakerNameplateArt").size.y == 160, "normal text restores designer nameplate geometry")
	var click: Rect2 = game._dialogue_next.get_global_rect()
	var scroll: Rect2 = game._dialogue_scroll.get_global_rect()
	_expect(click.position.is_equal_approx(scroll.position), "invisible next region follows moved body")
	_validate_top_hud(game, "after accessibility refresh")
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(output + "/designer-edit-in-game.png")
	game.queue_free()
	await _frames()
	var fixture = preload("res://scripts/tests/notebook_presentation_smoke.gd").new()
	for index in range(fixture.VIEWS.size()):
		fixture._seed(["A1", "C0", "D0"][index])
		var chapter = fixture.VIEWS[index].new()
		chapter.dialogue_hud_scene = load("user://__test_dialogue_edited.tscn")
		chapter.configure_session(fixture.SLOT, "MORNING_ROUTE")
		stage.add_child(chapter)
		await _frames()
		_validate_top_hud(chapter, "chapter family " + str(index))
		_expect(not chapter._location_label.text.is_empty() and chapter._location_label.text != "주인공의 침실", "chapter replaces preview location with live room name " + str(index))
		chapter._dismiss_dialogue_for_test()
		_expect(chapter._menu_button.is_visible_in_tree() and chapter._location_label.is_visible_in_tree(), "top HUD persists outside dialogue " + str(index))
		chapter._menu_button.pressed.emit()
		_expect(chapter._modal_active, "chapter authored menu retains connection " + str(index))
		chapter._close_modal()
		chapter.queue_free()
		await _frames()
	SaveManager.delete_test_slot(fixture.SLOT)
	DirAccess.remove_absolute("user://__test_dialogue_edited.tscn")
	var report := {"ok": errors.is_empty(), "errors": errors}
	var file := FileAccess.open(output + "/scene-edit-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DIALOGUE_SCENE_EDIT_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _validate_top_hud(game: Control, context: String) -> void:
	var menu: Button = game._menu_button
	var location: Label = game._location_label
	_expect(menu.position == Vector2(70, 40) and menu.size == Vector2(250, 76), context + ": menu geometry survives setup")
	_expect(menu.get_theme_font_size("font_size") == 31 and menu.get_theme_color("font_color") == Color("d9c6a0"), context + ": menu typography survives setup")
	_expect(menu.icon == null and menu.get_theme_stylebox("normal") is StyleBoxFlat, context + ": menu icon and custom style survive setup")
	_expect(menu.get_node("IconDivider").offset_left == 20, context + ": menu divider remains editable")
	_expect(location.position == Vector2(390, 50) and location.size == Vector2(720, 80), context + ": location geometry survives setup")
	_expect(location.get_theme_font_size("font_size") == 38 and location.get_theme_color("font_color") == Color("f4d8b8"), context + ": location typography survives setup")
	_expect(game.get_node("LocationDivider").offset_left == 365 and game.get_node("LocationDivider").color == Color("ae84cf"), context + ": location divider survives setup")

func _frames() -> void:
	for index in range(6): await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
