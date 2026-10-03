extends PanelContainer

# The host owns suspension, persistence and scope changes. This panel only reads.
signal close_requested
signal reference_requested(collection: String, reference: Dictionary, enabled: bool)
signal refresh_requested
signal material_viewed(key: String)
signal view_changed

const QUERY := preload("res://scripts/systems/notebook_query.gd")
var query
var _key := ""
var _locale := "ko-KR"
var _filters := {"tab": "clues"}
var _page := 0
var _selected := ""
var _back_stack: Array = []
var _pair := ["", ""]
var _comparison_mode := false
var _compact_side := 0
var _detail_visible := false
var _font_scale := 1.0
var _search_delay := -1.0
var _content: VBoxContainer
var _search: LineEdit
var _status: Label
var _body: HBoxContainer
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _tabs: Dictionary = {}
var _close: Button
var _previous: Button
var _next: Button
var _return_list: Button
var _chapter: OptionButton
var _pair_selectors: Array[OptionButton] = []
var _pair_body: HBoxContainer
var _pair_controls: HFlowContainer
var _pair_panels: Array[VBoxContainer] = []
var _pair_switch: Button
var _tools: HFlowContainer
var _command: VBoxContainer
var _notice: Label
var _reference_editable := false
var _seen: Dictionary = {}
var _seen_groups: Dictionary = {}
var _restoring_view := false
var _view_generation := 0
var _pending_restore: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_responsive)
	set_process(false)


func present(model, locale: String, entry_tab: String = "clues", font_scale: float = 1.0) -> bool:
	if not is_node_ready() or entry_tab not in QUERY.TABS or not model.diagnostics().ready: return false
	query = model
	_cancel_restoration()
	_restoring_view = true
	_seen.clear()
	_seen_groups.clear()
	_key = model.cache_key()
	_locale = "en-US" if locale.begins_with("en") else "ko-KR"
	_font_scale = clampf(font_scale, 1.0, 2.0)
	_filters = {"tab": entry_tab}
	_page = 0
	_selected = ""
	_pair = ["", ""]
	_comparison_mode = false
	_detail_visible = false
	_back_stack.clear()
	_search_delay = -1.0
	_search.clear()
	_apply_labels()
	_refresh()
	_load_basket()
	show()
	set_process(true)
	_close.grab_focus()
	_restoring_view = false
	return true


func dismiss() -> void:
	_cancel_restoration()
	set_process(false)
	hide()
	query = null
	_key = ""
	_selected = ""
	_pair = ["", ""]
	_back_stack.clear()
	_clear(_list)
	_clear(_detail)
	for panel in _pair_panels: _clear(panel)
	for selector in _pair_selectors: selector.clear()
	_clear(_tools)
	clear_command()
	_notice.text = ""
	_reference_editable = false
	_seen.clear()
	_seen_groups.clear()


func set_reference_editable(enabled: bool) -> void:
	_reference_editable = enabled
	if not _selected.is_empty(): show_detail(_selected, false, true, false)


func add_tool(label: String, action: Callable, id: String) -> void:
	_button(_tools, label, action, id)
	_cycle_focus.call_deferred()


func show_notice(message: String) -> void:
	_notice.text = message
	_cycle_focus.call_deferred()


func show_command(message: String, confirm: Callable, cancel: Callable) -> void:
	clear_command()
	_label(_command, message)
	var buttons := HFlowContainer.new()
	_command.add_child(buttons)
	_button(buttons, _l("실행 / 다시 시도", "Apply / retry"), confirm, "NotebookCommandConfirm")
	var back := _button(buttons, _l("취소", "Cancel"), cancel, "NotebookCommandCancel")
	back.grab_focus()
	_cycle_focus.call_deferred()


func clear_command() -> void:
	_clear(_command)
	_cycle_focus.call_deferred()


func capture_view() -> Dictionary:
	return {"filters": _filters.duplicate(true), "anchor": query.anchor_for(_selected, _filters) if _valid() else {}, "page": _page, "selected": _selected, "scroll": _detail_scroll.scroll_vertical, "list_scroll": _list_scroll.scroll_vertical, "list_anchor": _capture_list_anchor(), "body": _capture_body(_detail_scroll), "pair": _pair.duplicate(), "pair_body": [_capture_body(_pair_panels[0].get_parent()), _capture_body(_pair_panels[1].get_parent())], "comparing": _comparison_mode, "side": _compact_side, "detail": _detail_visible, "back": _back_stack.duplicate(true), "focus": _capture_focus()}


