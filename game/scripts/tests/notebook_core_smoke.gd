extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_public_puzzle_labels.gd")

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/core_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const BOARD := preload("res://scripts/chapters/core_overlay_board.gd")
const SLOT := "__test_notebook_core"
var errors := PackedStringArray()
var fixtures := {}
var covered := {}
var covered_segments := {}
var matrices := 0
var view: BasementController
var serial := 0
var anonymous_reviews := 0

class ControlledSave extends Node:
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	var attempts := 0
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		attempts += 1
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok":false, "error_ids":["ERR_TEST_CORE_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok":false, "error_ids":["ERR_TEST_CORE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_install(_fixture("F0_A"))
	view = VIEW.new()
	view.configure_session(SLOT, "F0_A")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		print("CORE_PHASE: ", language, " catalog")
		_catalog_matrix(language)
		_network_matrix(language)
		if not errors.is_empty(): break
		_network()
		print("CORE_PHASE: ", language, " samples")
		_samples()
		_overlay()
		print("CORE_PHASE: ", language, " roles")
		_roles(false)
		var anonymous_source := GameState.get_snapshot()
		_roles(true)
		print("CORE_PHASE: ", language, " authority")
		for index in range(3): _authority(NOTES.E.MARKS.keys()[index], NOTES.INTENTS[index])
		for mark in NOTES.E.MARKS:
			var retained := anonymous_source
			if mark != anonymous_source.meta_progress.knowledge_entries.self_authored_mark.type:
				_roles(false, mark)
				retained = GameState.get_snapshot()
			for intent in NOTES.INTENTS: _authority(mark, intent, retained)
		_original()
		print("CORE_PHASE: ", language, " failures")
		_failures()
		_legacy()
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + language), "unvisited actual ID: " + id + ":" + language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(covered_segments.has(id + ":" + segment + ":" + language), "unvisited actual segment: " + id + ":" + segment)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_expect(anonymous_reviews == 24, "both locales preserve all three actual mark histories across all nine mark-intent combinations")
	print("CORE_ANONYMOUS_REVIEWS: ", anonymous_reviews)
	print("CORE_COVERAGE: actual IDs/locales=", covered.size(), " segments/locales=", covered_segments.size(), " catalog/rule cases=", matrices)
	return {"ok":errors.is_empty(), "errors":errors, "actual_id_locales":covered.size(), "matrix_cases":matrices, "anonymous_reviews":anonymous_reviews,
		"not_covered":["durable_app_restart_cursor", "unified_notebook_UI", "visual_comparison_renderer", "OS_input"]}


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


func _context() -> Dictionary:
	return {"chapter_id":"CHAPTER_4", "node_id":"F0_A", "location_id":"H0_CORE_PATH", "event_occurrence_id":ARCHIVE.new_uid(), "conversation_session_id":ARCHIVE.new_uid(), "presentation_token":ARCHIVE.new_uid()}


func _catalog_matrix(locale: String) -> void:
	var count := 0
	for id in CONTENT.diagnostics().content_ids:
		if not String(id).begins_with(NOTES.PREFIX): continue
		var version := PUBLIC_LABELS.LABELS.version(id)
		var row := CONTENT.definition(id, version)
		var segments := {}
		for segment in row.visible_segment_ids:
			segments[segment] = {}
			for key in row.variables[segment]:
				var type: String = row.variables[segment][key]
				segments[segment][key] = 2 if type == "int" else ("literal old mark" if type == "string" else row.enums[type.trim_prefix("enum:")]["ko-KR"].keys()[0])
		var descriptor := CONTENT.descriptor(id, version, segments)
		var shown := CONTENT.presentation(descriptor, locale)
		_expect(shown.ok, "catalog presentation " + id)
		if not shown.ok: continue
		var context := _context()
		context.node_id = row.node_ids[0]
		var observed := CONTENT.observe(descriptor, context, shown.speaker, shown.text, locale, "replay_committed" if row.disclosure_owner == "event_note_commit" else "displayed")
		_expect(observed.ok, "catalog observation " + id)
		if observed.ok:
			var round_trip: Dictionary = JSON.parse_string(JSON.stringify(observed.observation))
			var appended := ARCHIVE.append_observation(ARCHIVE.create(), round_trip, 0)
			_expect(appended.ok, "serialized observation " + id)
			if appended.ok: _expect(CONTENT.render_entry(appended.archive.entries[0], "en-US" if locale == "ko-KR" else "ko-KR").ok, "opposite locale " + id)
		count += 1
		matrices += 1
	_expect(count == 122, "all frozen core rows")
	for layer in NOTES.C.LAYERS:
		var serialized_geometry: Dictionary = JSON.parse_string(JSON.stringify(BOARD.visual_manifest(layer)))
		_expect(CONTENT.definition(NOTES.PREFIX + "SCREEN_C_LAYER_" + layer, 1).visual == serialized_geometry, "frozen geometry matches actual renderer " + layer)
	for type in NOTES.E.MARKS:
		for order in NOTES.orders():
			var sequence := []
			for index in order: sequence.append(NOTES.E.MARKS[type][index])
			var descriptor := NOTES.mark_surface({"type":type,"text":NOTES.MARK_SOURCE.MARKS[type]}, sequence, locale)
			_expect(CONTENT.presentation(descriptor, locale).ok, "all mark permutations " + type + str(order))
			matrices += 1


