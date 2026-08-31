class_name ResetCoordinator
extends RefCounted

signal reset_phase_committed(transaction_id: StringName, phase: StringName, revision: int)
signal reset_completed(transaction_id: StringName, reset_type: StringName, revision: int)
signal reset_rejected(error_ids: PackedStringArray)

const NORMAL_RESET := "normal"
const BROKEN_RESET := "broken"
const PHASES := [
	"sleep_confirmed",
	"player_committed",
	"memory_committed",
	"physical_reset_complete",
	"morning_loaded",
	"route_selected",
	"complete",
	"idle",
]

var _game_state: Node
var _save_manager: Node
var _writer: StateWriter


func _init(game_state: Node, save_manager: Node) -> void:
	_game_state = game_state
	_save_manager = save_manager
	_writer = StateWriter.new(game_state)


func resolve_sleep_route() -> StringName:
	var snapshot: Dictionary = _game_state.get_snapshot()
	var reset: Dictionary = snapshot["reset_state"]
	if String(reset["phase"]) != "idle":
		return &"RESUME_PENDING_RESET"
	var fracture: Dictionary = snapshot["fracture_state"]
	if bool(fracture["broken_reset_triggered"]):
		return &"POST_BROKEN_REST"
	match String(fracture["camouflage_filter"]):
		"active":
			return &"NORMAL_RESET"
		"disabled":
			return &"BROKEN_RESET"
	return &"ERR_RESET_SLEEP_ROUTE"


func request_normal_reset(slot_id: String, stop_after_phase: String = "") -> Dictionary:
	return _request_reset(NORMAL_RESET, slot_id, stop_after_phase)


func request_broken_reset(slot_id: String, stop_after_phase: String = "") -> Dictionary:
	return _request_reset(BROKEN_RESET, slot_id, stop_after_phase)


func resume_pending_reset(slot_id: String, stop_after_phase: String = "") -> Dictionary:
	var reset: Dictionary = _game_state.get_value(&"reset_state", {})
	if String(reset.get("phase", "idle")) == "idle":
		return _failure(&"ERR_RESET_NOT_PENDING")
	if String(reset.get("reset_type", "")) not in [NORMAL_RESET, BROKEN_RESET]:
		return _failure(&"ERR_RESET_TYPE")
	return _run_until_stop(slot_id, stop_after_phase)


func _request_reset(reset_type: String, slot_id: String, stop_after_phase: String) -> Dictionary:
	var snapshot: Dictionary = _game_state.get_snapshot()
	var current_reset: Dictionary = snapshot["reset_state"]
	if String(current_reset["phase"]) != "idle":
		return _failure(&"ERR_RESET_ALREADY_ACTIVE")
	var fracture: Dictionary = snapshot["fracture_state"]
	if reset_type == NORMAL_RESET:
		if bool(fracture["broken_reset_triggered"]) or String(fracture["camouflage_filter"]) != "active":
			return _failure(&"ERR_RESET_NORMAL_NOT_ALLOWED")
	else:
		if bool(fracture["broken_reset_triggered"]):
			return _failure(&"ERR_RESET_BROKEN_ALREADY_COMPLETED")
		if String(fracture["camouflage_filter"]) != "disabled":
			return _failure(&"ERR_RESET_BROKEN_NOT_READY")

	var transaction_id := "RESET_%s_R%06d" % [reset_type.to_upper(), _game_state.revision + 1]
	snapshot["reset_state"] = {
		"phase": "sleep_confirmed",
		"reset_type": reset_type,
		"transaction_id": transaction_id,
		"last_completed_transaction_id": String(current_reset["last_completed_transaction_id"]),
		"player_commit_complete": false,
		"memory_commit_complete": false,
		"physical_reset_complete": false,
		"route_snapshot_id": "",
		"pending_reactions_snapshot": [],
	}
	var begin_result := _commit_and_save(snapshot, slot_id, "sleep_confirmed")
	if not bool(begin_result.get("ok", false)):
		return begin_result
	if stop_after_phase == "sleep_confirmed":
		return _stopped_result()
	return _run_until_stop(slot_id, stop_after_phase)


func _run_until_stop(slot_id: String, stop_after_phase: String) -> Dictionary:
	if not stop_after_phase.is_empty() and stop_after_phase not in PHASES:
		return _failure(&"ERR_RESET_STOP_PHASE")
	while true:
		var reset: Dictionary = _game_state.get_value(&"reset_state", {})
		var current_phase := String(reset.get("phase", "idle"))
		if current_phase == "idle":
			return {
				"ok": true,
				"completed": true,
				"phase": "idle",
				"transaction_id": String(reset.get("last_completed_transaction_id", "")),
			}
		var next_result := _advance_one_phase(slot_id, current_phase)
		if not bool(next_result.get("ok", false)):
			return next_result
		var next_phase := String(_game_state.get_value(&"reset_state.phase", ""))
		if next_phase == stop_after_phase:
			return _stopped_result()
	return _failure(&"ERR_RESET_LOOP_TERMINATED")


