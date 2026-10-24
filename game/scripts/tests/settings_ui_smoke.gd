extends Node
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/settings-ui-2026-10-24/")
var errors: Array[String] = []
var checks := 0
class DisplayFixture extends RefCounted:
	var state := {"mode":"windowed", "width":1280, "height":720}
	func capture() -> Dictionary: return state.duplicate()
	func apply(value: Dictionary) -> bool:
		state = value.duplicate()
		return true
	func restore(value: Dictionary) -> void: state = value.duplicate()
class RejectedStore extends AccessibilityProfileStore:
	func save_profile(_value: Dictionary) -> Dictionary: return {"ok":false}
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var window := get_tree().root
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	var screen = preload("res://scenes/ui/settings/settings_screen.tscn").instantiate()
	screen.profile_store = AccessibilityProfileStore.new("user://__test_settings_ui")
	screen.profile_store.delete_test_profile()
	var profile: Dictionary = screen.profile_store.default_profile()
	profile.audio = {"master":0.8,"bgm":0.6,"ambience":0.7,"effects":0.8,"muted":false}
	profile.display = {"mode":"windowed","width":1280,"height":720}
	screen.profile_store.save_profile(profile)
	get_tree().root.add_child(screen)
	var backend := DisplayFixture.new()
	screen.preview = screen.Display.Preview.new(backend, screen.Display.validate)
	for id in screen.CATEGORIES:
		screen.show_page(id)
		await _shot(id)
	await _behavior(screen, backend)
	var store: AccessibilityProfileStore = screen.profile_store
	screen.queue_free()
	await _frames()
	await _scene_edits()
	await _title_and_game()
	store.delete_test_profile()
	var report := {"ok":errors.is_empty(),"errors":errors,"checks":checks}
	var file := FileAccess.open(output + "audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SETTINGS_UI_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _behavior(screen, backend: DisplayFixture) -> void:
	var before_game := GameState.get_snapshot()
	screen.show_page("accessibility")
	_expect(not screen.apply.visible, "accessibility has no apply button")
	await _click(screen.text_size.get_child(1))
	_expect(screen.profile_store.load_profile().profile.text_scale == 1.25, "text size is saved immediately by native click")
	await _click(screen.captions.get_child(1))
	_expect(not screen.profile_store.load_profile().profile.captions_enabled, "sensory captions save immediately")
	_expect(not screen._pages.accessibility.get_node("Preview/Margin/Body/Captions").visible, "caption preview follows actual toggle")
	screen.restore_defaults()
	screen.show_page("audio")
	_expect(not screen.apply.visible, "audio has no apply button")
	screen.sliders.master.value = 37
	await _click(screen.mute.get_child(0))
	_expect(is_equal_approx(screen.profile_store.load_profile().profile.audio.master,0.37) and screen.profile_store.load_profile().profile.audio.muted, "volume and mute persist immediately")
	screen.show_page("controls")
	_expect(not screen.apply.visible, "controls have no apply button")
	screen.begin_capture("confirm",1)
	await _key(KEY_F7)
	var binding: Array = screen.profile_store.load_profile().profile.key_bindings.confirm
	_expect(binding.size() == 2 and int(binding[0]) == KEY_ENTER and int(binding[1]) == KEY_F7, "changing secondary confirm preserves the primary binding")
	screen.begin_capture("notebook")
	await _key(KEY_F7)
	_expect(not screen._capture.is_empty() and int(screen.profile_store.load_profile().profile.key_bindings.notebook[0]) == KEY_N, "duplicate key rejected without changing active binding")
	await _key(KEY_F8)
	_expect(int(screen.profile_store.load_profile().profile.key_bindings.notebook[0]) == KEY_F8, "new valid key saves immediately")
	screen.restore_defaults()
	screen.show_page("language")
	await _click(screen.choice.get_child(1))
	_expect(screen.profile_store.load_profile().profile.get("locale","ko-KR") == "ko-KR", "language remains a draft until applied")
	screen.show_page("audio")
	screen.sliders.bgm.value = 24
	_expect(screen.profile_store.load_profile().profile.get("locale","ko-KR") == "ko-KR", "audio save does not publish draft language")
	screen.show_page("language")
	_expect(screen.choice.selected == 1, "tab navigation retains language draft")
	await _click(screen.apply)
	_expect(screen.profile_store.load_profile().profile.locale == "en-US" and screen._tabs.language.get_node("Caption").text == "Language", "language applies and translates native settings")
	screen.show_page("display")
	screen.mode.get_child(1).pressed.emit()
	_expect(backend.state.mode == "windowed" and screen.profile_store.load_profile().profile.display.mode == "windowed", "display selection does not apply before confirmation")
	await _click(screen.apply)
	_expect(screen.preview.pending and screen.confirmation.visible and backend.state.mode == "borderless", "display apply opens actual preview confirmation")
	_expect(screen._tabs.audio.focus_mode == Control.FOCUS_NONE, "preview traps focus away from tabs")
	await _shot("display-confirmation")
	screen.preview.deadline_msec = Time.get_ticks_msec()-1
	screen._process(0)
	_expect(not screen.preview.pending and backend.state.mode == "windowed" and screen.profile_store.load_profile().profile.display.mode == "windowed", "expired preview restores display without saving")
	screen.mode.get_child(1).pressed.emit()
	screen._begin_preview()
	screen._keep()
	_expect(screen.profile_store.load_profile().profile.display.mode == "borderless" and not screen.confirmation.visible, "keep commits display")
	var real_store: AccessibilityProfileStore = screen.profile_store
	screen.profile_store = RejectedStore.new("user://__test_settings_ui")
	screen.show_page("audio")
	var saved_master: float = real_store.load_profile().profile.audio.master
	screen.sliders.master.value = 89
	_expect(screen._draft.audio.master == saved_master and not screen.message.text.is_empty(), "failed immediate save restores last applied audio")
	screen.profile_store = real_store
	screen.show_page("accessibility")
	screen.text_size.get_child(3).pressed.emit()
	for id in screen.CATEGORIES:
		screen.show_page(id)
		await _shot(id + "-200-en")
		_expect(screen._pages[id].size.x <= screen.get_node("Surface/ContentScroll").size.x + 1, "large text fits page width: " + id)
		var viewport: Rect2 = screen.get_node("Surface/ContentScroll").get_global_rect()
		for control in screen._pages[id].find_children("*", "Control", true, false):
			if control is BaseButton or control is Slider or control.name == "Preview":
				_expect(control.get_global_rect().end.x <= viewport.end.x + 1, "large-text child fits horizontally: " + str(control.get_path()))
	screen.show_page("display")
	screen._begin_preview()
	await _shot("display-confirmation-200-en")
	var popup: Rect2 = screen.confirmation.get_node("Center/Paper").get_global_rect()
	_expect(popup.position.x >= 0 and popup.end.x <= screen.size.x and popup.position.y >= 0 and popup.end.y <= screen.size.y, "large-text display confirmation remains inside the screen")
	screen._revert()
	screen.show_page("accessibility")
	screen.restore_defaults()
	_expect(GameState.get_snapshot() == before_game, "settings do not change gameplay progress")

func _scene_edits() -> void:
	var authored = preload("res://scenes/ui/settings/settings_screen.tscn").instantiate()
	authored.get_node("Surface/Paper").offset_left = 24
	authored.get_node("Surface/Category").add_theme_font_size_override("font_size",51)
	authored.get_node("Surface/ContentScroll/Pages/Audio/Master/Caption").add_theme_font_size_override("font_size",33)
	authored.get_node("Surface/ContentScroll/Pages/Accessibility/Preview/Margin/Body/Sample").add_theme_font_size_override("font_size",35)
	authored.get_node("Surface/ContentScroll/Pages/Display/Illustration").self_modulate.a = 0.6
	authored.get_node("Surface/ContentScroll/Pages/Language/Preview/Margin/Body/Sample").add_theme_font_size_override("font_size",39)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("382648")
	authored.get_node("Surface/ContentScroll/Pages/Controls/Left/notebook/Keys/Key_notebook").add_theme_stylebox_override("normal",style)
	var packed := PackedScene.new()
	_expect(packed.pack(authored) == OK and ResourceSaver.save(packed,"user://__test_settings_edited.tscn") == OK, "serialize edits across all five pages")
	authored.free()
	var live = load("user://__test_settings_edited.tscn").instantiate()
	live.profile_store = AccessibilityProfileStore.new("user://__test_settings_edits")
	get_tree().root.add_child(live)
	_expect(live.get_node("Surface/Paper").offset_left == 24 and live.heading.get_theme_font_size("font_size") == 51, "authored shell geometry and font survive runtime")
	_expect(live.labels.master.get_theme_font_size("font_size") == 33, "authored audio font survives runtime")
	_expect(live._pages.accessibility.get_node("Preview/Margin/Body/Sample").get_theme_font_size("font_size") == 35, "authored accessibility font survives runtime")
	_expect(live._pages.language.get_node("Preview/Margin/Body/Sample").get_theme_font_size("font_size") == 39, "authored language font survives runtime")
	_expect(is_equal_approx(live._pages.display.get_node("Illustration").self_modulate.a,0.6), "authored display illustration survives runtime")
	_expect(live.buttons.notebook.get_theme_stylebox("normal") is StyleBoxFlat, "authored controls style survives runtime")
	live.queue_free()
	await _frames()
	DirAccess.remove_absolute("user://__test_settings_edited.tscn")

func _title_and_game() -> void:
	var store := AccessibilityProfileStore.new("user://__test_settings_integration")
	store.delete_test_profile()
	var profile := store.default_profile()
	profile.display = {"mode":"windowed","width":1280,"height":720}
	store.save_profile(profile)
	var title = preload("res://scenes/ui/start_screen.tscn").instantiate()
	title.configure_profile_store(store)
	get_tree().root.add_child(title)
	title._on_new_game_pressed()
	await _frames()
	_expect(title._first_run_panel.visible and not title._slot_panel.visible, "first-run accessible settings precede slot selection")
	await _click(title._first_run_panel.text_size.get_child(1))
	_expect(store.load_profile().profile.text_scale == 1.25 and not store.load_profile().profile.first_run_complete, "first run applies immediately without prematurely completing setup")
	await _click(title._first_run_panel.apply)
	_expect(store.load_profile().profile.first_run_complete and title._slot_panel.visible, "first-run Start continues to slots")
	title._close_modal()
	title._on_settings_pressed()
	await _click(title._settings_panel._tabs.audio)
	title._settings_panel.sliders.master.value = 42
	_expect(title.get_audio_settings().master == 0.42, "title profile follows immediate audio changes")
	title._close_modal()
	title.hide()
	await _frames()
	var fixture = preload("res://scripts/tests/notebook_presentation_smoke.gd").new()
	for index in range(4):
		var game
		if index == 0:
			game = preload("res://scripts/prologue/prologue_controller.gd").new()
			game._test_mode = true
		else:
			fixture._seed(["A1","C0","D0"][index-1])
			game = fixture.VIEWS[index-1].new()
			game.configure_session(fixture.SLOT,"MORNING_ROUTE")
		game._audio_profile_store = store
		get_tree().root.add_child(game)
		await _frames()
		game._dismiss_dialogue_for_test()
		game._open_menu()
		var entry: Button
		for child in game._modal_body.get_children():
			if child is Button and child.text in ["설정","Settings"]: entry = child
		_expect(entry != null, "pause menu exposes the native settings entry " + str(index))
		if entry != null: await _click(entry)
		var settings = game._audio_settings_panel
		await _click(settings._tabs.audio)
		_expect(settings.scene_file_path == "res://scenes/ui/settings/settings_screen.tscn" and settings.visible, "native settings instantiated for gameplay family " + str(index))
		settings.sliders.master.value = 35 + index
		_expect(store.load_profile().profile.audio.master == (35 + index)/100.0 and settings.visible, "game audio applies immediately and stays in settings " + str(index))
		if index == 0:
			settings.show_page("language")
			settings.choice.get_child(1).pressed.emit()
			settings.apply.pressed.emit()
			_expect(store.load_profile().profile.locale == "en-US", "language applies from the actual game settings")
		settings.back.pressed.emit()
		_expect(game._modal_panel.visible and not settings.visible, "Back returns to pause menu " + str(index))
		game.queue_free()
		await _frames()
	SaveManager.delete_test_slot(fixture.SLOT)
	title.refresh_profile()
	_expect(title._locale == "en-US" and title._logo.text.replace("\n"," ") == "papa, where r u?", "returning to title refreshes saved game language")
	title.queue_free()
	await _frames()
	store.delete_test_profile()

func _frames() -> void:
	for index in range(8): await get_tree().process_frame

func _click(control: Control) -> void:
	control.grab_focus()
	await _frames()
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	get_tree().root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = motion.position
		get_tree().root.push_input(event,true)
		await _frames()

func _key(code: int) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames()
func _shot(name: String) -> void:
	for index in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output + name + ".png")
func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(message)
