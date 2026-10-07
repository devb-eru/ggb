extends RefCounted

const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const NOTES := preload("res://scripts/systems/chapter_one_notes.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const SLOT := "__test_notebook_chapter_one_notes"
var errors := PackedStringArray()
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()
var covered := {}
var observed_tuples := {}
var serial := 0
var retention_routes := 0

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": ["ERR_TEST_NOTE_SAVE"]}

class LostAcknowledgement extends Node:
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_ACK"]} if result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var language := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostics := CONTENT.diagnostics()
	if not diagnostics.ok: return {"ok": false, "errors": diagnostics.error_ids}
	var ids: Array = diagnostics.content_ids.filter(func(id: String) -> bool: return CONTENT.definition(id, 1).producer_id == "NP06")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		_route(locale)
		await _retained_sources_after_pruning(tree, locale)
		for id in ids: _expect(covered.has(id + ":" + locale), "missing acquisition: " + id + ":" + locale)
	await _persistence_and_legacy(tree)
	SaveManager.delete_test_slot(SLOT)
	_report_tuples()
	_expect(retention_routes == 2, "actual acquired source graph survives ordinary pruning in both languages")
	print("NOTEBOOK_NP06_ACTUAL_RETENTION_ROUTES:", retention_routes)
	TranslationServer.set_locale(language)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_expect(runtime_audit.emit("chapter-one-notes", errors.is_empty()).ok, "runtime trace validates")
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "guard_fixture": "BF_PHASE_UNSET", "not_covered": ["NP05", "NP07+", "new_notebook_UI", "OS_input"]}


