extends CanvasLayer

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")

var game: Node
var saves: Node
var panel
var model := QUERY.new()
var pending: Dictionary = {}
var _controller: WeakRef
var _focus: WeakRef
var _scope: Dictionary = {}
var _command_scope := ""
var _revision := -1
var _checked_revision := -1
var _slot := ""
var _mode := Node.PROCESS_MODE_INHERIT
var _visible := true
var _audio_paused := false
var _closing := false
var _invalid := false
var _held: Dictionary = {}
var _after_close := Callable()
var _entry_tab := "clues"
var _suspended := false


func begin(controller: Control, game_state: Node, save_service: Node, tab: String) -> bool:
	game = game_state
	saves = save_service
	_controller = weakref(controller)
	_slot = controller._slot_id
	_entry_tab = tab
	_scope = _current_scope()
	_command_scope = COMMANDS.scope(game, saves, _slot)
	_revision = game.revision
	_checked_revision = _revision
	var state: Dictionary = game.get_snapshot()
	var opened := model.open(state.meta_progress.dialogue_history, state.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), _scope, TranslationServer.get_locale())
	if not opened.ok: return false
	layer = 40
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var root := ColorRect.new()
	root.color = Color(0.025, 0.02, 0.04, 0.99)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	root.add_child(margin)
	panel = PANEL.new()
	panel.name = "IntegratedNotebook"
	margin.add_child(panel)
	panel.close_requested.connect(request_close)
	panel.reference_requested.connect(_request_reference)
	panel.refresh_requested.connect(refresh)
	_mode = controller.process_mode
	_visible = controller.visible
	_audio_paused = controller._menu_audio_paused
	var focused := controller.get_viewport().gui_get_focus_owner()
	_focus = weakref(focused) if focused != null else null
	_clear_pressed(controller)
	if get_viewport().has_method("gui_cancel_drag"): get_viewport().call("gui_cancel_drag")
	controller.hide()
	controller.process_mode = Node.PROCESS_MODE_DISABLED
	controller.menu_audio_pause_requested.emit(true)
	_suspended = true
	panel.present(model, TranslationServer.get_locale(), tab, controller._reading_text_scale)
	panel.set_reference_editable(true)
	for tool in controller._notebook_tools():
		panel.add_tool(tool.label, _leave_for_tool.bind(tool.action), tool.id)
	return true


func request_close() -> void:
	if _closing: return
	_closing = true
	get_viewport().set_input_as_handled()
	_finish_close()


func _input(event: InputEvent) -> void:
	var token := _input_token(event)
	if not token.is_empty():
		if event.is_pressed(): _held[token] = true
		else: _held.erase(token)
	if _closing: get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(panel) or _closing: return
	if event.is_action_pressed("notebook_toggle", false, true):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit or panel._search.has_ime_text(): return
		request_close()
	# No unhandled event from this layer may reach the suspended game.
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_pending_inputs()
	if what == NOTIFICATION_TRANSLATION_CHANGED and _suspended: refresh.call_deferred()


func release_pending_inputs() -> void:
	_held.clear()


func _process(_delta: float) -> void:
	if not _suspended: return
	var controller = _controller.get_ref()
	if not is_instance_valid(controller) or not controller.is_inside_tree() or controller.is_queued_for_deletion():
		_invalid = true
		_held.clear()
		request_close()
	elif not _same_live_scope():
		_invalid = true
		_held.clear()
		request_close()
	elif game.revision != _checked_revision:
		_checked_revision = game.revision
		panel.show_notice(_l("새 변경 사항이 있습니다. 갱신 후 계속할 수 있습니다.", "Changes are available. Refresh before changing saved references."))
	if _closing: _finish_close()


func _finish_close() -> void:
	if not _closing or not _held.is_empty() or not _suspended: return
	_suspended = false
	model.close()
	panel.dismiss()
	pending.clear()
	var controller = _controller.get_ref()
	if is_instance_valid(controller) and controller.is_inside_tree() and not controller.is_queued_for_deletion():
		controller._notebook_host = null
		if not _invalid:
			controller.process_mode = _mode
			controller.visible = _visible
			controller.menu_audio_pause_requested.emit(_audio_paused)
			var focused = _focus.get_ref() if _focus != null else null
			if is_instance_valid(focused) and focused.is_visible_in_tree() and not (focused is BaseButton and focused.disabled): focused.grab_focus()
			elif controller._notebook_button.is_visible_in_tree(): controller._notebook_button.grab_focus()
			if _after_close.is_valid(): _after_close.call_deferred()
			else: controller.call_deferred("_resume_after_notebook", controller._prologue_surface_scope())
		else:
			# Never resume an old controller against a newly loaded slot.
			controller.menu_audio_pause_requested.emit(false)
			controller.return_to_title_requested.emit()
	queue_free()


func _exit_tree() -> void:
	model.close()
	if _suspended:
		var controller = _controller.get_ref()
		if is_instance_valid(controller):
			controller._notebook_host = null
			if controller.is_inside_tree() and not controller.is_queued_for_deletion() and not _invalid:
				controller.process_mode = _mode
				controller.visible = _visible
				controller.menu_audio_pause_requested.emit(_audio_paused)


