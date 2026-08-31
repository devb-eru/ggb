class_name StartScreenSmokeRunner
extends RefCounted

const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen.tscn")
const UI_ASSET_REGISTRY_PATH := "res://data/registries/ui_asset_registry.json"
const TEST_PROFILE_ROOT := "user://__test_start_screen_profile"
const CAPTURE_ARG := "--capture-start-screen"
const CAPTURE_INITIAL_PATH := "res://../builds/validation/start_screen_1280x720.png"
const CAPTURE_FIRST_RUN_PATH := "res://../builds/validation/start_screen_first_run_1280x720.png"
const TEST_BOOTSTRAP_SLOT := "__test_start_screen_bootstrap"
const EMPTY_SUMMARIES: Array[Dictionary] = [
	{"slot_id": "slot_01", "available": false},
	{"slot_id": "slot_02", "available": false},
	{"slot_id": "slot_03", "available": false},
]

var _errors := PackedStringArray()
var _profile_store := AccessibilityProfileStore.new(TEST_PROFILE_ROOT)
var _tree: SceneTree


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_tree.root.size = Vector2i(1280, 720)
	_profile_store.delete_test_profile()
	var screen: StartScreen = START_SCREEN_SCENE.instantiate()
	screen.configure_profile_store(_profile_store)
	var screen_parent: Node = _tree.current_scene if _tree.current_scene != null else _tree.root
	screen_parent.add_child(screen)
	await _tree.process_frame
	await _tree.process_frame
	screen.set_slot_summaries(EMPTY_SUMMARIES)
	await _tree.process_frame

	_validate_asset_registry(screen)
	_validate_initial_state(screen)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_capture_screen(screen, CAPTURE_INITIAL_PATH, "initial")
	await _validate_first_run(screen)
	await _validate_slot_modes(screen)
	await _validate_support_modals(screen)
	_validate_layout(screen)
	await _validate_bootstrap_handoff()

	screen.queue_free()
	await _tree.process_frame
	_profile_store.delete_test_profile()
	return {"ok": _errors.is_empty(), "errors": _errors}


func _validate_bootstrap_handoff() -> void:
	SaveManager.delete_test_slot(TEST_BOOTSTRAP_SLOT)
	GameState.reset_for_test()
	var bootstrap := _tree.current_scene
	_expect(bootstrap != null and bootstrap.has_method("_on_new_game_requested"), "title bootstrap is unavailable", _errors)
	if bootstrap == null or not bootstrap.has_method("_on_new_game_requested"):
		return
	bootstrap.call("_on_new_game_requested", TEST_BOOTSTRAP_SLOT)
	await _tree.process_frame
	var saved := SaveManager.load_slot(TEST_BOOTSTRAP_SLOT)
	_expect(bool(saved.get("ok", false)), "bootstrap new game did not create a valid save", _errors)
	_expect(String(saved.get("header", {}).get("save_point_id", "")) == "SAVE_NEW_GAME", "new-game save boundary mismatch", _errors)
	var product_screen := bootstrap.get_node("%StartScreen") as StartScreen
	_expect(product_screen != null and (product_screen.get_node("%LaunchPanel") as Control).visible, "new game did not open the P1 handoff", _errors)
	if product_screen != null:
		_expect("P1_ENTRY" in (product_screen.get_node("%LaunchBody") as Label).text, "new-game handoff target mismatch", _errors)
		(product_screen.get_node("%LaunchReturnButton") as Button).pressed.emit()
	await _tree.process_frame

	var writer := StateWriter.new(GameState)
	var mutate_result := writer.commit_atomic(
		[{"state_path": "meta_progress.journal_stage", "operation": "set", "value": 2}],
		GameState.revision,
		&"TEST_TITLE_LOAD_MUTATION"
	)
	_expect(bool(mutate_result.get("ok", false)), "load handoff fixture mutation failed", _errors)
	bootstrap.call("_on_load_game_requested", TEST_BOOTSTRAP_SLOT)
	await _tree.process_frame
	_expect(int(GameState.get_value(&"meta_progress.journal_stage", -1)) == 0, "bootstrap load did not install the saved snapshot", _errors)
	if product_screen != null:
		_expect((product_screen.get_node("%LaunchPanel") as Control).visible, "load did not open the resume handoff", _errors)
		_expect("P1" in (product_screen.get_node("%LaunchBody") as Label).text, "load handoff target mismatch", _errors)
		(product_screen.get_node("%LaunchReturnButton") as Button).pressed.emit()
	SaveManager.delete_test_slot(TEST_BOOTSTRAP_SLOT)
	GameState.reset_for_test()


