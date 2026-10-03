extends RefCounted

const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const NOTES := preload("res://scripts/systems/chapter_one_notes.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const SLOT := "__test_notebook_self_mark"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": ["ERR_TEST_MARK_SAVE"]}

class LostAcknowledgement extends Node:
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result: Dictionary = delegate.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_MARK_ACK"]} if result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return delegate.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var before := GameState.get_snapshot()
	var language := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for type in SESSION.MARKS:
			await _route(tree, type, locale)
	_test_versions()
	_test_failed_save()
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(language)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_install(before)
	_expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "suite restores caller state")
	print("NOTEBOOK_SELF_MARK_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _seed() -> ChapterOneSession:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var state := GameState.get_snapshot()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.loop_state.day_index = 1
	_install(state)
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().ok, "mark scenario initializes through actual session")
	return session


func _route(tree: SceneTree, type: String, locale: String) -> void:
	var session := _seed()
	_expect(session.act("mark", type).ok, "actual mark transaction: " + type + ":" + locale)
	var state := GameState.get_snapshot()
	var revision: Dictionary = state.meta_progress.knowledge_entries[KNOWLEDGE.KEY].revisions[0]
	var original := ARCHIVE.resolve(state.meta_progress.dialogue_history, revision.observation_ref)
	_expect(original.ok and original.entry.observation.content_version == 2, "new event pins authored visual version two")
	_expect(revision.metadata.epistemic_state == "hypothesis" and not state.meta_progress.notebook_persistence_confirmed, "visual creation does not verify persistence")
	_expect(state.meta_progress.knowledge_entries.self_authored_mark == {"type": type, "text": SESSION.MARKS[type], "day": 1}, "existing puzzle mark inputs and their values are unchanged")
	var entry: Dictionary = original.entry
	var key := QUERY.reference_key(revision.observation_ref)
	for ui_locale in ["ko-KR", "en-US"]:
		var query = _query(state, ui_locale)
		var detail: Dictionary = query.detail(key, query.cache_key())
		var visual: Dictionary = query.visual(key, query.cache_key()).material
		_expect(detail.has_visual and detail.lifetime_label.is_empty() and detail.memory_notice.is_empty(), "A1 media does not disclose A2 rules")
		_expect(visual.version == 2 and not visual.description.is_empty(), "authored shape has a non-colour text description")
		_expect(not visual.description.contains("F0") and not visual.description.contains("SUBJECT"), "no future authority label in early visual description")
		if type == "sentence":
			_expect(visual.text_runs[0].text == ("Tomorrow morning," if locale == "en-US" else "내일 아침,"), "sentence picture keeps writing locale while surrounding UI localizes")
			_expect(detail.text.contains("Tomorrow morning," if ui_locale == "en-US" else "내일 아침,"), "translated record remains readable independently of picture locale")
		elif type == "house_glyph":
			_expect(visual.paths.size() == 7 and visual.paths[5].points[1][0] < visual.paths[5].points[0][0], "three windows, pointed roof and left-leaning door retained")
			_expect(visual.description.contains("pressed harder" if ui_locale == "en-US" else "힘이 실려") and visual.paths[5].width > visual.paths[1].width, "authored pressure appears in description and relative stroke width")
		else:
			_expect(visual.circles.size() == 3 and visual.paths[0].dashed and visual.circles.back().filled, "ink contacts and final spreading dot are distinct from paper edge")
		_expect(query.investigation_page(0, query.cache_key()).items.any(func(item: Dictionary) -> bool: return item.key == key), "own written mark is in current-investigation materials")
		if type == "house_glyph": await _panel(tree, state, query, key, ui_locale)
	_expect(GameState.get_snapshot() == state, "viewing written mark cannot set gameplay or ledger flags")
	_expect(session.act("routine").ok and session.sleep().ok, "normal reset proceeds without rewriting mark")
	var after_sleep := GameState.get_snapshot()
	_expect(ARCHIVE.resolve(after_sleep.meta_progress.dialogue_history, revision.observation_ref).entry == entry, "sleep preserves exact original visual observation")
	_expect(session.act("confirm_mark").ok, "A2 remains an explicit gameplay action")
	var verified := GameState.get_snapshot()
	var ledger: Dictionary = verified.meta_progress.knowledge_entries[KNOWLEDGE.KEY]
	_expect(ledger.revisions.back().metadata.epistemic_state == "verified" and revision.observation_ref in ledger.revisions.back().source_refs, "A2 links original authored mark, not reconstructed present data")
	var query = _query(verified, locale, "F0_E")
	_expect(query.detail(key, query.cache_key()).previous and query.visual(key, query.cache_key()).material == VISUALS.material(entry, "body", locale), "later self-authority context preserves earlier visual without solving it")
	_expect(query.investigation_page(0, query.cache_key()).items.any(func(item: Dictionary) -> bool: return item.key == key), "F0-E relevance includes exact version-two original")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "actual slot reload succeeds")
	_expect(StateSnapshotValidator.same_persisted_value(verified, GameState.get_snapshot()), "slot round trip retains original locale, shape version and revision chain")
	var reloaded = _query(GameState.get_snapshot(), locale)
	_expect(reloaded.visual(key, reloaded.cache_key()).material == VISUALS.material(entry, "body", locale), "reload uses same archived diagram")


