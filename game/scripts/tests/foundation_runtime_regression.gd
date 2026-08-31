class_name FoundationRuntimeRegression
extends RefCounted

const LOAD_SLOT := "__test_load_install"
const LOAD_INVALID_SLOT := "__test_load_invalid"
const LOAD_RECOVERY_SLOT := "__test_load_recovery"
const RESET_SLOT_PREFIX := "__test_reset_"
const DIALOGUE_SLOT := "__test_dialogue"
const CRASH_PHASES := [
	"sleep_confirmed",
	"player_committed",
	"memory_committed",
	"physical_reset_complete",
	"morning_loaded",
	"route_selected",
	"complete",
]


func run() -> Dictionary:
	var errors := PackedStringArray()
	_test_snapshot_install(errors)
	_test_load_install_and_recovery(errors)
	_test_reset_crash_recovery("normal", errors)
	_test_reset_crash_recovery("broken", errors)
	_test_dialogue_repository(errors)
	_cleanup()
	GameState.reset_for_test()
	return {"ok": errors.is_empty(), "errors": errors}


func _test_snapshot_install(errors: PackedStringArray) -> void:
	GameState.reset_for_test()
	var writer := StateWriter.new(GameState)
	var initial_snapshot := GameState.get_snapshot()
	var invalid_snapshot := initial_snapshot.duplicate(true)
	invalid_snapshot.erase("loop_state")
	var rejected := writer.install_snapshot(invalid_snapshot, GameState.revision, &"TEST_INVALID_SNAPSHOT")
	_expect(not bool(rejected.get("ok", false)), "partial snapshot was installed", errors)
	_expect(_equivalent(GameState.get_snapshot(), initial_snapshot), "rejected snapshot changed state", errors)

	var stay_snapshot := initial_snapshot.duplicate(true)
	stay_snapshot["ending_run"]["final_decision"] = "stay"
	stay_snapshot["ending_run"]["selected_ending"] = "stay"
	var installed := writer.install_snapshot(stay_snapshot, GameState.revision, &"TEST_STAY_ENUM")
	_expect(bool(installed.get("ok", false)), "canonical stay ending enum was rejected", errors)
	_expect(GameState.revision == 1, "snapshot install did not advance revision once", errors)


