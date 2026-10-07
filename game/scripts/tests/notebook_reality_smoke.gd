extends RefCounted

const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/reality_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const FIELD := preload("res://scripts/systems/field_notebook.gd")
const SLOT := "__test_notebook_reality"
var errors := PackedStringArray()
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()
var fixtures := {}
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var handoff_masks := 0
var historical_confirmations := 0

class ControlledSave extends Node:
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok":false,"error_ids":["ERR_TEST_REALITY_SAVE"]}
		var result := SaveManager.save_snapshot(slot,point,state,revision,transaction)
		return {"ok":false,"error_ids":["ERR_TEST_REALITY_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary: return SaveManager.confirm_snapshot_commit(slot,transaction)
	func capture_f3_reselect(slot: String) -> Dictionary: return SaveManager.capture_f3_reselect(slot)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor","full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	for id in diagnostic.content_ids:
		if not String(id).begins_with(NOTES.PREFIX): continue
		var row := CONTENT.definition(id,1)
		if row.node_ids[0] == "ED_ALL_CEREMONY" or String(row.node_ids[0]).begins_with("EDS_"):
			_expect(row.locales["ko-KR"].title == "엔딩 절차와 인계 기록" and row.locales["en-US"].title == "Ending Procedure and Handoff Records","neutral common/stay metadata title")
	_install(_fixture("EDR_ENTRY"))
	view = VIEW.new()
	view.configure_session(SLOT,"ENDING_SEQUENCE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for language in ["ko-KR","en-US"]:
		TranslationServer.set_locale(language)
		if "--notebook-handoff-history-only" in OS.get_cmdline_user_args():
			await _handoff_versions(tree, true)
			continue
		print("REALITY_PHASE: ",language," entry and ceremony")
		_entry()
		_signature_failure()
		print("REALITY_PHASE: ",language," frozen farewell variants")
		_farewells()
		await _wake(tree)
		print("REALITY_PHASE: ",language," physical pages and acquisition")
		_field()
		_field_failures()
		await _handoff_versions(tree)
		print("REALITY_PHASE: ",language," facility, choices and timer")
		_surface()
		_surface_failure()
		_legacy()
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + language),"unvisited actual ID " + id + ":" + language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + language),"unvisited segment " + id + ":" + segment + ":" + language)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor",flavor)
	print("REALITY_COVERAGE: actual ID/locales=",covered.size()," segment/locales=",segments.size())
	_expect(runtime_audit.emit("reality", errors.is_empty()).ok, "runtime trace validates")
	return {"ok":errors.is_empty(),"errors":errors,"actual_id_locales":covered.size(),"actual_segment_locales":segments.size(),
		"handoff_masks":handoff_masks,"historical_confirmations":historical_confirmations,
		"focused_history_only":"--notebook-handoff-history-only" in OS.get_cmdline_user_args(),
		"not_covered":["durable_app_restart_cursor","unified_notebook_UI","OS_input"]}


func _entry() -> void:
	for node in ["EDR_ENTRY","EDS_ENTRY"]:
		_install(_fixture(node))
		_present()
		_expect(_count("ENTRY_READ_" + node) == 0,"entry board does not fabricate a spoken line")
		_press("ENDING_CONTINUE")
		_drain()
		_press("ENDING_CONTINUE")
		_drain()
		_collect()
	for branch in ["reality","stay"]:
		var state := _fixture("ED_ALL_CEREMONY")
		state.ending_run.branch_id = branch
		state.ending_run.final_decision = branch
		state.ending_run.selected_ending = branch
		_install(state)
		_present()
		for owner in WAKE.OWNERS:
			_expect(_count("IDENTITY_" + String(owner).to_upper()) == 0,"identity not revealed by name label")
			_press("ENDING_IDENTITY")
			_drain()
		_press("ENDING_AUTHORITY")
		_drain()
		_press("ENDING_AUTO_SIGN")
		_drain()
		_expect(GameState.get_snapshot().ending_run.current_node_id == ("EDR_ENTRY" if branch == "reality" else "EDS_ENTRY"),"both ceremony signatures preserve original decision")
		_collect()


