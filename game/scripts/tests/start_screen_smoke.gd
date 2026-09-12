class_name StartScreenSmokeRunner
extends RefCounted

const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen.tscn")
const UI_ASSET_REGISTRY_PATH := "res://data/registries/ui_asset_registry.json"
const TEST_PROFILE_ROOT := "user://__test_start_screen_profile"
const CAPTURE_ARG := "--capture-start-screen"
const CAPTURE_OUTPUT_DIRECTORY := "../builds/validation"
const CAPTURE_INITIAL_FILE := "start_screen_1280x720.png"
const CAPTURE_FIRST_RUN_FILE := "start_screen_first_run_1280x720.png"
const CAPTURE_LARGE_TEXT_FILE := "start_screen_large_text_1280x720.png"
const TEST_BOOTSTRAP_SLOT := "__test_start_screen_bootstrap"
const EMPTY_SUMMARIES: Array[Dictionary] = [
	{"slot_id": "slot_01", "available": false},
	{"slot_id": "slot_02", "available": false},
	{"slot_id": "slot_03", "available": false},
]

var _errors := PackedStringArray()
var _profile_store := AccessibilityProfileStore.new(TEST_PROFILE_ROOT)
var _tree: SceneTree

class RejectAudioProfile extends AccessibilityProfileStore:
	func save_profile(_value: Dictionary) -> Dictionary:
		return {"ok": false}

class DisplayFixture extends RefCounted:
	var state := {"mode": "windowed", "width": 1280, "height": 720}
	var rejected := false
	func capture() -> Dictionary: return state.duplicate(true)
	func apply(value: Dictionary) -> bool:
		state = value.duplicate(true)
		return not rejected
	func restore(value: Dictionary) -> void: state = value.duplicate(true)


