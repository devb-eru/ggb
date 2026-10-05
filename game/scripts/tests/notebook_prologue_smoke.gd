extends RefCounted

const VIEW := preload("res://scenes/prologue/prologue.tscn")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const SLOT := "__test_notebook_prologue"
var errors := PackedStringArray()
var covered := {}
var required_tuples := {}
var observed_tuples := {}
var unmapped_tuples := {}
var catalog_hashes := {}
const PRODUCERS := ["NP01", "NP02", "NP03"]

class FailedSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_id": "TEST_PROLOGUE_SAVE"}
	func confirm_snapshot_commit(_slot: String, _transaction: String) -> Dictionary:
		return {"ok": false}


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var diagnostics := CONTENT.diagnostics()
	if not diagnostics.ok: return {"ok": false, "errors": diagnostics.error_ids}
	_prepare_tuple_audit()
	var ids: Array = diagnostics.content_ids.filter(func(id: String) -> bool: return id.begins_with("NB_PR_") or id.begins_with("NB_NOTE_P_"))
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		await _route(tree, language)
		for id in ids: _expect(covered.has(id + ":" + language), "unexecuted authored prologue path: " + id + ":" + language)
	await _partial_choice_and_retry(tree)
	var missing: Array = []
	for key in required_tuples:
		if not observed_tuples.has(key): missing.append(JSON.parse_string(key))
	_expect(missing.is_empty(), "all prologue producer node/variant/segment/locale tuples executed")
	_expect(unmapped_tuples.is_empty(), "no unregistered live prologue producer tuple")
	var observed := observed_tuples.keys()
	observed.sort()
	print("NOTEBOOK_PROLOGUE_BRANCH_AUDIT: " + JSON.stringify({"scope":"NP01_NP02_NP03_CONTROLLER_DISPLAY_AND_COMMIT_NOT_OS_INPUT", "catalog_sha256":catalog_hashes, "required_count":required_tuples.size(), "observed_count":observed_tuples.size(), "not_covered":missing, "unmapped":unmapped_tuples.keys(), "tuple_fields":["producer", "content", "version", "node", "variant", "segment", "locale"], "observed":observed.map(func(key: String) -> Array: return JSON.parse_string(key)), "errors":errors}))
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_ids": ids.size(), "covered_id_locales": covered.size(), "producer_paths": ["NP01", "NP02", "NP03"], "other_paths": "NOT_COVERED"}


func _prepare_tuple_audit() -> void:
	# Catalog membership defines coverage even when a content ID is renamed.
	for path in CONTENT.CATALOGS:
		var raw := FileAccess.get_file_as_string(path)
		var catalog: Dictionary = JSON.parse_string(raw)
		for id in catalog.contents:
			for version in catalog.contents[id]:
				var row: Dictionary = catalog.contents[id][version]
				if row.producer_id not in PRODUCERS: continue
				catalog_hashes[path] = raw.sha256_text()
				for node in row.node_ids:
					for segment in row.visible_segment_ids:
						for locale in row.locales:
							var key := JSON.stringify([row.producer_id, id, int(version), node, row.action_or_variant, segment, locale])
							_expect(not required_tuples.has(key), "unique prologue catalog tuple")
							required_tuples[key] = true


func _collect_tuple(observation: Dictionary) -> void:
	if observation.producer_id not in PRODUCERS: return
	for segment in observation.segments:
		var key := JSON.stringify([observation.producer_id, observation.content_id, int(observation.content_version), observation.node_id, observation.variant_id, segment.segment_id, segment.viewed_locale])
		if not required_tuples.has(key): unmapped_tuples[key] = true
		else: observed_tuples[key] = true


func _view(tree: SceneTree) -> Node:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var view := VIEW.instantiate()
	view.configure_session(SLOT, "P1_ENTRY", false)
	tree.current_scene.add_child(view)
	return view


func _drain(view: Node) -> void:
	for index in range(100):
		if not view._dialogue_active: return
		var token: String = view._dialogue_lines[view._dialogue_index].presentation_token
		var before := GameState.get_snapshot()
		view._present_dialogue_line()
		_expect(GameState.get_snapshot() == before, "same displayed line rerenders without a duplicate")
		view._dialogue_next.pressed.emit()
		if view._dialogue_active and view._dialogue_lines[view._dialogue_index].presentation_token == token:
			_expect(false, "dialogue cannot advance: " + String(view._dialogue_lines[view._dialogue_index].get("notebook_content", {})))
			return
	_expect(false, "dialogue continuation did not terminate")


func _press_choice(view: Node, id: String) -> void:
	for button in view._dialogue_choice_buttons:
		if button.visible and button.get_meta("choice_id", "") == id:
			button.pressed.emit()
			return
	_expect(false, "choice button unavailable: " + id)


