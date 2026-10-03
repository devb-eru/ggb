extends RefCounted

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const STORE := preload("res://scripts/systems/notebook_view_store.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree) -> Dictionary:
	var before := GameState.get_snapshot()
	var fixture := _fixture()
	_test_mapping(fixture)
	_test_sources()
	var view := await _test_panel(tree, fixture)
	_test_page_and_compatibility(fixture, view)
	_expect(GameState.get_snapshot() == before, "investigation reads leave game state unchanged")
	print("NOTEBOOK_INVESTIGATION_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": "__test_investigation", "run_id": "run", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}


func _open(fixture: Dictionary, node: String, locale: String = "ko-KR"):
	var query := QUERY.new()
	_expect(query.open(fixture.archive, fixture.ledger, _scope(fixture.archive), locale, {"chapter_notebook": {"unclassified": "B4 C5 D4 SECRET_MISSING_MATERIAL"}}, node).ok, "open related model: " + node)
	return query


func _observation(id: String) -> Dictionary:
	var row := CONTENT.definition(id, 1)
	var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var observed := CONTENT.observe(descriptor, {"node_id": row.node_ids[0], "location_id": "M1_LIBRARY_OUTER", "chapter_id": "CHAPTER_3", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}, shown.speaker, shown.text, "ko-KR")
	_expect(observed.ok, "fixture disclosure: " + id)
	return observed.observation


func _fixture() -> Dictionary:
	var result := {"archive": ARCHIVE.create(), "ledger": KNOWLEDGE.create(), "keys": {}}
	for id in ["NB_NOTE_P_PULSE", "NB_CH1_NOTE_J1", "NB_CH1_NOTE_B1", "NB_CH1_NOTE_CLOCK_PARLOR", "NB_CH1_NOTE_J2", "NB_MIRROR_NOTE_CLEANING", "NB_MIRROR_NOTE_CHEMICALS", "NB_MIRROR_NOTE_FORMULA", "NB_CH1_NOTE_B4", "NB_MIRROR_NOTE_C5_INFO", "NB_MIRROR_NOTE_J3", "NB_BASEMENT_NOTE_FLOORPLAN", "NB_BASEMENT_NOTE_D4", "NB_EDGAR_RECORD", "NB_CH1_NOTE_A1_SENTENCE", "NB_CH1_NOTE_A2", "NB_CORE_E_AUTHOR_RECORD", "NB_FINAL_J5_RECORD", "NB_HINT_F0_C_H1"]:
		var observation := _observation(id)
		var appended: Dictionary
		if CONTENT.definition(id, 1).has("knowledge"):
			appended = KNOWLEDGE.acquire(result.ledger, result.archive, observation, ARCHIVE.new_uid())
			if appended.ok: result.ledger = appended.ledger
		else: appended = ARCHIVE.append_observation(result.archive, observation, int(result.archive.revision))
		_expect(appended.ok, "fixture recorded: " + id)
		result.archive = appended.archive
		result.keys[id] = QUERY.reference_key(ARCHIVE.make_reference(result.archive.entries.back(), "body"))
	var partial := ARCHIVE.append_observation(result.archive, _observation("NB_J4_DOCUMENT"), int(result.archive.revision))
	_expect(partial.ok, "only J4 body shown; no full or unobserved researcher segment")
	result.archive = partial.archive
	result.keys.NB_J4_DOCUMENT = QUERY.reference_key(ARCHIVE.make_reference(result.archive.entries.back(), "body"))
	for id in ["NB_CH1_NOTE_B4", "NB_MIRROR_NOTE_C5_INFO", "NB_BASEMENT_NOTE_D4"]:
		var ref: Dictionary = JSON.parse_string(result.keys[id])
		var pinned := ARCHIVE.set_reference(result.archive, "comparison", ref, true, int(result.archive.revision))
		_expect(pinned.ok, "fixture saved comparison reference")
		result.archive = pinned.archive
	return result


func _test_mapping(fixture: Dictionary) -> void:
	var frozen := JSON.stringify(fixture)
	var matrix := {
		"B3_A": ["NB_CH1_NOTE_J1", "NB_CH1_NOTE_B1", "NB_CH1_NOTE_CLOCK_PARLOR"],
		"C3": ["NB_CH1_NOTE_J2", "NB_MIRROR_NOTE_CLEANING", "NB_MIRROR_NOTE_CHEMICALS"],
		"C4": ["NB_CH1_NOTE_B4", "NB_CH1_NOTE_J2", "NB_MIRROR_NOTE_FORMULA"],
		"D0_A": ["NB_MIRROR_NOTE_C5_INFO", "NB_MIRROR_NOTE_J3", "NB_BASEMENT_NOTE_FLOORPLAN"],
		"F0_C": ["NB_CH1_NOTE_B4", "NB_MIRROR_NOTE_C5_INFO", "NB_BASEMENT_NOTE_D4", "NB_HINT_F0_C_H1"],
		"F0_D": ["NB_J4_DOCUMENT", "NB_EDGAR_RECORD"],
		"F0_E": ["NB_CH1_NOTE_A1_SENTENCE", "NB_CH1_NOTE_A2", "NB_CORE_E_AUTHOR_RECORD"],
	}
	for locale in ["ko-KR", "en-US"]:
		for node in matrix:
			var query = _open(fixture, node, locale)
			var page: Dictionary = query.investigation_page(0, query.cache_key())
			var keys: Array = page.items.map(func(item: Dictionary) -> String: return item.key)
			_expect(query.investigation_available(), "current known context enables generic shortcut")
			for id in matrix[node]: _expect(fixture.keys[id] in keys, "required related material: " + node + " / " + id)
			_expect(fixture.keys.NB_FINAL_J5_RECORD not in keys, "J5 is not used as earlier-puzzle answer guidance")
			_expect(not JSON.stringify(page).contains("SECRET_MISSING_MATERIAL"), "legacy wording cannot invent an event attribution")
			_expect(not query.investigation_page(0, "old").ok, "old context query key rejected")
			if node == "F0_C": _expect(page.count == 4, "three acquired diagrams and requested H1 only; H2-H5 have no placeholder or count")
			if node == "F0_E": _expect(page.items.any(func(item: Dictionary) -> bool: return item.key == fixture.keys.NB_CH1_NOTE_A1_SENTENCE and item.previous), "past self-written mark remains available and is labelled as an earlier revision")
			if node == "F0_D":
				var hidden: Dictionary = JSON.parse_string(fixture.keys.NB_J4_DOCUMENT)
				hidden.segment_id = "full"
				_expect(QUERY.reference_key(hidden) not in keys and not query.detail(QUERY.reference_key(hidden), query.cache_key()).ok, "J4 full page remains hidden in related materials")
	var empty = _open({"archive": ARCHIVE.create(), "ledger": KNOWLEDGE.create()}, "F0_C")
	_expect(empty.investigation_page(0, empty.cache_key()).count == 0, "knowing a puzzle context does not acquire or enumerate its missing diagrams")
	var unknown = _open(fixture, "NOT_A_GAME_NODE")
	_expect(not unknown.investigation_available() and unknown.investigation_page(0, unknown.cache_key()).count == 0, "unknown context does not fall back to future content")
	_expect(JSON.stringify(fixture) == frozen, "relevance never edits original records, answers or references")


func _test_sources() -> void:
	var first := KNOWLEDGE.acquire(KNOWLEDGE.create(), ARCHIVE.create(), _observation("NB_NOTE_P_PULSE"), ARCHIVE.new_uid())
	_expect(first.ok, "source evidence fixture acquired")
	var source: Dictionary = ARCHIVE.make_reference(first.archive.entries.back(), "body")
	var linked := KNOWLEDGE.acquire(first.ledger, first.archive, _observation("NB_MIRROR_NOTE_CLEANING"), ARCHIVE.new_uid(), [source])
	_expect(linked.ok, "explicit typed source link acquired")
	var query = _open(linked, "C3")
	var page: Dictionary = query.investigation_page(0, query.cache_key())
	_expect(page.count == 2 and page.items.any(func(item: Dictionary) -> bool: return item.key == QUERY.reference_key(source)), "direct acquired source is included even outside the topic's own events")
	var old_key: String = query.cache_key()
	query.open(linked.archive, linked.ledger, _scope(linked.archive), "ko-KR", {}, "F0_E")
	_expect(not query.investigation_page(0, old_key).ok and query.investigation_page(0, query.cache_key()).count == 0, "context replacement invalidates old relevance results at the same archive revision")


func _test_panel(tree: SceneTree, fixture: Dictionary) -> Dictionary:
	var query = _open(fixture, "F0_C")
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, "ko-KR", "dialogue", 2.0)
	var filters := {"tab": "dialogue", "needle": "does not match", "bookmarks_only": true}
	panel.set_filters(filters)
	await _settle(tree)
	panel.find_child("NotebookInvestigation", true, false).pressed.emit()
	await _settle(tree)
	var page: Dictionary = query.investigation_page(0, query.cache_key())
	var key: String = page.items[0].key
	var button: Button = panel._browser.find_child("NotebookInvestigationRow_" + key.sha256_text(), true, false)
	_expect(button != null and panel._filters == filters, "explicit related browse ignores restrictive filters without changing them")
	_expect(not panel._status.visible, "original filtered result count is not mislabelled as the related-list count")
	_expect(panel._browser._back.get_global_rect().end.y <= panel.get_global_rect().end.y and panel._browser.get_node("NotebookBrowseScroll").size.y > 0, "720p 200 percent related list keeps back and scrolling available")
	_expect(panel._seen.is_empty() and panel._back_stack.is_empty(), "opening relevance list does not mark unseen records read")
	button.pressed.emit()
	await _settle(tree)
	_expect(panel._selected == key and panel._back_stack.size() == 1 and panel._back_stack[0].key.is_empty(), "related detail can return to a previously unselected list")
	_expect(panel._filters == filters and panel._seen.has(key), "only explicit selected material read; filters intact")
	var view: Dictionary = panel.capture_view()
	var state := STORE.empty_state()
	state.general = view
	_expect(STORE.valid_state(state), "related return state validates for persistence")
	panel.restore_view(view)
	await _settle(tree)
	_expect(panel._selected == key and panel._back_stack.size() == 1, "reopen keeps selected related record outside active filters")
	panel._back()
	await _settle(tree)
	_expect(panel._selected.is_empty() and not panel._detail_visible and panel._filters == filters, "back returns to exact original filtered list")
	panel.set_filters({"tab": "records"})
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	panel._compact_side = 1
	var pair: Array = panel.visible_pair()
	panel._open_browser("investigation")
	panel._browser.material_selected.emit(key)
	await _settle(tree)
	_expect(not panel._comparison_mode and panel._detail_visible, "related detail temporarily replaces comparison")
	panel._back()
	_expect(panel._comparison_mode, "comparison mode is restored synchronously before a rapid notebook close")
	await _settle(tree)
	_expect(panel._comparison_mode and panel.visible_pair() == pair and panel._compact_side == 1, "back restores comparison with the same pair and A/B side")
	panel._open_browser("investigation")
	var stale = panel._browser.find_child("NotebookInvestigationRow_" + key.sha256_text(), true, false)
	panel._close_browser()
	stale.pressed.emit()
	_expect(not panel._detail_visible and panel._comparison_mode, "dismissed browse button cannot open a late record")
	panel._open_browser("investigation")
	query.close()
	await _settle(tree)
	_expect(not panel._browser.visible, "query invalidation closes relevance list")
	panel.queue_free()
	await tree.process_frame
	return view