func _advance_one_phase(slot_id: String, current_phase: String) -> Dictionary:
	var current_index := PHASES.find(current_phase)
	if current_index < 0 or current_index >= PHASES.size() - 1:
		return _failure(&"ERR_RESET_PHASE")
	var next_phase: String = PHASES[current_index + 1]
	var snapshot: Dictionary = _game_state.get_snapshot()
	var reset: Dictionary = snapshot["reset_state"]
	var reset_type := String(reset["reset_type"])

	match next_phase:
		"player_committed":
			reset["player_commit_complete"] = true
		"memory_committed":
			reset["memory_commit_complete"] = true
		"physical_reset_complete":
			_apply_physical_reset(snapshot, reset_type)
			reset["physical_reset_complete"] = true
		"morning_loaded":
			reset["route_snapshot_id"] = _derive_route_snapshot_id(snapshot, reset_type)
		"route_selected":
			if String(reset["route_snapshot_id"]).is_empty():
				return _failure(&"ERR_RESET_ROUTE_SNAPSHOT")
		"complete":
			reset["last_completed_transaction_id"] = String(reset["transaction_id"])
		"idle":
			var completed_transaction_id := String(reset["last_completed_transaction_id"])
			var completed_type := reset_type
			snapshot["reset_state"] = {
				"phase": "idle",
				"reset_type": "none",
				"transaction_id": "",
				"last_completed_transaction_id": completed_transaction_id,
				"player_commit_complete": false,
				"memory_commit_complete": false,
				"physical_reset_complete": false,
				"route_snapshot_id": "",
				"pending_reactions_snapshot": [],
			}
			var final_result := _commit_and_save(snapshot, slot_id, "idle", completed_type)
			if bool(final_result.get("ok", false)):
				reset_completed.emit(StringName(completed_transaction_id), StringName(completed_type), _game_state.revision)
			return final_result
	reset["phase"] = next_phase
	return _commit_and_save(snapshot, slot_id, next_phase)


func _apply_physical_reset(snapshot: Dictionary, reset_type: String) -> void:
	var previous_loop: Dictionary = snapshot["loop_state"]
	snapshot["loop_state"] = {
		"day_index": int(previous_loop["day_index"]) + 1,
		"location_id": "M1_BEDROOM",
		"time_block": "morning",
		"inventory": [],
		"physical_changes": {},
		"event_local_states": {},
		"shortcut_context": {},
	}
	if reset_type == BROKEN_RESET:
		var fracture: Dictionary = snapshot["fracture_state"]
		fracture["broken_reset_triggered"] = true
		fracture["camouflage_filter"] = "broken"
		fracture["world_phase"] = "S3"


func _derive_route_snapshot_id(snapshot: Dictionary, reset_type: String) -> String:
	if reset_type == BROKEN_RESET:
		return "ROUTE_E1_ENTRY"
	return "ROUTE_J%d_DAY_%d" % [
		int(snapshot["meta_progress"]["journal_stage"]),
		int(snapshot["loop_state"]["day_index"]),
	]


func _commit_and_save(
	snapshot: Dictionary,
	slot_id: String,
	target_phase: String,
	reset_type_override: String = ""
) -> Dictionary:
	var reset: Dictionary = snapshot["reset_state"]
	var reset_transaction_id := String(reset["transaction_id"])
	if reset_transaction_id.is_empty():
		reset_transaction_id = String(reset["last_completed_transaction_id"])
	var transaction_id := StringName(
		"%s_%s_R%06d" % [reset_transaction_id, target_phase.to_upper(), _game_state.revision + 1]
	)
	var commit_result := _writer.install_snapshot(snapshot, _game_state.revision, transaction_id)
	if not bool(commit_result.get("ok", false)):
		return commit_result
	var reset_type := reset_type_override if not reset_type_override.is_empty() else String(reset["reset_type"])
	var save_point_id := _save_point_for(reset_type, target_phase)
	var save_result: Dictionary = _save_manager.save_snapshot(
		slot_id,
		save_point_id,
		_game_state.get_snapshot(),
		_game_state.revision,
		String(transaction_id)
	)
	if not bool(save_result.get("ok", false)):
		_game_state.rollback_failed_persistence(
			commit_result["previous_snapshot"],
			int(commit_result["revision"]),
			transaction_id,
			StringName(save_result.get("error_id", &"ERR_SAVE_UNKNOWN"))
		)
		return save_result
	reset_phase_committed.emit(StringName(reset_transaction_id), StringName(target_phase), _game_state.revision)
	return {"ok": true, "phase": target_phase, "revision": _game_state.revision}


func _save_point_for(reset_type: String, target_phase: String) -> String:
	if target_phase in ["complete", "idle"]:
		return "SAVE_BROKEN_RESET_COMPLETE" if reset_type == BROKEN_RESET else "SAVE_NORMAL_RESET_COMPLETE"
	return "SAVE_FRACTURE_CONFIRMED" if reset_type == BROKEN_RESET else "SAVE_P6_COMPLETE"


func _stopped_result() -> Dictionary:
	var reset: Dictionary = _game_state.get_value(&"reset_state", {})
	return {
		"ok": true,
		"completed": false,
		"phase": String(reset.get("phase", "")),
		"transaction_id": String(reset.get("transaction_id", "")),
	}


func _failure(error_id: StringName) -> Dictionary:
	var errors := PackedStringArray([String(error_id)])
	reset_rejected.emit(errors)
	return {"ok": false, "error_ids": errors, "error_id": error_id}
