extends Node

const PRESENTATION := preload("res://scripts/systems/save_presentation.gd")
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/save-load-ui-2026-10-24/")
const SLOT := "__test_save_presentation"
var errors: Array[String] = []
var stage: Control

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(stage)
	var store := AccessibilityProfileStore.new("user://__test_save_load_ui")
	var profile := store.default_profile()
	profile.motion_mode = "static"
	profile.first_run_complete = true
	profile.display = {"mode": "windowed", "width": 1280, "height": 720}
	store.save_profile(profile)
	var title = preload("res://scenes/ui/start_screen.tscn").instantiate()
	title.configure_profile_store(store)
	stage.add_child(title)
	var room_texture: Texture2D = preload("res://assets/ui/save_load/textures/menu_background.tres")
	var summaries: Array[Dictionary] = [
		{"slot_id":"slot_01", "available":false},
		{"slot_id":"slot_02", "available":true, "updated_at_utc":1792770000, "location_id":"M1_CENTRAL_HALL", "day_index":0, "thumbnail":room_texture, "play_seconds":5048},
		{"slot_id":"slot_03", "available":false},
	]
	title.set_slot_summaries(summaries)
	var new_requests: Array = []
	var load_requests: Array = []
	title.new_game_requested.connect(func(slot): new_requests.append(slot))
	title.load_game_requested.connect(func(slot): load_requests.append(slot))
	title._on_new_game_pressed()
	await _frames()
	_expect(title._new_slot_panel.visible and title._new_slot_panel.rows.size() == 3, "new game has three manual slots")
	await _shot("01-new-game")
	await _click(title._slot_buttons[2].get_global_rect().get_center())
	_expect(new_requests.is_empty() and title._active_slot_ui.selected_slot_id == "slot_03", "row click only selects")
	await _click(title._active_slot_ui.confirm_button.get_global_rect().get_center())
	_expect(new_requests == ["slot_03"], "start confirms chosen empty slot")
	title._on_new_game_pressed()
	await _frames()
	await _click(title._slot_buttons[1].get_global_rect().get_center())
	await _click(title._active_slot_ui.confirm_button.get_global_rect().get_center())
	_expect(title._overwrite_panel.visible and new_requests.size() == 1, "occupied slot requires overwrite confirmation")
	title._return_to_slot_panel()
	_expect(title._slot_panel.visible and new_requests.size() == 1, "overwrite cancellation keeps save")
	title._close_modal()
	title._on_load_pressed()
	await _frames()
	_expect(title._active_slot_ui.rows.size() == 4 and title._active_slot_ui.selected_slot_id == "slot_02", "autosave aliases latest real slot")
	_expect(title._load_slot_panel.rows[0].title_label.text == "자동 저장", "autosave title is localized")
	_expect(title._slot_buttons[0].disabled and title._slot_buttons[2].disabled, "empty load slots disabled")
	await _shot("02-load-game")
	await _click(title._active_slot_ui.confirm_button.get_global_rect().get_center())
	_expect(load_requests == ["slot_02"], "autosave confirmation loads latest source slot")
	title._profile.text_scale = 2.0
	title._on_load_pressed()
	await _frames()
	var last: Button = title._slot_buttons[1]
	last.grab_focus()
	await _frames()
	_expect(last.get_global_rect().end.y <= title._active_slot_ui.get_node("Content/RowsScroll").get_global_rect().end.y + 1, "large text follows keyboard focus")
	await _shot("03-load-200")
	title._close_modal()
	title._profile.text_scale = 1.0
	title._locale = "en-US"
	title._on_load_pressed()
	await _shot("04-load-english")
	title._close_modal()
	var empty: Array[Dictionary] = []
	title.set_slot_summaries(empty)
	title._on_load_pressed()
	_expect(title._active_slot_ui.confirm_button.disabled, "no save leaves load action disabled")
	title._active_slot_ui.close_button.pressed.emit()
	_expect(not title._slot_panel.visible, "X closes slot page")
	title.queue_free()
	await _frames()
	# Saved scene edits must remain authoritative after normal runtime setup.
	var edited = preload("res://scenes/ui/new_game_panel.tscn").instantiate()
	edited.get_node("Paper").offset_left = 24
	edited.get_node("Content/Title").add_theme_font_size_override("font_size", 70)
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK and ResourceSaver.save(packed, "user://__test_save_panel.tscn") == OK, "save panel edits")
	edited.free()
	var reloaded = load("user://__test_save_panel.tscn").instantiate()
	stage.add_child(reloaded)
	reloaded.present({}, "", "ko-KR", 1.0)
	_expect(reloaded.get_node("Paper").offset_left == 24 and reloaded.title_label.get_theme_font_size("font_size") == 70, "scene geometry and typography survive setup")
	await _shot("05-authored-panel-edits")
	reloaded.queue_free()
	await _frames()
	await _presentation_cases()
	await _real_game_capture(store)
	var report := {"ok":errors.is_empty(), "errors":errors}
	var file := FileAccess.open(output + "audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("SAVE_LOAD_UI_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _presentation_cases() -> void:
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.make_default_snapshot()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "NEW_GAME_TEST_DISPLAY").ok, "create actual presentation test slot")
	var service := PRESENTATION.new()
	add_child(service)
	service.configure(SaveManager)
	var room := ColorRect.new()
	room.color = Color("345678")
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(room)
	service.begin_session(SLOT, room)
	service._seconds = 5048
	_expect(SaveManager.save_snapshot(SLOT, "P1_ENTRY", state, 2, "TEST_DISPLAY_COMMIT").ok, "actual successful save triggers presentation")
	await _frames()
	await RenderingServer.frame_post_draw
	var summary: Dictionary = SaveManager.inspect_slot(SLOT)
	var display: Dictionary = PRESENTATION.read(SaveManager.get_save_root(), summary)
	_expect(int(display.get("play_seconds", -1)) == 5048, "time survives presentation file reload")
	_expect(display.get("thumbnail") is Texture2D, "framebuffer thumbnail stored and reloaded")
	if display.get("thumbnail") is Texture2D:
		var pixel: Color = display.thumbnail.get_image().get_pixel(280, 126)
		_expect(absf(pixel.r - room.color.r) < 0.02, "thumbnail contains actual rendered playfield")
	var path: String = SaveManager._slot_paths(SLOT).main
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	_expect(PRESENTATION.write(SaveManager.get_save_root(), summary, 5050), "display record can update atomically")
	_expect(FileAccess.get_file_as_bytes(path) == saved_bytes, "display metadata never changes gameplay save bytes")
	_expect(int(PRESENTATION.read(SaveManager.get_save_root(), summary).get("play_seconds", -1)) == 5050, "updated presentation reload")
	service._seconds = 6000
	_expect(not SaveManager.save_snapshot(SLOT, "P1_ENTRY", {}, 3, "TEST_DISPLAY_REJECT").ok, "invalid gameplay save rejected")
	_expect(int(PRESENTATION.read(SaveManager.get_save_root(), summary).get("play_seconds", -1)) == 5050, "failed save does not publish new display time")
	service._seconds = 5055
	service.begin_session(SLOT, room)
	_expect(service._seconds == 5055, "same-run chapter handoff keeps unsaved session time")
	service.end_session()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "NEW_GAME_TEST_REPLACEMENT").ok, "replace slot with new playthrough")
	var replacement: Dictionary = SaveManager.inspect_slot(SLOT)
	_expect(PRESENTATION.read(SaveManager.get_save_root(), replacement).is_empty(), "new run never inherits old thumbnail or duration")
	service.begin_session(SLOT, room)
	_expect(service._seconds == 0, "new run clock resets")
	service.end_session()
	service.queue_free()
	room.queue_free()
	await _frames()
	SaveManager.delete_test_slot(SLOT)

