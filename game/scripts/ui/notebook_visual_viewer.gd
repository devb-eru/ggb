extends VBoxContainer

signal closed
signal view_changed(key: String, view: Dictionary)
const CANVAS := preload("res://scripts/ui/notebook_visual_canvas.gd")
var _canvas
var _body: VBoxContainer
var _return: Button
var _status: Label
var _title: Label
var _description: Label
var _help: Label
var _query
var _query_key := ""
var _key := ""
var _locale := "ko-KR"
var _generation := 0
var _base_theme: Theme
var _base_fonts: Dictionary = {}
const ACTIONS := [
	["In", "확대", "Zoom in", 0.25, Vector2.ZERO],
	["Out", "축소", "Zoom out", -0.25, Vector2.ZERO],
	["Left", "왼쪽 이동", "Pan left", 0.0, Vector2(-0.15, 0)],
	["Right", "오른쪽 이동", "Pan right", 0.0, Vector2(0.15, 0)],
	["Up", "위로 이동", "Pan up", 0.0, Vector2(0, -0.15)],
	["Down", "아래로 이동", "Pan down", 0.0, Vector2(0, 0.15)],
	["Reset", "기본 위치", "Reset view", 0.0, Vector2.ZERO],
]


func _ready() -> void:
	_ensure_scene()
	_return = $NotebookVisualReturn
	_body = $NotebookVisualScroll/Body
	_title = _body.get_node("Title")
	_status = _body.get_node("Status")
	_canvas = _body.get_node("NotebookVisualCanvas")
	_description = _body.get_node("Description")
	_help = _body.get_node("Help")
	_base_theme = theme
	for control in find_children("*", "Control", true, false):
		if control.has_theme_font_size_override("font_size"):
			_base_fonts[control] = control.get_theme_font_size("font_size")
	_return.pressed.connect(func() -> void:
		if _valid(): closed.emit())
	for spec in ACTIONS:
		var button: Button = _body.get_node("Controls/NotebookVisual" + spec[0])
		button.pressed.connect(func() -> void:
			if _valid(): _canvas.adjust(spec[3], spec[4], spec[0] == "Reset"))
	_canvas.view_changed.connect(func(view: Dictionary) -> void:
		if _valid():
			_update_status()
			view_changed.emit(_key, view))
	set_process(false)


func _ensure_scene() -> void:
	if has_node("NotebookVisualScroll"): return
	# Legacy script.new() callers use the same authored children as PackedScene.
	var authored := load("res://scenes/ui/notebook/notebook_visual_viewer.tscn").instantiate() as Control
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
	var factor := clampf(scale, 1.0, 2.0)
	if _base_theme != null:
		theme = _base_theme.duplicate()
		theme.default_font_size = roundi(_base_theme.default_font_size * factor)
	for control in _base_fonts:
		control.add_theme_font_size_override("font_size", roundi(_base_fonts[control] * factor))


func present(query, key: String, locale: String, position: Dictionary) -> bool:
	dismiss()
	var result: Dictionary = query.visual(key, query.cache_key())
	if not result.ok or result.material.is_empty(): return false
	_query = query
	_query_key = query.cache_key()
	_key = key
	_locale = locale
	_return.text = _l("자료로 돌아가기", "Back to material")
	_title.text = result.material.title
	_description.text = result.material.description
	_help.text = _l("자료 영역에 포커스가 있을 때 방향키로 이동합니다. 휠 확대와 드래그는 보조 조작입니다. 퍼즐의 회전·배선·판정은 바뀌지 않습니다.", "Arrow keys pan only while the material has focus. Wheel zoom and dragging are optional. Puzzle rotation, wiring and judgment remain unchanged.")
	for spec in ACTIONS:
		_body.get_node("Controls/NotebookVisual" + spec[0]).text = _l(spec[1], spec[2])
	_canvas.configure(result.material, position)
	_update_status()
	show()
	set_process(true)
	_return.grab_focus()
	return true


func dismiss() -> void:
	_generation += 1
	_query = null
	_query_key = ""
	_key = ""
	if is_instance_valid(_canvas):
		_canvas.configure({})
		_canvas._dragging = false
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


func _l(ko: String, en: String) -> String:
	return en if _locale.begins_with("en") else ko
