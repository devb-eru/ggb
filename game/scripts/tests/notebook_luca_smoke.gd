extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_relationship_label_assertions.gd")

const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/luca_notebook.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const SLOT := "__test_notebook_luca"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var ready: Dictionary = {}
var cycle_ready: Dictionary = {}
var enum_cases := 0
var relationship_cases := 0

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
			return {"ok": false, "error_ids": ["ERR_TEST_LUCA_SAVE"]}
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_LUCA_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	errors.append_array(PUBLIC_LABELS.catalog(["luca"]))
	_seed()
	view = VIEW.new()
	view.configure_session(SLOT, "E3_3")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		_evidence()
		_enum_matrix()
		for outcome in ["full_disclosure", "stabilize_first"]: await _outcome(outcome)
		for bond in range(6):
			for alert in range(6):
				for outcome in ["full_disclosure", "stabilize_first"]:
					await _outcome(outcome, bond, alert, true)
					relationship_cases += 1
		_failures()
		await _legacy()
		for id in CONTENT.diagnostics().content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + locale), "unexecuted Luca content: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "undisplayed Luca segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": 31, "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "enum_cases": enum_cases,
		"relationship_cases": relationship_cases, "not_covered": ["other_relationship_producers", "durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _evidence() -> void:
	_seed()
	_present()
	_expect(_count("SCREEN_ENTRY") == 1 and _count("SCREEN_LOG_PRESERVATION") == 0, "entry does not reveal later cooling documents")
	var before := GameState.get_snapshot()
	view._render_room()
	_present()
	_expect(GameState.get_snapshot() == before, "redrawing entry adds no observation")
	_press("LIFE_SUPPORT_ENTER")
	_press("LUCA_PANEL")
	_expect(_count("PANEL") == 1 and _count("PANEL_S2") == 0 and _count("SCREEN_PIPE_MAIN") == 0, "first panel paragraph does not reveal its next paragraph or covered pipes")
	_drain()
	_expect(_count("PANEL_S2") == 1, "completed prior conversation adds only the actually displayed callback")
	var relation: Dictionary = GameState.get_snapshot().meta_progress.servants.luca
	_press("LUCA_PIPE_decoration")
	_drain()
	_press("LUCA_PIPE_main")
	_drain()
	_press("LUCA_MATCH")
	_press("LUCA_MATCH")
	_expect(_count("STATUS_MATCH_SOURCES") == 2 and GameState.get_snapshot().meta_progress.servants.luca == relation, "two wrong matches are distinct observations without relationship penalty")
	_press("LUCA_PIPE_decoration")
	_drain()
	_press("LUCA_PIPE_aux")
	_drain()
	_press("LUCA_MATCH")
	_drain()
	cycle_ready = GameState.get_snapshot()
	_press("LUCA_SLOT_0")
	var local: Dictionary = NOTES.RULES.progress(GameState.get_snapshot())
	view._cancel_prologue_modal()
	_expect(NOTES.RULES.progress(GameState.get_snapshot()) == local and _count("SLOT_SELECT_0") == 1, "Esc defers without assigning a valve")
	_press("LUCA_PREVIEW")
	_drain()
	var unassigned := _entry("CYCLE")
	_expect(unassigned.observation.segments[0].safe_variables.values() == ["unassigned", "unassigned", "unassigned", "unassigned"], "empty preview freezes only four unassigned tokens")
	_press("LUCA_RUN")
	_expect(_count("RUN_FAILURE") == 0 and not NOTES.RULES.progress(GameState.get_snapshot()).stable, "failed run result is not observed before the cycle line")
	_drain()
	_expect(_count("RUN_FAILURE") == 1 and NOTES.RULES.progress(GameState.get_snapshot()).pressure == 0, "failed run retains life signals and remains retryable")
	for index in range(4): _slot(index, NOTES.RULES.PHASES[3 - index])
	_press("LUCA_PREVIEW")
	_drain()
	var old_preview := _entry("CYCLE", true)
	var old_render := CONTENT.render_entry(old_preview, "en-US")
	var preserved: Array = _archive().entries.duplicate(true)
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "partial valve assignment JSON reload")
	view._render_room()
	_present()
	for observed in preserved: _expect(observed in _archive().entries, "load preserves all prior cycle observations")
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).slots["0"] == "safety", "load preserves the attempted layout rather than correcting it")
	for index in range(4): _slot(index, NOTES.RULES.PHASES[index])
	_press("LUCA_RUN")
	_expect(_count("RUN_SUCCESS") == 0 and _count("SCREEN_LOG_PRESERVATION") == 0, "successful state does not expose next dialogue or covered documents")
	_drain()
	_expect(CONTENT.render_entry(old_preview, "en-US") == old_render, "new layout cannot rewrite an earlier preview")
	for key in NOTES.RULES.LOGS:
		_expect(_count("SCREEN_LOG_" + String(key).to_upper()) == 1 and _count("LOG_" + String(key).to_upper()) == 0, "document buttons can be read before confirming them")
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).logs.is_empty() and not view.session.known("luca_wake_criteria_read"), "document display is not the game read confirmation")
	for key in NOTES.RULES.LOGS:
		_press("LUCA_LOG_" + key)
		_drain()
	_press("LUCA_CONFESS")
	var unavailable := ARCHIVE.make_reference(_entry("CONFESS"), "line_01")
	unavailable.segment_id = "line_03"
	_expect(not ARCHIVE.resolve(_archive(), unavailable).ok, "unshown confession paragraph cannot be referenced")
	_drain()
	ready = GameState.get_snapshot()
	_press("LUCA_CHOICE")
	view._modal_body.get_child(3).pressed.emit()
	var deferred := GameState.get_snapshot()
	deferred.meta_progress.dialogue_history = ready.meta_progress.dialogue_history.duplicate(true)
	_expect(STATE_ASSERTIONS.same_gameplay(ready, deferred, "modal") and _ledger().revisions.is_empty(), "deferral records choices and a completed cursor but neither completes relation nor creates record")
	_collect()


