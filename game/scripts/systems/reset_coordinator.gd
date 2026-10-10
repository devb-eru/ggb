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
var _async_running := false
var _async_epoch := -1
var _async_revision := -1


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
	if _async_running: return _failure(&"ERR_RESET_ALREADY_ACTIVE")
	var reset: Dictionary = _game_state.get_value(&"reset_state", {})
	if String(reset.get("phase", "idle")) == "idle":
		return _failure(&"ERR_RESET_NOT_PENDING")
	if String(reset.get("reset_type", "")) not in [NORMAL_RESET, BROKEN_RESET]:
		return _failure(&"ERR_RESET_TYPE")
	return _run_until_stop(slot_id, stop_after_phase)


func request_normal_reset_async(slot_id: String, stop_after_phase: String = "", guard: Callable = Callable()) -> Dictionary:
	return await _request_reset_async(NORMAL_RESET, slot_id, stop_after_phase, guard)


func request_broken_reset_async(slot_id: String, stop_after_phase: String = "", guard: Callable = Callable()) -> Dictionary:
	return await _request_reset_async(BROKEN_RESET, slot_id, stop_after_phase, guard)


func resume_pending_reset_async(slot_id: String, stop_after_phase: String = "", guard: Callable = Callable()) -> Dictionary:
	if _async_running: return _failure(&"ERR_RESET_ALREADY_ACTIVE")
	if String(_game_state.get_value(&"reset_state.phase", "idle")) == "idle": return _failure(&"ERR_RESET_NOT_PENDING")
	if not stop_after_phase.is_empty() and stop_after_phase not in PHASES: return _failure(&"ERR_RESET_STOP_PHASE")
	_async_running = true
	_capture_async_context()
	var result := await _run_async_until_stop(slot_id, stop_after_phase, guard)
	_async_running = false
	return result


func _request_reset_async(reset_type: String, slot_id: String, stop_after_phase: String, guard: Callable) -> Dictionary:
	if _async_running: return _failure(&"ERR_RESET_ALREADY_ACTIVE")
	if not stop_after_phase.is_empty() and stop_after_phase not in PHASES: return _failure(&"ERR_RESET_STOP_PHASE")
	_async_running = true
	_capture_async_context()
	var transaction := "RESET_%s_R%06d" % [reset_type.to_upper(), _game_state.revision + 1]
	var result := await _commit_step_async(slot_id, {"operation":"begin", "reset_type":reset_type, "transaction_id":transaction}, guard)
	if result.ok:
		result = _stopped_result() if stop_after_phase == "sleep_confirmed" else await _run_async_until_stop(slot_id, stop_after_phase, guard)
	_async_running = false
	return result


func _run_async_until_stop(slot_id: String, stop_after_phase: String, guard: Callable) -> Dictionary:
	while true:
		if not _reset_async_live(guard): return _failure(&"NB_COMMAND_SCOPE")
		var reset: Dictionary = _game_state.get_value(&"reset_state", {})
		var phase := String(reset.get("phase", "idle"))
		if phase == "idle": return {"ok":true, "completed":true, "phase":"idle", "transaction_id":String(reset.get("last_completed_transaction_id", ""))}
		var result := await _commit_step_async(slot_id, {"operation":"advance", "phase":phase}, guard)
		if not result.ok: return result
		if String(_game_state.get_value(&"reset_state.phase", "")) == stop_after_phase: return _stopped_result()
	return _failure(&"ERR_RESET_LOOP_TERMINATED")


func _commit_step_async(slot_id: String, payload: Dictionary, guard: Callable) -> Dictionary:
	if not _reset_async_live(guard): return _failure(&"NB_COMMAND_SCOPE")
	var previous: Dictionary = _game_state.get_value(&"reset_state", {})
	# The worker derives and validates the candidate; no live reset phase is staged here.
	var point := save_point_for(String(previous.reset_type), String(previous.phase))
	var result := await preload("res://scripts/systems/dialogue_history_writer.gd").save_reset_step_async(_game_state, _save_manager, slot_id, point, payload, _reset_async_live.bind(guard))
	if not result.ok: return result
	if not is_instance_valid(_game_state) or int(_game_state.load_epoch) != _async_epoch or _game_state.revision != _async_revision + 1:
		return _failure(&"NB_COMMAND_SCOPE")
	_async_revision = _game_state.revision
	if not _reset_async_live(guard): return _failure(&"NB_COMMAND_SCOPE")
	var reset: Dictionary = _game_state.get_value(&"reset_state", {})
	var phase := String(reset.phase)
	var transaction := String(reset.last_completed_transaction_id if phase == "idle" else reset.transaction_id)
	reset_phase_committed.emit(StringName(transaction), StringName(phase), _game_state.revision)
	if not _reset_async_live(guard): return _failure(&"NB_COMMAND_SCOPE")
	if phase == "idle": reset_completed.emit(StringName(transaction), StringName(previous.reset_type), _game_state.revision)
	return {"ok":true, "phase":phase, "revision":_game_state.revision}


func _capture_async_context() -> void:
	_async_epoch = int(_game_state.load_epoch)
	_async_revision = _game_state.revision


func _reset_async_live(guard: Callable) -> bool:
	# Keep one context across all phases, including callbacks between worker jobs.
	return _async_running and is_instance_valid(_game_state) and int(_game_state.load_epoch) == _async_epoch \
		and _game_state.revision == _async_revision and (guard.is_null() or (guard.is_valid() and guard.call()))


