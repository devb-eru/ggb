extends "res://scripts/tests/notebook_prologue_presentation_smoke.gd"

const STORE := preload("res://scripts/systems/presentation_view_store.gd")
const ROOT := "user://__test_presentation_views"
const POSITION_FILE := "user://__test_presentation_position.json"


func run(tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	TranslationServer.set_locale("ko-KR")
	var phase := "seed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor-phase="): phase = arg.trim_prefix("--cursor-phase=")
	if phase == "seed":
		await _cases_view(tree)
		await _modal_positions(tree)
		await _other_positions(tree)
		var view = await _long_dialogue(tree)
		var tracker = view.get_node("PresentationViewTracker")
		view._dialogue_scroll.scroll_vertical = 250
		view._dialogue_scroll.grab_focus()
		tracker._process(0.01)
		_expect(tracker.flush(), "persistent seed position saved")
		var file := FileAccess.open(POSITION_FILE, FileAccess.WRITE)
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "view": tracker.saved, "state": GameState.get_snapshot()}))
		file.close()
		view.queue_free()
		await tree.process_frame
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POSITION_FILE))
		_expect(int(expected.pid) != OS.get_process_id(), "independent process")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "position fixture loaded")
		var view = _view(tree, SLOT)
		view.get_node("PresentationViewTracker").store.root = ROOT
		await _frames(tree, 6)
		if phase == "resume":
			_expect(view._dialogue_scroll.scroll_vertical == int(expected.view.scrolls["dialogue:body"].offset), "restart restores exact body offset")
			_expect(view._dialogue_scroll.has_focus(), "restart restores body focus")
			_expect(_same(expected.state, GameState.get_snapshot()), "restart writes neither game nor archive")
			view._advance_dialogue()
			await _frames(tree, 6)
			_expect(view._dialogue_scroll.scroll_vertical == 0, "new sentence does not inherit old scroll")
		else:
			_expect(view._dialogue_index == 1 and view._dialogue_scroll.scroll_vertical == 0, "new sentence resumes without old position")
			SaveManager.delete_test_slot(SLOT)
		view.queue_free()
		await tree.process_frame
	print("PRESENTATION_VIEW_CHECKS: ", phase, " ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _frames(tree: SceneTree, count: int) -> void:
	for index in range(count): await tree.process_frame


func _long_dialogue(tree: SceneTree) -> Node:
	var view = _fresh(tree)
	view.get_node("PresentationViewTracker").store.root = ROOT
	_drain(view)
	var context := {"node_id": "P1", "chapter_id": "PROLOGUE", "location_id": "M2_BEDROOM"}
	view._show_dialogue([
		{"speaker": "SYSTEM", "text": "긴 기록을 읽는 위치입니다. Reading position.\n".repeat(80), "history_context": context},
		{"speaker": "SYSTEM", "text": "다음 문장은 아직 읽지 않았습니다.", "history_context": context}])
	await _frames(tree, 6)
	return view


func _cases_view(tree: SceneTree) -> void:
	var view = await _long_dialogue(tree)
	var tracker = view.get_node("PresentationViewTracker")
	var before := GameState.get_snapshot()
	view._dialogue_scroll.scroll_vertical = 300
	view._dialogue_scroll.grab_focus()
	tracker._process(0.01)
	_expect(tracker.saved.scrolls["dialogue:body"].offset > 0, "long body is scrollable")
	_expect(tracker.flush() and _same(before, GameState.get_snapshot()), "sidecar save is gameplay read-only")
	var stored: Dictionary = tracker.saved.duplicate(true)
	var scope: Dictionary = tracker.scope.duplicate(true)
	var identity: String = tracker.identity
	var store = tracker.store
	_expect(store.load_view(scope, "f".repeat(64)).view.is_empty(), "different presentation cannot inherit position")
	var other := scope.duplicate(true)
	other.slot += "_other"
	_expect(store.load_view(other, identity).view.is_empty(), "different slot isolated")
	for field in ["profile", "namespace", "run_id", "source_origin_id", "branch_id"]:
		other = scope.duplicate(true)
		other[field] += "_other"
		_expect(store.load_view(other, identity).view.is_empty(), "different scope isolated: " + field)
	_expect(store.save_view(scope, identity, stored), "backup fixture saved")
	var original: Dictionary = store.load_view(scope, identity).view
	var files: Dictionary = store.paths(scope)
	var file := FileAccess.open(files.main, FileAccess.WRITE)
	file.store_string("damaged")
	file.close()
	_expect(store.load_view(scope, identity).view == original and original.scrolls["dialogue:body"].offset == stored.scrolls["dialogue:body"].offset, "damaged primary uses verified backup")
	file = FileAccess.open(files.backup, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 99}))
	file.close()
	_expect(not store.load_view(scope, identity).writable and not store.save_view(scope, identity, stored), "future backup protected from downgrade")
	DirAccess.remove_absolute(files.main)
	DirAccess.remove_absolute(files.backup)
	var invalid := stored.duplicate(true)
	invalid.scrolls["dialogue:body"].fraction = 2
	_expect(not STORE.valid_view(invalid), "invalid relative offset rejected")
	var original_root: String = store.root
	store.root = POSITION_FILE
	file = FileAccess.open(POSITION_FILE, FileAccess.WRITE)
	file.store_string("occupied")
	file.close()
	_expect(not tracker.flush() and tracker.warning and _same(before, GameState.get_snapshot()), "sidecar write failure does not touch game state")
	store.root = original_root
	_expect(tracker.flush() and not tracker.warning, "explicit convenience retry succeeds")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "external load fixture")
	_expect(not tracker.flush(), "old tracker cannot write after load")
	view.queue_free()
	await tree.process_frame
	view = _view(tree, SLOT)
	tracker = view.get_node("PresentationViewTracker")
	tracker.store.root = ROOT
	view._apply_reading_text_scale(2.0)
	await _frames(tree, 6)
	var bar: VScrollBar = view._dialogue_scroll.get_v_scroll_bar()
	var limit := maxf(0, bar.max_value - bar.page)
	_expect(absf(view._dialogue_scroll.scroll_vertical - float(stored.scrolls["dialogue:body"].fraction) * limit) <= 2, "changed text scale restores relative reading position")
	_expect(_same(before, GameState.get_snapshot()), "layout adaptation does not change gameplay")
	view.queue_free()
	await tree.process_frame
	view = _view(tree, SLOT)
	tracker = view.get_node("PresentationViewTracker")
	tracker.store.root = ROOT
	tracker._process(0)
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = true
	tracker._input(event)
	await _frames(tree, 5)
	_expect(view._dialogue_scroll.scroll_vertical == 0, "new input cancels deferred automatic scroll")
	view.queue_free()
	await tree.process_frame


