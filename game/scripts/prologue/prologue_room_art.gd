class_name PrologueRoomArt
extends Control

var room_id := "M2_BEDROOM"
var task_state: Dictionary = {}


func set_room(next_room_id: String, next_task_state: Dictionary = {}) -> void:
	room_id = next_room_id
	task_state = next_task_state.duplicate(true)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.018, 0.055, 0.18))
	match room_id:
		"M2_BEDROOM":
			_draw_bedroom()
		"M1_PARLOR":
			_draw_parlor()
		"M1_LIBRARY_OUTER":
			_draw_library()
		"M1_NORTH_ARCHIVE_HALL":
			_draw_archive()
		"M1_KITCHEN":
			_draw_kitchen()
		"M1_GREENHOUSE_VESTIBULE":
			_draw_greenhouse()
		"M1_CENTRAL_HALL":
			_draw_hall_marks()


func _draw_bedroom() -> void:
	draw_rect(_rect(0.08, 0.57, 0.37, 0.29), Color(0.11, 0.055, 0.16, 0.86), true)
	draw_rect(_rect(0.075, 0.54, 0.38, 0.06), Color(0.35, 0.11, 0.22, 0.92), true)
	_draw_gilded_frame(_rect(0.67, 0.16, 0.18, 0.33), Color(0.28, 0.54, 0.72, 0.62))
	_draw_gilded_frame(_rect(0.48, 0.22, 0.11, 0.20), Color(0.56, 0.38, 0.19, 0.72))
	draw_circle(_point(0.535, 0.30), minf(size.x, size.y) * 0.035, Color(0.74, 0.67, 0.53, 0.45))
	draw_line(_point(0.19, 0.54), _point(0.19, 0.86), Color(0.72, 0.58, 0.38, 0.65), 4.0)


func _draw_parlor() -> void:
	var stages: Array = task_state.get("windows", [0, 0, 0])
	for index in range(3):
		var frame := _rect(0.15 + index * 0.23, 0.14, 0.17, 0.48)
		_draw_gilded_frame(frame, Color(0.37, 0.65, 0.83, 0.68))
		var stage := int(stages[index]) if index < stages.size() else 0
		if stage < 1:
			for streak in range(5):
				var y := frame.position.y + 35.0 + streak * 38.0
				draw_line(Vector2(frame.position.x + 15.0, y), Vector2(frame.end.x - 15.0, y + 24.0), Color(0.48, 0.42, 0.55, 0.75), 7.0)
		elif stage < 2:
			draw_circle(frame.get_center(), 48.0, Color(0.32, 0.23, 0.43, 0.55))
		elif stage < 3:
			for drop in range(4):
				var x := frame.position.x + 35.0 + drop * 34.0
				draw_line(Vector2(x, frame.position.y + 40.0), Vector2(x - 5.0, frame.end.y - 25.0), Color(0.38, 0.67, 0.86, 0.72), 4.0)
		else:
			draw_rect(frame.grow(-12.0), Color(0.38, 0.66, 0.88, 0.12), true)
	draw_circle(_point(0.81, 0.25), 56.0, Color(0.12, 0.08, 0.18, 0.90))
	draw_arc(_point(0.81, 0.25), 54.0, 0.0, TAU, 32, Color(0.74, 0.42, 0.24, 0.75), 5.0)


func _draw_library() -> void:
	for shelf in range(3):
		var shelf_rect := _rect(0.15 + shelf * 0.22, 0.18, 0.18, 0.47)
		draw_rect(shelf_rect, Color(0.10, 0.045, 0.055, 0.88), true)
		draw_rect(shelf_rect, Color(0.62, 0.31, 0.18, 0.72), false, 5.0)
		for row in range(4):
			var y := shelf_rect.position.y + 60.0 + row * 78.0
			draw_line(Vector2(shelf_rect.position.x + 8.0, y), Vector2(shelf_rect.end.x - 8.0, y), Color(0.63, 0.34, 0.24, 0.70), 3.0)
	for index in range(3):
		var book_x := 0.18 + index * 0.07
		draw_rect(_rect(book_x, 0.70, 0.045, 0.12), Color(0.18 + index * 0.12, 0.17, 0.35 - index * 0.06, 0.94), true)
	_draw_gilded_frame(_rect(0.76, 0.16, 0.16, 0.54), Color(0.23, 0.34, 0.66, 0.72))
	draw_line(_point(0.84, 0.16), _point(0.84, 0.70), Color(0.16, 0.24, 0.52, 0.82), 5.0)