func _capture_screen(screen: StartScreen, output_path: String, capture_name: String) -> void:
	var viewport_texture := screen.get_viewport().get_texture()
	_expect(viewport_texture != null, "start screen capture is unavailable for the active display driver", _errors)
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	_expect(image != null and not image.is_empty(), "start screen capture returned an empty image", _errors)
	if image == null or image.is_empty():
		return
	print(
		"START_SCREEN_CAPTURE_METRICS name=%s window=%s scene=%s screen=%s image=%s menu=%s buttons=%s"
		% [
			capture_name,
			_tree.root.size,
			(_tree.current_scene as Control).size if _tree.current_scene is Control else Vector2.ZERO,
			screen.size,
			image.get_size(),
			(screen.get_node("SafeArea/MainLayout/MenuCard") as Control).get_global_rect(),
			[
				(screen.get_node("%ContinueButton") as Control).get_global_rect(),
				(screen.get_node("%NewGameButton") as Control).get_global_rect(),
				(screen.get_node("%LoadButton") as Control).get_global_rect(),
				(screen.get_node("%SettingsButton") as Control).get_global_rect(),
				(screen.get_node("%QuitButton") as Control).get_global_rect(),
			],
		]
	)
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var absolute_directory := ProjectSettings.globalize_path("res://../builds/validation")
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	_expect(directory_error == OK, "start screen capture directory could not be created", _errors)
	if directory_error != OK:
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	_expect(save_error == OK, "start screen capture could not be saved", _errors)


func _validate_asset_registry(screen: StartScreen) -> void:
	var registry_file := FileAccess.open(UI_ASSET_REGISTRY_PATH, FileAccess.READ)
	_expect(registry_file != null, "UI asset registry could not be opened", _errors)
	if registry_file == null:
		return
	var parsed: Variant = JSON.parse_string(registry_file.get_as_text())
	registry_file.close()
	_expect(parsed is Dictionary, "UI asset registry is not a dictionary", _errors)
	if not parsed is Dictionary:
		return
	var assets: Dictionary = parsed.get("assets", {})
	for asset_id in ["UI_TITLE", "UI_FIRST_RUN_ACCESS", "UI_SETTINGS", "UI_SAVE_SLOTS"]:
		_expect(assets.has(asset_id), "missing UI asset registry ID: %s" % asset_id, _errors)
		if not assets.has(asset_id):
			continue
		var entry: Dictionary = assets[asset_id]
		_expect(String(entry.get("scene_path", "")) == "res://scenes/ui/start_screen.tscn", "scene mismatch: %s" % asset_id, _errors)
		var node_path := String(entry.get("node_path", ""))
		var node: Node = screen if node_path == "." else screen.get_node_or_null(node_path)
		_expect(node != null, "registered UI asset node missing: %s" % asset_id, _errors)
		if node != null:
			_expect(String(node.get_meta("asset_id", "")) == asset_id, "asset metadata mismatch: %s" % asset_id, _errors)
			_expect(bool(node.get_meta("is_placeholder", false)), "placeholder marker missing: %s" % asset_id, _errors)


func _validate_initial_state(screen: StartScreen) -> void:
	for node_name in ["ContinueButton", "NewGameButton", "LoadButton", "SettingsButton", "QuitButton"]:
		var button := screen.get_node("%%%s" % node_name) as Button
		_expect(button != null and not button.text.is_empty(), "main menu text missing: %s" % node_name, _errors)
		if button != null:
			_expect("ERR_TEXT" not in button.text, "main menu localization error: %s" % node_name, _errors)
	_expect((screen.get_node("%ContinueButton") as Button).disabled, "Continue must be disabled without saves", _errors)
	_expect((screen.get_node("%LoadButton") as Button).disabled, "Load must be disabled without saves", _errors)
	_expect(_tree.root.gui_get_focus_owner() == screen.get_node("%NewGameButton"), "New Game did not receive initial keyboard focus", _errors)


func _validate_first_run(screen: StartScreen) -> void:
	(screen.get_node("%NewGameButton") as Button).pressed.emit()
	await _tree.process_frame
	var panel := screen.get_node("%FirstRunPanel") as Control
	_expect(panel.visible, "first-run accessibility panel did not open", _errors)
	_expect(_tree.root.gui_get_focus_owner() == screen.get_node("%FirstTextOption"), "first-run panel focus target mismatch", _errors)
	_expect((screen.get_node("%FirstTextOption") as OptionButton).item_count == 4, "text scale presets mismatch", _errors)
	_expect((screen.get_node("%FirstSignatureOption") as OptionButton).item_count == 3, "signature presets mismatch", _errors)
	_expect((screen.get_node("%FirstMotionOption") as OptionButton).item_count == 3, "motion presets mismatch", _errors)
	_expect((screen.get_node("%FirstCaptions") as CheckButton).button_pressed, "captions must default to enabled", _errors)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_capture_screen(screen, CAPTURE_FIRST_RUN_PATH, "first_run")
	(screen.get_node("%FirstDefaultButton") as Button).pressed.emit()
	await _tree.process_frame
	await _tree.process_frame
	var profile_result := _profile_store.load_profile()
	_expect(bool(profile_result.get("ok", false)), "first-run profile was not saved", _errors)
	_expect(bool(profile_result.get("profile", {}).get("first_run_complete", false)), "first-run completion was not persisted", _errors)
	_expect((screen.get_node("%SlotPanel") as Control).visible, "new-game slot panel did not open after first-run setup", _errors)


