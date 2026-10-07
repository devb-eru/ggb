extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/stay_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const SLOT := "__test_notebook_stay"
var errors := PackedStringArray()
var fixtures := {}
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var checks := 0
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()

class ControlledSave extends Node:
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok":false,"error_ids":["ERR_TEST_STAY_SAVE"]}
		var result := SaveManager.save_snapshot(slot,point,state,revision,transaction)
		return {"ok":false,"error_ids":["ERR_TEST_STAY_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary: return SaveManager.confirm_snapshot_commit(slot,transaction)
	func capture_f3_reselect(slot: String) -> Dictionary: return SaveManager.capture_f3_reselect(slot)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor","full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_install(_fixture("EDS_MEMORY_CHARTER"))
	view = VIEW.new()
	view.configure_session(SLOT,"ENDING_SEQUENCE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	var focused := "--notebook-stay-neutral-only" in OS.get_cmdline_user_args()
	for language in ["ko-KR","en-US"]:
		TranslationServer.set_locale(language)
		if focused:
			_neutral_status()
			continue
		print("STAY_PHASE: ",language," charter and communication")
		_charter()
		print("STAY_PHASE: ",language," table branches and seating")
		_tables()
		_seating()
		print("STAY_PHASE: ",language," writing, retry and disclosure")
		_writing()
		_failures()
		_modal_failures()
		_neutral_status()
		_credits_excluded()
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
	print("STAY_COVERAGE: actual ID/locales=",covered.size()," segment/locales=",segments.size())
	print("STAY_ASSERTIONS: ", checks, " focused=", focused)
	_expect(runtime_audit.emit("stay-focused" if focused else "stay", errors.is_empty()).ok, "runtime trace validates")
	return {"ok":errors.is_empty(),"errors":errors,"actual_id_locales":covered.size(),"actual_segment_locales":segments.size(),"not_covered":["durable_app_restart_cursor","unified_notebook_UI","OS_input"]}


func _neutral_status() -> void:
	_install(_fixture("EDS_APPEARANCE_CONTROL"))
	_present()
	_expect(_count("APPEARANCE_NEUTRAL_LABEL") == 1, "visible neutral rule label is recorded")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 0, "unclicked neutral rule detail is not disclosed")
	var before := GameState.get_snapshot()
	_press("STAY_MODE_NEUTRAL")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 1, "clicked neutral rule detail is recorded")
	_expect(not view._status_label.text.contains("S5"), "neutral rule detail never exposes internal stage ID")
	_neutral_gameplay_unchanged(before)
	var entry: Dictionary = _archive().entries.back()
	_expect(entry.observation.content_id == NOTES.PREFIX + "APPEARANCE_NEUTRAL_DETAIL" and entry.observation.node_id == "EDS_APPEARANCE_CONTROL", "neutral detail keeps actual source node")
	var opposite := "ko-KR" if TranslationServer.get_locale().begins_with("en") else "en-US"
	var rendered := CONTENT.render_entry(entry, opposite)
	_expect(rendered.ok and not rendered.entry.text.contains("S5"), "neutral detail replays in other language without internal ID")
	_press("STAY_MODE_NEUTRAL")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 2, "explicit repeat inspection is a distinct observation")
	view._render_room()
	_present()
	_expect(_count("APPEARANCE_NEUTRAL_LABEL") == 1 and _count("APPEARANCE_NEUTRAL_DETAIL") == 2, "repaint does not manufacture status or label observations")
	var generation := view._notebook_surfaces.generation
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "neutral observations load from disk")
	before = GameState.get_snapshot()
	view._inspect_stay_display_rule(generation)
	_expect(GameState.get_snapshot() == before, "stale status callback cannot write after external load")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 2, "neutral observations persist after reload")
	_collect()
	_install(_fixture("EDS_APPEARANCE_CONTROL"))
	_present()
	before = GameState.get_snapshot()
	var hash_before := FileAccess.get_sha256(SaveManager._slot_paths(SLOT).main)
	var saver := ControlledSave.new()
	saver.reject_history = true
	view.session._save = saver
	_press("STAY_MODE_NEUTRAL")
	_expect(GameState.get_snapshot() == before and FileAccess.get_sha256(SaveManager._slot_paths(SLOT).main) == hash_before, "failed neutral observation preserves gameplay and disk")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 0 and view._hotspot_layer.get_node_or_null("NOTEBOOK_SURFACE_RETRY") != null, "failed neutral observation exposes explicit retry without disclosure")
	saver.reject_history = false
	saver.lose_ack = true
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation, true), "neutral retry reconciles lost acknowledgement")
	_expect(_count("APPEARANCE_NEUTRAL_DETAIL") == 1, "neutral retry records exactly one observation")
	_neutral_gameplay_unchanged(before)
	view.session._save = SaveManager
	saver.free()
	_collect()


