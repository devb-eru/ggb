extends RefCounted

const PROLOGUE := preload("res://scenes/prologue/prologue.tscn")
const CAMPAIGN := preload("res://scripts/chapters/basement_controller.gd")
const CHAPTER := preload("res://scripts/chapters/chapter_one_controller.gd")
const MIRROR := preload("res://scripts/chapters/black_mirror_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const VIEW_STORE := preload("res://scripts/systems/notebook_view_store.gd")
const SLOT := "__test_notebook_host"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class FailedViewStore extends "res://scripts/systems/notebook_view_store.gd":
	func save_view(_scope: Dictionary, _frontier: Dictionary, _state: Dictionary) -> Dictionary:
		return {"ok": false, "error_id": "NB_VIEW_TEST_FAILURE"}

class ControlledSave extends Node:
	var delegate: Node
	var reject := false
	var lose_ack := false
	var transactions: Array[String] = []
	func get_build_flavor() -> String:
		return delegate.get_build_flavor()
	func inspect_slot(slot: String) -> Dictionary:
		return delegate.inspect_slot(slot)
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		transactions.append(transaction)
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_HOST_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_HOST_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await _prologue(tree)
	await _view_preferences(tree)
	await _campaign(tree)
	await _deferred_tools(tree)
	await _visual_materials(tree)
	await _physical(tree)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	print("NOTEBOOK_HOST_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors, "not_covered": ["OS_IME", "native_mouse_keyboard_completion", "app_restart_gameplay_cursor"]}


func _deferred_tools(tree: SceneTree) -> void:
	for tool_id in ["CleanerQuantityTable", "ClockHintsButton"]:
		for boundary in ["live", "reload", "slot", "session", "reopen", "menu"]:
			var view = await _campaign_view(tree, "C3")
			view._open_notebook()
			var tool := view._notebook_host.panel.find_child(tool_id, true, false) as Button
			_expect(tool != null, "deferred tool is exposed: " + tool_id)
			var generation: int = view._choice_modal_generation
			if tool != null: tool.pressed.emit()
			_expect(not view._notebook_is_open() and not view._modal_active, "tool closes notebook before deferred dispatch: " + boundary)
			match boundary:
				"reload": _expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload between tool request and dispatch")
				"slot": view._slot_id = "__test_notebook_other_slot"
				"session": view.session = view._make_session()
				"reopen": view._open_notebook()
				"menu": view._open_menu()
			var before := GameState.get_snapshot()
			await tree.process_frame
			await tree.process_frame
			if boundary == "live":
				_expect(view._modal_active and view._choice_modal_generation == generation + 1, "live tool executes exactly once: " + tool_id)
			elif boundary == "menu":
				_expect(view._modal_active and view._choice_modal_generation == generation + 1 and view._modal_body.get_child(0).text == view._dialogue_ui_text("UI_P_MENU"), "deferred tool cannot replace a newer menu: " + tool_id)
			else:
				_expect(not view._modal_active and view._choice_modal_generation == generation, "stale tool cannot open or replace a surface: " + tool_id + " / " + boundary)
			if boundary == "reopen": _expect(view._notebook_is_open(), "older tool cannot replace the newly opened notebook")
			_expect(GameState.get_snapshot() == before, "tool dispatch neither reveals a hint nor mutates gameplay: " + boundary)
			view.queue_free()
			await tree.process_frame
			await tree.process_frame


func _view_preferences(tree: SceneTree) -> void:
	var view = await _campaign_view(tree, "C3")
	var before := GameState.get_snapshot()
	var disk_before: Dictionary = SaveManager.load_slot(SLOT).snapshot
	view._open_notebook()
	var host = view._notebook_host
	_expect(host.model.investigation_available() and host.model._investigation == "C3", "actual cleaner controller supplies current investigation")
	var store = host.view_store
	var scope: Dictionary = host._view_scope.duplicate(true)
	var frontier: Dictionary = host.model.view_frontier()
	var files: Dictionary = store.paths(scope)
	var rows: Dictionary = host.model.page({"tab": "clues"}, 0, host.model.cache_key())
	_expect(not rows.items.is_empty(), "actual notebook has public clue materials")
	if rows.items.is_empty():
		view._close_modal()
		view.queue_free()
		await tree.process_frame
		return
	var clue: String = rows.items[0].key
	host.panel.show_detail(clue)
	await tree.process_frame
	view._close_modal()
	await tree.process_frame
	var initial: Dictionary = store.load_view(scope, frontier)
	_expect(initial.source == "primary" and initial.state.general.selected == clue and clue in initial.state.seen, "host close flushes selected card and its read state to a real scoped sidecar")
	_expect(GameState.get_snapshot() == before and StateSnapshotValidator.same_persisted_value(SaveManager.load_slot(SLOT).snapshot, disk_before), "reading and preference writes change neither runtime nor saved gameplay")
	view._open_dialogue_history()
	host = view._notebook_host
	_expect(host.panel._selected == host.model.latest_dialogue_key(), "first actual history-menu entry opens last line of latest session")
	rows = host.model.page({"tab": "dialogue"}, 0, host.model.cache_key())
	_expect(not rows.items.is_empty(), "actual history has session lines")
	var line: String = rows.items[0].key
	host.panel.show_detail(line)
	view._close_modal()
	await tree.process_frame
	var both: Dictionary = store.load_view(scope, frontier)
	_expect(both.state.dialogue.selected == line and StateSnapshotValidator.same_persisted_value(both.state.general, initial.state.general), "history entry keeps an independent last-view cursor")
	view._open_dialogue_history()
	host = view._notebook_host
	for frame in range(8): await tree.process_frame
	_expect(host.panel._selected == line and host.panel._seen.has(line), "reopening actual history restores its own stable line and badge")
	host.panel.set_filters({"tab": "clues"})
	host.panel.show_detail(clue)
	view._close_modal()
	await tree.process_frame
	var after_history: Dictionary = store.load_view(scope, frontier)
	_expect(StateSnapshotValidator.same_persisted_value(after_history.state.general, initial.state.general) and after_history.state.dialogue.selected == line, "visiting another tab from history cannot overwrite general or dialogue entry state")
	view._open_notebook()
	host = view._notebook_host
	for frame in range(8): await tree.process_frame
	_expect(host.panel._selected == clue and host.panel._filters.tab == "clues" and host.panel._seen.has(clue), "N entry restores general material after history-menu use")
	view._close_modal()
	await tree.process_frame
	view.queue_free()
	await tree.process_frame
	var loaded := SaveManager.load_slot(SLOT)
	var epoch := GameState.load_epoch
	_expect(loaded.ok and StateWriter.new(GameState).install_snapshot(loaded.snapshot, GameState.revision, &"LOAD_NB_VIEW_TEST").ok and GameState.load_epoch > epoch, "real slot reload installs snapshot with a new runtime epoch")
	view = MIRROR.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	_drain(view)
	before = GameState.get_snapshot()
	disk_before = SaveManager.load_slot(SLOT).snapshot
	view._open_notebook()
	host = view._notebook_host
	for frame in range(8): await tree.process_frame
	_expect(host._view_scope == scope and host.panel._selected == clue and host.panel._seen.has(clue), "fresh controller and load epoch retain same-run UI preferences")
	_expect(GameState.get_snapshot() == before, "restoring read state cannot grant knowledge or first-reveal effects")
	var persisted := FileAccess.get_file_as_bytes(files.main)
	host.view_store = FailedViewStore.new()
	host.panel.show_detail(clue)
	_expect(not host._flush_view() and not host.panel._notice.text.is_empty(), "preference write failure is visible and non-blocking")
	view._close_modal()
	await tree.process_frame
	_expect(view.visible and not view._notebook_is_open() and FileAccess.get_file_as_bytes(files.main) == persisted, "failed sidecar write restores world and keeps last valid preferences")
	_expect(GameState.get_snapshot() == before and StateSnapshotValidator.same_persisted_value(SaveManager.load_slot(SLOT).snapshot, disk_before), "sidecar failure never rewrites gameplay save")
	view._open_notebook()
	host = view._notebook_host
	for frame in range(8): await tree.process_frame
	host.panel.show_detail(clue)
	persisted = FileAccess.get_file_as_bytes(files.main)
	GameState.load_epoch += 1
	host._process(0.0)
	_expect(FileAccess.get_file_as_bytes(files.main) == persisted and not view.visible, "invalidated live scope cannot flush pending UI data or resume old controller")
	view.queue_free()
	await tree.process_frame
	for path in files.values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _prologue(tree: SceneTree) -> void:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var view := PROLOGUE.instantiate()
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	view.configure_session(SLOT, "P1_ENTRY", false)
	tree.current_scene.add_child(view)
	await tree.process_frame
	_expect(view._dialogue_active and view._unified_notebook_enabled(), "actual v2 prologue is speaking")
	var before := GameState.get_snapshot()
	var lines: Array = view._dialogue_lines.duplicate(true)
	var index: int = view._dialogue_index
	view._fade.show()
	view._open_notebook()
	_expect(not view._notebook_is_open() and GameState.get_snapshot() == before, "transition barrier refuses opening without queuing a stale request")
	view._fade.hide()
	var recorded_index: int = view._prologue_history_index
	view._prologue_history_index = -1
	view._open_notebook()
	_expect(not view._notebook_is_open() and GameState.get_snapshot() == before, "unsaved displayed line must be persisted before suspension")
	view._prologue_history_index = recorded_index
	view._dialogue_next.grab_focus()
	view._notebook_button.pressed.emit()
	var host = view._notebook_host
	_expect(is_instance_valid(host), "mouse notebook entry opens during dialogue")
	if not is_instance_valid(host):
		view.queue_free()
		await tree.process_frame
		return
	await tree.process_frame
	_expect(view.process_mode == Node.PROCESS_MODE_DISABLED and not view.visible, "world input and inherited timers suspended")
	_expect(not tree.paused and host.panel.is_visible_in_tree(), "notebook remains usable without changing application pause state")
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == before and view._dialogue_index == index and view._dialogue_lines == lines, "readonly overlay neither advances nor rerecords dialogue")
	_expect(host.panel._tools.get_child_count() == 0, "gameplay hint and quantity actions unavailable over active dialogue")
	var clue_rows: Dictionary = host.model.page({"tab": "clues"}, 0, host.model.cache_key())
	var raw_notes: Array = clue_rows.items.filter(func(row: Dictionary) -> bool: return row.kind == "legacy_note")
	_expect(not raw_notes.is_empty(), "actual old notebook strings join the same host even during dialogue")
	if not raw_notes.is_empty():
		var raw: Dictionary = host.model.detail(raw_notes[0].key, host.model.cache_key())
		_expect(raw.text in before.meta_progress.knowledge_entries.prologue_notebook_entries, "host passes canonical original strings without regenerating them")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	host._input(wheel)
	_expect(host._held.is_empty(), "wheel pulses have no release and cannot hold notebook closure hostage")
	view._close_modal()
	_expect(view.visible and view.process_mode == Node.PROCESS_MODE_PAUSABLE and not view._notebook_is_open(), "close restores original world immediately when no input held")
	_expect(view.get_viewport().gui_get_focus_owner() == view._dialogue_next, "exact speaking control focus restored")
	await tree.process_frame
	_expect(GameState.get_snapshot() == before, "close has no history or gameplay side effect")
	view._dialogue_next.pressed.emit()
	_expect(view._dialogue_index != index or not view._dialogue_active, "original dialogue can continue after close")
	_drain(view)
	view._open_dialogue_history()
	host = view._notebook_host
	_expect(host.panel._filters.tab == "dialogue", "menu history shares host with dialogue entry tab")
	var rows: Dictionary = host.model.page({"tab": "dialogue"}, 0, host.model.cache_key())
	_expect(rows.count >= 3, "actual shown lines available in integrated history")
	if rows.count >= 3: await _commands(tree, host, rows.items.slice(0, 3))
	clue_rows = host.model.page({"tab": "clues"}, 0, host.model.cache_key())
	raw_notes = clue_rows.items.filter(func(row: Dictionary) -> bool: return row.kind == "legacy_note")
	if not raw_notes.is_empty():
		var note_row: Dictionary = raw_notes[0]
		var prior: Dictionary = GameState.get_snapshot()
		host.panel.set_filters({"tab": "clues"})
		host.panel.show_detail(note_row.key)
		host.panel.find_child("NotebookReference_comparison", true, false).pressed.emit()
		_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.size() == prior.meta_progress.dialogue_history.entries.size() + 1, "host captures exactly one raw value when adding it to comparison")
		_expect(host.panel._selected == note_row.key and host.model.detail(note_row.key, host.model.cache_key()).note_snapshot, "refresh keeps the selected raw card and shows durable original status")
		_expect(host.model.page({"tab": "clues"}, 0, host.model.cache_key()).count == clue_rows.count, "materialization never duplicates current raw note in host list")
	view._close_modal()
	await tree.process_frame
	view._enter_room("M1_LIBRARY_OUTER")
	_drain(view)
	view._on_shelf_item_dropped("BOOK_MECHANICAL", "SHELF_CLOCK")
	_drain(view)
	_expect(view._dialogue_choice_active, "actual P3 choice reached")
	before = GameState.get_snapshot()
	var choice: Dictionary = view._choice_history_context.duplicate(true)
	view._unhandled_input(_key(KEY_N, true))
	host = view._notebook_host
	_expect(is_instance_valid(host), "N opens during actual P3 choice")
	view._on_dialogue_choice_pressed(0)
	_expect(GameState.get_snapshot() == before and view._choice_history_context == choice, "underlying choice callback cannot execute while notebook open")
	if is_instance_valid(host):
		host._input(_key(KEY_F10, true))
		host.release_pending_inputs()
		_expect(host._held.is_empty(), "external suspension discards held inputs whose releases it cannot observe")
		host.panel._search.grab_focus()
		host._unhandled_input(_key(KEY_N, true))
		_expect(view._notebook_is_open() and not host._closing, "typing N in search is not a close shortcut")
		host.panel._search.text = "example"
		host.panel._search_input(_key(KEY_ESCAPE, true))
		_expect(host.panel._search.text.is_empty() and host.panel._close.has_focus() and not host._closing, "Esc first cancels search editing without closing notebook or underlying choice")
		host.panel._close.grab_focus()
		host._input(_key(KEY_ENTER, true))
		host.request_close()
		_expect(view._notebook_is_open() and not view.visible, "close waits for held accept release")
		host._input(_key(KEY_ENTER, false))
		host._process(0.0)
		_expect(not view._notebook_is_open() and view._dialogue_choice_active, "release restores same unanswered choices")
	await tree.process_frame
	_expect(GameState.get_snapshot() == before and view._choice_history_context == choice, "close does not cancel or recreate a choice")
	view._on_dialogue_choice_pressed(0)
	_expect(GameState.get_snapshot() != before, "the original choice works after resumption")
	view.queue_free()
	await tree.process_frame


