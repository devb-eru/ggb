extends PanelContainer

# The host owns suspension, persistence and scope changes. This panel only reads.
signal close_requested
signal reference_requested(collection: String, reference: Dictionary, enabled: bool)
signal refresh_requested

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_responsive)
	set_process(false)


func present(model, locale: String, entry_tab: String = "clues", font_scale: float = 1.0) -> bool:
	if not is_node_ready() or entry_tab not in QUERY.TABS or not model.diagnostics().ready: return false
	query = model
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
	return true


func dismiss() -> void:
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


func set_reference_editable(enabled: bool) -> void:
	_reference_editable = enabled
	if not _selected.is_empty(): show_detail(_selected, false, true)


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
	return {"filters": _filters.duplicate(true), "anchor": query.anchor_for(_selected, _filters) if _valid() else {}, "page": _page, "selected": _selected, "scroll": _detail_scroll.scroll_vertical, "pair": _pair.duplicate(), "comparing": _comparison_mode, "side": _compact_side, "detail": _detail_visible, "back": _back_stack.duplicate(true)}


func replace_model(model, view: Dictionary) -> void:
	query = model
	_key = model.cache_key()
	_locale = "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	_filters = view.filters.duplicate(true)
	_search.text = _filters.get("needle", "")
	_page = view.page
	_selected = ""
	_clear(_detail)
	clear_command()
	_apply_labels()
	_refresh()
	_load_basket()
	for side in range(2): select_pair(side, view.pair[side])
	_back_stack = view.back.duplicate(true)
	if not view.selected.is_empty():
		var restored: Dictionary = query.anchor_page(_filters, view.anchor, _key)
		if not _back_stack.is_empty() and query.detail(view.selected, _key).ok:
			show_detail(view.selected, false, true)
			_detail_scroll.set_deferred("scroll_vertical", view.scroll)
		elif restored.ok and not restored.key.is_empty():
			_page = restored.page
			_refresh()
			show_detail(restored.key)
			_detail_scroll.set_deferred("scroll_vertical", view.scroll)
	_comparison_mode = view.comparing
	_compact_side = view.side
	_detail_visible = view.detail and not _selected.is_empty()
	_render_pair()


func set_tab(tab: String) -> void:
	if tab not in QUERY.TABS or not _valid(): return
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
	_filters = filters.duplicate(true)
	_page = 0
	_selected = ""
	_detail_visible = false
	_clear(_detail)
	_search.set_text(String(_filters.get("needle", "")))
	_refresh()
	return true


func show_detail(key: String, linked: bool = false, preserve_stack: bool = false) -> bool:
	if not _valid(): return false
	var result: Dictionary = query.detail(key, _key)
	_clear(_detail)
	if not result.ok:
		_label(_detail, _l("이 자료를 표시하지 못했습니다. 다른 기록은 계속 읽을 수 있습니다.", "This material could not be displayed. Other records remain available."))
		_detail_visible = true
		_responsive()
		return false
	if linked and not _selected.is_empty():
		_back_stack.append({"key": _selected, "scroll": _detail_scroll.scroll_vertical})
	elif not linked and not preserve_stack:
		_back_stack.clear()
	_selected = key
	_detail_visible = true
	_detail_scroll.scroll_vertical = 0
	_render_detail(_detail, result, true)
	_responsive()
	return true