func set_review_state(seen: Array, groups: Array) -> void:
	_seen.clear()
	_seen_groups.clear()
	for key in seen: _seen[key] = true
	for group in groups: _seen_groups[group] = true
	_update_badges()


func open_latest_dialogue() -> void:
	if not _valid(): return
	var key: String = query.latest_dialogue_key()
	if key.is_empty(): return
	_page = query.anchor_page({"tab": "dialogue"}, query.anchor_for(key, {"tab": "dialogue"}), _key).page
	_refresh()
	show_detail(key, false, false, false)


func replace_model(model, view: Dictionary) -> void:
	query = model
	_key = model.cache_key()
	_locale = "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	clear_command()
	_apply_labels()
	restore_view(view)


func restore_view(view: Dictionary) -> void:
	if not _valid() or view.is_empty(): return
	_cancel_restoration()
	_restoring_view = true
	_pending_restore = view.duplicate(true)
	_filters = query.visible_filters(view.filters)
	_search.text = _filters.get("needle", "")
	_search_delay = -1.0
	_page = 0
	_selected = ""
	_back_stack.clear()
	_comparison_mode = false
	_detail_visible = false
	_clear(_detail)
	_refresh()
	_load_basket()
	if query.page(_filters, 0, _key).complete: _complete_restore()


func _complete_restore() -> void:
	if not _valid() or _pending_restore.is_empty(): return
	var view := _pending_restore.duplicate(true)
	_pending_restore.clear()
	for side in range(2): select_pair(side, view.pair[side], false)
	_back_stack = view.back.filter(func(step: Dictionary) -> bool: return not query.review_group(step.key).is_empty())
	var body: Dictionary = view.body
	if not view.selected.is_empty():
		var restored: Dictionary = query.anchor_page(_filters, view.anchor, _key)
		if not _back_stack.is_empty() and not query.review_group(view.selected).is_empty():
			show_detail(view.selected, false, true, false)
		elif restored.ok and not restored.key.is_empty():
			_page = restored.page
			_refresh()
			show_detail(restored.key, false, true, false)
		if _selected != view.selected:
			body = {"paragraph": -1, "fraction": 0.0}
			show_notice(_l("이 저장에서 이전 열람 위치를 확인할 수 없어 가까운 자료로 이동했습니다.", "The earlier position is unavailable in this save. Showing the nearest material."))
	else:
		var restored: Dictionary = query.anchor_page(_filters, view.list_anchor, _key)
		_page = restored.page
		_refresh()
	if not view.list_anchor.is_empty():
		_page = query.anchor_page(_filters, view.list_anchor, _key).page
		_refresh()
	_comparison_mode = view.comparing
	_compact_side = int(view.side)
	_detail_visible = view.detail and not _selected.is_empty()
	_render_pair(false)
	_finish_restore_layout.call_deferred(_view_generation, view, body)


func _finish_restore_layout(generation: int, view: Dictionary, body: Dictionary) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if generation != _view_generation or not _valid() or not is_inside_tree(): return
	_restore_body(_detail_scroll, body)
	_restore_list_anchor(view.list_anchor)
	for side in range(2):
		if _pair[side] == view.pair[side]: _restore_body(_pair_panels[side].get_parent(), view.pair_body[side])
	_restore_focus(view.focus)
	_restoring_view = false
	_changed()


func set_tab(tab: String) -> void:
	if tab not in QUERY.TABS or not _valid(): return
	_cancel_restoration()
	_filters.tab = tab
	_page = 0
	_selected = ""
	_detail_visible = false
	_back_stack.clear()
	_comparison_mode = false
	_clear(_detail)
	_refresh()