func _commands(tree: SceneTree, host, rows: Array) -> void:
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	host.saves = controlled
	var before := GameState.get_snapshot()
	host.panel.show_detail(rows[0].key)
	controlled.reject = true
	host.panel.find_child("NotebookReference_bookmarks", true, false).pressed.emit()
	var token: String = host.pending.command_id
	_expect(GameState.get_snapshot() == before and not host.pending.is_empty(), "failed bookmark save rolls back to original archive")
	_expect(host.panel.find_child("NotebookCommandCancel", true, false).has_focus(), "failed save defaults to cancellation")
	controlled.reject = false
	controlled.lose_ack = true
	host.panel.find_child("NotebookCommandConfirm", true, false).pressed.emit()
	_expect(host.pending.is_empty() and GameState.get_snapshot().meta_progress.dialogue_history.bookmarks.size() == 1, "lost acknowledgement recovered by exact committed payload")
	_expect(controlled.transactions.size() == 2 and controlled.transactions[0] == controlled.transactions[1] and controlled.transactions[0].ends_with(token), "retry preserves command identity")
	_expect(host.panel._selected == rows[0].key and host.panel._filters.tab == "dialogue", "metadata commit preserves selected material and tab")
	controlled.lose_ack = false
	for row in rows:
		host.panel.show_detail(row.key)
		host.panel.find_child("NotebookReference_comparison", true, false).pressed.emit()
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.comparison.size() == 3, "basket can hold more than displayed pair")
	host.panel.select_pair(0, rows[0].key)
	host.panel.select_pair(1, rows[2].key)
	_expect(host.panel.visible_pair() == [rows[0].key, rows[2].key], "two chosen materials displayed from larger basket")
	host.panel.select_pair(0, rows[2].key)
	_expect(host.panel.visible_pair() == [rows[2].key, rows[0].key], "choosing occupied side swaps pair instead of duplicating")
	var after := GameState.get_snapshot()
	var gameplay := after.duplicate(true)
	gameplay.meta_progress.dialogue_history = before.meta_progress.dialogue_history
	_expect(StateSnapshotValidator.same_persisted_value(gameplay, before), "only archive metadata changes, never puzzle state or knowledge")
	host.panel.show_detail(rows[0].key)
	host.panel.find_child("NotebookReference_bookmarks", true, false).pressed.emit()
	_expect(GameState.get_snapshot() == after, "unpin first asks for pruning confirmation")
	host.panel.find_child("NotebookCommandCancel", true, false).pressed.emit()
	_expect(host.pending.is_empty() and GameState.get_snapshot() == after, "cancelled unpin remains protected")
	host.panel.set_filters({"tab": "dialogue", "bookmarks_only": true})
	host.panel.show_detail(rows[0].key)
	host.panel.find_child("NotebookReference_bookmarks", true, false).pressed.emit()
	host.panel.find_child("NotebookCommandConfirm", true, false).pressed.emit()
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.bookmarks.is_empty(), "confirmed unpin saved")
	_expect(host.panel._selected.is_empty() and not host.panel._detail_visible, "removing the last filtered item returns to a usable empty list")
	host.panel.set_filters({"tab": "dialogue"})
	# Another writer's revision must never be adopted automatically on retry.
	var installed := StateWriter.new(GameState).install_snapshot(GameState.get_snapshot(), GameState.revision, &"NB_HOST_EXTERNAL_REVISION")
	_expect(installed.ok, "external revision fixture valid")
	after = GameState.get_snapshot()
	var revision := GameState.revision
	host._request_reference("bookmarks", rows[1].reference, true)
	_expect(not host.pending.is_empty() and GameState.revision == revision and GameState.get_snapshot() == after, "stale command cannot write against a newer revision")
	host.refresh()
	_expect(host.pending.is_empty(), "explicit refresh discards stale pending command")
	await tree.process_frame
	var controls: Array[Control] = []
	host.panel._collect_focus(host.panel, controls)
	host.panel._cycle_focus()
	for control in controls:
		_expect(control.get_node(control.focus_next) in controls and control.get_node(control.focus_previous) in controls, "Tab focus stays inside visible notebook controls")
	host.saves = SaveManager
	controlled.free()


