extends RefCounted

const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const SLOT := "__test_notebook_j3_retry_scope"
const OTHER_SLOT := "__test_notebook_j3_retry_scope_other"
const RECEIPT := "EFF_EP02_0049"
const LIMIT := 160
var errors := PackedStringArray()
var assertions := 0
var completed_cases := 0
var label := "preflight"
var view: BlackMirrorController
var saver: ControlledSave


class ControlledSave extends Node:
	var delegate: Node
	var armed := true
	var rejected := 0
	var calls := 0
	var pending_disk: Dictionary = {}
	var rejected_candidate: Dictionary = {}
	var rejected_bytes := {}
	func get_build_flavor() -> String:
		return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		calls += 1
		if slot not in [SLOT, OTHER_SLOT]:
			return {"ok": false, "error_ids": ["ERR_TEST_NON_TEST_SLOT"]}
		if armed and transaction.begins_with("CH1_") and state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).has(RECEIPT):
			rejected += 1
			pending_disk = delegate.load_slot(slot).duplicate(true)
			rejected_candidate = state.duplicate(true)
			var path: String = delegate.get_save_root().path_join(slot)
			for file in DirAccess.get_files_at(path):
				rejected_bytes[file] = FileAccess.get_file_as_bytes(path.path_join(file))
			return {"ok": false, "error_ids": ["ERR_TEST_J3_FINISH_DISK"]}
		return delegate.save_snapshot(slot, point, state, revision, transaction)
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	# Do not change ProjectSettings or preferences; use an editor binary with --ggb-dev-full.
	if not _check(OS.is_debug_build() and SaveManager.get_build_flavor() == "full", "debug full runtime required (--ggb-dev-full)"):
		return _result()
	if not _check("--ggb-dev-notebook-async" not in OS.get_cmdline_user_args(), "synchronous public writer path required"):
		return _result()
	var old_locale := TranslationServer.get_locale()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for mode in ["original", "configure", "presentation", "epoch", "slot", "session", "epoch_represent", "slot_represent", "session_represent"]:
			label = locale + "/" + mode
			print("J3_RETRY_PROGRESS: ", label)
			await _case(tree, mode)
			await _dispose(tree)
			completed_cases += 1
	SaveManager.delete_test_slot(SLOT)
	SaveManager.delete_test_slot(OTHER_SLOT)
	TranslationServer.set_locale(old_locale)
	return _result()