func _validate_display_settings(screen: StartScreen) -> void:
	var settings := preload("res://scripts/systems/display_settings.gd")
	var backend := DisplayFixture.new()
	var transaction := settings.Preview.new(backend, settings.validate)
	var initial := backend.state.duplicate(true)
	var candidate := {"mode": "borderless", "width": 1920, "height": 1080}
	_expect(transaction.begin(candidate, 1000), "display preview starts", _errors)
	_expect(not transaction.begin(candidate, 1001), "display duplicate preview blocked", _errors)
	_expect(not transaction.expire(15999) and transaction.pending, "display retains full 15 second window", _errors)
	_expect(transaction.expire(16000) and backend.state == initial, "display deadline restores snapshot", _errors)
	transaction.begin(candidate, 20000)
	_expect(not transaction.keep(35000) and backend.state == initial, "late display confirmation rejected", _errors)
	backend.rejected = true
	_expect(not transaction.begin(candidate, 40000) and backend.state == initial, "partially failed display apply restored", _errors)
	backend.rejected = false
	for bad: Variant in [null, true, [], {}, {"mode": "windowed", "width": 1, "height": 1}, {"mode": "windowed", "width": "1280", "height": 720}, {"mode": "windowed", "width": NAN, "height": 720}]:
		_expect(not settings.validate(bad), "malformed display rejected", _errors)
	var legacy := _profile_store.default_profile()
	legacy.erase("display")
	_expect(_profile_store.validate_profile(legacy).ok, "legacy display profile supported", _errors)
	var before := GameState.get_snapshot()
	screen._display_panel.preview = transaction
	screen._on_settings_pressed()
	screen._display_button.pressed.emit()
	await _tree.process_frame
	screen._display_panel.mode.select(0)
	screen._display_panel.resolution.select(1)
	screen._display_panel.apply.pressed.emit()
	_expect(transaction.pending and backend.state.width == 1600, "display panel previews selected size", _errors)
	_expect(not _profile_store.load_profile().profile.has("display") or int(_profile_store.load_profile().profile.display.width) != 1600, "unconfirmed display is not saved", _errors)
	screen._display_panel.back.pressed.emit()
	_expect(not transaction.pending and backend.state == initial, "display back restores previous window", _errors)
	screen._open_display_settings()
	screen._display_panel.mode.select(0)
	screen._display_panel.resolution.select(1)
	screen._display_panel.apply.pressed.emit()
	screen._display_panel.keep.pressed.emit()
	_expect(int(_profile_store.load_profile().profile.display.width) == 1600, "confirmed display saved", _errors)
	_expect(int(screen.get_display_settings().width) == 1600, "host keeps latest display profile", _errors)
	var rebuilt: Dictionary = screen._profile_from_controls(screen._settings_text_option, screen._settings_signature_option, screen._settings_motion_option, screen._settings_captions)
	_expect(int(rebuilt.display.width) == 1600, "ordinary settings retain display", _errors)
	screen._display_panel.resolution.select(2)
	screen._display_panel.apply.pressed.emit()
	screen._display_panel.profile_store = RejectAudioProfile.new()
	screen._display_panel.keep.pressed.emit()
	_expect(not transaction.pending and int(backend.state.width) == 1600, "display failed save restores confirmed size", _errors)
	_expect(int(_profile_store.load_profile().profile.display.width) == 1600, "display failed save leaves durable profile unchanged", _errors)
	screen._open_display_settings()
	screen._display_panel.mode.select(1)
	screen._display_panel.apply.pressed.emit()
	transaction.deadline_msec = Time.get_ticks_msec()
	screen._display_panel._process(0.0)
	_expect(not transaction.pending and int(backend.state.width) == 1600, "UI countdown timeout reverts", _errors)
	screen._display_panel.apply.pressed.emit()
	screen._close_modal()
	_expect(not transaction.pending, "closing display panel cancels preview", _errors)
	_expect(GameState.get_snapshot() == before, "display settings preserve game state", _errors)
	# Keep native capture fixtures at 1280x720; runtime behavior is tested separately.
	screen._profile["display"] = initial.duplicate()
	_profile_store.save_profile(screen._profile)
	screen._display_panel.preview = settings.Preview.new(settings.WindowBackend.new(screen.get_window()), settings.validate)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		var old_scale: float = screen._profile.text_scale
		screen._profile.text_scale = 2.0
		screen._apply_profile()
		screen._on_settings_pressed()
		await _tree.process_frame
		await _tree.process_frame
		await RenderingServer.frame_post_draw
		_capture_screen(screen, "general_settings_1280x720_200.png", "general_settings")
		screen._open_display_settings()
		await _tree.process_frame
		await _tree.process_frame
		await RenderingServer.frame_post_draw
		_capture_screen(screen, "display_settings_1280x720_200.png", "display_settings")
		screen._profile.text_scale = old_scale
		screen._apply_profile()
		screen._close_modal()