func set_filters(filters: Dictionary) -> bool:
	if not _valid(): return false
	var result: Dictionary = query.page(filters, 0, _key)
	if not result.ok: return false
	_cancel_restoration()
	_filters = filters.duplicate(true)
	_page = 0
	_selected = ""
	_detail_visible = false
	_clear(_detail)
	_search.set_text(String(_filters.get("needle", "")))
	_refresh()
	return true


func show_detail(key: String, linked: bool = false, preserve_stack: bool = false, mark_seen: bool = true) -> bool:
	if not _valid(): return false
	if mark_seen: _cancel_restoration()
	var result: Dictionary = query.detail(key, _key)
	var previous := {"key": _selected, "scroll": _detail_scroll.scroll_vertical, "body": _capture_body(_detail_scroll), "focus": _capture_focus()}
	_clear(_detail)
	if not result.ok:
		_label(_detail, _l("이 자료를 표시하지 못했습니다. 다른 기록은 계속 읽을 수 있습니다.", "This material could not be displayed. Other records remain available."))
		_detail_visible = true
		_responsive()
		return false
	if linked and not _selected.is_empty():
		_back_stack.append(previous)
		if _back_stack.size() > 32: _back_stack.pop_front()
	elif not linked and not preserve_stack:
		_back_stack.clear()
	_selected = key
	_detail_visible = true
	_detail_scroll.scroll_vertical = 0
	_render_detail(_detail, result, true)
	_responsive()
	if mark_seen: _mark_viewed(key)
	_changed()
	return true


func select_pair(side: int, key: String, mark_seen: bool = true) -> bool:
	if not _valid() or side not in [0, 1]: return false
	var basket: Dictionary = query.comparison(_key)
	if not basket.ok: return false
	var found := key.is_empty()
	for item in basket.items:
		if item.key == key: found = true
	if not found: return false
	if mark_seen: _cancel_restoration()
	var other := 1 - side
	if not key.is_empty() and key == _pair[other]:
		_pair[other] = _pair[side]
	_pair[side] = key
	_render_pair(mark_seen)
	return true


func visible_pair() -> Array:
	return _pair.duplicate()


func _process(delta: float) -> void:
	if not _valid():
		_clear(_list)
		_clear(_detail)
		for panel in _pair_panels: _clear(panel)
		for selector in _pair_selectors: selector.clear()
		_pair = ["", ""]
		_selected = ""
		_comparison_mode = false
		_detail_visible = false
		_responsive()
		_status.text = _l("자료가 바뀌었습니다. 수첩을 다시 열어 주세요.", "The source changed. Please reopen the notebook.")
		set_process(false)
		return
	if _search.has_ime_text():
		_search_delay = 0.2
		return
	if _search_delay >= 0.0:
		_search_delay -= delta
		if _search_delay <= 0.0:
			_filters.needle = _search.text
			_search_delay = -1.0
			_page = 0
			_refresh()
	if not String(_filters.get("needle", "")).strip_edges().is_empty():
		var diagnostic: Dictionary = query.diagnostics()
		if diagnostic.indexed < diagnostic.index_total:
			query.index_step(_key, 12)
			# Do not reorder partial matches under the player's cursor.
			if query.diagnostics().indexed == diagnostic.index_total:
				_refresh()
				if not _pending_restore.is_empty(): _complete_restore()
			else: _status.text = _l("공개된 기록을 검색하는 중입니다...", "Searching disclosed records...")


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if _search.has_focus() or _search.has_ime_text(): return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _comparison_mode:
			_comparison_mode = false
			_responsive()
			_changed()
		elif not _back_stack.is_empty():
			_back()
		elif _detail_visible:
			_return_to_list()
		elif not _search.text.is_empty():
			_clear_search()
		else:
			close_requested.emit()
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down"):
		var scroll := _detail_scroll if _detail_visible else _list_scroll
		if _comparison_mode:
			var side := _compact_side
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null and (_pair_panels[1] == focused or _pair_panels[1].is_ancestor_of(focused)): side = 1
			scroll = _pair_panels[side].get_parent() as ScrollContainer
		var direction := -1 if event.is_action_pressed("ui_page_up") else 1
		scroll.scroll_vertical += direction * maxi(40, int(scroll.size.y * 0.8))
		get_viewport().set_input_as_handled()


