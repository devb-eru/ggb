extends RefCounted

const VIEW := preload("res://scenes/prologue/prologue.tscn")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const EXPECTED := "user://__test_prologue_cursor_expected.json"
const SLOT := "__test_prologue_cursor"
var errors := PackedStringArray()
var checks := 0

class ControlledSave extends Node:
	var reject := false
	var reject_dialogue := false
	var lose_ack := false
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var cursor := CURSOR.read(state)
		if reject or (reject_dialogue and cursor.get("kind") == "dialogue"): return {"ok": false, "error_id": "TEST_PROLOGUE_SAVE"}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_id": "TEST_PROLOGUE_ACK"} if lose_ack and result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var phase := "seed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor-phase="): phase = arg.trim_prefix("--cursor-phase=")
	TranslationServer.set_locale("ko-KR" if phase == "seed" else "en-US")
	if phase == "seed":
		await _cases(tree)
		if not errors.is_empty(): return {"ok": false, "errors": errors}
		var expected := {"pid": OS.get_process_id(), "cases": {}}
		for event in ["P1", "P3", "P4", "P6", "R1"]:
			var slot: String = SLOT + "_" + event.to_lower()
			var view = _fresh(tree, slot)
			if event != "P1":
				_drain(view)
				_prepare(view, event)
			match event:
				"P1": view._advance_dialogue()
				"P3": view._show_p3_journal_choices()
				"P4":
					view._show_p4_father_choices()
					_pick(view, "luca_tenure")
					view._advance_dialogue()
				"P6":
					view._on_sleep_bed()
					view._prologue_confirmation_pressed(view._prologue_confirmation, "confirm")
					view._advance_dialogue()
				"R1":
					view._progress.P6_complete = true
					_expect(view._save_progress("SAVE_P6_COMPLETE", true), "R1 fixture records prior sleep")
					_expect(tree.current_scene.request_sleep_transition(slot).ok, "R1 fixture executes actual reset")
					view._progress = view._default_progress()
					view._show_after_reset()
					view._advance_dialogue()
			expected.cases[event] = {"slot": slot, "cursor": CURSOR.read(GameState.get_snapshot()), "archive": GameState.get_snapshot().meta_progress.dialogue_history}
			_expect(not expected.cases[event].cursor.is_empty(), "seed cursor exists: " + event)
			_expect(expected.cases[event].cursor.get("phase") != "completed", "seed retains unfinished presentation: " + event)
			view.queue_free()
			await tree.process_frame
		var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
		file.store_string(JSON.stringify(expected))
		file.close()
	elif phase in ["resume", "completed"]:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		_expect(int(expected.pid) != OS.get_process_id(), "a distinct operating-system process reloads fixtures")
		for event in expected.cases:
			var row: Dictionary = expected.cases[event]
			_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(row.slot).ok, "disk reload: " + event)
			var before := GameState.get_snapshot()
			var view = _view(tree, row.slot)
			_expect(_same(before, GameState.get_snapshot()), "restoring is read-only: " + event)
			if phase == "completed":
				_expect(not view._dialogue_active and not view._dialogue_choice_active, "completed presentation does not replay: " + event)
				SaveManager.delete_test_slot(row.slot)
			elif event == "P3":
				_expect(view._dialogue_choice_active and view._choice_history_context.presentation_token == row.cursor.lines[0].presentation_token, "choice occurrence restored without executing a selection")
				_expect(view._dialogue_label.text == CURSOR.localized_choice(row.cursor, "en-US").prompt, "choice restores current-language prompt")
				_pick(view, "silent")
				_expect(not view._dialogue_choice_active, "explicit restored P3 silent choice closes: " + view._status_label.text)
			else:
				_expect(view._dialogue_active and view._dialogue_index == int(row.cursor.index), "exact line index restored: " + event)
				if not view._dialogue_active:
					view.queue_free()
					await tree.process_frame
					continue
				_expect(view._dialogue_lines[view._dialogue_index].presentation_token == row.cursor.lines[int(row.cursor.index)].presentation_token, "same display token: " + event)
				_expect(view._dialogue_label.text == CONTENT.presentation(row.cursor.lines[int(row.cursor.index)].notebook_content, "en-US").text, "current language from captured descriptor: " + event)
				_drain(view)
				if event == "P6":
					await tree.create_timer(3.0).timeout
					_drain(view)
			view.queue_free()
			await tree.process_frame
	else:
		_expect(false, "unknown phase")
	print("NOTEBOOK_PROLOGUE_PRESENTATION_CHECKS: ", phase, " ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _cases(tree: SceneTree) -> void:
	var view = _fresh(tree)
	var first := CURSOR.read(GameState.get_snapshot())
	_expect(CURSOR.matches(first, GameState.get_snapshot()) and CURSOR.observed(first, GameState.get_snapshot()), "P1 has an observed matching cursor")
	if first.is_empty():
		print("PROLOGUE_CURSOR_DIAGNOSTIC: ", view._status_label.text, " spec=", view._prologue_dialogue_spec(), " history=", GameState.get_snapshot().meta_progress.dialogue_history)
		view.queue_free()
		await tree.process_frame
		return
	_expect(not _has_token(first.lines[1].presentation_token), "future line is not disclosed")
	view._advance_dialogue()
	var prior := GameState.get_snapshot()
	var failing := ControlledSave.new()
	failing.reject = true
	view._prologue_surface_saves = failing
	view._advance_dialogue()
	_expect(_same(GameState.get_snapshot(), prior), "failed next line rolls back gameplay, archive and cursor together")
	_expect(view._prologue_history_index == 1 and view._dialogue_index == 2, "unsaved visible line awaits retry")
	failing.reject = false
	failing.lose_ack = true
	_expect(view._record_prologue_history(), "exact saved snapshot recovers a lost acknowledgement")
	_expect(CURSOR.read(GameState.get_snapshot()).index == 2, "retry persists exact line")
	view._prologue_surface_saves = null
	failing.free()
	_drain(view)
	var completed := GameState.get_snapshot()
	view = await _reload(tree, view)
	_expect(not view._dialogue_active and _same(completed, GameState.get_snapshot()), "P1 completed intro does not replay")
	view._leave_bedroom_morning()
	var modal := CURSOR.read(GameState.get_snapshot())
	_expect(modal.kind == "choice" and modal.choice.mode == "P1_EXIT", "departure confirmation has a cursor")
	var incomplete: Dictionary = modal.duplicate(true)
	incomplete.choice.order = ["confirm"]
	incomplete.choice.labels.erase("cancel")
	_expect(not CURSOR.valid(incomplete), "confirmation must retain both fixed actions")
	var stale: Dictionary = view._prologue_confirmation
	view = await _reload(tree, view)
	_expect(view._modal_active and view._prologue_confirmation.recorded and not view._progress.P1_complete, "modal restores without confirming")
	view._prologue_confirmation_pressed(stale, "confirm")
	_expect(not view._progress.P1_complete, "pre-load confirmation cannot execute")
	view._prologue_confirmation_pressed(view._prologue_confirmation, "cancel")
	_expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "cancel completion saved")
	_prepare(view, "P3")
	view._show_p3_journal_choices()
	failing = ControlledSave.new()
	failing.reject_dialogue = true
	view._prologue_surface_saves = failing
	_pick(view, "author")
	var selected := GameState.get_snapshot()
	_expect(CURSOR.read(selected).phase == "selection_pending", "selection durable while its answer save fails")
	_expect(not selected.loop_state.event_local_states.PROLOGUE.p3_journal_questions_asked.has("author"), "failed answer does not commit its gameplay")
	var selected_token: String = CURSOR.read(selected).choice.tokens.author
	view._prologue_surface_saves = null
	failing.free()
	view = await _reload(tree, view)
	_expect(view._dialogue_choice_active and not view._dialogue_active, "pending selection restores choices, never executes answer")
	_expect(_count_token(selected_token) == 1, "restart preserves one selection record")
	for attempt in range(3):
		var retry: String = ["author", "locked", "author"][attempt]
		failing = ControlledSave.new()
		failing.reject_dialogue = true
		view._prologue_surface_saves = failing
		_pick(view, retry)
		var pending := CURSOR.read(GameState.get_snapshot())
		_expect(pending.phase == "selection_pending" and pending.choice.last_selected == retry, "failed answer leaves the explicitly selected intent pending: " + retry)
		if attempt == 0: _expect(pending.choice.tokens.author == selected_token, "same pending selection reuses its saved token")
		view._prologue_surface_saves = null
		failing.free()
		view = await _reload(tree, view)
		_expect(_count_token(selected_token) == 1, "same pending retry never duplicates its original token")
	_expect(CURSOR.read(GameState.get_snapshot()).choice.tokens.author != selected_token, "A to B to A is a new user intent, not a retry of the first A")
	_pick(view, "locked")
	_expect(view._dialogue_active and view._dialogue_lines[0].notebook_content.content_id == "NB_PR_P3_A_LOCKED", "player may explicitly choose a different answer after restart")
	_expect(not _has_content("NB_PR_P3_A_AUTHOR"), "unsaved answer is absent from persisted public archive")
	_drain(view)
	_pick(view, "silent")
	_expect(not view._dialogue_choice_active, "P3 silent completion remains usable")
	_expect(_has_content("NB_PROLOGUE_SURFACE_P3_SILENT_STATUS"), "post-choice status survives the same-room rebuild transaction")
	_prepare(view, "P4")
	view._show_p4_father_choices()
	var choice := CURSOR.read(GameState.get_snapshot())
	for field in ["after", "choice", "lines"]:
		var invalid: Dictionary = choice.duplicate(true)
		invalid[field] = 42
		_expect(not CURSOR.valid(invalid), "malformed choice rejected: " + field)
	var v1: Dictionary = first.duplicate(true)
	v1.family = "chapter_one_controller"
	v1.schema_version = 1
	v1.after = {}
	_expect(CURSOR.valid(v1), "version 1 shared cursor stays readable")
	view = await _reload(tree, view)
	_expect(view._dialogue_choice_active and view._progress.p4_father_question == "", "P4 question restore does not select an answer")
	_pick(view, "luca_tenure")
	_expect(CURSOR.read(GameState.get_snapshot()).kind == "dialogue" and view._progress.p4_father_question == "luca_tenure", "P4 answer cursor and selected gameplay commit together")
	view._advance_dialogue()
	var p4 := GameState.get_snapshot()
	view = await _reload(tree, view)
	_expect(view._dialogue_index == 1 and _same(p4, GameState.get_snapshot()), "P4 multi-line answer resumes at second line")
	_drain(view)
	_expect(view._progress.iris_greeting_seen and view._current_room == "M1_CENTRAL_HALL", "P4 and Iris continuations complete normally")
	_prepare(view, "P6")
	view._on_sleep_bed()
	view = await _reload(tree, view)
	_expect(view._modal_active and not view._progress.P6_complete, "sleep confirmation awaits explicit input after restart")
	view._prologue_confirmation_pressed(view._prologue_confirmation, "confirm")
	_expect(GameState.get_value("meta_progress.knowledge_entries.PROLOGUE_COMPLETE", false) and CURSOR.resume_family(GameState.get_snapshot()) == "prologue_controller", "completion flag cannot skip unfinished P6 lines")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "bootstrap P6 reload")
	tree.current_scene._launch_prologue(SLOT, "P1_ENTRY")
	view = tree.current_scene._prologue
	_expect(view._uses_prologue_history() and view._dialogue_active and GameState.get_value("loop_state.day_index", 0) == 0, "bootstrap keeps P6 before physical reset")
	_drain(view)
	await tree.create_timer(3.0).timeout
	_expect(GameState.get_value("loop_state.day_index", 0) == 1 and view._dialogue_active, "normal reset opens R1")
	_drain(view)
	await tree.process_frame
	view = tree.current_scene._prologue
	_expect(CURSOR.family(view) == "chapter_one_controller" and view._dialogue_active, "R1 handoff preserves the new chapter's first dialogue")
	_expect(view._dialogue_lines[0].notebook_content.content_id == "NB_CH1_WAKE", "A1 wake instruction is not mistaken for already-read R1")
	var entry_state := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "A1 entry reload")
	tree.current_scene._launch_prologue(SLOT, "P1_ENTRY")
	view = tree.current_scene._prologue
	_expect(view._dialogue_active and _same(entry_state, GameState.get_snapshot()), "A1 entry reload neither duplicates R1 nor appends the wake line again")
	view.queue_free()
	tree.current_scene._prologue = null
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)