func _test_load_install_and_recovery(errors: PackedStringArray) -> void:
	for slot_id in [LOAD_SLOT, LOAD_INVALID_SLOT, LOAD_RECOVERY_SLOT]:
		SaveManager.delete_test_slot(slot_id)
	GameState.reset_for_test()
	var writer := StateWriter.new(GameState)
	var prepared := GameState.get_snapshot()
	prepared["meta_progress"]["journal_stage"] = 2
	prepared["loop_state"]["location_id"] = "M1_LIBRARY_INNER"
	var prepare_result := writer.install_snapshot(prepared, GameState.revision, &"TEST_LOAD_PREPARE")
	_expect(bool(prepare_result.get("ok", false)), "load fixture preparation failed", errors)
	var expected_snapshot := GameState.get_snapshot()
	var save_result := SaveManager.save_snapshot(
		LOAD_SLOT,
		"SAVE_J1_COMPLETE",
		expected_snapshot,
		GameState.revision,
		"TEST_LOAD_SAVE"
	)
	_expect(bool(save_result.get("ok", false)), "load fixture save failed", errors)

	var mutated := GameState.get_snapshot()
	mutated["meta_progress"]["journal_stage"] = 4
	writer.install_snapshot(mutated, GameState.revision, &"TEST_LOAD_MUTATE")
	var revision_before_load := GameState.revision
	var coordinator := LoadCoordinator.new(GameState, SaveManager)
	var loaded := coordinator.load_and_install(LOAD_SLOT)
	_expect(bool(loaded.get("ok", false)), "valid slot was not installed", errors)
	_expect(GameState.revision == revision_before_load + 1, "load install revision count mismatch", errors)
	_expect(_equivalent(GameState.get_snapshot(), expected_snapshot), "installed slot differs from saved snapshot", errors)
	_expect(String(loaded.get("resume_event_id", "")) == "B3", "save point resume event mismatch", errors)
	_expect(String(loaded.get("resume_node_id", "")) == "B3_PREPARE", "save point resume node mismatch", errors)
	var valid_payload := SaveManager.load_slot(LOAD_SLOT)
	var wrong_flavor_header: Dictionary = valid_payload.get("header", {}).duplicate(true)
	wrong_flavor_header["build_flavor"] = "full"
	var wrong_flavor := coordinator.validate_header(wrong_flavor_header)
	_expect(not bool(wrong_flavor.get("ok", false)), "foreign build flavor was accepted", errors)

	var before_invalid := GameState.get_snapshot()
	var invalid_save := SaveManager.save_snapshot(
		LOAD_INVALID_SLOT,
		"SAVE_UNKNOWN_BOUNDARY",
		before_invalid,
		GameState.revision,
		"TEST_INVALID_BOUNDARY"
	)
	_expect(bool(invalid_save.get("ok", false)), "invalid boundary fixture could not be written", errors)
	var invalid_load := coordinator.load_and_install(LOAD_INVALID_SLOT)
	_expect(not bool(invalid_load.get("ok", false)), "unregistered save point was installed", errors)
	_expect(_equivalent(GameState.get_snapshot(), before_invalid), "rejected boundary changed state", errors)

	var backup_snapshot := GameState.get_snapshot()
	backup_snapshot["meta_progress"]["journal_stage"] = 1
	writer.install_snapshot(backup_snapshot, GameState.revision, &"TEST_BACKUP_FIRST")
	backup_snapshot = GameState.get_snapshot()
	SaveManager.save_snapshot(
		LOAD_RECOVERY_SLOT,
		"SAVE_J1_COMPLETE",
		backup_snapshot,
		GameState.revision,
		"TEST_BACKUP_FIRST_SAVE"
	)
	var newer_snapshot := backup_snapshot.duplicate(true)
	newer_snapshot["meta_progress"]["journal_stage"] = 3
	writer.install_snapshot(newer_snapshot, GameState.revision, &"TEST_BACKUP_SECOND")
	SaveManager.save_snapshot(
		LOAD_RECOVERY_SLOT,
		"SAVE_J3_COMPLETE",
		GameState.get_snapshot(),
		GameState.revision,
		"TEST_BACKUP_SECOND_SAVE"
	)
	_corrupt_primary(LOAD_RECOVERY_SLOT)
	GameState.reset_for_test()
	coordinator = LoadCoordinator.new(GameState, SaveManager)
	var recovered := coordinator.load_and_install(LOAD_RECOVERY_SLOT)
	_expect(bool(recovered.get("ok", false)), "backup snapshot was not installed", errors)
	_expect(bool(recovered.get("recovered", false)), "backup recovery source was not surfaced", errors)
	_expect(_equivalent(GameState.get_snapshot(), backup_snapshot), "installed backup snapshot differs", errors)

	_write_future_schema(LOAD_SLOT)
	var before_future := GameState.get_snapshot()
	var future_result := coordinator.load_and_install(LOAD_SLOT)
	_expect(not bool(future_result.get("ok", false)), "future schema was installed", errors)
	_expect(_equivalent(GameState.get_snapshot(), before_future), "future schema rejection changed state", errors)


