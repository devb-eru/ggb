extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const MODALS := preload("res://scripts/systems/modal_notebook.gd")
const FIELD := preload("res://scripts/ui/field_notebook_texts.gd")
const SLOT := "__test_notebook_modals"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var checkpoints := CHECKPOINTS.new()
var serial := 0

class ControlledSave extends Node:
	var delegate: Node
	var reject := false
	var lose_ack := false
	func get_build_flavor() -> String:
		return delegate.get_build_flavor()
	func capture_f3_reselect(slot: String) -> Dictionary:
		return delegate.capture_f3_reselect(slot)
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_MODAL_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_MODAL_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return {"ok": false, "errors": diagnostic.error_ids}
	var ids: Array = diagnostic.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP05")
	_seed("EDC")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await _static_choices(tree)
		await _field_choices(tree)
		await _routes(tree)
		for id in ids:
			_expect(covered.has(id + ":" + locale), "uncovered modal ID " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "uncovered modal segment " + id + ":" + segment + ":" + locale)
	await _failures(tree)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "not_covered": ["durable_restart_cursor", "OS_input", "remaining_unrecorded_modals"]}


func _static_choices(tree: SceneTree) -> void:
	for spec in [
		["A1", "_open_mark_choices", [], 3], ["B1", "_open_schedule_board", [], 3],
		["AS", "_confirm_sleep", [], 2], ["B3_B", "_confirm_clock", [], 3],
		["C4", "_open_patrol", [], 3], ["C4", "_confirm_wet_trace", [], 3],
		["E3_1", "_show_mara1_choice", [], 3], ["E3_2", "_show_iris_choice", [], 3], ["E3_3", "_show_luca_choice", [], 3],
		["E3_4", "_show_edgar_choice", [], 3], ["E3_5", "_show_mara2_choice", [], 3],
		["EDC", "_edc_summary", [], 1], ["EDC", "_confirm_ending", ["reality"], 2], ["EDC", "_confirm_ending", ["stay"], 2],
	]:
		for index in range(spec[3]):
			_seed(spec[0])
			view.callv(spec[1], spec[2])
			_expect(view._modal_active and not view._recorded_modal_request.is_empty(), "actual modal opens: " + spec[1] + ":" + str(index) + " stage=" + view.session.stage())
			if view._recorded_modal_request.is_empty(): continue
			var request := view._recorded_modal_request.duplicate(true)
			var before: int = _history().entries.size()
			if spec[1] == "_confirm_ending": _expect(GameState.get_snapshot().ending_run.final_decision == "unset", "confirmation preview cannot commit the ending")
			_collect()
			view._modal_body.get_child(3 + index).pressed.emit()
			_collect()
			var choice: Dictionary = request.row.choices[index]
			if choice.kind != "ui":
				var entry: Dictionary = _history().entries[before]
				_expect(entry.observation.content_id == choice.content_id, "explicit action identity, not first-button heuristic")
				_expect(entry.observation.event_occurrence_id == request.history_context.event_occurrence_id and entry.observation.conversation_session_id == request.history_context.conversation_session_id, "selection belongs to its displayed prompt")
			await tree.process_frame


func _field_choices(tree: SceneTree) -> void:
	for page in FIELD.RULES.PAGES:
		for expanded in [false, true]:
			for index in range(3):
				_seed("EDR_FIELD_NOTEBOOK")
				var before := GameState.get_snapshot()
				view._open_field_page(page, expanded)
				var request: Dictionary = view._recorded_modal_request
				var archive := _history()
				var observed: Dictionary = archive.entries.back()
				_expect(GameState.get_snapshot().ending_run == before.ending_run, "display is not gameplay read confirmation")
				if not expanded:
					var hidden := ARCHIVE.resolve(archive, ARCHIVE.make_reference(observed, "addendum_merged"))
					_expect(not hidden.ok, "summary cannot disclose an unobserved addendum")
				_collect()
				view._modal_body.get_child(3 + index).pressed.emit()
				_collect()
				if index == 0:
					_expect(_contains(request.row.choices[0].content_id), "first field button is a confirmation, not cancellation")
					_expect(page in GameState.get_snapshot().loop_state.event_local_states.FIELD_NOTEBOOK.pages, "actual read callback still executes")
				await tree.process_frame
	# Conditional source fixtures cover both completed outcomes and every owner.
	for page in FIELD.RULES.OWNERS:
		var owner: String = FIELD.RULES.OWNERS[page]
		for outcome in FIELD.OVERLAYS[owner]:
			var state := _seed("EDR_FIELD_NOTEBOOK")
			state.meta_progress.servants[owner].core_event_complete = true
			state.meta_progress.servants[owner].researcher_record_acquired = true
			state.meta_progress.event_history[FIELD.RULES.WAKE.EVENTS[owner]] = {"lifecycle": "completed", "outcome_id": outcome}
			_install(state)
			view._open_field_page(page, true)
			_expect(view._recorded_modal_request.recorded, "conditional addendum is recorded exactly")
			_collect()
			view._close_modal()
			view._open_field_page("SUBJECT_HANDOFF_PAGE", true)
			_collect()
			await tree.process_frame


