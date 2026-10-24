extends PanelContainer
## Read-only map of places witnessed in this save. No movement or puzzle writes.
signal back_requested
const DESIGN := preload("res://scripts/ui/design_theme.gd")
const DATA := "res://data/ui/discovered_map.json"
var _rooms: Dictionary = {}
var _edges: Array = []
var _known: Dictionary = {}
var _current := ""
var _locale := "ko-KR"
var _font_scale := 1.0
var _floors: HFlowContainer
var _scroll: ScrollContainer
var _canvas: FloorCanvas
var _heading: Label

class FloorCanvas extends Control:
	var rectangles: Dictionary = {}
	var edges: Array = []
	var current := ""
	func _draw() -> void:
		var ink := Color("383039")
		for edge: Array in edges:
			if not rectangles.has(edge[0]) or not rectangles.has(edge[1]): continue
			var a: Vector2 = rectangles[edge[0]].get_center()
			var b: Vector2 = rectangles[edge[1]].get_center()
			var corner := Vector2(a.x, b.y)
			draw_polyline(PackedVector2Array([a, corner, b]), Color("8b7b72"), 8, true)
		for id in rectangles:
			var rect: Rect2 = rectangles[id]
			draw_rect(rect, Color("eee3ce"))
			draw_rect(rect, ink, false, 3)
			draw_rect(rect.grow(-6), ink, false, 1)
			var door := Vector2(rect.get_center().x, rect.end.y - 6)
			draw_arc(door, 24, -PI, -PI * 0.5, 16, ink, 1, true)
			draw_line(door, door - Vector2(24, 0), ink, 2, true)
			if id == current:
				draw_circle(rect.position + Vector2(25, 26), 9, Color.BLACK)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.07
	anchor_right = 0.93
	anchor_top = 0.08
	anchor_bottom = 0.92
	theme = DESIGN.make_theme(true)
	add_theme_stylebox_override("panel", DESIGN.box("map_paper", Color.WHITE, 48))
	var body := VBoxContainer.new()
	add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_heading)
	var back := Button.new()
	back.name = "MapBack"
	back.text = "돌아가기 / Back"
	DESIGN.button(back, true)
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	_floors = HFlowContainer.new()
	body.add_child(_floors)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.follow_focus = true
	_scroll.gui_input.connect(_pan)
	body.add_child(_scroll)
	_canvas = FloorCanvas.new()
	_scroll.add_child(_canvas)
	hide()

func present(snapshot: Dictionary, current_room: String, locale: String, font_scale: float, witnessed: Dictionary = {}) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_rooms = data.rooms
	_edges = data.edges
	_current = current_room
	_locale = locale
	_font_scale = font_scale
	theme = DESIGN.make_theme(true, roundi(20 * font_scale))
	_known = preload("res://scripts/systems/discovered_rooms.gd").known(snapshot)
	_known.merge(witnessed)
	_known[current_room] = true
	if not _rooms.has(current_room):
		_rooms[current_room] = {"ko": "현재 공간", "en": "Current location", "position": [0, 0]}
	_heading.text = "Discovered spaces · ● You are here" if locale.begins_with("en") else "발견한 공간 · ● 현재 위치"
	for child in _floors.get_children(): child.queue_free()
	var floor_names := {"M2":["2층","Upper floor"],"M1":["1층","Ground floor"],"B1":["지하","Basement"],"H0":["시설","Facility"],"R0":["현실","Outside"]}
	for floor in floor_names:
		if not _known.keys().any(func(id: String) -> bool: return id.begins_with(floor + "_")): continue
		var button := Button.new()
		button.text = floor_names[floor][1 if locale.begins_with("en") else 0]
		DESIGN.button(button, true)
		button.pressed.connect(_show_floor.bind(floor))
		_floors.add_child(button)
	_show_floor(current_room.get_slice("_", 0))
	show()
	(find_child("MapBack", true, false) as Button).grab_focus()

func _show_floor(floor: String) -> void:
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_canvas.rectangles.clear()
	_canvas.edges = _edges
	_canvas.current = _current
	var minimum := Vector2(INF, INF)
	var maximum := Vector2.ZERO
	var layout_scale := maxf(1, _font_scale * 0.8)
	for id in _known:
		if not id.begins_with(floor + "_") or not _rooms.has(id): continue
		var point: Array = _rooms[id].position
		var rect := Rect2(Vector2(point[0], point[1]) * Vector2(310, 210) * layout_scale, Vector2(250, 150) * layout_scale)
		_canvas.rectangles[id] = rect
		minimum = minimum.min(rect.position)
		maximum = maximum.max(rect.end)
	if _canvas.rectangles.is_empty(): return
	for id in _canvas.rectangles:
		var rect: Rect2 = _canvas.rectangles[id]
		rect.position += Vector2(35, 35) - minimum
		_canvas.rectangles[id] = rect
		var label := Label.new()
		label.text = _rooms[id]["en" if _locale.begins_with("en") else "ko"]
		label.position = rect.position + Vector2(15, 45)
		label.size = rect.size - Vector2(30, 60)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", roundi(20 * _font_scale))
		_canvas.add_child(label)
	_canvas.custom_minimum_size = maximum - minimum + Vector2(70, 70)
	_canvas.queue_redraw()

func _pan(event: InputEvent) -> void:
	if not event.is_pressed(): return
	var step := 60
	if event.is_action("ui_right"): _scroll.scroll_horizontal += step
	elif event.is_action("ui_left"): _scroll.scroll_horizontal -= step
	elif event.is_action("ui_down"): _scroll.scroll_vertical += step
	elif event.is_action("ui_up"): _scroll.scroll_vertical -= step
	else: return
	_scroll.accept_event()
