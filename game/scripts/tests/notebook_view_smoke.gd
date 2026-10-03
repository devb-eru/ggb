extends RefCounted

const STORE := preload("res://scripts/systems/notebook_view_store.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
var errors := PackedStringArray()
var checks := 0
var _files: Array[String] = []


func run(tree: SceneTree, fixture: Dictionary) -> Dictionary:
	var before := GameState.get_snapshot()
	var query = _open(fixture.archive, fixture.ledger)
	await _badges(tree, query)
	await _navigation_restore(tree, query)
	await _body_and_store(tree)
	_expect(GameState.get_snapshot() == before, "all UI state reads/writes preserve the gameplay snapshot")
	for path in _files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://__test_notebook_view")
	print("NOTEBOOK_VIEW_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _scope(archive: Dictionary, epoch: int = 1) -> Dictionary:
	return {"namespace": "test", "slot": "__test_views", "run_id": "run-view", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": epoch}


func _open(archive: Dictionary, ledger: Dictionary, knowledge: Dictionary = {}, locale: String = "ko-KR"):
	var query := QUERY.new()
	_expect(query.open(archive, ledger, _scope(archive), locale, knowledge).ok, "view query opens")
	return query


func _badges(tree: SceneTree, query) -> void:
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	var viewed: Array = []
	panel.material_viewed.connect(func(key: String) -> void: viewed.append(key))
	panel.present(query, "ko-KR", "dialogue", 2.0)
	var rows: Dictionary = query.page({"tab": "dialogue"}, 0, query.cache_key())
	var order := panel._list.get_children().map(func(node: Node) -> String: return node.get_meta("reference_key", ""))
	_expect(viewed.is_empty() and panel._seen.is_empty(), "list previews and automatic basket preparation never mark read")
	panel.open_latest_dialogue()
	_expect(panel._selected == rows.items[4].key and viewed.is_empty(), "history first entry selects latest session's last line without fabricating a read action")
	panel.show_detail(rows.items[0].key)
	_expect(viewed == [rows.items[0].key] and panel._seen.has(rows.items[0].key), "explicit detail clears only its own unread badge")
	_expect(order == panel._list.get_children().map(func(node: Node) -> String: return node.get_meta("reference_key", "")), "reading does not reorder or rebuild result rows")
	_expect(not panel._list.get_child(0).text.begins_with("[신규]") and panel._list.get_child(1).text.begins_with("[신규]"), "badge update leaves unread siblings untouched")
	panel.show_detail(rows.items[0].key)
	_expect(viewed.size() == 1, "repeat detail does not produce duplicate seen entries")
	panel._change_page(1)
	await tree.process_frame
	var view := panel.capture_view()
	_expect(STORE.valid_state({"seen": panel._seen.keys(), "groups": panel._seen_groups.keys(), "general": view, "dialogue": view}), "captured live panel view satisfies sidecar schema")
	_expect(not view.list_anchor.is_empty() and view.page == 1, "page cursor is an actual first-visible row reference")
	panel.present(query, "ko-KR", "clues", 2.0)
	_expect(panel._seen.is_empty() and panel._seen_groups.is_empty(), "presenting a fresh model cannot inherit old panel read metadata")
	viewed.clear()
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	_expect(viewed.size() == 1, "compact comparison marks only the actually visible A material")
	panel.find_child("NotebookPairSwitch", true, false).pressed.emit()
	_expect(viewed.size() == 2, "explicit B switch marks the second material, not the whole basket")
	panel.dismiss()
	_expect(panel._seen.is_empty() and panel._seen_groups.is_empty(), "dismiss releases per-scope seen metadata")
	panel.queue_free()
	await tree.process_frame


func _navigation_restore(tree: SceneTree, query) -> void:
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, "ko-KR", "clues", 2.0)
	var clue: String = query.page({"tab": "clues"}, 0, query.cache_key()).items[0].key
	panel.show_detail(clue)
	var source: String = query.detail(clue, query.cache_key()).sources[0]
	var link: Button = panel.find_child("NotebookSource_" + source.sha256_text(), true, false)
	link.grab_focus()
	link.pressed.emit()
	var view := panel.capture_view()
	_expect(view.back.size() == 1 and view.back[0].focus.control == String(link.name), "source navigation captures a stable return control instead of a transient NodePath")
	var fresh := PANEL.new()
	fresh.size = Vector2(1280, 720)
	tree.current_scene.add_child(fresh)
	await tree.process_frame
	fresh.present(query, "ko-KR", "clues", 2.0)
	fresh.restore_view(JSON.parse_string(JSON.stringify(view, "", true, true)))
	for frame in range(8): await tree.process_frame
	_expect(fresh._selected == source and fresh._back_stack.size() == 1 and fresh._filters.tab == "clues", "recreated linked view preserves a public source outside the active tab")
	fresh._back()
	for frame in range(3): await tree.process_frame
	_expect(fresh._selected == clue and fresh._back_stack.is_empty(), "restored source back-stack returns to the original card")
	_expect(fresh.find_child("NotebookSource_" + source.sha256_text(), true, false).has_focus(), "source return restores the exact original link control")
	fresh.set_filters({"tab": "dialogue"})
	fresh._change_page(1)
	for frame in range(3): await tree.process_frame
	var row: Button = fresh._list.get_child(8)
	fresh._list_scroll.scroll_vertical = roundi(row.position.y + row.size.y * 0.25)
	await tree.process_frame
	view = fresh.capture_view()
	_expect(view.list_anchor.key == row.get_meta("reference_key"), "list captures a mid-page UID with relative row offset")
	fresh.restore_view(view)
	for frame in range(8): await tree.process_frame
	var restored := fresh.capture_view()
	_expect(restored.page == 1 and restored.list_anchor.key == view.list_anchor.key and absf(restored.list_anchor.fraction - view.list_anchor.fraction) < 0.05, "list page and row-relative viewport survive rebuilding")
	view.selected = "unavailable"
	view.anchor = view.list_anchor.duplicate(true)
	view.anchor.key = "unavailable"
	view.detail = true
	view.filters.speakers = ["UNDISCLOSED_SPEAKER"]
	fresh.restore_view(view)
	for frame in range(8): await tree.process_frame
	_expect(not fresh._selected.is_empty() and fresh._selected != "unavailable" and fresh._filters.speakers.is_empty(), "missing material falls back to an actual public neighbor and unavailable facets are cleared")
	_expect(not fresh._notice.text.is_empty(), "unavailable material fallback is explained")
	fresh.find_child("NotebookCompare", true, false).pressed.emit()
	var basket: Dictionary = query.comparison(query.cache_key())
	fresh.select_pair(1, basket.items[2].key)
	fresh.find_child("NotebookPairSwitch", true, false).pressed.emit()
	view = fresh.capture_view()
	fresh.restore_view(view)
	for frame in range(8): await tree.process_frame
	_expect(fresh.visible_pair() == view.pair and fresh._comparison_mode and fresh._compact_side == 1, "comparison restores chosen two of three and compact B side")
	for button in ["NotebookBookmarks", "NotebookPreviousRevisions", "NotebookSwapPair", "NotebookPairSwitch"]:
		fresh.restore_view(view)
		_expect(fresh._restoring_view, "restoration has a deferred layout phase: " + button)
		fresh.find_child(button, true, false).pressed.emit()
		_expect(not fresh._restoring_view and fresh._pending_restore.is_empty(), "explicit action cancels stale deferred restoration: " + button)
		for frame in range(3): await tree.process_frame
	fresh.restore_view(view)
	fresh._chapter.item_selected.emit(0)
	_expect(not fresh._restoring_view, "chapter filter cancels stale restore")
	fresh.restore_view(view)
	fresh.select_pair(0, basket.items[2].key)
	_expect(not fresh._restoring_view, "explicit pair choice cancels stale restore")
	for frame in range(3): await tree.process_frame
	panel.queue_free()
	fresh.queue_free()
	await tree.process_frame


func _body_and_store(tree: SceneTree) -> void:
	var archive := ARCHIVE.create()
	var parts: Array[String] = []
	for index in range(70): parts.append("문단 %d: " % index + "보존한 원문은 언어와 글자 크기가 바뀌어도 다른 사건의 정보로 대체되지 않는다. ".repeat(3))
	var knowledge := {"chapter_notebook": {"long": "\n".join(parts)}}
	var query = _open(archive, KNOWLEDGE.create(), knowledge)
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, "ko-KR", "clues", 1.0)
	var key: String = query.page({"tab": "clues"}, 0, query.cache_key()).items[0].key
	panel.show_detail(key)
	await tree.process_frame
	await tree.process_frame
	var paragraphs := panel._paragraphs(panel._detail_scroll)
	var paragraph = paragraphs[20]
	var offset: float = paragraph.get_global_rect().position.y - panel._detail.get_global_rect().position.y
	panel._detail_scroll.scroll_vertical = roundi(offset + paragraph.size.y * 0.25)
	await tree.process_frame
	var view := panel.capture_view()
	_expect(view.body.paragraph == 20, "long body captures a paragraph position instead of only pixel offset")
	view.filters.needle = "문단"
	var state := {"seen": [key], "groups": [query.review_group(key)], "general": view, "dialogue": {}}
	var store := STORE.new("user://__test_notebook_view")
	var scope := STORE.persistent_scope(_scope(archive))
	var files := store.paths(scope)
	for path in files.values(): _files.append(path)
	_expect(store.load_view(scope, query.view_frontier()).state == STORE.empty_state(), "missing sidecar defaults without touching progress")
	var saved := store.save_view(scope, query.view_frontier(), state)
	_expect(saved.ok, "view and seen state persist in actual sidecar: " + str(saved))
	var loaded := store.load_view(scope, query.view_frontier())
	var wire_state: Dictionary = JSON.parse_string(JSON.stringify(state, "", true, true))
	_expect(loaded.source == "primary" and StateSnapshotValidator.same_persisted_value(loaded.state, wire_state), "checksummed file preserves every serialized state value")
	_expect(absf(float(loaded.state.general.get("body", {}).get("fraction", -1.0)) - float(view.body.fraction)) < 0.000001, "fractional paragraph position loses no visible precision in JSON round trip")
	_expect(STORE.persistent_scope(_scope(archive, 999)) == scope, "runtime load epoch is not a persistent restart key")
	var english = _open(archive, KNOWLEDGE.create(), knowledge, "en-US")
	var fresh := PANEL.new()
	fresh.size = Vector2(1280, 720)
	tree.current_scene.add_child(fresh)
	await tree.process_frame
	var read_actions: Array = []
	fresh.material_viewed.connect(func(value: String) -> void: read_actions.append(value))
	fresh.present(english, "en-US", "clues", 2.0)
	fresh.set_review_state(loaded.state.seen, loaded.state.groups)
	fresh.restore_view(loaded.state.general)
	for frame in range(8): await tree.process_frame
	var restored := fresh.capture_view()
	_expect(not fresh._restoring_view and restored.selected == key and restored.filters.needle == "문단", "recreated panel waits for search indexing and restores the stable selection")
	_expect(restored.body.paragraph == 20 and absf(restored.body.fraction - float(view.body.fraction)) < 0.08, "paragraph-relative cursor survives 100 to 200 percent text and locale chrome change")
	_expect(read_actions.is_empty() and fresh._seen.has(key), "restoration and locale change never manufacture a new read")
	_expect(not fresh._list.get_child(0).text.begins_with("[Unread]"), "seen badge survives reconstruction")
	var overwritten := knowledge.duplicate(true)
	overwritten.chapter_notebook.long = "바뀐 원문"
	var changed = _open(archive, KNOWLEDGE.create(), overwritten)
	var newer_key: String = changed.page({"tab": "clues"}, 0, changed.cache_key()).items[0].key
	_expect(changed.review_group(newer_key) == query.review_group(key) and newer_key != key, "new revision shares review group but not seen key")
	fresh.present(changed, "ko-KR", "clues", 1.0)
	fresh.set_review_state([key], [query.review_group(key)])
	_expect(fresh._list.get_child(0).text.begins_with("[갱신]"), "changed original gets an updated badge instead of an already-seen badge")
	fresh.show_detail(newer_key)
	_expect(not fresh._list.get_child(0).text.begins_with("[갱신]"), "explicitly opening the new revision clears its updated badge")
	_test_files(store, scope, query.view_frontier(), state)
	panel.queue_free()
	fresh.queue_free()
	await tree.process_frame


func _test_files(store, scope: Dictionary, frontier: Dictionary, state: Dictionary) -> void:
	for field in STORE.SCOPE_KEYS:
		var foreign := scope.duplicate(true)
		foreign[field] += "-other"
		_expect(store.paths(foreign).main != store.paths(scope).main and store.load_view(foreign, frontier).state == STORE.empty_state(), "scope isolation: " + field)
	var unsafe := scope.duplicate(true)
	unsafe.slot = "../../outside"
	_expect(store.paths(unsafe).main.begins_with(store.root_path + "/") and not store.paths(unsafe).main.contains(".."), "scope strings never become filesystem path components")
	var older := frontier.duplicate(true)
	older.archive_revision = maxi(0, int(frontier.archive_revision) - 1)
	older.legacy_digest = "different-last-value"
	_expect(store.load_view(scope, older).state == STORE.empty_state(), "unproven alternate last-value snapshot cannot import future view data")
	var future_frontier := frontier.duplicate(true)
	future_frontier.archive_revision += 3
	future_frontier.next_sequence += 3
	future_frontier.last_uid = ARCHIVE.new_uid()
	_expect(store.save_view(scope, future_frontier, state).ok, "future view fixture saved")
	_expect(store.load_view(scope, frontier).warning_id == "NB_VIEW_PAST_SNAPSHOT", "past snapshot discards future filters and seen state together")
	_expect(store.save_view(scope, frontier, state).ok, "current view can replace discarded convenience state")
	var files: Dictionary = store.paths(scope)
	var bytes := FileAccess.get_file_as_bytes(files.main)
	_expect(DirAccess.make_dir_recursive_absolute(files.temporary) == OK, "isolated temp-file failure fixture created")
	_expect(not store.save_view(scope, frontier, state).ok and FileAccess.get_file_as_bytes(files.main) == bytes, "failed preference write preserves last valid main file")
	_expect(DirAccess.remove_absolute(files.temporary) == OK, "empty failure directory removed")
	_write(files.main, "broken-json")
	var recovered: Dictionary = store.load_view(scope, future_frontier)
	_expect(recovered.source == "backup" and recovered.warning_id == "NB_VIEW_RECOVERED", "corrupt primary can use a valid scoped backup")
	_write(files.backup, "broken-backup")
	_expect(store.load_view(scope, frontier).warning_id == "NB_VIEW_DAMAGED", "two damaged sidecars default without losing records")
	_expect(store.save_view(scope, frontier, state).ok, "damaged convenience state can be repaired independently")
	for target in [files.main, files.backup]:
		_write(target, JSON.stringify({"version": 999}))
		var protected := FileAccess.get_file_as_bytes(target)
		var loaded: Dictionary = store.load_view(scope, frontier)
		_expect(not loaded.writable and loaded.warning_id == "NB_VIEW_FUTURE", "future sidecar version disables preference writes")
		_expect(not store.save_view(scope, frontier, state).ok and FileAccess.get_file_as_bytes(target) == protected, "unsupported future preferences are never overwritten")
		DirAccess.remove_absolute(target)
	for malformed in [[], null, true, "bad"]:
		var broken := state.duplicate(true)
		broken.general.body = malformed
		_expect(not STORE.valid_state(broken), "invalid body anchor rejected without script error")
	var bad := state.duplicate(true)
	bad.general.filters.sources = ["spoken"]
	bad.general.filters.people = ["EDGAR"]
	bad.general.filters.sessions = ["public-session-key"]
	bad.general.filters.provenance = ["identified"]
	bad.general.filters.all_sections = true
	_expect(STORE.valid_state(bad), "extended public browse filters have a valid durable view representation")
	bad.general.filters.sources = [false]
	_expect(not STORE.valid_state(bad), "extended filters reject non-string facet values")
	bad = state.duplicate(true)
	bad.general.body.fraction = 2.0
	_expect(not STORE.valid_state(bad), "out-of-range paragraph fraction rejected")
	bad = state.duplicate(true)
	bad.general.filters["hidden_state"] = "secret"
	_expect(not STORE.valid_state(bad), "sidecar cannot request arbitrary query capabilities")
	bad = state.duplicate(true)
	bad.dialogue = state.general
	_expect(not STORE.valid_state(bad), "history entry state must remain the dialogue route")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "test fixture write: " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_VIEW_FAIL: ", message)
