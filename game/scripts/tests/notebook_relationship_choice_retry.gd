extends RefCounted

const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const RESULTS := {
	"mara1": ["E3_1", "original_attribution", "protected_identifiers"],
	"iris": ["E3_2", "external_truth", "shelter_projection"],
	"luca": ["E3_3", "full_disclosure", "stabilize_first"],
	"edgar": ["E3_4", "responsibility_recorded", "authority_returned"],
	"mara2": ["E3_5", "merged", "separated"],
}


static func run(view, controlled: Node, actor: String, index: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var before := GameState.get_snapshot()
	controlled.reject_history = true
	view.call("_show_" + actor + "_choice")
	var request: Dictionary = view._recorded_modal_request
	_check(not request.recorded and GameState.get_snapshot() == before, "failed prompt save leaves full snapshot unchanged", errors)
	view._recorded_choice_pressed(request, index)
	_check(GameState.get_snapshot() == before, "unsaved prompt cannot dispatch a choice", errors)
	controlled.reject_history = false
	_check(view._record_modal_options(request), "explicit prompt retry succeeds", errors)
	var shown := GameState.get_snapshot()
	var prompt: Dictionary = shown.meta_progress.dialogue_history.entries.back()
	var chosen_id: String = request.row.choices[index].content_id
	controlled.reject_history = true
	view._recorded_choice_pressed(request, index)
	_check(GameState.get_snapshot() == shown, "failed answer save cannot grant a relationship result", errors)
	controlled.reject_history = false
	controlled.reject_game = true
	view._recorded_choice_pressed(request, index)
	var pending := GameState.get_snapshot()
	var cursor := CURSOR.read(pending)
	_check(view._modal_active and cursor.get("phase") == "selection_pending" and CURSOR.matches(cursor, pending), "failed game commit restores the selected modal", errors)
	_check(not pending.meta_progress.servants[actor].core_event_complete, "recorded answer is not relationship completion", errors)
	var left := shown.duplicate(true)
	var right := pending.duplicate(true)
	right.meta_progress.dialogue_history = left.meta_progress.dialogue_history.duplicate(true)
	left.loop_state.event_local_states.erase(CURSOR.KEY)
	right.loop_state.event_local_states.erase(CURSOR.KEY)
	_check(StateSnapshotValidator.same_persisted_value(left, right), "failed game commit changes only observed history and presentation", errors)
	var answers: Array = pending.meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id", "") == chosen_id)
	_check(answers.size() == 1, "one selected answer before retry", errors)
	if answers.size() != 1:
		controlled.reject_game = false
		return errors
	var answer: Dictionary = answers[0]
	_check(answer.observation.event_occurrence_id == prompt.observation.event_occurrence_id and answer.observation.conversation_session_id == prompt.observation.conversation_session_id, "answer retains original prompt context", errors)
	_check(answer.observation.presentation_token != prompt.observation.presentation_token, "prompt and answer have different presentation tokens", errors)
	controlled.reject_game = false
	controlled.lose_ack = true
	var restored: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(restored, index)
	var after := GameState.get_snapshot()
	_check(after.meta_progress.servants[actor].core_event_complete, "explicit retry completes eligible relationship", errors)
	_check(after.meta_progress.event_history.get(RESULTS[actor][0], {}).get("outcome_id") == RESULTS[actor][index], "retry applies the selected outcome, not a default", errors)
	var retried: Array = after.meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id", "") == chosen_id)
	_check(retried.size() == 1 and _same_answer(answer, retried[0], after.meta_progress.dialogue_history), "retry preserves the same answer with only backed source protection added", errors)
	view._recorded_choice_pressed(restored, index)
	_check(GameState.get_snapshot() == after, "old callback cannot repeat a successful award", errors)
	controlled.lose_ack = false
	print("NOTEBOOK_RELATIONSHIP_CHOICE_RETRY: ", actor, " ", TranslationServer.get_locale(), " ", index, " ", "PASS" if errors.is_empty() else errors)
	return errors


static func _same_answer(before: Dictionary, after: Dictionary, archive: Dictionary) -> bool:
	if not ARCHIVE.validate(archive).ok: return false
	var left := before.duplicate(true)
	var right := after.duplicate(true)
	left.erase("protection_reasons")
	right.erase("protection_reasons")
	if not StateSnapshotValidator.same_persisted_value(left, right): return false
	for reason in before.protection_reasons:
		if reason not in after.protection_reasons: return false
	for reason in after.protection_reasons:
		if reason in before.protection_reasons: continue
		if not String(reason).begins_with("knowledge_source:"): return false
		var backed := false
		for link in archive.source_links:
			if link.consumer_kind == "knowledge_source" and "knowledge_source:" + link.consumer_uid == reason and link.target.uid == after.entry_uid: backed = true
		if not backed: return false
	return true


static func _check(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition: errors.append("Relationship choice retry: " + message)
