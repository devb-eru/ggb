extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_public_puzzle_labels.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/final_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const JOURNAL := preload("res://scripts/systems/journal_four_notebook.gd")
const FATHER := preload("res://scripts/systems/father_final_record.gd")
const CONFRONTATION := preload("res://scripts/systems/researcher_confrontation.gd")
const CORE_TEST := preload("res://scripts/tests/notebook_core_smoke.gd")
const SLOT := "__test_notebook_final"
var errors := PackedStringArray()
var fixtures := {}
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var retained_decisions := 0

class ControlledSave extends Node:
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok":false, "error_ids":["ERR_TEST_FINAL_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok":false, "error_ids":["ERR_TEST_FINAL_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)
	func capture_f3_reselect(slot: String) -> Dictionary: return SaveManager.capture_f3_reselect(slot)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_install(_fixture("F1"))
	view = VIEW.new()
	view.configure_session(SLOT, "F1")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		print("FINAL_PHASE: ", language, " father and J5")
		_father()
		for mask in [0, 3, 31]: _father(mask)
		_failures()
		print("FINAL_PHASE: ", language, " confrontation")
		for mode in ["public", "direct_private", "indirect", "denied", "withheld", "inferred_only"]: _confrontation(mode)
		_missing_recap()
		_recap_matrix()
		print("FINAL_PHASE: ", language, " inspection and decision")
		for intent in ["reality", "stay", "undecided"]:
			for decision in ["reality", "stay"]: _decision(intent, decision)
		_ending_failure()
		_legacy()
		print("FINAL_PHASE: ", language, " retained anonymous chain")
		await _retained_anonymous_chain(tree)
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + language), "unvisited actual ID " + id + ":" + language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + language), "unvisited segment " + id + ":" + segment)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_expect(retained_decisions == 12, "both locales retain anonymous material across three provisional intents and both ending decisions")
	print("FINAL_RETAINED_DECISIONS: ", retained_decisions)
	print("FINAL_COVERAGE: actual ID/locales=", covered.size(), " segment/locales=", segments.size())
	return {"ok":errors.is_empty(), "errors":errors, "actual_id_locales":covered.size(), "actual_segment_locales":segments.size(),
		"not_covered":["durable_app_restart_cursor", "unified_notebook_UI", "OS_input"]}