func _signature_failure() -> void:
	var state := _fixture("ED_ALL_CEREMONY")
	state.loop_state.event_local_states.ED_ALL_CEREMONY = {"identity_index":5,"authority_seen":true}
	_install(state)
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_history = true
	_press("ENDING_AUTO_SIGN")
	var signature = view._hotspot_layer.get_node("ENDING_SIGNATURE")
	_expect(not signature._complete and not view._dialogue_active,"failed ceremony display leaves signature retryable")
	_expect(GameState.get_snapshot().ending_run.current_node_id == "ED_ALL_CEREMONY","unrecorded signature cannot leave ceremony")
	saver.reject_history = false
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"ceremony display retry")
	_press("ENDING_AUTO_SIGN")
	_drain()
	_expect(GameState.get_snapshot().ending_run.current_node_id == "EDR_ENTRY" and _count("SIGN_REALITY") == 1,"retryable automatic signature advances once")
	view.session._save = SaveManager
	saver.free()
	_collect()


func _farewells() -> void:
	for owner in WAKE.OWNERS:
		var state := _farewell_state(owner)
		state.meta_progress.servants[owner].core_event_complete = false
		_install(state)
		_present()
		_expect(_count("FAREWELL_%s_INCOMPLETE" % String(owner).to_upper()) == 0,"handoff board not its recording")
		_press("REALITY_FAREWELL")
		_expect(_count("FAREWELL_NOTICE") == 1 and _count("FAREWELL_%s_INCOMPLETE" % String(owner).to_upper()) == 0,"only first handoff line disclosed")
		_drain()
		_collect()
		for outcome in WAKE.OVERLAYS[owner]:
			for band in [0,2,4]:
				state = _farewell_state(owner)
				state.meta_progress.servants[owner].bond = band
				state.meta_progress.servants[owner].alert = band
				state.meta_progress.event_history[WAKE.EVENTS[owner]].outcome_id = outcome
				_install(state)
				_press("REALITY_FAREWELL")
				_drain()
				_expect(_count("OVERLAY_%s_%s" % [String(owner).to_upper(),String(outcome).to_upper()]) == 1,"only chosen outcome overlay archived")
				_collect()
		state = _farewell_state(owner)
		state.meta_progress.event_history[WAKE.EVENTS[owner]].outcome_id = "unknown_legacy_outcome"
		_install(state)
		_press("REALITY_FAREWELL")
		_drain()
		for outcome in WAKE.OVERLAYS[owner]:
			_expect(_count("OVERLAY_%s_%s" % [String(owner).to_upper(),String(outcome).to_upper()]) == 0,"integrity warning cannot invent an overlay")
		_collect()
	for mode in ["public","direct_private","indirect","denied","withheld","inferred_only"]:
		var state := _farewell_state("iris")
		for servant in state.meta_progress.servants.values(): servant.core_event_complete = mode == "public"
		state.meta_progress.servants.iris.core_event_complete = mode != "inferred_only"
		state.meta_progress.servants.iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		state.meta_progress.servants.iris.alert = 4 if mode == "denied" else 0
		_expect(WAKE.CONFRONTATION.iris_state(state) == mode,"Iris fixture " + mode)
		_install(state)
		_press("REALITY_FAREWELL")
		_drain()
		_expect(_count("IRIS_" + mode.to_upper()) == 1,"exact Iris disclosure frozen")
		if mode != "public": _expect(_count("IRIS_PUBLIC") == 0,"no unearned public confession")
		_collect()


func _farewell_state(owner: String) -> Dictionary:
	var state := _fixture("EDR_FAREWELL")
	_complete_relations(state)
	state.loop_state.event_local_states.EDR_FAREWELL = {"index":WAKE.OWNERS.find(owner)}
	state.meta_progress.knowledge_entries.mara2_name_written = true
	return state


func _wake(tree: SceneTree) -> void:
	_install(_fixture("EDR_DISCONNECT"))
	_press("REALITY_DISCONNECT")
	_expect(_count("DISCONNECT_HEAT") == 1 and _count("DISCONNECT_TASTE") == 0,"sensory transition records only current line")
	# The real fade callback commits only after the last displayed line.
	for index in range(3): view._advance_dialogue()
	await tree.create_timer(1.2).timeout
	_expect(GameState.get_snapshot().ending_run.current_node_id == "EDR_WAKE_BODY","disconnect fade reaches physical body")
	_present()
	_press("REALITY_WAKE")
	_drain()
	for object in WAKE.BODY:
		_expect(_count("BODY_%s_FIRST" % object) == 0,"object label is not examination")
		_press(object)
		_drain()
		_press(object)
		_drain()
		_expect(_count("BODY_%s_FIRST" % object) == 1 and _count("BODY_%s_REPEAT" % object) == 1,"first and repeated body observations distinct")
	_press("REALITY_BODY_FINISH")
	_present()
	_expect(GameState.get_snapshot().ending_run.current_node_id == "EDR_FIELD_NOTEBOOK","body checks reach physical notebook")
	_collect()


