class_name ChapterOneController
extends PrologueController

const SESSION_SCRIPT := preload("res://scripts/systems/chapter_one_session.gd")
const HISTORY_SESSIONS := [SESSION_SCRIPT, preload("res://scripts/systems/black_mirror_session.gd")]
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const DISPLAY_TEXTS := preload("res://scripts/ui/chapter_one_display_texts.gd")
const MODAL_NOTES := preload("res://scripts/systems/modal_notebook.gd")
const NOTEBOOK_ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const NOTEBOOK_CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CHAPTER_SURFACES := preload("res://scripts/systems/notebook_chapter_surfaces.gd")
const OBJECTIVES := {"A1": "수첩에 다음 아침과 비교할 표식을 남긴다", "AS": "익숙한 일과를 마치고 침실에서 잠든다", "A2": "다음 아침의 수첩 표식을 확인한다", "B1": "사용인 공용실의 문서 두 장 이상으로 빈 시간대를 추론한다", "B2": "일과를 마치고 외부 서고를 통해 기록 내실에 접근한다", "J1": "책상의 압지 조각을 배열해 첫 페이지를 복원한다", "B3_A": "네 방의 시계 탁본을 모아 배선을 연결한다", "B3_B": "역할과 전달 시점을 설정해 시계망을 작동한다", "BF": "남은 조사 후 침실에서 잠든다 · 실패 정보는 남는다", "B4": "공명통에 남은 파형을 수첩에 기록한다", "B5": "기록 내실에서 파형과 두 번째 페이지를 겹친다", "J2_COMPLETE": "첫 장의 기록을 확인한다 · 다음은 검은 거울"}

var session: ChapterOneSession
var _swap_from := -1
var _edgar_timer: Timer
var _edgar_focus_suspended := false
var _edgar_paused_before_focus := false
var _rendering := false
var _world_focus := ""
var _history_recorded_index := -1
var _choice_modal_generation := 0
var _recorded_modal_request: Dictionary = {}
var _modal_dispatch_context: Dictionary = {}
var _utility_request: Dictionary = {}
var _utility_restoring := false
var _notebook_surfaces := preload("res://scripts/systems/notebook_surface_capture.gd").new()


func _notebook_surface_enabled() -> bool:
	return session != null and preload("res://scripts/systems/notebook_rollout.gd").enabled() and session._game.get_value("meta_progress.dialogue_history.schema_version", 0) == 2


func _notebook_surface_scope() -> Dictionary:
	if session == null: return {}
	var scope := _recorded_choice_scope()
	scope.node = session.stage()
	scope.location = session._game.get_value("loop_state.location_id", "")
	scope.day = session._game.get_value("loop_state.day_index", 0)
	if session._game.get_value("ending_run.branch_committed", false):
		scope.ending_node = session._game.get_value("ending_run.current_node_id", "")
	return scope


func _queue_notebook_content(content_id: String, text: String, new_attempt: bool = false) -> void:
	if _notebook_surface_enabled():
		_notebook_surfaces.queue(content_id, text, TranslationServer.get_locale(), session.history_context(), new_attempt)


func _queue_chapter_surface(descriptor: Dictionary, text: String) -> void:
	# Later controllers repaint the base view before replacing it; those labels were not disclosed.
	if _notebook_surface_enabled() and session.stage() in CHAPTER_SURFACES.NODES:
		_notebook_surfaces.queue_descriptor(descriptor, text, TranslationServer.get_locale(), session.history_context())


func _chapter_board(key: String, text: String, rect: Rect2, values: Dictionary = {}) -> void:
	_board_label(text, rect)
	_queue_chapter_surface(CHAPTER_SURFACES.surface(key, values), text)


func _flush_notebook_surfaces(generation: int, explicit_retry: bool = false) -> bool:
	if not _notebook_surface_enabled(): return true
	if _interaction_blocked(): return false
	if not _notebook_surfaces.live(_notebook_surface_scope(), generation): return not _notebook_surfaces.has_pending()
	var saved := _notebook_surfaces.flush(session, _notebook_surface_scope(), explicit_retry)
	var retry := _hotspot_layer.get_node_or_null("NOTEBOOK_SURFACE_RETRY")
	if saved and retry != null:
		var restore_focus: bool = retry is Control and retry.has_focus()
		_hotspot_layer.remove_child(retry)
		retry.queue_free()
		if restore_focus: call_deferred("_restore_notebook_surface_focus")
	elif not saved and retry == null:
		_add_hotspot("NOTEBOOK_SURFACE_RETRY", preload("res://scripts/ui/fracture_surface_texts.gd").retry_text(TranslationServer.get_locale()), Rect2(280, 945, 1360, 100), _flush_notebook_surfaces.bind(generation, true))
	return saved


func _restore_notebook_surface_focus() -> void:
	if _interaction_blocked() or not is_inside_tree(): return
	_restore_world_focus()
	if get_viewport().gui_get_focus_owner() == null and is_instance_valid(_menu_button) and _menu_button.is_visible_in_tree():
		_menu_button.grab_focus()


func _notebook_surface_allowed() -> bool:
	return _flush_notebook_surfaces(_notebook_surfaces.generation)


const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
var _presentation_scope := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_apply_accessibility_profile()
	_edgar_timer = Timer.new()
	_edgar_timer.one_shot = true
	_edgar_timer.wait_time = 6.0
	_edgar_timer.timeout.connect(_on_edgar_timeout)
	add_child(_edgar_timer)
	session = _make_session()
	var handoff := PRESENTATION.completed_handoff(session.snapshot(), PRESENTATION.family(self))
	if handoff:
		session._presentation_commit_override = PRESENTATION.read(session.snapshot())
		session._presentation_commit_override.family = PRESENTATION.family(self)
	var result := session.initialize()
	session._presentation_commit_override = {}
	_render_room()
	if not _restore_presentation(): _feedback(result)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_edgar_timer):
		if not _edgar_focus_suspended: _edgar_paused_before_focus = _edgar_timer.paused
		_edgar_focus_suspended = true
		_edgar_timer.paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(_edgar_timer):
		if _edgar_focus_suspended: _edgar_timer.paused = _edgar_paused_before_focus
		_edgar_focus_suspended = false


func _make_session() -> ChapterOneSession:
	return SESSION_SCRIPT.new(GameState, SaveManager, _slot_id)


func _save_progress(_save_point_id: String = "SAVE_NEW_GAME", _prologue_complete: bool = false) -> bool:
	# Chapter actions are persisted by ChapterOneSession before this view refreshes.
	return true


func _enter_room(room_id: String) -> void:
	_do("move", room_id)


func _rebuild_current_room_content() -> void:
	_render_room()


func _remember_world_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _hotspot_layer.is_ancestor_of(focused):
		_world_focus = String(focused.name)


func _restore_world_focus() -> void:
	if _interaction_blocked() or not is_inside_tree():
		return
	var target := _hotspot_layer.get_node_or_null(NodePath(_world_focus)) as Control if not _world_focus.is_empty() else null
	if target != null and target.is_visible_in_tree() and target.focus_mode == Control.FOCUS_ALL:
		target.grab_focus()
		return
	for child in _hotspot_layer.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			child.grab_focus()
			return


