extends RefCounted

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const NOTES := preload("res://scripts/systems/journal_four_display_notebook.gd")
const DOCUMENT := preload("res://scripts/systems/journal_four_notebook.gd")
const RULES := preload("res://scripts/systems/journal_four.gd")
const DISPLAY := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const SLOT := "__test_notebook_journal_four_display"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var view: BasementController
var serial := 0
var matrix_cases := 0
var order_surfaces := 0

class ControlledSave extends Node:
	var reject_game := false
	var reject_history := false
	var lose_ack := false
	var attempts := 0
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		attempts += 1
		if (reject_game and transaction.begins_with("CH1_")) or (reject_history and transaction.begins_with("HISTORY_")):
			return {"ok": false, "error_ids": ["ERR_TEST_J4_DISPLAY_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["ERR_TEST_J4_DISPLAY_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	_install(_fixture(0))
	view = VIEW.new()
	view.configure_session(SLOT, "J4")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		_confirmation_matrix(language)
		for mask in [0, 5, 31]: await _confirmation_route(tree, mask)
		_orders()
		_arrange()
		for mask in [0, 3, 31]: _read_route(mask, "known", 0)
		_read_route(31, "known", 1)
		_read_route(31, "missing", 0)
		_read_route(31, "original", 0)
		await _failures(tree)
		_legacy()
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id + ":" + language), "undisplayed ID: " + id + ":" + language)
			for segment in CONTENT.definition(id, 1).visible_segment_ids:
				_expect(segments.has(id + ":" + segment + ":" + language), "undisplayed segment: " + id + ":" + segment + ":" + language)
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": 102, "covered_id_locales": covered.size(), "covered_segment_locales": segments.size(), "confirmation_matrix": matrix_cases, "order_surfaces": order_surfaces,
		"not_covered": ["durable_app_restart_cursor", "shared_notebook_UI", "OS_input"]}


func _fixture(mask: int, hub: bool = false) -> Dictionary:
	var fixture := CHECKPOINTS.new().snapshot_for("E_HUB" if hub else "J4")
	_expect(fixture.ok, "checkpoint fixture")
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.knowledge_entries.chapter_notebook = {}
	for index in range(5):
		var owner: String = RULES.OWNERS[index]
		state.meta_progress.servants[owner].core_event_complete = (mask & (1 << index)) != 0
		state.meta_progress.servants[owner].researcher_record_acquired = (mask & (1 << index)) != 0
	state.loop_state.event_local_states.J4 = {"pages": [], "ordered": false}
	return state


func _context() -> Dictionary:
	return {"chapter_id": "CHAPTER_3", "node_id": "E_HUB", "location_id": "M1_CENTRAL_HALL", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}


func _confirmation_matrix(locale: String) -> void:
	for mask in range(32):
		for count in range(6):
			var state := _fixture(mask, true)
			for index in range(5): state.meta_progress.servants[RULES.OWNERS[index]].researcher_record_acquired = index < count
			var totals := RULES.summary(state)
			var descriptor := NOTES.confirmation(totals)
			var text := DISPLAY.text(NOTES.MODAL_TITLE, locale) + "\n" + DISPLAY.j4_confirmation(totals, locale)
			for label in NOTES.MODAL_LABELS: text += "\n" + DISPLAY.text(label, locale)
			var row := CONTENT.definition(descriptor.content_id, 1)
			var result := CONTENT.observe(descriptor, _context(), row.locales[locale].speaker, text, locale)
			_expect(result.ok, "confirmation matches shown counts, names and time: " + str(mask) + ":" + str(count))
			if not result.ok: continue
			var serialized: Dictionary = JSON.parse_string(JSON.stringify(result.observation))
			var archive: Dictionary = ARCHIVE.append_observation(ARCHIVE.create(), serialized, 0).archive
			var other := "en-US" if locale == "ko-KR" else "ko-KR"
			var replay := CONTENT.render_entry(archive.entries[0], other)
			_expect(replay.ok and not replay.entry.fallback, "confirmation opposite-language replay")
			_expect(descriptor.segments.has("minimum") == not totals.edgar_core_complete, "no unseen minimum-access warning")
			_expect(descriptor.segments.has("no_time") == (mask == 31) and descriptor.segments.has("time") == (mask != 31), "no unseen estimated-time line")
			matrix_cases += 1


func _confirmation_route(tree: SceneTree, mask: int) -> void:
	_install(_fixture(mask, true))
	_present()
	var before := _gameplay()
	_press("J4_CONFIRM")
	_expect(_count("CONFIRM_OPTIONS") == 1 and _count("CONFIRM_SELECT_1") == 0, "opening shows options, not a selection")
	_expect((view._modal_body.get_child(4) as Button).disabled, "existing confirmation delay preserved")
	_expect(_gameplay() == before, "opening confirmation does not change progress")
	view._cancel_prologue_modal()
	_expect(_count("CONFIRM_SELECT_0") == 1 and _gameplay() == before, "Escape records explicit cancellation without progress")
	_press("J4_CONFIRM")
	await tree.create_timer(0.6).timeout
	_expect(not (view._modal_body.get_child(4) as Button).disabled, "confirmation becomes available after delay")
	view._modal_body.get_child(4).pressed.emit()
	_expect(_count("CONFIRM_SELECT_1") == 1 and view.session.known("j4_confirmed"), "only explicit selection closes investigation")
	_drain()
	_expect(view.session.stage() == "J4", "confirmation does not restore the journal")
	_collect()


