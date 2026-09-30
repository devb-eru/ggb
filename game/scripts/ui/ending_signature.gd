extends Control

signal signed
signal assistance_suggested

var _drawing := false
var _complete := false
var _points := PackedVector2Array()
var _distance := 0.0
var _elapsed := 0.0
var _suggested := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(delta: float) -> void:
	if _complete or not is_visible_in_tree() or not get_window().has_focus(): return
	_elapsed += delta
	if _elapsed >= 4.0 and not _suggested:
		_suggested = true
		assistance_suggested.emit()

func _gui_input(event: InputEvent) -> void:
	if _complete: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if event.pressed:
			_elapsed = 0.0
			_points.append(event.position)
		elif _distance >= 12.0: finish_signature()
		accept_event()
	elif event is InputEventMouseMotion and _drawing:
		_elapsed = 0.0
		if not _points.is_empty(): _distance += event.position.distance_to(_points[-1])
		_points.append(event.position.clamp(Vector2.ZERO, size))
		queue_redraw()
		accept_event()

func finish_signature() -> void:
	if _complete: return
	_complete = true
	signed.emit()

func _draw() -> void:
	draw_style_box(_paper(), Rect2(Vector2.ZERO, size))
	draw_line(Vector2(30, size.y * 0.65), Vector2(size.x - 30, size.y * 0.65), Color(0.5,0.5,0.5), 2.0)
	if _points.size() > 1: draw_polyline(_points, Color(0.15,0.15,0.15), 3.0, true)

func _paper() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.88,0.85,0.78)
	return box