func _father(journal_mask: int = -1, source: Dictionary = {}) -> void:
	var initial := _fixture("F1") if source.is_empty() else source.duplicate(true)
	if journal_mask >= 0:
		for index in range(JOURNAL.RULES.OWNERS.size()):
			var owner: String = JOURNAL.RULES.OWNERS[index]
			var complete := (journal_mask & (1 << index)) != 0
			initial.meta_progress.servants[owner].core_event_complete = complete
			initial.meta_progress.servants[owner].researcher_record_acquired = complete
			if not complete: continue
			var id: String = JOURNAL.QUOTES[owner].keys()[0]
			var row := CONTENT.definition(id, 1)
			initial.meta_progress.knowledge_entries.chapter_notebook["REC_" + owner.to_upper()] = row.locales["ko-KR"].body
			var source_context := {"chapter_id":"CHAPTER_3", "node_id":row.node_ids[0], "location_id":"M1_CENTRAL_HALL"}
			_expect(preload("res://scripts/systems/notebook_event_notes.gd").write(initial, id, row.locales["ko-KR"].body, source_context, TranslationServer.get_locale()).ok, "prior research source fixture")
		var composed := JOURNAL.compose(initial)
		_expect(composed.ok, "prior J4 composition")
		var original := CONTENT.presentation(composed.descriptor, "ko-KR")
		_expect(original.ok, "prior J4 original")
		initial.meta_progress.knowledge_entries.chapter_notebook.J4 = original.text
		_expect(JOURNAL.write(initial, original.text, {"chapter_id":"CHAPTER_3", "node_id":"J4", "location_id":"M1_CENTRAL_HALL"}, TranslationServer.get_locale()).ok, "prior J4 acquisition fixture")
	_install(initial)
	if not source.is_empty(): _restore_retained()
	_present()
	var before := GameState.get_snapshot()
	var prior_ledger: Dictionary = before.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()).duplicate(true)
	var prior_entries: Array = before.meta_progress.dialogue_history.entries.duplicate(true)
	_expect(_count("F1_PLAY_0") == 0 and _count("J5_RECORD") == 0, "entry cannot fabricate playback or J5")
	_press("F1_ENTER")
	_drain()
	_press("F1_INSPECT")
	_expect(_count("F1_INSPECT") == 1, "inspection second paragraph remains hidden")
	_drain()
	_press("F1_AUTH")
	_drain()
	_expect(_count("F1_TITLE_PLAY_0") == 1 and _count("F1_TITLE_PLAY_1") == 0, "only available recording titles shown")
	for index in range(8):
		_press("F1_SEG_%d" % index)
		_expect(_count("F1_PLAY_%d" % index) == 1, "title disclosure does not reveal remaining audio")
		_drain()
		_expect(_count("F1_PLAY_%d" % index) == 1 + FATHER.SEGMENTS[index].split("\n",false).size(), "all played paragraphs eventually archived")
	_expect(_count("J5_PAGE") == 0, "playback flags cannot invent J5 page")
	_press("J5_PAGE")
	_expect(_count("J5_PAGE") == 1 and _count("J5_RECORD") == 0, "opening one paragraph is not document acquisition")
	_drain()
	_press("J5_WRITE")
	_expect(_count("J5_RECORD") == 1 and _count("J5_WRITE") == 1, "J5 written atomically but feedback still incremental")
	_drain()
	_expect(view.session.stage() == "F2", "J5 leads to confrontation")
	_expect(GameState.get_snapshot().ending_run == before.ending_run, "J5 cannot commit ending")
	var ledger: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries[KNOWLEDGE.KEY]
	_expect(ledger.revisions.size() == prior_ledger.revisions.size() + 1 and ledger.revisions.back().metadata.knowledge_id == "J5", "J5 adds one structured revision without replacing prior journals")
	_expect(KNOWLEDGE.validate(ledger, _archive()).ok, "J5 source references resolve")
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "J5 reload")
	_expect(StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "saved original and source versions retained")
	for revision in prior_ledger.revisions:
		_expect(revision in ledger.revisions, "J5 retains prior knowledge revision and source references")
	for entry in prior_entries:
		var retained: Dictionary = {}
		for candidate in _archive().entries:
			if candidate.entry_uid == entry.entry_uid: retained = candidate
		var comparable := retained.duplicate(true)
		comparable.protection_reasons = entry.protection_reasons.duplicate()
		_expect(comparable == entry, "J5 and reload preserve prior UID, original and order")
		var expected_reasons: Array = entry.protection_reasons.duplicate()
		for reference in ledger.revisions.back().source_refs:
			if reference.uid == entry.entry_uid:
				var reason: String = "knowledge_source:" + ledger.revisions.back().revision_uid
				if reason not in expected_reasons: expected_reasons.append(reason)
		expected_reasons.sort()
		var actual_reasons: Array = retained.get("protection_reasons", []).duplicate()
		actual_reasons.sort()
		_expect(actual_reasons == expected_reasons, "only the exact new J5 citation may extend prior protection")
		for language in ["ko-KR", "en-US"]:
			_expect(CONTENT.render_entry(retained, language) == CONTENT.render_entry(entry, language), "final truth cannot rewrite prior journal translations")
	if journal_mask >= 0:
		_expect(GameState.get_snapshot().meta_progress.knowledge_entries.chapter_notebook.J4 == before.meta_progress.knowledge_entries.chapter_notebook.J4, "legacy-compatible J4 original also stays unchanged")
	_collect()


