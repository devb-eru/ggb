extends VBoxContainer

signal closed
signal view_changed(key: String, view: Dictionary)
const CANVAS := preload("res://scripts/ui/notebook_visual_canvas.gd")
var _canvas
var _body: VBoxContainer
var _return: Button
var _status: Label
var _query
var _query_key := ""
var _key := ""
var _locale := "ko-KR"
var _generation := 0


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_return = Button.new()
	_return.name = "NotebookVisualReturn"
	_return.pressed.connect(func() -> void:
		if _valid(): closed.emit())
	add_child(_return)
	var scroll := ScrollContainer.new()
	scroll.name = "NotebookVisualScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	hide()
	set_process(false)


func present(query, key: String, locale: String, position: Dictionary) -> bool:
	dismiss()
	var result: Dictionary = query.visual(key, query.cache_key())
	if not result.ok or result.material.is_empty(): return false
	_query = query
	_query_key = query.cache_key()
	_key = key
	_locale = locale
	_return.text = _l("자료로 돌아가기", "Back to material")
	_label(result.material.title)
	var controls := HFlowContainer.new()
	_body.add_child(controls)
	for spec in [["In", "확대", "Zoom in", 0.25, Vector2.ZERO], ["Out", "축소", "Zoom out", -0.25, Vector2.ZERO], ["Left", "왼쪽 이동", "Pan left", 0.0, Vector2(-0.15, 0)], ["Right", "오른쪽 이동", "Pan right", 0.0, Vector2(0.15, 0)], ["Up", "위로 이동", "Pan up", 0.0, Vector2(0, -0.15)], ["Down", "아래로 이동", "Pan down", 0.0, Vector2(0, 0.15)], ["Reset", "기본 위치", "Reset view", 0.0, Vector2.ZERO]]:
		var button := Button.new()
		button.name = "NotebookVisual" + spec[0]
		button.text = _l(spec[1], spec[2])
		var generation := _generation
		button.pressed.connect(func() -> void:
			if _valid() and generation == _generation: _canvas.adjust(spec[3], spec[4], spec[0] == "Reset"))
		controls.add_child(button)
	_status = _label("")
	_canvas = CANVAS.new()
	_canvas.name = "NotebookVisualCanvas"
	_canvas.custom_minimum_size = Vector2(0, 260)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_canvas)
	_canvas.configure(result.material, position)
	_canvas.view_changed.connect(func(view: Dictionary) -> void:
		if _valid():
			_update_status()
			view_changed.emit(_key, view))
	_update_status()
	_label(result.material.description)
	_label(_l("자료 영역에 포커스가 있을 때 방향키로 이동합니다. 휠 확대와 드래그는 보조 조작입니다. 퍼즐의 회전·배선·판정은 바뀌지 않습니다.", "Arrow keys pan only while the material has focus. Wheel zoom and dragging are optional. Puzzle rotation, wiring and judgment remain unchanged."))
	show()
	set_process(true)
	_return.grab_focus()
	return true


func dismiss() -> void:
	_generation += 1
	_query = null
	_query_key = ""
	_key = ""
	_canvas = null
	if is_instance_valid(_body):
		for child in _body.get_children():
			_body.remove_child(child)
			child.queue_free()
	hide()
	set_process(false)


func _process(_delta: float) -> void:
	if not _valid():
		dismiss()
		closed.emit()


func _valid() -> bool:
	return _query != null and _query.diagnostics().ready and _query.cache_key() == _query_key


func _update_status() -> void:
	_status.text = _l("배율 %d%%", "Zoom %d%%") % roundi(float(_canvas.view.zoom) * 100)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)
	return label


func _l(ko: String, en: String) -> String:
	return en if _locale.begins_with("en") else ko
