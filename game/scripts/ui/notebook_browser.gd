extends VBoxContainer

signal filter_selected(filters: Dictionary, detail_key: String)
signal material_selected(key: String)
signal dismissed
signal layout_changed

const ITEM := preload("res://scenes/ui/notebook/notebook_browse_item.tscn")
const ITEM_LABEL := preload("res://scenes/ui/notebook/notebook_browse_label.tscn")
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
var _apply: Button
var _reset: Button
var _previous: Button
var _next: Button
var _page_status: Label
var _base_theme: Theme
var _base_fonts: Dictionary = {}
var _font_scale := 1.0


func _ready() -> void:
	_ensure_scene()
	_heading = $Heading
	_actions = $Actions
	_back = $Actions/NotebookBrowseBack
	_apply = $Actions/NotebookApplyFilters
	_reset = $Actions/NotebookResetFilters
	_status = $NotebookBrowseScroll/Body/Status
	_items = $NotebookBrowseScroll/Body/Items
	_paging = $Paging
	_previous = $Paging/NotebookBrowsePrevious
	_next = $Paging/NotebookBrowseNext
	_page_status = $Paging/PageStatus
	_base_theme = theme
	for control in find_children("*", "Control", true, false):
		if control.has_theme_font_size_override("font_size"):
			_base_fonts[control] = control.get_theme_font_size("font_size")
	_back.pressed.connect(func() -> void:
		if _valid(): dismissed.emit())
	_apply.pressed.connect(func() -> void:
		if _valid(): filter_selected.emit(_draft.duplicate(true), ""))
	_reset.pressed.connect(func() -> void:
		if not _valid(): return
		_draft = {"tab": _draft.get("tab", "clues")}
		_draw())
	_previous.pressed.connect(_change_page.bind(-1))
	_next.pressed.connect(_change_page.bind(1))
	set_process(false)


func _ensure_scene() -> void:
	if has_node("NotebookBrowseScroll"): return
	# Legacy script.new() callers use the same authored children as PackedScene.
	var authored := load("res://scenes/ui/notebook/notebook_browser.tscn").instantiate() as Control
	theme = authored.theme
	size_flags_vertical = authored.size_flags_vertical
	for child in authored.get_children():
		_release_authored_owner(child)
		authored.remove_child(child)
		add_child(child)
	authored.free()
	hide()


func _release_authored_owner(node: Node) -> void:
	# A script.new() root is outside the original PackedScene ownership tree.
	node.owner = null
	for child in node.get_children(): _release_authored_owner(child)


func apply_font_scale(scale: float) -> void:
	_font_scale = clampf(scale, 1.0, 2.0)
	if _base_theme != null:
		theme = _base_theme.duplicate()
		theme.default_font_size = roundi(_base_theme.default_font_size * _font_scale)
	for control in _base_fonts:
		if is_instance_valid(control):
			control.add_theme_font_size_override("font_size", roundi(_base_fonts[control] * _font_scale))


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
	_back.text = _l("돌아가기", "Back")
	_apply.text = _l("적용", "Apply")
	_reset.text = _l("필터 초기화", "Reset filters")
	_apply.visible = _mode == "filters"
	_reset.visible = _mode == "filters"
	_paging.hide()
	if _mode == "filters": _draw_filters()
	elif _mode == "investigation": _draw_investigation()
	else: _draw_groups()
	_back.grab_focus()
	layout_changed.emit()


func _draw_filters() -> void:
	_heading.text = _l("공개된 자료의 필터", "Filters for disclosed materials")
	_status.text = _l("같은 항목 안에서는 하나라도 일치, 다른 항목끼리는 모두 일치합니다. 적용 전에는 기존 목록이 바뀌지 않습니다.", "Match any selection within a field, and all selected fields. The list changes only after Apply.")
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
		if not group.retention_notice.is_empty(): label += "\n" + group.retention_notice
		if _mode == "people":
			var preview: Dictionary = query.detail(group.last, _query_key)
			if preview.ok: label += "\n" + _l("최근 보관 원문: ", "Latest retained text: ") + String(preview.text).replace("\n", " ").left(120)
		var button := _button(_items, label, func() -> void:
			var selected := _draft.duplicate(true)
			selected.tab = "people" if _mode == "people" else "dialogue"
			selected[_mode] = [group.id]
			filter_selected.emit(selected, (group.last_line if not group.last_line.is_empty() else group.last) if _mode == "sessions" else ""), "NotebookGroup_" + String(group.id).sha256_text())
		button.set_meta("group_id", group.id)
	_previous.text = _l("이전 묶음 페이지", "Previous group page")
	_next.text = _l("다음 묶음 페이지", "Next group page")
	_update_paging(result.pages)


func _draw_investigation() -> void:
	_heading.text = _l("현재 조사 관련 자료", "Current investigation materials")
	_status.text = _l("이미 확인한 자료와 직접 연결된 출처만 표시합니다. 정답 목록이 아니며 기존 검색·필터는 바뀌지 않습니다. 분류 정보가 없는 이전 원문은 전체 수첩에서 읽을 수 있습니다.", "Only disclosed materials and their direct sources are shown. This is not an answer list; existing search and filters stay unchanged. Unclassified earlier text remains in the full notebook.")
	var result: Dictionary = query.investigation_page(_page, _query_key)
	if not result.ok: return
	_page = result.page
	_was_complete = true
	if result.items.is_empty(): _label(_items, _l("지금 묶어 볼 수 있는 보관 자료가 없습니다.", "There are no retained materials to group here."))
	for item in result.items:
		var label: String = item.title
		if item.previous: label = _l("[이전 내용] ", "[Earlier revision] ") + label
		if item.epistemic == "refuted": label = _l("[반박됨] ", "[Refuted] ") + label
		if not String(item.speaker).is_empty(): label += " / " + item.speaker
		label += "\n" + item.location_label
		var button := _button(_items, label, func() -> void: material_selected.emit(item.key), "NotebookInvestigationRow_" + String(item.key).sha256_text())
		button.set_meta("reference_key", item.key)
	_previous.text = _l("이전 자료 페이지", "Previous material page")
	_next.text = _l("다음 자료 페이지", "Next material page")
	_update_paging(result.pages)


func _change_page(direction: int) -> void:
	if not _valid(): return
	if direction < 0 and _previous.disabled: return
	if direction > 0 and _next.disabled: return
	_page += direction
	_draw()


func _update_paging(pages: int) -> void:
	_paging.show()
	_previous.disabled = _page == 0
	_next.disabled = _page + 1 >= pages
	_page_status.text = "%d / %d" % [_page + 1, pages]


func _valid() -> bool:
	return query != null and query.diagnostics().ready and query.cache_key() == _query_key


func _button(parent: Node, text: String, action: Callable, id: String) -> Button:
	var button := ITEM.instantiate() as Button
	button.name = id
	button.text = text
	if button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", roundi(button.get_theme_font_size("font_size") * _font_scale))
	var generation := _generation
	button.pressed.connect(func() -> void:
		if _valid() and generation == _generation: action.call())
	parent.add_child(button)
	return button


func _label(parent: Node, text: String) -> Label:
	var label := ITEM_LABEL.instantiate() as Label
	label.text = text
	if label.has_theme_font_size_override("font_size"):
		label.add_theme_font_size_override("font_size", roundi(label.get_theme_font_size("font_size") * _font_scale))
	parent.add_child(label)
	return label


func _clear(parent: Node) -> void:
	if not is_instance_valid(parent): return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _l(ko: String, en: String) -> String:
	return en if _locale.begins_with("en") else ko