func _show_dialogue(lines: Array, after: Callable = Callable(), start_index: int = 0) -> void:
	_remember_world_focus()
	_history_recorded_index = -1
	_presentation_scope = _recorded_choice_scope()
	var captured := lines.duplicate(true)
	for line in captured:
		if not line.has("history_context") and session != null:
			line["history_context"] = session.history_context()
	super._show_dialogue(captured, after, start_index)


func _presentation_enabled() -> bool:
	return _history_enabled() and session.snapshot().meta_progress.dialogue_history.has("schema_version") and PRESENTATION.family(self) in PRESENTATION.FAMILIES


func _restore_presentation() -> bool:
	if not _presentation_enabled(): return false
	var state: Dictionary = session.snapshot()
	var cursor := PRESENTATION.read(state)
	if not PRESENTATION.matches(cursor, state) or cursor.family != PRESENTATION.family(self) or not PRESENTATION.observed(cursor, state): return false
	if cursor.phase == "completed": return true
	if cursor.kind == "utility": return _restore_utility(cursor.utility)
	if cursor.kind == "modal": return _restore_recorded_modal(cursor)
	_presentation_scope = _recorded_choice_scope()
	_history_recorded_index = int(cursor.index)
	super._show_dialogue(PRESENTATION.localized_lines(cursor, TranslationServer.get_locale()), PRESENTATION.callable_for(self, cursor.after), int(cursor.index))
	return true


func _presentation_cursor(phase: String = "reading") -> Dictionary:
	if _presentation_scope != _recorded_choice_scope(): return {"ok": false}
	var continuation := PRESENTATION.route(self, _dialogue_after)
	if not continuation.ok: return {"ok": false}
	return PRESENTATION.create(session.snapshot(), PRESENTATION.family(self), _dialogue_lines, _dialogue_index, TranslationServer.get_locale(), continuation.value, phase)


func _history_enabled() -> bool:
	return session != null and session.get_script() in HISTORY_SESSIONS


func _uses_prologue_history() -> bool:
	return false


func _present_dialogue_line() -> void:
	super._present_dialogue_line()
	_record_current_history_line()


func _record_current_history_line() -> bool:
	if not _history_enabled() or not _dialogue_active:
		return true
	if _presentation_enabled() and _presentation_scope != _recorded_choice_scope(): return false
	if _history_recorded_index == _dialogue_index: return true
	var context: Dictionary = _dialogue_lines[_dialogue_index].get("history_context", {}).duplicate(true)
	if _presentation_enabled():
		var cursor := _presentation_cursor()
		if not cursor.ok:
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return false
		context.presentation_cursor = cursor.value
	context["observed_fact_ids"] = _dialogue_lines[_dialogue_index].get("observed_fact_ids", [])
	context["presentation_token"] = _dialogue_lines[_dialogue_index].presentation_token
	if _dialogue_lines[_dialogue_index].has("notebook_content"):
		context["notebook_content"] = _dialogue_lines[_dialogue_index].notebook_content
	var result := session.record_viewed_line(_speaker_label.text, _dialogue_label.text, TranslationServer.get_locale(), context)
	if not result.get("ok", false):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return false
	_history_recorded_index = _dialogue_index
	return true


func _open_menu() -> void:
	if not _utility_request.is_empty(): return
	if session == null:
		super._open_menu()
		return
	if _dialogue_active or _dialogue_choice_active:
		return
	menu_audio_pause_requested.emit(true)
	_show_modal(_dialogue_ui_text("UI_P_MENU"), _dialogue_ui_text("UI_P_AUTOSAVE"), [
		{"label": _dialogue_ui_text("UI_DIALOGUE_CONTINUE"), "action": _close_modal},
		{"label": _dialogue_ui_text("CH1_HISTORY_TITLE"), "action": _open_dialogue_history},
		{"label": _dialogue_ui_text("UI_P_RETURN_TITLE"), "action": _return_to_title},
	] + _settings_menu_actions())


func _open_dialogue_history() -> void:
	if _try_open_unified_notebook("dialogue"): return
	var result := _dialogue_texts.render_history(session.snapshot()["meta_progress"]["dialogue_history"], TranslationServer.get_locale())
	_show_history_result(result)


func _advance_dialogue() -> void:
	if _notebook_is_open(): return
	if not _record_current_history_line():
		return
	if _presentation_enabled() and _dialogue_active and _dialogue_index == _dialogue_lines.size() - 1:
		var cursor := _presentation_cursor("completed" if _dialogue_after.is_null() else "finish_pending")
		if not cursor.ok: return
		var saved := preload("res://scripts/systems/dialogue_history_writer.gd").save_cursor(session._game, session._save, session.slot_id, session._save_point(session.snapshot()), cursor.value)
		if not saved.ok:
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return
	super._advance_dialogue()
	if not _dialogue_active:
		call_deferred("_restore_world_focus")
		if session != null and session.stage() in ["J2_COMPLETE", "J3_COMPLETE"]:
			campaign_requested.emit(_slot_id)
		_notebook_surface_allowed()


func _show_modal(title: String, body: String, actions: Array) -> void:
	_utility_request = {}
	_recorded_modal_request = {}
	_choice_modal_generation += 1
	_remember_world_focus()
	_remember_history_scroll()
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()
	super._show_modal(title, body, actions)


func _close_modal() -> void:
	if _notebook_is_open():
		_notebook_host.request_close()
		return
	if not _utility_request.is_empty() and not _save_utility(_utility_request, "completed"): return
	if _presentation_enabled() and not _recorded_modal_request.is_empty() and _recorded_choice_live(_recorded_modal_request) and _modal_dispatch_context.is_empty():
		if not _record_modal_options(_recorded_modal_request): return
		var cursor := _modal_cursor(_recorded_modal_request, "completed")
		if not cursor.ok or not preload("res://scripts/systems/dialogue_history_writer.gd").save_cursor(session._game, session._save, session.slot_id, session._save_point(session.snapshot()), cursor.value).ok:
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return
	_recorded_modal_request = {}
	_choice_modal_generation += 1
	super._close_modal()
	_utility_request = {}
	call_deferred("_restore_world_focus")
	_notebook_surface_allowed()