func _neutral_gameplay_unchanged(before: Dictionary) -> void:
	var after := GameState.get_snapshot()
	var receipt := preload("res://scripts/systems/notebook_surface_receipt.gd")
	_expect(StateSnapshotValidator.new().validate(after).ok and not receipt.read(after, view._notebook_surface_scope()).is_empty(), "neutral receipt and full snapshot validate")
	after.meta_progress.dialogue_history = before.meta_progress.dialogue_history.duplicate(true)
	if before.loop_state.event_local_states.has(receipt.KEY):
		after.loop_state.event_local_states[receipt.KEY] = before.loop_state.event_local_states[receipt.KEY].duplicate(true)
	else: after.loop_state.event_local_states.erase(receipt.KEY)
	_expect(StateSnapshotValidator.same_persisted_value(before, after), "neutral observation changes no policy, appearance, memory, relationship or ending")


func _charter() -> void:
	_install(_fixture("EDS_MEMORY_CHARTER"))
	_present()
	for index in range(3):
		_expect(_count("MEMORY_%d" % index) == 0,"principle label is not its body")
		_press("STAY_MEMORY_%d" % index)
		_expect(_count("MEMORY_%d" % index) == 1,"principle displayed immediately")
		_drain()
	_press("STAY_MEMORY_FINISH")
	_present()
	_press("STAY_LAYERED")
	_present()
	_press("STAY_CONTEXTUAL")
	_present()
	for index in [0,1,2]:
		view._show_stay_mode_settings()
		if index == 0: view._cancel_prologue_modal()
		else: view._recorded_choice_pressed(view._recorded_modal_request,index)
		_present()
	_press("STAY_APPEARANCE_FINISH")
	_present()
	for owner in NOTES.STORY.OWNERS:
		_press("STAY_ROLE_" + owner)
		_present()
		_press("STAY_ROLE_" + owner)
		_present()
	_press("STAY_AUTONOMY_FINISH")
	_present()
	for id in NOTES.STORY.HALL:
		if id == "cord": continue
		_expect(_count("HALL_READ_" + String(id).to_upper()) == 0,"unexamined hall object is not disclosed")
		_press("STORY_HALL_" + id)
		_drain()
	for index in range(6):
		_press("STORY_HALL_cord")
		if index == 0: view._cancel_prologue_modal()
		else: view._recorded_choice_pressed(view._recorded_modal_request,index)
		_present()
	_expect(GameState.get_snapshot().ending_run.final_decision == "stay","policies do not reinterpret ending")
	_collect()
	_press("STORY_DINE")
	_present()
	_press("STORY_SIT")
	_drain()
	_collect()


func _tables() -> void:
	for owner in NOTES.STORY.OWNERS:
		var state := _fixture("EDS_TABLE_OBJECTS")
		state.meta_progress.servants[owner].core_event_complete = false
		_install(state)
		_present()
		_expect(_count("TABLE_%s_INCOMPLETE" % String(owner).to_upper()) == 0,"table label does not disclose dialogue")
		_press("STORY_TABLE_" + owner)
		_drain()
		_collect()
		for outcome in WAKE.OVERLAYS[owner]:
			state = _fixture("EDS_TABLE_OBJECTS")
			_complete_relations(state)
			state.meta_progress.event_history[WAKE.EVENTS[owner]].outcome_id = outcome
			_install(state)
			_press("STORY_TABLE_" + owner)
			_expect(_count("OVERLAY_" + String(outcome).to_upper()) == 0,"unadvanced overlay not disclosed")
			_drain()
			_expect(_count("OVERLAY_" + String(outcome).to_upper()) == 1,"exact completed outcome recorded")
			_collect()
		state.meta_progress.event_history[WAKE.EVENTS[owner]].outcome_id = "unknown_legacy_outcome"
		_install(state)
		_press("STORY_TABLE_" + owner)
		_drain()
		for outcome in WAKE.OVERLAYS[owner]: _expect(_count("OVERLAY_" + String(outcome).to_upper()) == 0,"corrupt metadata cannot invent an overlay")
		_collect()
	for mode in ["public","direct_private","indirect","denied","withheld","inferred_only"]:
		var state := _fixture("EDS_TABLE_OBJECTS")
		for servant in state.meta_progress.servants.values(): servant.core_event_complete = mode == "public"
		state.meta_progress.servants.iris.core_event_complete = mode != "inferred_only"
		state.meta_progress.servants.iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		state.meta_progress.servants.iris.alert = 4 if mode == "denied" else 0
		_expect(NOTES.STORY.RESEARCHERS.iris_state(state) == mode,"Iris fixture")
		_install(state)
		_press("STORY_TABLE_iris")
		_drain()
		_expect(_count("IRIS_" + String(mode).to_upper()) == 1,"Iris disclosure frozen")
		if mode != "public": _expect(_count("IRIS_PUBLIC") == 0,"no compulsory confession")
		_collect()


