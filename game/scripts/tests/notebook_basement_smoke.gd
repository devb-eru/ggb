extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const RULES := preload("res://data/puzzles/puzzle_basement.tres")
const SLOT := "__test_notebook_basement"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var serial := 0
var view: BasementController
var checkpoints := CHECKPOINTS.new()

class ControlledSave extends Node:
	var delegate: Node
	var reject := false
	var lose_ack := false
	func get_build_flavor() -> String: return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_BASEMENT_NOTE_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_BASEMENT_NOTE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return {"ok": false, "errors": diagnostic.error_ids}
	var ids: Array = diagnostic.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP08")
	for id in ids:
		var row := CONTENT.definition(id, 1)
		for locale in row.locales: _expect(not String(row.locales[locale].title).contains(row.event_id), "basement card titles do not expose internal event codes")
	_seed("D0")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await _route(tree)
		await _storage_branches(tree)
		await _modals(tree)
		await _failures(tree)
		for id in ids:
			_expect(covered.has(id + ":" + locale), "unexecuted basement ID: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "unseen basement segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(),
		"not_covered": ["static_puzzle_board_disclosure", "D5_transition_producer", "app_restart_cursor", "OS_input", "shared_notebook_UI"]}


func _route(tree: SceneTree) -> void:
	_seed("D0")
	_room("M1_LIBRARY_INNER")
	for point in ["bedroom", "greenhouse", "great_clock"]: _act("d_drawer_point", point)
	var assembled := _latest("BASEMENT_PLAN")
	_expect(assembled.metadata.epistemic_state == "observed", "collected floorplan is not a verified orientation")
	_act("d_overlay")
	_expect(_latest("BASEMENT_PLAN").revision_uid == assembled.revision_uid, "mismatched overlay cannot verify the plan")
	for index in range(3): _act("d_rotate")
	_act("d_flip")
	_act("d_anchor", "great_clock")
	_act("d_overlay")
	var plan := _latest("BASEMENT_PLAN")
	_expect(plan.previous_revision_uid == assembled.revision_uid and plan.metadata.epistemic_state == "verified", "actual overlay verification extends the assembled record")
	_act("d_drawer_point", "bedroom")
	_act("d_overlay")
	_expect(_latest("BASEMENT_PLAN").revision_uid == plan.revision_uid, "reopening the drawer cannot regress or duplicate the verified plan")
	_room("B1_AXIS_CHAMBER")
	_act("d_axis_depth", ["line", 2])
	_push("line")
	_push("ring")
	var first_failure := _latest("BASEMENT_FAILURE")
	var first_ref: Dictionary = first_failure.observation_ref.duplicate(true)
	var locked := GameState.get_snapshot()
	_expect(not view.session.act("d_axis_push", {"value": "ring", "confirmed": true}).ok and GameState.get_snapshot() == locked, "locked input cannot become another failed attempt")
	_sleep()
	_expect(ARCHIVE.resolve(_archive(), first_ref).ok and "MANSION_FLOORPLAN" not in GameState.get_snapshot().loop_state.inventory, "sleep keeps knowledge but resets the physical floorplan")
	_act("d_shortcut")
	_expect(view._basement().basement_local().axes.depths == {"line": 2, "branch": 1, "ring": 1}, "shortcut presets only verified depths, not the untried ring answer")
	_push("line")
	_push("ring")
	_expect(_latest("BASEMENT_FAILURE").previous_revision_uid == first_failure.revision_uid, "same category on another real attempt gets another revision")
	_sleep()
	_act("d_shortcut")
	_push("line")
	_push("branch")
	_push("ring")
	_sleep()
	_act("d_shortcut")
	_push("line")
	_push("branch")
	_act("d_axis_depth", ["ring", 3])
	_push("ring")
	_act("d_axis_central", {"value": "counterclockwise", "confirmed": true})
	_expect(not view._basement().basement_local().axes.locked, "first reverse warning is not a failed attempt")
	_act("d_axis_central", {"value": "counterclockwise", "confirmed": false})
	_act("d_axis_central", {"value": "counterclockwise", "confirmed": true})
	var last_failure := _latest("BASEMENT_FAILURE")
	_sleep()
	_act("d_shortcut")
	for axis in RULES.AXES: _push(axis)
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	var before := GameState.get_snapshot()
	_expect(not view.session.act("d_axis_central", {"value": "clockwise", "confirmed": true}).ok and GameState.get_snapshot() == before, "access and failure resolution roll back atomically")
	controlled.reject = false
	controlled.lose_ack = true
	var opened := view.session.act("d_axis_central", {"value": "clockwise", "confirmed": true})
	_expect(opened.ok and _ledger().revisions.size() == before.meta_progress.knowledge_entries.notebook_knowledge.revisions.size() + 2, "lost acknowledgement commits access and resolution once")
	view.session._save = SaveManager
	controlled.free()
	_expect(_latest("BASEMENT_FAILURE").previous_revision_uid == last_failure.revision_uid and ARCHIVE.resolve(_archive(), first_ref).ok, "resolution retains the earliest failed source")
	view._feedback(opened)
	_drain()
	_collect()
	var access := _latest("BASEMENT_ACCESS")
	_sleep()
	_act("d_fastpath")
	_expect(view._basement().basement_local().axes.open and _latest("BASEMENT_ACCESS").revision_uid == access.revision_uid, "physical fast path reopens the door without inventing another access verification")
	_room("B1_STORAGE")
	_act("d_storage", "barrel")
	var second := view.session.act("d_storage", "cable")
	_expect(second.ok, "second storage observation")
	view._feedback(second)
	var partial: Dictionary = _archive().entries.back()
	_expect(not ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(partial, "line_02")).ok, "unshown doorway sentence is not an available source")
	_drain()
	_collect()
	_room("B1_CLOCKWORK_HEART")
	for handle in ["A", "B", "C", "C"]: _heart("turn", handle)
	_heart("fix")
	_heart("unfix")
	_heart("fix")
	for index in range(12): _heart("wind")
	_heart("stabilize")
	_heart("inspect_auxiliary")
	view._confirm_auxiliary()
	var before_release := GameState.get_snapshot()
	_expect(before_release.fracture_state.camouflage_filter != "disabled" and not _has("NB_BASEMENT_NOTE_D4"), "auxiliary preview does not release the filter")
	_press(2)
	_expect(view.session.stage() == "D5", "actual confirmed input reaches D5")
	var last: Dictionary = _entry("NB_BASEMENT_HEART_PULL_AUXILIARY")
	_expect(last.observation.content_id == "NB_BASEMENT_HEART_PULL_AUXILIARY" and last.observation.node_id == "D4" and last.observation.chapter_id == "CHAPTER_2", "D4 result stays in chapter two after the D5 state change")
	var heart := _latest("BASEMENT_HEART")
	_expect(heart.source_refs.size() >= 6 and _has("NB_MODAL_BASEMENT_AUXILIARY_SELECT_2"), "release record cites actually displayed stabilization and its confirmed input")
	for reference in heart.source_refs:
		var source := ARCHIVE.resolve(_archive(), reference)
		_expect(source.ok and source.entry.observation.content_id != "NB_BASEMENT_HEART_PULL_AUXILIARY", "event-written release note cannot cite its not-yet-displayed result dialogue")
	var before_read := GameState.get_snapshot()
	view._open_notebook()
	view._close_modal()
	for entry in _archive().entries:
		if entry.get("record_class") == "authored":
			var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
			_expect(rendered.ok and not rendered.entry.fallback, "authored source rereads in the other language at the same version")
	_expect(GameState.get_snapshot() == before_read, "notebook reading cannot repeat the filter release")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(before_read, GameState.get_snapshot()), "D4 notes and disclosure survive real JSON reload")
	var replayed := view.session.initialize()
	_expect(replayed.ok and replayed.notebook_feedback[0].content_id == "NB_BASEMENT_HEART_PULL_AUXILIARY", "inherited initialization retains explicit D4 source")
	_collect()
	await tree.process_frame