func _show_recorded_choice(title: String, body: String, actions: Array, descriptor: Dictionary, history_context: Dictionary = {}, view: Dictionary = {}) -> void:
	var row := NOTEBOOK_CONTENT.definition(descriptor.get("content_id", ""), 1)
	if row.is_empty() or row.get("choices", []).size() != actions.size():
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		push_error("NB_MODAL_DESCRIPTOR")
		return
	var frozen := session.history_context() if session != null else {}
	if not history_context.is_empty(): frozen = history_context.duplicate(true)
	frozen.event_occurrence_id = NOTEBOOK_ARCHIVE.new_uid()
	frozen.conversation_session_id = NOTEBOOK_ARCHIVE.new_uid()
	frozen.presentation_token = NOTEBOOK_ARCHIVE.new_uid()
	frozen.notebook_content = descriptor.duplicate(true)
	var context := {"generation": _choice_modal_generation + 1, "recorded": false, "text": title + "\n" + body, "history_context": frozen,
		"scope": _recorded_choice_scope(), "locale": TranslationServer.get_locale(), "row": row, "actions": actions.duplicate(true), "pending_index": -1,
		"selection_recorded": false, "dispatching": false, "options_speaker": _dialogue_ui_text("HISTORY_OPTIONS"), "selected_speaker": _dialogue_ui_text("HISTORY_SELECTED"),
		"title": title, "body": body, "view": view.duplicate(true), "focus": 0}
	_present_recorded_modal(context)
	_record_modal_options(context)


func _present_recorded_modal(context: Dictionary) -> void:
	context.generation = _choice_modal_generation + 1
	var wrapped: Array = []
	context.text = context.title + "\n" + context.body
	for index in range(context.actions.size()):
		var action: Dictionary = context.actions[index].duplicate()
		context.text += "\n" + String(action.label)
		action["action"] = _recorded_choice_pressed.bind(context, index)
		wrapped.append(action)
	_show_modal(context.title, context.body, wrapped)
	_recorded_modal_request = context
	_restore_recorded_modal_extras(context.view)
	var buttons: Array = _modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
	if int(context.focus) in range(buttons.size()):
		call_deferred("_focus_visible_control", weakref(buttons[int(context.focus)]))


func _restore_recorded_modal_extras(_view: Dictionary) -> void:
	pass


func _modal_cursor(context: Dictionary, phase: String) -> Dictionary:
	if context.scope != _recorded_choice_scope(): return {"ok": false}
	var modal := PRESENTATION.MODAL.capture(self, context)
	if modal.is_empty(): return {"ok": false}
	var line := {"speaker": context.options_speaker, "text": context.text, "history_context": context.history_context.duplicate(true),
		"presentation_token": context.history_context.presentation_token, "notebook_content": context.history_context.notebook_content.duplicate(true)}
	var cursor: Dictionary = PRESENTATION.create(session.snapshot(), PRESENTATION.family(self), [line], 0, context.locale, {}).value
	cursor.kind = "modal"
	cursor.phase = phase
	cursor.modal = modal
	return {"ok": PRESENTATION.valid(cursor), "value": cursor}


func _restore_recorded_modal(cursor: Dictionary) -> bool:
	var line: Dictionary = cursor.lines[0]
	var row := NOTEBOOK_CONTENT.definition(line.notebook_content.get("content_id", ""), 1)
	if row.is_empty() or row.get("choices", []).size() != cursor.modal.routes.size(): return false
	var data := PRESENTATION.MODAL.localized(cursor.modal, line.notebook_content, TranslationServer.get_locale())
	var actions := []
	for index in range(data.routes.size()):
		var route: Dictionary = data.routes[index]
		if not has_method(route.method): return false
		actions.append({"label": data.labels[index], "action": Callable(self, route.method).bindv(route.args)})
	var context := {"recorded": true, "history_context": line.history_context.duplicate(true),
		"scope": _recorded_choice_scope(), "locale": TranslationServer.get_locale(), "row": row, "actions": actions,
		"pending_index": int(data.pending_index), "selection_token": data.selection_token, "selection_recorded": not data.selection_token.is_empty(), "dispatching": false,
		"options_speaker": _dialogue_ui_text("HISTORY_OPTIONS"), "selected_speaker": _dialogue_ui_text("HISTORY_SELECTED"),
		"title": data.title, "body": data.body, "view": data.view, "focus": int(data.focus)}
	_present_recorded_modal(context)
	return true


func _restore_utility(utility: Dictionary) -> bool:
	if utility.stage != session.stage(): return false
	_utility_restoring = true
	match utility.type:
		"hints": _show_clock_hint_menu(int(utility.level))
		"failure": _offer_clock_failure_support()
		"quantities":
			if has_method("_open_cleaner_quantity_table"): call("_open_cleaner_quantity_table", utility.ratio, utility.difference)
	_utility_restoring = false
	return not _utility_request.is_empty()


func _show_utility_modal(title: String, body: String, actions: Array, type: String, level: int = 0, ratio: bool = false, difference: bool = false) -> void:
	if not _presentation_enabled():
		_show_modal(title, body, actions)
		return
	var request := {"utility": {"type": type, "stage": session.stage(), "level": level, "ratio": ratio, "difference": difference},
		"scope": _recorded_choice_scope(), "generation": _choice_modal_generation + 1, "anchor": PRESENTATION.anchor(session.snapshot())}
	var wrapped: Array = []
	for action in actions:
		wrapped.append({"label": action.label, "action": _utility_action.bind(request, action.action)})
	_show_modal(title, body, wrapped)
	_utility_request = request
	if not _utility_restoring: _save_utility(request)


func _utility_live(request: Dictionary) -> bool:
	return _recorded_choice_live(request) and request.utility.stage == session.stage() and request.anchor == PRESENTATION.anchor(session.snapshot())


func _save_utility(request: Dictionary, phase: String = "viewing") -> bool:
	if not _utility_live(request): return false
	var cursor := PRESENTATION.create_utility(session.snapshot(), PRESENTATION.family(self), request.utility, TranslationServer.get_locale(), phase)
	if not cursor.ok or not preload("res://scripts/systems/dialogue_history_writer.gd").save_cursor(session._game, session._save, session.slot_id, session._save_point(session.snapshot()), cursor.value).ok:
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return false
	_set_status("")
	return true


func _utility_action(request: Dictionary, action: Callable) -> void:
	if not _utility_live(request) or not action.is_valid() or action.get_object() != self: return
	if not _save_utility(request): return
	action.call()


func _update_quantity_view(ratio: bool, difference: bool, request: Dictionary) -> bool:
	if not _presentation_enabled(): return true
	if request.is_empty() or not _utility_live(request) or _utility_request.is_empty() or _utility_request.utility.type != "quantities": return false
	var candidate: Dictionary = _utility_request.duplicate(true)
	candidate.utility.ratio = ratio
	candidate.utility.difference = difference
	if not _save_utility(candidate): return false
	_utility_request.utility = candidate.utility
	return true


func _recorded_choice_scope() -> Dictionary:
	if session == null: return {}
	var archive: Dictionary = session._game.get_value("meta_progress.dialogue_history", {})
	return {"slot": session.slot_id, "view_slot": _slot_id, "session": session.get_instance_id(), "load_epoch": session._game.get("load_epoch"),
		"origin": archive.get("source_origin_id", ""), "branch": archive.get("branch_id", ""), "namespace": SaveManager.get_build_flavor()}


func _recorded_choice_live(context: Dictionary) -> bool:
	return not _notebook_is_open() and _modal_active and int(context.generation) == _choice_modal_generation and context.scope == _recorded_choice_scope()