func _search_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE or _search.has_ime_text(): return
	if not _search.text.is_empty(): _clear_search()
	_close.grab_focus()
	_search.accept_event()


func _clear_search() -> void:
	_cancel_restoration()
	_search.clear()
	_search_delay = -1.0
	_filters.erase("needle")
	_page = 0
	_refresh()


func _build() -> void:
	_content = VBoxContainer.new()
	_content.name = "NotebookContent"
	add_child(_content)
	var top := HBoxContainer.new()
	_content.add_child(top)
	_search = LineEdit.new()
	_search.name = "NotebookSearch"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	top.add_child(_search)
	_search.text_changed.connect(func(_value: String) -> void:
		_cancel_restoration()
		_search_delay = 0.2)
	# Enter in the search field never opens a result or confirms a game choice.
	_search.text_submitted.connect(func(_value: String) -> void: _search_delay = 0.2)
	_search.gui_input.connect(_search_input)
	_close = _button(top, "", func() -> void: close_requested.emit(), "NotebookClose")
	var tabs := HFlowContainer.new()
	_content.add_child(tabs)
	for tab in QUERY.TABS:
		var button := _button(tabs, tab, set_tab.bind(tab), "NotebookTab_" + tab)
		button.toggle_mode = true
		_tabs[tab] = button
	var controls := HFlowContainer.new()
	_content.add_child(controls)
	_chapter = OptionButton.new()
	_chapter.name = "NotebookChapterFilter"
	controls.add_child(_chapter)
	_chapter.item_selected.connect(func(index: int) -> void:
		_cancel_restoration()
		var chapter: String = _chapter.get_item_metadata(index)
		_filters.chapters = [] if chapter.is_empty() else [chapter]
		_page = 0
		_refresh())
	var bookmarks := _button(controls, "", func() -> void:
		_cancel_restoration()
		_filters.bookmarks_only = not _filters.get("bookmarks_only", false)
		_page = 0
		_refresh(), "NotebookBookmarks")
	bookmarks.toggle_mode = true
	var previous_revisions := _button(controls, "", func() -> void:
		_cancel_restoration()
		_filters.include_previous = not _filters.get("include_previous", false)
		_filters.include_refuted = _filters.include_previous
		_page = 0
		_refresh(), "NotebookPreviousRevisions")
	previous_revisions.toggle_mode = true
	_button(controls, "", func() -> void:
		_cancel_restoration()
		_comparison_mode = not _comparison_mode
		_render_pair(), "NotebookCompare")
	_return_list = _button(controls, "", _return_to_list, "NotebookReturnList")
	_button(controls, "", func() -> void: refresh_requested.emit(), "NotebookRefresh")
	_tools = HFlowContainer.new()
	_content.add_child(_tools)
	_notice = _label(_content, "")
	_notice.name = "NotebookNotice"
	_command = VBoxContainer.new()
	_content.add_child(_command)
	_status = _label(_content, "")
	_status.name = "NotebookStatus"
	var pages := HBoxContainer.new()
	_content.add_child(pages)
	_previous = _button(pages, "", _change_page.bind(-1), "NotebookPreviousPage")
	_next = _button(pages, "", _change_page.bind(1), "NotebookNextPage")
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_body)
	_list_scroll = _scroll(_body, "NotebookListScroll")
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	_detail_scroll = _scroll(_body, "NotebookDetailScroll")
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail)
	_pair_controls = HFlowContainer.new()
	_content.add_child(_pair_controls)
	for side in range(2):
		var selector := OptionButton.new()
		selector.name = "NotebookPair" + str(side)
		selector.fit_to_longest_item = false
		selector.custom_minimum_size.x = 160
		_pair_controls.add_child(selector)
		_pair_selectors.append(selector)
		selector.item_selected.connect(func(index: int) -> void:
			select_pair(side, String(selector.get_item_metadata(index))))
	_button(_pair_controls, "", func() -> void:
		_cancel_restoration()
		_pair.reverse()
		_render_pair(), "NotebookSwapPair")
	_pair_switch = _button(_pair_controls, "", func() -> void:
		_cancel_restoration()
		_compact_side = 1 - _compact_side
		_responsive()
		_mark_visible_pair()
		_changed(), "NotebookPairSwitch")
	_pair_body = HBoxContainer.new()
	_pair_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_pair_body)
	for side in range(2):
		var scroll := _scroll(_pair_body, "NotebookCompareScroll" + str(side))
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		_pair_panels.append(body)