func _storage_branches(tree: SceneTree) -> void:
	for object_id in ["barrel", "cable", "filter", "drawing"]:
		for door in [false, true]:
			var state := _seed("D2")
			state.loop_state.location_id = "B1_STORAGE"
			state.loop_state.event_local_states.BASEMENT.storage_seen = ["cable" if object_id == "barrel" else "barrel"] if door else []
			_install(state)
			_act("d_storage", object_id)
			_expect(_has("NB_BASEMENT_STORAGE_" + String(object_id).to_upper() + "_DOOR") == door, "door sentence follows actual investigation count")
			await tree.process_frame
	var state := _seed("D1")
	state.meta_progress.failure_knowledge.erase("D1")
	state.loop_state.location_id = "B1_AXIS_CHAMBER"
	state.loop_state.event_local_states.BASEMENT.axes = RULES.axis_default()
	state.loop_state.event_local_states.BASEMENT.axes.pushed = RULES.AXES.duplicate()
	_install(state)
	_act("d_axis_central", {"value": "clockwise", "confirmed": true})
	_expect(not _has("NB_BASEMENT_NOTE_RESOLVED") and _ledger().revisions.size() == 1, "legacy verified flags cannot create missing old notes or an absent failure")
	# The public demo deliberately does not display the full-game D4 result dialogue.
	_prepare_modal("auxiliary", "")
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	var released := view.session.act("d_heart", {"action": "pull_auxiliary", "confirmed": true})
	_expect(released.ok and _has("NB_BASEMENT_NOTE_D4"), "demo still commits the event-written release note")
	var recorded := _archive()
	view._feedback(released)
	_expect(_archive() == recorded and not _has("NB_BASEMENT_HEART_PULL_AUXILIARY"), "suppressed demo feedback cannot acquire a displayed observation")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	await tree.process_frame


