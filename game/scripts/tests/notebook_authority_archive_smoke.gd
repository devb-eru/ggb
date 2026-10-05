extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_relationship_label_assertions.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const EDGAR := preload("res://scripts/systems/edgar_notebook.gd")
const MARA2 := preload("res://scripts/systems/mara2_notebook.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")
const SLOT := "__test_notebook_authority_archive"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var ready := {}
var entry_states := {}
var edgar_assignment: Dictionary = {}
var mara2_alignment: Dictionary = {}
var mara2_cells: Dictionary = {}
var matrix_cases := 0
var outcomes := 0

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
	errors.append_array(PUBLIC_LABELS.catalog(["edgar","mara2"]))
	_seed("edgar")
	view = VIEW.new()
	view.configure_session(SLOT, "E3_4")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		print("AUTHORITY_ARCHIVE_PHASE: ", locale, " edgar route")
		_edgar_route()
		print("AUTHORITY_ARCHIVE_PHASE: ", locale, " mara2 route")
		_mara2_route()
		print("AUTHORITY_ARCHIVE_PHASE: ", locale, " rule matrix")
		_rule_matrix()
		for actor in ["edgar", "mara2"]:
			for bond in [0, 2, 4]:
				for alert in [0, 4]:
					for index in range(2):
						print("AUTHORITY_ARCHIVE_PHASE: ", locale, " ", actor, " outcome ", bond, "/", alert, "/", index)
						_outcome(actor, bond, alert, index)
			print("AUTHORITY_ARCHIVE_PHASE: ", locale, " ", actor, " failures")
			_failures(actor)
			print("AUTHORITY_ARCHIVE_PHASE: ", locale, " ", actor, " legacy")
			_legacy(actor)
		for id in diagnostic.content_ids:
			if not String(id).begins_with(EDGAR.PREFIX) and not String(id).begins_with(MARA2.PREFIX): continue
			_expect(covered.has(id + ":" + locale), "unexecuted authority/archive ID: " + id + ":" + locale)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + locale), "undisplayed authority/archive segment: " + id + ":" + segment + ":" + locale)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": 148, "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "outcomes": outcomes, "matrix_cases": matrix_cases,
		"not_covered": ["NP15_minimum_access_and_settlement", "durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _edgar_route() -> void:
	_seed("edgar")
	_present()
	_expect(_count("NB_EDGAR_SCREEN_ENTRY") == 1 and _count("NB_EDGAR_SCREEN_LOG_CONSENT") == 0, "entry cannot expose hidden audit documents")
	_press("EDGAR_MACHINE")
	_present()
	entry_states.edgar = GameState.get_snapshot()
	_expect(EDGAR.RULES.progress(entry_states.edgar).order.is_empty(), "visible documents do not arrange chronology")
	for key in ["vacancy", "protocol", "extension", "consent"]:
		_press("EDGAR_LOG_" + key)
		_drain()
	_press("EDGAR_AUDIT")
	_press("EDGAR_AUDIT")
	_expect(_count("NB_EDGAR_STATUS_AUDIT_ORDER") == 2, "distinct chronology attempts retain separate observations")
	_press("EDGAR_CLEAR")
	_drain()
	for key in EDGAR.RULES.ORDER:
		_press("EDGAR_LOG_" + key)
		_drain()
	_press("EDGAR_AUDIT")
	_expect(_count("NB_EDGAR_SCREEN_FUNCTION_CHOICE") == 0, "audit result covers the next function board")
	_drain()
	edgar_assignment = GameState.get_snapshot()
	_press("EDGAR_OWNER_PROTECTION")
	view._cancel_prologue_modal()
	_expect(EDGAR.RULES.progress(GameState.get_snapshot()).owners.is_empty(), "owner modal Esc is a deferral")
	_press("EDGAR_VALIDATE")
	_expect(_count("NB_EDGAR_WRONG_PROTECTION") == 1 and _count("NB_EDGAR_WRONG_CHOICE") == 0, "only the first contradiction is disclosed")
	_drain()
	_edgar_owner("PROTECTION", "SYSTEM")
	_edgar_owner("CHOICE", "CUSTODIAN")
	_press("EDGAR_VALIDATE")
	_drain()
	_expect(EDGAR.RULES.progress(GameState.get_snapshot()).owners == {"PROTECTION": "SYSTEM"}, "validation preserves the correct card only")
	_edgar_owner("SURVEILLANCE", "SUBJECT")
	_edgar_owner("MEMORY", "CUSTODIAN")
	_edgar_owner("CHOICE", "SYSTEM")
	_press("EDGAR_VALIDATE")
	_drain()
	for function in EDGAR.RULES.OWNERS: _edgar_owner(function, EDGAR.RULES.OWNERS[function])
	_reload("partial authority assignments")
	_press("EDGAR_VALIDATE")
	_drain()
	ready.edgar = GameState.get_snapshot()
	_expect(not EDGAR.RULES.progress(ready.edgar).confessed and _ledger().revisions.is_empty(), "authority puzzle alone does not grant research record")
	_collect()


func _mara2_route() -> void:
	_seed("mara2")
	_present()
	_press("MARA2_FORWARD")
	_present()
	_press("MARA2_FORWARD")
	_present()
	entry_states.mara2 = GameState.get_snapshot()
	_expect(MARA2.RULES.progress(entry_states.mara2).sources.is_empty(), "visible signatures do not identify their owners")
	_expect(_count("NB_MARA2_SCREEN_PORTRAIT_A") == 0 and _count("NB_MARA2_BACKUP_EDGAR") == 0, "later marks and backups stay undisclosed")
	_press("MARA2_SOURCE_AEDGAR")
	view._cancel_prologue_modal()
	_mara2_source("A", "EDGAR", "MARA1")
	_expect(_count("NB_MARA2_STATUS_SOURCE_MISMATCH") == 1 and MARA2.RULES.progress(GameState.get_snapshot()).sources.is_empty(), "wrong owner cannot identify the signal")
	for portrait in MARA2.RULES.PORTRAITS:
		for owner in MARA2.RULES.OWNERS: _mara2_source(portrait, owner, owner)
	mara2_alignment = GameState.get_snapshot()
	for portrait in ["A", "B", "C"]:
		_press("MARA2_ORDER_" + portrait)
		_drain()
	_press("MARA2_OVERLAY")
	_expect(_count("NB_MARA2_STATUS_OVERLAY_ORDER") == 1, "wrong degradation sequence is recorded without reset")
	_press("MARA2_CLEAR")
	_drain()
	for portrait in MARA2.RULES.ORDER:
		_press("MARA2_ORDER_" + portrait)
		_drain()
	_press("MARA2_OVERLAY")
	_expect(_count("NB_MARA2_STATUS_OVERLAY_START") == 1, "missing start reference is not an inferred solution")
	_press("MARA2_START_A")
	view._cancel_prologue_modal()
	_mara2_align("A", "start", 1)
	_press("MARA2_OVERLAY")
	_expect(_count("NB_MARA2_STATUS_OVERLAY_OUTLINE") == 1, "missing outline reference remains explicit")
	for portrait in MARA2.RULES.PORTRAITS:
		for kind in ["start", "outline"]: _mara2_align(portrait, kind, MARA2.RULES.PORTRAITS[portrait][kind])
	_reload("source and alignment evidence")
	_press("MARA2_OVERLAY")
	_expect(_count("NB_MARA2_SCREEN_OVERLAY") == 0, "overlay result does not reveal the covered doorway board")
	_drain()
	_press("ARCHIVE_ENTER")
	_present()
	_expect(_count("NB_MARA2_SCREEN_CELL_3_MISSING") == 1 and _count("NB_MARA2_SCREEN_CELL_3_ARC") == 0, "missing cell cannot reveal its future repair")
	_press("MARA2_CELL_2")
	view._cancel_prologue_modal()
	for owner in MARA2.RULES.BACKUPS:
		_press("MARA2_BACKUP_" + owner)
		if owner == "EDGAR":
			var hidden := ARCHIVE.make_reference(_entry("NB_MARA2_BACKUP_EDGAR"), "line_01")
			hidden.segment_id = "line_02"
			_expect(not ARCHIVE.resolve(_archive(), hidden).ok, "backup's unshown original-reference line cannot resolve")
		_drain()
	mara2_cells = GameState.get_snapshot()
	_press("MARA2_CHECKSUM")
	_drain()
	var old_count := _entry("NB_MARA2_CHECKSUM_COUNT")
	var old_render := CONTENT.render_entry(old_count, "en-US")
	for glyph in ["호", "선", "점"]:
		for index in MARA2.RULES.GAPS: _mara2_cell(index, glyph)
	_press("MARA2_CHECKSUM")
	_drain()
	_expect(not MARA2.RULES.progress(GameState.get_snapshot()).solved, "wrong checksum remains retryable")
	for index in MARA2.RULES.GAPS: _mara2_cell(index, MARA2.RULES.CHECKSUM[index])
	_reload("checksum assignment and observations")
	_press("MARA2_CHECKSUM")
	_expect(_count("NB_MARA2_CHECKSUM_SOLVED") == 0, "match count does not disclose the next success line")
	_drain()
	_expect(CONTENT.render_entry(old_count, "en-US") == old_render, "later checksum success cannot rewrite the earlier count")
	ready.mara2 = GameState.get_snapshot()
	_expect(not view.session.known("mara2_archive_index_known") and _ledger().revisions.is_empty(), "puzzle alone does not complete the relation or identify the archive index")
	_collect()


func _outcome(actor: String, bond: int, alert: int, index: int) -> void:
	var fixture: Dictionary = ready[actor].duplicate(true)
	fixture.meta_progress.servants[actor].bond = bond
	fixture.meta_progress.servants[actor].alert = alert
	_install(fixture)
	_present()
	var prefix := "NB_" + actor.to_upper() + "_"
	_press(actor.to_upper() + "_CONFESS")
	var entry := _entry(prefix + "CONFESS")
	var hidden := ARCHIVE.make_reference(entry, "line_01")
	hidden.segment_id = "line_04" if actor == "edgar" else "line_03"
	_expect(not ARCHIVE.resolve(_archive(), hidden).ok, "future confession paragraph remains unavailable")
	_expect(_count(prefix + "CONFESS_HIGH") == 0 and _count(prefix + "CONFESS_ALERT") == 0, "first paragraph cannot disclose conditional response")
	_drain()
	_expect(_count(prefix + "CONFESS_HIGH") == (1 if bond >= 4 else 0), "only the actual high-bond response is observed")
	_expect(_count(prefix + "CONFESS_MID") == (1 if bond >= 2 and bond < 4 else 0), "only the actual middle-bond response is observed")
	_expect(_count(prefix + "CONFESS_ALERT") == (1 if alert >= 4 else 0), "alert response is independent")
	var confession := _archive().duplicate(true)
	var before := GameState.get_snapshot()
	_press(actor.to_upper() + "_CHOICE")
	var request := view._recorded_modal_request.duplicate(true)
	view._cancel_prologue_modal()
	var after := GameState.get_snapshot()
	_expect(_defer_history_unchanged(before, after, request), "deferral appends exactly its prompt and cancel without rewriting prior observations")
	after.meta_progress.dialogue_history = before.meta_progress.dialogue_history.duplicate(true)
	_expect(STATE_ASSERTIONS.same_gameplay(before, after, "modal") and _ledger().revisions.is_empty(), "last choice deferral changes only its completed cursor, not the relation or research record")
	if bond == 0 and alert == 0 and index == 0:
		_expect(STATE_ASSERTIONS.mutation_guards(before, after, "modal"), "deferral rejects gameplay and cursor mutations")
	_press(actor.to_upper() + "_CHOICE")
	view._modal_body.get_child(4 + index).pressed.emit()
	var outcome: String = (["responsibility_recorded", "authority_returned"] if actor == "edgar" else ["merged", "separated"])[index]
	var direct: bool = index == 1 if actor == "edgar" else index == 0
	_expect(_count(prefix + "RECORD") == 1 and _ledger().revisions.size() == 1, "record and relationship commit once")
	_drain()
	after = GameState.get_snapshot()
	var servant: Dictionary = after.meta_progress.servants[actor]
	_expect(servant.bond == clampi(bond + (2 if direct else 1), 0, 5) and servant.alert == clampi(alert + (1 if direct else -1), 0, 5), "original relation deltas remain exact")
	_expect(servant.core_event_complete and servant.researcher_record_acquired, "original completion flags retained")
	var note: Dictionary = _ledger().revisions.back()
	_expect(note.metadata.knowledge_id == "REC_" + actor.to_upper() and note.source_refs.size() >= 10, "record cites already-displayed evidence and itself")
	for reference in note.source_refs:
		var resolved := ARCHIVE.resolve(_archive(), reference)
		_expect(resolved.ok, "record source resolves")
		if resolved.ok:
			_expect(not String(resolved.entry.observation.content_id).begins_with(prefix + "CHOOSE_"), "future result is not cited at record commit")
			_expect("knowledge_source:" + note.revision_uid in resolved.entry.protection_reasons, "cited source gains the exact research revision protection")
	_expect(not view.session.act(actor + "_choose", outcome).ok and GameState.get_snapshot() == after, "relation reward cannot be applied twice")
	view._open_notebook()
	view._close_modal()
	_expect(GameState.get_snapshot() == after, "research rereading is read-only")
	_reload("completed research record")
	_collect()
	var committed_entries := {}
	for observed in confession.entries:
		if observed.get("record_class") == "authored" and String(observed.observation.content_id).begins_with(prefix + "CONFESS"):
			var found := _entry_uid(observed.entry_uid)
			_expect(found.observation == observed.observation and found.sequence == observed.sequence, "acquisition protects the source without rewriting its observation or order")
			committed_entries[observed.entry_uid] = found.duplicate(true)
	var changed := after.duplicate(true)
	changed.meta_progress.servants[actor].bond = 5 - bond
	changed.meta_progress.servants[actor].alert = 5 - alert
	_install(changed)
	var frozen := GameState.get_snapshot()
	for observed in confession.entries:
		if observed.get("record_class") == "authored" and String(observed.observation.content_id).begins_with(prefix + "CONFESS"):
			var found := _entry_uid(observed.entry_uid)
			_expect(found == committed_entries[observed.entry_uid] and CONTENT.render_entry(found, "en-US") == CONTENT.render_entry(observed, "en-US"), "changed relation cannot rewrite a historical response or its committed protection")
	_expect(GameState.get_snapshot() == frozen, "replay cannot mutate current relationship")
	outcomes += 1


func _rule_matrix() -> void:
	for code in range(625):
		var number := code
		var owners := {}
		var seen := {}
		var valid := true
		for function in EDGAR.RULES.OWNERS:
			var token := number % 5
			number = int(number / 5)
			if token == 0: continue
			var owner: String = EDGAR.RULES.OWNERS.values()[token - 1]
			if seen.has(owner): valid = false
			seen[owner] = true
			owners[function] = owner
		if not valid: continue
		var source := edgar_assignment.duplicate(true)
		source.loop_state.event_local_states.E3_4.owners = owners
		var result := EDGAR.RULES.apply(source, "validate", null)
		var expected := {}
		for function in owners:
			if owners[function] == EDGAR.RULES.OWNERS[function]: expected[function] = owners[function]
		_expect(result.ok and result.state.loop_state.event_local_states.E3_4.owners == expected, "all 209 reachable layouts preserve exactly correct assignments")
		_check_feedback(result, EDGAR.paragraphs(result.feedback_keys), "E3_4", "H0_CLOCK_MACHINE")
		matrix_cases += 1
	for code in range(64):
		var source := mara2_cells.duplicate(true)
		var number := code
		for index in MARA2.RULES.GAPS:
			var token := number % 4
			number = int(number / 4)
			if token == 0: source.loop_state.event_local_states.E3_5.cells.erase(str(index))
			else: source.loop_state.event_local_states.E3_5.cells[str(index)] = ["선", "점", "호"][token - 1]
		var result := MARA2.RULES.apply(source, "checksum", null)
		_expect(result.ok and result.feedback_variables.matches >= 9 and result.feedback_variables.matches <= 12, "checksum uses only the actually matched cells")
		_check_feedback(result, MARA2.paragraphs(result.feedback_keys, result.feedback_variables), "E3_5", "H0_PERSONALITY_ARCHIVE")
		matrix_cases += 1


func _check_feedback(result: Dictionary, descriptors: Array, event: String, room: String) -> void:
	var language := "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	var other := "ko-KR" if language == "en-US" else "en-US"
	var parts: PackedStringArray = DISPLAY.text(result.text, language).split("\n", false)
	var opposite: PackedStringArray = DISPLAY.text(result.text, other).split("\n", false)
	_expect(parts.size() == descriptors.size(), "one descriptor per actual feedback paragraph")
	for index in range(descriptors.size()):
		var row := CONTENT.definition(descriptors[index].content_id, 1)
		var context := {"chapter_id": "CHAPTER_3", "node_id": event, "location_id": room, "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
		var observed := CONTENT.observe(descriptors[index], context, row.locales[language].speaker, parts[index], language)
		_expect(observed.ok, "rule matrix matches the actual source feedback")
		if not observed.ok: continue
		var archive := ARCHIVE.create()
		archive = ARCHIVE.append_observation(archive, observed.observation, 0).archive
		var rendered := CONTENT.render_entry(archive.entries[0], other)
		_expect(rendered.ok and not rendered.entry.fallback and rendered.entry.segments[0].text == opposite[index], "rule matrix replays the exact frozen opposite-language paragraph")


func _failures(actor: String) -> void:
	var controlled := ControlledSave.new()
	controlled.delegate = SaveManager
	_install(ready[actor])
	_present()
	_press(actor.to_upper() + "_CONFESS")
	_drain()
	view.session._save = controlled
	for choice_index in [1, 2]:
		_install(ready[actor])
		_present()
		_press(actor.to_upper() + "_CONFESS")
		_drain()
		view.session._save = controlled
		errors.append_array(preload("res://scripts/tests/notebook_relationship_choice_retry.gd").run(view, controlled, actor, choice_index))
	_install(ready[actor])
	_present()
	_press(actor.to_upper() + "_CONFESS")
	_drain()
	view.session._save = controlled
	controlled.reject_game = true
	var before := GameState.get_snapshot()
	var outcome := "responsibility_recorded" if actor == "edgar" else "merged"
	var result: Dictionary = view.session.act(actor + "_choose", outcome)
	_expect(not result.ok and GameState.get_snapshot() == before, "failed record save leaves all game/archive/ledger state unchanged")
	controlled.reject_game = false
	controlled.lose_ack = true
	result = view.session.act(actor + "_choose", outcome)
	_expect(result.ok and _ledger().revisions.size() == 1, "lost acknowledgement recovers the committed record once")
	view._render_room()
	view._feedback(result)
	_drain()
	_collect()
	_install(edgar_assignment if actor == "edgar" else entry_states.mara2)
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	_press("EDGAR_OWNER_PROTECTION" if actor == "edgar" else "MARA2_SOURCE_AEDGAR")
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before, "failed options display cannot perform the puzzle action")
	controlled.reject_history = false
	controlled.lose_ack = true
	view._recorded_choice_pressed(request, 1)
	_drain()
	_expect(_count("NB_EDGAR_OWNER_SELECT_1" if actor == "edgar" else "NB_MARA2_SOURCE_SELECT_1") == 1, "selection retry after acknowledgement loss writes exactly once")
	_press("EDGAR_OWNER_MEMORY" if actor == "edgar" else "MARA2_SOURCE_AMARA1")
	request = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load while input modal is open")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 2)
	_expect(GameState.get_snapshot() == before, "old modal cannot write after load epoch changes")
	view._cancel_prologue_modal()
	_collect()
	_install(entry_states.edgar if actor == "edgar" else mara2_alignment)
	_present()
	view.session._save = controlled
	controlled.lose_ack = false
	controlled.reject_history = true
	before = GameState.get_snapshot()
	var button := "EDGAR_AUDIT" if actor == "edgar" else "MARA2_OVERLAY"
	_press(button)
	_expect(GameState.get_snapshot() == before, "failed status display fabricates no observation")
	var attempts := controlled.attempts
	_press(button)
	_expect(controlled.attempts == attempts, "redraw and repeated action do not retry a failed disk write")
	controlled.reject_history = false
	controlled.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("NB_EDGAR_STATUS_AUDIT_ORDER" if actor == "edgar" else "NB_MARA2_STATUS_OVERLAY_ORDER") == 1, "explicit status retry retains the original occurrence")
	_collect()
	view.session._save = SaveManager
	controlled.free()