func _confrontation(mode: String, retained: Dictionary = {}) -> void:
	var state := _fixture("F2") if retained.is_empty() else retained.duplicate(true)
	if retained.is_empty():
		for servant in state.meta_progress.servants.values(): servant.core_event_complete = mode == "public"
		state.meta_progress.servants.edgar.core_event_complete = true
		var iris: Dictionary = state.meta_progress.servants.iris
		iris.core_event_complete = mode != "inferred_only"
		iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		iris.alert = 4 if mode == "denied" else 0
	_expect(CONFRONTATION.iris_state(state) == mode, "fixture relation variant " + mode)
	_install(state)
	if not retained.is_empty(): _restore_retained()
	_press("F2_ENTER")
	_expect(_count("F2_ENTER_" + mode.to_upper()) == 1, "only first confrontation line observed")
	_expect(_count("F2_OPTIONS") == 0, "questions not displayed under dialogue")
	_drain()
	_expect(_count("F2_ENTER_" + mode.to_upper()) == 7, "chosen relation variant completely shown")
	if mode != "public": _expect(_count("F2_ENTER_PUBLIC") == 0, "no unearned public confession")
	var after_enter := _archive().duplicate(true)
	for question in NOTES.QUESTIONS:
		_press("F2_" + question)
		_drain()
	_press("F2_RECAP")
	_drain()
	for fact in CONFRONTATION.FACTS:
		_expect(_count("F2_FACT_" + String(fact).trim_prefix("KN_F2_")) == String(CONFRONTATION.FACTS[fact]).split("\n", false).size(), "recap does not repeat already asked fact")
	_press("F2_FINISH")
	_drain()
	_expect(view.session.stage() == "F3" and GameState.get_snapshot().ending_run.final_decision == "unset", "all relationship states reach uncommitted inspection")
	for index in range(after_enter.entries.size()): _expect(_archive().entries[index] == after_enter.entries[index], "later interaction cannot rewrite relation variant")
	_collect()


func _missing_recap() -> void:
	_install(_fixture("F2"))
	_press("F2_ENTER")
	_drain()
	_press("F2_RECAP")
	_expect(_count("F2_FACT_PROMISED_FUTURE_BODIES") == 1 and _count("F2_FACT_FINAL_AUTHORITY_BELONGS_TO_SUBJECT") == 0, "recap knowledge flags cannot expose trailing facts")
	_drain()
	for fact in CONFRONTATION.FACTS:
		_expect(_count("F2_FACT_" + String(fact).trim_prefix("KN_F2_")) == String(CONFRONTATION.FACTS[fact]).split("\n",false).size(), "missing facts observed on actual recap")
	_collect()


func _recap_matrix() -> void:
	for mask in range(32):
		var state := _fixture("F2")
		var entered := CONFRONTATION.apply(state, "enter", null)
		_expect(entered.ok, "matrix confrontation entry")
		state = entered.state
		for index in range(NOTES.QUESTIONS.size()):
			if mask & (1 << index):
				state = CONFRONTATION.apply(state, "question", NOTES.QUESTIONS[index]).state
		var already: Array = CONFRONTATION.progress(state).facts.duplicate()
		var result := CONFRONTATION.apply(state, "recap", null)
		var lines := PackedStringArray()
		for descriptor in NOTES.paragraphs(result.notebook_keys):
			var shown := CONTENT.presentation(descriptor, "ko-KR")
			_expect(shown.ok, "partial recap descriptor")
			lines.append(shown.text)
		_expect("\n".join(lines) == String(result.text).strip_edges(), "all question subsets preserve exact recap order")
		for fact in already:
			_expect("F2_FACT_" + String(fact).trim_prefix("KN_F2_") not in result.notebook_keys, "asked fact not redisclosed by recap")