func _record_modal_options(context: Dictionary) -> bool:
	if not _recorded_choice_live(context): return false
	if context["recorded"] or not _history_enabled():
		return true
	var frozen: Dictionary = context.history_context.duplicate(true)
	if _presentation_enabled():
		var cursor := _modal_cursor(context, "choosing")
		if not cursor.ok:
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return false
		frozen.presentation_cursor = cursor.value
	var result := session.record_viewed_line(context.options_speaker, String(context["text"]), context.locale, frozen)
	if not result.get("ok", false):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return false
	context["recorded"] = true
	return true


func _recorded_choice_pressed(context: Dictionary, index: int) -> void:
	if not _recorded_choice_live(context) or context.dispatching or index not in range(context.actions.size()):
		return
	if not _record_modal_options(context):
		return
	var choice: Dictionary = context.row.choices[index]
	context.focus = index
	if context.pending_index != index:
		context.pending_index = index
		context.selection_recorded = false
		context.selection_token = NOTEBOOK_ARCHIVE.new_uid()
	if choice.kind != "ui" and _history_enabled() and not context.selection_recorded:
		var selected: Dictionary = context.history_context.duplicate(true)
		selected.presentation_token = context.selection_token
		selected.notebook_content = NOTEBOOK_CONTENT.descriptor(choice.content_id, 1, {"body": {}})
		if _presentation_enabled():
			context.selection_recorded = true
			var cursor := _modal_cursor(context, "selection_pending")
			context.selection_recorded = false
			if not cursor.ok:
				_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
				return
			selected.presentation_cursor = cursor.value
		var result := session.record_viewed_line(context.selected_speaker, context.actions[index].label, context.locale, selected)
		if not result.get("ok", false):
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return
		context.selection_recorded = true
	context.dispatching = true
	var action: Callable = context.actions[index].action
	if String(action.get_method()) != "_close_modal": _modal_dispatch_context = context
	context.actions[index].action.call()
	_modal_dispatch_context = {}
	context.dispatching = false
	# A saved answer is not a successful world action. Never replay it automatically.
	if _presentation_enabled() and context.scope == _recorded_choice_scope() and not _modal_active and not _dialogue_active and not _notebook_is_open():
		var pending := PRESENTATION.read(session.snapshot())
		if pending.get("kind") == "modal" and pending.phase == "selection_pending" and PRESENTATION.matches(pending, session.snapshot()) and PRESENTATION.observed(pending, session.snapshot()):
			_restore_recorded_modal(pending)


func _cancel_prologue_modal() -> void:
	if not _recorded_modal_request.is_empty() and not _recorded_choice_live(_recorded_modal_request):
		_close_modal()
		return
	if not _recorded_modal_request.is_empty() and int(_recorded_modal_request.row.cancel_index) >= 0:
		_recorded_choice_pressed(_recorded_modal_request, int(_recorded_modal_request.row.cancel_index))
	else:
		if not _recorded_modal_request.is_empty() and not _record_modal_options(_recorded_modal_request): return
		super._cancel_prologue_modal()


func _update_objective() -> void:
	if session != null:
		var objective_id := "CH1_OBJ_" + session.stage() if OBJECTIVES.has(session.stage()) else "CH1_OBJ_DEFAULT"
		_objective_label.text = _dialogue_ui_text(objective_id)


func _do(action: String, value: Variant = null, show_text: bool = true) -> void:
	if not _notebook_surface_allowed(): return
	if _interaction_blocked():
		return
	if not show_text and _presentation_enabled():
		var completion := PRESENTATION.completion_for_action(session.snapshot(), PRESENTATION.family(self), action, value)
		if not completion.is_empty():
			if _presentation_scope != _recorded_choice_scope(): return
			session._presentation_commit_override = completion
	var result := _act_with_modal_completion(action, value)
	session._presentation_commit_override = {}
	if result.get("ok", false):
		_set_status("")
	_render_room()
	if show_text:
		if action == "activate_clock" and result.get("ok", false) and session.stage() == "BF":
			var failure: Dictionary = session.snapshot()["meta_progress"]["failure_knowledge"].get("B3_B", {})
			if int(failure.get("attempts", 0)) >= 2:
				result["presentation_after"] = _offer_clock_failure_support
		_feedback(result)
	elif not result.get("ok", false):
		var text_id := String(result.get("text_id", ""))
		var fallback := String(result.get("text", str(result.get("error_ids", []))))
		_set_status(_dialogue_ui_text(text_id) if not text_id.is_empty() else _display_feedback(fallback))


func _feedback(result: Dictionary) -> void:
	var text := String(result.get("text", ""))
	if not String(result.get("text_id", "")).is_empty():
		text = _dialogue_ui_text(String(result["text_id"]))
	else:
		text = _display_feedback(text)
	if text.is_empty():
		if not result.get("ok", false):
			_set_status(DISPLAY_TEXTS.ui("save_error", TranslationServer.get_locale(), [str(result.get("error_ids", []))]))
		return
	if not result.get("ok", false):
		_set_status(text)
		return
	var speaker := String(result.get("speaker", "주인공"))
	var lines: Array = []
	for paragraph in text.split("\n"):
		if not paragraph.is_empty():
			lines.append({"speaker": speaker, "portrait": "EDGAR" if speaker == "에드가" else "", "text": paragraph, "history_context": result.get("history_context", session.history_context())})
	var descriptors: Array = result.get("notebook_feedback", [])
	if not descriptors.is_empty():
		if descriptors.size() != lines.size():
			push_error("NB_CH1_FEEDBACK_SEGMENT_COUNT")
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return
		for index in range(lines.size()): lines[index].notebook_content = descriptors[index].duplicate(true)
	_show_dialogue(lines, result.get("presentation_after", Callable()))


func _display_feedback(text: String) -> String:
	return DISPLAY_TEXTS.feedback(text, TranslationServer.get_locale())