func _campaign(tree: SceneTree) -> void:
	var view = await _campaign_view(tree, "A1")
	view._open_mark_choices()
	var request: Dictionary = view._recorded_modal_request
	var before := GameState.get_snapshot()
	view._open_notebook()
	var host = view._notebook_host
	_expect(is_instance_valid(host), "campaign choice can be suspended")
	view._recorded_choice_pressed(request, 0)
	_expect(GameState.get_snapshot() == before and view._recorded_modal_request == request, "typed modal retains its original context without submitting")
	view._close_modal()
	_expect(view._modal_active and view._recorded_modal_request == request and view._recorded_choice_live(request), "close restores original modal generation and callbacks")
	await tree.process_frame
	view._close_modal()
	# The same inherited Timer is used by B2; do not replace or restart it.
	view._edgar_timer.start(6.0)
	view._open_notebook()
	host = view._notebook_host
	var remaining: float = view._edgar_timer.time_left
	await tree.create_timer(0.15).timeout
	_expect(is_equal_approx(remaining, view._edgar_timer.time_left), "Edgar countdown frozen by notebook controller suspension")
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(not view._edgar_timer.paused and view.process_mode == Node.PROCESS_MODE_DISABLED, "focus recovery does not clear notebook pause")
	view._edgar_timer.paused = true
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(view._edgar_timer.paused, "focus recovery preserves an independently paused timer")
	view._close_modal()
	view._edgar_timer.paused = false
	await tree.create_timer(0.15).timeout
	_expect(view._edgar_timer.time_left < remaining, "original timer resumes without restarting its six seconds")
	view.queue_free()
	await tree.process_frame
	await _pause_points(tree)
	view = await _campaign_view(tree, "C3")
	view._open_notebook()
	host = view._notebook_host
	_expect(host.panel.find_child("CleanerQuantityTable", true, false) != null and host.panel.find_child("ClockHintsButton", true, false) != null, "quantity helper and explicit hint request retained as separate tools")
	before = GameState.get_snapshot()
	var quantity = host.panel.find_child("CleanerQuantityTable", true, false)
	if quantity != null: quantity.pressed.emit()
	else: view._close_modal()
	await tree.process_frame
	_expect(not view._notebook_is_open() and view._modal_active, "quantity tool exits readonly overlay and opens existing helper")
	_expect(GameState.get_snapshot().loop_state == before.loop_state, "opening helper does not decide puzzle")
	view._close_modal()
	view._open_notebook()
	host = view._notebook_host
	view.queue_free()
	await tree.process_frame
	await tree.process_frame
	_expect(not is_instance_valid(host) or host.is_queued_for_deletion(), "destroying a controller invalidates and removes its notebook")
	view = await _campaign_view(tree, "EDC")
	view._confirm_ending("reality")
	request = view._recorded_modal_request
	view._open_notebook()
	host = view._notebook_host
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(view._notebook_is_open() and view._recorded_modal_request == request and GameState.get_snapshot().ending_run.final_decision == "unset", "focus loss while reading does not submit or dismiss ending confirmation")
	view._close_modal()
	await tree.process_frame
	view._close_modal()
	view._open_notebook()
	host = view._notebook_host
	var stale_key: String = host.model.cache_key()
	GameState.load_epoch += 1
	host._process(0.0)
	_expect(not host.model.diagnostics().ready and not host.panel.visible and not view.visible, "load epoch change clears notebook without resuming stale controller")
	_expect(not host.model.page({"tab": "dialogue"}, 0, stale_key).ok, "stale query rejected after invalidation")
	view.queue_free()
	await tree.process_frame


