extends Node

# Run in a fresh, isolated APPDATA, one process per profile/engine-CLI combination:
# In an isolated project copy, register this LAST in [autoload], then launch the
# normal main scene with -- --display-startup-smoke [--display-startup-mode=...].
# A --script SceneTree changes main-scene timing and cannot detect this race.
# No mode argument exercises the missing-profile default (borderless). Engine
# --windowed/--fullscreen/--resolution/--position belong BEFORE the -- separator.
# Never repair the window here: only the real StartScreen._ready may apply display.
const Store := preload("res://scripts/systems/accessibility_profile_store.gd")
const RESULT_PATH := "user://__test_display_startup_result.json"
const MARKER := "DISPLAY_STARTUP_SMOKE"
const SLOT := "__test_display_startup_geometry"
const STABLE_MSEC := 1000
const SETTLE_TIMEOUT_MSEC := 8000

var _mode := "borderless"
var _profile_source := "default"
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _samples: Array[Dictionary] = []
var _geometry: Array[Dictionary] = []
var _ready_snapshot: Dictionary = {}
var _screen: Control
var _first_frame_seen := false
var _ready_before_first_frame := false
var _finished := false
var _geometry_started := false
var _initial_snapshot: Dictionary = {}
var root: Window
var current_scene: Node:
	get: return get_tree().current_scene


func _enter_tree() -> void:
	if not "--display-startup-smoke" in OS.get_cmdline_user_args(): return
	root = get_tree().root
	_initial_snapshot = _window_snapshot()
	if DisplayServer.get_name() == "headless":
		_check(false, "native_display_required", "headless cannot prove native startup")
		_finish("not_run")
		return
	var requested := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--display-startup-mode="):
			if not requested.is_empty():
				_check(false, "single_mode_argument", "duplicate mode argument")
			requested = arg.trim_prefix("--display-startup-mode=")
			_check(requested in ["windowed", "borderless", "fullscreen"], "valid_mode_argument", arg)
		elif arg.begins_with("--") and arg != "--display-startup-smoke":
			_check(false, "supported_user_argument", arg)
	if not _failures.is_empty():
		_finish("not_run")
		return
	# Use the product's DEFAULT_ROOT, not an injected store. Refuse existing data
	# rather than deleting a real profile or silently testing its backup instead.
	for filename in ["accessibility.json", "accessibility.bak.json", "accessibility.tmp.json"]:
		_check(not FileAccess.file_exists(Store.DEFAULT_ROOT.path_join(filename)),
			"fresh_profile_" + filename, "requires fresh isolated APPDATA")
	if not _failures.is_empty():
		_finish("not_run")
		return
	var store := Store.new()
	if not requested.is_empty():
		_mode = requested
		_profile_source = "primary"
		var profile := store.default_profile()
		profile.display = {"mode": _mode, "width": 1280, "height": 720}
		_check(bool(store.save_profile(profile).get("ok", false)), "prepare_profile_before_ready")
	var prepared := store.load_profile()
	_check(prepared.get("source") == _profile_source, "prepared_profile_source")
	_check(_matches_display(prepared.profile.display), "prepared_profile_values")
	if not _failures.is_empty():
		_finish("not_run")
		return
	get_tree().process_frame.connect(func() -> void: _first_frame_seen = true, CONNECT_ONE_SHOT)
	get_tree().node_added.connect(_watch_start_screen)
	var main_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main_path == "res://scenes/main/main.tscn", "real_main_scene_configured", main_path)
	# Let the engine itself load run/main_scene after autoload initialization.
	_run.call_deferred()


func _watch_start_screen(node: Node) -> void:
	if node.get_script() == null or node.get_script().resource_path != "res://scripts/ui/start_screen.gd":
		return
	_check(_screen == null, "single_real_start_screen")
	_screen = node as Control
	node.ready.connect(_observe_start_screen_ready, CONNECT_ONE_SHOT)


func _observe_start_screen_ready() -> void:
	_ready_before_first_frame = not _first_frame_seen
	_ready_snapshot = _window_snapshot()


