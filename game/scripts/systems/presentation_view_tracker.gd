extends Node

const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
const STORE := preload("res://scripts/systems/presentation_view_store.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")
const LAYOUT_VERSION := 1
var store := STORE.new()
var view: Control
var scope := {}
var live_scope := {}
var identity := ""
var saved := {}
var pending := {}
var warning := false
var _revision := -1
var _cursor := {}
var _anchor := ""
var _writable := true
var _restore_frames := 0
var _delay := -1.0
var _input_generation := 0
var _restore_generation := 0


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_input_generation += 1


func _live() -> Dictionary:
	return {"slot": view._slot_id, "namespace": COMMANDS.scope_namespace(GameState, SaveManager, view._slot_id), "load_epoch": GameState.load_epoch,
		"origin": GameState.get_value("meta_progress.dialogue_history.source_origin_id", ""),
		"branch": GameState.get_value("meta_progress.dialogue_history.branch_id", "")}


func _process(delta: float) -> void:
	if not is_instance_valid(view) or view.is_queued_for_deletion() or view._test_mode or view._notebook_is_open() or not view.is_visible_in_tree(): return
	var current := _live()
	if live_scope.is_empty():
		live_scope = current
		scope = {"profile": "local", "namespace": current.namespace, "slot": current.slot,
			"run_id": SaveManager.inspect_slot(current.slot).get("run_id", ""), "source_origin_id": current.origin, "branch_id": current.branch}
	if live_scope != current: return
	if _revision != GameState.revision:
		var state := GameState.get_snapshot()
		_cursor = PRESENTATION.read(state)
		if not PRESENTATION.matches(_cursor, state) or not PRESENTATION.observed(_cursor, state) or _cursor.family != PRESENTATION.family(view): _cursor = {}
		_anchor = PRESENTATION.anchor(state)
		_revision = GameState.revision
	var surface := _surface()
	if surface.is_empty(): return
	var key := JSON.stringify(PRESENTATION._canonical([LAYOUT_VERSION, PRESENTATION.family(view), _anchor, surface.id]), "", true).sha256_text()
	if key != identity:
		identity = key
		var restored := store.load_view(scope, identity)
		pending = restored.view
		_writable = restored.writable
		saved = {}
		_restore_frames = 2 if not pending.is_empty() else 0
		_restore_generation = _input_generation
		_delay = -1.0
	if _restore_frames > 0:
		_restore_frames -= 1
		if _restore_generation != _input_generation:
			_restore_frames = 0
			pending = {}
		elif _restore_frames == 0:
			_restore(surface, pending)
		return
	var captured := _capture(surface)
	if captured != saved:
		saved = captured
		_delay = 0.25
	if _delay >= 0:
		_delay -= delta
		if _delay <= 0: flush()


func flush() -> bool:
	_delay = -1.0
	if saved.is_empty() or identity.is_empty() or not _writable or not is_instance_valid(view) or _live() != live_scope or _revision != GameState.revision: return false
	var ok := store.save_view(scope, identity, saved)
	if not ok and not warning and view.is_inside_tree() and not view.is_queued_for_deletion():
		view._set_status("열람 위치를 저장하지 못했습니다. 게임 진행 저장에는 영향이 없습니다." if not TranslationServer.get_locale().begins_with("en") else "The reading position could not be saved. Game progress is unaffected.")
	warning = not ok
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		if _delay >= 0: flush()