func _orders() -> void:
	var orders := NOTES.all_orders()
	_expect(orders.size() == 65, "all unique ordered prefixes")
	for pages in orders:
		var state := _fixture(0)
		state.loop_state.event_local_states.J4.pages = pages
		_install(state)
		var before := _gameplay()
		_present()
		var key := NOTES.order_key(pages)
		_expect(_count(key) == 1 and _gameplay() == before, "displaying order neither adds pages nor solves it")
		var count: int = _archive().entries.size()
		view._render_room()
		_present()
		_expect(_archive().entries.size() == count, "same-scope redraw does not duplicate order")
		_collect()
		order_surfaces += 1


func _arrange() -> void:
	_install(_fixture(0))
	_present()
	_press("J4_ORDER")
	_expect(_count("STATUS_ORDER") == 1, "meaningful wrong-order result disclosed")
	view._render_room()
	_present()
	_expect(_count("STATUS_ORDER") == 1, "redraw does not repeat rejection")
	_press("J4_ORDER")
	_expect(_count("STATUS_ORDER") == 2, "new rejected attempt has a new presentation token")
	_press("J4_CLEAR")
	_drain()
	for id in RULES.ORDER:
		_expect(_count("PAGE_" + id.to_upper()) == 0, "page label alone is not arrangement feedback")
		_press("J4_PAGE_" + id)
		_drain()
	_press("J4_ORDER")
	_drain()
	_expect(RULES.progress(GameState.get_snapshot()).ordered and GameState.get_snapshot().meta_progress.journal_stage == 3, "ordering is not reading")
	_collect()


func _read_route(mask: int, mode: String, outcome: int) -> void:
	var state := _fixture(mask)
	state.loop_state.event_local_states.J4 = {"pages": RULES.ORDER.duplicate(), "ordered": true}
	for owner in RULES.OWNERS:
		if not state.meta_progress.servants[owner].researcher_record_acquired: continue
		var key := "REC_" + String(owner).to_upper()
		if mode == "missing": continue
		if mode == "original":
			state.meta_progress.knowledge_entries.chapter_notebook[key] = RULES.PAGES.promise + "\nOld {original_text} <literal> " + owner
			continue
		var ids: Array = DOCUMENT.QUOTES[owner].keys()
		var id: String = ids[outcome if owner == "mara1" else 0]
		var row := CONTENT.definition(id, 1)
		state.meta_progress.knowledge_entries.chapter_notebook[key] = row.locales["ko-KR"].body
		var context := _context()
		context.node_id = row.node_ids[0]
		_expect(EVENT_NOTES.write(state, id, row.locales["ko-KR"].body, context, TranslationServer.get_locale()).ok, "research record fixture")
	_install(state)
	_present()
	var servants: Dictionary = state.meta_progress.servants.duplicate(true)
	_press("J4_READ")
	_expect(_count("READ_BODY") == 1 and _count("READ_LAST") == 0, "first visible paragraph cannot disclose later lines")
	var committed := GameState.get_snapshot()
	var saved_feedback: Dictionary = committed.loop_state.event_local_states.CHAPTER_ONE.last_feedback
	_expect(not saved_feedback.notebook_feedback.is_empty(), "selected display descriptors persist with committed feedback")
	_drain()
	_expect(_count("READ_FULL") == (1 if mask == 31 else 0), "full passage visible only for all five")
	_expect(_count("READ_LAST") == 3, "last section disclosed only through three actual advances")
	for entry in _archive().entries:
		if entry.get("record_class") != "authored" or not entry.observation.content_id.begins_with(NOTES.PREFIX + "READ_"): continue
		_expect(entry.observation.node_id == "J4" and entry.observation.location_id == state.loop_state.location_id, "J4 dialogue retains pre-transition context")
		for segment in entry.observation.segments: _expect(segment.disclosure == "displayed", "dialogue is not a document acquisition")
		if entry.observation.content_id.ends_with("_ORIGINAL"):
			var replay := CONTENT.render_entry(entry, "en-US")
			_expect(replay.entry.fallback and replay.entry.segments[0].text == entry.observation.segments[0].captured_text, "old quote remains literal, even when matching another known line")
	if mask == 0 or mask == 3:
		_expect(view.session.stage() == "E3_4M" and _count("SCREEN_MINIMUM") == 1, "zero or partial records retain minimum-access route")
		_press("EDGAR_MINIMUM")
		_expect(_count("MINIMUM") == 1, "minimum first paragraph only")
		_drain()
		_expect(_count("MINIMUM") == 3 and view.session.stage() == "E5", "three minimum paragraphs reach evening")
	_expect(GameState.get_snapshot().meta_progress.servants == servants, "display and minimum access grant no relationship or record")
	_collect()
	var before := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "all displayed evidence survives JSON reload")
	var reloaded: Dictionary = GameState.get_snapshot().loop_state.event_local_states.CHAPTER_ONE.last_feedback
	_expect(StateSnapshotValidator.same_persisted_value(before.loop_state.event_local_states.CHAPTER_ONE.last_feedback, reloaded), "saved feedback descriptors remain frozen")