func _seating() -> void:
	# Every membership subset, not only a scalar relationship count.
	for mask in range(32):
		var state := _fixture("EDS_DINING_ROOM")
		for index in range(5): state.meta_progress.servants[NOTES.STORY.OWNERS.keys()[index]].core_event_complete = bool(mask & (1 << index))
		_install(state)
		_present()
		_expect(_count("SEATING_READ") == 0,"seating board not duplicate dialogue")
		_press("STORY_SIT")
		_drain()
		_collect()
		state = GameState.get_snapshot()
		state.ending_run.current_node_id = "EDS_FINAL_FRAME"
		state.loop_state.event_local_states.STAY_STORY = {"elapsed":0}
		_install(state)
		_present()
		_expect(_count("FINAL_SEATING") == 0,"two-second transition not revealed early")
		_expect(view.session.act("story_tick").ok,"first final frame tick")
		_expect(view.session.act("story_tick").ok,"second final frame tick")
		view._render_room()
		_present()
		_expect(_count("FINAL_OPENING") == 1 and _count("FINAL_SEATING") == 1,"both actual frame stages recorded")
		_collect()


func _writing() -> void:
	var state := _fixture("EDS_TABLE_OBJECTS")
	state.loop_state.event_local_states.STAY_STORY = {}
	_install(state)
	_present()
	_expect(_ledger().revisions.is_empty(),"sentence options are not written sentences")
	for index in range(2):
		_press("STORY_WRITE_%d" % index)
		_present()
		_press("STORY_WRITE_%d" % index)
		_present()
	_expect(_ledger().revisions.size() == 2,"repeat writing does not duplicate knowledge")
	for index in range(2):
		_expect(_source_ids(_ledger().revisions[index]) == ["NB_STAY_NOTE_%d" % index,"NB_STAY_WRITE_%d_NEW_OPTIONS" % index,"NB_STAY_WRITE_%d_NEW_SELECT_0" % index],"sentence protects itself and links actual option and selection")
	for tea in ["usual","warm","hot"]:
		for target in ["WARM","HOT"]:
			state = GameState.get_snapshot()
			state.loop_state.event_local_states.STAY_STORY.tea = tea
			_install(state)
			_press("STORY_TEA_" + target)
			_present()
			_collect()
	var saved := GameState.get_snapshot()
	for entry in _archive().entries: CONTENT.render_entry(entry,"en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
	_expect(GameState.get_snapshot() == saved,"replay cannot change tea, policy, writing or ending")
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"written sentence reload")
	_expect(_ledger().revisions.size() == 2,"atomic sentence revisions persist across reload")
	_collect()


func _failures() -> void:
	var state := _fixture("EDS_TABLE_OBJECTS")
	state.loop_state.event_local_states.STAY_STORY = {}
	_install(state)
	_present()
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_game = true
	_press("STORY_WRITE_0")
	_expect(_ledger().revisions.is_empty() and NOTES.STORY.progress(GameState.get_snapshot()).written.is_empty(),"failed game commit cannot acquire sentence or writing flag")
	_expect(_count("WRITE_0_NEW_SELECT_0") == 1,"actual selection retained separately from failed application")
	saver.reject_game = false
	saver.lose_ack = true
	_press("STORY_WRITE_0")
	_present()
	_expect(_ledger().revisions.size() == 1 and _count("WRITE_0_NEW_SELECT_0") == 1,"lost acknowledgement reconciles without duplicate choice")
	_collect()
	view.session._save = SaveManager
	state = _fixture("EDS_FINAL_FRAME")
	state.loop_state.event_local_states.STAY_STORY = {"elapsed":0}
	_install(state)
	view.session._save = saver
	saver.lose_ack = false
	saver.reject_history = true
	var before := GameState.get_snapshot()
	view._surface_active_seconds = 0.0
	view._process(1.0)
	_expect(GameState.get_snapshot() == before and view._surface_active_seconds == 0.0,"unrecorded final frame blocks timer advance")
	_expect(not view._notebook_surface_allowed(),"surface failure requires explicit retry")
	saver.reject_history = false
	saver.lose_ack = true
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"explicit surface retry reconciles acknowledgement")
	_expect(_count("FINAL_OPENING") == 1,"surface retry idempotent")
	view.session._save = SaveManager
	saver.free()
	_collect()
	state = _fixture("EDS_TABLE_OBJECTS")
	state.loop_state.event_local_states.STAY_STORY = {"written":[0,1]}
	_install(state)
	_present()
	var generation := view._notebook_surfaces.generation
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"stale input fixture reload")
	before = GameState.get_snapshot()
	view._stay_world_choice_pressed(generation,"TEA_USUAL",0,"stale","ko-KR","story_tea","warm")
	_expect(GameState.get_snapshot() == before,"old scene callback cannot mutate reloaded slot")
	_expect(_ledger().revisions.is_empty(),"old writing flags never backfill new records")
	_press("STORY_WRITE_0")
	_expect(_ledger().revisions.is_empty(),"stale scene cannot reacquire after load")
	view._render_room()
	_present()
	_press("STORY_WRITE_0")
	_present()
	_expect(_ledger().revisions.size() == 1,"explicit new rewrite acquires only the current sentence")
	_expect(_source_ids(_ledger().revisions[0]) == ["NB_STAY_NOTE_0","NB_STAY_WRITE_0_WRITTEN_OPTIONS","NB_STAY_WRITE_0_WRITTEN_SELECT_0"],"legacy rewrite cites itself and current written-state option/click, not invented original sources")
	_collect()