func _surface() -> Dictionary:
	var controls := {}
	var scrolls := {}
	var id: Variant
	if view._modal_active:
		if _cursor.is_empty() or _cursor.kind not in ["modal", "utility", "choice"] or _cursor.phase == "completed": return {}
		if _cursor.kind == "modal":
			var request: Variant = view.get("_recorded_modal_request")
			if not request is Dictionary or request.is_empty() or request.history_context.presentation_token != _cursor.lines[0].presentation_token: return {}
		elif _cursor.kind == "utility":
			var request: Variant = view.get("_utility_request")
			if not request is Dictionary or request.is_empty(): return {}
		elif view._prologue_confirmation.is_empty(): return {}
		id = [_cursor.kind, _cursor.lines[0].presentation_token if not _cursor.lines.is_empty() else _cursor.utility, _cursor.phase]
		_collect(view._modal_body, "modal", controls, scrolls)
	elif view._dialogue_choice_active:
		if _cursor.is_empty() or _cursor.kind != "choice" or _cursor.phase == "completed": return {}
		id = ["choice", _cursor.lines[0].presentation_token, _cursor.phase]
		for button in view._dialogue_choice_buttons: controls["choice:" + String(button.get_meta("choice_id", ""))] = button
	elif view._dialogue_active:
		if _cursor.is_empty() or _cursor.kind != "dialogue" or _cursor.phase == "completed" or _cursor.index != view._dialogue_index: return {}
		if _cursor.lines[int(_cursor.index)].presentation_token != view._dialogue_lines[view._dialogue_index].presentation_token: return {}
		id = ["dialogue", _cursor.lines[int(_cursor.index)].presentation_token]
		controls = {"dialogue:body": view._dialogue_scroll, "dialogue:next": view._dialogue_next}
		scrolls = {"dialogue:body": view._dialogue_scroll}
	elif view._inspection_active:
		id = ["window", view._inspected_window]
		_collect(view._inspection_layer, "window", controls, scrolls)
		for button in view._inventory_slots: controls["inventory:" + String(button.get_meta("item_id", ""))] = button
	else:
		if GameState.get_value("loop_state.location_id", "") != view._current_room: return {}
		id = ["world", view._current_room]
		for control in view._hotspot_layer.get_children(): controls["world:" + String(control.name)] = control
		controls["world:menu"] = view._menu_button
		controls["world:notebook"] = view._notebook_button
	return {"id": id, "controls": controls, "scrolls": scrolls}


func _collect(node: Node, prefix: String, controls: Dictionary, scrolls: Dictionary) -> void:
	for index in range(node.get_child_count()):
		var child := node.get_child(index)
		var key := prefix + ":" + str(index)
		if child is Control and child.focus_mode == Control.FOCUS_ALL: controls[key] = child
		if child is ScrollContainer: scrolls[key] = child
		_collect(child, key, controls, scrolls)


func _layout() -> Array:
	return [TranslationServer.get_locale(), view._reading_text_scale, view.size.x, view.size.y]


func _usable(control: Variant) -> bool:
	return is_instance_valid(control) and control is Control and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled)


func _capture(surface: Dictionary) -> Dictionary:
	var result := {"focus": "", "scrolls": {}, "layout": _layout()}
	var focused := get_viewport().gui_get_focus_owner()
	for key in surface.controls:
		if surface.controls[key] == focused and _usable(focused): result.focus = key
	for key in surface.scrolls:
		var scroll: ScrollContainer = surface.scrolls[key]
		var bar := scroll.get_v_scroll_bar()
		var limit := maxf(0, bar.max_value - bar.page)
		result.scrolls[key] = {"offset": scroll.scroll_vertical, "fraction": clampf(float(scroll.scroll_vertical) / limit, 0, 1) if limit > 0 else 0.0}
	return result


func _restore(surface: Dictionary, value: Dictionary) -> void:
	var target: Variant = surface.controls.get(value.focus)
	if _usable(target): target.grab_focus()
	for key in value.scrolls:
		if not surface.scrolls.has(key): continue
		var scroll: ScrollContainer = surface.scrolls[key]
		var bar := scroll.get_v_scroll_bar()
		var limit := maxf(0, bar.max_value - bar.page)
		var row: Dictionary = value.scrolls[key]
		scroll.scroll_vertical = clampi(int(row.offset) if value.layout == _layout() else roundi(row.fraction * limit), 0, int(limit))
