extends RefCounted

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const STORE := preload("res://scripts/systems/notebook_view_store.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree, fixture: Dictionary) -> Dictionary:
	var before := GameState.get_snapshot()
	var query = _open(fixture.archive, fixture.ledger)
	_test_groups(query)
	_test_occurrences()
	await _test_retention_notice(tree)
	await _test_people(tree)
	_test_sidecar(query, fixture.archive)
	await _test_panel(tree, query)
	_expect(GameState.get_snapshot() == before, "all browse paths leave gameplay unchanged")
	print("NOTEBOOK_BROWSE_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": "__test_browse", "run_id": "run", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}


func _open(archive: Dictionary, ledger: Dictionary, locale: String = "ko-KR"):
	var query := QUERY.new()
	_expect(query.open(archive, ledger, _scope(archive), locale).ok, "public browse model opens")
	return query


func _test_groups(query) -> void:
	var key: String = query.cache_key()
	var sessions: Dictionary = query.groups("sessions", {"tab": "dialogue"}, 0, key)
	_expect(sessions.count == 2 and sessions.items[0].count == 5 and sessions.items[1].count == 100, "same text in two actual sessions stays separate with complete counts")
	var chosen: String = sessions.items[0].id
	var lines: Dictionary = query.page({"tab": "dialogue", "sessions": [chosen]}, 0, key)
	_expect(lines.count == 5 and lines.items.back().key == sessions.items[0].last_line, "session filter and last-line entry agree")
	var nav: Dictionary = query.dialogue_neighbors(lines.items[0].key, key)
	_expect(nav.previous.is_empty() and nav.next == lines.items[1].key and nav.last == lines.items[4].key, "spoken navigation stays inside the chosen occurrence")
	nav = query.dialogue_neighbors(lines.items.back().key, key)
	_expect(nav.next.is_empty() and nav.previous == lines.items[3].key, "last line does not jump into another session")
	var people: Dictionary = query.groups("people", {}, 0, key)
	_expect(people.count == 1 and people.items[0].id == "EDGAR" and people.items[0].spoken == 105, "person summary contains only an actually recorded speaker")
	_expect(query.public_label("locations", "M1_LIBRARY_OUTER") == "외부 서고" and query.public_label("speakers", "EDGAR") == "에드가", "public location and speaker labels use readable names")
	_expect(not query.public_label("locations", "H0_LIFE_SUPPORT").contains("생명") and not query.public_label("people", "IRIS").contains("이리스"), "label accessor itself cannot disclose an unseen place or person")
	_expect(query.page({"tab": "dialogue", "locations": ["M1_LIBRARY_OUTER", "missing"], "sources": ["spoken"]}, 0, key).count == 105, "OR within location and AND across source filters")
	var clue: String = query.page({"tab": "clues"}, 0, key).items[0].key
	var source: String = query.detail(clue, key).sources[0]
	_expect(query.detail(source, key).related.any(func(item: Dictionary) -> bool: return item.key == clue), "actually acquired knowledge has a reverse link from its cited line")
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(key, 50)
	_expect(query.page({"tab": "dialogue", "needle": "외부 서고"}, 0, key).count == 105, "search includes the disclosed location name")
	_expect(query.page({"tab": "dialogue", "needle": "M1_LIBRARY_OUTER"}, 0, key).count == 0, "location ID is never a search keyword")
	_expect(query.page({"tab": "dialogue", "needle": "진동"}, 0, key).count == 0 and query.page({"tab": "dialogue", "needle": "진동", "all_sections": true}, 0, key).count == 1, "explicit all-section search crosses tabs without revealing hidden material")
	var restored: Dictionary = query.visible_filters({"tab": "dialogue", "all_sections": true, "sources": ["note"]})
	_expect(restored.sources == ["note"] and query.page(restored, 0, key).count == 1, "restoring all-section search preserves filters outside the active tab")
	_expect(not query.groups("hidden", {}, 0, key).ok and not query.groups("people", {}, 0, "old").ok, "group API rejects unknown capability and stale query key")


func _observe(id: String, occurrence: String, session: String, location: String = "M1_LIBRARY_OUTER") -> Dictionary:
	var definition := CONTENT.definition(id, 1)
	var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var context := {"node_id": definition.node_ids[0], "location_id": location, "chapter_id": "CHAPTER_3", "event_occurrence_id": occurrence, "conversation_session_id": session, "presentation_token": ARCHIVE.new_uid()}
	var observed := CONTENT.observe(descriptor, context, shown.speaker, shown.text, "ko-KR")
	_expect(observed.ok, "browse fixture observation: " + id)
	return observed.observation


func _test_occurrences() -> void:
	var archive := ARCHIVE.create()
	var shared_session := ARCHIVE.new_uid()
	for index in range(51):
		var result := ARCHIVE.append_observation(archive, _observe("NB_PR_DUTY_1", ARCHIVE.new_uid(), shared_session), int(archive.revision))
		_expect(result.ok, "occurrence fixture appended")
		archive = result.archive
	var before := JSON.stringify(archive)
	var query = _open(archive, KNOWLEDGE.create(), "en-US")
	var groups: Dictionary = query.groups("sessions", {}, 0, query.cache_key())
	_expect(groups.count == 51 and groups.items.size() == 50 and groups.pages == 2, "different occurrences cannot merge even if a session ID is reused; group pages bounded to 50")
	_expect(query.groups("sessions", {}, 1, query.cache_key()).items.size() == 1, "51st occurrence is accessible")
	_expect(query.public_label("locations", "M1_LIBRARY_OUTER") == "Outer library", "browse labels follow current UI language")
	_expect(JSON.stringify(archive) == before, "grouping does not collapse or rewrite original observations")


func _test_retention_notice(tree: SceneTree) -> void:
	var original := preload("res://scripts/tests/notebook_retention_fixture.gd").create()
	var maintained := ARCHIVE.maintain(original, original.revision)
	_expect(maintained.ok, "retention browse fixture pruned through real archive policy")
	if not maintained.ok: return
	# Keep an unmarked, later observation in the same session to test filtered grouping.
	var archive: Dictionary = maintained.archive
	var observed: Dictionary = original.entries[4].observation.duplicate(true)
	observed.presentation_token = ARCHIVE.new_uid()
	observed.content_protection = ["journal"]
	archive = ARCHIVE.append_observation(archive, observed, archive.revision).archive
	var late: Dictionary = archive.entries.back()
	_expect(not late.has(ARCHIVE.SESSION_PRUNED), "later same-session entry does not fabricate its own prune evidence")
	var late_ref := ARCHIVE.make_reference(late, "body")
	archive = ARCHIVE.set_reference(archive, "bookmarks", late_ref, true, archive.revision).archive
	archive = ARCHIVE.set_reference(archive, "comparison", late_ref, true, archive.revision).archive
	var other_ref := ARCHIVE.make_reference(original.entries[2], "body")
	archive = ARCHIVE.set_reference(archive, "comparison", other_ref, true, archive.revision).archive
	var before := archive.duplicate(true)
	for locale in ["ko-KR", "en-US"]:
		var query = _open(archive, KNOWLEDGE.create(), locale)
		var key: String = query.cache_key()
		var detail: Dictionary = query.detail(QUERY.reference_key(late_ref), key)
		var notice: String = detail.retention_notice
		_expect(notice.contains("정리되었습니다" if locale == "ko-KR" else "were pruned"), "retention notice follows UI language: " + locale)
		_expect(detail.text == observed.segments[0].captured_text and "retention_notice" not in QUERY.SEARCH_FIELDS, "notice is not added to observed text or search fields")
		var groups: Dictionary = query.groups("sessions", {"bookmarks_only":true}, 0, key)
		_expect(groups.count == 1 and groups.items[0].retention_notice == notice, "filter hiding marked entries does not hide known session evidence")
		var other: Dictionary = query.detail(QUERY.reference_key(ARCHIVE.make_reference(original.entries[2], "body")), key)
		_expect(other.retention_notice.is_empty(), "same session IDs from another origin do not inherit notice")
		var panel := PANEL.new()
		panel.size = Vector2(1280, 720)
		tree.current_scene.add_child(panel)
		await tree.process_frame
		panel.present(query, locale, "dialogue")
		panel.show_detail(detail.key)
		var label := panel._detail.find_child("NotebookRetentionNotice", true, false) as Label
		_expect(label != null and label.text == notice, "detail displays retention notice separately: " + locale)
		panel._comparison_mode = true
		panel._render_pair()
		var left := panel._pair_panels[0].find_child("NotebookRetentionNotice", true, false) as Label
		_expect(left != null and left.text == notice and panel._pair_panels[1].find_child("NotebookRetentionNotice", true, false) == null, "two-material comparison marks only affected side: " + locale)
		panel._comparison_mode = false
		panel.set_filters({"tab":"dialogue", "bookmarks_only":true})
		panel._open_browser("sessions")
		var cards: Array = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.has_meta("group_id"))
		_expect(cards.size() == 1 and cards[0].text.contains(notice), "conversation card displays its retention notice: " + locale)
		panel.dismiss()
		panel.queue_free()
		await tree.process_frame
		query.close()
		_expect(query._pruned_sessions.is_empty(), "close releases session retention cache")
		query.open(original, KNOWLEDGE.create(), _scope(original), locale)
		_expect(query.detail(QUERY.reference_key(ARCHIVE.make_reference(original.entries[1], "body")), query.cache_key()).retention_notice.is_empty(), "reopening an earlier save does not inherit future prune history")
	_expect(archive == before, "retention browsing never modifies archive")