func _failures(tree: SceneTree) -> void:
	var saver := ControlledSave.new()
	_install(_fixture(0, true))
	_present()
	view.session._save = saver
	saver.reject_history = true
	var before := GameState.get_snapshot()
	_press("J4_CONFIRM")
	var request: Dictionary = view._recorded_modal_request
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before, "failed modal history cannot confirm")
	await tree.create_timer(0.6).timeout
	_expect(GameState.get_snapshot() == before, "delay cannot confirm or silently retry failed disclosure")
	saver.reject_history = false
	saver.lose_ack = true
	view._recorded_choice_pressed(request, 1)
	_drain()
	_expect(_count("CONFIRM_OPTIONS") == 1 and _count("CONFIRM_SELECT_1") == 1 and view.session.stage() == "J4", "explicit retry and lost acknowledgment commit once")
	_collect()
	_install(_fixture(0, true))
	_present()
	_press("J4_CONFIRM")
	request = view._recorded_modal_request
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load while old confirmation exists")
	before = GameState.get_snapshot()
	view._recorded_choice_pressed(request, 1)
	_expect(GameState.get_snapshot() == before, "old modal cannot change new load scope")
	_install(_fixture(0))
	view.session._save = saver
	saver.lose_ack = false
	saver.reject_history = true
	before = GameState.get_snapshot()
	_expect(not view._notebook_surface_allowed(), "surface failure is reported")
	var attempts := saver.attempts
	_press("J4_PAGE_promise")
	_expect(saver.attempts == attempts and GameState.get_snapshot() == before, "blocked surface neither retries nor arranges")
	saver.reject_history = false
	saver.lose_ack = true
	_press("NOTEBOOK_SURFACE_RETRY")
	_expect(_count("SCREEN_GUIDE") == 1, "explicit surface retry is idempotent")
	saver.lose_ack = false
	saver.reject_game = true
	before = GameState.get_snapshot()
	_press("J4_PAGE_promise")
	_expect(GameState.get_snapshot() == before and _count("PAGE_PROMISE") == 0, "failed gameplay commit cannot disclose success")
	saver.reject_game = false
	_press("J4_PAGE_promise")
	_drain()
	_expect(_count("PAGE_PROMISE") == 1, "successful explicit gameplay retry records once")
	_collect()
	view.session._save = SaveManager
	saver.free()


func _legacy() -> void:
	var state := _fixture(31)
	state.meta_progress.journal_stage = 4
	state.meta_progress.knowledge_entries.J4_complete = true
	state.meta_progress.knowledge_entries.chapter_notebook.J4 = "legacy original"
	_install(state)
	_present()
	view._open_notebook()
	view._close_modal()
	_expect(_count("READ_BODY") == 0 and _ledger().revisions.is_empty(), "old flags and notebook opening cannot invent J4 reading or acquisition")


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	var token := "NB_J4_DISPLAY_FIXTURE_%d" % serial
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName(token)).ok, "fixture install")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", GameState.get_snapshot(), GameState.revision, token).ok, "fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(), "actual surface capture")
	view.set_process(false)


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null, "missing J4 button: " + id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(60):
		if not view._dialogue_active:
			_present()
			return
		view._advance_dialogue()
	_expect(false, "J4 dialogue blocked")
	view._dismiss_dialogue_for_test()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history
func _ledger() -> Dictionary: return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
func _gameplay() -> Dictionary:
	var state := GameState.get_snapshot()
	state.meta_progress.erase("dialogue_history")
	return state


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == NOTES.PREFIX + key: count += 1
	return count


func _collect() -> void:
	for entry in _archive().entries:
		_expect(entry.get("record_class") == "authored", "J4 route cannot silently write unmapped history")
		if entry.get("record_class") != "authored": continue
		var observed: Dictionary = entry.observation
		if not observed.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observed.chapter_id == "CHAPTER_3" and observed.node_id in ["J4", "E_HUB", "E3_4M"], "actual pre-transition chapter and node")
		for segment in observed.segments:
			covered[observed.content_id + ":" + segment.viewed_locale] = true
			segments[observed.content_id + ":" + segment.segment_id + ":" + segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry, "en-US" if TranslationServer.get_locale().begins_with("ko") else "ko-KR").ok, "opposite-language replay")
	_expect(KNOWLEDGE.validate(_ledger(), _archive()).ok, "source references and ledger remain valid")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("J4_DISPLAY_ASSERT: ", message)