func _network_matrix(locale: String) -> void:
	for room in NOTES.A.ROOMS:
		for target in NOTES.A.ROOMS:
			for direction in range(4):
				for end in range(4):
					var descriptor := NOTES.descriptor("A_SIGNAL_PATH", {"room":room,"target_room":target,"direction":str(direction),"target_direction":str(end)})
					var expected := "%s %s → %s %s" % [NOTES.DISPLAY.direction(direction,locale),NOTES.DISPLAY.room_name(room,locale),NOTES.DISPLAY.direction(end,locale),NOTES.DISPLAY.room_name(target,locale)]
					_expect(CONTENT.presentation(descriptor,locale).text == expected, "arbitrary path translates typed values")
					matrices += 1


func _network() -> void:
	_install(_fixture("F0_A"))
	_present()
	var before: int = _archive().entries.size()
	view._render_room()
	_present()
	_expect(_archive().entries.size() == before, "same variable surfaces are not duplicated")
	_expect(_count("A_NOTES") == 0, "notes not acquired by showing the board")
	_press("F0A_NOTES")
	_expect(_count("A_NOTES") == 1, "first visible notes paragraph only")
	_drain()
	_press("F0A_SIGNAL")
	_drain()
	_expect(not view.session.known("f0_room_feedback_loop_solved"), "wrong wiring retryable")
	for pair in [[0,2],[1,3],[2,3]]:
		_press("F0A_TILE_%d" % pair[0])
		_press("F0A_TILE_%d" % pair[1])
	for slot in range(3):
		for turn in range(slot + 1): _press("F0A_ROTATE_%d" % slot)
	_press("F0A_SIGNAL")
	_drain()
	_expect(view.session.stage() == "F0_B", "network solved with existing answer")
	_collect()


func _samples() -> void:
	_install(_fixture("F0_B"))
	_present()
	for room in NOTES.B.ROOMS: _expect(_count("B_SAMPLE_" + room.to_upper() + "_0") == 0, "label does not disclose trace")
	for room in NOTES.B.ROOMS:
		_press("F0B_" + room + "_1")
		_drain()
		_press("F0B_SEND_" + room)
		_drain()
	_expect(_count("B_HINT") == 1, "third failure hint appears once")
	for room in NOTES.B.ROOMS:
		_press("F0B_" + room + "_0")
		_drain()
		_press("F0B_SEND_" + room)
		_drain()
	_expect(view.session.stage() == "F0_C", "verified samples do not grant subject authority")
	_expect(not view.session.known("subject_authority_restored"), "sample channels are not permission")
	_collect()


