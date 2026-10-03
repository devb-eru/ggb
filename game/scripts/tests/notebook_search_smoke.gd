extends RefCounted

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree, fixture: Dictionary) -> Dictionary:
	var before := GameState.get_snapshot()
	var frozen := JSON.stringify(fixture)
	_test_ranges()
	var query := QUERY.new()
	_expect(query.open(fixture.archive, fixture.ledger, _scope(fixture.archive), "ko-KR").ok, "query fixture opens")
	var key: String = query.page({"tab": "clues"}, 0, query.cache_key()).items[0].key
	var hit: Dictionary = query.search_matches(key, "진동", query.cache_key())
	_expect(hit.ok and hit.matches.any(func(item: Dictionary) -> bool: return item.field == "text"), "matches come from actually disclosed text")
	_expect(query.search_matches(key, "NB_NOTE_P_PULSE", query.cache_key()).matches.is_empty(), "internal IDs cannot become search hits")
	_expect(not query.search_matches(key, "진동", "old").ok and not query.search_matches("hidden", "진동", query.cache_key()).ok, "stale and unobserved references denied")
	var detail: Dictionary = query.detail(key, query.cache_key())
	var across_fields: String = detail.title.right(4) + "\n" + detail.summary.left(4)
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(query.cache_key(), 50)
	_expect(query.page({"tab": "clues", "needle": across_fields}, 0, query.cache_key()).count == 0, "search does not invent adjacency between different public fields")
	for locale in ["ko-KR", "en-US"]:
		for size in [Vector2(1280, 720), Vector2(1920, 1080)]:
			for scale in [1.0, 1.5, 2.0]: await _test_panel(tree, locale, size, scale)
	_expect(JSON.stringify(fixture) == frozen and GameState.get_snapshot() == before, "all searches and navigation preserve recorded and game state")
	print("NOTEBOOK_SEARCH_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": "__test_search", "run_id": "run", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}


func _test_ranges() -> void:
	var body := "서재 A[b]🙂 NEEDLE, needle.\n다음 행"
	var detail := {"text": body, "title": "Needle", "summary": "", "speaker": "", "location_label": "서재", "source_label": "기록", "private_id": "secret"}
	var hits := QUERY.match_ranges(detail, "  nEeDlE  ")
	_expect(hits.size() == 3 and hits[0].field == "text" and hits[2].field == "title", "literal case-insensitive matches prefer original text before metadata")
	_expect(body.substr(hits[0].offset, hits[0].length) == "NEEDLE" and body.substr(hits[1].offset, hits[1].length) == "needle", "Korean and supplementary codepoints preserve character offsets")
	_expect(QUERY.match_ranges(detail, "secret").is_empty() and QUERY.match_ranges(detail, "\n \t").is_empty(), "private fields and blank input excluded")
	_expect(QUERY.match_ranges(detail, "[b]").size() == 1, "markup-like search is literal")
	var multiline := QUERY.match_ranges(detail, "needle.\n다음")
	_expect(multiline.size() == 1 and body.substr(multiline[0].offset, multiline[0].length) == "needle.\n다음", "matches may cross actual newlines inside one source")
	_expect(QUERY.match_ranges({"text": "aaaaa"}, "aa").size() == 2, "navigation uses nonoverlapping occurrences")


func _test_panel(tree: SceneTree, locale: String, size: Vector2, scale: float) -> void:
	var archive := ARCHIVE.create()
	var body := "첫 문단.\n" + "원문은 그대로 보존됩니다. ".repeat(220) + "[b]NEEDLE[/b] " + "이어지는 문장. ".repeat(70) + "needle\n마지막 문단."
	var legacy := {"chapter_notebook": {"long": body}}
	var query := QUERY.new()
	_expect(query.open(archive, KNOWLEDGE.create(), _scope(archive), locale, legacy).ok, "long legacy search fixture opens")
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(query.cache_key(), 50)
	var result := query.page({"tab": "clues", "needle": "needle"}, 0, query.cache_key())
	var key: String = result.items[0].key
	var panel := PANEL.new()
	panel.size = size
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(query, locale, "clues", scale)
	panel.set_filters({"tab": "clues", "needle": "needle"})
	panel.show_detail(key)
	await _settle(tree)
	_expect(panel._matches.size() == 2 and panel._match_index == 0, "explicit result opens its first body match")
	var paragraph = panel._paragraphs(panel._detail_scroll)[1]
	_expect(paragraph is RichTextLabel and paragraph.get_parsed_text() == body.split("\n")[1], "highlight preserves literal BBCode-like source and all characters")
	_expect(paragraph.get_character_line(panel._matches[0].offset - 6) > 0, "long single paragraph wraps before the match")
	_assert_visible(panel, paragraph, panel._matches[0].offset - 6)
	var first_scroll: int = panel._detail_scroll.scroll_vertical
	var next: Button = panel.find_child("NotebookMatchNext", true, false)
	next.grab_focus()
	next.pressed.emit()
	await _settle(tree)
	_expect(panel._match_index == 1 and panel._detail_scroll.scroll_vertical >= first_scroll, "next match advances within the same long paragraph; end-of-document scroll may already be clamped")
	_assert_visible(panel, paragraph, panel._matches[1].offset - 6)
	_expect(next.disabled and panel.get_viewport().gui_get_focus_owner() == panel.find_child("NotebookMatchPrevious", true, false), "last match leaves an enabled backward focus target")
	var cursor: Dictionary = panel.capture_view()
	panel.restore_view(cursor)
	await _settle(tree)
	_expect(abs(panel._detail_scroll.scroll_vertical - int(cursor.scroll)) < 5, "reopening search preserves saved body position rather than forcing first match")
	panel.find_child("NotebookMatchNext", true, false).pressed.emit()
	panel.set_tab("records")
	await _settle(tree)
	_expect(not panel._match_controls.visible and not panel._detail_visible, "tab change cancels delayed match navigation")
	panel.set_filters({"tab": "clues", "needle": "needle"})
	panel.show_detail(key)
	await _settle(tree)
	panel._clear_search()
	await _settle(tree)
	_expect(not panel._match_controls.visible and panel._paragraphs(panel._detail_scroll)[1] is Label, "clearing search removes highlighting without changing the original")
	panel.set_filters({"tab": "clues", "needle": "시점 미상" if locale == "ko-KR" else "unknown"})
	panel.show_detail(key)
	await _settle(tree)
	_expect(panel._matches.is_empty() and panel.find_child("NotebookMatchNext", true, false).disabled, "UI-only status labels are not counted as searchable original text")
	_expect(panel._close.get_global_rect().end.y <= panel.get_global_rect().end.y and panel._close.is_visible_in_tree(), "close remains inside 720p/1080p and 100/150/200 percent panel")
	panel.set_filters({"tab": "clues", "needle": "needle"})
	panel.show_detail(key)
	query.close()
	await _settle(tree)
	_expect(panel._selected.is_empty() and not panel._match_controls.visible, "closing query invalidates pending hit callbacks")
	panel.queue_free()
	await tree.process_frame


func _assert_visible(panel, label: RichTextLabel, column: int) -> void:
	var y: float = label.get_global_rect().position.y + label.get_line_offset(label.get_character_line(column))
	var rect: Rect2 = panel._detail_scroll.get_global_rect()
	_expect(y >= rect.position.y - 2 and y < rect.end.y, "exact wrapped line is visible after navigation")


func _settle(tree: SceneTree) -> void:
	for frame in range(5): await tree.process_frame


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: errors.append(message)
