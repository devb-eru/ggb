extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_relationship_label_assertions.gd")

const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/mara1_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const SLOT := "__test_notebook_mara1"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var ready: Dictionary = {}

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
			return {"ok": false, "error_ids": ["ERR_TEST_MARA1_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_MARA1_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	errors.append_array(PUBLIC_LABELS.catalog(["mara1"]))
	_seed()
	view = VIEW.new()
	view.configure_session(SLOT, "E3_1")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for outcome in ["original_attribution", "protected_identifiers"]: await _route(outcome)
		_failures()
		await _legacy()
		for key in NOTES.authored_rows():
			var id: String = NOTES.PREFIX + key
			_expect(covered.has(id + ":" + locale), "unexecuted Mara 1 content: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "undisplayed Mara 1 segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": NOTES.authored_rows().size(), "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(),
		"not_covered": ["other_relationship_producers", "durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _route(outcome: String) -> void:
	_seed()
	_present()
	_expect(_count("SCREEN_ENTRY") == 1 and _count("SCREEN_LOG_CONSENT") == 0 and _ledger().revisions.is_empty(), "entry reveals neither hidden documents nor a completed research record")
	var before := GameState.get_snapshot()
	view._render_room()
	_present()
	_expect(GameState.get_snapshot() == before, "entry redraw does not append an observation")
	_press("WIRING_ENTER")
	_press("MARA_PANEL")
	_expect(_count("PANEL") == 1 and _count("SCREEN_TERMINAL_0") == 0, "covered terminals are not disclosed behind the investigation dialogue")
	_drain()
	var servant: Dictionary = GameState.get_snapshot().meta_progress.servants.mara1
	_press("MARA_SOURCE_0_2")
	_drain()
	_expect(GameState.get_snapshot().meta_progress.servants.mara1 == servant, "wrong source causes no relationship penalty")
	_press("MARA_BRIDGE")
	_press("MARA_BRIDGE")
	_expect(_count("STATUS_BRIDGE_SOURCES") == 2, "two genuine blocked attempts are separate observations")
	for index in range(3):
		_press("MARA_SOURCE_%d_%d" % [index, index])
		_drain()
	_press("MARA_BRIDGE")
	_expect(_count("SCREEN_LOG_COMMAND") == 0, "documents behind the bridge dialogue remain undisclosed")
	_drain()
	for key in ["CONSENT", "FAILURE", "COMMAND"]:
		_expect(_count("SCREEN_LOG_" + key) == 1 and _count("LOG_" + key) == 0, "readable document buttons are observations, not click results")
	_expect(GameState.get_snapshot().loop_state.event_local_states.E3_1.order.is_empty(), "document disclosure does not arrange the puzzle")
	var preserved: Array = _archive().entries.duplicate(true)
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "partial repair and disclosed documents reload")
	view._render_room()
	_present()
	_expect(view.session.snapshot().loop_state.event_local_states.E3_1.bridge and view.session.snapshot().loop_state.event_local_states.E3_1.order.is_empty(), "reloading the opened panel does not arrange fragments or reset the repair")
	for observed in preserved:
		_expect(observed in _archive().entries, "partial reload preserves every earlier observation unchanged")
	for key in ["command", "failure", "consent"]:
		_press("MARA_LOG_" + key)
		_drain()
	_press("MARA_RESTORE")
	_expect(_count("STATUS_RESTORE_ORDER") == 1 and not view.session.known("E3_1_complete"), "incorrect chronology is recorded without granting completion")
	_press("MARA_CLEAR")
	_drain()
	for key in ["consent", "failure", "command"]:
		_press("MARA_LOG_" + key)
		_drain()
	_press("MARA_RESTORE")
	_drain()
	_press("MARA_CONFESS")
	var entry := _entry("CONFESS")
	_expect(entry.observation.segments.size() == 1 and entry.observation.segments[0].segment_id == "line_01", "only the first confession paragraph has appeared")
	var unavailable := ARCHIVE.make_reference(entry, "line_01")
	unavailable.segment_id = "line_03"
	_expect(not ARCHIVE.resolve(_archive(), unavailable).ok, "future confession paragraphs cannot be resolved from the first paragraph")
	_drain()
	ready = GameState.get_snapshot()
	_press("MARA_CHOICE")
	view._modal_body.get_child(3).pressed.emit()
	var cancelled := GameState.get_snapshot()
	cancelled.meta_progress.dialogue_history = ready.meta_progress.dialogue_history.duplicate(true)
	_expect(STATE_ASSERTIONS.same_gameplay(ready, cancelled, "modal") and _ledger().revisions.is_empty(), "deferral changes only observed history and its completed presentation cursor")
	_press("MARA_CHOICE")
	view._modal_body.get_child(4 if outcome == "original_attribution" else 5).pressed.emit()
	_drain()
	var after := GameState.get_snapshot()
	_expect(view.session.known("E3_1_complete") and view.session.known("REC_MARA1"), "record and relationship completion commit together")
	_expect(int(after.meta_progress.servants.mara1.bond) == int(servant.bond) + (2 if outcome == "original_attribution" else 1), "unchanged relationship delta")
	_expect(after.meta_progress.knowledge_entries.chapter_notebook.REC_MARA1 == NOTES.record_text(outcome), "legacy-compatible record retains the selected wording")
	_expect(_count("RECORD_" + outcome.to_upper()) == 1 and _ledger().revisions.size() == 1, "only the chosen research record exists")
	var note: Dictionary = _ledger().revisions.back()
	_expect(note.metadata.knowledge_id == "REC_MARA1" and note.source_refs.size() >= 8, "record cites itself and actually seen source documents")
	for reference in note.source_refs:
		var resolved := ARCHIVE.resolve(_archive(), reference)
		_expect(resolved.ok, "all research-record references resolve")
		if resolved.ok:
			_expect(not String(resolved.entry.observation.content_id).contains("RECORD_" + ("PROTECTED_IDENTIFIERS" if outcome == "original_attribution" else "ORIGINAL_ATTRIBUTION")), "the unchosen record is not a source")
	_expect(not view.session.act("mara1_choose", outcome).ok and GameState.get_snapshot() == after, "completed relation cannot be applied twice")
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == after, "notebook rereading does not add documents or resolve the puzzle")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "actual JSON reload")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), after), "saved record, sources and completion survive JSON roundtrip")
	_collect()