func _field() -> void:
	_install(_unread_field())
	_present()
	_expect(_ledger().revisions.is_empty(),"page index reveals no page body")
	view._open_field_page("FIELD_NOTEBOOK_PREFACE",false)
	var opened := GameState.get_snapshot()
	view._cancel_prologue_modal()
	_expect(STATE_ASSERTIONS.same_gameplay(opened, GameState.get_snapshot(), "modal") and _ledger().revisions.is_empty(),"Esc completes the presentation but is not read confirmation")
	for page in FIELD.PAGES:
		view._open_field_page(page,false)
		view._recorded_choice_pressed(view._recorded_modal_request,0)
		_expect(_count("FIELD_%s_SUMMARY" % page) == 1,"summary acquired only after confirmation")
		view._open_field_page(page,true)
		view._recorded_choice_pressed(view._recorded_modal_request,0)
		_expect(_count("FIELD_%s_FULL" % page) == 1,"expanded page acquired")
		var total: int = _ledger().revisions.size()
		view._open_field_page(page,false)
		view._recorded_choice_pressed(view._recorded_modal_request,0)
		view._open_field_page(page,true)
		view._recorded_choice_pressed(view._recorded_modal_request,0)
		_expect(_ledger().revisions.size() == total,"reread neither downgrades nor duplicates full revision")
	_expect(_ledger().revisions.size() == 18,"nine physical pages with summary and full revisions")
	for revision in _ledger().revisions:
		_expect(revision.metadata.lifetime == "physical" and revision.metadata.knowledge_id.begins_with("REALITY_"),"physical pages not simulation notebook")
		_expect(not revision.source_refs.is_empty(),"read confirmation links actual modal source")
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"physical pages reload")
	_expect(StateSnapshotValidator.same_persisted_value(saved,GameState.get_snapshot()),"physical source revisions survive reload")
	view._render_room()
	_present()
	_collect()
	# Both owner addenda and handoff source variants, including no completed records.
	for page in FIELD.OWNERS:
		var owner: String = FIELD.OWNERS[page]
		for outcome in WAKE.OVERLAYS[owner]:
			var state := _unread_field()
			state.meta_progress.event_history[WAKE.EVENTS[owner]].outcome_id = outcome
			_install(state)
			view._open_field_page(page,true)
			view._recorded_choice_pressed(view._recorded_modal_request,0)
			_collect()
	var empty := _unread_field()
	for servant in empty.meta_progress.servants.values():
		servant.core_event_complete = false
		servant.researcher_record_acquired = false
	_install(empty)
	view._open_field_page("SUBJECT_HANDOFF_PAGE",true)
	view._recorded_choice_pressed(view._recorded_modal_request,0)
	_expect(_ledger().revisions.size() == 1,"handoff indices do not create missing research documents")
	_collect()