func _routes(tree: SceneTree) -> void:
	var tests: Array = [[0, true, false, []], [90, false, true, []], [90, false, true, ["entry"]], [90, false, true, ["entry", "long_branch", "short_branch"]], [90, false, true, ["entry", "counterclockwise_ring"]], [90, false, true, MODALS.MIRROR.PATH]]
	for segment in MODALS.MIRROR.SEGMENTS: tests.append([90, false, true, [segment, segment, segment, segment]])
	for sample in tests:
		_seed("C4")
		var local: Dictionary = view.session.mirror_local().duplicate(true)
		local.rotation = sample[0]
		local.flipped = sample[1]
		local.anchored = sample[2]
		local.path = sample[3]
		view._show_route_feedback(local)
		_expect(view._recorded_modal_request.recorded, "route text and actual descriptor match")
		_collect()
		var state := GameState.get_snapshot()
		view._recorded_choice_pressed(view._recorded_modal_request, 1)
		_expect(GameState.get_snapshot() == state, "signal replay is UI only, not a new choice")
		await tree.process_frame


func _failures(tree: SceneTree) -> void:
	TranslationServer.set_locale("ko-KR")
	_seed("EDC")
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	view.session._save = controlled
	controlled.reject = true
	var before := GameState.get_snapshot()
	view._confirm_ending("reality")
	_expect(not view._recorded_modal_request.recorded and GameState.get_snapshot() == before, "failed prompt stays visible without partial persistence")
	var request: Dictionary = view._recorded_modal_request
	view._modal_body.get_child(4).pressed.emit()
	_expect(GameState.get_snapshot() == before, "cannot execute while prompt save fails")
	controlled.reject = false
	controlled.lose_ack = true
	view._cancel_prologue_modal()
	_expect(not view._modal_active and GameState.get_snapshot().ending_run.final_decision == "unset", "Esc recovers prompt/choice acknowledgements and cancels without committing")
	var prompt := _one_authored("NB_MODAL_EDC_REALITY_OPTIONS")
	var cancellation := _one_authored("NB_MODAL_EDC_REALITY_SELECT_0")
	_expect(cancellation.get("entry_kind") == "choice_cancelled", "explicit cancellation type")
	_expect(prompt.get("event_occurrence_id") == request.history_context.event_occurrence_id and cancellation.get("event_occurrence_id") == request.history_context.event_occurrence_id, "recovered prompt and cancel belong to the original occurrence")
	_expect(not _contains("NB_MODAL_EDC_REALITY_SELECT_1"), "cancelling never records an ending commitment")
	var after := GameState.get_snapshot()
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == after, "stale closed callback does nothing")
	view.session._save = SaveManager
	controlled.free()
	_seed("EDC")
	view._confirm_ending("reality")
	controlled = ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	before = GameState.get_snapshot()
	request = view._recorded_modal_request
	view._modal_body.get_child(4).pressed.emit()
	_expect(view._modal_active and GameState.get_snapshot() == before, "failed selection save cannot execute its callback")
	var token: String = request.selection_token
	view._modal_body.get_child(4).pressed.emit()
	_expect(request.selection_token == token and GameState.get_snapshot() == before, "selection retry keeps the same token and no partial record")
	controlled.reject = false
	view._cancel_prologue_modal()
	_expect(not _contains("NB_MODAL_EDC_REALITY_SELECT_1") and _contains("NB_MODAL_EDC_REALITY_SELECT_0"), "changing to cancel drops an uncommitted selection, not a recorded answer")
	view.session._save = SaveManager
	controlled.free()
	_seed("EDC")
	view._confirm_ending("stay")
	request = view._recorded_modal_request
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real slot reloaded")
	view._recorded_choice_pressed(request, 1)
	_expect(StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "load epoch rejects stale popup selection")
	view._cancel_prologue_modal()
	_expect(not view._modal_active and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "stale popup can close without writing to the loaded state")
	_seed("EDC")
	view._confirm_ending("stay")
	request = view._recorded_modal_request
	view._slot_id = "__test_other_modal_slot"
	saved = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == saved, "changed view slot rejects old callbacks")
	view._slot_id = SLOT
	_seed("EDC")
	view._confirm_ending("stay")
	request = view._recorded_modal_request
	view.session.slot_id = "__test_other_modal_slot"
	saved = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == saved, "changed session slot rejects old callbacks")
	view._cancel_prologue_modal()
	_expect(not view._modal_active and GameState.get_snapshot() == saved, "session slot mismatch closes without writing")
	view.session.slot_id = SLOT
	_seed("EDR_FIELD_NOTEBOOK")
	view._open_field_page("FIELD_NOTEBOOK_PREFACE", false)
	saved = GameState.get_snapshot()
	view._cancel_prologue_modal()
	_expect(not view._modal_active and GameState.get_snapshot() == saved, "Esc closes a field page without read confirmation or a choice record")
	_expect(not _contains("NB_MODAL_FIELD_FIELD_NOTEBOOK_PREFACE_SUMMARY_SELECT_0"), "field-page Esc is not its first button")
	_seed("EDR_FIELD_NOTEBOOK")
	controlled = ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	saved = GameState.get_snapshot()
	view._open_field_page("FIELD_NOTEBOOK_PREFACE", false)
	view._cancel_prologue_modal()
	_expect(view._modal_active and GameState.get_snapshot() == saved, "Esc cannot discard a failed page observation")
	controlled.reject = false
	view._cancel_prologue_modal()
	_expect(not view._modal_active and _contains("NB_MODAL_FIELD_FIELD_NOTEBOOK_PREFACE_SUMMARY_OPTIONS") and not _contains("NB_MODAL_FIELD_FIELD_NOTEBOOK_PREFACE_SUMMARY_SELECT_0"), "Esc retry persists the page without confirming its reading")
	_expect(GameState.get_snapshot().ending_run == saved.ending_run and GameState.get_snapshot().loop_state == saved.loop_state, "successful close retry leaves gameplay unread")
	view.session._save = SaveManager
	controlled.free()
	_seed("EDC")
	view._confirm_ending("reality")
	TranslationServer.set_locale("en-US")
	view._cancel_prologue_modal()
	cancellation = _one_authored("NB_MODAL_EDC_REALITY_SELECT_0")
	_expect(not cancellation.is_empty() and cancellation.segments[0].viewed_locale == "ko-KR", "record the displayed language, not a later locale")
	var snapshot := GameState.get_snapshot()
	for entry in _history().entries:
		if entry.get("record_class") != "authored" or entry.observation.producer_id != "NP05": continue
		var rendered := CONTENT.render_entry(entry, "en-US")
		_expect(rendered.ok and not rendered.entry.fallback, "exact version rereads in the new language")
	_expect(GameState.get_snapshot() == snapshot, "rereading cannot execute a modal choice")
	await tree.process_frame