func _panel(tree: SceneTree, state: Dictionary, query, key: String, locale: String) -> void:
	var fixture := state.duplicate(true)
	var archive: Dictionary = fixture.meta_progress.dialogue_history
	archive = ARCHIVE.set_reference(archive, "comparison", JSON.parse_string(key), true, int(archive.revision)).archive
	var row := CONTENT.definition("NB_CH1_NOTE_B4", 1)
	var shown := CONTENT.presentation(CONTENT.descriptor("NB_CH1_NOTE_B4", 1, {"body": {}}), locale)
	var observed := CONTENT.observe(CONTENT.descriptor("NB_CH1_NOTE_B4", 1, {"body": {}}), _context("B4"), shown.speaker, shown.text, locale, "replay_committed")
	_expect(observed.ok and row.knowledge.knowledge_id == "CH1_WAVEFORM", "comparison fixture is an explicitly acquired second document")
	var acquired := KNOWLEDGE.acquire(fixture.meta_progress.knowledge_entries[KNOWLEDGE.KEY], archive, observed.observation, ARCHIVE.new_uid())
	_expect(acquired.ok, "comparison fixture stores waveform separately from mark")
	fixture.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = acquired.ledger
	var second := ARCHIVE.make_reference(acquired.archive.entries.back(), "body")
	fixture.meta_progress.dialogue_history = ARCHIVE.set_reference(acquired.archive, "comparison", second, true, int(acquired.archive.revision)).archive
	query = _query(fixture, locale)
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, locale, "clues", 2.0)
	panel.show_detail(key)
	await tree.process_frame
	_expect(panel._detail.find_child("NotebookVisualPreview", true, false) != null, "200 percent detail shows mark preview")
	panel._open_visual(key)
	panel._visual.find_child("NotebookVisualIn", true, false).pressed.emit()
	panel._visual.find_child("NotebookVisualRight", true, false).pressed.emit()
	var position: Dictionary = panel._visual._canvas.view.duplicate()
	_expect(position.zoom > 1 and position.x > 0, "explicit zoom and pan operate on mark")
	panel._visual._canvas.grab_focus()
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	panel._visual._canvas._gui_input(left)
	_expect(panel._visual._canvas.view.x < position.x, "focused keyboard pan works on self-written material")
	panel._close_visual()
	_expect(panel.select_pair(0, key) and panel.select_pair(1, QUERY.reference_key(second)), "mark and acquired waveform can be selected as A/B")
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	await tree.process_frame
	_expect(panel._pair_panels[0].find_child("NotebookVisualPreview", true, false) != null and panel._pair_panels[1].find_child("NotebookVisualPreview", true, false) != null, "both comparison sides retain their own visuals")
	panel._open_visual(key)
	panel._visual.find_child("NotebookVisualReset", true, false).pressed.emit()
	_expect(panel._visual._canvas.view == {"zoom": 1.0, "x": 0.0, "y": 0.0}, "view reset never reexecutes A1")
	panel._close_visual()
	_expect(panel._comparison_mode and panel._pair[0] == key and panel._pair[1] == QUERY.reference_key(second), "enlargement returns to same comparison pair")
	_expect(panel._close.get_global_rect().end.y <= panel.get_global_rect().end.y, "close control stays within 720p at 200 percent")
	_expect(GameState.get_snapshot() == state, "comparison leaves live writer, puzzle draft and memory rules unchanged")
	panel.queue_free()
	await tree.process_frame