func _validate_slot_modes(screen: StartScreen) -> void:
	var requested_new_slots: Array[String] = []
	var requested_load_slots: Array[String] = []
	screen.new_game_requested.connect(func(slot_id: String) -> void: requested_new_slots.append(slot_id))
	screen.load_game_requested.connect(func(slot_id: String) -> void: requested_load_slots.append(slot_id))
	for index in range(1, 4):
		_expect(not (screen.get_node("%%SlotButton%d" % index) as Button).disabled, "empty new-game slot is disabled: %d" % index, _errors)
	(screen.get_node("%SlotButton1") as Button).pressed.emit()
	await _tree.process_frame
	_expect(requested_new_slots == ["slot_01"], "new-game slot signal mismatch", _errors)

	screen.set_slot_summaries([
		{
			"slot_id": "slot_01",
			"available": true,
			"updated_at_utc": 100,
			"day_index": 2,
			"location_id": "M1_LIBRARY_OUTER",
		},
		{"slot_id": "slot_02", "available": false},
		{"slot_id": "slot_03", "available": false},
	])
	_expect(not (screen.get_node("%ContinueButton") as Button).disabled, "Continue stayed disabled with a valid save", _errors)
	_expect(not (screen.get_node("%LoadButton") as Button).disabled, "Load stayed disabled with a valid save", _errors)
	(screen.get_node("%LoadButton") as Button).pressed.emit()
	await _tree.process_frame
	_expect((screen.get_node("%SlotPanel") as Control).visible, "load slot panel did not open", _errors)
	_expect(not (screen.get_node("%SlotButton1") as Button).disabled, "valid load slot is disabled", _errors)
	_expect((screen.get_node("%SlotButton2") as Button).disabled, "empty load slot is enabled", _errors)
	_expect((screen.get_node("%SlotButton3") as Button).disabled, "empty load slot is enabled", _errors)
	(screen.get_node("%SlotButton1") as Button).pressed.emit()
	await _tree.process_frame
	_expect(requested_load_slots == ["slot_01"], "load slot signal mismatch", _errors)
	(screen.get_node("%ContinueButton") as Button).pressed.emit()
	await _tree.process_frame
	_expect(requested_load_slots == ["slot_01", "slot_01"], "Continue did not select the latest save", _errors)


func _validate_support_modals(screen: StartScreen) -> void:
	(screen.get_node("%SettingsButton") as Button).pressed.emit()
	await _tree.process_frame
	_expect((screen.get_node("%SettingsPanel") as Control).visible, "Settings panel did not open", _errors)
	_close_with_cancel(screen)
	await _tree.process_frame
	(screen.get_node("%ContentButton") as Button).pressed.emit()
	await _tree.process_frame
	_expect((screen.get_node("%ContentPanel") as Control).visible, "Content Details panel did not open", _errors)
	_expect(not (screen.get_node("%ContentBody") as Label).text.is_empty(), "Content Details body is empty", _errors)
	_close_with_cancel(screen)
	await _tree.process_frame
	(screen.get_node("%QuitButton") as Button).pressed.emit()
	await _tree.process_frame
	_expect((screen.get_node("%QuitPanel") as Control).visible, "Quit confirmation did not open", _errors)
	(screen.get_node("%QuitCancelButton") as Button).pressed.emit()
	await _tree.process_frame


func _close_with_cancel(screen: StartScreen) -> void:
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	screen._unhandled_input(cancel_event)


func _validate_layout(screen: StartScreen) -> void:
	_expect(_tree.root.size == Vector2i(1280, 720), "minimum physical window size was not applied", _errors)
	_expect(is_equal_approx(screen.size.aspect(), 16.0 / 9.0), "start screen logical aspect ratio is not 16:9", _errors)
	var viewport_rect := Rect2(screen.global_position, screen.size)
	for node_path in [
		"SafeArea/MainLayout/MenuCard",
		"SafeArea/MainLayout/MenuCard/MenuMargin/Menu/NewGameButton",
		"SafeArea/MainLayout/MenuCard/MenuMargin/Menu/QuitButton",
	]:
		var control := screen.get_node(node_path) as Control
		_expect(control != null and _rect_inside(control.get_global_rect(), viewport_rect), "1280x720 layout overflow: %s" % node_path, _errors)
	for panel_name in ["SlotPanel", "FirstRunPanel", "SettingsPanel", "ContentPanel", "QuitPanel", "OverwritePanel", "LaunchPanel"]:
		var panel := screen.get_node("%%%s" % panel_name) as Control
		_expect(panel != null and _rect_inside(panel.get_global_rect(), viewport_rect), "1280x720 modal overflow: %s" % panel_name, _errors)


func _rect_inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - 0.5 \
		and rect.position.y >= bounds.position.y - 0.5 \
		and rect.end.x <= bounds.end.x + 0.5 \
		and rect.end.y <= bounds.end.y + 0.5


func _expect(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(message)