func _seed(id: String) -> Dictionary:
	if view != null:
		view._close_modal()
		view._dismiss_dialogue_for_test()
	var loaded := checkpoints.snapshot_for(id)
	_expect(loaded.ok, "checkpoint fixture " + id)
	var state: Dictionary = loaded.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase("notebook_knowledge")
	GameState.reset_for_test()
	_install(state)
	return state


func _install(state: Dictionary) -> void:
	serial += 1
	var installed := StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_MODAL_FIXTURE_%d" % serial))
	_expect(installed.ok, "valid modal fixture " + str(installed.get("error_ids", [])))


func _history() -> Dictionary:
	return GameState.get_snapshot().meta_progress.dialogue_history


func _contains(id: String) -> bool:
	for entry in _history().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: return true
	return false


func _one_authored(id: String) -> Dictionary:
	var matches: Array = []
	for entry in _history().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: matches.append(entry.observation)
	_expect(matches.size() == 1, "exactly one authored observation: " + id)
	return matches[0] if matches.size() == 1 else {}


func _collect() -> void:
	for entry in _history().entries:
		if entry.get("record_class") != "authored" or entry.observation.producer_id != "NP05": continue
		for segment in entry.observation.segments:
			var key: String = entry.observation.content_id + ":" + segment.viewed_locale
			covered[key] = true
			segments[entry.observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("MODAL_ASSERT: ", message)