func _legacy(actor: String) -> void:
	_install(ready[actor])
	var state := GameState.get_snapshot()
	state.loop_state.event_local_states["E3_4" if actor == "edgar" else "E3_5"].confessed = true
	_install(state)
	_expect(view.session.act(actor + "_choose", "authority_returned" if actor == "edgar" else "separated").ok, "old completion fixture")
	state = GameState.get_snapshot()
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_install(state)
	_present()
	view._open_notebook()
	view._close_modal()
	_expect(_ledger().revisions.is_empty() and _count("NB_" + actor.to_upper() + "_RECORD") == 0, "old completion does not fabricate a new research acquisition")
	_collect()


func _edgar_owner(function: String, owner: String) -> void:
	_press("EDGAR_OWNER_" + function)
	view._modal_body.get_child(4 + EDGAR.RULES.OWNERS.values().find(owner)).pressed.emit()
	_drain()


func _mara2_source(portrait: String, owner: String, candidate: String) -> void:
	_press("MARA2_SOURCE_" + portrait + owner)
	view._modal_body.get_child(4 + MARA2.RULES.OWNERS.find(candidate)).pressed.emit()
	if candidate != owner:
		var before := GameState.get_snapshot()
		var cursor := STATE_ASSERTIONS.PRESENTATION.read(before)
		_expect(view._modal_active and cursor.get("phase") == "selection_pending", "wrong attribution retains the explicit pending selection")
		_expect(not view._notebook_surface_allowed() and GameState.get_snapshot() == before, "covered world is not recorded while attribution modal remains open")
		_expect(_count("NB_MARA2_STATUS_SOURCE_MISMATCH") == 1, "wrong-attribution feedback was actually observed before returning to the modal")
		view._cancel_prologue_modal()
		_expect(not view._modal_active and MARA2.RULES.progress(GameState.get_snapshot()).sources.is_empty(), "explicit dismissal permits another attempt without assigning an owner")
	_drain()