func _validate_key_settings(screen: StartScreen) -> void:
	var bindings := preload("res://scripts/systems/key_bindings.gd")
	var before := GameState.get_snapshot()
	var legacy := _profile_store.default_profile()
	legacy.erase("key_bindings")
	_expect(_profile_store.validate_profile(legacy).ok, "legacy bindings remain supported", _errors)
	for malformed: Variant in [null, true, [], {}, {"cancel": [KEY_ESCAPE]}]:
		_expect(not bindings.validate(malformed), "malformed binding structure rejected", _errors)
	for code: Variant in [true, "65", null, -1, 65.5, NAN, INF, KEY_SHIFT, KEY_CTRL]:
		var invalid := bindings.defaults()
		invalid.cancel = [code]
		_expect(not bindings.validate(invalid), "invalid key rejected before conversion", _errors)
	var duplicate := bindings.defaults()
	duplicate.cancel = duplicate.next.duplicate()
	_expect(not bindings.apply_bindings(duplicate), "invalid bindings cannot partially apply", _errors)
	screen._open_key_settings()
	await _tree.process_frame
	screen._key_panel.begin_capture("cancel")
	await _binding_key(KEY_TAB)
	_expect(screen._key_panel._capture == "cancel", "duplicate key capture rejected", _errors)
	await _binding_key(KEY_F8)
	_expect(screen._key_panel._capture.is_empty(), "new binding captured", _errors)
	_expect(InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_ESCAPE)), "draft does not replace applied input", _errors)
	screen._key_panel.apply.pressed.emit()
	_expect(InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_F8)), "saved cancel key applied", _errors)
	_expect(not InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_ESCAPE)), "old Escape removed", _errors)
	_expect("F8" in screen._menu_hint.text and "Escape" not in screen._menu_hint.text, "title hint displays current cancel binding", _errors)
	var loaded: Dictionary = AccessibilityProfileStore.new(TEST_PROFILE_ROOT).load_profile().profile
	_expect(int(loaded.key_bindings.cancel[0]) == KEY_F8, "new store reload retains binding", _errors)
	bindings.apply_bindings(bindings.defaults())
	screen.refresh_profile()
	_expect(InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_F8)), "profile refresh restores runtime binding", _errors)
	var controls_profile: Dictionary = screen._profile_from_controls(screen._settings_text_option, screen._settings_signature_option, screen._settings_motion_option, screen._settings_captions)
	_expect(controls_profile.key_bindings == loaded.key_bindings, "ordinary settings preserve bindings", _errors)
	screen._open_key_settings()
	screen._key_panel.begin_capture("next")
	await _binding_key(KEY_F9)
	screen._key_panel.begin_capture("previous")
	await _binding_key(KEY_F10)
	screen._key_panel.begin_capture("cancel")
	await _binding_key(KEY_ESCAPE)
	_expect(screen._key_panel._capture.is_empty(), "Escape assigned instead of closing panel", _errors)
	screen._profile_store = RejectAudioProfile.new()
	screen._key_panel.apply.pressed.emit()
	_expect(screen._active_modal() == screen._key_panel and InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_F8)), "failed save keeps old inputs and panel", _errors)
	screen._profile_store = _profile_store
	screen._key_panel.apply.pressed.emit()
	screen._open_key_settings()
	await _tree.process_frame
	screen._key_panel.buttons.confirm.grab_focus()
	await _binding_key(KEY_F9)
	_expect(screen.get_viewport().gui_get_focus_owner() == screen._key_panel.buttons.cancel, "rebound next navigates real GUI focus", _errors)
	await _binding_key(KEY_F10)
	_expect(screen.get_viewport().gui_get_focus_owner() == screen._key_panel.buttons.confirm, "rebound previous navigates real GUI focus", _errors)
	screen._key_panel.begin_capture("next")
	await _binding_key(KEY_TAB)
	screen._key_panel.begin_capture("previous")
	await _binding_key(KEY_TAB | KEY_MASK_SHIFT)
	_expect(int(screen._key_panel._draft.previous[0]) == (KEY_TAB | KEY_MASK_SHIFT), "Shift Tab captured with modifier", _errors)
	screen._key_panel.back.pressed.emit()
	screen._open_key_settings()
	_expect(int(screen._key_panel._draft.next[0]) == KEY_F9, "back discards draft", _errors)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		var scale_before: float = screen._profile.text_scale
		screen._profile.text_scale = 2.0
		screen._apply_profile()
		await _tree.process_frame
		await _tree.process_frame
		await RenderingServer.frame_post_draw
		_capture_screen(screen, "keyboard_settings_1280x720_200.png", "keyboard")
		screen._profile.text_scale = scale_before
		screen._apply_profile()
	screen._key_panel.restore.pressed.emit()
	screen._key_panel.apply.pressed.emit()
	_expect(InputMap.action_has_event("ui_cancel", preload("res://scripts/systems/key_bindings.gd").key_event(KEY_ESCAPE)), "restore defaults applied", _errors)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	_expect(InputMap.action_has_event("interact_confirm", mouse), "keyboard replacement preserves mouse", _errors)
	_expect(GameState.get_snapshot() == before, "key settings preserve game state", _errors)
	screen._close_modal()


func _binding_key(code: Key) -> void:
	var event := preload("res://scripts/systems/key_bindings.gd").key_event(code)
	event.pressed = true
	Input.parse_input_event(event)
	await _tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _tree.process_frame