func _modals(tree: SceneTree) -> void:
	for spec in [["axis", "line", 3], ["axis", "branch", 3], ["axis", "ring", 3], ["central", "clockwise", 2], ["central", "counterclockwise", 2], ["auxiliary", "", 3]]:
		for index in range(spec[2]):
			_prepare_modal(spec[0], spec[1])
			view.callv("_confirm_" + spec[0], [] if spec[0] == "auxiliary" else [spec[1]])
			_expect(view._modal_active and not view._recorded_modal_request.is_empty(), "real basement confirmation opens")
			var request := view._recorded_modal_request.duplicate(true)
			var before := GameState.get_snapshot()
			_collect()
			_press(index)
			var choice: Dictionary = request.row.choices[index]
			if choice.kind != "confirm":
				_expect(GameState.get_snapshot().loop_state == before.loop_state and GameState.get_snapshot().fracture_state == before.fracture_state, "review or cancellation cannot operate the mechanism")
			if choice.kind != "ui":
				var selected := _entry(choice.content_id)
				_expect(selected.observation.event_occurrence_id == request.history_context.event_occurrence_id and selected.observation.conversation_session_id == request.history_context.conversation_session_id, "selection belongs to the displayed target")
			await tree.process_frame


func _failures(tree: SceneTree) -> void:
	_prepare_modal("axis", "line")
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	var before := GameState.get_snapshot()
	view._confirm_axis("line")
	var request := view._recorded_modal_request
	_press(2)
	_expect(GameState.get_snapshot() == before and view._modal_active, "failed modal observation blocks irreversible input")
	view._cancel_prologue_modal()
	_expect(view._modal_active and GameState.get_snapshot() == before, "failed cancel leaves its original modal")
	controlled.reject = false
	controlled.lose_ack = true
	view._cancel_prologue_modal()
	_expect(not view._modal_active and GameState.get_snapshot().loop_state == before.loop_state, "lost-ack cancellation records once and does not push the axis")
	_expect(_entry("NB_MODAL_BASEMENT_AXIS_LINE_SELECT_1").observation.event_occurrence_id == request.history_context.event_occurrence_id, "retry preserves modal occurrence")
	view.session._save = SaveManager
	controlled.free()
	_collect()
	_prepare_modal("axis", "line")
	view._confirm_axis("line")
	var stale: Callable = view._modal_body.get_child(5).pressed.get_connections()[0].callable
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload while confirmation exists")
	before = GameState.get_snapshot()
	stale.call()
	_expect(GameState.get_snapshot() == before, "pre-load confirmation cannot operate the newly loaded state")
	view._cancel_prologue_modal()
	_prepare_modal("auxiliary", "")
	controlled = ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	before = GameState.get_snapshot()
	_expect(not view.session.act("d_heart", {"action": "pull_auxiliary", "confirmed": true}).ok and GameState.get_snapshot() == before, "release note, filter change and D5 reaction freeze roll back together")
	controlled.reject = false
	controlled.lose_ack = true
	var result := view.session.act("d_heart", {"action": "pull_auxiliary", "confirmed": true})
	_expect(result.ok and _ledger().revisions.size() == 1, "lost release acknowledgement creates only one note")
	controlled.lose_ack = false
	controlled.reject = true
	before = GameState.get_snapshot()
	view._feedback(result)
	var token: String = view._dialogue_lines[0].presentation_token
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == before and view._dialogue_lines[0].presentation_token == token, "failed D4 display retains its original token after gameplay commit")
	controlled.reject = false
	view._advance_dialogue()
	_expect(not view._dialogue_active and _archive().entries.size() == before.meta_progress.dialogue_history.entries.size() + 1, "display retry adds exactly one D4 observation")
	view.session._save = SaveManager
	controlled.free()
	_collect()
	await tree.process_frame