static func prepare_step(previous: Dictionary, payload: Dictionary) -> Dictionary:
	if payload.get("operation") not in ["begin", "advance"]: return {"ok":false, "error_id":"ERR_RESET_REQUEST"}
	var snapshot := previous.duplicate(true)
	var reset: Dictionary = snapshot.reset_state
	var reset_type := String(reset.reset_type)
	var next_phase := "sleep_confirmed"
	if payload.operation == "begin":
		if String(reset.phase) != "idle": return {"ok":false, "error_id":"ERR_RESET_ALREADY_ACTIVE"}
		if payload.get("reset_type") not in [NORMAL_RESET, BROKEN_RESET] or not payload.get("transaction_id") is String or payload.transaction_id.is_empty(): return {"ok":false, "error_id":"ERR_RESET_REQUEST"}
		reset_type = payload.reset_type
		var fracture: Dictionary = snapshot.fracture_state
		if reset_type == NORMAL_RESET:
			if fracture.broken_reset_triggered or fracture.camouflage_filter != "active": return {"ok":false, "error_id":"ERR_RESET_NORMAL_NOT_ALLOWED"}
		else:
			if fracture.broken_reset_triggered: return {"ok":false, "error_id":"ERR_RESET_BROKEN_ALREADY_COMPLETED"}
			if fracture.camouflage_filter != "disabled": return {"ok":false, "error_id":"ERR_RESET_BROKEN_NOT_READY"}
		snapshot.reset_state = {"phase":next_phase, "reset_type":reset_type, "transaction_id":payload.transaction_id,
			"last_completed_transaction_id":String(reset.last_completed_transaction_id), "player_commit_complete":false,
			"memory_commit_complete":false, "physical_reset_complete":false, "route_snapshot_id":"", "pending_reactions_snapshot":[]}
	else:
		if not payload.get("phase") is String or payload.phase != reset.phase: return {"ok":false, "error_id":"ERR_RESET_PHASE"}
		if reset_type not in [NORMAL_RESET, BROKEN_RESET]: return {"ok":false, "error_id":"ERR_RESET_TYPE"}
		var index := PHASES.find(payload.phase)
		if index < 0 or index >= PHASES.size() - 1: return {"ok":false, "error_id":"ERR_RESET_PHASE"}
		next_phase = PHASES[index + 1]
		match next_phase:
			"player_committed": reset.player_commit_complete = true
			"memory_committed": reset.memory_commit_complete = true
			"physical_reset_complete":
				_apply_physical_reset(snapshot, reset_type)
				reset.physical_reset_complete = true
			"morning_loaded": reset.route_snapshot_id = _derive_route_snapshot_id(snapshot, reset_type)
			"route_selected":
				if String(reset.route_snapshot_id).is_empty(): return {"ok":false, "error_id":"ERR_RESET_ROUTE_SNAPSHOT"}
			"complete": reset.last_completed_transaction_id = String(reset.transaction_id)
			"idle":
				snapshot.reset_state = {"phase":"idle", "reset_type":"none", "transaction_id":"",
					"last_completed_transaction_id":String(reset.last_completed_transaction_id), "player_commit_complete":false,
					"memory_commit_complete":false, "physical_reset_complete":false, "route_snapshot_id":"", "pending_reactions_snapshot":[]}
		if next_phase != "idle": reset.phase = next_phase
	var completed: Dictionary = snapshot.reset_state
	return {"ok":true, "snapshot":snapshot, "phase":next_phase, "reset_type":reset_type,
		"reset_transaction_id":String(completed.last_completed_transaction_id if next_phase == "idle" else completed.transaction_id)}


func _request_reset(reset_type: String, slot_id: String, stop_after_phase: String) -> Dictionary:
	if _async_running: return _failure(&"ERR_RESET_ALREADY_ACTIVE")
	var transaction_id := "RESET_%s_R%06d" % [reset_type.to_upper(), _game_state.revision + 1]
	var prepared := prepare_step(_game_state.get_snapshot(), {"operation":"begin", "reset_type":reset_type, "transaction_id":transaction_id})
	if not prepared.ok: return _failure(StringName(prepared.error_id))
	var begin_result := _commit_and_save(prepared.snapshot, slot_id, "sleep_confirmed")
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
	var prepared := prepare_step(_game_state.get_snapshot(), {"operation":"advance", "phase":current_phase})
	if not prepared.ok: return _failure(StringName(prepared.error_id))
	var result := _commit_and_save(prepared.snapshot, slot_id, prepared.phase, prepared.reset_type)
	if result.ok and prepared.phase == "idle": reset_completed.emit(StringName(prepared.reset_transaction_id), StringName(prepared.reset_type), _game_state.revision)
	return result


static func _apply_physical_reset(snapshot: Dictionary, reset_type: String) -> void:
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


static func _derive_route_snapshot_id(snapshot: Dictionary, reset_type: String) -> String:
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
		var committed := false
		if _save_manager.has_method("confirm_snapshot_commit"):
			var confirmed: Dictionary = _save_manager.confirm_snapshot_commit(slot_id, String(transaction_id))
			committed = confirmed.get("ok", false) and StateSnapshotValidator.same_persisted_value(_game_state.get_snapshot(), confirmed.snapshot)
		if not committed:
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
	return save_point_for(reset_type, target_phase)


static func save_point_for(reset_type: String, target_phase: String) -> String:
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
