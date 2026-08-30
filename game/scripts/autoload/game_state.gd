extends Node

signal state_committed(transaction_id: StringName, revision: int, changed_paths: PackedStringArray)
signal state_rolled_back(transaction_id: StringName, revision: int, reason_id: StringName)

const DESIGN_REVISION := "v0.4-state-r12"

var revision := 0
var _state: Dictionary = {}


func _ready() -> void:
	if _state.is_empty():
		_state = _make_default_state()


func get_snapshot() -> Dictionary:
	return _state.duplicate(true)


func get_value(state_path: StringName, fallback: Variant = null) -> Variant:
	var cursor: Variant = _state
	for segment in String(state_path).split("."):
		if not cursor is Dictionary or not cursor.has(segment):
			return fallback
		cursor = cursor[segment]
	return cursor


func commit_validated_snapshot(
	next_state: Dictionary,
	expected_revision: int,
	transaction_id: StringName,
	changed_paths: PackedStringArray
) -> int:
	if expected_revision != revision:
		return -1
	_state = next_state.duplicate(true)
	revision += 1
	state_committed.emit(transaction_id, revision, changed_paths)
	return revision


func rollback_failed_persistence(
	previous_state: Dictionary,
	committed_revision: int,
	transaction_id: StringName,
	reason_id: StringName
) -> bool:
	if revision != committed_revision:
		return false
	_state = previous_state.duplicate(true)
	revision = committed_revision + 1
	state_rolled_back.emit(transaction_id, revision, reason_id)
	return true


func reset_for_test() -> void:
	if not OS.is_debug_build():
		push_error("reset_for_test is only available in debug builds.")
		return
	_state = _make_default_state()
	revision = 0


func _make_default_state() -> Dictionary:
	return {
		"meta_progress": {
			"notebook_persistence_confirmed": false,
			"journal_stage": 0,
			"knowledge_entries": {},
			"failure_knowledge": {},
			"event_history": {},
			"dialogue_history": {"next_sequence": 0, "entries": []},
			"servants": {
				"edgar": _make_servant_state(),
				"mara1": _make_servant_state(),
				"mara2": _make_servant_state(),
				"luca": _make_servant_state(),
				"iris": _make_servant_state(),
			},
		},
		"loop_state": {
			"day_index": 0,
			"location_id": "M1_BEDROOM",
			"time_block": "morning",
			"inventory": [],
			"physical_changes": {},
			"event_local_states": {},
			"shortcut_context": {},
		},
		"fracture_state": {
			"broken_reset_triggered": false,
			"camouflage_filter": "active",
			"world_phase": "S0",
			"servant_events_completed": [],
			"researcher_records": [],
			"mandatory_e1_observations": [],
		},
		"reset_state": {
			"phase": "idle",
			"reset_type": "none",
			"transaction_id": "",
			"last_completed_transaction_id": "",
		},
		"ending_run": {
			"final_decision": "unset",
			"selected_ending": "",
			"reselect_used": false,
		},
	}


func _make_servant_state() -> Dictionary:
	return {
		"bond": 0,
		"alert": 0,
		"residual_memory": [],
		"core_event_complete": false,
		"researcher_record_acquired": false,
	}
