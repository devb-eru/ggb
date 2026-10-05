extends RefCounted

const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")
const SLOT := "__test_notebook_mirror"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var serial := 0
var recovery_cases := 0
var view: BlackMirrorController
var checkpoints := CHECKPOINTS.new()
var coverage := preload("res://scripts/tests/notebook_puzzle_coverage.gd").new()

class ControlledSave extends Node:
	var delegate: Node
	var reject := false
	var reject_game := false
	var rejected_game_saves := 0
	var lose_ack := false
	func get_build_flavor() -> String:
		return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject_game and not transaction.begins_with("HISTORY_"):
			rejected_game_saves += 1
			return {"ok": false, "error_ids": ["ERR_TEST_MIRROR_DISK"]}
		if reject: return {"ok": false, "error_ids": ["ERR_TEST_MIRROR_DISK"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_MIRROR_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return {"ok": false, "errors": diagnostic.error_ids}
	var ids: Array = coverage.owned_ids("mirror")
	_seed("C0")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await _route(tree)
		await _branches(tree)
		await _failures(tree)
		await _choice_recovery(tree)
		for id in ids:
			_expect(covered.has(id + ":" + locale), "unexecuted mirror ID: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "unseen mirror segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(),
		"choice_recovery_cases": recovery_cases, "guard_fixtures": ["MIXTURE_ORDER"], "not_covered": ["static_puzzle_board_disclosure", "app_restart_cursor", "OS_input", "shared_notebook_UI"]}


func _route(tree: SceneTree) -> void:
	var state := _seed("C0")
	state.meta_progress.knowledge_entries.erase("MEM_FATHER_TEA_HAND_FRAGMENT")
	_install(state)
	_room("M1_MIRROR_GALLERY")
	_act("c_observe")
	_expect(not _has("NB_MIRROR_OBSERVE_WARNING"), "low alert cannot disclose the warning variant")
	_act("c_hypothesis")
	var hypothesis := _latest("MIRROR_COATING")
	var observation_count: int = _archive().entries.size()
	_act("c_observe")
	_expect(_latest("MIRROR_COATING").revision_uid == hypothesis.revision_uid and _archive().entries.size() == observation_count + 1, "re-observation records dialogue without regressing the existing hypothesis")
	_act("c_hypothesis")
	_expect(_latest("MIRROR_COATING").revision_uid == hypothesis.revision_uid, "rechecking the same hypothesis does not manufacture another revision")
	var invalid_note := GameState.get_snapshot()
	var invalid_before := invalid_note.duplicate(true)
	_expect(not view.MIRROR_SESSION.MIRROR_NOTES.write(invalid_note, "C0", "unmatched source", view.session.history_context(), TranslationServer.get_locale()).ok and invalid_note == invalid_before, "superseded notes still validate their source before skipping")
	_room("M1_TOOL_ROOM")
	_act("c_read_cleaning")
	var prior: int = _ledger().revisions.size()
	_act("c_read_cleaning")
	_expect(_ledger().revisions.size() == prior, "unchanged cleaning record is not another revision")
	_room("M1_KITCHEN")
	_act("c_read_chemicals")
	_act("c_prepare")
	_act("c_test")
	_act("c_discard")
	_mix()
	var formula := _latest("MIRROR_FORMULA")
	_expect(formula.source_refs.size() == 3 and formula.metadata.epistemic_state == "verified", "formula cites both acquired documents and its own writing")
	_room("M1_GREAT_CLOCK")
	_act("c_bell")
	_room("M1_MIRROR_GALLERY")
	_act("c_wet", true)
	var failure := _latest("MIRROR_FAILURE")
	var failure_ref: Dictionary = failure.observation_ref.duplicate(true)
	var locked := GameState.get_snapshot()
	_expect(not view.session.act("c_wet", true).ok and GameState.get_snapshot() == locked, "locked-day retry is not another failed attempt")
	_room("M2_BEDROOM")
	_act("routine")
	var reset := view.session.sleep()
	_expect(reset.ok, "normal physical reset after the failed mirror")
	_expect(not view.session.mirror_local().cleaner_ready and not view.session.mirror_local().locked, "physical mixture and hardened coating reset")
	_expect(ARCHIVE.resolve(_archive(), failure_ref).ok, "failure revision survives normal reset")
	_act("c_shortcut")
	_mix()
	_expect(_latest("MIRROR_FORMULA").revision_uid == formula.revision_uid, "making fresh physical solution does not rewrite the known formula")
	_room("M1_GREAT_CLOCK")
	_act("c_bell")
	_room("M1_MIRROR_GALLERY")
	_act("c_wet", true)
	var repeated := _latest("MIRROR_FAILURE")
	_expect(repeated.previous_revision_uid == failure.revision_uid and repeated.revision_uid != failure.revision_uid, "the same diagnosis on a new failed attempt still gets a new immutable revision")
	failure = repeated
	_room("M2_BEDROOM")
	_act("routine")
	_expect(view.session.sleep().ok, "second failed attempt uses the same physical reset")
	_act("c_shortcut")
	_mix()
	_room("M1_GREAT_CLOCK")
	_act("c_bell")
	_room("M1_MIRROR_GALLERY")
	_act("c_handle_patrol", "question")
	_act("c_rotate")
	_act("c_anchor")
	for part in RULES.PATH: _act("c_segment", part)
	view._do("c_dry")
	_expect(view._modal_active and view._recorded_modal_request.recorded, "real dry route uses its NP05 display owner")
	view._close_modal()
	_act("c_verify_plan")
	var plan := _latest("MIRROR_PLAN")
	_expect(plan.source_refs.size() > 2, "verified plan cites actually displayed route segments")
	_act("c_wet", true)
	var raw := _latest("MIRROR_TRACING")
	var raw_entry := ARCHIVE.resolve(_archive(), raw.observation_ref)
	var raw_text := String(raw_entry.entry.observation.segments[0].captured_text)
	_expect(not raw_text.contains("마라") and not raw_text.contains("Mara") and not _has("NB_MIRROR_SCAN_SURFACE_MARA2"), "raw capture does not auto-disclose unscanned channels")
	var channel_result := view.session.act("c_scan", "EDGAR")
	_expect(channel_result.ok, "Edgar channel action")
	view._feedback(channel_result)
	var first: Dictionary = _archive().entries.back()
	_expect(first.observation.content_id == "NB_MIRROR_SCAN_SURFACE_EDGAR", "selected channel gets its own explicit source")
	_expect(not ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(first, "line_02")).ok, "unshown second channel sentence is not a valid source")
	view._dismiss_dialogue_for_test()
	for owner in ["MARA1", "LUCA", "IRIS", "MARA2"]: _act("c_scan", owner)
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	var before := GameState.get_snapshot()
	_expect(not view.session.act("c_record").ok and GameState.get_snapshot() == before, "C5 capture and failure resolution roll back together")
	controlled.reject = false
	controlled.lose_ack = true
	var recorded := view.session.act("c_record")
	_expect(recorded.ok, "C5 commit acknowledgement loss recovered from exact saved state")
	view.session._save = SaveManager
	controlled.free()
	_expect(_ledger().revisions.size() == before.meta_progress.knowledge_entries.notebook_knowledge.revisions.size() + 2, "C5 and failure resolution are one two-revision commit")
	var compared := _latest("MIRROR_TRACING")
	_expect(compared.previous_revision_uid == raw.revision_uid, "identified channels extend rather than replace the raw tracing")
	for reference in compared.source_refs:
		if reference.uid == first.entry_uid: _expect(reference.segment_id == "line_01", "only the disclosed Edgar segment is cited")
	_expect(_latest("MIRROR_FAILURE").previous_revision_uid == failure.revision_uid and ARCHIVE.resolve(_archive(), failure_ref).ok, "resolved failure keeps its immutable diagnosis")
	view._feedback(recorded)
	_drain()
	prior = _ledger().revisions.size()
	_act("c_record")
	_expect(_ledger().revisions.size() == prior, "rechecking compared channels does not append revisions")
	_room("M1_LIBRARY_INNER")
	_restore_j3(false)
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real mirror archive reload")
	_expect(StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "notes, references and observations survive JSON reload")
	_collect()
	await tree.process_frame


func _mix() -> void:
	for index in range(5): _act("c_pour", "water")
	_act("c_pour", "stabilizer")
	_act("c_disperse")
	for index in range(2): _act("c_pour", "active")
	_act("c_test")
	_act("c_mix")
	_act("c_mix")
	_act("c_test")
	_act("c_settle")
	_act("c_test")


func _branches(tree: SceneTree) -> void:
	var state := _seed("C0")
	state.meta_progress.servants.edgar.alert = 4
	state.meta_progress.knowledge_entries.c1_cleaning_hypothesis = true
	state.loop_state.location_id = "M1_MIRROR_GALLERY"
	_install(state)
	_act("c_observe")
	_expect(_latest("MIRROR_COATING").metadata.epistemic_state == "observed", "legacy hypothesis flags do not suppress a newly acquired observation")
	for mode in ["wait", "cloth"]:
		_seed("C4")
		_room("M1_MIRROR_GALLERY")
		_act("c_handle_patrol", mode)
	for spec in [[0, true, false, []], [90, false, true, []], [90, false, true, ["entry"]], [90, false, true, ["entry", "long_branch", "short_branch"]], [90, false, true, ["entry", "counterclockwise_ring"]], [90, false, true, RULES.PATH]]:
		state = _seed("C4")
		state.loop_state.location_id = "M1_MIRROR_GALLERY"
		state.loop_state.event_local_states.BLACK_MIRROR.merge({"rotation": spec[0], "flipped": spec[1], "anchored": spec[2], "path": spec[3]}, true)
		_install(state)
		var dry := view.session.act("c_dry")
		_expect(dry.ok, "dry test commits diagnostic state")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "dry feedback real reload")
		var resumed := view.session.initialize()
		_expect(resumed.ok and StateSnapshotValidator.same_persisted_value({"feedback": resumed.notebook_feedback}, {"feedback": dry.notebook_feedback}), "saved dry feedback retains explicit content after reinitialization")
		view._feedback(resumed)
		_drain()
		_act("c_wet", true)
		_collect()
		await tree.process_frame
	state = _seed("C4")
	state.loop_state.location_id = "M1_MIRROR_GALLERY"
	state.meta_progress.servants.edgar.alert = 4
	state.meta_progress.servants.edgar.bond = 0
	_install(state)
	_act("c_wet", true)
	for mode in ["SURFACE", "COPY"]:
		state = _seed("C5_INFO")
		state.meta_progress.failure_knowledge.erase("C4")
		state.loop_state.location_id = "M1_MIRROR_GALLERY"
		state.loop_state.event_local_states.BLACK_MIRROR.surface_open = mode == "SURFACE"
		_install(state)
		for owner in view.MIRROR_SESSION.CHANNELS: _act("c_scan", owner)
		_act("c_record")
		_expect(not _has("NB_MIRROR_NOTE_CF_RESOLVED") and _ledger().revisions.size() == 1, "recording without a failed attempt cannot invent a failure or old notes from legacy flags")
		_collect()
	for mix in [
		{"water": 6, "stabilizer": 1, "active": 1, "order": RULES.MATERIALS, "dispersed": true, "mixed": 1, "foamy": false},
		{"water": 5, "stabilizer": 1, "active": 2, "order": ["water", "active", "stabilizer"], "dispersed": true, "mixed": 1, "foamy": false},
	]:
		state = _seed("C3")
		state.loop_state.location_id = "M1_KITCHEN"
		state.loop_state.event_local_states.BLACK_MIRROR.merge({"materials_ready": true, "mixture": mix, "cleaner_ready": false}, true)
		_install(state)
		_act("c_test")
		_collect()
	state = _seed("J3")
	state.meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
	state.loop_state.location_id = "M1_LIBRARY_INNER"
	_install(state)
	_restore_j3(true)
	_collect()
	await tree.process_frame


