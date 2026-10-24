extends Node

const DESIGN := preload("res://scripts/ui/design_theme.gd")
var errors: Array[String] = []
var capture := false
var output := ""
var root: Window

func _ready() -> void:
	root = get_tree().root
	call_deferred("_run")

func _run() -> void:
	capture = "--capture-design" in OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path("res://").path_join("../outputs/ui-design-audit-2026-10-24")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("15121c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(background)
	var title = preload("res://scenes/ui/start_screen.tscn").instantiate()
	var test_profile := AccessibilityProfileStore.new("user://__test_design_ui")
	var profile := test_profile.default_profile()
	profile.display = {"mode": "windowed", "width": 1280, "height": 720}
	test_profile.save_profile(profile)
	title.configure_profile_store(test_profile)
	stage.add_child(title)
	_expect(title._first_text_option == title._first_run_panel.get_node("Surface/ContentScroll/Pages/Accessibility/Fields/TextSize/Options"), "first-run settings use the authored native text-size control")
	await _frames()
	var composition: Control = title.get_node("HtmlTitleComposition")
	_expect(composition.get_node("TitleMenuLayout").position.x < root.content_scale_size.x * 0.2, "title menu is on left")
	_expect(composition.character.position.x > root.content_scale_size.x * 0.4, "portrait is on right")
	_expect(title.get_node_or_null("PlaceholderArt") == null, "old title effects removed")
	_expect(title._logo.text.replace("\n", " ") == "아빠, 왜 안 와?", "Korean title matches user wording")
	var fixed_menu_position: Vector2 = composition.get_node("TitleMenuLayout").position
	composition._cursor = Vector2.ONE
	composition._position_character()
	_expect(composition.get_node("TitleMenuLayout").position == fixed_menu_position, "parallax leaves menu hit regions fixed")
	title._profile.motion_mode = "reduced"
	composition._process(0.016)
	_expect(composition._cursor == Vector2.ZERO, "reduced motion resets artwork offsets")
	title._profile.motion_mode = "standard"
	await _shot("01-title-ko")
	title._on_load_pressed()
	await _shot("02-save-slots")
	title._close_modal()
	title._on_settings_pressed()
	_expect(not title._settings_panel.get_node("Surface/Background").visible, "settings opens above the existing title artwork")
	await _shot("03-settings-ko")
	var state_before: Dictionary = get_node("/root/GameState").get_snapshot()
	title._open_language_settings()
	title._language_panel.choice.get_child(1).pressed.emit()
	title._language_panel.apply.pressed.emit()
	_expect(title._locale == "en-US" and test_profile.load_profile().profile.locale == "en-US", "language choice persists")
	_expect(title._logo.text.replace("\n", " ") == "papa, where r u?", "English title preserves user case and punctuation")
	_expect(root.title == "papa, where r u?", "window caption follows selected title language")
	title._close_modal()
	await _shot("17-title-en")
	title._on_settings_pressed()
	_expect(get_node("/root/GameState").get_snapshot() == state_before, "language selection preserves gameplay")
	await _shot("13-language-en")
	title._open_language_settings()
	title._language_panel.choice.get_child(0).pressed.emit()
	title._language_panel.apply.pressed.emit()
	title._close_modal()
	title._profile.text_scale = 2.0
	title._apply_profile()
	await _shot("04-title-200")
	title._on_settings_pressed()
	await _shot("05-settings-200")
	title._close_modal()
	title._on_new_game_pressed()
	_expect(title._first_run_panel.is_visible_in_tree() and not title._first_run_panel.get_node("Surface/Background").visible, "first-run accessibility remains a popup before new-game slots")
	await _shot("15-first-run-200")
	var first_rect: Rect2 = title._first_run_panel.get_global_rect()
	_expect(first_rect.position.y >= 0 and first_rect.end.y <= title.size.y, "first-run panel stays within viewport at 200 percent")
	title._close_modal()
	title.queue_free()
	await _frames()
	var game = preload("res://scripts/prologue/prologue_controller.gd").new()
	game._test_mode = true
	stage.add_child(game)
	await _frames()
	await _shot("06-dialogue-ko")
	var line_before: int = game._dialogue_index
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	game._unhandled_input(cancel)
	_expect(game._modal_active and game._dialogue_index == line_before, "cancel opens menu without advancing dialogue")
	game._close_modal()
	_expect(game._inventory_panel.modulate == Color.WHITE, "inventory remains above dialogue shadow")
	for slot in game._inventory_slots: _expect(slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "inventory input blocked while reading")
	game._dialogue_active = false
	game._dialogue_layer.hide()
	game._open_menu()
	await _shot("07-pause-menu")
	game._close_modal()
	game._enter_room("M1_CENTRAL_HALL")
	game._enter_room("M1_PARLOR")
	game._dialogue_active = false
	game._dialogue_layer.hide()
	await _shot("08-exploration")
	game._progress.P1_complete = true
	game._open_menu()
	var map_state_before: Dictionary = get_node("/root/GameState").get_snapshot()
	game._open_discovered_map()
	_expect(game._map_panel._known.has("M1_PARLOR"), "map includes current room")
	_expect(not game._map_panel._known.has("H0_CORE_CHAMBER"), "map conceals unvisited room")
	_expect(get_node("/root/GameState").get_snapshot() == map_state_before, "map browsing preserves gameplay")
	await _shot("14-discovered-map")
	game._map_panel.present(get_node("/root/GameState").get_snapshot(), game._current_room, "en-US", 2.0, game._witnessed_rooms)
	await _shot("16-map-en-200")
	game._close_modal()
	game._selected_item = "SOFT_CLOTH"
	game._unhandled_input(cancel)
	_expect(game._selected_item.is_empty() and not game._modal_active, "cancel clears selected item before opening menu")
	game.queue_free()
	await _frames()
	var notebook = preload("res://scripts/ui/notebook_panel.gd").new()
	notebook.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(notebook)
	var query_fixture = preload("res://scripts/tests/notebook_query_smoke.gd").new()
	var fixture: Dictionary = query_fixture._fixture()
	var query = query_fixture._open(fixture)
	notebook.present(query, "ko-KR")
	var records: Dictionary = query.page({"tab":"clues"}, 0, query.cache_key())
	if not records.items.is_empty(): notebook.show_detail(records.items[0].key)
	await _frames()
	var tabs: Array = notebook._tabs.values()
	for index in range(1, tabs.size()): _expect(tabs[index].global_position.y > tabs[index - 1].global_position.y, "bookmarks are vertical")
	await _shot("09-notebook-ko")
	notebook._comparison_mode = true
	notebook._render_pair()
	await _shot("11-notebook-compare")
	notebook.present(query_fixture._open(fixture, "en-US"), "en-US", "dialogue", 2.0)
	await _shot("10-notebook-en-200")
	notebook.queue_free()
	await _frames()
	var campaign_fixture = preload("res://scripts/tests/notebook_presentation_smoke.gd").new()
	campaign_fixture._seed("B3_A")
	var chapter = campaign_fixture._view(get_tree(), 0)
	chapter.reparent(stage)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	chapter._dismiss_dialogue_for_test()
	await _frames()
	await _shot("12-clock-puzzle")
	chapter.queue_free()
	await _frames()
	get_node("/root/SaveManager").delete_test_slot("__test_notebook_presentation")
	var visits := preload("res://scripts/tests/discovered_rooms_smoke.gd").new().run()
	for message in visits.errors: errors.append("map persistence: " + message)
	var report := {"ok": errors.is_empty(), "errors": errors, "captures": capture}
	var file := FileAccess.open(output + "/audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DESIGN_UI_AUDIT: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _frames() -> void:
	for index in range(4): await get_tree().process_frame

func _shot(id: String) -> void:
	await _frames()
	if not capture: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + id + ".png")

func _expect(condition: bool, label: String) -> void:
	if not condition: errors.append(label)