func _prepare(view: Node, event: String) -> void:
	view._progress.P1_complete = true
	if event == "P3":
		view._progress.current_room = "M1_LIBRARY_OUTER"
		view._progress.p3_journal_seen = true
		view._progress.p3_journal_choice = "pending"
		view._mark_intro("P3")
		view._p3_journal_prompt_active = true
	elif event == "P4":
		view._progress.current_room = "M1_KITCHEN"
		view._progress.tea_step = 6
		view._progress.p4_memory_anchor_seen = true
		view._progress.p4_phase = "memory_anchor_ready"
		view._mark_intro("P4")
	else:
		view._progress.current_room = "M2_BEDROOM"
		view._progress.P4_complete = true
		view._mark_intro("P6")
	view._prologue_surfaces.begin({})
	view._enter_room(view._progress.current_room)
	_drain(view)


func _fresh(tree: SceneTree, slot: String = SLOT) -> Node:
	SaveManager.delete_test_slot(slot)
	GameState.reset_for_test()
	return _view(tree, slot)


func _view(tree: SceneTree, slot: String) -> Node:
	var view := VIEW.instantiate()
	view.configure_session(slot, "P1_ENTRY", false)
	tree.current_scene.add_child(view)
	return view


func _reload(tree: SceneTree, view: Node) -> Node:
	var slot: String = view._slot_id
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(slot).ok, "load installs saved slot")
	return _view(tree, slot)


func _drain(view: Node) -> void:
	for i in range(40):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false, "dialogue did not terminate")


func _pick(view: Node, id: String) -> void:
	for i in range(view._dialogue_choice_buttons.size()):
		if view._dialogue_choice_buttons[i].get_meta("choice_id", "") == id:
			view._on_dialogue_choice_pressed(i)
			return
	_expect(false, "missing choice: " + id)


func _count_token(token: String) -> int:
	var count := 0
	for entry in GameState.get_snapshot().meta_progress.dialogue_history.entries:
		if entry.get("observation", {}).get("presentation_token") == token: count += 1
	return count


func _has_token(token: String) -> bool:
	return _count_token(token) > 0


func _has_content(id: String) -> bool:
	for entry in GameState.get_snapshot().meta_progress.dialogue_history.entries:
		if entry.get("observation", {}).get("content_id") == id: return true
	return false


func _same(a: Dictionary, b: Dictionary) -> bool:
	return StateSnapshotValidator.same_persisted_value(a, b)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(message)