func _test_people(tree: SceneTree) -> void:
	var archive := ARCHIVE.create()
	var ledger := KNOWLEDGE.create()
	var anonymous := KNOWLEDGE.acquire(ledger, archive, _observe("NB_CORE_D_INDEX_RECORD", ARCHIVE.new_uid(), ARCHIVE.new_uid()), ARCHIVE.new_uid())
	_expect(anonymous.ok, "anonymous resident index fixture acquired")
	archive = anonymous.archive
	ledger = anonymous.ledger
	var query = _open(archive, ledger)
	var groups: Dictionary = query.groups("people", {}, 0, query.cache_key())
	_expect(groups.count == 1 and groups.items[0].id == "unidentified" and not groups.items[0].title.contains("마라"), "anonymous purple index is never promoted to Mara 2's identity")
	var spoken := ARCHIVE.append_observation(archive, _observe("NB_PR_DUTY_1", ARCHIVE.new_uid(), ARCHIVE.new_uid()), int(archive.revision))
	_expect(spoken.ok, "earlier spoken person material appended")
	archive = spoken.archive
	for id in ["NB_EDGAR_RECORD", "NB_IRIS_RECORD", "NB_LUCA_RECORD", "NB_MARA1_RECORD_ORIGINAL_ATTRIBUTION", "NB_MARA2_RECORD"]:
		var acquired := KNOWLEDGE.acquire(ledger, archive, _observe(id, ARCHIVE.new_uid(), ARCHIVE.new_uid()), ARCHIVE.new_uid())
		_expect(acquired.ok, "public person record: " + id)
		archive = acquired.archive
		ledger = acquired.ledger
	query = _open(archive, ledger)
	groups = query.groups("people", {}, 0, query.cache_key())
	_expect(groups.count == 6, "five acquired researcher records plus anonymous material stay independently addressable")
	_expect(groups.items.map(func(item: Dictionary) -> String: return item.id) == ["unidentified", "EDGAR", "IRIS", "LUCA", "MARA1", "MARA2"], "people use first available disclosure order instead of most recent document order")
	var filtered: Dictionary = query.groups("people", {"sources": ["note", "document"]}, 0, query.cache_key())
	_expect(filtered.items.map(func(item: Dictionary) -> String: return item.id) == ["unidentified", "EDGAR", "IRIS", "LUCA", "MARA1", "MARA2"], "person ordering remains stable when a filter excludes earlier dialogue")
	var iris: Dictionary = query.page({"tab": "people", "people": ["IRIS"]}, 0, query.cache_key())
	_expect(iris.count == 1 and iris.items[0].title == "이리스의 연구 기록", "person page includes actually acquired document even when notebook is its speaker")
	_expect(query.page({"tab": "people", "people": ["MARA2"]}, 0, query.cache_key()).count == 1, "Mara 2's known record does not absorb anonymous material")
	_expect(query.page({"tab": "records", "people": ["IRIS"], "provenance": ["identified", "authenticated"]}, 0, query.cache_key()).count == 1, "public person and source-status filters compose across records")
	var edgar: Dictionary = groups.items.filter(func(item: Dictionary) -> bool: return item.id == "EDGAR")[0]
	var latest: Dictionary = query.detail(edgar.last, query.cache_key())
	_expect(edgar.last != edgar.last_line and latest.kind == "document_segment", "latest person material may be a document after an earlier utterance")
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, "ko-KR", "people")
	panel._open_browser("people")
	var card: Button = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.get_meta("group_id", "") == "EDGAR")[0]
	_expect(card.text.contains(String(latest.text).replace("\n", " ").left(120)), "person preview uses the latest document instead of a stale last utterance")
	panel.dismiss()
	panel.queue_free()
	await tree.process_frame