func _ending_failure() -> void:
	_install(_fixture("EDC"))
	_present()
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_game = true
	view._confirm_ending("stay")
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_expect(GameState.get_snapshot().ending_run.final_decision == "unset", "failed ending save remains uncommitted")
	_expect(_count("EDC_REAFFIRMED") + _count("EDC_REVISED") + _count("EDC_FORMED") == 0, "failed final commit has no success reaction")
	saver.reject_game = false
	saver.lose_ack = true
	view._confirm_ending("stay")
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_drain()
	_expect(GameState.get_snapshot().ending_run.final_decision == "stay", "ending save acknowledgement reconciled")
	_expect(_count("EDC_REAFFIRMED") + _count("EDC_REVISED") + _count("EDC_FORMED") == 1, "ending response recorded exactly once")
	_collect()
	view.session._save = SaveManager
	saver.free()


func _decision(intent: String, decision: String, retained: Dictionary = {}) -> void:
	var state := _fixture("F3") if retained.is_empty() else retained.duplicate(true)
	if retained.is_empty(): state.meta_progress.knowledge_entries.f0_provisional_intent = intent
	else: _expect(state.meta_progress.knowledge_entries.f0_provisional_intent == intent, "retained provisional intent is not rewritten by the final test")
	_install(state)
	if not retained.is_empty(): _restore_retained()
	_present()
	_press("F3_ENTER")
	_drain()
	for device in (["wake", "stay", "notebook"] if decision == "reality" else ["stay", "wake", "notebook"]):
		_press("F3_" + device.to_upper())
		_drain()
	_press("F3_SUMMARY")
	_drain()
	_expect(GameState.get_snapshot().ending_run.final_decision == "unset", "summary is not final decision")
	_press("F3_OPEN")
	_drain()
	_expect(view.session.stage() == "EDC", "inspection opens neutral final review")
	view._confirm_ending(decision)
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_drain()
	_expect(view.session.stage() == "F3" and GameState.get_snapshot().ending_run.final_decision == "unset", "cancel does not inherit provisional intent")
	_press("F3_OPEN")
	_drain()
	view._confirm_ending(decision)
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_drain()
	var relation := "formed" if intent == "undecided" else "reaffirmed" if intent == decision else "revised"
	_expect(_count("EDC_" + relation.to_upper()) == 1, "only actual final-choice reaction archived")
	_expect(GameState.get_snapshot().ending_run.final_decision == decision, "each provisional intent allows either ending")
	var saved := GameState.get_snapshot()
	for entry in _archive().entries: CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
	_expect(GameState.get_snapshot() == saved, "replay cannot change branch or relationship")
	_collect()


func _retained_anonymous_chain(tree: SceneTree) -> void:
	var core := CORE_TEST.new()
	core._install(core._fixture("F0_D"))
	core.view = VIEW.new()
	core.view.configure_session(core.SLOT, "F0_D")
	tree.current_scene.add_child(core.view)
	await tree.process_frame
	core.view._dismiss_dialogue_for_test()
	core._roles(false)
	var role_source := GameState.get_snapshot()
	for intent in ["reality", "stay", "undecided"]:
		core._authority("house_glyph", intent, role_source)
		var original := GameState.get_snapshot()
		_father(-1, original)
		_check_retained_anonymous(core, original, "unset")
		var after_father := GameState.get_snapshot()
		_confrontation(CONFRONTATION.iris_state(after_father), after_father)
		_check_retained_anonymous(core, original, "unset")
		var inspection_source := GameState.get_snapshot()
		for decision in ["reality", "stay"]:
			_decision(intent, decision, inspection_source)
			_check_retained_anonymous(core, original, decision)
			retained_decisions += 1
	_expect(core.anonymous_reviews == 16, "role, authority and final stages all review actual anonymous records")
	errors.append_array(core.errors)
	core.view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(core.SLOT)


func _restore_retained() -> void:
	_expect(view._restore_presentation(), "retained final cursor uses actual presentation restoration")
	_present()


