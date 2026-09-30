extends RefCounted

var errors := PackedStringArray()

class DisplayFixture extends RefCounted:
	var state := {"mode": "windowed", "width": 1280, "height": 720}
	func capture() -> Dictionary: return state.duplicate(true)
	func apply(value: Dictionary) -> bool:
		state = value.duplicate(true)
		return true
	func restore(value: Dictionary) -> void: state = value.duplicate(true)

func run(app: Control) -> Dictionary:
	var tree := app.get_tree()
	await tree.create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		var original_mode := tree.root.mode
		tree.root.mode = Window.MODE_MINIMIZED
		await tree.create_timer(0.3, true).timeout
		_expect(tree.root.mode == Window.MODE_MINIMIZED, "native window is minimized")
		_expect(tree.paused and app._focus_suspended, "native minimization pauses even without a focus notification")
		tree.root.mode = original_mode
		tree.root.grab_focus()
		await tree.create_timer(0.4, true).timeout
		_expect(not tree.paused and not app._focus_suspended, "native window restoration resumes safely")
	app._start_screen._on_settings_pressed()
	await tree.process_frame
	var checkbox: CheckButton = app._start_screen._settings_captions
	var held := InputEventMouseButton.new()
	held.button_index = MOUSE_BUTTON_LEFT
	held.position = checkbox.get_global_rect().get_center()
	held.pressed = true
	Input.parse_input_event(held)
	await tree.process_frame
	var checked := checkbox.button_pressed
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.create_timer(0.2, true).timeout
	held = held.duplicate()
	held.pressed = false
	Input.parse_input_event(held)
	await tree.process_frame
	_expect(checkbox.button_pressed == checked, "stale mouse release cannot toggle a checkbox")
	app._start_screen._close_modal()
	SaveManager.delete_test_slot("__test_focus_pause")
	app._launch_prologue("__test_focus_pause", "P1_ENTRY")
	await tree.process_frame
	await tree.process_frame
	var game: Control = app._prologue
	_expect(game.process_mode == Node.PROCESS_MODE_PAUSABLE, "production gameplay is pausable")
	var timer := Timer.new()
	timer.wait_time = 10.0
	game.add_child(timer)
	timer.start()
	game._dialogue_next.grab_focus()
	var prior_focus: Control = tree.root.gui_get_focus_owner()
	var before := GameState.get_snapshot()
	game._dialogue_next.force_drag({"focus_test": true}, Label.new())
	_expect(tree.root.gui_is_dragging(), "native GUI drag begins")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not tree.root.gui_is_dragging(), "focus loss cancels GUI drag without dropping")
	var paused_time := timer.time_left
	_expect(tree.paused and app._focus_suspended, "application focus out pauses gameplay")
	await _key(tree, KEY_ENTER)
	await tree.create_timer(0.2, true).timeout
	_expect(is_equal_approx(timer.time_left, paused_time), "game timer remains frozen")
	_expect(GameState.get_snapshot() == before, "input while unfocused leaves progress untouched")
	var old_serial: int = app._focus_resume_serial
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(tree.paused, "focus return retains recovery pause")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._on_focus_recovery_timeout(old_serial)
	await tree.create_timer(0.2, true).timeout
	_expect(tree.paused and app._focus_suspended, "stale recovery cannot resume a later focus loss")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.create_timer(0.2, true).timeout
	_expect(not tree.paused and not app._focus_suspended, "latest focus return resumes after grace period")
	_expect(tree.root.gui_get_focus_owner() == prior_focus, "focus returns to gameplay not hidden title")
	await tree.process_frame
	_expect(timer.time_left < paused_time, "game timer resumes")
	# A release after refocusing must not finish a click that began before focus loss.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = game._dialogue_next.get_global_rect().get_center()
	press.pressed = true
	Input.parse_input_event(press)
	await tree.process_frame
	before = GameState.get_snapshot()
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.create_timer(0.2, true).timeout
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	await tree.process_frame
	_expect(GameState.get_snapshot() == before, "stale mouse release does not advance dialogue")
	game._dismiss_dialogue_for_test()
	game._open_menu()
	game._open_display_settings()
	await tree.process_frame
	var settings := preload("res://scripts/systems/display_settings.gd")
	var backend := DisplayFixture.new()
	var panel: Control = game._display_settings_panel
	var store := AccessibilityProfileStore.new("user://__test_focus_display")
	store.delete_test_profile()
	panel.profile_store = store
	panel.preview = settings.Preview.new(backend, settings.validate)
	panel.mode.select(0)
	panel.resolution.select(1)
	panel._begin_preview()
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	panel.keep.grab_focus()
	await _key(tree, KEY_ENTER)
	_expect(panel.preview.pending and store.load_profile().source == "default", "always-processing display UI cannot accept unfocused input")
	panel.preview.deadline_msec = Time.get_ticks_msec() + 50
	await tree.create_timer(0.1, true).timeout
	_expect(not panel.preview.pending and int(backend.state.width) == 1280, "display safety countdown still reverts while gameplay is paused")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.create_timer(0.2, true).timeout
	_expect(panel.is_ancestor_of(tree.root.gui_get_focus_owner()), "hidden previous control falls back inside active modal")
	game._close_modal()
	store.delete_test_profile()
	tree.paused = true
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.create_timer(0.2, true).timeout
	_expect(tree.paused, "preexisting pause is preserved")
	tree.paused = false
	app._on_prologue_return_to_title()
	await tree.process_frame
	SaveManager.delete_test_slot("__test_focus_pause")
	return {"ok": errors.is_empty(), "errors": errors}

func _key(tree: SceneTree, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame

func _expect(value: bool, label: String) -> void:
	if not value: errors.append(label)