func _test_versions() -> void:
	for type in SESSION.MARKS:
		var id := "NB_CH1_NOTE_A1_" + String(type).to_upper()
		var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
		var shown := CONTENT.presentation(descriptor, "ko-KR")
		var observed := CONTENT.observe(descriptor, _context(), shown.speaker, shown.text, "ko-KR", "replay_committed")
		_expect(observed.ok, "old mark semantic version remains registered")
		var entry := {"record_class": "authored", "observation": observed.observation}
		_expect(not VISUALS.supports(entry, "body") and VISUALS.material(entry, "body", "en-US").is_empty(), "old text-only marks do not gain invented pressure or spread")
		_expect(CONTENT.render_segment(entry, "body", "ko-KR").entry.text.ends_with(shown.text), "old original text is unchanged")
		descriptor = CONTENT.descriptor(id, 2, {"body": {}})
		shown = CONTENT.presentation(descriptor, "ko-KR")
		observed = CONTENT.observe(descriptor, _context(), shown.speaker, shown.text, "ko-KR", "replay_committed")
		_expect(observed.ok, "new version has its own authored disclosure")
		entry.observation = observed.observation.duplicate(true)
		_expect(not VISUALS.supports(entry, "back"), "unobserved segment cannot reveal another face")
		entry.observation.content_version = 999
		_expect(not VISUALS.supports(entry, "body"), "unknown future version cannot borrow latest image")
		entry.observation = observed.observation.duplicate(true)
		entry.observation.speaker_id = "EDGAR"
		_expect(VISUALS.material(entry, "body", "ko-KR").is_empty(), "identity mismatch never generates a visual")
		_expect(not CONTENT.observe(descriptor, _context("A2"), shown.speaker, shown.text, "ko-KR", "replay_committed").ok, "reopening after sleep cannot masquerade as new writing")


func _test_failed_save() -> void:
	var session := _seed()
	var before := GameState.get_snapshot()
	var rejecting := RejectingSave.new()
	var failed := SESSION.new(GameState, rejecting, SLOT)
	_expect(not failed.act("mark", "house_glyph").ok and GameState.get_snapshot() == before, "failed mark save publishes neither art evidence nor gameplay mark")
	rejecting.free()
	var lost_ack := LostAcknowledgement.new()
	lost_ack.delegate = SaveManager
	var recovering := SESSION.new(GameState, lost_ack, SLOT)
	_expect(recovering.act("mark", "house_glyph").ok, "lost acknowledgement reconciles original transaction")
	lost_ack.free()
	var committed := GameState.get_snapshot()
	_expect(committed.meta_progress.knowledge_entries[KNOWLEDGE.KEY].revisions.size() == 1, "reconciliation creates exactly one version-two mark")
	_expect(not session.act("mark", "ink_corner").ok and GameState.get_snapshot() == committed, "retry cannot change type or duplicate an already written mark")
	var candidate := before.duplicate(true)
	_expect(not EVENT_NOTES.write(candidate, "NB_CH1_NOTE_A1_HOUSE_GLYPH", NOTES.mark_text("house_glyph"), _context(), "ko-KR", 1).ok and candidate == before, "version-two text cannot be mislabeled as historical version one")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(committed, GameState.get_snapshot()), "reconciled diagram survives real disk reload")


func _query(state: Dictionary, locale: String, node: String = "A1"):
	var archive: Dictionary = state.meta_progress.dialogue_history
	var query := QUERY.new()
	var scope := {"namespace": "test", "slot": SLOT, "run_id": "self-mark", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}
	_expect(query.open(archive, state.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), scope, locale, {}, node).ok, "self mark read scope opens")
	return query


func _context(node: String = "A1") -> Dictionary:
	return {"node_id": node, "location_id": "M2_BEDROOM", "chapter_id": "CHAPTER_1", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_SELF_MARK_%d" % serial)).ok, "self mark fixture installs")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: errors.append(message)
