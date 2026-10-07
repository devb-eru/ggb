extends Node

const TEST := preload("res://scripts/tests/notebook_final_smoke.gd")
const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const LABELS := preload("res://scripts/ui/basement_display_texts.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
var failures: Array = []
var cases: Array = []
var serial := 0

class ControlledSave extends Node:
	var reject_copy := false
	var reject_history := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject_history and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["REGRESSION_HISTORY_REJECTED"]}
		return SaveManager.save_snapshot(slot, point, state, revision, transaction)
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)
	func capture_f3_reselect(slot: String) -> Dictionary:
		return {"ok":false,"error":"REGRESSION_COPY_REJECTED"} if reject_copy else SaveManager.capture_f3_reselect(slot)

class RejectMeta extends RefCounted:
	func commit_completed(_state: Dictionary) -> Dictionary:
		return {"ok":false,"error":"REGRESSION_META_REJECTED"}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for reject in [false, true]:
			await _f3(reject)
			for branch in ["reality", "stay"]: await _credits(branch, reject)
		await _f3_history_failure()
	print("SIDECAR_REGRESSION: " + JSON.stringify({"ok":failures.is_empty(),"errors":failures,"cases":cases,
		"case_count":cases.size(),"notebook_v2":ROLLOUT.enabled(),"scope":"AUXILIARY_SAVE_WARNINGS_NOT_FULL_CAMPAIGN_OR_OS_INPUT"}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _view(stage: String) -> BasementController:
	var fixture := TEST.new()._fixture(stage)
	fixture.meta_progress.dialogue_history = ROLLOUT.new_history()
	GameState.reset_for_test()
	serial += 1
	var token := StringName("SIDECAR_FIXTURE_%d" % serial)
	_expect(StateWriter.new(GameState).install_snapshot(fixture, GameState.revision, token).ok, "install")
	_expect(SaveManager.save_snapshot(TEST.SLOT, "SAVE_CAMPAIGN_PROGRESS", GameState.get_snapshot(), GameState.revision, String(token)).ok, "save fixture")
	var view := VIEW.new()
	view.configure_session(TEST.SLOT, stage)
	add_child(view)
	return view

func _f3(reject: bool) -> void:
	var view := _view("F3")
	await get_tree().process_frame
	view._dismiss_dialogue_for_test()
	view.set_process(false)
	_press(view, "F3_ENTER")
	for target in ["WAKE", "STAY", "NOTEBOOK", "SUMMARY"]: _press(view, "F3_" + target)
	var before: Dictionary = GameState.get_snapshot()
	var controlled := ControlledSave.new()
	controlled.reject_copy = reject
	add_child(controlled)
	view.session._save = controlled
	_press(view, "F3_OPEN")
	var after: Dictionary = GameState.get_snapshot()
	var entries: Array = after.meta_progress.dialogue_history.entries.slice(before.meta_progress.dialogue_history.entries.size())
	var authored_count := 0
	for entry in entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == TEST.NOTES.PREFIX + "F3_OPEN": authored_count += 1
		var body := String(entry.get("legacy_payload", entry).get("variables", {}).get("text", ""))
		_expect(not body.contains("다른 선택 확인용") and not body.contains("reviewing another choice"), "warning excluded from transcript")
		if ROLLOUT.enabled(): _expect(entry.record_class == "authored", "no new unmapped")
	if ROLLOUT.enabled(): _expect(authored_count == 1, "authored F3_OPEN exactly once")
	var feedback: Dictionary = after.loop_state.event_local_states.CHAPTER_ONE.last_feedback
	_expect(feedback.text == "최종 선택 확인 단계가 열렸다. 아직 결정이 저장되지는 않았다.", "original stored feedback")
	_expect(view.session.stage() == "EDC" and after.ending_run.final_decision == "unset", "progress success and neutral choice")
	if reject: _expect(view._status_label.text == LABELS.ui("f3_copy_save_warning", TranslationServer.get_locale()), "localized UI warning")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(TEST.SLOT).ok, "F3 reload")
	_expect(StateSnapshotValidator.same_persisted_value(after, GameState.get_snapshot()), "F3 persisted unchanged")
	cases.append({"kind":"F3","reject":reject,"locale":TranslationServer.get_locale(),"new_entries":entries.size(),"authored_open":authored_count,"stage":view.session.stage()})
	view.queue_free()
	controlled.queue_free()
	await get_tree().process_frame
	SaveManager.delete_test_slot(TEST.SLOT)

func _credits(branch: String, reject: bool) -> void:
	var view := _view("EDR_FINAL_FRAME" if branch == "reality" else "EDS_FINAL_FRAME")
	await get_tree().process_frame
	view._dismiss_dialogue_for_test()
	view.set_process(false)
	if reject: view.session.ending_meta_store = RejectMeta.new()
	if branch == "reality":
		for step in range(7): _expect(view.session.act("surface_tick").ok, "final frame tick")
	else:
		for step in range(2): _expect(view.session.act("story_tick").ok, "final frame tick")
	var before: Dictionary = GameState.get_snapshot()
	var result: Dictionary = view.session.act("surface_tick" if branch == "reality" else "story_finish")
	_expect(result.ok and result.text.is_empty(), "empty original feedback preserved")
	_expect(result.get("auxiliary_warning", "") == ("ending_meta_save_warning" if reject else ""), "warning metadata only")
	view._render_room()
	view._feedback(result)
	var after: Dictionary = GameState.get_snapshot()
	_expect(not view._dialogue_active, "no artificial credits dialogue")
	_expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.dialogue_history, after.meta_progress.dialogue_history), "credits warning cannot write history")
	_expect(after.ending_run.current_node_id == ("CREDITS_REALITY" if branch == "reality" else "CREDITS_STAY"), "credits reached")
	if reject: _expect(view._status_label.text == LABELS.ui("ending_meta_save_warning", TranslationServer.get_locale()), "localized credits warning")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(TEST.SLOT).ok, "credits reload")
	_expect(StateSnapshotValidator.same_persisted_value(after, GameState.get_snapshot()), "credits persisted unchanged")
	cases.append({"kind":"CREDITS","branch":branch,"reject":reject,"locale":TranslationServer.get_locale()})
	view.queue_free()
	await get_tree().process_frame
	SaveManager.delete_test_slot(TEST.SLOT)