func _pause_points(tree: SceneTree) -> void:
	var view = await _campaign_view(tree, "B2")
	# Use the real B2 visit and hiding route, not only a manually started timer.
	for room in ["M1_CENTRAL_HALL", "M1_LIBRARY_OUTER", "M1_LIBRARY_INNER"]:
		if view.session.snapshot().loop_state.location_id == room: continue
		view._do("move", room)
		_drain(view)
	for object in ["alcove", "index", "drawer"]:
		view._do("inspect_inner", object)
		_drain(view)
	view._do("edgar_hide")
	_drain(view)
	_expect(view.session.local_state().edgar_state == "hidden", "actual B2 hiding route reached")
	var before := GameState.get_snapshot()
	var remaining: float = view._edgar_timer.time_left
	view._open_notebook()
	await tree.create_timer(0.2).timeout
	_expect(GameState.get_snapshot() == before and is_equal_approx(view._edgar_timer.time_left, remaining), "actual B2 visit neither advances nor restarts while notebook open")
	view._close_modal()
	await tree.create_timer(0.15).timeout
	_expect(view._edgar_timer.time_left < remaining and view.session.local_state().edgar_state == "hidden", "actual B2 hiding resumes at remaining time")
	view.queue_free()
	await tree.process_frame
	view = await _campaign_view(tree, "E_HUB")
	view._show_j4_confirmation()
	_expect(view._modal_active, "J4 confirmation actually opens")
	var button: Button = view._modal_body.get_child(4)
	view._open_notebook()
	before = GameState.get_snapshot()
	await tree.create_timer(0.6).timeout
	_expect(button.disabled and GameState.get_snapshot() == before, "J4 accept delay cannot elapse behind notebook")
	view._close_modal()
	await tree.create_timer(0.6).timeout
	_expect(not button.disabled and view._modal_active and GameState.get_snapshot() == before, "J4 delay resumes without selecting confirmation")
	view.queue_free()
	await tree.process_frame
	view = await _campaign_view(tree, "D5")
	view._d5_hold_active = true
	view._open_notebook()
	_expect(not view._notebook_is_open(), "D5 mandatory observation cannot be interrupted by notebook entry")
	view._d5_hold_active = false
	view._d6_sleep_transition_active = true
	view._open_notebook()
	_expect(not view._notebook_is_open(), "D6 sleep transition cannot be interrupted by notebook entry")
	view._d6_sleep_transition_active = false
	view.queue_free()
	await tree.process_frame


