extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/settlement_notebook.gd")
const DISPLAY := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const SLOT := "__test_notebook_settlement"
const OUTCOMES := [["responsibility_recorded", "authority_returned"], ["original_attribution", "protected_identifiers"], ["full_disclosure", "stabilize_first"], ["external_truth", "shelter_projection"], ["merged", "separated"]]
var errors := PackedStringArray()
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var matrix_cases := 0
var routes := 0
var evening_mask_routes := 0
var question_ready := {}
var evening_ready := {}
var mara2_ready := {}
var edgar_ready := {}

class ControlledSave extends Node:
	var delegate: Node
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	var attempts := 0
	func get_build_flavor() -> String: return delegate.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		attempts += 1
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok": false, "error_ids": ["ERR_TEST_AUTHORITY_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_AUTHORITY_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)



func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_install(_fixture(0))
	view = VIEW.new()
	view.configure_session(SLOT, "E5")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for mask in [0, 3, 15, 31]:
			_evening_route(mask, 0, 0, "wish")
		for mask in range(32):
			var questions: Array = NOTES.EVENING.QUESTIONS.keys()
			_evening_route(mask, 0, 0, questions[mask % questions.size()], true)
			evening_mask_routes += 1
		_evening_route(31, 2, 1, "leave")
		_evening_route(31, 4, 0, "stay")
		for complete in [false, true]:
			for choice in ["ask", "order", "wait"]: _edgar_route(complete, choice)
		for outcome in range(2):
			for known in [false, true]:
				for choice in ["write", "call", "joke"]: _mara2_route(outcome, known, choice)
		_failures()
		await _legacy()
		_rule_matrix()
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + locale), "unexecuted settlement ID: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "undisplayed settlement segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	_expect(evening_mask_routes == 64, "all 32 completion masks execute in both locales")
	print("NOTEBOOK_E5_MASK_ROUTES:", evening_mask_routes)
	_expect(runtime_audit.emit("settlement", errors.is_empty()).ok, "runtime trace validates")
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": 75, "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "routes": routes, "matrix_cases": matrix_cases, "evening_mask_routes": evening_mask_routes,
		"not_covered": ["NP15_J4_and_minimum_access", "durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _fixture(mask: int, bond: int = 0, outcome: int = 0) -> Dictionary:
	var fixture := CHECKPOINTS.new().snapshot_for("E5")
	_expect(fixture.ok, "E5 fixture")
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	for index in range(5):
		var owner: String = NOTES.EVENING.OWNERS[index]
		var complete := (mask & (1 << index)) != 0
		state.meta_progress.servants[owner].core_event_complete = complete
		state.meta_progress.servants[owner].researcher_record_acquired = complete
		state.meta_progress.servants[owner].bond = bond
		state.meta_progress.servants[owner].alert = 0
		if complete: state.meta_progress.event_history[NOTES.EVENING.EVENTS[index]] = {"event_id": NOTES.EVENING.EVENTS[index], "lifecycle": "completed", "outcome_id": OUTCOMES[index][outcome]}
	return state


func _evening_route(mask: int, bond: int, outcome: int, question: String, audit_mask: bool = false) -> void:
	_install(_fixture(mask, bond, outcome))
	var initial := GameState.get_snapshot()
	_present()
	_expect(_archive().entries.is_empty(), "enter prompt is not an unseen dinner scene")
	_press("E5_ENTER")
	_expect(_count(NOTES.PREFIX + "E5_ENTER_STANDARD") + _count(NOTES.PREFIX + "E5_ENTER_CONSENT") == 1, "only the displayed first entry paragraph is recorded")
	_drain()
	_press("E5_TABLE")
	_drain()
	_press("E5_SEATS")
	_drain()
	_press("E5_HALL")
	_drain()
	_press("E5_RETURN")
	_drain()
	_press("E5_SIT")
	_expect(_count(NOTES.PREFIX + "E5_INSERT_EDGAR") == 0 and _count(NOTES.PREFIX + "QUESTION_OPTIONS") == 0, "seating opening cannot disclose later dialogue or covered questions")
	_drain()
	if audit_mask: _check_evening_mask(mask, outcome)
	question_ready = GameState.get_snapshot()
	_expect(NOTES.EVENING.progress(question_ready).question == "", "seeing the question list does not select a question")
	_reload("seated dinner")
	_press("E5_QUESTION_" + question)
	_drain()
	_expect(_count(NOTES.PREFIX + "E5_QUESTION_" + question.to_upper()) == 3, "only chosen answer paragraphs are disclosed")
	for other in NOTES.EVENING.QUESTIONS:
		if other != question: _expect(_count(NOTES.PREFIX + "E5_QUESTION_" + other.to_upper()) == 0, "unselected dinner answer remains hidden")
	_press("E5_FINISH")
	view._cancel_prologue_modal()
	_expect(not view.session.known("e5_locked_in"), "deferring final dinner does not lock progression")
	_press("E5_FINISH")
	view._modal_body.get_child(4).pressed.emit()
	_drain()
	_expect(view.session.stage() == "E6" and not view.session.known("f0_entered"), "dinner completion is not a core or ending choice")
	evening_ready = GameState.get_snapshot()
	if audit_mask:
		_expect(evening_ready.meta_progress.servants == initial.meta_progress.servants, "dinner cannot award relationship completion or modify bond")
		_expect(_ledger().revisions.is_empty(), "dinner cannot fabricate researcher acquisitions")
		_expect(view.session.known("all_servants_complete") == (mask == 31), "all-servants flag requires five actual completions")
		var owners: Array = []
		for index in range(5):
			if mask & (1 << index): owners.append(String(NOTES.EVENING.OWNERS[index]).to_upper())
		_expect(evening_ready.meta_progress.event_history.E5.completed_owner_ids == owners, "completed-owner provenance follows exact mask")
		_expect(NOTES.EVENING.progress(evening_ready).question == question, "actual dinner stores only the chosen question")
		_reload("completed dinner mask " + str(mask))
		_expect(view.session.stage() == "E6", "every dinner mask restores the E6 threshold")
	_collect()
	_replay_unchanged()
	routes += 1


func _check_evening_mask(mask: int, outcome: int) -> void:
	var completed := 0
	for index in range(5):
		var owner: String = NOTES.EVENING.OWNERS[index]
		var complete := (mask & (1 << index)) != 0
		if complete: completed += 1
		_expect(_count(NOTES.PREFIX + "E5_INSERT_" + owner.to_upper()) == (1 if complete else 0), "private insert requires own completion: " + owner)
		_expect(_count(NOTES.PREFIX + "E5_DISTANCE_" + owner.to_upper()) == (0 if complete else 1), "unfinished owner uses only distance response: " + owner)
		for option in range(2):
			var id: String = NOTES.PREFIX + "E5_OVERLAY_" + String(OUTCOMES[index][option]).to_upper()
			_expect(_count(id) == (1 if complete and option == outcome else 0), "overlay provenance requires own completed outcome: " + id)
	var expected := "ALL" if completed == 5 else ("HIGH" if completed == 4 else ("MID" if completed >= 2 else "LOW"))
	for tier in ["LOW", "MID", "HIGH", "ALL"]:
		_expect(_count(NOTES.PREFIX + "E5_OPENING_" + tier) == (1 if tier == expected else 0), "only exact completion-tier opening is disclosed")
	_expect(_count(NOTES.PREFIX + "E5_ALL") == (2 if mask == 31 else 0), "five-name shared scene is exclusive to all completions")


func _approach_fixture(complete: bool, outcome: int = 0) -> Dictionary:
	var state := _fixture(31 if complete else 0, 4, outcome)
	state.meta_progress.knowledge_entries.e5_locked_in = true
	state.meta_progress.event_history.E5 = {"event_id": "E5", "lifecycle": "completed", "variant_id": "ALL" if complete else "LOW"}
	state.loop_state.location_id = "M1_CENTRAL_HALL"
	return state


func _edgar_route(complete: bool, choice: String) -> void:
	var state := _approach_fixture(complete)
	state.meta_progress.servants.edgar.alert = 4 if complete else 0
	_install(state)
	_present()
	_press("E6_CLOCK")
	_present()
	edgar_ready = GameState.get_snapshot()
	var before: int = state.meta_progress.servants.edgar.bond
	_press("EDGAR_S3_" + choice)
	_expect(_count(NOTES.PREFIX + "E6_EDGAR_WARNING") == 0, "warning is not disclosed with the first line")
	_drain()
	_expect(view.session.known("core_access_open") and not view.session.known("f0_entered"), "conversation opens but does not cross the threshold")
	_expect(GameState.get_snapshot().meta_progress.servants.edgar.bond == mini(5, before + (1 if choice == "ask" else 0)), "original Edgar delta")
	_expect(_count(NOTES.PREFIX + "E6_EDGAR_ORDER") == (1 if choice == "order" else 0), "high-bond order response follows only that choice")
	_expect(_count(NOTES.PREFIX + "E6_EDGAR_WARNING") == (1 if complete else 0), "warning obeys frozen alert")
	_press("E6_ENTER")
	view._cancel_prologue_modal()
	_expect(not view.session.known("f0_entered"), "core entry cancellation preserves location")
	_press("E6_ENTER")
	view._modal_body.get_child(4).pressed.emit()
	# Do not capture later F0 content in this producer test.
	while view._dialogue_active: view._advance_dialogue()
	_expect(view.session.stage() == "F0_A", "minimum and complete routes both enter F0")
	_expect(_entry(NOTES.PREFIX + "E6_ENTER").observation.node_id == "E6", "entry result belongs to E6, not F0")
	_expect(not view.session.known("ending_decision"), "entry cannot decide an ending")
	_collect()
	routes += 1


func _mara2_route(outcome: int, known: bool, choice: String) -> void:
	var state := _approach_fixture(true, outcome)
	state.meta_progress.knowledge_entries.mara2_name_attention_seen = known
	state.meta_progress.servants.mara2.bond = 2
	_install(state)
	_present()
	_press("E6_ARCHIVE")
	_present()
	mara2_ready = GameState.get_snapshot()
	_expect(_ledger().revisions.is_empty(), "name prompt alone cannot write the name")
	_press("MARA2_FU_" + choice)
	_expect(_count(NOTES.PREFIX + "E6_MARA2_REMEMBER") == 0, "follow-up first line does not reveal its continuation")
	_drain()
	_expect(GameState.get_snapshot().meta_progress.servants.mara2.bond == (3 if choice in ["write", "call"] else 2), "original name follow-up delta")
	_expect(_count(NOTES.PREFIX + "NAME_RECORD") == (1 if choice == "write" else 0), "only writing acquires the name record")
	if choice == "write":
		var revision: Dictionary = _ledger().revisions.back()
		_expect(revision.metadata.knowledge_id == "MARA2_NAME", "name ledger identity")
		for ref in revision.source_refs:
			var resolved := ARCHIVE.resolve(_archive(), ref)
			_expect(resolved.ok and not resolved.entry.observation.content_id.begins_with(NOTES.PREFIX + "E6_MARA2"), "future response is not a precommitted source")
	_expect(not view.session.act("e6_mara2", choice).ok, "follow-up cannot farm bond or records")
	_reload("completed name follow-up")
	_press("E6_CLOCK")
	_present()
	_press("E6_OPEN")
	_drain()
	_expect(view.session.known("core_access_open"), "skip dialogue route remains available")
	_collect()
	_replay_unchanged()
	routes += 1


func _replay_unchanged() -> void:
	var entries: Array = _archive().entries.duplicate(true)
	var state := GameState.get_snapshot()
	for owner in state.meta_progress.servants:
		state.meta_progress.servants[owner].bond = 0
		state.meta_progress.servants[owner].alert = 5
	_install(state)
	var before := GameState.get_snapshot()
	for entry in entries:
		_expect(_entry_uid(entry.entry_uid) == entry, "current relations do not rewrite historical records")
		for locale in ["ko-KR", "en-US"]: _expect(CONTENT.render_entry(entry, locale).ok, "stored meaning remains renderable")
	_expect(before == GameState.get_snapshot(), "reading evidence cannot mutate relationships")


func _failures() -> void:
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	_install(mara2_ready)
	_present()
	view.session._save = controlled
	controlled.reject_game = true
	_press("MARA2_FU_write")
	_expect(not view.session.known("mara2_name_written") and _ledger().revisions.is_empty(), "failed name transaction rolls back gameplay and ledger")
	_expect(_count(NOTES.PREFIX + "MARA2_SELECT_0") == 1, "input intention survives a failed gameplay commit")
	controlled.reject_game = false
	controlled.lose_ack = true
	_press("MARA2_FU_write")
	_drain()
	_expect(_count(NOTES.PREFIX + "MARA2_SELECT_0") == 1 and _count(NOTES.PREFIX + "NAME_RECORD") == 1, "lost acknowledgement is idempotent for input and atomic record")
	_collect()
	_install(mara2_ready)
	_present()
	var button := view._hotspot_layer.get_node("MARA2_FU_write") as Button
	var callback: Callable = button.pressed.get_connections()[0].callable
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load with stale world choice")
	var before := GameState.get_snapshot()
	callback.call()
	_expect(GameState.get_snapshot() == before, "stale world choice cannot modify new load scope")
	_install(evening_ready)
	_present()
	_press("E6_CLOCK")
	_present()
	_press("E6_OPEN")
	_drain()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("E6_ENTER")
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before, "failed modal disclosure cannot enter F0")
	controlled.reject_history = false
	controlled.lose_ack = true
	view._recorded_choice_pressed(request, 1)
	_drain()
	_expect(view.session.stage() == "F0_A", "explicit modal retry can recover")
	_collect()
	_install(_approach_fixture(true))
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_expect(not view._notebook_surface_allowed(), "failed actual surface capture")
	var attempts := controlled.attempts
	_press("E6_CLOCK")
	_expect(controlled.attempts == attempts and GameState.get_snapshot() == before, "failed surface does not auto-retry or move")
	controlled.reject_history = false
	controlled.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count(NOTES.PREFIX + "SCREEN_OPTIONAL") == 1, "explicit surface retry stores once")
	_collect()
	view.session._save = SaveManager
	controlled.free()