func _route(tree: SceneTree, language: String) -> void:
	var view := _view(tree)
	await tree.process_frame
	_drain(view)
	_validate_departure_confirmation(view)
	_collect(language)
	view.queue_free()
	await tree.process_frame
	view = _view(tree)
	await tree.process_frame
	_drain(view)
	for object in ["bed", "window", "photo", "notebook"]:
		view._inspect_bedroom(object)
		_drain(view)
	view._leave_bedroom_morning()
	_drain(view)
	var duties := ["P2_complete", "P3_complete", "P3B_complete"]
	for mask in range(1, 8):
		for index in range(3): view._progress[duties[index]] = not bool(mask & (1 << index))
		view._report_tasks()
		_drain(view)
	for duty in duties: view._progress[duty] = false
	view._enter_room("M1_PARLOR")
	_drain(view)
	view._hotspot_layer.get_node("CLOCK").pressed.emit()
	_drain(view)
	view._on_window_pressed(0)
	for tool in ["SPANNER", "COARSE_BRUSH"]:
		view._apply_window_tool(tool, "TOP")
		_drain(view)
	for window in range(3):
		view._on_window_pressed(window)
		view._apply_window_tool("SOFT_CLOTH", "TOP")
		_drain(view)
		view._apply_window_tool("WATER", "MIDDLE")
		view._apply_window_tool("SOFT_CLOTH", "BOTTOM")
		_drain(view)
	view._enter_room("M1_LIBRARY_OUTER")
	_drain(view)
	view._hotspot_layer.get_node("INNER_DOOR").pressed.emit()
	_drain(view)
	view._on_shelf_item_dropped("BOOK_MECHANICAL", "SHELF_CLOCK")
	_drain(view)
	_press_choice(view, "author")
	_drain(view)
	# Reconstruct the pending choice widget, without marking either answer as chosen.
	view._dismiss_dialogue_for_test()
	view._p3_journal_prompt_active = false
	view._resume_p3_journal_choice()
	_drain(view)
	_press_choice(view, "locked")
	_drain(view)
	_press_choice(view, "silent")
	view._on_shelf_item_dropped("BOOK_FLORA", "SHELF_FLOWER")
	view._on_shelf_item_dropped("BOOK_LEDGER", "SHELF_CUP")
	_drain(view)
	view._enter_room("M1_NORTH_ARCHIVE_HALL")
	_drain(view)
	view._selected_item = "LABEL_LUCA"
	view._on_portrait_pressed(0, "EDGAR")
	_drain(view)
	for index in range(view.P3B_OWNERS.size()):
		view._on_portrait_item_dropped("LABEL_" + view.P3B_OWNERS[index], "PORTRAIT_%d" % index)
		_drain(view)
	view._enter_room("M1_KITCHEN")
	_drain(view)
	for index in range(view.TEA_STEPS.size()):
		view._on_tea_item_dropped(view.TEA_STEP_ITEMS[index], "TEA_%d" % index)
		_drain(view)
	view._turn_p4_cup_handle()
	_drain(view)
	view._turn_p4_cup_handle()
	_drain(view)
	# Branch fixtures exercise all three answers; a real playthrough still chooses one.
	view._record_p4_life_support_pulse()
	for choice in view.P4_FATHER_CHOICE_ORDER:
		view._enter_room("M1_KITCHEN")
		view._progress.P4_complete = false
		view._progress.p4_father_question = ""
		view._progress.iris_greeting_seen = false
		view._show_p4_father_choices()
		_press_choice(view, choice)
		_drain(view)
	view._hotspot_layer.get_node("PARLOR").pressed.emit()
	_drain(view)
	view._hotspot_layer.get_node("LIBRARY").pressed.emit()
	_drain(view)
	view._enter_room("M1_GREENHOUSE_VESTIBULE")
	_drain(view)
	for object in ["CORRIDOR_WINDOW", "GREENHOUSE_GLASS", "THRESHOLD"]:
		view._hotspot_layer.get_node(object).pressed.emit()
		_drain(view)
	view._hotspot_layer.get_node("RECORD").pressed.emit()
	_drain(view)
	view._enter_room("M2_BEDROOM")
	_drain(view)
	view._inspect_bedroom("window")
	_drain(view)
	view._on_sleep_bed()
	_cancel_key(view)
	_expect(not view._modal_active and not view._progress.P6_complete, "sleep cancellation never begins reset")
	view._on_sleep_bed()
	_modal_button(view, view._dialogue_ui_text("P6_SLEEP")).pressed.emit()
	_drain(view)
	await tree.create_timer(3.0).timeout
	_drain(view)
	var state := GameState.get_snapshot()
	_expect(ARCHIVE.validate(state.meta_progress.dialogue_history).ok, "actual prologue archive validates")
	var ledger: Dictionary = state.meta_progress.knowledge_entries.get("notebook_knowledge", {})
	_expect(preload("res://scripts/systems/notebook_knowledge.gd").validate(ledger, state.meta_progress.dialogue_history).ok and ledger.get("revision") == 9, "nine actual note actions survive the first physical reset")
	_expect(view._save_progress() and GameState.get_snapshot() == state, "departing prologue cannot overwrite permanent notes with reset defaults")
	view._open_notebook()
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
	view._close_modal()
	_expect(GameState.get_snapshot() == state, "notebook reopen is readonly after reset")
	_collect(language)
	_expect(GameState.get_snapshot() == state, "reading all prologue records leaves gameplay unchanged")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real prologue archive reloads")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), state), "prologue UIDs and captured source survive first reset and reload")
	view.queue_free()
	await tree.process_frame