func _retained_sources_after_pruning(tree: SceneTree, locale: String) -> void:
	var state := GameState.get_snapshot()
	var original := state.duplicate(true)
	var archive: Dictionary = state.meta_progress.dialogue_history
	var ledger: Dictionary = _ledger().duplicate(true)
	var failed: Array = ledger.revisions.filter(func(row: Dictionary) -> bool: return row.metadata.knowledge_id == "CH1_CLOCK_FAILURE")
	_expect(failed.size() >= 2, "retention begins with actual failed and resolved revisions")
	if failed.size() < 2: return
	var previous: Dictionary = failed[failed.size() - 2]
	var resolved: Dictionary = failed.back()
	_expect(previous.observation_ref in resolved.source_refs, "actual resolved revision cites the previous failure")
	var descriptor := CONTENT.descriptor("NB_PR_DUTY_1", 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, locale)
	var row := CONTENT.definition("NB_PR_DUTY_1", 1)
	var context := {"node_id":row.node_ids[0], "location_id":"M1_LIBRARY_OUTER", "chapter_id":"PROLOGUE", "event_occurrence_id":ARCHIVE.new_uid(), "conversation_session_id":ARCHIVE.new_uid(), "presentation_token":ARCHIVE.new_uid()}
	var observed := CONTENT.observe(descriptor, context, shown.speaker, shown.text, locale, "displayed")
	_expect(observed.ok, "ordinary stress template validates")
	if not observed.ok: return
	# Synthetic ordinary load, not 2,003 actual player interactions.
	for index in range(2003):
		var observation: Dictionary = observed.observation.duplicate(true)
		observation.presentation_token = ARCHIVE.new_uid()
		archive.entries.append({"entry_uid":ARCHIVE.new_uid(), "source_origin_id":archive.source_origin_id, "sequence":int(archive.next_sequence), "record_class":"authored", "observation":observation, "protection_reasons":[]})
		archive.next_sequence += 1
	var maintained := ARCHIVE.maintain(archive, archive.revision)
	_expect(maintained.ok and not maintained.pruned_uids.is_empty(), "actual note graph is tested after real ordinary pruning")
	if not maintained.ok: return
	archive = maintained.archive
	_expect(archive.entries.filter(func(entry: Dictionary) -> bool: return entry.protection_reasons.is_empty()).size() == 2000, "ordinary quota is independent from protected acquired records")
	_expect(KNOWLEDGE.validate(ledger, archive).ok, "every actual acquired source remains valid after pruning")
	for note in ledger.revisions:
		for reference in [note.observation_ref] + note.source_refs:
			var before := ARCHIVE.resolve(original.meta_progress.dialogue_history, reference)
			var after := ARCHIVE.resolve(archive, reference)
			_expect(before.ok and after.ok, "actual note and cited source survive the quota boundary")
			if before.ok and after.ok:
				_expect(after.entry.observation == before.entry.observation and after.entry.sequence == before.entry.sequence, "pruning preserves source UID, meaning and order")
	for reference in [previous.observation_ref, resolved.observation_ref]:
		var fixed := ARCHIVE.set_reference(archive, "comparison", reference, true, archive.revision)
		_expect(fixed.ok, "actual previous and resolved failure can be compared")
		if fixed.ok: archive = fixed.archive
	state.meta_progress.dialogue_history = archive
	_install(state)
	var committed := GameState.get_snapshot()
	_expect(SaveManager.save_snapshot(SLOT, SESSION.SAVE_POINT, committed, GameState.revision, "NB_ACTUAL_RETENTION_%d" % serial).ok, "pruned acquired graph commits durably")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "pruned actual source graph reloads")
	_expect(StateSnapshotValidator.same_persisted_value(committed, GameState.get_snapshot()), "reload preserves actual revisions, comparison and source references")
	var reloaded := GameState.get_snapshot()
	var query := QUERY.new()
	var scope := {"namespace":"test", "slot":SLOT, "run_id":"actual-source-retention", "source_origin_id":archive.source_origin_id, "branch_id":archive.branch_id, "load_epoch":1}
	var opened := query.open(reloaded.meta_progress.dialogue_history, reloaded.meta_progress.knowledge_entries[KNOWLEDGE.KEY], scope, locale)
	_expect(opened.ok, "actual pruned graph opens for read-only source navigation")
	if not opened.ok: return
	for note in ledger.revisions:
		var key: String = QUERY.reference_key(note.observation_ref)
		var detail := query.detail(key, query.cache_key())
		_expect(detail.ok and detail.epistemic == note.metadata.epistemic_state, "each past revision keeps its own epistemic state")
		var expected: Array = []
		for reference in note.source_refs:
			var target: String = QUERY.reference_key(reference)
			if target != key and target not in expected: expected.append(target)
		_expect(detail.get("sources", []) == expected, "all disclosed source links remain navigable after pruning")
		for target in expected: _expect(query.detail(target, query.cache_key()).ok, "actual source detail survives pruning")
	var comparison := query.comparison(query.cache_key())
	_expect(comparison.ok and comparison.items.map(func(item: Dictionary) -> String: return item.key) == [QUERY.reference_key(previous.observation_ref), QUERY.reference_key(resolved.observation_ref)], "comparison retains exactly the old failure and its resolution")
	var panel := PANEL.new()
	tree.current_scene.add_child(panel)
	_expect(panel.present(query, locale, "clues", 1.0), "actual pruned source graph presents in the common panel")
	panel.show_detail(QUERY.reference_key(resolved.observation_ref))
	var target: String = QUERY.reference_key(previous.observation_ref)
	var link := panel.find_child("NotebookSource_" + target.sha256_text(), true, false) as Button
	_expect(link != null, "resolved actual failure exposes its previous failure button")
	if link != null:
		link.pressed.emit()
		_expect(panel._selected == target and query.detail(target, query.cache_key()).epistemic == previous.metadata.epistemic_state, "source button opens the prior immutable failure, not its resolution")
	panel.queue_free()
	await tree.process_frame
	query.close()
	_expect(GameState.get_snapshot() == committed and _ledger() == ledger, "source navigation never rewrites the acquired ledger or live state")
	retention_routes += 1


func _seed() -> ChapterOneSession:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var state := GameState.get_snapshot()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.loop_state.day_index = 1
	_install(state)
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().ok, "session initializes")
	return session