func _apply_labels() -> void:
	var names := [["단서", "Clues"], ["대화", "Dialogue"], ["기록", "Records"], ["인물", "People"]]
	for index in range(QUERY.TABS.size()): _tabs[QUERY.TABS[index]].text = _l(names[index][0], names[index][1])
	_close.text = _l("닫기", "Close")
	_search.placeholder_text = _l("공개된 기록 검색", "Search disclosed records")
	_previous.text = _l("이전 페이지", "Previous page")
	_next.text = _l("다음 페이지", "Next page")
	_return_list.text = _l("목록으로", "Back to list")
	find_child("NotebookBookmarks", true, false).text = _l("책갈피만", "Bookmarks only")
	find_child("NotebookPreviousRevisions", true, false).text = _l("이전·반박된 기록", "Previous / refuted records")
	find_child("NotebookCompare", true, false).text = _l("담아 둔 자료 비교", "Compare saved materials")
	find_child("NotebookRefresh", true, false).text = _l("갱신", "Refresh")
	find_child("NotebookSwapPair", true, false).text = _l("A/B 교환", "Swap A/B")
	_pair_switch.text = _l("A/B 화면 전환", "Switch A/B view")
	var notebook_theme := Theme.new()
	notebook_theme.default_font_size = roundi(18 * _font_scale)
	theme = notebook_theme


func _refresh() -> void:
	if not _valid(): return
	var result: Dictionary = query.page(_filters, _page, _key)
	if not result.ok: return
	_page = result.page
	_clear(_list)
	for item in result.items:
		var label: String = item.title
		var kind := _kind_label(item.kind)
		if not kind.is_empty(): label = "[" + kind + "] " + label
		if not String(item.speaker).is_empty(): label += " / " + item.speaker
		if item.bookmarked: label = _l("[책갈피] ", "[Bookmark] ") + label
		var preview: Dictionary = query.detail(item.key, _key)
		if preview.ok: label += "\n" + String(preview.text).replace("\n", " ").left(100)
		else: label += "\n" + _l("원문 표시 오류", "Original text unavailable")
		var button := _button(_list, label, show_detail.bind(item.key, false), "NotebookRow_" + String(item.key).sha256_text().left(16))
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = label
		button.set_meta("reference_key", item.key)
		button.set_meta("base_label", label)
		button.set_meta("legacy", item.legacy)
	if result.items.is_empty(): _label(_list, _l("표시할 기록이 없습니다.", "No records to show.") if result.complete else _l("검색 중입니다...", "Search in progress..."))
	_status.text = (_l("%d개 / %d·%d 페이지", "%d records / page %d of %d") % [result.count, result.page + 1, result.pages]) if result.complete else _l("공개된 기록을 검색하는 중입니다...", "Searching disclosed records...")
	if query.diagnostics().error_count > 0: _status.text += _l(" · 일부 기록을 표시하지 못했습니다.", " · Some records could not be displayed.")
	_previous.disabled = _page == 0
	_next.disabled = _page + 1 >= result.pages
	for tab in _tabs: _tabs[tab].set_pressed_no_signal(_filters.tab == tab)
	find_child("NotebookBookmarks", true, false).set_pressed_no_signal(_filters.get("bookmarks_only", false))
	find_child("NotebookPreviousRevisions", true, false).set_pressed_no_signal(_filters.get("include_previous", false))
	_chapter.clear()
	_chapter.add_item(_l("장: 전체", "Chapter: all"))
	_chapter.set_item_metadata(0, "")
	# Available chapter labels do not disappear merely because search has no match.
	var facet_filter := {"tab": _filters.tab, "include_previous": true, "include_refuted": true}
	var facets: Dictionary = query.facets(facet_filter, _key)
	var chapters := {"PROLOGUE": _l("프롤로그", "Prologue"), "CHAPTER_1": _l("1장", "Chapter 1"), "CHAPTER_2": _l("2장", "Chapter 2"), "CHAPTER_3": _l("3장", "Chapter 3"), "CHAPTER_4": _l("4장", "Chapter 4"), "LEGACY": _l("이전·미분류", "Earlier / unclassified")}
	for chapter in facets.values.chapters:
		_chapter.add_item(chapters.get(chapter, chapters.LEGACY))
		_chapter.set_item_metadata(_chapter.item_count - 1, chapter)
		if chapter in _filters.get("chapters", []): _chapter.select(_chapter.item_count - 1)
	_responsive()
	_update_badges()
	_changed()