func _overlay() -> void:
	_install(_fixture("F0_C"))
	_present()
	var original: Array = _archive().entries.duplicate(true)
	_press("F0C_VERIFY")
	_drain()
	for layer in NOTES.C.LAYERS: _press(layer + "_ANCHOR")
	_press("F0C_VERIFY")
	_drain()
	for turn in range(2): _press("B4_ROTATE")
	_press("F0C_VERIFY")
	_drain()
	_press("C5_FLIP")
	for turn in range(3): _press("C5_ROTATE")
	_press("B4_OPACITY")
	_press("F0C_VERIFY")
	_drain()
	_expect(_count("C_INSPECT_PATH") == 0, "revealing a point is not investigating it")
	_press("F0C_AUTH")
	_expect(_count("STATUS_C_SEQUENCE") == 1, "wrong investigation order")
	for point in NOTES.C.INVESTIGATION:
		_press("F0C_" + point)
		_drain()
	_expect(view.session.stage() == "F0_D", "overlay answer and order retained")
	for index in range(original.size()):
		_expect(_archive().entries[index] == original[index], "changing live layer cannot rewrite earlier diagram observation")
	_collect()


func _roles(complete: bool, mark: String = "") -> void:
	var state := _fixture("F0_D")
	if not mark.is_empty(): state.meta_progress.knowledge_entries.self_authored_mark = {"type":mark, "text":NOTES.MARK_SOURCE.MARKS[mark], "day":1}
	state.meta_progress.servants.mara2.researcher_record_acquired = complete
	_install(state)
	_present()
	var servants: Dictionary = GameState.get_snapshot().meta_progress.servants.duplicate(true)
	for index in range(5):
		_press("F0D_CARD_" + NOTES.D.RECORDS[index])
		_drain()
		_press("F0D_SLOT_%d" % (index if index == 0 else (index % 4) + 1))
	_expect(_count("D_ANONYMOUS") == (0 if complete else 1), "anonymous index conditional")
	for attempt in range(3):
		_press("F0D_VERIFY")
		_drain()
		_expect(_count("D_HINT_0") == maxi(0, attempt), "hints disclosed only after second comparison")
	_press("F0D_LOCK_1")
	_expect(_count("STATUS_D_LOCK") == 1, "invalid lock does not grant correct role")
	_press("F0D_LOCK_0")
	_drain()
	for index in range(1,5):
		_press("F0D_CARD_" + NOTES.D.RECORDS[index])
		_drain()
		_press("F0D_SLOT_%d" % index)
	_press("F0D_VERIFY")
	_drain()
	_expect(view.session.stage() == "F0_E", "roles solved without relationship requirement")
	_expect(GameState.get_snapshot().meta_progress.servants == servants, "anonymous index is not a researcher reward")
	var before := GameState.get_snapshot()
	_expect(_count("D_INDEX_RECORD") == (0 if complete else 1), "anonymous record acquisition follows actual resident inspection exactly once")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before), "role records and anonymous identity survive real JSON load")
	if not complete: _anonymous_review()
	_collect()


func _authority(type: String, intent: String, source: Dictionary = {}) -> void:
	var state: Dictionary = _fixture("F0_E") if source.is_empty() else source.duplicate(true)
	if source.is_empty(): state.meta_progress.knowledge_entries.self_authored_mark = {"type":type,"text":NOTES.MARK_SOURCE.MARKS[type],"day":1}
	else: _expect(state.meta_progress.knowledge_entries.self_authored_mark.type == type, "retained A1 mark is never changed after its actual role observations")
	_install(state)
	if not source.is_empty():
		_expect(view._restore_presentation(), "retained completed role screen restores using the real presentation path")
		_expect(view._presentation_scope == view._recorded_choice_scope(), "retained completed cursor binds the current controller load scope")
	_present()
	var ending: Dictionary = state.ending_run.duplicate(true)
	var servants: Dictionary = state.meta_progress.servants.duplicate(true)
	_press("F0E_PAST")
	_expect(_count("STATUS_E_PAST") == 1, "wrong past sequence captured")
	for index in [1,2,0]: _press("F0E_PIECE_%d" % index)
	_press("F0E_PAST")
	_drain()
	if not source.is_empty():
		_expect(NOTES.E.progress(GameState.get_snapshot()).past_verified, "retained mark pieces actually verify before current-author choices")
		print("CORE_AUTHORITY_RETAINED_PAST: ", JSON.stringify({"type":type, "intent":intent, "past_verified":NOTES.E.progress(GameState.get_snapshot()).past_verified}))
	for owner in ["father","system","servant"]: _press("F0E_AUTHOR_" + owner)
	_expect(_count("STATUS_E_AUTHOR") == 3 and _count("E_AUTHOR") == 0, "rejected authors cannot grant authority")
	_press("F0E_AUTHOR_subject")
	_drain()
	_expect(_count("E_AUTHOR_RECORD") == 1 and _count("E_INTENT_SELECT_0") == 0, "author record is not intent selection")
	_expect(GameState.get_snapshot().ending_run == ending, "authority is not final choice")
	_press("F0E_INTENT_" + intent)
	_drain()
	_expect(view.session.stage() == "F1", "each provisional intent merges into F1")
	_expect(GameState.get_snapshot().ending_run == ending and GameState.get_snapshot().meta_progress.servants == servants, "private intent cannot choose ending or alter relationships")
	_expect(_count("E_INTENT_" + intent.to_upper() + "_RECORD") == 1, "selected intent document acquired once")
	for other in NOTES.INTENTS:
		if other != intent: _expect(_count("E_INTENT_" + other.to_upper()) == 0, "unselected reaction not disclosed")
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok, "completed authority reload")
	_expect(GameState.get_snapshot().ending_run == ending, "reload cannot finalize intent")
	if not source.is_empty():
		for original in source.meta_progress.dialogue_history.entries:
			if original.get("record_class") != "authored": continue
			var found := {}
			for current in _archive().entries:
				if current.entry_uid == original.entry_uid: found = current; break
			_expect(not found.is_empty() and found.observation == original.observation and found.sequence == original.sequence, "authority and intent cannot rewrite earlier role or anonymous observations")
		_anonymous_review()
	var before := GameState.get_snapshot()
	for entry in _archive().entries: CONTENT.render_entry(entry,"en-US")
	_expect(GameState.get_snapshot() == before, "notebook replay does not solve puzzles")
	_collect()