func _test_page_and_compatibility(fixture: Dictionary, view: Dictionary) -> void:
	var archive := ARCHIVE.create()
	for index in range(51):
		var appended := ARCHIVE.append_observation(archive, _observation("NB_CH1_NOTE_B4"), int(archive.revision))
		_expect(appended.ok, "repeat occurrence fixture")
		archive = appended.archive
	var query = _open({"archive": archive, "ledger": KNOWLEDGE.create()}, "F0_C")
	var page: Dictionary = query.investigation_page(0, query.cache_key())
	_expect(page.count == 51 and page.items.size() == 50 and page.pages == 2, "related materials page at fifty observed segments")
	_expect(query.investigation_page(1, query.cache_key()).items.size() == 1, "fifty-first item accessible")
	var state := STORE.empty_state()
	state.general = view
	var invalid := state.duplicate(true)
	invalid.general.back[0].view.detail = "yes"
	_expect(not STORE.valid_state(invalid), "return view flags require booleans")
	var store := STORE.new("user://__test_investigation_views")
	var scope := STORE.persistent_scope(_scope(fixture.archive))
	query = _open(fixture, "F0_C")
	_expect(store.save_view(scope, query.view_frontier(), state).ok, "version four sidecar writes")
	_expect(store.load_view(scope, query.view_frontier()).state.general.back == JSON.parse_string(JSON.stringify(state.general.back)), "related return context round trips through a real sidecar with JSON numeric normalization")
	var paths := store.paths(scope)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths.main))
	_expect(int(envelope.version) == 4, "new return-state envelope identifies version four")
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	for step in payload.state.general.back: step.erase("view")
	envelope.payload = JSON.stringify(payload, "", true)
	envelope.checksum = envelope.payload.sha256_text()
	envelope.version = 3
	var file := FileAccess.open(paths.main, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_expect(store.load_view(scope, query.view_frontier()).source == "primary", "version three convenience data remains readable")
	for path in paths.values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _settle(tree: SceneTree) -> void:
	for frame in range(8): await tree.process_frame


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors.append(message)
		print("NB_INVESTIGATION_FAIL: ", message)