func _failures() -> void:
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	_install(ready)
	_present()
	view.session._save = controlled
	for choice_index in [1, 2]:
		_install(ready)
		_present()
		view.session._save = controlled
		errors.append_array(preload("res://scripts/tests/notebook_relationship_choice_retry.gd").run(view, controlled, "mara1", choice_index))
	_install(ready)
	_present()
	view.session._save = controlled
	controlled.reject_game = true
	var before := GameState.get_snapshot()
	var result: Dictionary = view.session.act("mara1_choose", "original_attribution")
	_expect(not result.ok and GameState.get_snapshot() == before, "failed record commit preserves bond, completion, old record, archive and ledger")
	controlled.reject_game = false
	controlled.lose_ack = true
	result = view.session.act("mara1_choose", "original_attribution")
	_expect(result.ok and _ledger().revisions.size() == 1, "lost acknowledgement confirms the atomic record commit")
	view._render_room()
	view._feedback(result)
	_drain()
	before = GameState.get_snapshot()
	_expect(not view.session.act("mara1_choose", "original_attribution").ok and GameState.get_snapshot() == before, "successful commit retry cannot duplicate the research record")
	_collect()
	_seed()
	_press("WIRING_ENTER")
	_press("MARA_PANEL")
	_drain()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("MARA_BRIDGE")
	_expect(_count("STATUS_BRIDGE_SOURCES") == 0 and GameState.get_snapshot() == before, "failed status capture does not fabricate a visible record")
	var attempts := controlled.attempts
	_press("MARA_BRIDGE")
	_expect(controlled.attempts == attempts and _count("STATUS_BRIDGE_SOURCES") == 0, "failed status capture waits for explicit retry")
	controlled.reject_history = false
	controlled.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("STATUS_BRIDGE_SOURCES") == 1, "explicit retry retains the failed status token")
	_collect()
	_install(ready)
	_present()
	_press("MARA_CHOICE")
	var request: Dictionary = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load with an old choice callback")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before and not view.session.known("E3_1_complete"), "pre-load confirmation cannot complete a relationship on a newly loaded snapshot")
	view._cancel_prologue_modal()
	view.session._save = SaveManager
	controlled.free()


func _legacy() -> void:
	_install(ready)
	var result: Dictionary = view.session.act("mara1_choose", "protected_identifiers")
	_expect(result.ok, "legacy completion fixture")
	var old := GameState.get_snapshot()
	old.meta_progress.dialogue_history = ARCHIVE.create()
	old.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_install(old)
	_present()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(_ledger().revisions.is_empty() and _count("RECORD_PROTECTED_IDENTIFIERS") == 0, "old completion flags and rereading do not create new authored research records")
	_collect()


func _seed() -> void:
	var fixture := CHECKPOINTS.new().snapshot_for("E_HUB")
	_expect(fixture.ok, "Mara 1 entry checkpoint")
	var state: Dictionary = fixture.snapshot
	state.loop_state.location_id = "M1_SERVICE_HALL"
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.servants.mara1.bond = 1
	state.meta_progress.servants.mara1.alert = 1
	_install(state)


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_MARA1_FIXTURE_%d" % serial)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "NB_MARA1_FIXTURE_%d" % serial).ok, "fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual Mara 1 screen capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing Mara 1 button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(15):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "Mara 1 dialogue remains blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _count(key: String) -> int:
	var found := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: found += 1
	return found


func _entry(key: String) -> Dictionary:
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: return entry
	_expect(false, "missing authored Mara 1 entry: " + key)
	return {}


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "Mara 1 route cannot silently produce unmapped history")
			continue
		if entry.observation.producer_id != "NP10": continue
		var observed: Dictionary = entry.observation
		if String(observed.content_id).ends_with("_SCREEN_COMPLETE"):
			_expect(PUBLIC_LABELS.live(entry), "current completion has readable labels and exact version 2 observation")
		_expect(observed.chapter_id == "CHAPTER_3" and observed.event_id == "E3_1", "research record remains in its actual chapter and event")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "fixed Mara 1 translation remains available without recomputing a relationship")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "research ledger and source references remain valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("MARA1_NOTE_ASSERT: ", message)