func select_pair(side: int, key: String) -> bool:
	if not _valid() or side not in [0, 1]: return false
	var basket: Dictionary = query.comparison(_key)
	if not basket.ok: return false
	var found := key.is_empty()
	for item in basket.items:
		if item.key == key: found = true
	if not found: return false
	var other := 1 - side
	if not key.is_empty() and key == _pair[other]:
		_pair[other] = _pair[side]
	_pair[side] = key
	_render_pair()
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
			_page = 0
			_refresh()
	if not String(_filters.get("needle", "")).strip_edges().is_empty():
		var diagnostic: Dictionary = query.diagnostics()
		if diagnostic.indexed < diagnostic.index_total:
			query.index_step(_key, 12)
			# Do not reorder partial matches under the player's cursor.
			if query.diagnostics().indexed == diagnostic.index_total: _refresh()
			else: _status.text = _l("공개된 기록을 검색하는 중입니다...", "Searching disclosed records...")


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if _search.has_focus() or _search.has_ime_text(): return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _comparison_mode:
			_comparison_mode = false
			_responsive()
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
	_search.text_changed.connect(func(_value: String) -> void: _search_delay = 0.2)
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
		var chapter: String = _chapter.get_item_metadata(index)
		_filters.chapters = [] if chapter.is_empty() else [chapter]
		_page = 0
		_refresh())
	var bookmarks := _button(controls, "", func() -> void:
		_filters.bookmarks_only = not _filters.get("bookmarks_only", false)
		_page = 0
		_refresh(), "NotebookBookmarks")
	bookmarks.toggle_mode = true
	var previous_revisions := _button(controls, "", func() -> void:
		_filters.include_previous = not _filters.get("include_previous", false)
		_filters.include_refuted = _filters.include_previous
		_page = 0
		_refresh(), "NotebookPreviousRevisions")
	previous_revisions.toggle_mode = true
	_button(controls, "", func() -> void:
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
		_pair.reverse()
		_render_pair(), "NotebookSwapPair")
	_pair_switch = _button(_pair_controls, "", func() -> void:
		_compact_side = 1 - _compact_side
		_responsive(), "NotebookPairSwitch")
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


func _render_detail(target: VBoxContainer, result: Dictionary, with_links: bool) -> void:
	_label(target, result.title)
	var kind := _kind_label(result.kind)
	if not kind.is_empty(): _label(target, kind)
	if result.previous: _label(target, _l("이전에 작성된 내용", "Earlier revision"))
	var states := {"observed": _l("내용: 관찰", "Content: observed"), "hypothesis": _l("내용: 가설", "Content: hypothesis"), "verified": _l("내용: 검증됨", "Content: verified"), "refuted": _l("내용: 반박됨", "Content: refuted")}
	var sources := {"unverified": _l("출처: 미확인", "Source: unverified"), "identified": _l("출처: 식별됨", "Source: identified"), "authenticated": _l("출처: 인증됨", "Source: authenticated")}
	if states.has(result.epistemic): _label(target, states[result.epistemic])
	if sources.has(result.provenance): _label(target, sources[result.provenance])
	if result.legacy: _label(target, _l("이전 원문 · 당시 언어·획득 시점 미확인", "Earlier original text; original language / acquisition time unknown"))
	elif result.fallback: _label(target, _l("당시 보관된 원문", "Original recorded text") + " (" + result.viewed_locale + ")")
	if not result.summary.is_empty(): _label(target, result.summary)
	if not result.speaker.is_empty(): _label(target, result.speaker)
	_label(target, result.text)
	if with_links:
		if _reference_editable:
			var state: Dictionary = query.reference_state(result.key, _key)
			if state.ok:
				for collection in ["bookmarks", "comparison"]:
					var title := _l("책갈피 해제" if state[collection] else "책갈피 추가", "Remove bookmark" if state[collection] else "Add bookmark") if collection == "bookmarks" else _l("비교 묶음에서 빼기" if state[collection] else "비교에 담기", "Remove from comparison" if state[collection] else "Add to comparison")
					_button(target, title, func() -> void: reference_requested.emit(collection, state.reference, not state[collection]), "NotebookReference_" + collection)
		if not _back_stack.is_empty(): _button(target, _l("이전 자료로", "Back to previous material"), _back, "NotebookBack")
		for key in result.sources:
			_button(target, _l("연결된 원문 보기", "Read linked source"), show_detail.bind(key, true), "NotebookSource")


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


func _render_pair() -> void:
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


func _change_page(offset: int) -> void:
	_page += offset
	_refresh()
	_list_scroll.scroll_vertical = 0


func _return_to_list() -> void:
	_detail_visible = false
	_comparison_mode = false
	_responsive()
	for node in _list.get_children():
		if node is Button and node.get_meta("reference_key", "") == _selected:
			node.grab_focus()
			return
	_close.grab_focus()


func _back() -> void:
	if _back_stack.is_empty(): return
	var previous: Dictionary = _back_stack.pop_back()
	show_detail(previous.key, false, true)
	_detail_scroll.set_deferred("scroll_vertical", previous.scroll)


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


func _scroll(parent: Node, node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	return scroll


func _button(parent: Node, text: String, action: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(action)
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
	}
	return labels.get(kind, "")