func _leave_for_tool(action: Callable) -> void:
	if not _same_live_scope(): return
	_after_close = action
	request_close()


func refresh() -> void:
	if _closing or not _same_live_scope() or _current_scope() != _scope: return
	var ui: Dictionary = panel.capture_view()
	var state: Dictionary = game.get_snapshot()
	var result := model.open(state.meta_progress.dialogue_history, state.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), _scope, TranslationServer.get_locale())
	if not result.ok:
		panel.show_notice(_l("자료를 갱신하지 못했습니다. 저장 복구 상태를 확인해 주세요.", "Unable to refresh records. Check save recovery status."))
		return
	_revision = game.revision
	_checked_revision = _revision
	pending.clear()
	panel.replace_model(model, ui)
	panel.set_reference_editable(true)


func _request_reference(collection: String, reference: Dictionary, enabled: bool) -> void:
	if not _same_live_scope() or _closing: return
	pending = {"collection": collection, "reference": reference.duplicate(true), "enabled": enabled, "command_id": ARCHIVE.new_uid()}
	if not enabled:
		panel.show_command(_l("고정을 해제하면 다른 보호 이유가 없는 오래된 일반 기록이 정리될 수 있습니다.", "Removing this reference may allow old ordinary records with no other protection to be pruned."), _execute_pending, _cancel_pending)
	else:
		_execute_pending()


func _execute_pending() -> void:
	if pending.is_empty() or not _same_live_scope() or _closing: return
	var before: Dictionary = game.get_snapshot()
	var result := COMMANDS.set_reference(game, saves, _slot, pending.collection, pending.reference, pending.enabled, _command_scope, _revision, pending.command_id)
	if not result.ok:
		var error_id: String = result.get("error_id", "")
		if error_id == "NB_REFERENCE_LIMIT":
			panel.show_notice(_l("책갈피는 50개, 비교 묶음은 12개까지 저장할 수 있습니다. 기존 고정을 해제한 뒤 다시 담아 주세요.", "You can save 50 bookmarks and 12 comparison materials. Remove an existing reference first."))
			_cancel_pending()
			return
		if error_id in ["NB_COMMAND_SCOPE", "NB_COMMAND_STALE_REVISION", "NB_COMMAND_SLOT_UNAVAILABLE"]:
			panel.show_notice(_l("저장 범위가 바뀌었습니다. 갱신하거나 수첩을 다시 열어 주세요.", "The save scope changed. Refresh or reopen the notebook."))
			panel.show_command(_l("이전 요청은 저장되지 않았습니다.", "The old request was not saved."), refresh, _cancel_pending)
			return
		if _same_live_scope() and StateSnapshotValidator.same_persisted_value(before, game.get_snapshot()) and game.revision != _revision:
			# Adopt only our verified rollback revision, never an unrelated commit.
			if not result.get("error_id", "").begins_with("NB_COMMAND_"):
				_revision = game.revision
				_checked_revision = _revision
		panel.show_command(_l("저장하지 못했습니다. 원래 고정 상태를 유지합니다. 다시 시도하거나 취소해 주세요.", "Not saved. The original reference state is unchanged. Retry or cancel."), _execute_pending, _cancel_pending)
		return
	refresh()
	panel.show_notice(_l("고정 상태를 저장했습니다.", "Saved reference changes."))


func _cancel_pending() -> void:
	pending.clear()
	panel.clear_command()


func _current_scope() -> Dictionary:
	var archive: Dictionary = game.get_value("meta_progress.dialogue_history", {})
	return {"namespace": "development" if _slot.begins_with("__dev_") else saves.get_build_flavor(), "slot": _slot, "run_id": saves.inspect_slot(_slot).get("run_id", ""), "source_origin_id": archive.get("source_origin_id", ""), "branch_id": archive.get("branch_id", ""), "load_epoch": int(game.load_epoch)}


func _same_live_scope() -> bool:
	var controller = _controller.get_ref()
	if not is_instance_valid(controller) or not controller.is_inside_tree() or controller.is_queued_for_deletion() or controller._slot_id != _slot: return false
	if controller.has_method("_make_session") and controller.session != null and controller.session.slot_id != _slot: return false
	if int(game.load_epoch) != _scope.load_epoch: return false
	var namespace_now: String = "development" if _slot.begins_with("__dev_") else saves.get_build_flavor()
	return namespace_now == _scope.namespace and game.get_value("meta_progress.dialogue_history.source_origin_id", "") == _scope.source_origin_id and game.get_value("meta_progress.dialogue_history.branch_id", "") == _scope.branch_id


func _clear_pressed(node: Node) -> void:
	if node is BaseButton and not node.toggle_mode: node.set_pressed_no_signal(false)
	for child in node.get_children(): _clear_pressed(child)


func _input_token(event: InputEvent) -> String:
	if event is InputEventKey: return "key:%d" % (event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]: return "mouse:%d" % event.button_index
	return ""


func _l(ko: String, en: String) -> String:
	return en if TranslationServer.get_locale().begins_with("en") else ko