func _handoff_versions(tree: SceneTree, history_only: bool = false) -> void:
	var modal_notes := preload("res://scripts/systems/modal_notebook.gd")
	var field_texts := preload("res://scripts/ui/field_notebook_texts.gd")
	var cursor_rules := preload("res://scripts/systems/notebook_presentation.gd")
	var page := "SUBJECT_HANDOFF_PAGE"
	var document_id := NOTES.PREFIX + "FIELD_SUBJECT_HANDOFF_PAGE_FULL"
	var locale := TranslationServer.get_locale()
	var previous_entry := {}
	var previous_text := ""
	for mask in range(0 if history_only else 32):
		var state := _unread_field()
		for index in range(5): state.meta_progress.servants[WAKE.OWNERS[index]].researcher_record_acquired = bool(mask & (1 << index))
		_install(state)
		if not previous_entry.is_empty():
			_expect(CONTENT.render_entry(previous_entry, locale).entry.text == previous_text, "next installed relationship state cannot rewrite previous captured names")
		view._open_field_page(page, true)
		var request: Dictionary = view._recorded_modal_request
		_expect(not request.is_empty() and request.recorded, "handoff mask actually displayed and saved")
		if request.is_empty(): continue
		var descriptor: Dictionary = request.history_context.notebook_content
		_expect(int(descriptor.content_version) == 2 and descriptor == modal_notes.field_options(state, page, true), "new prompt has exact frozen mask and version")
		_expect(not request.body.contains("REC_") and request.body == field_texts.page_text(state, page, true, locale), "actual handoff contains localized names, no internal record keys")
		for language in ["ko-KR", "en-US"]:
			var document := CONTENT.presentation(NOTES.field_descriptor(state, page, true), language)
			var expected: String = field_texts.page_text(state, page, true, language)
			_expect(document.ok and document.text == expected and not document.text.contains("REC_"), "all mask translations agree with displayed physical page")
		var prompt_token: String = request.history_context.presentation_token
		view._recorded_choice_pressed(request, 0)
		_expect(_ledger().revisions.size() == 1, "indices alone do not create researcher records")
		if _ledger().revisions.is_empty(): continue
		var revision: Dictionary = _ledger().revisions.back()
		var entry: Dictionary = ARCHIVE.resolve(_archive(), revision.observation_ref).entry
		_expect(entry.observation.content_id == document_id and int(entry.observation.content_version) == 2, "confirmed handoff acquires exact new document version")
		var backed := false
		for reference in revision.source_refs:
			var source: Dictionary = ARCHIVE.resolve(_archive(), reference).entry
			if source.observation.presentation_token == prompt_token: backed = true
		_expect(backed, "physical page cites its actual displayed prompt")
		previous_entry = entry.duplicate(true)
		previous_text = CONTENT.render_entry(entry, locale).entry.text
		_collect()
		handoff_masks += 1
	# Create an old open prompt using its actual version-1 descriptor and save cursor.
	_install(_unread_field())
	_expect(view.session.initialize().ok, "historical fixture follows normal session initialization before opening a prompt")
	var initialized := GameState.get_snapshot()
	view._open_field_page(page, true)
	var actions: Array = view._recorded_modal_request.actions.duplicate(true)
	_install(initialized)
	var old_descriptor := CONTENT.descriptor("NB_MODAL_FIELD_SUBJECT_HANDOFF_PAGE_FULL_OPTIONS", 1,
		{"header": {}, "body": {}, "sources_present": {"records": "REC_EDGAR, REC_MARA1, REC_LUCA, REC_IRIS, REC_MARA2"}, "option_0": {}, "option_1": {}, "option_2": {}})
	var old_shown := CONTENT.presentation(old_descriptor, locale)
	var body := PackedStringArray()
	for segment in old_shown.segments:
		if segment.segment_id != "header" and not String(segment.segment_id).begins_with("option_"): body.append(segment.text)
	view._show_recorded_choice(field_texts.title(page, locale), "\n".join(body), actions, old_descriptor)
	_expect(view._recorded_modal_request.recorded, "historical open prompt recorded")
	var frozen_prompt: Dictionary = _archive().entries.back().duplicate(true)
	var frozen_cursor := cursor_rules.read(GameState.get_snapshot())
	var count: int = _archive().entries.size()
	view.queue_free()
	view = null
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload historical open field page from disk")
	var before_restore := GameState.get_snapshot()
	view = VIEW.new()
	view.configure_session(SLOT, "ENDING_SEQUENCE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	print("HANDOFF_RESTORE_DIFF: ", STATE_ASSERTIONS.changed_paths(before_restore, GameState.get_snapshot()))
	_expect(StateSnapshotValidator.same_persisted_value(before_restore, GameState.get_snapshot()), "restoring old prompt preserves the entire saved snapshot")
	_expect(view._modal_active and not view._recorded_modal_request.is_empty(), "recreated controller restores old open prompt")
	if view._recorded_modal_request.is_empty(): return
	_expect(int(view._recorded_modal_request.history_context.notebook_content.content_version) == 1 and view._recorded_modal_request.body.contains("REC_EDGAR"), "old prompt remains old wording, not silently upgraded")
	_expect(_archive().entries.size() == count, "restoring historical prompt adds no observation")
	var forged: Dictionary = frozen_cursor.lines[0].history_context.duplicate(true)
	forged.presentation_token = ARCHIVE.new_uid()
	var candidate := GameState.get_snapshot()
	var before := candidate.duplicate(true)
	_expect(not NOTES.write_field(candidate, page, true, NOTES.context(candidate, {}), locale, forged).ok and candidate == before, "unobserved confirmation token fails without mutation")
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(_ledger().revisions.size() == 1, "historical confirmation acquires once")
	if _ledger().revisions.is_empty(): return
	var old_entry: Dictionary = ARCHIVE.resolve(_archive(), _ledger().revisions.back().observation_ref).entry.duplicate(true)
	_expect(int(old_entry.observation.content_version) == 1, "old confirmation acquires exactly displayed version")
	var protected_prompt: Dictionary = ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(frozen_prompt, "body")).entry.duplicate(true)
	var expected_prompt := frozen_prompt.duplicate(true)
	expected_prompt.protection_reasons.append("knowledge_source:" + String(_ledger().revisions.back().revision_uid))
	expected_prompt.protection_reasons.sort()
	_expect(protected_prompt == expected_prompt and KNOWLEDGE.validate(_ledger(), _archive()).ok, "old acquisition adds exactly its source protection without changing prompt content or identity")
	for language in ["ko-KR", "en-US"]:
		_expect(CONTENT.render_entry(old_entry, language).entry.text.contains("REC_EDGAR"), "historical handoff remains replayable in both languages")
	view._open_field_page(page, true)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(_ledger().revisions.size() == 2, "explicit new-version reread adds one new revision")
	view._open_field_page(page, false)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	view._open_field_page(page, true)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_expect(_ledger().revisions.size() == 2, "new full page is neither downgraded by summary nor duplicated")
	var latest: Dictionary = ARCHIVE.resolve(_archive(), _ledger().revisions.back().observation_ref).entry
	_expect(int(latest.observation.content_version) == 2 and not CONTENT.render_entry(latest, locale).entry.text.contains("REC_"), "latest explicit reread uses public names")
	var saved: Dictionary = ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(old_entry, "body")).entry
	_expect(saved == old_entry, "new reread preserves the old document UID and original segments")
	_expect(ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(frozen_prompt, "body")).entry == protected_prompt, "new reread preserves the old displayed prompt and its source protection")
	_collect()
	historical_confirmations += 1


