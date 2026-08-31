class_name StateSnapshotValidator
extends RefCounted

const ROOT_KEYS := [
	"meta_progress",
	"loop_state",
	"fracture_state",
	"reset_state",
	"ending_run",
]
const SERVANT_KEYS := ["edgar", "mara1", "mara2", "luca", "iris"]
const WORLD_PHASES := ["S0", "S1", "S2", "S3", "S4", "S5", "R0"]
const FILTER_STATES := ["active", "disabled", "broken"]
const RESET_TYPES := ["none", "normal", "broken"]
const RESET_PHASES := [
	"idle",
	"sleep_confirmed",
	"player_committed",
	"memory_committed",
	"physical_reset_complete",
	"morning_loaded",
	"route_selected",
	"complete",
]
const ENDING_DECISIONS := ["unset", "reality", "stay"]


func validate(snapshot: Variant) -> Dictionary:
	var errors := PackedStringArray()
	if not snapshot is Dictionary:
		return _result(PackedStringArray(["ERR_SNAPSHOT_ROOT_TYPE"]))

	var state: Dictionary = snapshot
	_validate_exact_keys(state, ROOT_KEYS, "ROOT", errors)
	if not errors.is_empty():
		return _result(errors)

	_validate_meta_progress(state["meta_progress"], errors)
	_validate_loop_state(state["loop_state"], errors)
	_validate_fracture_state(state["fracture_state"], errors)
	_validate_reset_state(state["reset_state"], errors)
	_validate_ending_run(state["ending_run"], errors)
	_validate_cross_root_invariants(state, errors)
	return _result(errors)