func _run() -> void:
	get_tree().create_timer(25.0, true).timeout.connect(func() -> void:
		if not _finished:
			_check(false, "watchdog", "startup/geometry did not complete in 25 seconds")
			_finish("fail"))
	# SceneTree publishes current_scene only when its queued change completes.
	if not is_instance_valid(current_scene): await get_tree().scene_changed
	_check(is_instance_valid(current_scene), "real_main_instantiated")
	_check(is_instance_valid(_screen) and not _ready_snapshot.is_empty(), "real_start_screen_ready")
	_check(_ready_before_first_frame, "ready_precedes_first_process_frame",
		"late instantiation would bypass the startup override regression")
	if not is_instance_valid(current_scene) or not is_instance_valid(_screen) or not _ready_before_first_frame:
		_finish("fail")
		return
	_check(current_scene.get_node_or_null("StartScreen") == _screen, "main_owns_start_screen")
	_check(current_scene.is_node_ready() and current_scene.get_script().resource_path == "res://scripts/systems/bootstrap.gd", "real_main_bootstrap_ready")
	_check(_screen.is_visible_in_tree(), "startup_title_visible")
	_check(_matches_display(_screen.call("get_display_settings")), "real_start_screen_loaded_profile")
	var stable := await _wait_for_stable_window()
	_check(stable, "native_window_settled", "unchanged for >=1 second and >=12 frames; 8 second deadline")
	_verify_window("startup")
	for name in ["LogoStack", "ContinueButton", "NewGameButton", "LoadButton", "SettingsButton", "QuitButton", "ContentButton", "GalleryButton", "ImportButton"]:
		var control := _screen.get_node_or_null(NodePath("%" + name)) as Control
		if name == "ImportButton" and control != null and not control.is_visible_in_tree():
			continue # Product hides import in the demo build.
		_fit(control, "title/" + name)
	# Geometry must not mask a broken initial display by changing scene/window.
	if stable and _failures.is_empty():
		await _controller_geometry()
		_verify_window("after_geometry")
	_finish("pass" if _failures.is_empty() else "fail")


func _wait_for_stable_window() -> bool:
	var start := Time.get_ticks_msec()
	var unchanged_since := start
	var previous: Dictionary = {}
	var frames := 0
	while Time.get_ticks_msec() - start < SETTLE_TIMEOUT_MSEC:
		await get_tree().process_frame
		var sample := _window_snapshot()
		if sample != previous:
			_samples.append({"elapsed_msec": Time.get_ticks_msec() - start, "window": sample})
			previous = sample
			unchanged_since = Time.get_ticks_msec()
			frames = 0
		frames += 1
		if frames >= 12 and Time.get_ticks_msec() - unchanged_since >= STABLE_MSEC:
			return true
	return false


func _verify_window(phase: String) -> void:
	var screen_id := root.current_screen
	var origin := DisplayServer.screen_get_position(screen_id)
	var native_size := DisplayServer.screen_get_size(screen_id)
	var usable := DisplayServer.screen_get_usable_rect(screen_id)
	var expected_mode := Window.MODE_WINDOWED
	if _mode == "borderless": expected_mode = Window.MODE_FULLSCREEN
	elif _mode == "fullscreen": expected_mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	_check(root.mode == expected_mode, phase + "/mode", JSON.stringify(_window_snapshot()))
	_check(DisplayServer.window_get_mode(root.get_window_id()) == expected_mode, phase + "/native_mode")
	_check(root.size == DisplayServer.window_get_size(root.get_window_id()), phase + "/native_client_size_matches")
	_check(root.position == DisplayServer.window_get_position(root.get_window_id()), phase + "/native_position_matches")
	var client := Rect2(Vector2(root.position), Vector2(root.size))
	if _mode == "windowed":
		_check(root.size == Vector2i(1280, 720), phase + "/windowed_1280x720")
		_check(not root.borderless, phase + "/windowed_decorated")
		var center := usable.position + (usable.size - Vector2i(1280, 720)) / 2
		_check(Vector2(root.position - center).length() <= 2.0, phase + "/windowed_centered")
		_check(Rect2(usable).grow(2.0).encloses(client), phase + "/client_fits_usable_screen")
	else:
		_check(root.position == origin, phase + "/fullscreen_screen_origin", "actual=%s expected=%s" % [root.position, origin])
		_check(root.size == native_size, phase + "/fullscreen_native_size", "actual=%s expected=%s" % [root.size, native_size])
		_check(Rect2(Vector2(origin), Vector2(native_size)).grow(2.0).encloses(client), phase + "/client_fits_native_screen")
	_check(root.get_visible_rect().has_area(), phase + "/viewport_has_area")