func _render_room() -> void:
	if _rendering or session == null:
		return
	_rendering = true
	_notebook_surfaces.begin(_notebook_surface_scope())
	call_deferred("_flush_notebook_surfaces", _notebook_surfaces.generation)
	_remember_world_focus()
	var state := session.snapshot()
	if _current_room != state["loop_state"]["location_id"]:
		_swap_from = -1
		_world_focus = ""
	_current_room = state["loop_state"]["location_id"]
	var local := session.local_state(state)
	_progress = {"notebook_entries": [], "P1_complete": true}
	_update_inventory([])
	_inventory_panel.visible = false
	_clear_hotspots()
	var background_id := _current_room
	if _current_room in ["M1_LIBRARY_INNER", "M1_SERVANT_COMMON"]:
		background_id = "M1_LIBRARY_OUTER" if _current_room == "M1_LIBRARY_INNER" else "M1_KITCHEN"
	_set_room_background(background_id)
	_room_art.set_room(background_id, {})
	var locale := TranslationServer.get_locale()
	_location_label.text = DISPLAY_TEXTS.location_header(_current_room, int(state["loop_state"]["day_index"]) + 1, locale)
	_update_objective()
	if _current_room == "M1_LIBRARY_INNER" and local["edgar_state"] != "absent":
		_build_edgar_pressure(local)
		_rendering = false
		call_deferred("_restore_world_focus")
		return
	match _current_room:
		"M2_BEDROOM":
			_build_loop_bedroom(local)
		"M1_CENTRAL_HALL":
			var destinations := ["M1_SERVANT_COMMON", "M1_PARLOR", "M1_LIBRARY_OUTER", "M1_GREAT_CLOCK", "M1_NORTH_ARCHIVE_HALL", "M2_BEDROOM"]
			for index in range(destinations.size()):
				_action("GO_" + destinations[index], DISPLAY_TEXTS.location_name(destinations[index], locale), Rect2(240 + (index % 3) * 490, 230 + (index / 3) * 210, 410, 140), "move", destinations[index], false)
		"M1_SERVANT_COMMON":
			for index in range(4):
				var owner: String = ["edgar", "luca", "mara1", "mara2"][index]
				var label := _dialogue_ui_text("CH1_B1_DOC_" + owner.to_upper())
				if session.known("schedule_" + owner):
					label += _dialogue_ui_text("CH1_B1_READ")
				_action("DOC_" + owner, label, Rect2(260 + (index % 2) * 720, 210 + (index / 2) * 165, 640, 115), "read_schedule", owner)
				_queue_chapter_surface(CHAPTER_SURFACES.surface("B1_DOC_%s_%s" % [owner.to_upper(), "READ" if session.known("schedule_"+owner) else "UNREAD"]), label)
			_add_hotspot("B1_BOARD", _dialogue_ui_text("CH1_B1_BOARD"), Rect2(610, 610, 650, 110), _open_schedule_board)
		"M1_LIBRARY_OUTER":
			_action("INNER_DOOR", DISPLAY_TEXTS.ui("inner_door", locale), Rect2(1180, 230, 350, 390), "move", "M1_LIBRARY_INNER", false)
			_queue_chapter_surface(CHAPTER_SURFACES.surface("INNER_DOOR"), DISPLAY_TEXTS.ui("inner_door", locale))
			_clock_hotspot()
		"M1_LIBRARY_INNER":
			_build_inner(local, int(state["meta_progress"]["journal_stage"]))
		"M1_PARLOR":
			_clock_hotspot()
		"M1_GREAT_CLOCK":
			_build_great_clock(local)
		"M1_NORTH_ARCHIVE_HALL":
			_action("NORTH_LINK", DISPLAY_TEXTS.ui("north_link", locale) + "\n" + DISPLAY_TEXTS.ui("north_known" if session.known("north_library_shortcut") else "north_locked", locale), Rect2(580, 250, 700, 260), "move", "M1_LIBRARY_INNER", false)
			_queue_chapter_surface(CHAPTER_SURFACES.surface("NORTH_KNOWN" if session.known("north_library_shortcut") else "NORTH_LOCKED"), _hotspot_layer.get_node("NORTH_LINK").text)
			_add_hotspot("MARA2_MEMORY", DISPLAY_TEXTS.ui("mara2_memory_action", locale), Rect2(600, 570, 600, 110), _show_mara2_memory)
	if _current_room == "M1_LIBRARY_INNER":
		_action("BACK", DISPLAY_TEXTS.ui("back_outer", locale), Rect2(700, 944, 400, 72), "move", "M1_LIBRARY_OUTER", false)
	elif _current_room != "M1_CENTRAL_HALL":
		_action("BACK", DISPLAY_TEXTS.ui("back_hall", locale), Rect2(700, 944, 400, 72), "move", "M1_CENTRAL_HALL", false)
	_rendering = false
	call_deferred("_restore_world_focus")


func _show_mara2_memory() -> void:
	var line := {"speaker": "마라 2", "portrait": "MARA2", "text": DISPLAY_TEXTS.ui("mara2_memory_line", TranslationServer.get_locale())}
	var descriptors := preload("res://scripts/systems/chapter_one_notebook.gd").paragraphs("MARA2_MEMORY")
	if not descriptors.is_empty(): line.notebook_content = descriptors[0]
	_show_dialogue([line])


func _action(id: String, label: String, rect: Rect2, action: String, value: Variant = null, show_text: bool = true) -> void:
	_add_hotspot(id, label, rect, _do.bind(action, value, show_text))


func _build_loop_bedroom(local: Dictionary) -> void:
	if session.stage() == "A1":
		_add_hotspot("A1_MARK", _dialogue_ui_text("CH1_BED_MARK"), Rect2(510, 320, 830, 160), _open_mark_choices)
	elif session.stage() == "A2":
		_action("A2_CONFIRM", _dialogue_ui_text("CH1_BED_CONFIRM"), Rect2(510, 320, 830, 160), "confirm_mark")
	else:
		_add_hotspot("NOTEBOOK", _dialogue_ui_text("CH1_BED_NOTEBOOK"), Rect2(350, 240, 470, 100), _open_notebook)
	_action("AS_ROUTINE", _dialogue_ui_text("CH1_BED_ROUTINE_DONE" if local["routine_done"] else "CH1_BED_ROUTINE"), Rect2(350, 550, 650, 100), "routine")
	_add_hotspot("SLEEP", _dialogue_ui_text("CH1_BED_SLEEP"), Rect2(1090, 580, 510, 140), _confirm_sleep)
	if session.can_prepare_clock_shortcut():
		_action("BSHORT", _dialogue_ui_text("CH1_BED_SHORTCUT"), Rect2(360, 730, 880, 100), "shortcut")
	_clock_hotspot()


func _open_mark_choices() -> void:
	var actions: Array = []
	for id in SESSION_SCRIPT.MARKS:
		actions.append({"label": _dialogue_ui_text("CH1_MARK_" + String(id).to_upper()), "action": _modal_act.bind("mark", id)})
	_show_recorded_choice(_dialogue_ui_text("CH1_MARK_TITLE"), _dialogue_ui_text("CH1_MARK_PROMPT"), actions, MODAL_NOTES.options("CH1_MARK"))


func _open_schedule_board() -> void:
	_show_recorded_choice(_dialogue_ui_text("CH1_B1_TITLE"), _dialogue_ui_text("CH1_B1_PROMPT"), [
		{"label": _dialogue_ui_text("CH1_B1_MORNING"), "action": _modal_act.bind("schedule_window", "morning")},
		{"label": _dialogue_ui_text("CH1_B1_TEA"), "action": _modal_act.bind("schedule_window", "after_tea_before_bell")},
		{"label": _dialogue_ui_text("CH1_B1_BELL"), "action": _modal_act.bind("schedule_window", "after_bell")},
	], MODAL_NOTES.options("CH1_SCHEDULE"))


func _modal_act(action: String, value: Variant = null) -> void:
	_close_modal()
	_do(action, value)