func _test_reset_crash_recovery(reset_type: String, errors: PackedStringArray) -> void:
	for crash_phase in CRASH_PHASES:
		var slot_id := "%s%s_%s" % [RESET_SLOT_PREFIX, reset_type, crash_phase]
		SaveManager.delete_test_slot(slot_id)
		GameState.reset_for_test()
		var seed := GameState.get_snapshot()
		seed["meta_progress"]["journal_stage"] = 2
		seed["meta_progress"]["knowledge_entries"] = {"KN_TEST_KEEP": "verified"}
		seed["meta_progress"]["servants"]["edgar"]["bond"] = 2
		seed["loop_state"]["inventory"] = ["OBJ_TEST_TEMP_KEY"]
		seed["loop_state"]["physical_changes"] = {"OBJ_TEST_DRAWER": "open"}
		seed["loop_state"]["event_local_states"] = {"TEST_EVENT": {"step": 2}}
		seed["loop_state"]["shortcut_context"] = {"source": "test"}
		if reset_type == "broken":
			seed["fracture_state"]["camouflage_filter"] = "disabled"
			seed["fracture_state"]["world_phase"] = "S2"
		var writer := StateWriter.new(GameState)
		var seed_result := writer.install_snapshot(seed, GameState.revision, &"TEST_RESET_SEED")
		_expect(bool(seed_result.get("ok", false)), "reset seed rejected: %s" % reset_type, errors)
		var expected_meta: Dictionary = GameState.get_snapshot()["meta_progress"].duplicate(true)
		var coordinator := ResetCoordinator.new(GameState, SaveManager)
		var stopped: Dictionary
		if reset_type == "broken":
			stopped = coordinator.request_broken_reset(slot_id, crash_phase)
		else:
			stopped = coordinator.request_normal_reset(slot_id, crash_phase)
		_expect(bool(stopped.get("ok", false)), "reset stopped with error: %s/%s" % [reset_type, crash_phase], errors)
		_expect(String(stopped.get("phase", "")) == crash_phase, "reset did not stop at phase: %s/%s" % [reset_type, crash_phase], errors)

		GameState.reset_for_test()
		var loader := LoadCoordinator.new(GameState, SaveManager)
		var loaded := loader.load_and_install(slot_id)
		_expect(bool(loaded.get("ok", false)), "pending reset slot did not load: %s/%s" % [reset_type, crash_phase], errors)
		_expect(String(loaded.get("resume_event_id", "")) == "SYS_RESET", "pending reset did not route to coordinator", errors)
		coordinator = ResetCoordinator.new(GameState, SaveManager)
		var resumed := coordinator.resume_pending_reset(slot_id)
		_expect(bool(resumed.get("ok", false)) and bool(resumed.get("completed", false)), "pending reset did not complete", errors)

		var completed := GameState.get_snapshot()
		_expect(String(completed["reset_state"]["phase"]) == "idle", "completed reset did not return to idle", errors)
		_expect(not String(completed["reset_state"]["last_completed_transaction_id"]).is_empty(), "completed reset lost transaction id", errors)
		_expect(_equivalent(completed["meta_progress"], expected_meta), "reset changed persistent progress", errors)
		_expect(completed["loop_state"]["inventory"].is_empty(), "reset kept loop inventory", errors)
		_expect(completed["loop_state"]["physical_changes"].is_empty(), "reset kept physical changes", errors)
		_expect(completed["loop_state"]["event_local_states"].is_empty(), "reset kept local event state", errors)
		_expect(int(completed["loop_state"]["day_index"]) == 1, "reset day index mismatch", errors)
		if reset_type == "broken":
			_expect(bool(completed["fracture_state"]["broken_reset_triggered"]), "broken reset trigger missing", errors)
			_expect(String(completed["fracture_state"]["camouflage_filter"]) == "broken", "broken filter state missing", errors)
			_expect(String(completed["fracture_state"]["world_phase"]) == "S3", "broken reset world phase mismatch", errors)
			_expect(coordinator.resolve_sleep_route() == &"POST_BROKEN_REST", "post-broken sleep route mismatch", errors)
		else:
			_expect(not bool(completed["fracture_state"]["broken_reset_triggered"]), "normal reset triggered fracture", errors)
			_expect(String(completed["fracture_state"]["world_phase"]) == "S0", "normal reset world phase changed", errors)

		GameState.reset_for_test()
		var final_load := LoadCoordinator.new(GameState, SaveManager).load_and_install(slot_id)
		_expect(bool(final_load.get("ok", false)), "completed reset slot did not reload", errors)
		_expect(String(GameState.get_value(&"reset_state.phase", "")) == "idle", "reloaded reset was not idle", errors)
		SaveManager.delete_test_slot(slot_id)