func _route(locale: String) -> void:
	var session: ChapterOneSession
	for mark in SESSION.MARKS:
		session = _seed()
		_act(session, "mark", mark)
		var first: Dictionary = _latest("CH1_SELF_MARK").duplicate(true)
		_expect(first.metadata.epistemic_state == "hypothesis", "unconfirmed mark remains a hypothesis")
		_act(session, "routine")
		var ledger := _ledger().duplicate(true)
		_expect(session.sleep().ok and _ledger() == ledger, "physical reset preserves mark revision without acquiring anything")
		_act(session, "confirm_mark")
		var confirmed := _latest("CH1_SELF_MARK")
		_expect(confirmed.knowledge_uid == first.knowledge_uid and confirmed.previous_revision_uid == first.revision_uid and confirmed.metadata.epistemic_state == "verified", "A2 verifies the same card through a new revision")
		_expect(_ledger().revisions[0] == first and first.observation_ref in confirmed.source_refs, "verification protects the immutable A1 source")
		_collect(locale)
	_travel(session, "M1_SERVANT_COMMON")
	for owner in ["edgar", "luca", "mara1", "mara2"]:
		_act(session, "read_schedule", owner)
		var unchanged := _ledger().duplicate(true)
		_act(session, "read_schedule", owner)
		_expect(_ledger() == unchanged, "reinspecting unchanged schedule does not acquire a revision: " + owner)
	_act(session, "schedule_window", "after_tea_before_bell")
	_expect(_latest("CH1_LIBRARY_WINDOW").source_refs.size() == 5, "library inference cites the four actually acquired schedules and its own text")
	var inference := _ledger().duplicate(true)
	_act(session, "schedule_window", "after_tea_before_bell")
	_expect(_ledger() == inference, "repeating a confirmed inference does not manufacture another revision")
	_act(session, "routine")
	_travel(session, "M1_LIBRARY_OUTER")
	_act(session, "move", "M1_LIBRARY_INNER")
	_act(session, "inspect_inner", "desk")
	for index in range(3):
		_act(session, "j1_piece", index)
		_act(session, "j1_flip", index)
	_act(session, "j1_restore")
	var first_journal: Dictionary = ARCHIVE.resolve(GameState.get_snapshot().meta_progress.dialogue_history, _latest("CH1_J1").observation_ref).entry
	_expect(first_journal.observation.segments[0].disclosure == "replay_committed" and _latest("CH1_J1").metadata.provenance_state == "unverified", "restored journal is authored text, not a claim about its writer or a viewed dialogue")
	for room in SESSION.CLOCK_ROOMS:
		_travel(session, room)
		_act(session, "rub_clock")
		var card := _latest("CH1_CLOCK_" + String(SESSION.CLOCK_ROOMS[room]).to_upper())
		_expect(card.metadata.lifetime == "persistent", "clock observation is not the expendable physical rubbing")
		var unchanged := _ledger().duplicate(true)
		var rubbed: Array = session.local_state().rubbed.duplicate()
		_act(session, "rub_clock")
		_expect(_ledger() == unchanged and session.local_state().rubbed == rubbed, "repeated rubbing preserves the card and physical item count: " + room)
	_solve_board(session)
	_act(session, "board_check")
	_expect(_latest("CH1_CLOCK_LAYOUT").source_refs.size() == 5, "layout cites four disclosed clock observations")
	var failure_rows: Array = []
	for role in CLOCK.ROLES:
		var roles := CLOCK.SOLUTION.duplicate()
		roles.erase(role)
		_set_clock(session, roles, "0")
		var before_test := _ledger().duplicate(true)
		_act(session, "test_clock")
		_expect(_ledger() == before_test, "weak check does not write a failure note")
		_act(session, "activate_clock", true)
		failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
		var locked_ledger := _ledger().duplicate(true)
		_expect(not session.act("activate_clock", true).ok and _ledger() == locked_ledger, "locked same-day retry cannot manufacture a new failure record")
	for phase in ["-1", "0", "HALF", "unset"]:
		_set_clock(session, CLOCK.SOLUTION, phase)
		_act(session, "activate_clock", true)
		failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
	# A distinct same-diagnosis attempt must not be deduplicated as rereading.
	_set_clock(session, CLOCK.SOLUTION, "0")
	_act(session, "activate_clock", true)
	failure_rows.append(_latest("CH1_CLOCK_FAILURE").duplicate(true))
	for index in range(1, failure_rows.size()):
		_expect(failure_rows[index].knowledge_uid == failure_rows[0].knowledge_uid and failure_rows[index].previous_revision_uid == failure_rows[index - 1].revision_uid, "every actual failure keeps its own immutable attempt")
	_travel(session, "M2_BEDROOM")
	var before_sleep := _ledger().duplicate(true)
	_expect(session.sleep().ok and _ledger() == before_sleep, "sleep keeps all failure records and sources")
	_expect(session.local_state().rubbed.is_empty(), "physical rubbings still reset")
	_act(session, "shortcut")
	_act(session, "phase", "+1")
	_act(session, "activate_clock", true)
	var before_wave := _ledger().duplicate(true)
	var before_wave_state := GameState.get_snapshot()
	var rejecting := RejectingSave.new()
	var rejected := SESSION.new(GameState, rejecting, SLOT)
	_expect(not rejected.act("record_wave").ok and GameState.get_snapshot() == before_wave_state, "failed waveform save rolls back both new revisions and the resolved gameplay flag")
	rejecting.free()
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = SaveManager
	var recovering := SESSION.new(GameState, lost_ack, SLOT)
	_expect(recovering.act("record_wave").ok, "lost acknowledgement confirms the two-note transaction")
	lost_ack.free()
	_expect(_ledger().revision == before_wave.revision + 2, "waveform and resolved failure are committed together")
	var resolved := _latest("CH1_CLOCK_FAILURE")
	_expect(resolved.previous_revision_uid == failure_rows.back().revision_uid and failure_rows.back().observation_ref in resolved.source_refs and _latest("CH1_WAVEFORM").observation_ref in resolved.source_refs, "resolution links previous failure and actual waveform without erasing history")
	var archive: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history
	var wave_observation: Dictionary = ARCHIVE.resolve(archive, _latest("CH1_WAVEFORM").observation_ref).entry.observation
	var resolved_observation: Dictionary = ARCHIVE.resolve(archive, resolved.observation_ref).entry.observation
	_expect(wave_observation.event_occurrence_id == resolved_observation.event_occurrence_id and wave_observation.conversation_session_id == resolved_observation.conversation_session_id and wave_observation.presentation_token != resolved_observation.presentation_token, "B4 notes share one event and writing batch but distinct observation tokens")
	var after_wave := _ledger().duplicate(true)
	_act(session, "record_wave")
	_expect(_ledger() == after_wave, "repeated waveform recording does not duplicate resolution")
	_travel(session, "M1_LIBRARY_OUTER")
	_act(session, "move", "M1_LIBRARY_INNER")
	for index in range(3): _act(session, "wave_rotate")
	_act(session, "restore_j2")
	_expect(_latest("CH1_J2").source_refs.size() == 3, "J2 cites the first page and the recorded waveform")
	for previous in before_wave.revisions:
		_expect(previous in _ledger().revisions, "all old revisions survive success and restoration")
	_collect(locale)
	var saved := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "actual slot round-trip preserves cards and typed source links")