func _check_retained_anonymous(core: RefCounted, original: Dictionary, decision: String) -> void:
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "retained anonymous final stage reload")
	_expect(StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "final reload preserves actual anonymous chain")
	var current_entries := {}
	for current in _archive().entries: current_entries[current.entry_uid] = current
	for entry in original.meta_progress.dialogue_history.entries:
		var found: Dictionary = current_entries.get(entry.entry_uid, {})
		_expect(not found.is_empty() and found.observation == entry.observation and found.sequence == entry.sequence, "final truth and choice cannot rewrite earlier core observations")
	_expect(GameState.get_snapshot().meta_progress.servants == original.meta_progress.servants, "final anonymous path never awards a relationship")
	_expect(GameState.get_snapshot().ending_run.final_decision == decision, "anonymous browsing cannot alter final decision")
	core._anonymous_review()


func _failures() -> void:
	var state := _fixture("F1")
	state.loop_state.event_local_states.F1 = {"entered":true, "authenticated":true, "next":8, "j5_read":true}
	state.meta_progress.knowledge_entries.father_final_record_played = true
	_install(state)
	_present()
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_game = true
	var before := GameState.get_snapshot()
	_press("J5_WRITE")
	_expect(GameState.get_snapshot() == before and _count("J5_RECORD") == 0, "failed J5 commit cannot acquire document")
	saver.reject_game = false
	saver.lose_ack = true
	_press("J5_WRITE")
	_drain()
	_expect(_count("J5_RECORD") == 1, "uncertain acknowledgement reconciled once")
	_collect()
	view.session._save = SaveManager
	_install(_fixture("F1"))
	view.session._save = saver
	saver.lose_ack = false
	_press("F1_ENTER")
	_drain()
	saver.reject_history = true
	_press("F1_INSPECT")
	_expect(_count("F1_INSPECT") == 0 and view._dialogue_active, "failed first-line save is not recorded")
	view._advance_dialogue()
	_expect(_count("F1_INSPECT") == 0 and view._dialogue_index == 0, "failed save blocks next paragraph")
	saver.reject_history = false
	_drain()
	_expect(_count("F1_INSPECT") == 2, "explicit retry records each paragraph once")
	_collect()
	view.session._save = SaveManager
	saver.free()


func _legacy() -> void:
	_install(_fixture("F2"))
	_present()
	_expect(_count("J5_RECORD") == 0 and _count("F1_PLAY_7") == 0, "legacy progress does not invent prior observations")
	_press("F2_ENTER")
	_drain()
	var generation := view._notebook_surfaces.generation
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load advances input scope")
	var before := GameState.get_snapshot()
	view._final_question_pressed(generation, 0, "stale", "ko-KR")
	_expect(GameState.get_snapshot() == before, "stale question cannot write in loaded scope")


func _fixture(stage: String) -> Dictionary:
	if not fixtures.has(stage):
		var fixture := CHECKPOINTS.new().snapshot_for(stage)
		_expect(fixture.ok, "checkpoint " + stage)
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
	var token := "NB_FINAL_FIXTURE_%d" % serial
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName(token)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, token).ok, "fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual final surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing final button " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(60):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "final dialogue blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: count += 1
	return count


func _collect() -> void:
	errors.append_array(PUBLIC_LABELS.screen_errors(view))
	var state := GameState.get_snapshot()
	for entry in _archive().entries:
		errors.append_array(PUBLIC_LABELS.live_errors(entry))
		_expect(entry.get("record_class") == "authored", "no unmapped final history")
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_4" and observation.node_id in ["F1", "F2", "F3", "EDC"], "precommit final source context")
		for segment in observation.segments:
			covered[observation.content_id + ":" + segment.viewed_locale] = true
			segments[observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR").ok, "bilingual replay of actual observations")
	_expect(KNOWLEDGE.validate(state.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), _archive()).ok, "knowledge references valid")
	_expect(GameState.get_snapshot() == state, "collection is read only")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("FINAL_ASSERT: ", message)
