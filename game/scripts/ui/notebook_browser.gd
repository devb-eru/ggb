extends VBoxContainer

signal filter_selected(filters: Dictionary, detail_key: String)
signal dismissed
signal layout_changed

const LABELS := preload("res://scripts/systems/notebook_browse_labels.gd")
var query
var _query_key := ""
var _locale := "ko-KR"
var _mode := "filters"
var _draft: Dictionary = {}
var _page := 0
var _generation := 0
var _was_complete := true
var _items: VBoxContainer
var _heading: Label
var _status: Label
var _actions: HFlowContainer
var _paging: HFlowContainer
var _back: Button


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heading = _label(self, "")
	_actions = HFlowContainer.new()
	add_child(_actions)
	_status = _label(self, "")
	var scroll := ScrollContainer.new()
	scroll.name = "NotebookBrowseScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items)
	_paging = HFlowContainer.new()
	add_child(_paging)
	hide()
	set_process(false)


func present(mode: String, model, locale: String, filters: Dictionary) -> void:
	_generation += 1
	query = model
	_query_key = model.cache_key()
	_locale = locale
	_mode = mode
	_draft = filters.duplicate(true)
	_page = 0
	show()
	set_process(true)
	_draw()
	_back.grab_focus()


func dismiss() -> void:
	_generation += 1
	query = null
	_query_key = ""
	_draft.clear()
	_clear(_items)
	_clear(_actions)
	_clear(_paging)
	hide()
	set_process(false)


func _process(_delta: float) -> void:
	if not _valid():
		dismiss()
		dismissed.emit()
	elif not _was_complete and query.diagnostics().indexed == query.diagnostics().index_total:
		_draw()


func _draw() -> void:
	if not _valid(): return
	_generation += 1
	_clear(_items)
	_clear(_actions)
	_clear(_paging)
	_back = _button(_actions, _l("돌아가기", "Back"), func() -> void: dismissed.emit(), "NotebookBrowseBack")
	if _mode == "filters": _draw_filters()
	else: _draw_groups()
	_back.grab_focus()
	layout_changed.emit()


func _draw_filters() -> void:
	_heading.text = _l("공개된 자료의 필터", "Filters for disclosed materials")
	_status.text = _l("같은 항목 안에서는 하나라도 일치, 다른 항목끼리는 모두 일치합니다. 적용 전에는 기존 목록이 바뀌지 않습니다.", "Match any selection within a field, and all selected fields. The list changes only after Apply.")
	_button(_actions, _l("적용", "Apply"), func() -> void: filter_selected.emit(_draft.duplicate(true), ""), "NotebookApplyFilters")
	_button(_actions, _l("필터 초기화", "Reset filters"), func() -> void:
		_draft = {"tab": _draft.get("tab", "clues")}
		_draw(), "NotebookResetFilters")
	if not _draft.get("sessions", []).is_empty():
		_button(_items, _l("대화 묶음 제한 해제", "Clear conversation selection"), func() -> void:
			_draft.erase("sessions")
			_draw(), "NotebookClearSession")
	var available: Dictionary = query.facets({"tab": _draft.get("tab", "clues"), "include_previous": true, "include_refuted": true, "all_sections": _draft.get("all_sections", false)}, _query_key)
	for field in LABELS.FIELDS:
		if available.values[field].is_empty(): continue
		_label(_items, LABELS.pair(LABELS.FIELDS[field], _locale))
		for value in available.values[field]:
			var button := _button(_items, query.public_label(field, value), func() -> void:
				var chosen: Array = _draft.get(field, []).duplicate()
				if value in chosen: chosen.erase(value)
				else: chosen.append(value)
				_draft[field] = chosen, "NotebookFilter_" + field + "_" + String(value).sha256_text())
			button.toggle_mode = true
			button.set_pressed_no_signal(value in _draft.get(field, []))
			button.set_meta("filter_field", field)
			button.set_meta("filter_value", value)
	_was_complete = true


func _draw_groups() -> void:
	_heading.text = _l("인물별 보관 자료", "Records by person") if _mode == "people" else _l("사건별 대화 묶음", "Conversations by occurrence")
	var result: Dictionary = query.groups(_mode, _draft, _page, _query_key)
	if not result.ok: return
	_page = result.page
	_was_complete = result.complete
	_status.text = _l("보관 중인 공개 부분만 표시합니다. 정리된 일반 발언을 복원하거나 같은 내용의 재청취를 합치지 않습니다.", "Only retained, disclosed parts are shown. Pruned ordinary lines are not reconstructed; repeated conversations remain separate.")
	if not result.complete:
		_label(_items, _l("검색이 끝나면 묶음을 표시합니다...", "Groups will appear when search is complete..."))
		return
	if result.items.is_empty():
		_label(_items, _l("이 범위의 보관 자료가 없습니다.", "No retained materials in this scope."))
		_button(_items, _l("이 분류의 필터 해제", "Clear this section's filters"), func() -> void:
			_draft = {"tab": "people" if _mode == "people" else "dialogue"}
			_draw(), "NotebookBrowseClear")
	for group in result.items:
		var label: String = group.title
		label += "\n" + (_l("보관 부분 %d개 · 발언 %d개 · 그 밖의 기록 %d개", "%d retained parts · %d spoken parts · %d other parts") % [group.count, group.spoken, group.documents])
		label += "\n" + " / ".join(group.locations)
		if _mode == "sessions" and not group.names.is_empty(): label += "\n" + " / ".join(group.names)
		if _mode == "people":
			var preview: Dictionary = query.detail(group.last, _query_key)
			if preview.ok: label += "\n" + _l("최근 보관 원문: ", "Latest retained text: ") + String(preview.text).replace("\n", " ").left(120)
		var button := _button(_items, label, func() -> void:
			var selected := _draft.duplicate(true)
			selected.tab = "people" if _mode == "people" else "dialogue"
			selected[_mode] = [group.id]
			filter_selected.emit(selected, (group.last_line if not group.last_line.is_empty() else group.last) if _mode == "sessions" else ""), "NotebookGroup_" + String(group.id).sha256_text())
		button.set_meta("group_id", group.id)
	var previous := _button(_paging, _l("이전 묶음 페이지", "Previous group page"), func() -> void:
		_page -= 1
		_draw(), "NotebookBrowsePrevious")
	previous.disabled = _page == 0
	_label(_paging, "%d / %d" % [_page + 1, result.pages])
	var next := _button(_paging, _l("다음 묶음 페이지", "Next group page"), func() -> void:
		_page += 1
		_draw(), "NotebookBrowseNext")
	next.disabled = _page + 1 >= result.pages


func _valid() -> bool:
	return query != null and query.diagnostics().ready and query.cache_key() == _query_key


func _button(parent: Node, text: String, action: Callable, id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var generation := _generation
	button.pressed.connect(func() -> void:
		if _valid() and generation == _generation: action.call())
	parent.add_child(button)
	return button


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _clear(parent: Node) -> void:
	if not is_instance_valid(parent): return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _l(ko: String, en: String) -> String:
	return en if _locale.begins_with("en") else ko
