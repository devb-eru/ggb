class_name FoundationSmokeRunner
extends RefCounted

const TEST_SLOT := "__test_foundation"


func run() -> Dictionary:
	var errors := PackedStringArray()
	SaveManager.delete_test_slot(TEST_SLOT)
	GameState.reset_for_test()
	var writer := StateWriter.new(GameState)

	var invalid_result := writer.commit_atomic(
		[{"state_path": "meta_progress.undeclared", "operation": "set", "value": true}],
		GameState.revision,
		&"TEST_INVALID_PATH"
	)
	_expect(not bool(invalid_result.get("ok", false)), "undeclared path accepted", errors)
	_expect(GameState.revision == 0, "invalid path changed revision", errors)

	var valid_result := writer.commit_atomic(
		[{"state_path": "meta_progress.journal_stage", "operation": "set", "value": 1}],
		GameState.revision,
		&"TEST_VALID_WRITE"
	)
	_expect(bool(valid_result.get("ok", false)), "valid write rejected", errors)
	var stale_result := writer.commit_atomic(
		[{"state_path": "meta_progress.journal_stage", "operation": "set", "value": 2}],
		0,
		&"TEST_STALE_WRITE"
	)
	_expect(not bool(stale_result.get("ok", false)), "stale revision accepted", errors)
	_expect(GameState.revision == 1, "stale write changed revision", errors)

	GameState.reset_for_test()
	var signal_order: Array[String] = []
	var started_callback := func(_event_id: StringName, _node_id: StringName) -> void:
		signal_order.append("started")
	var committed_callback := func(_transaction_id: StringName, _revision: int, _paths: PackedStringArray) -> void:
		signal_order.append("committed")
	var completed_callback := func(_event_id: StringName, _result_id: StringName) -> void:
		signal_order.append("completed")
	EventManager.event_started.connect(started_callback, CONNECT_ONE_SHOT)
	GameState.state_committed.connect(committed_callback, CONNECT_ONE_SHOT)
	EventManager.event_completed.connect(completed_callback, CONNECT_ONE_SHOT)
	var event_ok := EventManager.request_event(
		&"FOUNDATION_SMOKE",
		&"OBJ_FOUNDATION_CONSOLE",
		{"slot_id": TEST_SLOT}
	)
	_expect(event_ok, "foundation event rejected", errors)
	_expect(signal_order == ["started", "committed", "completed"], "event signal order mismatch", errors)
	_expect(GameState.get_value(&"meta_progress.notebook_persistence_confirmed", false), "event bool effect missing", errors)
	_expect(GameState.get_value(&"meta_progress.journal_stage", 0) == 1, "event journal effect missing", errors)

	var first_snapshot := GameState.get_snapshot()
	var loaded := SaveManager.load_slot(TEST_SLOT)
	_expect(bool(loaded.get("ok", false)), "saved snapshot did not reload", errors)
	_expect(_equivalent(loaded.get("snapshot", {}), first_snapshot), "reloaded snapshot differs", errors)

	var second_write := writer.commit_atomic(
		[{"state_path": "meta_progress.journal_stage", "operation": "set", "value": 2}],
		GameState.revision,
		&"TEST_BACKUP_WRITE"
	)
	_expect(bool(second_write.get("ok", false)), "backup preparation write failed", errors)
	var second_save := SaveManager.save_snapshot(
		TEST_SLOT,
		"SAVE_FOUNDATION_BACKUP",
		GameState.get_snapshot(),
		GameState.revision,
		"TEST_BACKUP_SAVE"
	)
	_expect(bool(second_save.get("ok", false)), "backup preparation save failed", errors)
	_corrupt_primary(TEST_SLOT)
	var recovered := SaveManager.load_slot(TEST_SLOT)
	_expect(bool(recovered.get("ok", false)), "corrupt primary did not recover", errors)
	_expect(String(recovered.get("source", "")) == "backup", "recovery source was not backup", errors)
	_expect(_equivalent(recovered.get("snapshot", {}), first_snapshot), "backup recovery snapshot differs", errors)

	_write_future_schema(TEST_SLOT)
	var future_result := SaveManager.load_slot(TEST_SLOT)
	_expect(future_result.get("error_id", &"") == &"ERR_SAVE_FUTURE_SCHEMA", "future schema was not refused", errors)

	for action_name in [
		"interact_confirm",
		"ui_cancel",
		"notebook_toggle",
		"inventory_toggle",
		"focus_next",
		"focus_previous",
	]:
		_expect(InputMap.has_action(action_name), "missing input action: %s" % action_name, errors)

	SaveManager.delete_test_slot(TEST_SLOT)
	GameState.reset_for_test()
	return {"ok": errors.is_empty(), "errors": errors}


func _corrupt_primary(slot_id: String) -> void:
	var path := "user://saves/%s/progress.json" % slot_id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("{corrupted-primary")
		file.close()


func _write_future_schema(slot_id: String) -> void:
	var path := "user://saves/%s/progress.json" % slot_id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"save_header": {"schema_version": SaveManager.SCHEMA_VERSION + 1},
			"state": {},
		}))
		file.close()


func _expect(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(message)


func _equivalent(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _equivalent(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _equivalent(left[index], right[index]):
				return false
		return true
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(left), float(right))
	return left == right