func _f3_history_failure() -> void:
	var view := _view("F3")
	await get_tree().process_frame
	view._dismiss_dialogue_for_test()
	view.set_process(false)
	_press(view, "F3_ENTER")
	for target in ["WAKE", "STAY", "NOTEBOOK", "SUMMARY"]: _press(view, "F3_" + target)
	var before: Dictionary = GameState.get_snapshot()
	var controlled := ControlledSave.new()
	controlled.reject_copy = true
	controlled.reject_history = true
	add_child(controlled)
	view.session._save = controlled
	var button := view._hotspot_layer.get_node_or_null("F3_OPEN") as Button
	_expect(button != null, "open button")
	if button != null: button.pressed.emit()
	_expect(view.session.stage() == "EDC" and view._dialogue_active, "game saved while failed display remains open")
	_expect(view._status_label.text == view._dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"), "history error takes priority over sidecar warning")
	_expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.dialogue_history, GameState.get_snapshot().meta_progress.dialogue_history), "failed display cannot record warning or story")
	var pending := GameState.get_snapshot()
	view._advance_dialogue()
	_expect(StateSnapshotValidator.same_persisted_value(pending, GameState.get_snapshot()), "rejected retry cannot advance")
	controlled.reject_history = false
	view._advance_dialogue()
	_expect(not view._dialogue_active and GameState.get_snapshot().ending_run.final_decision == "unset", "history retry finishes only original story")
	var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.slice(before.meta_progress.dialogue_history.entries.size())
	var count := 0
	for entry in entries:
		if ROLLOUT.enabled():
			_expect(entry.record_class == "authored", "retry no unmapped")
			if entry.observation.content_id == TEST.NOTES.PREFIX + "F3_OPEN": count += 1
	if ROLLOUT.enabled(): _expect(count == 1, "retry original observation once")
	cases.append({"kind":"F3_HISTORY_FAILURE","locale":TranslationServer.get_locale(),"authored_open":count})
	view.queue_free()
	controlled.queue_free()
	await get_tree().process_frame
	SaveManager.delete_test_slot(TEST.SLOT)

func _press(view: BasementController, id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing button " + id)
	if button != null: button.pressed.emit()
	for step in range(60):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false, "dialogue blocked")

func _expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label + ":" + TranslationServer.get_locale())