func normalize(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	if normalized.get("meta_progress") is Dictionary:
		var meta: Dictionary = normalized["meta_progress"]
		if meta.has("journal_stage"):
			meta["journal_stage"] = int(meta["journal_stage"])
		if meta.get("dialogue_history") is Dictionary:
			var history: Dictionary = meta["dialogue_history"]
			if history.has("next_sequence"):
				history["next_sequence"] = int(history["next_sequence"])
			if history.get("entries") is Array:
				for entry_value in history["entries"]:
					if entry_value is Dictionary and entry_value.has("sequence"):
						entry_value["sequence"] = int(entry_value["sequence"])
		if meta.get("servants") is Dictionary:
			for servant_value in meta["servants"].values():
				if servant_value is Dictionary:
					if servant_value.has("bond"):
						servant_value["bond"] = int(servant_value["bond"])
					if servant_value.has("alert"):
						servant_value["alert"] = int(servant_value["alert"])
	if normalized.get("loop_state") is Dictionary and normalized["loop_state"].has("day_index"):
		normalized["loop_state"]["day_index"] = int(normalized["loop_state"]["day_index"])
	return normalized


func _validate_meta_progress(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "META", errors):
		return
	var meta: Dictionary = value
	var required := [
		"notebook_persistence_confirmed",
		"journal_stage",
		"knowledge_entries",
		"failure_knowledge",
		"event_history",
		"dialogue_history",
		"servants",
	]
	_validate_required_keys(meta, required, "META", errors)
	_require_type(meta.get("notebook_persistence_confirmed"), TYPE_BOOL, "META_NOTEBOOK", errors)
	if _require_type(meta.get("journal_stage"), TYPE_INT, "META_JOURNAL_STAGE", errors):
		var stage := int(meta["journal_stage"])
		if stage < 0 or stage > 5:
			errors.append("ERR_SNAPSHOT_META_JOURNAL_RANGE")
	for field in ["knowledge_entries", "failure_knowledge", "event_history"]:
		_require_type(meta.get(field), TYPE_DICTIONARY, "META_%s" % field.to_upper(), errors)
	_validate_dialogue_history(meta.get("dialogue_history"), errors)
	_validate_servants(meta.get("servants"), errors)


func _validate_dialogue_history(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "DIALOGUE_HISTORY", errors):
		return
	var history: Dictionary = value
	_validate_exact_keys(history, ["next_sequence", "entries"], "DIALOGUE_HISTORY", errors)
	if not _require_type(history.get("next_sequence"), TYPE_INT, "DIALOGUE_NEXT_SEQUENCE", errors):
		return
	if not _require_type(history.get("entries"), TYPE_ARRAY, "DIALOGUE_ENTRIES", errors):
		return
	var next_sequence := int(history["next_sequence"])
	if next_sequence < 0:
		errors.append("ERR_SNAPSHOT_DIALOGUE_NEXT_SEQUENCE")
	var sequences := {}
	var max_sequence := -1
	for entry_value in history["entries"]:
		if not entry_value is Dictionary:
			errors.append("ERR_SNAPSHOT_DIALOGUE_ENTRY_TYPE")
			continue
		var entry: Dictionary = entry_value
		for field in ["sequence", "line_id", "speaker_id"]:
			if not entry.has(field):
				errors.append("ERR_SNAPSHOT_DIALOGUE_ENTRY_FIELD")
		if not entry.has("sequence") or typeof(entry["sequence"]) != TYPE_INT:
			continue
		var sequence := int(entry["sequence"])
		if sequence < 0 or sequences.has(sequence):
			errors.append("ERR_SNAPSHOT_DIALOGUE_SEQUENCE")
		sequences[sequence] = true
		max_sequence = maxi(max_sequence, sequence)
		if String(entry.get("line_id", "")).is_empty() or String(entry.get("speaker_id", "")).is_empty():
			errors.append("ERR_SNAPSHOT_DIALOGUE_ID")
	if next_sequence <= max_sequence:
		errors.append("ERR_SNAPSHOT_DIALOGUE_NEXT_SEQUENCE")


func _validate_servants(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "SERVANTS", errors):
		return
	var servants: Dictionary = value
	_validate_exact_keys(servants, SERVANT_KEYS, "SERVANTS", errors)
	for servant_id in SERVANT_KEYS:
		if not servants.has(servant_id) or not servants[servant_id] is Dictionary:
			continue
		var servant: Dictionary = servants[servant_id]
		var required := [
			"bond",
			"alert",
			"residual_memory",
			"core_event_complete",
			"researcher_record_acquired",
		]
		_validate_exact_keys(servant, required, "SERVANT_%s" % servant_id.to_upper(), errors)
		for field in ["bond", "alert"]:
			if _require_type(servant.get(field), TYPE_INT, "SERVANT_%s_%s" % [servant_id, field], errors):
				var amount := int(servant[field])
				if amount < 0 or amount > 5:
					errors.append("ERR_SNAPSHOT_SERVANT_RANGE")
		_require_unique_string_array(servant.get("residual_memory"), "SERVANT_MEMORY", errors)
		_require_type(servant.get("core_event_complete"), TYPE_BOOL, "SERVANT_CORE", errors)
		_require_type(servant.get("researcher_record_acquired"), TYPE_BOOL, "SERVANT_RECORD", errors)


func _validate_loop_state(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "LOOP", errors):
		return
	var loop_state: Dictionary = value
	var required := [
		"day_index",
		"location_id",
		"time_block",
		"inventory",
		"physical_changes",
		"event_local_states",
		"shortcut_context",
	]
	_validate_exact_keys(loop_state, required, "LOOP", errors)
	if _require_type(loop_state.get("day_index"), TYPE_INT, "LOOP_DAY", errors):
		if int(loop_state["day_index"]) < 0:
			errors.append("ERR_SNAPSHOT_LOOP_DAY_RANGE")
	for field in ["location_id", "time_block"]:
		if _require_type(loop_state.get(field), TYPE_STRING, "LOOP_%s" % field.to_upper(), errors):
			if String(loop_state[field]).is_empty():
				errors.append("ERR_SNAPSHOT_LOOP_ID_EMPTY")
	_require_unique_string_array(loop_state.get("inventory"), "LOOP_INVENTORY", errors)
	for field in ["physical_changes", "event_local_states", "shortcut_context"]:
		_require_type(loop_state.get(field), TYPE_DICTIONARY, "LOOP_%s" % field.to_upper(), errors)


func _validate_fracture_state(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "FRACTURE", errors):
		return
	var fracture: Dictionary = value
	var required := [
		"broken_reset_triggered",
		"camouflage_filter",
		"world_phase",
		"servant_events_completed",
		"researcher_records",
		"mandatory_e1_observations",
	]
	_validate_exact_keys(fracture, required, "FRACTURE", errors)
	_require_type(fracture.get("broken_reset_triggered"), TYPE_BOOL, "FRACTURE_TRIGGER", errors)
	if _require_type(fracture.get("camouflage_filter"), TYPE_STRING, "FRACTURE_FILTER", errors):
		if String(fracture["camouflage_filter"]) not in FILTER_STATES:
			errors.append("ERR_SNAPSHOT_FRACTURE_FILTER")
	if _require_type(fracture.get("world_phase"), TYPE_STRING, "FRACTURE_PHASE", errors):
		if String(fracture["world_phase"]) not in WORLD_PHASES:
			errors.append("ERR_SNAPSHOT_WORLD_PHASE")
	for field in ["servant_events_completed", "researcher_records", "mandatory_e1_observations"]:
		_require_unique_string_array(fracture.get(field), "FRACTURE_%s" % field.to_upper(), errors)


func _validate_reset_state(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "RESET", errors):
		return
	var reset: Dictionary = value
	var required := [
		"phase",
		"reset_type",
		"transaction_id",
		"last_completed_transaction_id",
		"player_commit_complete",
		"memory_commit_complete",
		"physical_reset_complete",
		"route_snapshot_id",
		"pending_reactions_snapshot",
	]
	_validate_exact_keys(reset, required, "RESET", errors)
	if _require_type(reset.get("phase"), TYPE_STRING, "RESET_PHASE", errors):
		if String(reset["phase"]) not in RESET_PHASES:
			errors.append("ERR_SNAPSHOT_RESET_PHASE")
	if _require_type(reset.get("reset_type"), TYPE_STRING, "RESET_TYPE", errors):
		if String(reset["reset_type"]) not in RESET_TYPES:
			errors.append("ERR_SNAPSHOT_RESET_TYPE")
	for field in ["transaction_id", "last_completed_transaction_id", "route_snapshot_id"]:
		_require_type(reset.get(field), TYPE_STRING, "RESET_%s" % field.to_upper(), errors)
	for field in ["player_commit_complete", "memory_commit_complete", "physical_reset_complete"]:
		_require_type(reset.get(field), TYPE_BOOL, "RESET_%s" % field.to_upper(), errors)
	_require_unique_string_array(reset.get("pending_reactions_snapshot"), "RESET_REACTIONS", errors)

	var phase := String(reset.get("phase", ""))
	var reset_type := String(reset.get("reset_type", ""))
	if phase == "idle":
		if reset_type != "none" or not String(reset.get("transaction_id", "")).is_empty():
			errors.append("ERR_SNAPSHOT_RESET_IDLE_INVARIANT")
		return
	if reset_type not in ["normal", "broken"] or String(reset.get("transaction_id", "")).is_empty():
		errors.append("ERR_SNAPSHOT_RESET_ACTIVE_INVARIANT")
	var phase_index := RESET_PHASES.find(phase)
	if phase_index >= RESET_PHASES.find("player_committed") and not bool(reset.get("player_commit_complete", false)):
		errors.append("ERR_SNAPSHOT_RESET_PLAYER_COMMIT")
	if phase_index >= RESET_PHASES.find("memory_committed") and not bool(reset.get("memory_commit_complete", false)):
		errors.append("ERR_SNAPSHOT_RESET_MEMORY_COMMIT")
	if phase_index >= RESET_PHASES.find("physical_reset_complete") and not bool(reset.get("physical_reset_complete", false)):
		errors.append("ERR_SNAPSHOT_RESET_PHYSICAL_COMMIT")


func _validate_ending_run(value: Variant, errors: PackedStringArray) -> void:
	if not _require_dictionary(value, "ENDING", errors):
		return
	var ending: Dictionary = value
	var required := ["final_decision", "selected_ending", "reselect_used"]
	_validate_exact_keys(ending, required, "ENDING", errors)
	if _require_type(ending.get("final_decision"), TYPE_STRING, "ENDING_DECISION", errors):
		if String(ending["final_decision"]) not in ENDING_DECISIONS:
			errors.append("ERR_SNAPSHOT_ENDING_DECISION")
	_require_type(ending.get("selected_ending"), TYPE_STRING, "ENDING_SELECTED", errors)
	_require_type(ending.get("reselect_used"), TYPE_BOOL, "ENDING_RESELECT", errors)


func _validate_cross_root_invariants(state: Dictionary, errors: PackedStringArray) -> void:
	if not state.get("fracture_state") is Dictionary or not state.get("ending_run") is Dictionary:
		return
	var fracture: Dictionary = state["fracture_state"]
	var is_broken := bool(fracture.get("broken_reset_triggered", false))
	var filter_is_broken := String(fracture.get("camouflage_filter", "")) == "broken"
	if is_broken != filter_is_broken:
		errors.append("ERR_STATE_FRACTURE_FILTER_INVARIANT")
	var ending: Dictionary = state["ending_run"]
	var final_decision := String(ending.get("final_decision", ""))
	var selected_ending := String(ending.get("selected_ending", ""))
	if final_decision == "unset" and not selected_ending.is_empty():
		errors.append("ERR_STATE_ENDING_INVARIANT")
	if final_decision in ["reality", "stay"] and selected_ending != final_decision:
		errors.append("ERR_STATE_ENDING_INVARIANT")


func _validate_required_keys(value: Dictionary, required: Array, scope: String, errors: PackedStringArray) -> void:
	for key in required:
		if not value.has(key):
			errors.append("ERR_SNAPSHOT_%s_FIELD_MISSING" % scope)


func _validate_exact_keys(value: Dictionary, expected: Array, scope: String, errors: PackedStringArray) -> void:
	_validate_required_keys(value, expected, scope, errors)
	for key in value.keys():
		if String(key) not in expected:
			errors.append("ERR_SNAPSHOT_%s_FIELD_UNKNOWN" % scope)


func _require_dictionary(value: Variant, scope: String, errors: PackedStringArray) -> bool:
	return _require_type(value, TYPE_DICTIONARY, scope, errors)


func _require_type(value: Variant, expected_type: int, scope: String, errors: PackedStringArray) -> bool:
	if typeof(value) == expected_type:
		return true
	errors.append("ERR_SNAPSHOT_%s_TYPE" % scope)
	return false


func _require_unique_string_array(value: Variant, scope: String, errors: PackedStringArray) -> bool:
	if not _require_type(value, TYPE_ARRAY, scope, errors):
		return false
	var seen := {}
	for item in value:
		if typeof(item) not in [TYPE_STRING, TYPE_STRING_NAME] or String(item).is_empty() or seen.has(String(item)):
			errors.append("ERR_SNAPSHOT_%s_SET" % scope)
			return false
		seen[String(item)] = true
	return true


func _result(errors: PackedStringArray) -> Dictionary:
	return {"ok": errors.is_empty(), "error_ids": errors}