func _persistence_and_legacy(tree: SceneTree) -> void:
	var session := _seed()
	var legacy := GameState.get_snapshot()
	legacy.meta_progress.notebook_persistence_confirmed = true
	legacy.meta_progress.knowledge_entries.chapter_notebook = {"A1": "기존 표식: 작성 시점 미상", "BF": "예전의 마지막 실패 메모"}
	legacy.loop_state.location_id = "M1_SERVANT_COMMON"
	_install(legacy)
	_expect(session.initialize().ok and not GameState.get_snapshot().meta_progress.knowledge_entries.has(KNOWLEDGE.KEY), "old strings do not create invented acquisition histories")
	var before := GameState.get_snapshot()
	var rejecting := RejectingSave.new()
	var failed := SESSION.new(GameState, rejecting, SLOT)
	_expect(not failed.act("read_schedule", "edgar").ok and GameState.get_snapshot() == before, "failure rolls back legacy note, schedule flag, source protection and revision atomically")
	rejecting.free()
	_act(session, "read_schedule", "edgar")
	_expect(_ledger().revision == 1 and _latest("CH1_SELF_MARK").is_empty(), "retry acquires only the new actual document")
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = SaveManager
	var recovering := SESSION.new(GameState, lost_ack, SLOT)
	_expect(recovering.act("read_schedule", "luca").ok, "lost acknowledgement confirms complete note transaction")
	lost_ack.free()
	var committed := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(committed, GameState.get_snapshot()), "confirmed note transaction survives reload")
	var bad := GameState.get_snapshot()
	_expect(not NOTES.write(bad, "J1", "not the authored source", session.history_context(), "ko-KR").ok and bad == GameState.get_snapshot(), "mismatching source cannot write a candidate")
	var unobserved := _latest("CH1_LIBRARY_WINDOW")
	_expect(unobserved.is_empty(), "loading documents does not auto-solve the inference")
	_act(session, "schedule_window", "after_tea_before_bell")
	_expect(_latest("CH1_LIBRARY_WINDOW").source_refs.size() == 3, "inference cites only actually acquired documents, not other catalog entries")
	var view := preload("res://scripts/chapters/chapter_one_controller.gd").new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	var before_read := GameState.get_snapshot()
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_read, "existing notebook consumer never writes acquisition or resolves hypotheses")
	view.queue_free()
	await tree.process_frame