func _validate_audio_settings(screen: StartScreen) -> void:
	await _validate_display_settings(screen)
	await _validate_key_settings(screen)
	var before := GameState.get_snapshot()
	for field in ["accessibility_profile_version", "text_scale", "signature_mode", "motion_mode"]:
		for bad_value in [true, null, [], {}, "1", NAN, INF, 1.9]:
			var malformed := _profile_store.default_profile()
			malformed[field] = bad_value
			var unchanged := malformed.duplicate(true)
			_expect(not _profile_store.validate_profile(malformed).ok, "profile rejects malformed " + field, _errors)
			if not (bad_value is float and is_nan(bad_value)):
				_expect(malformed == unchanged, "validation preserves malformed source", _errors)
	var json_profile: Variant = JSON.parse_string(JSON.stringify(_profile_store.default_profile()))
	_expect(_profile_store.validate_profile(json_profile).ok, "JSON numeric profile remains compatible", _errors)
	var legacy := _profile_store.default_profile()
	legacy.erase("audio")
	_expect(_profile_store.validate_profile(legacy).ok, "legacy profile accepts absent audio", _errors)
	var invalid := _profile_store.default_profile()
	invalid.audio.master = "0.5"
	_expect(not _profile_store.validate_profile(invalid).ok, "audio rejects numeric strings", _errors)
	invalid.audio.master = NAN
	_expect(not _profile_store.validate_profile(invalid).ok, "audio rejects NaN", _errors)
	screen._on_settings_pressed()
	screen._audio_button.pressed.emit()
	await _tree.process_frame
	_expect(screen._active_modal() == screen._audio_panel, "audio panel opens from settings", _errors)
	screen._audio_panel.sliders.master.value = 37
	screen._audio_panel.mute.button_pressed = true
	screen._audio_panel.back.pressed.emit()
	_expect(screen.get_audio_settings().master == 1.0, "audio cancel preserves profile", _errors)
	screen._open_audio_settings()
	screen._audio_panel.sliders.master.value = 37
	screen._audio_panel.sliders.effects.value = 0
	screen._audio_panel.mute.button_pressed = true
	screen._audio_panel.apply.pressed.emit()
	var loaded: Dictionary = _profile_store.load_profile().profile
	_expect(is_equal_approx(loaded.audio.master, 0.37) and loaded.audio.muted and loaded.audio.effects == 0.0, "audio saved and reloaded", _errors)
	var rebuilt: Dictionary = screen._profile_from_controls(screen._settings_text_option, screen._settings_signature_option, screen._settings_motion_option, screen._settings_captions)
	_expect(rebuilt.audio == loaded.audio, "accessibility edits retain audio", _errors)
	screen._open_audio_settings()
	screen._profile_store = RejectAudioProfile.new()
	screen._audio_panel.sliders.master.value = 99
	screen._audio_panel.apply.pressed.emit()
	_expect(screen._active_modal() == screen._audio_panel and not screen._audio_panel.error_label.text.is_empty(), "audio failed save stays open with error", _errors)
	_expect(screen.get_audio_settings() == loaded.audio, "audio failed save preserves applied values", _errors)
	screen._profile_store = _profile_store
	var old_locale: String = screen._locale
	screen._locale = "en-US"
	screen._open_audio_settings()
	_expect(screen._audio_panel.heading.text == "Audio settings", "English audio labels", _errors)
	_expect(screen._audio_panel.labels.master.text == "Master volume: 37%", "audio percentage shown", _errors)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		var scale_before: float = screen._profile.text_scale
		screen._profile.text_scale = 2.0
		screen._apply_profile()
		await _tree.process_frame
		await _tree.process_frame
		await RenderingServer.frame_post_draw
		_capture_screen(screen, "audio_settings_1280x720_200.png", "audio")
		screen._profile.text_scale = scale_before
		screen._apply_profile()
	screen._locale = old_locale
	screen._apply_audio_settings(AccessibilityProfileStore.DEFAULT_AUDIO.duplicate())
	screen._close_modal()
	_expect(GameState.get_snapshot() == before, "audio settings preserve game state", _errors)