func _test_dialogue_repository(errors: PackedStringArray) -> void:
	SaveManager.delete_test_slot(DIALOGUE_SLOT)
	var repository := DialogueRepository.new()
	_expect(repository.is_ready(), "dialogue repository failed: %s" % repository.get_errors(), errors)
	_expect(repository.get_supported_locales() == ["ko-KR", "en-US"], "dialogue locale registry mismatch", errors)
	var ko_text := repository.get_text(&"SYS_FOUNDATION_HISTORY_SAMPLE", "ko-KR", {"count": 2})
	var en_text := repository.get_text(&"SYS_FOUNDATION_HISTORY_SAMPLE", "en-US", {"count": 2})
	_expect(ko_text != en_text and "2" in ko_text and "2" in en_text, "localized placeholder rendering failed", errors)
	_expect("ERR_TEXT_VARIABLES" in repository.get_text(&"SYS_FOUNDATION_HISTORY_SAMPLE", "ko-KR", {"count": "2"}), "placeholder type mismatch was accepted", errors)

	var history := {
		"next_sequence": 1,
		"entries": [{
			"sequence": 0,
			"line_id": "SYS_FOUNDATION_HISTORY_SAMPLE",
			"speaker_id": "SYSTEM",
			"variables": {"count": 2},
			"viewed_locale": "ko-KR",
		}],
	}
	GameState.reset_for_test()
	var writer := StateWriter.new(GameState)
	var write_result := writer.commit_atomic(
		[{"state_path": "meta_progress.dialogue_history", "operation": "set", "value": history}],
		GameState.revision,
		&"TEST_DIALOGUE_HISTORY"
	)
	_expect(bool(write_result.get("ok", false)), "dialogue history state write failed", errors)
	SaveManager.save_snapshot(
		DIALOGUE_SLOT,
		"SAVE_J1_COMPLETE",
		GameState.get_snapshot(),
		GameState.revision,
		"TEST_DIALOGUE_SAVE"
	)
	GameState.reset_for_test()
	var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(DIALOGUE_SLOT)
	_expect(bool(loaded.get("ok", false)), "dialogue history slot did not load", errors)
	var loaded_history: Dictionary = GameState.get_value(&"meta_progress.dialogue_history", {})
	var rendered_ko := repository.render_history(loaded_history, "ko-KR")
	var rendered_en := repository.render_history(loaded_history, "en-US")
	_expect(bool(rendered_ko.get("ok", false)) and bool(rendered_en.get("ok", false)), "dialogue history did not render", errors)
	if not rendered_ko.get("entries", []).is_empty() and not rendered_en.get("entries", []).is_empty():
		_expect(String(rendered_ko["entries"][0]["text"]) != String(rendered_en["entries"][0]["text"]), "history body was not reinterpreted by locale", errors)


func _corrupt_primary(slot_id: String) -> void:
	var file := FileAccess.open("user://saves/%s/progress.json" % slot_id, FileAccess.WRITE)
	if file != null:
		file.store_string("{corrupted-primary")
		file.close()


func _write_future_schema(slot_id: String) -> void:
	var file := FileAccess.open("user://saves/%s/progress.json" % slot_id, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"save_header": {"schema_version": SaveManager.SCHEMA_VERSION + 1},
			"state": {},
		}))
		file.close()


func _cleanup() -> void:
	for slot_id in [LOAD_SLOT, LOAD_INVALID_SLOT, LOAD_RECOVERY_SLOT, DIALOGUE_SLOT]:
		SaveManager.delete_test_slot(slot_id)
	for reset_type in ["normal", "broken"]:
		for phase in CRASH_PHASES:
			SaveManager.delete_test_slot("%s%s_%s" % [RESET_SLOT_PREFIX, reset_type, phase])


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