func _test_sidecar(query, archive: Dictionary) -> void:
	var store := STORE.new("user://__test_browse_version")
	var scope := STORE.persistent_scope(_scope(archive))
	_expect(store.save_view(scope, query.view_frontier(), STORE.empty_state()).ok, "new sidecar writes")
	var files := store.paths(scope)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(files.main))
	_expect(envelope.version == STORE.VERSION, "sidecar writes the current convenience format")
	envelope.version = 1
	var file := FileAccess.open(files.main, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_expect(store.load_view(scope, query.view_frontier()).source == "primary", "version one UI preferences remain readable")
	_expect(store.save_view(scope, query.view_frontier(), STORE.empty_state()).ok, "old preferences upgrade on the next explicit UI save")
	for path in files.values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://__test_browse_version")


func _test_panel(tree: SceneTree, query) -> void:
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, "ko-KR", "dialogue", 2.0)
	var original := panel._filters.duplicate(true)
	panel.find_child("NotebookFilters", true, false).pressed.emit()
	_expect(panel._browser.visible and not panel._body.visible and panel._browser._back.has_focus(), "filter browser opens with keyboard focus and no overlapping material view")
	var locations: Array = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.get_meta("filter_field", "") == "locations")
	_expect(locations.size() == 1 and locations[0].text == "외부 서고", "filter UI offers only disclosed names")
	locations[0].pressed.emit()
	_expect(panel._filters == original and panel._browser._draft.locations == ["M1_LIBRARY_OUTER"], "filter edits are staged until Apply")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._unhandled_key_input(escape)
	_expect(not panel._browser.visible and panel._filters == original, "Esc cancels only the filter browser")
	panel._open_browser("filters")
	locations = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.get_meta("filter_field", "") == "locations")
	locations[0].pressed.emit()
	panel.find_child("NotebookApplyFilters", true, false).pressed.emit()
	_expect(not panel._browser.visible and panel._filters.locations == ["M1_LIBRARY_OUTER"] and panel._list.get_child_count() == 50, "Apply uses existing bounded row query")
	panel.find_child("NotebookBrowseGroups", true, false).pressed.emit()
	var groups: Array = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.has_meta("group_id"))
	_expect(groups.size() == 2 and panel._seen.is_empty(), "group browsing does not mark all sessions read")
	groups[0].pressed.emit()
	_expect(panel._filters.sessions.size() == 1 and panel._list.get_child_count() == 5 and panel._seen.size() == 1, "choosing session opens its last line, not every line")
	panel.find_child("NotebookLine_previous", true, false).pressed.emit()
	_expect(not panel.find_child("NotebookLine_next", true, false).disabled, "explicit previous-line control enables forward navigation")
	_expect(panel.find_child("NotebookLine_previous", true, false).has_focus(), "previous-line keyboard focus survives rebuilding the detail")
	panel.find_child("NotebookLine_last", true, false).pressed.emit()
	_expect(panel.find_child("NotebookLine_previous", true, false).has_focus(), "last-line navigation focuses an enabled continuation at the boundary")
	panel.set_tab("clues")
	_expect(not panel._filters.has("sessions"), "changing top-level section releases conversation restriction")
	var clue: String = query.page({"tab": "clues"}, 0, query.cache_key()).items[0].key
	var source: String = query.detail(clue, query.cache_key()).sources[0]
	panel.show_detail(source)
	panel.find_child("NotebookRelated_" + clue.sha256_text(), true, false).pressed.emit()
	_expect(panel._selected == clue and panel._back_stack.size() == 1, "related-clue control creates a source return path")
	panel._back()
	_expect(panel._selected == source, "related-clue back returns to the exact cited line")
	panel.set_tab("people")
	panel._open_browser("people")
	groups = panel._browser._items.get_children().filter(func(node: Node) -> bool: return node.has_meta("group_id"))
	_expect(groups.size() == 1 and groups[0].text.contains("최근 보관 원문"), "person card quotes retained material without generating a biography")
	groups[0].pressed.emit()
	_expect(panel._filters.people == ["EDGAR"], "person card filters actual related materials")
	panel.set_filters({"tab": "dialogue", "needle": "진동"})
	panel.find_child("NotebookSearchAll", true, false).pressed.emit()
	_expect(panel._filters.all_sections and panel._list.get_child_count() == 1, "empty search offers explicit all-disclosed search")
	panel._open_browser("filters")
	await tree.process_frame
	var controls: Array[Control] = []
	panel._collect_focus(panel, controls)
	panel._cycle_focus()
	for control in controls:
		_expect(control.get_node(control.focus_next) in controls and control.get_node(control.focus_previous) in controls, "filter focus ring contains only visible notebook controls")
	var page_down := InputEventKey.new()
	page_down.keycode = KEY_PAGEDOWN
	page_down.pressed = true
	var scroll: ScrollContainer = panel._browser.get_node("NotebookBrowseScroll")
	scroll.scroll_vertical = 0
	panel._unhandled_key_input(page_down)
	_expect(scroll.scroll_vertical > 0, "Page Down scrolls the visible filter browser, not a hidden material")
	_expect(panel._close.get_global_rect().end.y <= panel.get_global_rect().end.y, "close remains reachable at 720p and 200 percent text")
	var stale = panel._browser._back
	panel.dismiss()
	stale.pressed.emit()
	_expect(not panel.visible and not panel._browser.visible, "dismiss invalidates stale browser callbacks")
	panel.queue_free()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_BROWSE_FAIL: ", message)
