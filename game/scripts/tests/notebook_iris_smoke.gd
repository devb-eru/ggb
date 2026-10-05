extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_relationship_label_assertions.gd")

const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/iris_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const SLOT := "__test_notebook_iris"
const SCENARIOS := [
	[0, 0, "external_truth", "indirect", false], [0, 5, "external_truth", "indirect", true],
	[2, 0, "external_truth", "direct_private", false], [2, 5, "external_truth", "direct_private", true],
	[0, 0, "shelter_projection", "withheld", false], [0, 4, "shelter_projection", "denied", true],
	[2, 0, "shelter_projection", "indirect", false], [2, 4, "shelter_projection", "indirect", true],
	[4, 0, "shelter_projection", "direct_private", false], [4, 4, "shelter_projection", "direct_private", true],
]
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var ready: Dictionary = {}
var ordering: Dictionary = {}

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
			return {"ok": false, "error_ids": ["ERR_TEST_IRIS_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_IRIS_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	errors.append_array(PUBLIC_LABELS.catalog(["iris"]))
	_seed()
	view = VIEW.new()
	view.configure_session(SLOT, "E3_2")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		_evidence()
		for scenario in SCENARIOS: await _outcome(scenario)
		_failures()
		await _legacy()
		for id in CONTENT.diagnostics().content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + locale), "unexecuted Iris content: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "undisplayed Iris segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": 45, "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "outcome_scenarios": SCENARIOS.size() * 2,
		"not_covered": ["other_relationship_producers", "durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _evidence() -> void:
	_seed()
	_present()
	_expect(_count("SCREEN_ENTRY") == 1 and _count("SCREEN_LOG_WARNING") == 0, "entry cannot expose later power documents")
	var before := GameState.get_snapshot()
	view._render_room()
	_present()
	_expect(GameState.get_snapshot() == before, "redraw preserves the original observation")
	_press("IRIS_CONTROL")
	_press("IRIS_PANEL")
	_expect(_count("PANEL") == 1 and _count("SCREEN_CHANNEL_TEMPERATURE_0") == 0, "panel dialogue hides the gauge buttons")
	_drain()
	var relation: Dictionary = GameState.get_snapshot().meta_progress.servants.iris
	_press("IRIS_CHANNEL_temperature_0")
	var local: Dictionary = NOTES.RULES.progress(GameState.get_snapshot())
	view._cancel_prologue_modal()
	_expect(NOTES.RULES.progress(GameState.get_snapshot()) == local and _count("CHANNEL_SELECT_0") == 1, "Esc records deferral, not a sensor assignment")
	_channel("temperature", 0, "EXTERNAL")
	_expect(GameState.get_snapshot().meta_progress.servants.iris == relation, "wrong sensor choice has no relationship penalty")
	for gauge in NOTES.RULES.CHANNELS:
		for index in range(3): _channel(gauge, index, NOTES.RULES.CHANNELS[gauge][index])
	for key in NOTES.RULES.LOGS:
		_expect(_count("SCREEN_LOG_" + String(key).to_upper()) == 1 and _count("LOG_" + String(key).to_upper()) == 0, "readable power documents are not puzzle placements")
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).order.is_empty(), "document display does not arrange the chronology")
	var preserved: Array = _archive().entries.duplicate(true)
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "partial sensor repair reload")
	view._render_room()
	_present()
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).channels.size() == 9 and NOTES.RULES.progress(GameState.get_snapshot()).order.is_empty(), "load preserves repair but cannot solve chronology")
	for observed in preserved: _expect(observed in _archive().entries, "partial load retains original observations unchanged")
	ordering = GameState.get_snapshot()
	for key in ["command", "warning", "loss", "audit", "conversion"]:
		_press("IRIS_LOG_" + key)
		_drain()
	_press("IRIS_RESTORE")
	_press("IRIS_RESTORE")
	_expect(_count("STATUS_RESTORE_ORDER") == 2 and not NOTES.RULES.progress(GameState.get_snapshot()).power, "genuine failed chronology attempts are distinct observations")
	_press("IRIS_CLEAR")
	_drain()
	for key in NOTES.RULES.ORDER:
		_press("IRIS_LOG_" + key)
		_drain()
	_press("IRIS_RESTORE")
	_expect(_count("SCREEN_AUDIT") == 0, "audit panel behind the restore dialogue is undisclosed")
	_drain()
	_press("IRIS_AUDIT_WRONG")
	_expect(_count("STATUS_AUDIT_MISMATCH") == 1 and not NOTES.RULES.progress(GameState.get_snapshot()).mismatch, "incorrect attribution gives evidence, not a solved audit")
	_press("IRIS_AUDIT")
	_drain()
	_press("IRIS_CONFRONT")
	var entry := _entry("CONFRONT")
	_expect(entry.observation.segments.size() == 1, "only the first account paragraph is observed")
	var unavailable := ARCHIVE.make_reference(entry, "line_01")
	unavailable.segment_id = "line_03"
	_expect(not ARCHIVE.resolve(_archive(), unavailable).ok, "future account paragraph cannot resolve")
	_drain()
	ready = GameState.get_snapshot()
	_press("IRIS_CHOICE")
	view._modal_body.get_child(3).pressed.emit()
	var deferred := GameState.get_snapshot()
	deferred.meta_progress.dialogue_history = ready.meta_progress.dialogue_history.duplicate(true)
	_expect(STATE_ASSERTIONS.same_gameplay(ready, deferred, "modal") and _ledger().revisions.is_empty(), "deferring changes only observed choice context and its completed presentation cursor")
	_collect()