func _restore_j3(memory: bool) -> void:
	_act("j3_overlay")
	for index in range(4): _act("j3_piece", index)
	var restored := view.session.act("j3_restore")
	_expect(restored.ok and view.session.stage() == "J3_COMPLETE", "actual J3 restoration")
	var written := _latest("MIRROR_J3")
	_expect(written.metadata.provenance_state == "unverified", "journal restoration does not authenticate its author")
	view._feedback(restored)
	var first: Dictionary = _archive().entries.back()
	_expect(first.observation.node_id == "J3" and first.observation.chapter_id == "CHAPTER_2", "last J3 dialogue retains the source chapter")
	_expect(not ARCHIVE.resolve(_archive(), ARCHIVE.make_reference(first, "line_08")).ok, "written full page does not disclose unshown dialogue segments")
	_expect(_has("NB_MIRROR_NOTE_J3_MEMORY") == memory, "conditional memory note only exists in its observed variant")
	_drain()


func _failures(tree: SceneTree) -> void:
	_seed("C0")
	_room("M1_MIRROR_GALLERY")
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	controlled.reject = true
	view.session._save = controlled
	var before := GameState.get_snapshot()
	_expect(not view.session.act("c_observe").ok and GameState.get_snapshot() == before, "event note, warning memory and game progress roll back together")
	controlled.reject = false
	controlled.lose_ack = true
	var seen := view.session.act("c_observe")
	_expect(seen.ok and _ledger().revisions.size() == 1, "same event can retry once and recover a lost save acknowledgement")
	controlled.lose_ack = false
	controlled.reject = true
	before = GameState.get_snapshot()
	view._feedback(seen)
	var token: String = view._dialogue_lines[0].presentation_token
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == before and view._dialogue_lines[0].presentation_token == token, "failed display stays on its original token without partial observation")
	controlled.reject = false
	controlled.lose_ack = true
	view._advance_dialogue()
	_expect(not view._dialogue_active and _archive().entries.size() == before.meta_progress.dialogue_history.entries.size() + 1, "successful display retry records once after its separately committed note")
	view.session._save = SaveManager
	controlled.free()
	var invalid := GameState.get_snapshot()
	var invalid_before := invalid.duplicate(true)
	var bad := view.MIRROR_SESSION.MIRROR_NOTES.write(invalid, "C0", "unmatched source", view.session.history_context(), TranslationServer.get_locale())
	_expect(not bad.ok and invalid == invalid_before, "source mismatch cannot fabricate an event note")
	var readonly := GameState.get_snapshot()
	view._open_notebook()
	view._close_modal()
	for entry in _archive().entries:
		if entry.get("record_class") == "authored":
			var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
			_expect(rendered.ok and not rendered.entry.fallback, "same authored version rereads without current-state inference")
	_expect(GameState.get_snapshot() == readonly, "notebook reading cannot rerun events or acquire notes")
	_collect()
	await tree.process_frame