func _real_game_capture(store: AccessibilityProfileStore) -> void:
	var slot := "__test_real_save_preview"
	SaveManager.delete_test_slot(slot)
	var host = preload("res://scenes/main/main.tscn").instantiate()
	host.get_node("%StartScreen").configure_profile_store(store)
	stage.add_child(host)
	host._on_new_game_requested(slot)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000:
		await get_tree().process_frame
		if SaveManager._notebook_job.is_empty() and PRESENTATION.read(SaveManager.get_save_root(), SaveManager.inspect_slot(slot)).has("thumbnail"): break
	var current: Dictionary = SaveManager.inspect_slot(slot)
	var display: Dictionary = PRESENTATION.read(SaveManager.get_save_root(), current)
	_expect(display.get("thumbnail") is Texture2D and display.get("play_seconds", -1) >= 0, "real new-game bootstrap records thumbnail and clock")
	if display.get("thumbnail") is Texture2D:
		display.thumbnail.get_image().save_png(output + "06-real-saved-thumbnail.png")
	_expect(host._save_presentation._view.get_ref() == host._prologue, "presentation service follows actual game view")
	host._on_prologue_return_to_title()
	_expect(host._save_presentation._slot.is_empty(), "returning to title stops gameplay clock")
	host.queue_free()
	await _frames()
	SaveManager.delete_test_slot(slot)

func _frames() -> void:
	for index in range(8): await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output + name + ".png")

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

func _expect(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