func run(tree: SceneTree) -> Dictionary:
	_tree = tree
	_tree.root.size = Vector2i(1280, 720)
	_profile_store.delete_test_profile()
	var screen: StartScreen = START_SCREEN_SCENE.instantiate()
	var window_fixture := _profile_store.default_profile()
	window_fixture.display.mode = "windowed"
	_profile_store.save_profile(window_fixture)
	screen.configure_profile_store(_profile_store)
	var screen_parent: Node = _tree.current_scene if _tree.current_scene != null else _tree.root
	screen_parent.add_child(screen)
	await _tree.process_frame
	await _tree.process_frame
	screen.set_slot_summaries(EMPTY_SUMMARIES)
	await _tree.process_frame

	_validate_asset_registry(screen)
	_validate_initial_state(screen)
	await _validate_audio_settings(screen)
	await _validate_title_treatment(screen)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_capture_screen(screen, CAPTURE_INITIAL_FILE, "initial")
	await _validate_first_run(screen)
	await _validate_slot_modes(screen)
	await _validate_support_modals(screen)
	_validate_layout(screen)
	var gallery_before := GameState.get_snapshot()
	var gallery_locale: String = screen._locale
	screen._locale = "en-US"
	screen._apply_localized_text()
	screen._open_gallery()
	_expect(screen._gallery_button.text == screen._text(&"UI_TITLE_GALLERY"), "gallery entry button refreshes with title language", _errors)
	_expect(screen._active_modal() != null and screen._gallery_controls.visible, "title gallery opens", _errors)
	_expect(screen._gallery_previous.text == "Previous" and screen._gallery_next.text == "Next", "title gallery English navigation", _errors)
	if not screen._gallery_pages.is_empty():
		screen._show_gallery_page(0)
		var expected_pages: Array = preload("res://scripts/systems/ending_gallery_pages.gd").build(screen._gallery_entries[0]["state"],"en-US")
		_expect(screen._launch_body.text == expected_pages[0]["text"], "title gallery reads same English pages as post-ending gallery", _errors)
		if CAPTURE_ARG in OS.get_cmdline_user_args():
			var longest := 0
			for index in range(expected_pages.size()):
				if str(expected_pages[index]["text"]).length() > str(expected_pages[longest]["text"]).length(): longest = index
			screen._show_gallery_page(longest)
			await _tree.process_frame
			await RenderingServer.frame_post_draw
			_capture_screen(screen, "ending_gallery_english.png", "ending_gallery_english")
	else:
		_expect(screen._launch_title.text == "Viewing records" and screen._launch_body.text == screen.GALLERY_TEXTS.text("empty","en-US"), "empty title gallery is localized without inventing records", _errors)
	screen._locale = gallery_locale
	screen._apply_localized_text()
	screen._gallery_pages.assign([{"title":"긴 기록","text":"스크롤 확인\n".repeat(100)},{"title":"다음 기록","text":"처음부터 읽는다."}])
	screen._show_gallery_page(0)
	await _tree.process_frame
	await _tree.process_frame
	var before_scroll_focus: Control = screen._gallery_scroll.find_prev_valid_focus()
	before_scroll_focus.grab_focus()
	await _binding_key(KEY_TAB)
	_expect(_tree.root.gui_get_focus_owner() == screen._gallery_scroll, "Tab reaches gallery reading area", _errors)
	await _binding_key(KEY_PAGEDOWN)
	_expect(screen._gallery_scroll.scroll_vertical > 0, "keyboard PageDown scrolls long gallery record", _errors)
	await _binding_key(KEY_PAGEUP)
	_expect(screen._gallery_scroll.scroll_vertical == 0, "keyboard PageUp returns to the beginning", _errors)
	var keys_before: Dictionary = screen.get_key_bindings()
	var custom_gallery_keys: Dictionary = keys_before.duplicate(true)
	custom_gallery_keys["page_down"] = [KEY_F11 | KEY_MASK_CTRL]
	var binding_rules = preload("res://scripts/systems/key_bindings.gd")
	_expect(binding_rules.apply_bindings(custom_gallery_keys), "gallery custom page key installs", _errors)
	await _binding_key(KEY_PAGEDOWN)
	_expect(screen._gallery_scroll.scroll_vertical == 0, "replaced PageDown does not scroll", _errors)
	await _binding_key(KEY_F11 | KEY_MASK_CTRL)
	_expect(screen._gallery_scroll.scroll_vertical > 0, "gallery paging follows rebound input action", _errors)
	_expect(binding_rules.apply_bindings(keys_before), "restore gallery page keys", _errors)
	screen._gallery_scroll.scroll_vertical = 80
	screen._gallery_next.grab_focus()
	screen._show_gallery_page(1)
	_expect(screen._gallery_scroll.scroll_vertical == 0, "gallery page change resets scroll", _errors)
	_expect(_tree.root.gui_get_focus_owner() == screen._launch_return_button, "disabled gallery navigation restores focus", _errors)
	screen._on_settings_pressed()
	_expect(not screen._gallery_controls.visible, "other modal hides gallery controls", _errors)
	screen._close_modal()
	_expect(not screen._gallery_controls.visible and GameState.get_snapshot() == gallery_before, "title gallery leaves gameplay untouched", _errors)
	await _validate_bootstrap_handoff()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor",null)
	ProjectSettings.set_setting("ggb/build_flavor","demo")
	screen._open_demo_import()
	_expect(not screen._import_controls.visible, "demo cannot open full import", _errors)
	ProjectSettings.set_setting("ggb/build_flavor","full")
	screen._import_button.show()
	await _validate_title_treatment(screen)
	var import_state := GameState.get_snapshot()
	screen._open_demo_import()
	_expect(screen._import_controls.visible, "full title opens import confirmation", _errors)
	await _tree.process_frame
	_expect(_tree.root.gui_get_focus_owner() == screen._launch_return_button, "import defaults to cancel focus", _errors)
	screen._close_modal()
	_expect(GameState.get_snapshot() == import_state and not screen._import_controls.visible, "import cancellation preserves gameplay", _errors)
	var korean_locale := screen._locale
	screen._locale = "en-US"
	screen._open_demo_import()
	_expect(screen._launch_title.text == "Confirm demo save import", "English import confirmation title", _errors)
	_expect("[UI_" not in screen._launch_body.text and not screen._launch_body.text.is_empty(), "English import body resolves", _errors)
	_expect(screen._text(&"UI_IMPORT_SLOT", {"slot":"slot_01"}) == "Demo slot_01", "Import slot variable resolves in English", _errors)
	_expect(screen._text(&"UI_IMPORT_ERROR", {"error":"ERR_IMPORT_TEST"}).ends_with("\nERR_IMPORT_TEST"), "Import error identifier preserved", _errors)
	_expect("will not be overwritten" in screen._text(&"UI_IMPORT_BODY"), "English import preserves overwrite warning", _errors)
	screen._close_modal()
	screen._locale = korean_locale
	ProjectSettings.set_setting("ggb/build_flavor",old_flavor)

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
	var sidecar := SaveManager.get_save_root().path_join(TEST_BOOTSTRAP_SLOT).path_join("f3_reselect.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sidecar.get_base_dir()))
	for suffix in ["", ".tmp", ".bak"]:
		var file := FileAccess.open(sidecar + suffix, FileAccess.WRITE)
		file.store_string("old run fixture")
		file.close()
	bootstrap.call("_on_new_game_requested", TEST_BOOTSTRAP_SLOT)
	await _tree.process_frame
	var saved := SaveManager.load_slot(TEST_BOOTSTRAP_SLOT)
	_expect(bool(saved.get("ok", false)), "bootstrap new game did not create a valid save", _errors)
	_expect(String(saved.get("header", {}).get("save_point_id", "")) == "SAVE_NEW_GAME", "new-game save boundary mismatch", _errors)
	var initial_run: String = saved.get("header", {}).get("run_id", "")
	_expect(not initial_run.is_empty(), "new game assigns save lineage", _errors)
	SaveManager.save_snapshot(TEST_BOOTSTRAP_SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_NORMAL_SAVE")
	_expect(SaveManager.load_slot(TEST_BOOTSTRAP_SLOT)["header"].get("run_id") == initial_run, "normal save preserves lineage", _errors)
	SaveManager.save_snapshot(TEST_BOOTSTRAP_SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "NEW_GAME_TEST_OVERWRITE")
	_expect(SaveManager.load_slot(TEST_BOOTSTRAP_SLOT)["header"].get("run_id") != initial_run, "confirmed new game replaces lineage", _errors)
	for suffix in ["", ".tmp", ".bak"]:
		_expect(not FileAccess.file_exists(sidecar + suffix), "new game clears previous F3 sidecars", _errors)
	var stale := FileAccess.open(sidecar, FileAccess.WRITE)
	stale.store_string("leftover after failed cleanup")
	stale.close()
	_expect(SaveManager.load_f3_reselect(TEST_BOOTSTRAP_SLOT).get("error_id") == &"ERR_RESELECT_CURRENT_RUN", "current run guard blocks leftover F3 copy", _errors)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sidecar))
	var product_screen := bootstrap.get_node("%StartScreen") as StartScreen
	var prologue = bootstrap.get_node_or_null("Prologue")
	_expect(product_screen != null and not product_screen.visible, "new game did not hide the title screen", _errors)
	_expect(prologue != null, "new game did not launch the prologue scene", _errors)
	if prologue != null:
		_expect(String(prologue._resume_id) == "P1_ENTRY", "new-game prologue target mismatch", _errors)
	bootstrap.call("_on_prologue_return_to_title")
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
	prologue = bootstrap.get_node_or_null("Prologue")
	_expect(prologue != null, "load did not launch the prologue scene", _errors)
	if prologue != null:
		_expect("P1" in String(prologue._resume_id), "load prologue target mismatch", _errors)
	bootstrap.call("_on_prologue_return_to_title")
	await _tree.process_frame
	SaveManager.delete_test_slot(TEST_BOOTSTRAP_SLOT)
	GameState.reset_for_test()