func _collect(language: String) -> void:
	var state := GameState.get_snapshot()
	for entry in state.meta_progress.dialogue_history.entries:
		_expect(entry.record_class == "authored", "live prologue callsite must not silently fall back to unmapped")
		if entry.record_class != "authored": continue
		var observation: Dictionary = entry.observation
		_collect_tuple(observation)
		if observation.producer_id == "NP03":
			_expect(observation.entry_kind == "document_segment" and observation.segments[0].disclosure == "replay_committed", "event-written note is not a spoken or gameplay-read line")
			_expect(entry.protection_reasons.size() == 2, "note content and real knowledge revision both protect the source")
		covered[observation.content_id + ":" + language] = true
		_expect(observation.chapter_id == "PROLOGUE", "first reset lines keep their prologue context")
		var read := CONTENT.render_entry(entry, "en-US" if language == "ko-KR" else "ko-KR")
		_expect(read.ok and not read.entry.fallback, "exact authored prologue version translates")
		if observation.node_id == "P6" and observation.content_id == "NB_PR_P6_INSPECT_WINDOW":
			_expect(observation.location_id == "M2_BEDROOM", "nighttime reuse does not claim morning event")


func _modal_button(view: Node, label: String) -> Button:
	for child in view._modal_body.get_children():
		if child is Button and child.text == label: return child
	_expect(false, "modal action missing: " + label)
	return null


func _cancel_key(view: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	view._unhandled_input(event)


func _validate_departure_confirmation(view: Node) -> void:
	view._leave_bedroom_morning()
	var stale: Callable = _modal_button(view, view._dialogue_ui_text("P1_EXIT_START")).pressed.get_connections()[0].callable
	var before := GameState.get_snapshot()
	var rejected := FailedSave.new()
	view._prologue_surface_saves = rejected
	_cancel_key(view)
	_expect(view._modal_active and GameState.get_snapshot() == before, "failed modal cancellation remains retryable")
	var token: String = view._prologue_confirmation.tokens.cancel
	view._prologue_surface_saves = null
	rejected.free()
	_cancel_key(view)
	var cancelled := GameState.get_snapshot()
	_expect(not view._modal_active and not view._progress.P1_complete, "cancel preserves bedroom progress")
	_expect(cancelled.meta_progress.dialogue_history.entries.back().observation.presentation_token == token, "modal cancel retry preserves its token")
	_expect(cancelled.meta_progress.dialogue_history.entries.back().observation.entry_kind == "choice_cancelled", "cancel is not mislabeled as confirmation")
	stale.call()
	_expect(GameState.get_snapshot() == cancelled and not view._progress.P1_complete, "closed modal callback cannot confirm old intent")
	view._leave_bedroom_morning()
	_modal_button(view, view._dialogue_ui_text("P1_EXIT_START")).pressed.emit()
	_drain(view)
	_expect(view._progress.P1_complete and view._current_room == "M1_CENTRAL_HALL", "confirmed departure follows existing action")


func _partial_choice_and_retry(tree: SceneTree) -> void:
	TranslationServer.set_locale("en-US")
	var view := _view(tree)
	await tree.process_frame
	_drain(view)
	var count: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
	view._current_room = "M1_LIBRARY_OUTER"
	view._show_dialogue_choice_set("p3_journal", view._dialogue_ui_text("P3_HEADER"), "주인공", view._dialogue_ui_text("P3_PROMPT"), "EDGAR", ["author"], view._localized_p3_choices())
	var entry: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
	_expect(entry.observation.segments.size() == 3, "only displayed header, prompt, author option stored")
	var hidden := ARCHIVE.make_reference(entry, "locked")
	_expect(not ARCHIVE.resolve(GameState.get_snapshot().meta_progress.dialogue_history, hidden).ok, "unshown option cannot be compared")
	var token: String = entry.observation.presentation_token
	var rejected := FailedSave.new()
	view._prologue_surface_saves = rejected
	_press_choice(view, "author")
	_expect(view._dialogue_choice_active and GameState.get_snapshot().meta_progress.dialogue_history.entries.size() == count + 1, "failed selected record keeps original choice open")
	var selected_token: String = view._choice_selected_tokens.author
	view._prologue_surface_saves = null
	rejected.free()
	_press_choice(view, "author")
	var history: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history
	_expect(history.entries.size() == count + 3, "choice retry commits selection then only its displayed answer")
	_expect(history.entries[count].observation.presentation_token == token and history.entries[count + 1].observation.presentation_token == selected_token, "choice retry preserves presentation tokens")
	_expect(history.entries.back().observation.content_id == "NB_PR_P3_A_AUTHOR", "unselected locked answer never disclosed")
	_expect(history.entries[count].observation.conversation_session_id == history.entries[count + 1].observation.conversation_session_id, "selected intent is linked to its displayed choice context")
	_expect(history.entries.back().observation.conversation_session_id == history.entries[count].observation.conversation_session_id, "displayed answer retains its originating conversation")
	view.queue_free()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