func _choice_recovery(tree: SceneTree) -> void:
	for spec in [["patrol", 0, "valid"], ["patrol", 1, "valid"], ["patrol", 2, "valid"],
		["wet", 1, "valid"], ["wet", 1, "invalid"], ["wet", 2, "valid"], ["wet", 2, "invalid"], ["wet", 2, "confiscated"]]:
		for follow_up in ["retry", "cancel"]:
			var old_errors := errors.size()
			var state := _seed("C4")
			state.loop_state.location_id = "M1_MIRROR_GALLERY"
			state.meta_progress.servants.edgar.alert = 4 if spec[2] == "confiscated" else 0
			state.meta_progress.servants.edgar.bond = 0
			state.loop_state.event_local_states.BLACK_MIRROR.merge({"rotation": 0 if spec[2] == "invalid" else 90,
				"flipped": false, "anchored": true, "path": RULES.PATH.duplicate(), "cleaner_ready": true,
				"signal_ready": true, "intervention_handled": false, "dry_passed": false}, true)
			_install(state)
			_expect(view.session.initialize().ok, "mirror recovery fixture passes normal session initialization")
			view._render_room()
			if spec[0] == "patrol": view._open_patrol()
			else: view._confirm_wet_trace()
			var request: Dictionary = view._recorded_modal_request
			_expect(view._modal_active and request.get("recorded", false), "mirror recovery prompt displayed and saved")
			var shown := GameState.get_snapshot()
			var controlled := ControlledSave.new()
			controlled.delegate = SaveManager
			controlled.reject_game = true
			view.session._save = controlled
			view._recorded_choice_pressed(request, spec[1])
			_expect(controlled.rejected_game_saves == 1, "one real game save is rejected after the answer is saved")
			var pending := GameState.get_snapshot()
			var cursor := CURSOR.read(pending)
			_expect(view._modal_active and cursor.get("phase") == "selection_pending" and CURSOR.matches(cursor, pending), "failed mirror action restores pending choice")
			_expect(_same_choice_gameplay(shown, pending), "failed mirror action changes only observations and backed presentation receipts")
			var changed := pending.duplicate(true)
			changed.loop_state.event_local_states.BLACK_MIRROR.cleaner_ready = false
			_expect(not _same_choice_gameplay(shown, changed), "comparison rejects premature cleaner consumption")
			var answer_id: String = request.row.choices[spec[1]].content_id
			var answers := _choice_answers(answer_id)
			_expect(answers.size() == 1, "one attempted mirror answer before retry")
			view.session._save = SaveManager
			view.queue_free()
			await tree.process_frame
			_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "pending mirror choice reloads from disk")
			view = VIEW.new()
			view.configure_session(SLOT, "MORNING_ROUTE")
			tree.current_scene.add_child(view)
			await tree.process_frame
			_expect(view._modal_active and StateSnapshotValidator.same_persisted_value(pending, GameState.get_snapshot()), "mirror reload does not apply the saved answer")
			var restored: Dictionary = view._recorded_modal_request
			_expect(restored.get("selection_recorded", false) and restored.get("selection_token") == cursor.get("modal", {}).get("selection_token"), "mirror reload retains selected answer token")
			controlled.reject_game = false
			controlled.lose_ack = true
			view.session._save = controlled
			if follow_up == "cancel":
				view._cancel_prologue_modal()
				_expect(not view._modal_active and _same_choice_gameplay(shown, GameState.get_snapshot()), "cancel does not apply an attempted mirror action")
			else:
				view._recorded_choice_pressed(restored, spec[1])
				var local: Dictionary = view.session.mirror_local()
				if spec[0] == "patrol":
					_expect(local.intervention_handled and local.cleaner_ready and not local.locked, "patrol retry handles intervention without using cleaner")
				elif spec[1] == 1:
					_expect(local.dry_passed == (spec[2] == "valid") and local.cleaner_ready and not local.locked, "dry retry diagnoses the actual route without physical consumption")
					_expect(view._modal_active and not view._recorded_modal_request.is_empty(), "dry retry opens its result modal")
				else:
					_expect(not local.cleaner_ready and local.surface_open == (spec[2] == "valid") and local.locked == (spec[2] != "valid"), "wet retry applies the actual irreversible result exactly once")
					if spec[2] != "valid":
						var failure: Dictionary = GameState.get_snapshot().meta_progress.failure_knowledge.get("C4", {})
						var previous: int = shown.meta_progress.failure_knowledge.get("C4", {}).get("attempts", 0)
						_expect(failure.get("attempts", 0) == previous + 1, "wet retry counts one failed attempt")
						if spec[2] == "confiscated": _expect(failure.get("category") == "tool_confiscated", "patrol confiscation is not misreported as a trace error")
			var after := GameState.get_snapshot()
			_expect(StateSnapshotValidator.same_persisted_value(answers, _choice_answers(answer_id)), "retry/cancel preserves one original attempted answer")
			view._recorded_choice_pressed(restored, spec[1])
			_expect(GameState.get_snapshot() == after, "stale mirror callback cannot apply twice")
			view.session._save = SaveManager
			controlled.free()
			recovery_cases += 1
			print("NOTEBOOK_MIRROR_CHOICE_RECOVERY: ", TranslationServer.get_locale(), " ", spec, " ", follow_up, " ", "PASS" if old_errors == errors.size() else errors.slice(old_errors))