func _enum_matrix() -> void:
	var source := cycle_ready.duplicate(true)
	var context := view.session.history_context()
	context.event_occurrence_id = ARCHIVE.new_uid()
	context.conversation_session_id = ARCHIVE.new_uid()
	context.presentation_token = ARCHIVE.new_uid()
	var locale := TranslationServer.get_locale()
	var row := CONTENT.definition(NOTES.PREFIX + "CYCLE", 1)
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	var tokens: Array = ["unassigned"] + NOTES.RULES.PHASES
	for code in range(625):
		var number := code
		var slots := {}
		for index in range(4):
			var token: String = tokens[number % 5]
			number = int(number / 5)
			if token != "unassigned": slots[str(index)] = token
		source.loop_state.event_local_states.E3_3.slots = slots
		var result := NOTES.RULES.apply(source, "preview", null)
		_expect(result.ok, "all public slot combinations can be previewed")
		var descriptor: Dictionary = NOTES.paragraphs(result.feedback_keys, result.cycle_values)[0]
		var observed := CONTENT.observe(descriptor, context, row.locales[language].speaker, DISPLAY.text(result.text, locale), locale)
		_expect(observed.ok, "closed enum matches actual preview: " + str(code))
		if not observed.ok: continue
		var archive := ARCHIVE.create()
		archive = ARCHIVE.append_observation(archive, observed.observation, 0).archive
		var other := "ko-KR" if language == "en-US" else "en-US"
		var rendered := CONTENT.render_entry(archive.entries[0], other)
		_expect(rendered.ok and not rendered.entry.fallback and rendered.entry.segments[0].text == DISPLAY.text(result.text, other), "all 625 combinations preserve current-language phase names")
		enum_cases += 1