func _capture_screen(screen: StartScreen, output_file: String, capture_name: String) -> void:
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
	var project_directory := ProjectSettings.globalize_path("res://")
	var absolute_directory := project_directory.path_join(CAPTURE_OUTPUT_DIRECTORY).simplify_path()
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	_expect(directory_error == OK, "start screen capture directory could not be created", _errors)
	if directory_error != OK:
		return
	var save_error := image.save_png(absolute_directory.path_join(output_file))
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
		if asset_id == "UI_TITLE":
			var expected_background := "res://assets/ui/title/ui_title_manor_background_v01.png"
			var background_path := String(entry.get("background_path", ""))
			_expect(background_path == expected_background, "title background registry path mismatch", _errors)
			_expect(ResourceLoader.exists(background_path), "registered title background is unavailable", _errors)
			_expect(String(entry.get("visual_revision", "")) == "gothic_manor_ui_v02", "title visual revision mismatch", _errors)
			var background := screen.get_node_or_null("%TitleBackground") as TextureRect
			_expect(background != null, "title background node is missing", _errors)
			if background != null:
				_expect(background.texture != null, "title background texture is missing", _errors)
				_expect(String(background.get_meta("asset_id", "")) == "UI_TITLE", "title background metadata mismatch", _errors)
				_expect(String(background.get_meta("resource_role", "")) == "background", "title background role mismatch", _errors)