func _legacy() -> void:
	var state := mara2_ready.duplicate(true)
	state.meta_progress.knowledge_entries.mara2_name_written = true
	state.meta_progress.event_history.MARA2_FU = {"event_id": "MARA2_FU", "lifecycle": "completed", "outcome_id": "write"}
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_install(state)
	_present()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(_ledger().revisions.is_empty() and _count(NOTES.PREFIX + "NAME_RECORD") == 0, "old name flag does not fabricate a new acquisition")


func _rule_matrix() -> void:
	for mask in range(32):
		for bond in [0, 2, 4]:
			for outcome in range(2):
				var state := _fixture(mask, bond, outcome)
				state.loop_state.event_local_states.E5 = {"entered": true, "seated": false, "question": "", "seen": []}
				state.loop_state.location_id = "M1_DINING_ROOM"
				var result := NOTES.EVENING.apply(state, "sit", null)
				_check_feedback(result, NOTES.paragraphs("E5", result.feedback_keys))
				matrix_cases += 1


func _check_feedback(result: Dictionary, descriptors: Array) -> void:
	var language := "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	var other := "ko-KR" if language == "en-US" else "en-US"
	var parts: PackedStringArray = DISPLAY.text(result.text, language).split("\n", false)
	var opposite: PackedStringArray = DISPLAY.text(result.text, other).split("\n", false)
	_expect(parts.size() == descriptors.size(), "one descriptor per displayed settlement paragraph")
	for index in range(mini(parts.size(), descriptors.size())):
		var row := CONTENT.definition(descriptors[index].content_id, 1)
		var context := {"chapter_id": "CHAPTER_3", "node_id": "E5", "location_id": "M1_DINING_ROOM", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
		var observed := CONTENT.observe(descriptors[index], context, row.locales[language].speaker, parts[index], language)
		_expect(observed.ok, "matrix matches actual feedback")
		if not observed.ok: continue
		var serialized: Dictionary = JSON.parse_string(JSON.stringify(observed.observation))
		var archive := ARCHIVE.create()
		archive = ARCHIVE.append_observation(archive, serialized, 0).archive
		var rendered := CONTENT.render_entry(archive.entries[0], other)
		_expect(rendered.ok and not rendered.entry.fallback and rendered.entry.segments[0].text == opposite[index], "matrix preserves the opposite-language paragraph")

func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_SETTLEMENT_FIXTURE_%d" % serial)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "NB_SETTLEMENT_FIXTURE_%d" % serial).ok, "fixture save")
	if view != null:
		view._render_room()
		# Synthetic fixtures intentionally reuse a controller with a fresh test state.
		# Real load behavior is tested separately with a new controller in _reload.
		view._presentation_scope = view._recorded_choice_scope()


func _reload(label: String) -> void:
	var before := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, label + " JSON load")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before), label + " exact saved state")
	var parent := view.get_parent()
	parent.remove_child(view)
	view.queue_free()
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	parent.add_child(view)
	_expect(not view._dialogue_active and not view._modal_active, label + " completed cursor does not replay")
	_expect(view._presentation_scope == view._recorded_choice_scope(), label + " completed cursor binds new controller scope")
	_present()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing settlement button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(40):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "settlement dialogue remains blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _count(id: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: count += 1
	return count


func _entry(id: String) -> Dictionary:
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == id: return entry
	_expect(false, "missing entry: " + id)
	return {}


func _entry_uid(uid: String) -> Dictionary:
	for entry in _archive().entries:
		if entry.entry_uid == uid: return entry
	return {}


func _collect() -> void:
	runtime_audit.capture(_archive())
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "settlement route cannot silently produce unmapped history")
			continue
		var observed: Dictionary = entry.observation
		if observed.producer_id != "NP15": continue
		_expect(observed.chapter_id == "CHAPTER_3" and observed.node_id in ["E5", "E6"] and observed.event_id in ["E5", "E6", "MARA2_FU", "EDGAR_S3"], "actual pre-transition context captured")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "opposite-language replay uses the same meaning version")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "research ledger and sources are valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("SETTLEMENT_ASSERT: ", message)
