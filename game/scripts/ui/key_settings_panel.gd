extends PanelContainer

signal apply_requested(bindings: Dictionary)
signal back_requested
const Bindings := preload("res://scripts/systems/key_bindings.gd")
var back := Button.new()
var apply := Button.new()
var restore := Button.new()
var cancel_capture := Button.new()
var message := Label.new()
var heading := Label.new()
var buttons: Dictionary = {}
var _draft: Dictionary = {}
var _capture := ""
var _english := false

func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.03, 0.045, 0.99)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, 16)
	add_theme_stylebox_override("panel", panel_style)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.1
	anchor_right = 0.9
	anchor_top = 0.08
	anchor_bottom = 0.92
	var body := VBoxContainer.new()
	add_child(body)
	body.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for id: String in Bindings.ACTIONS:
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 44
		buttons[id] = button
		rows.add_child(button)
		button.pressed.connect(func(): begin_capture(id))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	for button: Button in [cancel_capture, restore, back, apply]:
		body.add_child(button)
	cancel_capture.pressed.connect(_cancel_capture)
	restore.pressed.connect(func():
		_capture = ""
		_draft = Bindings.defaults()
		_refresh())
	back.pressed.connect(func():
		_capture = ""
		back_requested.emit())
	apply.pressed.connect(func():
		if _capture.is_empty() and Bindings.validate(_draft): apply_requested.emit(_draft.duplicate(true)))
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _capture = "")
	hide()

func load_values(value: Dictionary, locale: String) -> void:
	_english = locale.begins_with("en")
	_draft = value.duplicate(true)
	_capture = ""
	heading.text = "Keyboard settings" if _english else "키보드 설정"
	back.text = "Cancel / back" if _english else "취소 / 뒤로"
	apply.text = "Save and apply" if _english else "저장하고 적용"
	restore.text = "Restore defaults (apply to save)" if _english else "기본값 복원 (적용 시 저장)"
	cancel_capture.text = "Cancel key capture" if _english else "키 입력 취소"
	_refresh()

func begin_capture(id: String) -> void:
	if not buttons.has(id): return
	_capture = id
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _capture.is_empty():
		_cancel_capture()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _capture.is_empty() or not event is InputEventKey: return
	# Capture before GUI handling so Tab and Escape can themselves be assigned.
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	var code: int = event.get_keycode_with_modifiers()
	var candidate := _draft.duplicate(true)
	candidate[_capture] = [code]
	if not Bindings.validate(candidate):
		message.text = "Already assigned or unsupported. Try another key." if _english else "이미 할당되었거나 지원하지 않는 키입니다. 다른 키를 눌러 주세요."
		return
	var target: Button = buttons[_capture]
	_draft = candidate
	_capture = ""
	_refresh()
	target.grab_focus()

func _cancel_capture() -> void:
	_capture = ""
	_refresh()
	back.grab_focus()

func _refresh() -> void:
	for id: String in buttons:
		buttons[id].text = "%s: %s" % [Bindings.NAMES[id][1 if _english else 0], Bindings.caption(_draft[id])]
	message.text = ("Press a new key. Mouse buttons below remain available." if _english else "새 키를 눌러 주세요. 아래 버튼은 마우스로 사용할 수 있습니다.") if not _capture.is_empty() else ("Changes are saved only when applied." if _english else "변경 사항은 적용할 때만 저장됩니다.")
	apply.disabled = not _capture.is_empty()
	# Keep a closed focus cycle within the panel, including recovery buttons.
	var controls := interactive_controls()
	controls = controls.filter(func(control: Control): return not (control is BaseButton and control.disabled))
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])

func show_save_error() -> void:
	message.text = "Could not save. Previous controls remain active." if _english else "저장하지 못했습니다. 이전 조작 설정을 유지합니다."

func interactive_controls() -> Array[Control]:
	var result: Array[Control] = []
	for button: Button in buttons.values(): result.append(button)
	result.append_array([cancel_capture, restore, back, apply])
	return result