func _defer_history_unchanged(before: Dictionary, after: Dictionary, request: Dictionary) -> bool:
	var old: Dictionary = before.meta_progress.dialogue_history
	var history: Dictionary = after.meta_progress.dialogue_history.duplicate(true)
	var ids := [request.history_context.notebook_content.content_id, request.row.choices[request.row.cancel_index].content_id]
	if history.entries.size() != old.entries.size() + ids.size(): return false
	if not StateSnapshotValidator.same_persisted_value(old.entries, history.entries.slice(0, old.entries.size())): return false
	for index in range(ids.size()):
		var entry: Dictionary = history.entries[old.entries.size() + index]
		if entry.get("record_class") != "authored": return false
		var observed: Dictionary = entry.observation
		if observed.content_id != ids[index] or observed.event_occurrence_id != request.history_context.event_occurrence_id or observed.conversation_session_id != request.history_context.conversation_session_id: return false
		var rendered := CONTENT.render_entry(entry, request.locale)
		if not rendered.ok or rendered.entry.get("fallback", true): return false
	history.entries = old.entries.duplicate(true)
	history.revision -= ids.size()
	history.next_sequence -= ids.size()
	return StateSnapshotValidator.same_persisted_value(old, history)


func _mara2_align(portrait: String, kind: String, point: int) -> void:
	_press("MARA2_" + kind.to_upper() + "_" + portrait)
	view._modal_body.get_child(4 + point).pressed.emit()
	_drain()