func _validate_initial_state(screen: StartScreen) -> void:
	for node_name in ["ContinueButton", "NewGameButton", "LoadButton", "SettingsButton", "QuitButton"]:
		var button := screen.get_node("%%%s" % node_name) as Button
		_expect(button != null and not button.text.is_empty(), "main menu text missing: %s" % node_name, _errors)
		if button != null:
			_expect("ERR_TEXT" not in button.text, "main menu localization error: %s" % node_name, _errors)
	_expect((screen.get_node("%ContinueButton") as Button).disabled, "Continue must be disabled without saves", _errors)
	_expect((screen.get_node("%LoadButton") as Button).disabled, "Load must be disabled without saves", _errors)
	_expect(_tree.root.gui_get_focus_owner() == screen.get_node("%NewGameButton"), "New Game did not receive initial keyboard focus", _errors)
	_expect(not (screen.get_node("%MenuHeader") as Label).text.is_empty(), "menu header text is missing", _errors)
	_expect(not (screen.get_node("%MenuHint") as Label).text.is_empty(), "menu hint text is missing", _errors)
	var logo := screen.get_node("%Logo") as Label
	_expect((screen.get_node("%LogoGhostCyan") as Label).text == logo.text, "cyan logo layer mismatch", _errors)
	_expect((screen.get_node("%LogoGhostMagenta") as Label).text == logo.text, "magenta logo layer mismatch", _errors)


