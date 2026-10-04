extends RefCounted

const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
const RECEIPT := preload("res://scripts/systems/notebook_surface_receipt.gd")


static func same_surface_gameplay(before: Dictionary, after: Dictionary) -> bool:
	var receipt: Dictionary = after.loop_state.event_local_states.get(RECEIPT.KEY, {})
	if not RECEIPT.valid(receipt): return false
	var old: Dictionary = before.meta_progress.dialogue_history
	var current: Dictionary = after.meta_progress.dialogue_history
	var added: int = current.entries.size() - old.entries.size()
	if added < 0 or not StateSnapshotValidator.same_persisted_value(old.entries, current.entries.slice(0, old.entries.size())): return false
	var archive := current.duplicate(true)
	archive.entries = old.entries.duplicate(true)
	archive.next_sequence -= added
	archive.revision -= added
	if not StateSnapshotValidator.same_persisted_value(old, archive): return false
	if receipt.scope.origin != current.source_origin_id or receipt.scope.branch != current.branch_id: return false
	for identity in receipt.receipts.values():
		var backed := false
		for entry in current.entries:
			if entry.get("record_class") != "authored": continue
			var observed: Dictionary = entry.observation
			if observed.presentation_token == identity.presentation_token and observed.event_occurrence_id == identity.event_occurrence_id and observed.conversation_session_id == identity.conversation_session_id: backed = true
		if not backed: return false
	var left := before.duplicate(true)
	var right := after.duplicate(true)
	left.loop_state.event_local_states.erase(RECEIPT.KEY)
	right.loop_state.event_local_states.erase(RECEIPT.KEY)
	right.meta_progress.dialogue_history = old.duplicate(true)
	return StateSnapshotValidator.same_persisted_value(left, right)


static func same_gameplay(before: Dictionary, after: Dictionary, closed_kind: String, report: bool = true) -> bool:
	var cursor := PRESENTATION.read(after)
	if not PRESENTATION.matches(cursor, after) or cursor.get("kind") != closed_kind or cursor.get("phase") != "completed":
		if report: print("NOTEBOOK_STATE_DIFF: invalid completed ", closed_kind, " cursor")
		return false
	var left := before.duplicate(true)
	var right := after.duplicate(true)
	left.loop_state.event_local_states.erase(PRESENTATION.KEY)
	right.loop_state.event_local_states.erase(PRESENTATION.KEY)
	var changes := changed_paths(left, right)
	if report:
		print("NOTEBOOK_STATE_DIFF: allowed=", PRESENTATION.KEY, " kind=", closed_kind, " phase=completed; unexpected=", changes)
	return changes.is_empty()


static func changed_paths(before: Variant, after: Variant, path: String = "$") -> PackedStringArray:
	var result := PackedStringArray()
	if StateSnapshotValidator.same_persisted_value(before, after): return result
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key): result.append(path + "." + str(key))
			else: result.append_array(changed_paths(before[key], after[key], path + "." + str(key)))
		for key in after:
			if not before.has(key): result.append(path + "." + str(key))
	elif before is Array and after is Array and before.size() == after.size():
		for index in range(before.size()):
			result.append_array(changed_paths(before[index], after[index], path + "[%d]" % index))
	else:
		result.append(path)
	return result


static func mutation_guards(before: Dictionary, after: Dictionary, closed_kind: String) -> bool:
	if not same_gameplay(before, after, closed_kind, false): return false
	for field in ["relationship", "inventory", "knowledge", "history", "missing_cursor", "pending_cursor", "foreign_scope"]:
		var mutated := after.duplicate(true)
		match field:
			"relationship": mutated.meta_progress.servants.mara1.bond += 1
			"inventory": mutated.loop_state.inventory.append("TEST_UNEARNED_ITEM")
			"knowledge": mutated.meta_progress.knowledge_entries.TEST_UNEARNED_NOTE = true
			"history": mutated.meta_progress.dialogue_history.next_sequence += 1
			"missing_cursor": mutated.loop_state.event_local_states.erase(PRESENTATION.KEY)
			"pending_cursor": mutated.loop_state.event_local_states[PRESENTATION.KEY].phase = "viewing" if closed_kind == "utility" else "choosing"
			"foreign_scope": mutated.loop_state.event_local_states[PRESENTATION.KEY].branch_id = "0".repeat(32)
		if same_gameplay(before, mutated, closed_kind, false):
			print("NOTEBOOK_STATE_MUTATION_MISSED: ", field)
			return false
	print("NOTEBOOK_STATE_MUTATION_GUARDS: 7 rejected")
	return true