func _field_failures() -> void:
	_install(_unread_field())
	_present()
	view._open_field_page("FIELD_NOTEBOOK_COVER",false)
	view._recorded_choice_pressed(view._recorded_modal_request,1)
	_expect(_ledger().revisions.is_empty() and "FIELD_NOTEBOOK_COVER" not in GameState.get_snapshot().ending_run.required_interactions_seen,"expanding alone does not confirm reading")
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_game = true
	var before := GameState.get_snapshot()
	view._recorded_choice_pressed(view._recorded_modal_request,2)
	_expect(view._modal_active and _ledger().revisions.is_empty(),"failed next-page commit leaves current page and no document")
	_expect(GameState.get_snapshot().ending_run == before.ending_run,"failed read cannot satisfy required page")
	saver.reject_game = false
	saver.lose_ack = true
	view._recorded_choice_pressed(view._recorded_modal_request,2)
	_expect(_count("FIELD_FIELD_NOTEBOOK_COVER_FULL") == 1,"lost read acknowledgement reconciles one document")
	_expect("FIELD_NOTEBOOK_COVER" in GameState.get_snapshot().ending_run.required_interactions_seen,"successful next confirms previous page")
	_expect(_count("FIELD_FIELD_NOTEBOOK_FIRST_72_HOURS_SUMMARY") == 0,"next page display is not its read confirmation")
	view.session._save = SaveManager
	view._cancel_prologue_modal()
	saver.free()
	_collect()


func _surface() -> void:
	_install(_fixture("EDR_EXIT_PANEL"))
	var state := GameState.get_snapshot()
	for id in FIELD.EXIT: state.ending_run.required_interactions_seen.erase(id)
	_install(state)
	_present()
	for id in FIELD.EXIT:
		_press(id)
		_drain()
	_press("FIELD_UNLOCK")
	_present()
	for id in ["tools","plant","names"]:
		_press("SURFACE_OBJ_" + id)
		_drain()
	_press("SURFACE_MOVE")
	_present()
	for id in ["glass","stand"]:
		_press("SURFACE_OBJ_" + id)
		_drain()
	_press("SURFACE_MOVE")
	_press("SURFACE_AIRLOCK")
	_present()
	_expect(_count("AIRLOCK_SELECT_1") == 0,"world options are not a selected destination")
	_press("SURFACE_CANCEL")
	_present()
	_expect(_count("AIRLOCK_SELECT_0") == 1 and GameState.get_snapshot().ending_run.current_node_id == "EDR_FACILITY_FREE_LOOK","airlock cancel recorded without leaving")
	_press("SURFACE_AIRLOCK")
	_press("SURFACE_ENTER")
	_present()
	_press("SURFACE_OBJ_signal")
	_drain()
	_press("SURFACE_OUTSIDE")
	_present()
	for direction in ["left","center","right"]:
		_press("SURFACE_LOOK_" + direction)
		_present()
	_expect(GameState.get_snapshot().ending_run.final_decision == "reality","last gaze cannot reinterpret final ending choice")
	_collect()
	var generation := view._notebook_surfaces.generation
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"ending view reload")
	var before := GameState.get_snapshot()
	view._reality_world_choice_pressed(generation,"LOOK",0,"stale","ko-KR","surface_look","left")
	_expect(GameState.get_snapshot() == before,"stale world choice cannot affect reloaded slot")