func _set_clock(session: ChapterOneSession, roles: Dictionary, phase: String) -> void:
	var state := GameState.get_snapshot()
	var local := session.local_state(state)
	local.clock_locked = false
	local.signal_generated = false
	local.roles = roles.duplicate()
	local.phase = phase
	state.loop_state.event_local_states.CHAPTER_ONE = local
	state.loop_state.location_id = "M1_GREAT_CLOCK"
	_install(state)


func _solve_board(session: ChapterOneSession) -> void:
	for index in range(4):
		var board := session.local_state().board as Dictionary
		var target: String = CLOCK.SOLUTION[CLOCK.ROLES[index]]
		var other: int = board.pieces.find(target)
		if other != index: _act(session, "board_swap", [index, other])
		for turn in range(4):
			if session.local_state().board.rotations[index] == 0: break
			_act(session, "board_rotate", index)
	_act(session, "board_flip")


func _travel(session: ChapterOneSession, destination: String) -> void:
	var room: String = GameState.get_snapshot().loop_state.location_id
	if room == destination: return
	if room == "M1_LIBRARY_INNER": _act(session, "move", "M1_LIBRARY_OUTER")
	if GameState.get_snapshot().loop_state.location_id != "M1_CENTRAL_HALL": _act(session, "move", "M1_CENTRAL_HALL")
	_act(session, "move", destination)


func _ledger() -> Dictionary:
	return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _latest(id: String) -> Dictionary:
	var result := {}
	for row in _ledger().revisions:
		if row.metadata.knowledge_id == id: result = row
	return result


func _report_tuples() -> void:
	var keys := observed_tuples.keys()
	keys.sort()
	print("NOTEBOOK_NP06_PATH_AUDIT: " + JSON.stringify({"scope":"OBSERVED_RUNTIME_PATHS_NOT_EXHAUSTIVE_ALLOWED_NODE_PRODUCT", "tuple_fields":["producer", "content", "version", "node", "variant", "segment", "locale"], "observed":keys.map(func(key: String) -> Array: return JSON.parse_string(key)), "errors":errors}))


func _collect(locale: String) -> void:
	var state := GameState.get_snapshot()
	runtime_audit.capture(state.meta_progress.dialogue_history)
	_expect(KNOWLEDGE.validate(_ledger(), state.meta_progress.dialogue_history).ok, "complete source graph validates")
	for row in _ledger().revisions:
		var entry: Dictionary = ARCHIVE.resolve(state.meta_progress.dialogue_history, row.observation_ref).entry
		var observation: Dictionary = entry.observation
		_expect(observation.producer_id == "NP06" and observation.entry_kind == "document_segment" and observation.segments[0].disclosure == "replay_committed", "acquired note has explicit production and disclosure owner")
		covered[observation.content_id + ":" + locale] = true
		var version := 2 if observation.content_id.trim_prefix("NB_CH1_NOTE_") in NOTES.MARK_IDS else 1
		var definition := CONTENT.definition(observation.content_id, version)
		_expect(int(observation.content_version) == version and observation.variant_id == definition.action_or_variant and observation.node_id in definition.node_ids, "note uses current producer version and registered node/variant")
		for segment in observation.segments:
			var tuple := JSON.stringify([observation.producer_id, observation.content_id, int(observation.content_version), observation.node_id, observation.variant_id, segment.segment_id, segment.viewed_locale])
			observed_tuples[tuple] = true
			_expect(segment.viewed_locale == locale and segment.segment_id in definition.visible_segment_ids, "actual note segment and capture locale agree with acquisition")
		var read := CONTENT.render_entry(entry, "en-US" if locale == "ko-KR" else "ko-KR")
		_expect(read.ok and not read.entry.fallback, "source exact version is readable in the other locale")
	_expect(GameState.get_snapshot() == state, "reading the revision graph is side-effect free")


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_NOTES_FIXTURE_%d" % serial)).ok, "valid scenario fixture")


func _act(session: ChapterOneSession, action: String, value: Variant = null) -> void:
	var result := session.act(action, value)
	_expect(result.get("ok", false), action + ":" + str(value) + " " + str(result.get("error_ids", [])))


func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)
