extends CanvasLayer

signal jump_requested(id: String)
signal resume_requested
signal menu_opened
signal menu_closed

var launch_button: Button
var panel: PanelContainer
var blocker: ColorRect
var search: LineEdit
var list: ItemList
var detail: Label
var jump_button: Button
var rows: Array[Dictionary] = []
var filtered: Array[Dictionary] = []
var selected_id := ""
var _previous_focus: WeakRef


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	launch_button = Button.new()
	launch_button.text = "개발자 · F10"
	root.add_child(launch_button)
	launch_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	launch_button.offset_left = -225
	launch_button.offset_top = 8
	launch_button.offset_right = -12
	launch_button.offset_bottom = 60
	launch_button.pressed.connect(toggle)
	blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.8)
	root.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.hide()
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 110
	panel.offset_top = 80
	panel.offset_right = -110
	panel.offset_bottom = -70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.075, 1)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.add_theme_font_size_override("font_size", 24)
	panel.add_child(column)
	var title := Label.new()
	title.text = "개발자 모드 · 시점 / 이벤트 이동"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	var notice := Label.new()
	notice.text = "이동 시 선택한 시점의 초기 상태로 시작합니다. 기존 개발 테스트 진행은 대체됩니다.\n일반 저장 슬롯은 보존됩니다. 개발 테스트는 전체 게임 모드의 별도 슬롯·엔딩 기록을 사용합니다."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	search = LineEdit.new()
	search.placeholder_text = "이벤트 ID, 이름, 공간 검색 (예: C4, 거울, P4, E3_5, EDR_FIELD_NOTEBOOK)"
	search.custom_minimum_size.y = 55
	column.add_child(search)
	search.text_changed.connect(_filter)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 180
	list.add_theme_font_size_override("font_size", 25)
	column.add_child(list)
	list.item_selected.connect(_select)
	list.item_activated.connect(func(index: int): _select(index); _jump())
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 65
	column.add_child(detail)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	jump_button = _button(buttons, "선택한 시점에서 새 테스트", _jump)
	var resume := _button(buttons, "마지막 개발 테스트 이어하기", func(): resume_requested.emit())
	var cancel := _button(buttons, "닫기 · Esc", close)
	var controls: Array[Control] = [search, list, jump_button, resume, cancel]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])
	panel.hide()
	_filter("")


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 62
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func toggle() -> void:
	if panel.visible: close()
	else:
		_previous_focus = weakref(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner() != null else null
		panel.show()
		blocker.show()
		menu_opened.emit()
		search.grab_focus()


func close() -> void:
	if not panel.visible: return
	panel.hide()
	blocker.hide()
	menu_closed.emit()
	var previous = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			toggle()
			get_viewport().set_input_as_handled()
		elif panel.visible and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _filter(query: String) -> void:
	list.clear()
	filtered.clear()
	selected_id = ""
	jump_button.disabled = true
	for row in rows:
		if not query.is_empty() and not (String(row.id) + " " + String(row.title) + " " + String(row.room)).to_lower().contains(query.to_lower()): continue
		filtered.append(row)
		list.add_item("%s  |  %s" % [row.id, row.title])
	detail.text = "%d개 시점 · 목록에서 선택하세요." % filtered.size()
	if not filtered.is_empty():
		list.select(0)
		_select(0)


func _select(index: int) -> void:
	if index < 0 or index >= filtered.size(): return
	var row := filtered[index]
	selected_id = row.id
	jump_button.disabled = false
	detail.text = "%s · %s\n공간: %s / 루프: %d / 일지: %d단계 / 관계 결산: %s" % [row.id, row.title, row.room, row.day, row.journal, row.tier]


func _jump() -> void:
	if not selected_id.is_empty(): jump_requested.emit(selected_id)