func _surface_failure() -> void:
	_install(_fixture("EDR_FINAL_FRAME"))
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_history = true
	var before := GameState.get_snapshot()
	view._surface_active_seconds = 0.0
	view._process(1.0)
	view._on_surface_tick()
	_expect(GameState.get_snapshot() == before and view._surface_active_seconds == 0.0,"failed frame observation pauses automatic credits timer")
	_expect(not view._notebook_surface_allowed(),"save failure exposes retry")
	saver.reject_history = false
	saver.lose_ack = true
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"surface retry reconciles acknowledgement")
	_expect(_count("FINAL_FRAME_CENTER") == 1,"retry does not duplicate final frame")
	view.session._save = SaveManager
	saver.free()
	_collect()


func _legacy() -> void:
	var state := _fixture("EDR_FACILITY_FREE_LOOK")
	_install(state)
	_present()
	_expect(_ledger().revisions.is_empty(),"old read flags never backfill document content")
	view._open_field_page("FIELD_NOTEBOOK_PREFACE",false)
	view._recorded_choice_pressed(view._recorded_modal_request,0)
	_expect(_ledger().revisions.size() == 1,"only actual new reread creates a physical page")
	var saved := GameState.get_snapshot()
	for entry in _archive().entries: CONTENT.render_entry(entry,"en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
	_expect(GameState.get_snapshot() == saved,"replay cannot change page reads, branch, gaze or timer")
	_collect()


func _unread_field() -> Dictionary:
	var state := _fixture("EDR_FIELD_NOTEBOOK")
	_complete_relations(state)
	state.loop_state.event_local_states.FIELD_NOTEBOOK = {"pages":[]}
	for page in FIELD.REQUIRED: state.ending_run.required_interactions_seen.erase(page)
	return state


func _complete_relations(state: Dictionary) -> void:
	var completed := _fixture("ED_ALL_CEREMONY")
	state.meta_progress.servants = completed.meta_progress.servants.duplicate(true)
	for event in WAKE.EVENTS.values():
		state.meta_progress.event_history[event] = completed.meta_progress.event_history[event].duplicate(true)


func _fixture(stage: String) -> Dictionary:
	if not fixtures.has(stage):
		var fixture := CHECKPOINTS.new().snapshot_for(stage)
		_expect(fixture.ok,"checkpoint " + stage)
		fixtures[stage] = fixture.snapshot
	var state: Dictionary = fixtures[stage].duplicate(true)
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.knowledge_entries.chapter_notebook = {}
	return state


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	var token := "NB_REALITY_FIXTURE_%d" % serial
	var installed := StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(token))
	_expect(installed.ok,"fixture install " + str(installed.get("error_ids",[])))
	_expect(SaveManager.save_snapshot(SLOT,"SAVE_BROKEN_RESET_COMPLETE",GameState.get_snapshot(),GameState.revision,token).ok,"fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(),"actual ending surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null,"missing reality button " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(60):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false,"reality dialogue blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY,KNOWLEDGE.create())


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: count += 1
	return count


func _collect() -> void:
	runtime_audit.capture(_archive())
	var state := GameState.get_snapshot()
	for entry in _archive().entries:
		_expect(entry.get("record_class") == "authored","no unmapped reality history")
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_4" and observation.node_id.begins_with("ED"),"actual ending node context")
		for segment in observation.segments:
			covered[observation.content_id + ":" + segment.viewed_locale] = true
			segments[observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry,"en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR").ok,"bilingual replay of frozen ending observations")
	_expect(KNOWLEDGE.validate(_ledger(),_archive()).ok,"physical source references valid")
	_expect(GameState.get_snapshot() == state,"collection read only")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("REALITY_ASSERT: ",message)