func _case(tree: SceneTree, mode: String) -> void:
	if not _seed(): return
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	if not _drain(): return
	# Use the actual J3 session actions and feedback chain, not a synthetic finish context.
	for spec in [["j3_overlay", null], ["j3_point", "BED"], ["j3_point", "GREEN"], ["j3_point", "CLOCK"], ["j3_compare", null], ["j3_flip_page", null], ["j3_compare", null]]:
		if not _act(spec[0], spec[1]): return
	for index in range(4):
		if not _act("j3_piece", index): return
	if not _check(view.session.mirror_local().j3_order == [0, 1, 2, 3], "actual J3 fragment actions completed"): return
	saver = ControlledSave.new()
	saver.delegate = SaveManager
	view.session._save = saver
	view._do("j3_restore")
	if not _drain(true): return
	if not _check(saver.rejected == 1 and view._modal_active, "real final J3 finish save rejected once; retry modal displayed"): return
	var pending := GameState.get_snapshot()
	_check(CURSOR.read(pending).get("phase") == "finish_pending", "last sentence retained as finish_pending")
	var pending_cursor := CURSOR.read(pending)
	_check(int(pending_cursor.get("index", -1)) == pending_cursor.get("lines", []).size() - 1 and CURSOR.observed(pending_cursor, pending), "finish_pending points to the actually observed last sentence")
	_check(CURSOR.read(saver.rejected_candidate).get("phase") == "completed", "rejected candidate was the real finish_pending-to-completed transition")
	_check(not _receipts(pending).has(RECEIPT), "rejected completion publishes no completion receipt")
	_check(_receipts(saver.rejected_candidate).has(RECEIPT), "injection targets completion, not line/history/cursor persistence")
	_check(saver.pending_disk.get("ok", false), "pending primary disk snapshot validates")
	_check(StateSnapshotValidator.same_persisted_value(pending, saver.pending_disk.get("snapshot", {})), "full rollback snapshot equals durable finish_pending snapshot")
	_check(_disk()[SLOT] == saver.rejected_bytes, "rejected completion leaves primary/backup/temporary bytes unchanged")
	_check(_count_content(pending, "NB_EP02_J3_UI_COMMIT_DONE") == 0, "completion notice is not disclosed before successful finish")
	var button := _retry_button()
	if button == null: return
	var connections := button.get_signal_connection_list("pressed")
	if not _check(connections.size() == 1, "displayed retry has one actual pressed connection"): return
	var callback: Callable = connections[0].callable
	_check(callback.is_valid(), "actual UI connection callable is valid")
	print("J3_RETRY_CONNECTION: ", label, " method=", callback.get_method(), " bound=", callback.get_bound_arguments_count())
	saver.armed = false
	if mode == "original":
		button.pressed.emit()
		if not _drain(): return
		var finished := GameState.get_snapshot()
		_check(_receipts(finished).get(RECEIPT, false), "original retry commits completion receipt")
		_check(CURSOR.read(finished).get("phase") == "completed", "original retry completes final presentation")
		_check(SaveManager.inspect_slot(SLOT).get("save_point_id") == "SAVE_J3_COMPLETE", "original retry reaches real J3 checkpoint")
		_check(_count_content(finished, "NB_EP02_J3_UI_COMMIT_DONE") == 1, "original retry discloses completion notice exactly once")
		_check(StateSnapshotValidator.same_persisted_value(finished, SaveManager.load_slot(SLOT).get("snapshot", {})), "original retry full memory/disk snapshots agree")
		_check_unique(finished)
		# A retained UI connection must not republish a completed continuation.
		await _probe(tree, callback, "completed_original")
		return
	var old_scope := view._recorded_choice_scope()
	var old_generation := view._choice_modal_generation
	if mode == "configure":
		view._close_modal()
		view.configure_session(SLOT, "MORNING_ROUTE")
		view._render_room()
	elif mode == "presentation":
		view._close_modal()
		view._ep01_play("EP02_J3_DOC_001")
	else:
		if mode.begins_with("epoch"):
			if not _check(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "real reload replaces load epoch"): return
		elif mode.begins_with("slot"):
			view.configure_session(OTHER_SLOT, "MORNING_ROUTE")
			view.session.slot_id = OTHER_SLOT
			if not _check(SaveManager.save_snapshot(OTHER_SLOT, "SAVE_CAMPAIGN_PROGRESS", GameState.get_snapshot(), GameState.revision, "J3_RETRY_OTHER_SLOT").get("ok", false), "dedicated destination slot saved"): return
		elif mode.begins_with("session"):
			view.session = view._make_session()
			view.session._save = saver
		if mode.ends_with("_represent"):
			view._close_modal()
			view._ep01_play("EP02_J3_DOC_001")
	if mode in ["configure", "presentation"]:
		_check(old_scope == view._recorded_choice_scope() and old_generation != view._choice_modal_generation, "same controller scope but old modal generation retired")
	else:
		_check(old_scope != view._recorded_choice_scope(), "original epoch/slot/session scope retired")
	if mode.ends_with("_represent"):
		_check(view._presentation_scope == view._recorded_choice_scope(), "replacement presentation legitimately owns current scope")
	if mode == "presentation" or mode.ends_with("_represent"):
		if not _check(view._dialogue_active, "different real presentation is displayed before stale retry"): return
		_check(view._dialogue_lines[view._dialogue_index].presentation_token != pending_cursor.lines[pending_cursor.index].presentation_token, "replacement presentation has a distinct displayed token")
	# This is the callable extracted from pressed, including any product wrapper.
	# Never construct _ep01_retry_finish.bind(...) or unwrap its bound action.
	await _probe(tree, callback, mode)


func _probe(tree: SceneTree, callback: Callable, context: String) -> void:
	# Settle ordinary deferred rendering before attributing effects to the callback.
	for frame in range(3): await tree.process_frame
	var before := GameState.get_snapshot()
	var revision: int = GameState.revision
	var disk := _disk()
	var ui := _ui()
	var calls := saver.calls
	for attempt in range(2):
		callback.call()
		for frame in range(3): await tree.process_frame
		_check(GameState.get_snapshot() == before and GameState.revision == revision, context + ": stale UI callable preserves full snapshot/revision #%d" % attempt)
		_check(_disk() == disk, context + ": stale UI callable preserves all slot bytes #%d" % attempt)
		_check(_ui() == ui, context + ": stale UI callable preserves replacement UI #%d" % attempt)
		_check(saver.calls == calls, context + ": stale UI callable does not attempt persistence #%d" % attempt)
		_check(_receipts(GameState.get_snapshot()) == _receipts(before), context + ": no completion receipt publication")
		_check(GameState.get_snapshot().meta_progress.dialogue_history == before.meta_progress.dialogue_history, context + ": no duplicate public disclosure")
		_check_unique(GameState.get_snapshot())