func _modal_positions(tree: SceneTree) -> void:
	var helper := preload("res://scripts/tests/notebook_modal_presentation_smoke.gd").new()
	for spec in [["A1", 0, "_open_mark_choices"], ["C4", 1, "_open_patrol"], ["E_HUB", 2, "_show_j4_confirmation"], ["C3", 1, "_open_cleaner_quantity_table"]]:
		TranslationServer.set_locale("ko-KR")
		helper._seed(spec[0])
		var view = helper._view(tree, spec[1])
		view.get_node("PresentationViewTracker").store.root = ROOT
		view.call(spec[2])
		await _frames(tree, 6)
		var tracker = view.get_node("PresentationViewTracker")
		var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button and not child.disabled)
		_expect(not buttons.is_empty(), "modal has available focus " + spec[2])
		if buttons.is_empty():
			view.queue_free()
			await tree.process_frame
			continue
		buttons.back().grab_focus()
		tracker._process(0.01)
		var stored: Dictionary = tracker.saved.duplicate(true)
		_expect(not stored.is_empty() and not stored.focus.is_empty() and tracker.flush(), "modal focus saves without pressing button " + spec[2])
		var before := GameState.get_snapshot()
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(helper.SLOT).ok, "modal position disk load")
		TranslationServer.set_locale("en-US")
		view = helper._view(tree, spec[1])
		tracker = view.get_node("PresentationViewTracker")
		tracker.store.root = ROOT
		await _frames(tree, 6)
		_expect(tracker._capture(tracker._surface()).focus == stored.focus, "modal restores nonselected button focus " + spec[2])
		_expect(_same(before, GameState.get_snapshot()), "modal restoration executes no selection " + spec[2])
		view.queue_free()
		await tree.process_frame
	_expect(helper.errors.is_empty(), "all modal fixtures initialized")
	TranslationServer.set_locale("ko-KR")


func _other_positions(tree: SceneTree) -> void:
	for kind in ["choice", "window", "world"]:
		var view = _window_fresh(tree, 1) if kind == "window" else _fresh(tree)
		view.get_node("PresentationViewTracker").store.root = ROOT
		if kind != "window": _drain(view)
		if kind == "choice":
			_prepare(view, "P4")
			view._show_p4_father_choices()
		elif kind == "world":
			view._progress.P1_complete = true
			view._enter_room("M1_CENTRAL_HALL")
		await _frames(tree, 6)
		var tracker = view.get_node("PresentationViewTracker")
		var target: Control
		if kind == "choice": target = view._dialogue_choice_buttons[1]
		elif kind == "window": target = view._window_drop_targets.MIDDLE
		else:
			for control in tracker._surface().controls.values():
				if tracker._usable(control):
					target = control
					break
		_expect(target != null, "focus target exists " + kind)
		if target == null:
			view.queue_free()
			await tree.process_frame
			continue
		target.grab_focus()
		tracker._process(0.01)
		var focus: String = tracker.saved.focus
		_expect(not focus.is_empty() and tracker.flush(), "focus persisted " + kind)
		var before := GameState.get_snapshot()
		view = await _reload(tree, view)
		tracker = view.get_node("PresentationViewTracker")
		tracker.store.root = ROOT
		await _frames(tree, 6)
		_expect(tracker._capture(tracker._surface()).focus == focus, "restart focus restored " + kind)
		_expect(_same(before, GameState.get_snapshot()), "focus restore executes no gameplay " + kind)
		view.queue_free()
		await tree.process_frame