func _outcome(scenario: Array) -> void:
	var fixture := ready.duplicate(true)
	fixture.meta_progress.servants.iris.bond = scenario[0]
	fixture.meta_progress.servants.iris.alert = scenario[1]
	_install(fixture)
	_present()
	_press("IRIS_CHOICE")
	view._modal_body.get_child(4 if scenario[2] == "external_truth" else 5).pressed.emit()
	var mode: String = scenario[3]
	_expect(_count("RECORD") == 1 and _ledger().revisions.size() == 1, "record and completion commit atomically")
	_expect(_count("CHOOSE_" + String(scenario[2]).to_upper()) == 1 and _count("CONFESSION_" + mode.to_upper()) == 0, "committed choice does not disclose the next confession paragraph")
	for key in ["DIRECT_PRIVATE", "INDIRECT", "DENIED", "WITHHELD"]: _expect(_count("CONFESSION_" + key) == 0, "unshown confession is unavailable")
	_drain()
	var after := GameState.get_snapshot()
	var iris: Dictionary = after.meta_progress.servants.iris
	_expect(int(iris.bond) == clampi(int(scenario[0]) + (2 if scenario[2] == "external_truth" else 0), 0, 5), "original bond delta")
	_expect(int(iris.alert) == clampi(int(scenario[1]) + (1 if scenario[2] == "shelter_projection" else 0), 0, 5), "original alert delta")
	_expect(iris.core_event_complete and iris.researcher_record_acquired and view.session.known("REC_IRIS"), "original completion conditions")
	_expect(not after.meta_progress.knowledge_entries.has("iris_confession_state"), "no new global confession state")
	_expect(after.meta_progress.knowledge_entries.chapter_notebook.REC_IRIS == NOTES.RULES.RECORD, "research record does not acquire private confession text")
	for key in ["DIRECT_PRIVATE", "INDIRECT", "DENIED", "WITHHELD"]:
		_expect(_count("CONFESSION_" + key) == (1 if key == mode.to_upper() else 0), "only the actual conditional response is preserved")
	_expect(_count("ALERT") == (1 if scenario[4] else 0), "sharp-voice paragraph follows its independent actual condition")
	var revision: Dictionary = _ledger().revisions.back()
	_expect(revision.metadata.knowledge_id == "REC_IRIS" and revision.source_refs.size() >= 12, "record cites visible evidence and itself")
	for reference in revision.source_refs:
		var resolved := ARCHIVE.resolve(_archive(), reference)
		_expect(resolved.ok, "record source resolves")
		if resolved.ok: _expect(not String(resolved.entry.observation.content_id).begins_with(NOTES.PREFIX + "CONFESSION_"), "record cannot cite a confession that occurs after its commit")
	_expect(not view.session.act("iris_choose", scenario[2]).ok and GameState.get_snapshot() == after, "completed choice is not farmable")
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == after, "rereading cannot infer a stronger confession")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "outcome JSON reload")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), after), "saved record and conditional text survive reload")
	_collect()
	# Changed live relationship values must not alter the frozen response.
	var previous_render := CONTENT.render_entry(_entry("CONFESSION_" + mode.to_upper()), TranslationServer.get_locale())
	var changed := after.duplicate(true)
	changed.meta_progress.servants.iris.bond = 5 if mode != "direct_private" else 0
	changed.meta_progress.servants.iris.alert = 0
	_install(changed)
	var before_read := GameState.get_snapshot()
	var original := _entry("CONFESSION_" + mode.to_upper())
	var rendered := CONTENT.render_entry(original, TranslationServer.get_locale())
	_expect(rendered.ok and not rendered.entry.fallback and rendered == previous_render and GameState.get_snapshot() == before_read, "relationship changes cannot rewrite the historical response or write during rendering")
	for key in ["DIRECT_PRIVATE", "INDIRECT", "DENIED", "WITHHELD"]:
		_expect(_count("CONFESSION_" + key) == (1 if key == mode.to_upper() else 0), "new relationship values cannot add a stronger response")
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
		errors.append_array(preload("res://scripts/tests/notebook_relationship_choice_retry.gd").run(view, controlled, "iris", choice_index))
	_install(ready)
	_present()
	view.session._save = controlled
	controlled.reject_game = true
	var before := GameState.get_snapshot()
	var result: Dictionary = view.session.act("iris_choose", "external_truth")
	_expect(not result.ok and GameState.get_snapshot() == before, "failed commit leaves relation, record, ledger and history unchanged")
	controlled.reject_game = false
	controlled.lose_ack = true
	result = view.session.act("iris_choose", "external_truth")
	_expect(result.ok and _ledger().revisions.size() == 1, "lost game acknowledgement confirms the atomic record")
	view._render_room()
	view._feedback(result)
	_drain()
	_collect()
	_install(ordering)
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("IRIS_RESTORE")
	_expect(_count("STATUS_RESTORE_ORDER") == 0 and GameState.get_snapshot() == before, "failed status observation is not fabricated")
	var attempts := controlled.attempts
	_press("IRIS_RESTORE")
	_expect(controlled.attempts == attempts, "blocked repeat does not keep writing to disk")
	controlled.reject_history = false
	controlled.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("STATUS_RESTORE_ORDER") == 1, "explicit retry reuses failed status token")
	_collect()
	_seed()
	_present()
	_press("IRIS_CONTROL")
	_press("IRIS_PANEL")
	_drain()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("IRIS_CHANNEL_temperature_0")
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request, 3)
	_expect(GameState.get_snapshot() == before, "failed source options prevent input dispatch")
	controlled.reject_history = false
	controlled.lose_ack = true
	view._recorded_choice_pressed(request, 3)
	_drain()
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).channels.size() == 1 and _count("CHANNEL_SELECT_3") == 1, "acknowledged source choice executes once")
	_press("IRIS_CHANNEL_temperature_1")
	request = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load while a source modal is open")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 2)
	_expect(GameState.get_snapshot() == before, "pre-load source callback cannot change reloaded state")
	view._cancel_prologue_modal()
	_collect()
	view.session._save = SaveManager
	controlled.free()