func _render_detail(target: VBoxContainer, result: Dictionary, with_links: bool) -> void:
	_label(target, result.title)
	var kind := _kind_label(result.kind)
	if not kind.is_empty(): _label(target, kind)
	if result.previous: _label(target, _l("이전에 작성된 내용", "Earlier revision"))
	var states := {"observed": _l("내용: 관찰", "Content: observed"), "hypothesis": _l("내용: 가설", "Content: hypothesis"), "verified": _l("내용: 검증됨", "Content: verified"), "refuted": _l("내용: 반박됨", "Content: refuted")}
	var sources := {"unverified": _l("출처: 미확인", "Source: unverified"), "identified": _l("출처: 식별됨", "Source: identified"), "authenticated": _l("출처: 인증됨", "Source: authenticated")}
	if states.has(result.epistemic): _label(target, states[result.epistemic])
	if sources.has(result.provenance): _label(target, sources[result.provenance])
	if result.kind == "legacy_note":
		_label(target, _l("과거 갱신 시점·작성 언어 미상. 사라진 이전 내용은 복원하지 않습니다.", "Past update time / original language unknown. Earlier overwritten text is unavailable."))
		_label(target, _l("자료를 담을 때 보존한 원문", "Original text preserved when added") if result.note_snapshot else _l("기존 수첩에 남아 있는 마지막 값", "Last value remaining in the earlier notebook"))
	elif result.legacy: _label(target, _l("이전 원문 · 당시 언어·획득 시점 미확인", "Earlier original text; original language / acquisition time unknown"))
	elif result.fallback: _label(target, _l("당시 보관된 원문", "Original recorded text") + " (" + result.viewed_locale + ")")
	if not result.summary.is_empty(): _label(target, result.summary)
	if not result.speaker.is_empty(): _label(target, result.speaker)
	var paragraphs := VBoxContainer.new()
	paragraphs.name = "NotebookMaterialBody"
	paragraphs.add_theme_constant_override("separation", 0)
	target.add_child(paragraphs)
	var parts := String(result.text).split("\n", true)
	for index in range(parts.size()):
		var paragraph := _label(paragraphs, parts[index])
		paragraph.set_meta("paragraph", index)
		if parts[index].is_empty(): paragraph.custom_minimum_size.y = 18 * _font_scale
	if with_links:
		if _reference_editable:
			var state: Dictionary = query.reference_state(result.key, _key)
			if state.ok:
				for collection in ["bookmarks", "comparison"]:
					var title := _l("책갈피 해제" if state[collection] else "책갈피 추가", "Remove bookmark" if state[collection] else "Add bookmark") if collection == "bookmarks" else _l("비교 묶음에서 빼기" if state[collection] else "비교에 담기", "Remove from comparison" if state[collection] else "Add to comparison")
					_button(target, title, func() -> void: reference_requested.emit(collection, state.reference, not state[collection]), "NotebookReference_" + collection)
		if not _back_stack.is_empty(): _button(target, _l("이전 자료로", "Back to previous material"), _back, "NotebookBack")
		for key in result.sources:
			_button(target, _l("연결된 원문 보기", "Read linked source"), show_detail.bind(key, true), "NotebookSource_" + String(key).sha256_text())


func _load_basket() -> void:
	var basket: Dictionary = query.comparison(_key)
	if not basket.ok: return
	_pair = ["", ""]
	for side in range(2):
		var selector: OptionButton = _pair_selectors[side]
		selector.clear()
		selector.add_item(("A: " if side == 0 else "B: ") + _l("선택 없음", "None"))
		selector.set_item_metadata(0, "")
		for item in basket.items:
			selector.add_item("%d. %s" % [selector.item_count, item.title])
			selector.set_item_metadata(selector.item_count - 1, item.key)
		if side < basket.items.size(): _pair[side] = basket.items[side].key
	_render_pair()


