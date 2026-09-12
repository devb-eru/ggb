extends SceneTree

const Settings := preload("res://scripts/systems/display_settings.gd")
const DISPLAY_PANEL := preload("res://scripts/ui/display_settings_panel.gd")
const Store := preload("res://scripts/systems/accessibility_profile_store.gd")
const PROFILE := "user://__test_native_display"
var _errors := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("DISPLAY_NATIVE_SMOKE requires a native renderer")
		quit(1)
		return
	var store := Store.new(PROFILE)
	var backend := Settings.WindowBackend.new(root)
	if "--verify-display-restart" in OS.get_cmdline_user_args():
		var loaded := store.load_profile()
		_expect(loaded.get("source") == "primary", "read confirmed profile from previous process")
		_expect(backend.apply(loaded.profile.display), "apply confirmed display after process restart")
		await process_frame
		await process_frame
		_expect(root.mode == Window.MODE_FULLSCREEN, "restarted borderless mode")
		store.delete_test_profile()
		_finish()
		return
	store.delete_test_profile()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var initial := backend.capture()
	var panel := DISPLAY_PANEL.new()
	panel.profile_store = store
	root.add_child(panel)
	var theme := Theme.new()
	theme.default_font_size = 36
	panel.theme = theme
	panel.load_values({"mode": "windowed", "width": 1280, "height": 720}, "en-US")
	panel.show()
	panel.mode.select(1)
	panel._begin_preview()
	await process_frame
	await process_frame
	_expect(root.mode == Window.MODE_FULLSCREEN, "native borderless preview")
	_expect(panel.preview.pending and panel.revert.visible and panel.keep.visible, "confirmation controls visible")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://display_preview_200.png")
	await create_timer(15.2, true).timeout
	_expect(not panel.preview.pending, "real 15 second wall timeout")
	_expect(root.mode == initial.mode and root.size == initial.size, "native timeout restores mode and window size")
	_expect(store.load_profile().get("source") == "default", "timeout did not save preview")
	panel.mode.select(2)
	panel._begin_preview()
	await process_frame
	await process_frame
	_expect(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "native exclusive fullscreen preview")
	panel._revert()
	await process_frame
	_expect(root.mode == initial.mode, "exclusive fullscreen reverted")
	panel.mode.select(0)
	panel.resolution.select(4)
	if backend.available_size().x < 3840 or backend.available_size().y < 2160:
		panel._begin_preview()
		_expect(not panel.preview.pending, "unsupported 4K window rejected on smaller monitor")
		_expect(root.mode == initial.mode and root.size == initial.size, "unsupported size retains usable display")
	panel.mode.select(1)
	panel.resolution.select(0)
	panel._begin_preview()
	panel._keep()
	_expect(not panel.preview.pending and store.load_profile().profile.display.mode == "borderless", "native keep commits profile")
	panel.queue_free()
	await process_frame
	backend.restore(initial)
	_finish()

func _expect(condition: bool, label: String) -> void:
	if not condition: _errors.append(label)

func _finish() -> void:
	if _errors.is_empty():
		print("DISPLAY_NATIVE_SMOKE: PASS")
		quit(0)
	else:
		push_error("DISPLAY_NATIVE_SMOKE: FAIL " + str(_errors))
		quit(1)