func _anonymous_review() -> void:
	var snapshot := GameState.get_snapshot()
	var archive: Dictionary = snapshot.meta_progress.dialogue_history
	var ledger: Dictionary = snapshot.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
	var records: Array = ledger.revisions.filter(func(note: Dictionary) -> bool: return note.metadata.get("knowledge_id") == "ANON_PURPLE_RESIDENT_INDEX")
	_expect(records.size() == 1, "actual anonymous inspection creates one anonymous knowledge revision")
	if records.size() != 1: return
	var revision: Dictionary = records[0]
	var resolved := ARCHIVE.resolve(archive, revision.observation_ref)
	_expect(resolved.ok, "anonymous observation reference resolves after progression")
	if not resolved.ok: return
	_expect(resolved.entry.observation.content_id == "NB_CORE_D_INDEX_RECORD", "anonymous identity is not reattributed to a known researcher")
	for reference in revision.source_refs:
		var cited := ARCHIVE.resolve(archive, reference)
		_expect(cited.ok and not String(cited.get("entry", {}).get("observation", {}).get("content_id", "")).begins_with("NB_MARA2_"), "anonymous record cites no undisclosed Mara 2 research source")
	var query := QUERY.new()
	var scope := {"namespace":"test", "slot":SLOT, "run_id":"anonymous-core-review", "source_origin_id":archive.source_origin_id, "branch_id":archive.branch_id, "load_epoch":1}
	var opened := query.open(archive, ledger, scope, TranslationServer.get_locale())
	_expect(opened.ok, "actual anonymous archive opens in read model")
	if opened.ok:
		var key: String = QUERY.reference_key(revision.observation_ref)
		_expect(key in _people_keys(query, "unidentified"), "actual anonymous record remains in unidentified people material")
		_expect(key not in _people_keys(query, "MARA2"), "actual anonymous record never enters Mara 2's identified material")
	query.close()
	_expect(GameState.get_snapshot() == snapshot, "anonymous browsing does not award relationships or change intent")
	anonymous_reviews += 1


func _people_keys(query: RefCounted, person: String) -> Array:
	var keys := []
	var first: Dictionary = query.page({"tab":"people", "people":[person]}, 0, query.cache_key())
	_expect(first.ok, "anonymous review person page opens")
	if not first.ok: return keys
	for index in range(first.pages):
		var page: Dictionary = first if index == 0 else query.page({"tab":"people", "people":[person]}, index, query.cache_key())
		_expect(page.ok, "anonymous review scans every person page")
		if page.ok:
			for item in page.items: keys.append(item.key)
	return keys