func _render_pair(mark_seen: bool = true) -> void:
	if not _valid(): return
	for side in range(2):
		var selector: OptionButton = _pair_selectors[side]
		for index in range(selector.item_count):
			if selector.get_item_metadata(index) == _pair[side]: selector.select(index)
		_clear(_pair_panels[side])
		_label(_pair_panels[side], "A" if side == 0 else "B")
		if _comparison_mode and not _pair[side].is_empty():
			var result: Dictionary = query.detail(_pair[side], _key)
			if result.ok: _render_detail(_pair_panels[side], result, false)
			else: _label(_pair_panels[side], _l("자료를 표시하지 못했습니다.", "Unable to display this material."))
	_responsive()
	if mark_seen: _mark_visible_pair()
	_changed()


func _change_page(offset: int) -> void:
	_cancel_restoration()
	_page += offset
	_refresh()
	_list_scroll.scroll_vertical = 0
	_changed()


func _return_to_list() -> void:
	_cancel_restoration()
	_detail_visible = false
	_comparison_mode = false
	_responsive()
	_changed()
	for node in _list.get_children():
		if node is Button and node.get_meta("reference_key", "") == _selected:
			node.grab_focus()
			return
	_close.grab_focus()


func _back() -> void:
	if _back_stack.is_empty(): return
	var previous: Dictionary = _back_stack.pop_back()
	show_detail(previous.key, false, true)
	_restore_link_position.call_deferred(_view_generation, previous)


func _responsive() -> void:
	if not is_instance_valid(_body): return
	var compact := size.x < 1050 * _font_scale
	_body.visible = not _comparison_mode
	_list_scroll.visible = not compact or not _detail_visible
	_detail_scroll.visible = not compact or _detail_visible
	_return_list.visible = _detail_visible or _comparison_mode
	_pair_controls.visible = _comparison_mode
	_pair_body.visible = _comparison_mode
	_pair_switch.visible = compact
	for side in range(2): _pair_panels[side].get_parent().visible = not compact or side == _compact_side
	_cycle_focus.call_deferred()


func _cycle_focus() -> void:
	if not is_inside_tree() or not is_visible_in_tree(): return
	var controls: Array[Control] = []
	_collect_focus(self, controls)
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])