func _physical(tree: SceneTree) -> void:
	var view = await _campaign_view(tree, "EDR_FIELD_NOTEBOOK")
	view._open_notebook()
	_expect(not view._notebook_is_open() and view._modal_active, "reality N still opens distinct physical notebook")
	view._close_modal()
	view._open_dialogue_history()
	_expect(view._notebook_is_open(), "history menu in reality still accesses captured observations")
	view._close_modal()
	view.queue_free()
	await tree.process_frame


func _visual_materials(tree: SceneTree) -> void:
	var view = await _campaign_view(tree, "F0_C")
	view._do("f0c", {"action": "rotate", "layer": "B4"}, false)
	view._do("f0c", {"action": "flip", "layer": "C5"}, false)
	view._do("f0c", {"action": "anchor", "layer": "D4", "value": 1}, false)
	_drain(view)
	for frame in range(5): await tree.process_frame
	var before := GameState.get_snapshot()
	var local: Dictionary = before.loop_state.event_local_states.F0_C.duplicate(true)
	_expect(not local.locked and local.B4.turn == 1 and local.C5.flip and local.D4.anchor == 1, "actual core puzzle has an unverified rotation, reflection and anchor draft")
	var lines: Array = view._dialogue_lines.duplicate(true)
	var line_index: int = view._dialogue_index
	view._dialogue_lines = [{"history_context": {"node_id": "F0_B"}}]
	view._dialogue_index = 0
	view._dialogue_active = true
	_expect(view._notebook_context_node() == "F0_B" and view.session.stage() == "F0_C", "displayed source context takes precedence over an advanced session stage")
	view._dialogue_lines = [{}]
	_expect(view._notebook_context_node().is_empty(), "unclassified active line does not infer the next investigation")
	view._dialogue_lines = lines
	view._dialogue_index = line_index
	view._dialogue_active = false
	view._open_notebook()
	var host = view._notebook_host
	_expect(is_instance_valid(host), "notebook opens over the actual pending overlay board")
	if not is_instance_valid(host):
		view.queue_free()
		await tree.process_frame
		return
	var query = host.model
	_expect(query._investigation == "F0_C", "actual overlay context is frozen in notebook model")
	var related: Dictionary = query.investigation_page(0, query.cache_key())
	_expect(related.count >= 3, "actual displayed overlay layers are available through current materials")
	var old_filters: Dictionary = host.panel._filters.duplicate(true)
	host.panel._open_browser("investigation")
	if not related.items.is_empty():
		host.panel._browser.material_selected.emit(related.items[0].key)
		_expect(host.panel._filters == old_filters and GameState.get_snapshot() == before, "actual related navigation does not alter filters or pending puzzle")
		host.panel._back()
		for frame in range(3): await tree.process_frame
	else: host.panel._close_browser()
	var materials: Array = []
	for index in range(query.page({"tab": "records"}, 0, query.cache_key()).pages):
		for item in query.page({"tab": "records"}, index, query.cache_key()).items:
			if query.detail(item.key, query.cache_key()).has_visual: materials.append(item.key)
	_expect(materials.size() >= 3, "actual displayed layer producers supply three notebook visuals")
	if not materials.is_empty():
		host.panel.show_detail(materials[0])
		host.panel._open_visual(materials[0])
		_expect(host.panel._visual.visible, "actual observed layer enlarges from live notebook")
		host.panel._visual.find_child("NotebookVisualIn", true, false).pressed.emit()
		host.panel._visual.find_child("NotebookVisualDown", true, false).pressed.emit()
		view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_expect(host.panel._visual.visible and GameState.get_snapshot() == before, "visual inspection and focus loss never verify or alter pending puzzle input")
		host.panel._close_visual()
	view._close_modal()
	await tree.process_frame
	_expect(view.visible and view.session.stage() == "F0_C" and view.session.snapshot().loop_state.event_local_states.F0_C == local, "closing notebook restores exactly the same unverified overlay draft")
	_expect(GameState.get_snapshot() == before, "returning from visual replay neither rerecords board nor advances gameplay")
	view.queue_free()
	await tree.process_frame


func _campaign_view(tree: SceneTree, checkpoint: String):
	SaveManager.delete_test_slot(SLOT)
	var loaded := CHECKPOINTS.new().snapshot_for(checkpoint)
	_expect(loaded.ok, "valid checkpoint: " + checkpoint)
	var state: Dictionary = loaded.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	GameState.reset_for_test()
	serial += 1
	var transaction := "NB_HOST_FIXTURE_%d" % serial
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName(transaction)).ok, "install checkpoint: " + checkpoint)
	var view
	if state.meta_progress.journal_stage < 2: view = CHAPTER.new()
	elif state.meta_progress.journal_stage < 3: view = MIRROR.new()
	else: view = CAMPAIGN.new()
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	_drain(view)
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", GameState.get_snapshot(), GameState.revision, transaction + "_SAVE").ok, "persist checkpoint run scope: " + checkpoint)
	return view


func _drain(view: Node) -> void:
	for index in range(100):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false, "dialogue failed to drain")


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_HOST_FAIL: ", message)
