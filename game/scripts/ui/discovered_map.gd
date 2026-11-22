extends PanelContainer
## Read-only map of places witnessed in this save. No movement or puzzle writes.
signal back_requested
const DESIGN := preload("res://scripts/ui/design_theme.gd")
const DISCOVERED_ROOMS := preload("res://scripts/systems/discovered_rooms.gd")
const DATA := "res://data/ui/discovered_map.json"
const FLOOR_NAMES := {"M2": ["2층", "Upper floor"], "M1": ["1층", "Ground floor"], "B1": ["지하", "Basement"], "H0": ["시설", "Facility"], "R0": ["현실", "Outside"]}
const CURRENT_ROOM := {"ko": "현재 공간", "en": "Current location", "position": [0, 0]}
var _rooms: Dictionary = {}
var _known: Dictionary = {}
var _current := ""
var _locale := "ko-KR"
var _font_scale := 1.0
var _shown_floor := ""
var _floor_dirty := true
var _floors: HFlowContainer
var _floor_buttons: Dictionary = {}
var _room_labels: Array[Label] = []
var _scroll: ScrollContainer
var _canvas: FloorCanvas
var _heading: Label
var _back: Button

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
	theme = DESIGN.make_theme(true, 20)
	add_theme_stylebox_override("panel", _paper_style())
	var body := VBoxContainer.new()
	add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_heading)
	_back = Button.new()
	_back.name = "MapBack"
	_back.text = "돌아가기 / Back"
	DESIGN.button(_back, true)
	_back.pressed.connect(func(): back_requested.emit())
	top.add_child(_back)
	_floors = HFlowContainer.new()
	body.add_child(_floors)
	for floor in FLOOR_NAMES:
		var button := Button.new()
		DESIGN.button(button, true)
		button.pressed.connect(_show_floor.bind(floor))
		button.hide()
		_floors.add_child(button)
		_floor_buttons[floor] = button
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.follow_focus = true
	_scroll.gui_input.connect(_pan)
	body.add_child(_scroll)
	_canvas = FloorCanvas.new()
	_scroll.add_child(_canvas)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_rooms = data.rooms
	_canvas.edges = data.edges
	hide()

func _paper_style() -> StyleBoxTexture:
	var paper: AtlasTexture = DESIGN.texture("map_paper")
	var style := StyleBoxTexture.new()
	style.texture = paper.atlas
	style.region_rect = paper.region
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 153.0)
		style.set_content_margin(side, 48.0)
	return style

func present(snapshot: Dictionary, current_room: String, locale: String, font_scale: float, witnessed: Dictionary = {}) -> void:
	present_known(DISCOVERED_ROOMS.known(snapshot), current_room, locale, font_scale, witnessed)

func present_known(known_rooms: Dictionary, current_room: String, locale: String, font_scale: float, witnessed: Dictionary = {}) -> void:
	var next_known := known_rooms.duplicate()
	next_known.merge(witnessed)
	next_known[current_room] = true
	if _known != next_known or _current != current_room or _locale != locale or _font_scale != font_scale:
		_known = next_known
		_current = current_room
		_locale = locale
		_font_scale = font_scale
		_floor_dirty = true
		_update_floor_controls()
	_show_floor(current_room.get_slice("_", 0))
	show()
	_back.grab_focus()

func _update_floor_controls() -> void:
	var font_size := roundi(20 * _font_scale)
	if theme.default_font_size != font_size: theme.default_font_size = font_size
	var english := _locale.begins_with("en")
	_heading.text = "Discovered spaces · ● You are here" if english else "발견한 공간 · ● 현재 위치"
	var known_floors := {}
	for id: String in _known:
		if "_" in id: known_floors[id.get_slice("_", 0)] = true
	for floor in _floor_buttons:
		var button: Button = _floor_buttons[floor]
		button.text = FLOOR_NAMES[floor][1 if english else 0]
		button.visible = known_floors.has(floor)

func _show_floor(floor: String) -> void:
	if not _floor_dirty and _shown_floor == floor: return
	_shown_floor = floor
	_floor_dirty = false
	_canvas.rectangles.clear()
	_canvas.current = _current
	var minimum := Vector2(INF, INF)
	var maximum := Vector2.ZERO
	var layout_scale := maxf(1, _font_scale * 0.8)
	var font_size := roundi(20 * _font_scale)
	for id in _known:
		if not id.begins_with(floor + "_") or (id != _current and not _rooms.has(id)): continue
		var point: Array = _rooms.get(id, CURRENT_ROOM).position
		var rect := Rect2(Vector2(point[0], point[1]) * Vector2(310, 210) * layout_scale, Vector2(250, 150) * layout_scale)
		_canvas.rectangles[id] = rect
		minimum = minimum.min(rect.position)
		maximum = maximum.max(rect.end)
	var label_index := 0
	for id in _canvas.rectangles:
		var rect: Rect2 = _canvas.rectangles[id]
		rect.position += Vector2(35, 35) - minimum
		_canvas.rectangles[id] = rect
		var label := _room_label(label_index)
		label_index += 1
		label.text = _rooms.get(id, CURRENT_ROOM)["en" if _locale.begins_with("en") else "ko"]
		if not label.has_theme_font_size_override("font_size") or label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)
		label.position = rect.position + Vector2(15, 45)
		label.size = rect.size - Vector2(30, 60)
		label.show()
	for index in range(label_index, _room_labels.size()):
		_room_labels[index].hide()
		_room_labels[index].text = ""
	_canvas.custom_minimum_size = maximum - minimum + Vector2(70, 70) if label_index > 0 else Vector2.ZERO
	_canvas.queue_redraw()

func _room_label(index: int) -> Label:
	if index < _room_labels.size(): return _room_labels[index]
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_canvas.add_child(label)
	_room_labels.append(label)
	return label

func _pan(event: InputEvent) -> void:
	if not event.is_pressed(): return
	var step := 60
	if event.is_action("ui_right"): _scroll.scroll_horizontal += step
	elif event.is_action("ui_left"): _scroll.scroll_horizontal -= step
	elif event.is_action("ui_down"): _scroll.scroll_vertical += step
	elif event.is_action("ui_up"): _scroll.scroll_vertical -= step
	else: return
	_scroll.accept_event()