func _seed() -> bool:
	SaveManager.delete_test_slot(SLOT)
	SaveManager.delete_test_slot(OTHER_SLOT)
	var fixture: Dictionary = CHECKPOINTS.new().snapshot_for("J3")
	if not _check(fixture.get("ok", false), "canonical J3 fixture"): return false
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.loop_state.location_id = "M1_LIBRARY_INNER"
	state.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "absent"
	GameState.reset_for_test()
	return _check(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"J3_RETRY_FIXTURE").get("ok", false), "fixture installed through real writer")


func _act(action: String, value: Variant) -> bool:
	view._do(action, value)
	return _drain()


func _drain(stop_on_retry: bool = false) -> bool:
	for step in range(LIMIT):
		if stop_on_retry and view._modal_active: return true
		if not view._dialogue_active: return true
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		var before := GameState.get_snapshot()
		view._present_dialogue_line()
		if not _check(GameState.get_snapshot() == before, "line redraw is idempotent step %d" % step): return false
		view._advance_dialogue()
		if view._dialogue_active and not view._modal_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			return _check(false, "bounded dialogue blocked at " + token)
	return _check(false, "dialogue exceeds bound %d" % LIMIT)


func _retry_button() -> Button:
	for child in view._modal_body.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled and child.text == ("Retry" if TranslationServer.get_locale().begins_with("en") else "\ub2e4\uc2dc \uc2dc\ub3c4"):
			return child
	_check(false, "actual visible enabled retry button exists")
	return null


func _disk() -> Dictionary:
	var result := {}
	for slot in [SLOT, OTHER_SLOT]:
		var path := SaveManager.get_save_root().path_join(slot)
		var files := {}
		if DirAccess.dir_exists_absolute(path):
			for file in DirAccess.get_files_at(path):
				files[file] = FileAccess.get_file_as_bytes(path.path_join(file))
		result[slot] = files
	return result


func _ui() -> Dictionary:
	return {"modal": view._modal_active, "dialogue": view._dialogue_active, "lines": view._dialogue_lines.duplicate(true),
		"index": view._dialogue_index, "choice_generation": view._choice_modal_generation, "history_generation": view._history_generation,
		"scope": view._presentation_scope.duplicate(true), "status": view._status_label.text}


func _receipts(state: Dictionary) -> Dictionary:
	return state.get("meta_progress", {}).get("event_history", {}).get("EP02_DIALOGUE_EFFECTS", {})


func _count_content(state: Dictionary, id: String) -> int:
	var count := 0
	for entry in state.meta_progress.dialogue_history.entries:
		if entry.get("observation", {}).get("content_id") == id: count += 1
	return count


func _check_unique(state: Dictionary) -> void:
	var seen := {}
	_check(ARCHIVE.validate(state.meta_progress.dialogue_history).get("ok", false), "complete public archive validates")
	for entry in state.meta_progress.dialogue_history.entries:
		var token: String = entry.get("observation", {}).get("presentation_token", entry.get("snapshot_context", {}).get("presentation_token", ""))
		if token.is_empty(): continue
		_check(not seen.has(token), "presentation token disclosed once: " + token)
		seen[token] = true
	_check(_count_content(state, "NB_EP02_J3_UI_COMMIT_DONE") <= 1, "completion notice has no duplicate publication")


func _dispose(tree: SceneTree) -> void:
	if is_instance_valid(view):
		view.session._save = SaveManager
		view.queue_free()
	await tree.process_frame
	view = null
	if is_instance_valid(saver): saver.free()
	saver = null


func _check(condition: bool, message: String) -> bool:
	assertions += 1
	print("J3_RETRY_ASSERT: ", label, " ", "PASS " if condition else "FAIL ", message)
	if not condition: errors.append(label + ": " + message)
	return condition


func _result() -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors, "cases": completed_cases, "assertions": assertions,
		"scope": "actual pressed callable; original retry and retired same-controller UI/scope",
		"not_covered": ["OS input delivery", "async writer opt-in", "process restart", "engine execution during authoring"]}