func _same_choice_gameplay(before: Dictionary, after: Dictionary) -> bool:
	var left := before.duplicate(true)
	var right := after.duplicate(true)
	left.loop_state.event_local_states.erase(CURSOR.KEY)
	right.loop_state.event_local_states.erase(CURSOR.KEY)
	return ASSERTIONS.same_surface_gameplay(left, right)


func _choice_answers(id: String) -> Array:
	return _archive().entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id", "") == id)


func _seed(stage: String) -> Dictionary:
	if view != null:
		view._close_modal()
		view._dismiss_dialogue_for_test()
	var fixture := checkpoints.snapshot_for(stage)
	_expect(fixture.ok, "checkpoint " + stage)
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
	var result := StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_MIRROR_FIXTURE_%d" % serial))
	_expect(result.ok, "fixture install: " + str(result.get("error_ids", [])))


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
		_expect(GameState.get_snapshot() == before, "redraw is idempotent")
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		view._advance_dialogue()
		if view._dialogue_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			_expect(false, "blocked mirror dialogue: " + str(view._dialogue_lines[view._dialogue_index]))
			view._dismiss_dialogue_for_test()
			return
	_expect(false, "dialogue did not terminate")


func _archive() -> Dictionary:
	return GameState.get_snapshot().meta_progress.dialogue_history


func _ledger() -> Dictionary:
	return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


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


func _collect() -> void:
	coverage.collect(_archive().entries, "mirror")
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "new mirror observation cannot silently become unmapped")
			continue
		if entry.observation.producer_id != "NP07": continue
		for segment in entry.observation.segments:
			covered[entry.observation.content_id + ":" + segment.viewed_locale] = true
			segments[entry.observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("MIRROR_NOTE_ASSERT: ", message)