func _original() -> void:
	var state := _fixture("F0_E")
	state.meta_progress.knowledge_entries.self_authored_mark = {"type":"sentence","text":"An old literal quotation","day":1}
	_install(state)
	_present()
	_expect(_count("SCREEN_E_MARK_ORIGINAL") == 1, "unknown old mark stays original-only")
	var entry: Dictionary = _archive().entries.filter(func(item): return item.observation.content_id == NOTES.PREFIX + "SCREEN_E_MARK_ORIGINAL")[0]
	var shown := CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR")
	_expect(shown.ok and str(shown).contains("An old literal quotation"), "original quote preserved across locale")
	_collect()


func _failures() -> void:
	_install(_fixture("F0_A"))
	var saver := ControlledSave.new()
	view.session._save = saver
	saver.reject_history = true
	var before := GameState.get_snapshot()
	_expect(not view._notebook_surface_allowed(), "surface save failure visible")
	var attempts := saver.attempts
	_press("F0A_TILE_0")
	_expect(saver.attempts == attempts and GameState.get_snapshot() == before, "failed surface prevents action and auto retry")
	saver.reject_history = false
	saver.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("SCREEN_A_GUIDE") == 1, "lost acknowledgement reconciles once")
	saver.lose_ack = false
	saver.reject_game = true
	before = GameState.get_snapshot()
	_press("F0A_NOTES")
	_expect(GameState.get_snapshot() == before and _count("A_NOTES") == 0, "failed action does not disclose notes")
	saver.reject_game = false
	_press("F0A_NOTES")
	_drain()
	_collect()
	var state := _fixture("F0_E")
	state.loop_state.event_local_states.F0_E = {"sequence":NOTES.E.MARKS.sentence.duplicate(),"past_verified":true,"current_verified":false}
	_install(state)
	_present()
	view.session._save = saver
	saver.reject_game = true
	_press("F0E_AUTHOR_subject")
	_expect(_count("E_AUTHOR_SELECT_2") == 1 and _count("E_AUTHOR_RECORD") == 0 and not view.session.known("subject_authority_restored"), "selection survives game failure but authority document does not")
	saver.reject_game = false
	_press("F0E_AUTHOR_subject")
	_drain()
	_expect(_count("E_AUTHOR_SELECT_2") == 1 and _count("E_AUTHOR_RECORD") == 1, "explicit retry acquires atomically without duplicate choice")
	var generation := view._notebook_surfaces.generation
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok, "load changes input scope")
	before = GameState.get_snapshot()
	view._core_choice_pressed(generation,"INTENT",0,"stale","ko-KR","f0e_intent","reality")
	_expect(GameState.get_snapshot() == before, "stale pre-load callback cannot choose intent")
	view.session._save = SaveManager
	saver.free()


func _legacy() -> void:
	var state := _fixture("F0_E")
	state.meta_progress.knowledge_entries.subject_authority_restored = true
	state.meta_progress.knowledge_entries.f0_provisional_intent = "stay"
	_install(state)
	_present()
	_expect(_count("E_AUTHOR_RECORD") == 0 and _count("E_INTENT_STAY_RECORD") == 0, "old flags never invent acquisition")


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	var token := "NB_CORE_FIXTURE_%d" % serial
	_expect(StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(token)).ok,"fixture install")
	_expect(SaveManager.save_snapshot(SLOT,"SAVE_BROKEN_RESET_COMPLETE",GameState.get_snapshot(),GameState.revision,token).ok,"fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual core surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing core button " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(60):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false,"core dialogue blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: count += 1
	return count


func _collect() -> void:
	errors.append_array(PUBLIC_LABELS.screen_errors(view))
	for entry in _archive().entries:
		errors.append_array(PUBLIC_LABELS.live_errors(entry))
		_expect(entry.get("record_class") == "authored","core cannot silently write unmapped history")
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_4" and observation.node_id.begins_with("F0_"),"actual core source context")
		for segment in observation.segments:
			covered[observation.content_id + ":" + segment.viewed_locale] = true
			covered_segments[observation.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry,"en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR").ok,"actual history replay")
	var ledger: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY,KNOWLEDGE.create())
	_expect(KNOWLEDGE.validate(ledger,_archive()).ok,"ledger source references valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("CORE_ASSERT: ",message)