func _mara2_cell(index: int, glyph: String) -> void:
	_press("MARA2_CELL_%d" % index)
	view._modal_body.get_child(4 + ["선", "점", "호"].find(glyph)).pressed.emit()
	_drain()


func _seed(actor: String) -> void:
	var fixture := CHECKPOINTS.new().snapshot_for("E_HUB")
	_expect(fixture.ok, "relationship hub fixture")
	var state: Dictionary = fixture.snapshot
	state.loop_state.location_id = "M1_GREAT_CLOCK" if actor == "edgar" else "M1_NORTH_ARCHIVE_HALL"
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.servants[actor].bond = 0
	state.meta_progress.servants[actor].alert = 0
	_install(state)


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_AUTHORITY_FIXTURE_%d" % serial)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, "NB_AUTHORITY_FIXTURE_%d" % serial).ok, "fixture save")
	if view != null: view._render_room()


func _reload(label: String) -> void:
	var before := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, label + " JSON load")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before), label + " exact saved state")
	view._render_room()
	_present()


func _present() -> void:
	var allowed := view._notebook_surface_allowed()
	if not allowed:
		print("AUTHORITY_SURFACE_BLOCKED: stage=", view.session.stage(), " blocked=", view._interaction_blocked(), " dialogue=", view._dialogue_active, " modal=", view._modal_active, " notebook=", view._notebook_is_open(), " retry=", view._notebook_surfaces.retry_required)
		for request in view._notebook_surfaces.requests.values():
			if not request.recorded: print("AUTHORITY_PENDING_SURFACE: ", request.id, " attempted=", request.attempted)
	_expect(allowed, "actual surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing authority/archive button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(20):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "authority/archive dialogue remains blocked")
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
	for entry in _archive().entries:
		if entry.get("record_class") != "authored":
			_expect(false, "authority/archive route cannot silently produce unmapped history")
			continue
		var observed: Dictionary = entry.observation
		if observed.producer_id not in ["NP13", "NP14"]: continue
		if String(observed.content_id).ends_with("_SCREEN_COMPLETE"):
			_expect(PUBLIC_LABELS.live(entry), "current completion has readable labels and exact version 2 observation")
		_expect(observed.chapter_id == "CHAPTER_3" and observed.event_id == ("E3_4" if observed.producer_id == "NP13" else "E3_5"), "actual relationship event and chapter captured")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		var rendered := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "opposite-language replay uses the same meaning version")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "research ledger and sources are valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("AUTHORITY_ARCHIVE_ASSERT: ", message)