func _act_with_modal_completion(action: String, value: Variant) -> Dictionary:
	if not _presentation_enabled() or _modal_dispatch_context.is_empty(): return session.act(action, value)
	var cursor := _modal_cursor(_modal_dispatch_context, "completed")
	if not cursor.ok: return {"ok": false, "text": _dialogue_ui_text("CH1_HISTORY_SAVE_ERROR")}
	var previous: Dictionary = session._presentation_commit_override
	session._presentation_commit_override = cursor.value
	var result := session.act(action, value)
	session._presentation_commit_override = previous
	return result


func _confirm_sleep() -> void:
	_show_recorded_choice(_dialogue_ui_text("CH1_SLEEP_TITLE"), _dialogue_ui_text("CH1_SLEEP_RULE"), [
		{"label": _dialogue_ui_text("P6_CANCEL"), "action": _close_modal},
		{"label": _dialogue_ui_text("P6_SLEEP"), "action": _sleep_now},
	], MODAL_NOTES.options("CH1_SLEEP"))


func _sleep_now() -> void:
	_close_modal()
	if not _notebook_surface_allowed(): return
	var result := session.sleep()
	_render_room()
	_feedback(result)


func _localized_notebook_entry(entry: String) -> String:
	for text_id in ["CH1_B4_RECORDED", "CH1_J2_RESTORED"]:
		if entry == _dialogue_texts.get_text(text_id, "ko-KR"):
			return _dialogue_ui_text(text_id)
	for category in ["REFERENCE", "RELAY", "OUTPUT", "EXCLUDED", "PHASE_TOO_EARLY", "PHASE_SIMULTANEOUS", "PHASE_BETWEEN", "PHASE_UNSET"]:
		var text_id: String = "CH1_CLOCK_FAILURE_" + category + "_NOTE"
		if entry == _dialogue_texts.get_text(text_id, "ko-KR"):
			return _dialogue_ui_text(text_id)
	for clock_id in CLOCK.CLOCKS:
		if entry == CLOCK.CLUES[clock_id]:
			return _dialogue_ui_text("CH1_CLOCK_" + clock_id.to_upper())
	if entry == "\n\n".join(SESSION_SCRIPT.J1_FRAGMENTS):
		return _dialogue_ui_text("CH1_J1_RESTORED")
	return super._localized_notebook_entry(entry)


func _build_inner(local: Dictionary, journal: int) -> void:
	var ids := ["desk", "index", "drawer", "alcove", "gap", "link"]
	for index in range(ids.size()):
		_action("INNER_" + ids[index], _dialogue_ui_text("CH1_INNER_LABEL_" + ids[index].to_upper()), Rect2(150 + (index % 3) * 540, 145 + (index / 3) * 94, 485, 70), "inspect_inner", ids[index])
		_queue_chapter_surface(CHAPTER_SURFACES.surface("INNER_"+ids[index].to_upper()), _dialogue_ui_text("CH1_INNER_LABEL_"+ids[index].to_upper()))
	if journal == 0 and "desk" in local["inspected"]:
		for index in range(3):
			var fragment_id: int = [2, 0, 1][index]
			var fragment := _dialogue_ui_text("CH1_J1_FRAGMENT_%d" % fragment_id)
			var face := _dialogue_ui_text("CH1_J1_FRONT" if bool(local["j1_front"][fragment_id]) else "CH1_J1_BACK")
			_action("J1_PIECE_%d" % fragment_id, fragment + "\n" + face, Rect2(130 + index * 565, 368, 535, 200), "j1_piece", fragment_id, false)
			_queue_chapter_surface(CHAPTER_SURFACES.fragment(fragment_id, bool(local["j1_front"][fragment_id])), fragment+"\n"+face)
			_action("J1_FLIP_%d" % fragment_id, _dialogue_ui_text("CH1_J1_FLIP"), Rect2(160 + index * 565, 580, 470, 56), "j1_flip", fragment_id, false)
		var order: Array[String] = []
		for id in local["j1_order"]:
			order.append(_dialogue_ui_text("CH1_J1_FRAGMENT_%d" % int(id)).split("\n")[0])
		var order_text := _dialogue_ui_text("CH1_J1_ORDER") + " → ".join(order)
		_board_label(order_text, Rect2(170, 660, 1550, 70))
		_queue_chapter_surface(CHAPTER_SURFACES.order(local["j1_order"]), order_text)
		_action("J1_CLEAR", _dialogue_ui_text("CH1_J1_CLEAR"), Rect2(450, 768, 450, 75), "j1_clear", null, false)
		_action("J1_RESTORE", _dialogue_ui_text("CH1_J1_VERIFY"), Rect2(990, 768, 450, 75), "j1_restore")
	elif session.known("b4_waveform_acquired") and journal < 2:
		_chapter_board("J2_BOARD", _dialogue_ui_text("CH1_J2_BOARD") + _direction(int(local["wave_rotation"])), Rect2(260, 390, 1370, 190), {"direction":str(int(local["wave_rotation"]))})
		_action("B5_ROTATE", _dialogue_ui_text("CH1_J2_ROTATE"), Rect2(300, 650, 580, 95), "wave_rotate", null, false)
		_action("J2_RESTORE", _dialogue_ui_text("CH1_J2_COMPARE"), Rect2(990, 650, 580, 95), "restore_j2")
	else:
		_add_hotspot("JOURNAL_READ", _dialogue_ui_text("CH1_J1_READ"), Rect2(440, 520, 950, 150), _open_notebook)


func _build_edgar_pressure(local: Dictionary) -> void:
	if local["edgar_state"] == "hidden":
		_chapter_board("B2_HIDDEN_BOARD", _dialogue_ui_text("CH1_B2_HIDDEN_BOARD"), Rect2(390, 330, 1080, 230))
		if _edgar_timer.is_stopped():
			_edgar_timer.start()
		return
	_chapter_board("B2_ENTRY", _dialogue_ui_text("CH1_B2_ENTRY"), Rect2(400, 250, 1120, 160))
	if "alcove" in local["inspected"]:
		_action("B2_HIDE", _dialogue_ui_text("CH1_B2_HIDE"), Rect2(380, 490, 540, 140), "edgar_hide")
	_action("B2_CAUGHT", _dialogue_ui_text("CH1_B2_TALK"), Rect2(1000, 490, 540, 140), "edgar_talk")


func _on_edgar_timeout() -> void:
	if session.local_state()["edgar_state"] != "hidden":
		return
	if _dialogue_active or _modal_active:
		_edgar_timer.start(1.0)
		return
	_do("edgar_leave")


func _clock_hotspot() -> void:
	if int(session.snapshot()["meta_progress"]["journal_stage"]) < 1:
		return
	var room_clock: String = SESSION_SCRIPT.CLOCK_ROOMS.get(_current_room, "")
	if not room_clock.is_empty():
		_action("RUB_CLOCK", _dialogue_ui_text("CH1_CLOCK_RUB"), Rect2(1080, 150, 550, 140), "rub_clock")