func _modal_failures() -> void:
	_install(_fixture("EDS_CENTRAL_HALL"))
	_present()
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_history = true
	var before := GameState.get_snapshot()
	view._story_channel_menu()
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request,1)
	_expect(view._modal_active and GameState.get_snapshot() == before,"unsaved channel prompt cannot apply a choice")
	saver.reject_history = false
	saver.lose_ack = true
	view._recorded_choice_pressed(request,1)
	_present()
	_expect(_count("CHANNEL_OPTIONS") == 1 and _count("CHANNEL_SELECT_1") == 1,"channel prompt and click reconcile lost acknowledgement")
	_expect(NOTES.STORY.progress(GameState.get_snapshot()).channel == "edgar","only chosen communication target applied")
	view.session._save = SaveManager
	saver.free()
	_collect()
	view._story_channel_menu()
	request = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"modal reload")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request,2)
	_expect(GameState.get_snapshot() == before,"old modal context cannot select in reloaded scope")
	view._close_modal()


func _credits_excluded() -> void:
	_install(_fixture("CREDITS_STAY"))
	var before := _archive()
	_present()
	_press("CREDITS_START")
	_present()
	for index in range(2):
		_press("CREDITS_NEXT")
		_present()
	_press("CREDITS_FINISH")
	_present()
	_expect(GameState.get_snapshot().ending_run.current_node_id == "ENDING_POST_CREDITS","actual credits reach post-credits")
	_expect(_archive() == before,"credits and post-credits UI are not investigation material")


func _complete_relations(state: Dictionary) -> void:
	var completed := _fixture("ED_ALL_CEREMONY")
	state.meta_progress.servants = completed.meta_progress.servants.duplicate(true)
	for event in WAKE.EVENTS.values(): state.meta_progress.event_history[event] = completed.meta_progress.event_history[event].duplicate(true)


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
	var token := "NB_STAY_FIXTURE_%d" % serial
	var installed := StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(token))
	_expect(installed.ok,"fixture install " + str(installed.get("error_ids",[])))
	_expect(SaveManager.save_snapshot(SLOT,"SAVE_BROKEN_RESET_COMPLETE",GameState.get_snapshot(),GameState.revision,token).ok,"fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(),"actual stay surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null,"missing stay button " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(60):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false,"stay dialogue blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY,KNOWLEDGE.create())


func _source_ids(revision: Dictionary) -> Array:
	var ids: Array = []
	for ref in revision.source_refs:
		var resolved := ARCHIVE.resolve(_archive(),ref)
		_expect(resolved.ok,"acquired source must resolve")
		if resolved.ok: ids.append(resolved.entry.observation.content_id)
	ids.sort()
	return ids


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: count += 1
	return count


func _collect() -> void:
	var state := GameState.get_snapshot()
	runtime_audit.capture(_archive())
	for entry in _archive().entries:
		_expect(entry.get("record_class") == "authored","no unmapped stay history")
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_4" and observation.node_id.begins_with("EDS_"),"actual stay node context")
		for segment in observation.segments:
			covered[observation.content_id + ":" + segment.viewed_locale] = true
			segments[observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry,"en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR").ok,"bilingual replay")
	_expect(KNOWLEDGE.validate(_ledger(),_archive()).ok,"sentence source references valid")
	_expect(GameState.get_snapshot() == state,"collection read only")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("STAY_ASSERT: ",message)
