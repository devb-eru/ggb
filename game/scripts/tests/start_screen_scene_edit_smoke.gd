extends Node

const SCENE := preload("res://scenes/ui/start_screen.tscn")
const OUTPUT := "res://../outputs/title-scene-2026-10-24/"
var errors: Array[String] = []
var stage: Control

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(stage)
	# No StartScreen._ready(): this is the authored scene, before runtime setup.
	var preview = SCENE.instantiate()
	preview.set_script(null)
	stage.add_child(preview)
	await _frames()
	var composition: Control = preview.get_node("HtmlTitleComposition")
	_expect(preview.get_node("TitleBackground").texture.resource_path.ends_with("menu_background__r01.png"), "native scene has latest background")
	_expect(composition.get_node("TitleProtagonist").texture != null, "native scene contains character")
	_expect(preview.get_node("%Logo").text == "아빠,\n왜 안 와?", "native scene contains official title")
	_expect(composition.get_node("TitleMenuLayout").position.x < 0.2 * preview.size.x, "native menu on left")
	_expect(preview.get_node("%GalleryButton").is_visible_in_tree(), "gallery authored in scene")
	_expect(preview.get_node_or_null("SafeArea") == null and preview.get_node_or_null("PlaceholderArt") == null, "old composition removed")
	await _shot("01-authored-scene")
	preview.queue_free()
	await _frames()
	# Serialize actual Inspector-style edits, then run the edited saved scene.
	var edited = SCENE.instantiate()
	var menu: Control = edited.get_node("HtmlTitleComposition/TitleMenuLayout")
	menu.anchor_left = 0.08
	menu.anchor_right = 0.37
	var character: TextureRect = edited.get_node("HtmlTitleComposition/TitleProtagonist")
	character.anchor_left = 0.48
	character.offset_left = 11
	var logo: Label = edited.get_node("%Logo")
	logo.add_theme_font_size_override("font_size", 72)
	edited.get_node("%LogoStack").custom_minimum_size.y = 195
	edited.get_node("%NewGameButton").add_theme_font_size_override("font_size", 28)
	var shade: TextureRect = edited.get_node("HtmlTitleComposition/TitleShade")
	shade.self_modulate.a = 0.6
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "pack editable scene")
	_expect(ResourceSaver.save(packed, "user://__test_start_screen_edited.tscn") == OK, "save scene edits")
	edited.free()
	var store := AccessibilityProfileStore.new("user://__test_title_scene")
	var profile := store.default_profile()
	profile.motion_mode = "static"
	profile.display = {"mode": "windowed", "width": 1280, "height": 720}
	store.save_profile(profile)
	var game = load("user://__test_start_screen_edited.tscn").instantiate()
	game.configure_profile_store(store)
	stage.add_child(game)
	await _frames()
	menu = game.get_node("HtmlTitleComposition/TitleMenuLayout")
	character = game.get_node("HtmlTitleComposition/TitleProtagonist")
	_expect(is_equal_approx(menu.anchor_left, 0.08) and is_equal_approx(menu.anchor_right, 0.37), "runtime preserves menu anchors")
	_expect(is_equal_approx(character.anchor_left, 0.48) and is_equal_approx(character.offset_left, 11), "runtime preserves character position")
	_expect(game._logo.get_theme_font_size("font_size") == 72, "runtime preserves designer title size")
	_expect(game._logo_stack.custom_minimum_size.y == 195, "runtime preserves designer logo area")
	_expect(game._new_game_button.get_theme_font_size("font_size") == 28, "runtime preserves designer button font")
	_expect(is_equal_approx(game.get_node("HtmlTitleComposition/TitleShade").self_modulate.a, 0.6), "runtime preserves shade opacity")
	_expect(game.find_children("TitleProtagonist", "TextureRect", true, false).size() == 1, "runtime does not add duplicate artwork")
	_expect(game.find_children("GalleryButton", "Button", true, false).size() == 1, "runtime reuses authored menu controls")
	var live_composition = game.get_node("HtmlTitleComposition")
	var menu_rest: Vector2 = menu.position
	live_composition._cursor = Vector2.ONE
	live_composition._position_character()
	_expect(is_equal_approx(character.offset_left, 7) and menu.position == menu_rest, "parallax moves artwork without changing authored menu hit regions")
	live_composition._process(0.0)
	_expect(live_composition._cursor == Vector2.ZERO and is_equal_approx(character.offset_left, 11), "static mode restores edited artwork position")
	await _shot("02-edited-scene-in-game")
	game._profile.text_scale = 2.0
	game._apply_profile()
	await _frames()
	_expect(game._new_game_button.get_theme_font_size("font_size") == 56, "accessibility scales authored font")
	await _shot("03-edited-scene-200")
	game._profile.text_scale = 1.0
	game._apply_profile()
	_expect(game._logo.get_theme_font_size("font_size") == 72, "reset restores authored font without accumulation")
	game.queue_free()
	await _frames()
	DirAccess.remove_absolute("user://__test_start_screen_edited.tscn")
	store.delete_test_profile()
	# Capture the actual unmodified scene with its complete normal startup.
	profile = store.default_profile()
	profile.motion_mode = "static"
	profile.display = {"mode": "windowed", "width": 1280, "height": 720}
	store.save_profile(profile)
	game = SCENE.instantiate()
	game.configure_profile_store(store)
	stage.add_child(game)
	await _shot("04-current-title-ko")
	game._locale = "en-US"
	TranslationServer.set_locale("en-US")
	game._apply_localized_text()
	game.refresh_slots()
	await _shot("05-current-title-en")
	await _check_title_overlays(game)
	var report := {"ok": errors.is_empty(), "errors": errors}
	var file := FileAccess.open(OUTPUT + "scene-edit-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("START_SCREEN_SCENE_EDIT_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _check_title_overlays(game: Control) -> void:
	var composition = game.get_node("HtmlTitleComposition")
	composition.set_process(false)
	var background: TextureRect = game.get_node("TitleBackground")
	var character: TextureRect = composition.get_node("TitleProtagonist")
	var background_id := background.get_instance_id()
	var character_id := character.get_instance_id()
	var menu_rect: Rect2 = composition.get_node("TitleMenuLayout").get_global_rect()
	game._profile.motion_mode = "standard"
	game._profile.first_run_complete = true
	game._locale = "ko-KR"
	TranslationServer.set_locale("ko-KR")
	game._apply_localized_text()
	var summaries: Array[Dictionary] = [{"slot_id":"slot_01", "available":true, "updated_at_utc":1792770000, "location_id":"M1_CENTRAL_HALL", "day_index":0}]
	game.set_slot_summaries(summaries)
	var cases := [
		[game._on_new_game_pressed, game._new_slot_panel, "Background", "Paper", "res://scenes/ui/new_game_panel.tscn", "06-new-game-overlay"],
		[game._on_load_pressed, game._load_slot_panel, "Background", "Paper", "res://scenes/ui/load_game_panel.tscn", "07-load-overlay"],
		[game._on_settings_pressed, game._settings_panel, "Surface/Background", "Surface/Paper", "res://scenes/ui/settings/settings_screen.tscn", "08-settings-overlay"],
	]
	for entry in cases:
		entry[0].call()
		await _frames()
		var panel: Control = entry[1]
		_expect(panel.is_visible_in_tree() and not panel.get_node(entry[2]).visible, "%s uses title backdrop" % entry[5])
		_expect(background.get_instance_id() == background_id and character.get_instance_id() == character_id and character.is_visible_in_tree(), "%s retains original artwork" % entry[5])
		var standalone: Control = load(entry[4]).instantiate()
		_expect(standalone.get_node(entry[2]).visible, "standalone scene keeps preview backdrop")
		var paper: Control = panel.get_node(entry[3])
		var authored_paper: Control = standalone.get_node(entry[3])
		_expect(paper.anchor_left == authored_paper.anchor_left and paper.anchor_right == authored_paper.anchor_right and paper.anchor_top == authored_paper.anchor_top and paper.anchor_bottom == authored_paper.anchor_bottom and composition._offsets(paper) == composition._offsets(authored_paper), "%s keeps authored window size" % entry[5])
		standalone.free()
		_expect(game._new_game_button.focus_mode == Control.FOCUS_NONE and game._new_game_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and game._active_modal().is_ancestor_of(get_viewport().gui_get_focus_owner()), "%s traps input in popup" % entry[5])
		_expect(game._dimmer.visible and game._dimmer.color.a < 0.3, "paper popup keeps main artwork visible")
		composition._cursor = Vector2.ZERO
		composition._update_artwork(0.0, composition.size * 0.5, true)
		var rest := character.position
		composition._update_artwork(0.3, composition.size * 0.9, true)
		_expect(character.position != rest and composition.get_node("TitleMenuLayout").get_global_rect() == menu_rect, "%s keeps background parallax with fixed menu regions" % entry[5])
		await _shot(entry[5])
		game._close_modal()
		await _frames()
		_expect(game._active_modal() == null and not game._dimmer.visible and game._new_game_button.focus_mode == Control.FOCUS_ALL, "closing popup restores title input")
	game._profile.first_run_complete = false
	game._on_new_game_pressed()
	await _frames()
	_expect(game._first_run_panel.is_visible_in_tree() and not game._first_run_panel.get_node("Surface/Background").visible, "first-run accessibility opens above title before slots")
	await _shot("09-first-run-overlay")
	for mode in ["static", "reduced"]:
		game._profile.motion_mode = mode
		composition._update_artwork(0.3, composition.size * 0.9, true)
		_expect(composition._cursor == Vector2.ZERO and composition._offsets(character) == composition._character_rest, "%s disables motion while popup is open" % mode)
	game._profile.motion_mode = "standard"
	game.set_input_suspended(true)
	composition._update_artwork(0.3, composition.size * 0.9, true)
	_expect(composition._cursor == Vector2.ZERO, "suspended input still disables parallax")
	game.set_input_suspended(false)
	composition._update_artwork(0.3, composition.size * 0.9, false)
	_expect(composition._cursor == Vector2.ZERO, "unfocused window still disables parallax")
	game._close_modal()
	game._on_quit_pressed()
	_expect(game._dimmer.color == game._default_dimmer_color, "small confirmation keeps its authored dimmer")
	game._close_modal()

func _frames() -> void:
	for index in range(6): await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