func _draw_archive() -> void:
	var signature_colors: Array[Color] = [
		Color(0.18, 0.29, 0.62, 0.70),
		Color(0.86, 0.36, 0.12, 0.70),
		Color(0.48, 0.78, 0.24, 0.70),
		Color(0.94, 0.78, 0.32, 0.70),
		Color(0.50, 0.22, 0.75, 0.70),
	]
	for index in range(5):
		var x := 0.10 + index * 0.165
		var frame := _rect(x, 0.17 + (index % 2) * 0.04, 0.13, 0.30)
		var color: Color = signature_colors[index]
		_draw_gilded_frame(frame, color)
		draw_circle(frame.get_center() - Vector2(0.0, 28.0), 28.0, Color(0.16, 0.12, 0.20, 0.92))
		draw_rect(Rect2(frame.get_center() + Vector2(-34.0, 10.0), Vector2(68.0, 78.0)), Color(0.13, 0.09, 0.18, 0.90), true)
	draw_rect(_rect(0.24, 0.59, 0.52, 0.12), Color(0.16, 0.08, 0.20, 0.90), true)
	draw_rect(_rect(0.24, 0.59, 0.52, 0.12), Color(0.57, 0.29, 0.70, 0.66), false, 4.0)


func _draw_kitchen() -> void:
	draw_rect(_rect(0.17, 0.57, 0.62, 0.20), Color(0.13, 0.075, 0.055, 0.94), true)
	draw_rect(_rect(0.17, 0.57, 0.62, 0.20), Color(0.64, 0.34, 0.18, 0.78), false, 5.0)
	draw_circle(_point(0.48, 0.54), 64.0, Color(0.20, 0.22, 0.25, 0.96))
	draw_arc(_point(0.48, 0.54), 64.0, 0.0, TAU, 32, Color(0.62, 0.77, 0.50, 0.76), 5.0)
	draw_rect(_rect(0.59, 0.49, 0.07, 0.09), Color(0.79, 0.72, 0.58, 0.88), true)
	draw_circle(_point(0.625, 0.48), 20.0, Color(0.90, 0.84, 0.69, 0.85))
	for pipe in range(3):
		draw_line(_point(0.12 + pipe * 0.055, 0.18), _point(0.12 + pipe * 0.055, 0.54), Color(0.35, 0.42, 0.34, 0.72), 10.0)


func _draw_greenhouse() -> void:
	var glass := _rect(0.18, 0.12, 0.60, 0.58)
	draw_rect(glass, Color(0.08, 0.35, 0.38, 0.22), true)
	draw_rect(glass, Color(0.55, 0.79, 0.72, 0.58), false, 5.0)
	for index in range(10):
		var x := glass.position.x + 30.0 + index * (glass.size.x - 60.0) / 9.0
		draw_line(Vector2(x, glass.position.y + 18.0), Vector2(x - 28.0, glass.end.y - 18.0), Color(0.42, 0.72, 0.91, 0.76), 4.0)
	draw_rect(_rect(0.18, 0.70, 0.60, 0.035), Color(0.64, 0.44, 0.24, 0.96), true)
	draw_rect(_rect(0.80, 0.22, 0.11, 0.20), Color(0.58, 0.46, 0.25, 0.84), true)


func _draw_hall_marks() -> void:
	draw_arc(_point(0.50, 0.75), 145.0, 0.0, TAU, 64, Color(0.57, 0.22, 0.56, 0.34), 4.0)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		draw_line(_point(0.50, 0.75), _point(0.50, 0.75) + Vector2(cos(angle), sin(angle)) * 128.0, Color(0.31, 0.42, 0.68, 0.20), 2.0)


func _draw_gilded_frame(rect: Rect2, glow: Color) -> void:
	draw_rect(rect, Color(0.08, 0.045, 0.12, 0.90), true)
	draw_rect(rect, Color(0.62, 0.40, 0.20, 0.85), false, 7.0)
	draw_rect(rect.grow(-8.0), glow, false, 3.0)


func _rect(x: float, y: float, width: float, height: float) -> Rect2:
	return Rect2(size.x * x, size.y * y, size.x * width, size.y * height)


func _point(x: float, y: float) -> Vector2:
	return Vector2(size.x * x, size.y * y)
