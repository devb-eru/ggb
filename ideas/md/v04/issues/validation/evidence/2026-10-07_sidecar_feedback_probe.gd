extends Node

const TEST := preload("res://scripts/tests/notebook_final_smoke.gd")
const VIEW := preload("res://scripts/chapters/basement_controller.gd")
var failures: Array = []
var cases: Array = []

class RejectCopy extends Node:
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		return SaveManager.save_snapshot(slot, point, state, revision, transaction)
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)
	func capture_f3_reselect(_slot: String) -> Dictionary:
		return {"ok":false,"error":"DIAGNOSTIC_COPY_REJECTED"}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		var test := TEST.new()
		test._install(test._fixture("F3"))
		test.view = VIEW.new()
		test.view.configure_session(TEST.SLOT, "F3")
		add_child(test.view)
		await get_tree().process_frame
		test.view._dismiss_dialogue_for_test()
		test._present()
		test._press("F3_ENTER")
		test._drain()
		for target in ["WAKE", "STAY", "NOTEBOOK", "SUMMARY"]:
			test._press("F3_" + target)
			test._drain()
		var before: Dictionary = GameState.get_snapshot()
		var controlled := RejectCopy.new()
		add_child(controlled)
		test.view.session._save = controlled
		test._press("F3_OPEN")
		test._drain()
		var after: Dictionary = GameState.get_snapshot()
		var entries: Array = after.meta_progress.dialogue_history.entries.slice(before.meta_progress.dialogue_history.entries.size())
		var raw: Array = entries.filter(func(entry: Dictionary) -> bool: return entry.record_class == "unmapped")
		var authored_open: Array = entries.filter(func(entry: Dictionary) -> bool:
			return entry.record_class == "authored" and entry.observation.content_id == TEST.NOTES.PREFIX + "F3_OPEN")
		var row := {"locale":locale,"stage":test.view.session.stage(),"final_decision":after.ending_run.final_decision,
			"new_unmapped":raw,"authored_open_count":authored_open.size(),"test_errors":test.errors,
			"scope":"FAILED_AUXILIARY_COPY_AFTER_SUCCESSFUL_GAME_SAVE"}
		cases.append(row)
		print("SIDECAR_PROBE_CASE: " + JSON.stringify(row))
		if raw.size() != 1 or not authored_open.is_empty() or test.view.session.stage() != "EDC" or after.ending_run.final_decision != "unset":
			failures.append("EXPECTED_DEFECT_NOT_REPRODUCED:" + locale)
		failures.append_array(test.errors)
		test.view.queue_free()
		controlled.queue_free()
		await get_tree().process_frame
		SaveManager.delete_test_slot(TEST.SLOT)
	print("SIDECAR_PROBE: " + JSON.stringify({"ok":failures.is_empty(),"errors":failures,"case_count":cases.size(),
		"scope":"DEFECT_REPRODUCTION_NOT_PRODUCT_ACCEPTANCE"}))
	get_tree().quit(0 if failures.is_empty() else 1)