func _collect_focus(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			if not child is BaseButton or not child.disabled: controls.append(child)
		if not child is Window: _collect_focus(child, controls)


func _valid() -> bool:
	return query != null and not _key.is_empty() and query.diagnostics().ready and query.cache_key() == _key


func _cancel_restoration() -> void:
	_view_generation += 1
	_restoring_view = false
	_pending_restore.clear()


func _changed() -> void:
	if _valid() and not _restoring_view and is_visible_in_tree(): view_changed.emit()


func _mark_viewed(key: String) -> void:
	if not _valid() or _restoring_view or key.is_empty(): return
	var group: String = query.review_group(key)
	if group.is_empty() or _seen.has(key): return
	_seen[key] = true
	_seen_groups[group] = true
	_update_badges()
	material_viewed.emit(key)


func _mark_visible_pair() -> void:
	if not _comparison_mode: return
	for side in range(2):
		if _pair_panels[side].get_parent().is_visible_in_tree(): _mark_viewed(_pair[side])


func _update_badges() -> void:
	if not _valid() or not is_instance_valid(_list): return
	for node in _list.get_children():
		if not node is Button or not node.has_meta("base_label"): continue
		var key: String = node.get_meta("reference_key")
		var badge := ""
		if not _seen.has(key):
			if _seen_groups.has(query.review_group(key)): badge = _l("[갱신] ", "[Updated] ")
			elif node.get_meta("legacy", false): badge = _l("[미열람] ", "[Unread] ")
			else: badge = _l("[신규] ", "[New] ")
		node.text = badge + String(node.get_meta("base_label"))
		node.tooltip_text = node.text


func _capture_focus() -> Dictionary:
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus == null or not is_ancestor_of(focus): return {"control": "", "key": ""}
	return {"control": String(focus.name), "key": String(focus.get_meta("reference_key", ""))}


func _restore_focus(focus: Dictionary) -> void:
	var target: Control
	if not String(focus.key).is_empty():
		for node in _list.get_children():
			if node is Button and node.get_meta("reference_key", "") == focus.key: target = node
	elif String(focus.control).begins_with("Notebook"):
		target = find_child(focus.control, true, false) as Control
	if is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode == Control.FOCUS_ALL and not (target is BaseButton and target.disabled): target.grab_focus()
	elif _detail_visible and _return_list.is_visible_in_tree(): _return_list.grab_focus()
	else: _close.grab_focus()


func _capture_list_anchor() -> Dictionary:
	if not _valid(): return {}
	for node in _list.get_children():
		if not node is Button: continue
		var start: float = node.position.y
		if start + node.size.y < _list_scroll.scroll_vertical: continue
		var anchor: Dictionary = query.anchor_for(node.get_meta("reference_key", ""), _filters)
		if not anchor.is_empty(): anchor.fraction = clampf((_list_scroll.scroll_vertical - start) / maxf(node.size.y, 1.0), 0.0, 1.0)
		return anchor
	return {}


func _restore_list_anchor(anchor: Dictionary) -> void:
	if anchor.is_empty():
		_list_scroll.scroll_vertical = 0
		return
	var restored: Dictionary = query.anchor_page(_filters, anchor, _key)
	for node in _list.get_children():
		if node is Button and node.get_meta("reference_key", "") == restored.key:
			var fraction: float = anchor.fraction if restored.key == anchor.key else 0.0
			_list_scroll.scroll_vertical = roundi(node.position.y + node.size.y * fraction)
			return


func _paragraphs(scroll: ScrollContainer) -> Array:
	var body := scroll.find_child("NotebookMaterialBody", true, false)
	return body.get_children() if body != null else []


func _capture_body(scroll: ScrollContainer) -> Dictionary:
	var result := {"paragraph": -1, "fraction": 0.0}
	if scroll.get_child_count() == 0: return result
	for paragraph in _paragraphs(scroll):
		var start: float = paragraph.get_global_rect().position.y - scroll.get_child(0).get_global_rect().position.y
		if scroll.scroll_vertical < start: return result
		result = {"paragraph": int(paragraph.get_meta("paragraph")), "fraction": clampf((scroll.scroll_vertical - start) / maxf(paragraph.size.y, 1.0), 0.0, 1.0)}
		if scroll.scroll_vertical < start + paragraph.size.y: return result
	return result


func _restore_body(scroll: ScrollContainer, anchor: Dictionary) -> void:
	var paragraphs := _paragraphs(scroll)
	if int(anchor.paragraph) < 0 or paragraphs.is_empty():
		scroll.scroll_vertical = 0
		return
	var paragraph = paragraphs[mini(int(anchor.paragraph), paragraphs.size() - 1)]
	var start: float = paragraph.get_global_rect().position.y - scroll.get_child(0).get_global_rect().position.y
	scroll.scroll_vertical = roundi(start + paragraph.size.y * float(anchor.fraction))


func _restore_link_position(generation: int, previous: Dictionary) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if generation != _view_generation or not _valid() or _selected != previous.key: return
	_restore_body(_detail_scroll, previous.body)
	_restore_focus(previous.focus)
	_changed()


func _scroll(parent: Node, node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _changed())
	parent.add_child(scroll)
	return scroll


func _button(parent: Node, text: String, action: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(action)
	button.focus_entered.connect(_changed)
	parent.add_child(button)
	return button


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _l(ko: String, en: String) -> String:
	return en if _locale == "en-US" else ko


func _kind_label(kind: String) -> String:
	var labels := {
		"options_presented": _l("표시된 질문", "Presented options"),
		"choice_confirmed": _l("실제로 선택한 답", "Confirmed choice"),
		"choice_cancelled": _l("선택 취소", "Cancelled choice"),
		"hint_revealed": _l("요청한 힌트", "Requested hint"),
		"legacy_note": _l("시점 미상", "Time unknown"),
	}
	return labels.get(kind, "")