func _prepare_modal(kind: String, target: String) -> void:
	var state := _seed("D4" if kind == "auxiliary" else "D1")
	state.loop_state.location_id = "B1_CLOCKWORK_HEART" if kind == "auxiliary" else "B1_AXIS_CHAMBER"
	var local: Dictionary = state.loop_state.event_local_states.BASEMENT
	if kind == "auxiliary":
		local.heart = RULES.heart_default()
		local.heart.merge({"rings": RULES.RING_TARGET.duplicate(), "fixed": true, "wind": 12, "stable_attempt_seen": true, "auxiliary_seen": true}, true)
	else:
		local.axes = RULES.axis_default()
		local.axes.depths = RULES.DEPTHS.duplicate()
		local.axes.pushed = RULES.AXES.duplicate() if kind == "central" else RULES.AXES.slice(0, RULES.AXES.find(target))
	_install(state)


func _sleep() -> void:
	_room("M2_BEDROOM")
	_act("routine")
	_expect(view.session.sleep().ok, "actual normal reset after basement work")


func _push(axis: String) -> void:
	_act("d_axis_push", {"value": axis, "confirmed": true})


func _heart(action: String, value: Variant = null) -> void:
	_act("d_heart", {"action": action, "value": value, "confirmed": true})


func _press(index: int) -> void:
	view._modal_body.get_child(3 + index).pressed.emit()
	_drain()
	_collect()


func _act(action: String, value: Variant = null) -> Dictionary:
	var result := view.session.act(action, value)
	_expect(result.ok, "actual action " + action + ": " + str(result))
	if result.ok:
		view._feedback(result)
		_drain()
	_collect()
	return result


func _drain() -> void:
	for index in range(20):
		if not view._dialogue_active: return
		var before := GameState.get_snapshot()
		view._present_dialogue_line()
		_expect(GameState.get_snapshot() == before, "dialogue redraw is idempotent")
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		view._advance_dialogue()
		if view._dialogue_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			_expect(false, "blocked basement dialogue: " + str(view._dialogue_lines[view._dialogue_index]))
			view._dismiss_dialogue_for_test()
			return
	_expect(false, "dialogue did not terminate")


func _seed(id: String) -> Dictionary:
	if view != null:
		view._close_modal()
		view._dismiss_dialogue_for_test()
		view.set_process(false)
	var fixture := checkpoints.snapshot_for(id)
	_expect(fixture.ok, "checkpoint " + id)
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	GameState.reset_for_test()
	_install(state)
	return state


func _room(id: String) -> void:
	var state := GameState.get_snapshot()
	state.loop_state.location_id = id
	if id == "M1_LIBRARY_INNER": state.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "absent"
	_install(state)


func _install(state: Dictionary) -> void:
	serial += 1
	var result := StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_BASEMENT_FIXTURE_%d" % serial))
	_expect(result.ok, "fixture install: " + str(result.get("error_ids", [])))


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _latest(id: String) -> Dictionary:
	var revisions: Array = _ledger().revisions
	for index in range(revisions.size() - 1, -1, -1):
		if revisions[index].metadata.knowledge_id == id: return revisions[index]
	_expect(false, "missing knowledge revision: " + id)
	return {}


func _has(id: String) -> bool:
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: return true
	return false


func _entry(id: String) -> Dictionary:
	var entries: Array = _archive().entries
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].get("record_class") == "authored" and entries[index].observation.content_id == id: return entries[index]
	_expect(false, "missing authored entry: " + id)
	return {}


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "new basement observation cannot silently become unmapped")
			continue
		if entry.observation.producer_id != "NP08": continue
		for segment in entry.observation.segments:
			covered[entry.observation.content_id + ":" + segment.viewed_locale] = true
			segments[entry.observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("BASEMENT_NOTE_ASSERT: ", message)