func _outcome(outcome: String, bond: int = 1, alert: int = 1, matrix: bool = false) -> void:
	var source := ready.duplicate(true)
	source.meta_progress.servants.luca.bond = bond
	source.meta_progress.servants.luca.alert = alert
	_install(source)
	_present()
	var previous: Array = _archive().entries.duplicate(true)
	_press("LUCA_CHOICE")
	view._modal_body.get_child(4 if outcome == "full_disclosure" else 5).pressed.emit()
	var first := "RISK" if outcome == "full_disclosure" else "STABLE"
	var second := "STABLE" if first == "RISK" else "RISK"
	_expect(_count(first) == 1 and _count(second) == 0, "only the selected first disclosure is observed")
	_expect(_count("RECORD") == 1 and _ledger().revisions.size() == 1, "record acquisition is separate from result paragraph display")
	_drain()
	var after := GameState.get_snapshot()
	_expect(int(_entry(first).sequence) < int(_entry(second).sequence), "choice preserves the risk/stabilization presentation order")
	var luca: Dictionary = after.meta_progress.servants.luca
	_expect(luca.bond == clampi(bond + (2 if outcome == "full_disclosure" else 1), 0, 5) and luca.alert == clampi(alert + (1 if outcome == "full_disclosure" else -1), 0, 5), "relationship deltas preserve both bounds for every initial value")
	_expect(luca.core_event_complete and luca.researcher_record_acquired and view.session.known("wake_criteria_missing"), "original relation and knowledge complete")
	_expect(after.meta_progress.knowledge_entries.chapter_notebook.REC_LUCA == NOTES.RULES.RECORD, "both choices preserve the same risk record")
	var note: Dictionary = _ledger().revisions.back()
	_expect(note.metadata.knowledge_id == "REC_LUCA" and note.source_refs.size() >= 9, "record cites visible evidence and itself")
	for reference in note.source_refs:
		var resolved := ARCHIVE.resolve(_archive(), reference)
		_expect(resolved.ok, "research record source resolves")
		if resolved.ok: _expect(resolved.entry.observation.content_id not in [NOTES.PREFIX + "RISK", NOTES.PREFIX + "STABLE"], "record cannot cite the future choice response")
	_expect(not view.session.act("luca_choose", outcome).ok and GameState.get_snapshot() == after, "completed choice cannot repeat relationship rewards")
	if not matrix:
		view._open_notebook()
		if is_instance_valid(view._notebook_host):
			_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
		view._close_modal()
		_expect(GameState.get_snapshot() == after, "rereading does not verify awakening safety")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "research record and result order reload")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), after), "actual JSON preserves all outcome evidence")
	for old in previous:
		var found := _find_uid(old.entry_uid)
		_expect(not found.is_empty() and found.observation == old.observation and found.sequence == old.sequence, "Luca record acquisition preserves previous observation and order")
	_collect()
	var record := _entry("RECORD").duplicate(true)
	var replay := CONTENT.render_entry(record, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
	var changed := after.duplicate(true)
	changed.meta_progress.servants.luca.bond = 5 - bond
	changed.meta_progress.servants.luca.alert = 5 - alert
	_install(changed)
	_expect(_find_uid(record.entry_uid) == record and CONTENT.render_entry(record, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR") == replay, "changed Luca relation cannot rewrite the captured research record")


func _find_uid(uid: String) -> Dictionary:
	for entry in _archive().entries:
		if entry.entry_uid == uid: return entry
	return {}


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
		errors.append_array(preload("res://scripts/tests/notebook_relationship_choice_retry.gd").run(view, controlled, "luca", choice_index))
	_install(ready)
	_present()
	view.session._save = controlled
	controlled.reject_game = true
	var before := GameState.get_snapshot()
	var result: Dictionary = view.session.act("luca_choose", "full_disclosure")
	_expect(not result.ok and GameState.get_snapshot() == before, "failed record save is atomic with bond, flags, archive and ledger")
	controlled.reject_game = false
	controlled.lose_ack = true
	result = view.session.act("luca_choose", "full_disclosure")
	_expect(result.ok and _ledger().revisions.size() == 1, "lost acknowledgement confirms the committed record")
	view._render_room()
	view._feedback(result)
	_drain()
	_collect()
	_install(cycle_ready)
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("LUCA_SLOT_0")
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before, "failed options display prevents valve assignment")
	controlled.reject_history = false
	controlled.lose_ack = true
	view._recorded_choice_pressed(request, 1)
	_drain()
	_expect(NOTES.RULES.progress(GameState.get_snapshot()).slots["0"] == "main_1" and _count("SLOT_SELECT_1") == 1, "source selection retry executes once")
	_press("LUCA_SLOT_1")
	request = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load with an open valve modal")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 2)
	_expect(GameState.get_snapshot() == before, "pre-load callback cannot assign a valve to a new snapshot")
	view._cancel_prologue_modal()
	_collect()
	_seed()
	_present()
	_press("LIFE_SUPPORT_ENTER")
	_press("LUCA_PANEL")
	_drain()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("LUCA_MATCH")
	_expect(GameState.get_snapshot() == before and _count("STATUS_MATCH_SOURCES") == 0, "failed rejection capture creates no observation")
	var attempts := controlled.attempts
	_press("LUCA_MATCH")
	_expect(controlled.attempts == attempts, "failed capture waits for explicit retry")
	controlled.reject_history = false
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("STATUS_MATCH_SOURCES") == 1, "explicit retry preserves the failed status token")
	_collect()
	view.session._save = SaveManager
	controlled.free()


func _legacy() -> void:
	_seed(false)
	_present()
	_press("LIFE_SUPPORT_ENTER")
	_press("LUCA_PANEL")
	_drain()
	_expect(_count("PANEL_S2") == 0, "old hub without prior S2 confirmation cannot invent its callback")
	_collect()
	_install(ready)
	_expect(view.session.act("luca_choose", "stabilize_first").ok, "completed legacy fixture")
	var old := GameState.get_snapshot()
	old.meta_progress.dialogue_history = ARCHIVE.create()
	old.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_install(old)
	_present()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(_ledger().revisions.is_empty() and _count("RECORD") == 0 and _count("RISK") == 0, "old completion does not backfill record or response")
	_collect()


func _seed(prior_s2: bool = true) -> void:
	var fixture := CHECKPOINTS.new().snapshot_for("E_HUB")
	_expect(fixture.ok, "Luca entry fixture")
	var state: Dictionary = fixture.snapshot
	state.loop_state.location_id = "M1_KITCHEN"
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	if prior_s2: state.meta_progress.knowledge_entries.LUCA_S2_complete = true
	else: state.meta_progress.knowledge_entries.erase("LUCA_S2_complete")
	state.meta_progress.servants.luca.bond = 1
	state.meta_progress.servants.luca.alert = 1
	_install(state)


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_LUCA_FIXTURE_%d" % serial)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "NB_LUCA_FIXTURE_%d" % serial).ok, "fixture save")
	if view != null: view._render_room()


func _slot(index: int, phase: String) -> void:
	_press("LUCA_SLOT_%d" % index)
	view._modal_body.get_child(4 + NOTES.RULES.PHASES.find(phase)).pressed.emit()
	_drain()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual Luca screen capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing Luca button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(15):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "Luca dialogue remains blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _count(key: String) -> int:
	var found := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: found += 1
	return found


func _entry(key: String, latest: bool = false) -> Dictionary:
	var found := {}
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key:
			if not latest: return entry
			found = entry
	_expect(not found.is_empty(), "missing authored Luca entry: " + key)
	return found


func _collect() -> void:
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "Luca route cannot silently produce unmapped history")
			continue
		if entry.observation.producer_id != "NP12": continue
		var observed: Dictionary = entry.observation
		if String(observed.content_id).ends_with("_SCREEN_COMPLETE"):
			_expect(PUBLIC_LABELS.live(entry), "current completion has readable labels and exact version 2 observation")
		_expect(observed.chapter_id == "CHAPTER_3" and observed.event_id == "E3_3", "Luca record uses actual chapter and event")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "fixed Luca translation does not depend on current valve state")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "record ledger and references remain valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("LUCA_NOTE_ASSERT: ", message)