func _legacy() -> void:
	_install(ready)
	_expect(view.session.act("iris_choose", "external_truth").ok, "legacy completed fixture")
	var old := GameState.get_snapshot()
	old.meta_progress.dialogue_history = ARCHIVE.create()
	old.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_install(old)
	_present()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(_ledger().revisions.is_empty() and _count("RECORD") == 0 and _count("CONFESSION_INDIRECT") == 0, "old completion and rereading cannot backfill records or confession")
	_collect()


func _seed() -> void:
	var fixture := CHECKPOINTS.new().snapshot_for("E_HUB")
	_expect(fixture.ok, "Iris entry fixture")
	var state: Dictionary = fixture.snapshot
	state.loop_state.location_id = "M1_GREENHOUSE"
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.servants.iris.bond = 0
	state.meta_progress.servants.iris.alert = 0
	_install(state)


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_IRIS_FIXTURE_%d" % serial)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "NB_IRIS_FIXTURE_%d" % serial).ok, "fixture save")
	if view != null: view._render_room()


func _channel(gauge: String, index: int, source: String) -> void:
	_press("IRIS_CHANNEL_%s_%d" % [gauge, index])
	view._modal_body.get_child(4 + NOTES.RULES.SOURCES.find(source)).pressed.emit()
	_drain()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual Iris screen capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing Iris button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(15):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "Iris dialogue remains blocked")
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
	_expect(false, "missing authored Iris entry: " + key)
	return {}


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "Iris route cannot silently produce unmapped history")
			continue
		if entry.observation.producer_id != "NP11": continue
		var observed: Dictionary = entry.observation
		if String(observed.content_id).ends_with("_SCREEN_COMPLETE"):
			_expect(PUBLIC_LABELS.live(entry), "current completion has readable labels and exact version 2 observation")
		_expect(observed.chapter_id == "CHAPTER_3" and observed.event_id == "E3_2", "Iris record uses actual chapter and event")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "fixed Iris translation is available independently of current relationship")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "record ledger and source references remain valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("IRIS_NOTE_ASSERT: ", message)