func _controller_geometry() -> void:
	_geometry_started = true
	var checkpoints = load("res://scripts/systems/developer_checkpoints.gd").new()
	var fixture: Dictionary = checkpoints.snapshot_for("A1")
	_check(bool(fixture.get("ok", false)), "geometry/checkpoint_A1", str(fixture.get("error_ids", [])))
	if not fixture.get("ok", false): return
	var game := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	game.reset_for_test()
	var writer = load("res://scripts/systems/state_writer.gd").new(game)
	var installed: Dictionary = writer.install_snapshot(fixture.snapshot, game.revision, &"DISPLAY_STARTUP_GEOMETRY")
	_check(bool(installed.get("ok", false)), "geometry/install_checkpoint")
	if not installed.get("ok", false): return
	var view = load("res://scripts/chapters/chapter_one_controller.gd").new()
	view.configure_session(SLOT, "MORNING_ROUTE", true)
	_screen.hide()
	current_scene.add_child(view) # Real controller _ready builds its actual HUD.
	await get_tree().process_frame
	await get_tree().process_frame
	_fit(view._inventory_panel, "game/inventory_panel")
	_check(view._inventory_slots.size() == 6, "geometry/six_inventory_slots")
	for index in view._inventory_slots.size():
		_fit(view._inventory_slots[index], "game/inventory_slot_%d" % index)
	# Deliberate presentation setup, NOT an OS input/reachability assertion.
	view._show_dialogue([{"speaker": "SYSTEM", "text": "Native startup reading geometry."}])
	await get_tree().process_frame
	await get_tree().process_frame
	_fit(view._dialogue_layer, "game/reading_layer")
	_fit(view._dialogue_scroll, "game/reading_scroll")
	_fit(view._dialogue_next, "game/reading_advance")
	_fit(view._dialogue_history_button, "game/reading_history")
	_fit(view._menu_button, "game/menu")
	view.queue_free()
	await get_tree().process_frame
	saves.delete_test_slot(SLOT)
	_screen.show()


func _fit(control: Control, label: String) -> void:
	_check(is_instance_valid(control), label + "/exists")
	if not is_instance_valid(control): return
	var rect := control.get_global_rect()
	var viewport := root.get_visible_rect()
	var pixels := root.get_final_transform() * rect
	_geometry.append({"control": label, "global_rect": _rect(rect), "client_rect": _rect(pixels),
		"visible": control.is_visible_in_tree(), "viewport_rect": _rect(viewport)})
	_check(control.is_visible_in_tree(), label + "/visible")
	_check(rect.has_area(), label + "/positive_area")
	_check(viewport.grow(1.0).encloses(rect), label + "/global_rect_fits_viewport")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(2.0).encloses(pixels), label + "/fits_native_client")
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != root:
		if ancestor is Control and ancestor.clip_contents:
			_check(ancestor.get_global_rect().grow(1.0).encloses(rect), label + "/not_clipped_by_" + String(ancestor.name))
		ancestor = ancestor.get_parent()


func _window_snapshot() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"display_server": "headless", "native_observation": "not_run"}
	if root.get_window_id() < 0:
		return {"native_observation":"window_not_created"}
	var screen_id := root.current_screen
	return {"mode": root.mode, "position": _vec(root.position), "size": _vec(root.size),
		"borderless": root.borderless, "screen": screen_id,
		"native_mode": DisplayServer.window_get_mode(root.get_window_id()),
		"native_position": _vec(DisplayServer.window_get_position(root.get_window_id())),
		"native_client_size": _vec(DisplayServer.window_get_size(root.get_window_id())),
		"screen_origin": _vec(DisplayServer.screen_get_position(screen_id)),
		"screen_native_size": _vec(DisplayServer.screen_get_size(screen_id)),
		"screen_usable_rect": _rect(Rect2(DisplayServer.screen_get_usable_rect(screen_id)))}


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]


func _matches_display(value: Variant) -> bool:
	return preload("res://scripts/systems/display_settings.gd").validate(value) \
		and value.mode == _mode and int(value.width) == 1280 and int(value.height) == 720


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks.append({"name": label, "ok": ok, "detail": detail})
	if not ok: _failures.append(label + (": " + detail if not detail.is_empty() else ""))


func _finish(status: String) -> void:
	if _finished: return
	_finished = true
	var result := {"test": MARKER, "status": status, "ok": status == "pass",
		"requested_mode": _mode, "profile_source": _profile_source,
		"display_server": DisplayServer.get_name(), "engine": Engine.get_version_info(),
		"engine_args": Array(OS.get_cmdline_args()), "user_args": Array(OS.get_cmdline_user_args()),
		"user_data_dir": OS.get_user_data_dir(), "result_path": RESULT_PATH,
		"checks": _checks, "check_count": _checks.size(), "failures": _failures,
		"initial_window": _initial_snapshot, "ready_window": _ready_snapshot,
		"ready_before_first_process_frame": _ready_before_first_frame,
		"final_window": _window_snapshot(), "startup_transitions": _samples,
		"controller_geometry": "run" if _geometry_started else "not_run", "geometry": _geometry,
		"os_input": "not_run: direct presentation setup is geometry evidence only"}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "write_result_json", str(FileAccess.get_open_error()))
		result.status = "fail"
		result.ok = false
		result.checks = _checks
		result.check_count = _checks.size()
		result.failures = _failures
	else:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print(MARKER + "_RESULT_JSON: " + JSON.stringify(result))
	print(MARKER + ": " + String(result.status).to_upper())
	get_tree().quit(0 if result.ok else (2 if result.status == "not_run" else 1))