func _validate_title_treatment(screen: StartScreen) -> void:
	var expected_indices := ["01", "02", "03", "04", "05", "INFO"]
	var button_names := ["ContinueButton", "NewGameButton", "LoadButton", "SettingsButton", "QuitButton", "ContentButton"]
	for index in range(button_names.size()):
		var button := screen.get_node("%%%s" % button_names[index]) as GothicTitleButton
		_expect(button != null, "gothic button treatment is missing: %s" % button_names[index], _errors)
		if button != null:
			_expect(button.menu_index == expected_indices[index], "gothic button index mismatch: %s" % button_names[index], _errors)
	var original_profile: Dictionary = screen._profile.duplicate(true)
	screen._profile["text_scale"] = 2.0
	screen._apply_profile()
	await _tree.process_frame
	var new_game := screen.get_node("%NewGameButton") as GothicTitleButton
	_expect(new_game.get_theme_font_size("font_size") == 40, "main menu text did not scale to 200%", _errors)
	_expect(new_game.custom_minimum_size.y >= 76.0, "main menu hit target did not grow with text scale", _errors)
	var viewport_rect := Rect2(screen.global_position, screen.size)
	var menu_card := screen.get_node("SafeArea/MainLayout/MenuCard") as Control
	_expect(_rect_inside(menu_card.get_global_rect(), viewport_rect), "200% title menu overflow", _errors)
	for extra_button in [screen._gallery_button, screen._import_button]:
		if extra_button.is_visible_in_tree():
			_expect(_rect_inside(extra_button.get_global_rect(), menu_card.get_global_rect()), "200% extra menu button overflow: " + extra_button.text, _errors)
			extra_button.grab_focus()
			_expect(_tree.root.gui_get_focus_owner() == extra_button, "extra menu button cannot receive keyboard focus", _errors)
	var logo_stack := screen.get_node("%LogoStack") as Control
	_expect(_rect_inside(logo_stack.get_global_rect(), viewport_rect), "200% title logo overflow", _errors)
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_capture_screen(screen, CAPTURE_LARGE_TEXT_FILE, "large_text")
	screen._profile = original_profile
	screen._apply_profile()
	await _tree.process_frame


func _validate_first_run(screen: StartScreen) -> void:
	var retained := {"audio": screen.get_audio_settings(), "key_bindings": screen.get_key_bindings(), "display": screen.get_display_settings()}
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
		_capture_screen(screen, CAPTURE_FIRST_RUN_FILE, "first_run")
	(screen.get_node("%FirstDefaultButton") as Button).pressed.emit()
	await _tree.process_frame
	await _tree.process_frame
	var profile_result := _profile_store.load_profile()
	_expect(bool(profile_result.get("ok", false)), "first-run profile was not saved", _errors)
	_expect(bool(profile_result.get("profile", {}).get("first_run_complete", false)), "first-run completion was not persisted", _errors)
	for field: String in retained:
		var serialized: Variant = JSON.parse_string(JSON.stringify(retained[field]))
		_expect(profile_result.profile[field] == serialized, "first-run accessibility defaults preserve " + field, _errors)
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