func _build_great_clock(local: Dictionary) -> void:
	if local["clock_locked"]:
		_chapter_board("CLOCK_LOCKED", _dialogue_ui_text("CH1_CLOCK_LOCKED"), Rect2(300, 340, 1290, 230))
		return
	if local["signal_generated"] or session.known("b4_waveform_acquired"):
		_action("B4_RECORD", _dialogue_ui_text("CH1_B4_RECORD"), Rect2(440, 330, 1030, 220), "record_wave")
		return
	if local["rubbed"].size() < 4:
		_clock_hotspot()
		_chapter_board("CLOCK_COLLECT", _dialogue_ui_text("CH1_CLOCK_COLLECT") % local["rubbed"].size(), Rect2(350, 370, 1220, 250), {"count":local["rubbed"].size()})
		return
	if not session.known("clock_network_layout_solved"):
		_build_layout_board(local)
	else:
		_build_roles_board(local)


func _build_layout_board(local: Dictionary) -> void:
	var board: Dictionary = local["board"]
	_chapter_board("CLOCK_LAYOUT", _dialogue_ui_text("CH1_CLOCK_LAYOUT"), Rect2(150, 145, 1620, 105))
	for index in range(4):
		var clock_id: String = board["pieces"][index]
		var back: bool = clock_id == "library_outer" and board["library_back"]
		var pattern := _dialogue_ui_text("CH1_CLOCK_PATTERN_" + ("LIBRARY_BACK" if back else clock_id.to_upper()))
		var label := _dialogue_ui_text("CH1_CLOCK_CARD") % [index + 1, _dialogue_ui_text("CH1_CLOCK_NAME_" + clock_id.to_upper()), _direction(int(board["rotations"][index])), pattern, _dialogue_ui_text("CH1_CLOCK_BACK") if back else _dialogue_ui_text("CH1_CLOCK_FRONT")]
		_add_hotspot("B3_PIECE_%d" % index, label, Rect2(135 + index * 445, 320, 405, 245), _swap_piece.bind(index))
		_queue_chapter_surface(CHAPTER_SURFACES.card(index, board), label)
		_action("B3_ROTATE_%d" % index, _dialogue_ui_text("CH1_CLOCK_ROTATE"), Rect2(155 + index * 445, 585, 365, 65), "board_rotate", index, false)
	_action("B3_FLIP", _dialogue_ui_text("CH1_CLOCK_FLIP"), Rect2(220, 706, 570, 90), "board_flip", null, false)
	_action("B3_CHECK", _dialogue_ui_text("CH1_CLOCK_CHECK"), Rect2(1020, 706, 630, 90), "board_check")


func _swap_piece(index: int) -> void:
	if _interaction_blocked():
		return
	if not _notebook_surface_allowed(): return
	if _swap_from < 0:
		_swap_from = index
		_set_status(_dialogue_ui_text("CH1_CLOCK_SWAP") % (index + 1))
		return
	var from := _swap_from
	_swap_from = -1
	_do("board_swap", [from, index], false)


func _build_roles_board(local: Dictionary) -> void:
	_chapter_board("CLOCK_ROLES", _dialogue_ui_text("CH1_CLOCK_ROLES"), Rect2(180, 145, 1570, 80))
	for index in range(4):
		var role: String = CLOCK.ROLES[index]
		var selected: String = local["roles"].get(role, "")
		var button := OptionButton.new()
		button.name = "ROLE_" + role
		button.add_item(_dialogue_ui_text("CH1_CLOCK_ROLE_" + role.to_upper()) + " · " + _dialogue_ui_text("CH1_CLOCK_SELECT"), 0)
		for clock_id in CLOCK.CLOCKS:
			button.add_item(_dialogue_ui_text("CH1_CLOCK_ROLE_" + role.to_upper()) + " · " + _dialogue_ui_text("CH1_CLOCK_NAME_" + clock_id.to_upper()))
		button.select(CLOCK.CLOCKS.find(selected) + 1)
		button.add_theme_font_size_override("font_size", 22)
		_place(button, Rect2(180 + index * 430, 325, 385, 105))
		button.item_selected.connect(_role_selected.bind(role, _notebook_surfaces.generation, _notebook_surface_scope()))
		_hotspot_layer.add_child(button)
		_queue_chapter_surface(CHAPTER_SURFACES.role(role, selected), button.text)
		button.get_popup().about_to_popup.connect(_role_menu_displayed.bind(button, role, _notebook_surfaces.generation, _notebook_surface_scope()))
	var names: Array[String] = []
	for phase_index in range(4):
		names.append(_dialogue_ui_text("CH1_CLOCK_PHASE_%d" % phase_index))
	for index in range(4):
		var phase: String = CLOCK.PHASES[index]
		_action("PHASE_%d" % index, names[index] + (_dialogue_ui_text("CH1_CLOCK_SELECTED") if local["phase"] == phase else ""), Rect2(180 + index * 430, 480, 385, 112), "phase", phase, false)
		_queue_chapter_surface(CHAPTER_SURFACES.surface("CLOCK_PHASE_%d_%s" % [index,"SELECTED" if local["phase"] == phase else "UNSELECTED"]), _hotspot_layer.get_node("PHASE_%d" % index).text)
	_action("B3_TEST", _dialogue_ui_text("CH1_CLOCK_TEST"), Rect2(380, 700, 490, 100), "test_clock")
	_add_hotspot("B3_ACTIVATE", _dialogue_ui_text("CH1_CLOCK_ACTIVATE"), Rect2(1020, 700, 530, 100), _confirm_clock)


func _role_menu_displayed(button: OptionButton, role: String, generation: int, scope: Dictionary) -> void:
	if not is_instance_valid(button) or not _notebook_surfaces.live(_notebook_surface_scope(), generation) or scope != _notebook_surface_scope(): return
	var labels := PackedStringArray()
	for index in range(button.item_count): labels.append(button.get_item_text(index))
	_queue_chapter_surface(CHAPTER_SURFACES.surface("CLOCK_MENU_"+role.to_upper()), "\n".join(labels))
	call_deferred("_flush_notebook_surfaces", generation)


func _role_selected(index: int, role: String, generation: int = -1, scope: Dictionary = {}) -> void:
	if generation >= 0 and (not _notebook_surfaces.live(_notebook_surface_scope(), generation) or scope != _notebook_surface_scope()): return
	if index <= 0 or index > CLOCK.CLOCKS.size() or _interaction_blocked() or not _notebook_surface_allowed():
		var button := _hotspot_layer.get_node_or_null("ROLE_"+role) as OptionButton
		if button != null: button.select(CLOCK.CLOCKS.find(session.local_state().roles.get(role, ""))+1)
		return
	_do("role", [role, CLOCK.CLOCKS[index - 1]], false)


func _confirm_clock() -> void:
	_show_recorded_choice(_dialogue_ui_text("CH1_CLOCK_CONFIRM"), _dialogue_ui_text("CH1_CLOCK_WARNING"), [
		{"label": _dialogue_ui_text("CH1_CLOCK_RETEST"), "action": _modal_act.bind("test_clock", null)},
		{"label": _dialogue_ui_text("CH1_CLOCK_COMMIT"), "action": _modal_act.bind("activate_clock", true)},
		{"label": _dialogue_ui_text("CH1_CLOCK_EDIT"), "action": _close_modal},
	], MODAL_NOTES.options("CLOCK_ACTIVATE"))


