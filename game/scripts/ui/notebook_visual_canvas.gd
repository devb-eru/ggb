extends Control

signal view_changed(view: Dictionary)
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
var drawing: Dictionary = {}
var view := {"zoom": 1.0, "x": 0.0, "y": 0.0}
var _dragging := false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	focus_exited.connect(func() -> void: _dragging = false)


func configure(value: Dictionary, position: Dictionary = {}) -> void:
	drawing = value.duplicate(true)
	view = position.duplicate() if VISUALS.valid_view(position) else {"zoom": 1.0, "x": 0.0, "y": 0.0}
	queue_redraw()


func adjust(zoom_delta: float = 0.0, direction: Vector2 = Vector2.ZERO, reset: bool = false) -> void:
	view.zoom = 1.0 if reset else clampf(float(view.zoom) + zoom_delta, 1.0, 4.0)
	view.x = 0.0 if reset or view.zoom == 1.0 else clampf(float(view.x) + direction.x, -1.0, 1.0)
	view.y = 0.0 if reset or view.zoom == 1.0 else clampf(float(view.y) + direction.y, -1.0, 1.0)
	queue_redraw()
	view_changed.emit(view.duplicate())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed: grab_focus()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			adjust(0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_dragging = false
			return
		adjust(0, event.relative / maxf(1.0, minf(size.x, size.y) * (float(view.zoom) - 1.0) * 0.5))
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2(-0.1, 0)
			KEY_RIGHT: direction = Vector2(0.1, 0)
			KEY_UP: direction = Vector2(0, -0.1)
			KEY_DOWN: direction = Vector2(0, 0.1)
			_: return
		adjust(0, direction)
		accept_event()


func _point(raw: Array) -> Vector2:
	var unit := minf(size.x, size.y) / 9.0
	var pan := Vector2(view.x, view.y) * minf(size.x, size.y) * (float(view.zoom) - 1.0) * 0.5
	return size * 0.5 + pan + Vector2(raw[0], raw[1]) * unit * float(view.zoom)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.04))
	if drawing.is_empty(): return
	var ink := Color(0.93, 0.93, 0.90)
	for path in drawing.paths:
		var width: float = path.width * float(view.zoom)
		for index in range(path.points.size() - 1):
			if path.dashed: draw_dashed_line(_point(path.points[index]), _point(path.points[index + 1]), ink, width, 7.0)
			else: draw_line(_point(path.points[index]), _point(path.points[index + 1]), ink, width, true)
	for circle in drawing.circles:
		var radius: float = circle.radius * minf(size.x, size.y) / 9.0 * float(view.zoom)
		if circle.get("filled", false):
			draw_circle(_point(circle.point), radius, ink, true, -1, true)
		elif circle.dashed:
			for index in range(12): draw_arc(_point(circle.point), radius, TAU * index / 12, TAU * (index + 0.6) / 12, 5, ink, circle.width, true)
		else: draw_arc(_point(circle.point), radius, 0, TAU, 64, ink, circle.width, true)
	for point in drawing.squares:
		draw_rect(Rect2(_point(point) - Vector2(7, 7), Vector2(14, 14)), ink, false, 2)
	var font := get_theme_font("font")
	for line in drawing.get("text_runs", []):
		var natural := font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var fit := minf(1.0, minf(size.x, size.y) * 7.0 / 9.0 / maxf(natural, 1.0))
		draw_string(font, _point(line.point), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, roundi(24.0 * fit * float(view.zoom))), ink)
	if has_focus(): draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color.WHITE, false, 2)