func _direction(degrees: int) -> String:
	return _dialogue_ui_text("CH1_CLOCK_DIR_%d" % degrees) if degrees in [0, 90, 180, 270] else "?"


func _board_label(text: String, rect: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.018, 0.045, 0.94), Color(0.60, 0.40, 0.30), 2, 6))
	_place(panel, rect)
	_hotspot_layer.add_child(panel)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)


func _notebook_open_block_reason() -> String:
	var reason := super._notebook_open_block_reason()
	if not reason.is_empty(): return reason
	if (_dialogue_active and _history_recorded_index != _dialogue_index) or (not _recorded_modal_request.is_empty() and not _recorded_modal_request.recorded):
		return "표시 중인 기록의 저장을 먼저 완료해 주세요." if not TranslationServer.get_locale().begins_with("en") else "Finish saving the displayed record first."
	return ""


func _notebook_context_node() -> String:
	var displayed := super._notebook_context_node()
	if _dialogue_active or _dialogue_choice_active: return displayed
	if _modal_active and not _recorded_modal_request.is_empty():
		return String(_recorded_modal_request.history_context.get("node_id", ""))
	return session.stage() if session != null else ""


func _notebook_tools() -> Array:
	var tools := super._notebook_tools()
	if tools.is_empty(): return tools
	if session != null and session.stage() in _supported_hint_stages():
		tools.append({"id": "ClockHintsButton", "label": "Organize my thoughts" if TranslationServer.get_locale().begins_with("en") else "생각을 정리한다", "action": _show_clock_hint_menu.bind(0)})
	return tools


func _open_legacy_notebook() -> void:
	if _interaction_blocked():
		return
	var knowledge: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"]
	var notes: Dictionary = knowledge.get("chapter_notebook", {})
	_show_modal(_dialogue_ui_text("UI_NOTE_PERMANENT"), _dialogue_ui_text("UI_NOTE_PERSIST"), [{"label": _dialogue_ui_text("UI_NOTE_CLOSE"), "action": _close_modal}])
	if session.stage() in _supported_hint_stages():
		var hint_button := Button.new()
		hint_button.name = "ClockHintsButton"
		hint_button.text = "Organize my thoughts" if TranslationServer.get_locale().begins_with("en") else "생각을 정리한다"
		hint_button.custom_minimum_size.y = 58
		hint_button.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
		hint_button.pressed.connect(_show_clock_hint_menu.bind(0))
		_modal_body.add_child(hint_button)
	var scroll := _modal_body.get_child(2) as ScrollContainer
	scroll.custom_minimum_size = Vector2(0, 430)
	var label := scroll.get_child(0) as Label
	var pages: Array[String] = []
	for entry in knowledge.get("prologue_notebook_entries", []):
		pages.append(_localized_notebook_entry(String(entry)))
	if pages.is_empty() and knowledge.get("MEM_FATHER_TEA_HAND_FRAGMENT", "") == "sensory_fragment":
		pages.append(_dialogue_ui_text("NOTE_P_TEA"))
	for key in notes:
		var entry := String(notes[key])
		var owner := String(key).trim_prefix("B1_")
		if String(key).begins_with("B1_") and SESSION_SCRIPT.DOCUMENTS.get(owner, "") == entry:
			entry = _dialogue_ui_text("CH1_B1_TEXT_" + owner.to_upper())
		elif key == "B1" and entry == _dialogue_texts.get_text("CH1_B1_SOLVED", "ko-KR"):
			entry = _dialogue_ui_text("CH1_B1_SOLVED")
		pages.append(entry)
	label.text = "\n\n".join(pages) if not pages.is_empty() else _dialogue_ui_text("UI_NOTE_COMPARE_EMPTY")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(round(22 * _reading_text_scale)))
	_cycle_modal_focus()


func _offer_clock_failure_support() -> void:
	if session == null or session.stage() != "BF":
		return
	var failure: Dictionary = session.snapshot()["meta_progress"]["failure_knowledge"].get("B3_B", {})
	var attempts := int(failure.get("attempts", 0))
	if attempts < 2 or failure.get("status", "") != "active":
		return
	var english := TranslationServer.get_locale().begins_with("en")
	var level := mini(attempts, 4)
	var body := ("The clock network has locked %d times. You can request stronger support before sleeping. This does not repair today's pin or alter your choices." if english else "시계망이 %d번 잠겼다. 잠들기 전에 더 구체적인 도움을 요청할 수 있다. 오늘의 핀을 복구하거나 선택을 대신하지는 않는다.") % attempts
	_show_utility_modal("Review the failed attempt" if english else "실패한 시도를 정리한다", body, [
		{"label": "Continue investigating" if english else "조사를 계속한다", "action": _close_modal},
		{"label": ("Request stronger hint H%d" if english else "더 구체적인 H%d 힌트를 요청한다") % (level + 1), "action": _read_clock_hint.bind(level)},
		{"label": "Start with observation hints" if english else "관찰 힌트부터 살펴본다", "action": _show_clock_hint_menu.bind(0)},
	], "failure")


func _supported_hint_stages() -> Array:
	return ["B3_A", "B3_B", "BF"]


func _puzzle_hint_text(level: int) -> String:
	return preload("res://scripts/ui/clock_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())


func _puzzle_hint_title() -> String:
	return "Clock network hints" if TranslationServer.get_locale().begins_with("en") else "시계망 생각 정리"


func _show_clock_hint_menu(level: int) -> void:
	if session == null or session.stage() not in _supported_hint_stages() or level < 0 or level > 5:
		return
	var english := TranslationServer.get_locale().begins_with("en")
	var actions: Array = [{"label": "Close" if english else "닫기", "action": _close_modal}]
	var body := "Hints do not change your puzzle inputs or relationships. Later hints reveal more of the solution." if english else "힌트를 읽어도 퍼즐 입력이나 관계는 바뀌지 않는다. 뒤 단계일수록 해답을 더 구체적으로 알려 준다."
	if level < 5:
		actions.append({"label": ("Read hint H%d" if english else "H%d 힌트를 읽는다") % (level + 1), "action": _read_clock_hint.bind(level)})
	else:
		body = "You have reached the final hint. Review the hints you requested and use the available reversible checks before committing." if english else "마지막 단계의 힌트까지 살펴봤다. 직접 요청한 도움말을 다시 보고, 돌이킬 수 없는 실행 전에 가능한 사전 시험을 활용하자."
	_show_utility_modal(_puzzle_hint_title(), body, actions, "hints", level)
	_cycle_modal_focus()


func _read_clock_hint(level: int) -> void:
	if session == null:
		return
	var text := _puzzle_hint_text(level)
	if text.is_empty():
		return
	_close_modal()
	if _modal_active: return
	var descriptor := preload("res://scripts/systems/notebook_content.gd").hint_descriptor(session.stage(), level)
	_show_dialogue([{"speaker": "주인공", "text": text, "notebook_content": descriptor}], _show_clock_hint_menu.bind(level + 1))
