class_name PrologueWindowInspectionArt
extends Control

var window_index := 0
var window_state: Dictionary = {}
var _fall_progress := -1.0
var _feedback_color := Color.TRANSPARENT
var _active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_window_state(next_window_index: int, next_state: Dictionary) -> void:
	window_index = next_window_index
	window_state = next_state.duplicate(true)
	queue_redraw()


func play_falling_dust() -> void:
	_stop_animation()
	_fall_progress = 0.0
	_active_tween = create_tween()
	_active_tween.tween_method(func(value: float) -> void:
		_fall_progress = value
		queue_redraw()
	, 0.0, 1.0, 0.65)
	_active_tween.tween_callback(func() -> void:
		_fall_progress = -1.0
		queue_redraw()
	)


func play_feedback(color: Color) -> void:
	_stop_animation()
	_feedback_color = Color(color, 0.42)
	_active_tween = create_tween()
	_active_tween.tween_method(func(alpha: float) -> void:
		_feedback_color.a = alpha
		queue_redraw()
	, 0.42, 0.0, 0.45)


func _stop_animation() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var frame := Rect2(size.x * 0.06, size.y * 0.04, size.x * 0.88, size.y * 0.92)
	draw_rect(frame, Color(0.055, 0.027, 0.075, 0.98), true)
	draw_rect(frame, Color(0.68, 0.42, 0.20, 0.95), false, 12.0)
	var glass := frame.grow(-24.0)
	draw_rect(glass, Color(0.16, 0.31, 0.43, 0.88), true)
	var third := glass.size.y / 3.0
	for divider in range(1, 3):
		var y := glass.position.y + third * divider
		draw_line(Vector2(glass.position.x, y), Vector2(glass.end.x, y), Color(0.76, 0.66, 0.53, 0.72), 3.0)
	_draw_top_dust(Rect2(glass.position, Vector2(glass.size.x, third)))
	_draw_middle_stain(Rect2(glass.position + Vector2(0.0, third), Vector2(glass.size.x, third)))
	_draw_bottom_wet(Rect2(glass.position + Vector2(0.0, third * 2.0), Vector2(glass.size.x, third)))
	if _fall_progress >= 0.0:
		_draw_falling_dust(glass)
	if _feedback_color.a > 0.0:
		draw_rect(glass, _feedback_color, true)
	if _is_clean():
		for shine in range(3):
			var x := glass.position.x + glass.size.x * (0.24 + shine * 0.25)
			draw_line(Vector2(x, glass.position.y + 22.0), Vector2(x - 100.0, glass.end.y - 22.0), Color(0.76, 0.91, 1.0, 0.30), 12.0)


func _draw_top_dust(zone: Rect2) -> void:
	if not bool(window_state.get("top_dust", true)):
		return
	var spread := bool(window_state.get("dust_spread", false))
	for particle in range(18):
		var column := particle % 6
		var row := particle / 6
		var x_ratio := 0.08 + column * 0.17
		if spread:
			x_ratio = 0.02 + column * 0.195
		var point := zone.position + Vector2(zone.size.x * x_ratio, 28.0 + row * 34.0 + (column % 2) * 9.0)
		draw_circle(point, 7.0 if spread else 5.0, Color(0.64, 0.57, 0.62, 0.82))
	if spread:
		for streak in range(4):
			var y := zone.position.y + 30.0 + streak * 32.0
			draw_line(Vector2(zone.position.x + 18.0, y), Vector2(zone.end.x - 18.0, y + 18.0), Color(0.58, 0.49, 0.56, 0.64), 8.0)


func _draw_middle_stain(zone: Rect2) -> void:
	if not bool(window_state.get("middle_stain", true)):
		return
	var center := zone.get_center()
	match window_index % 3:
		0:
			draw_arc(center, minf(zone.size.x, zone.size.y) * 0.27, 0.2, TAU - 0.5, 42, Color(0.34, 0.21, 0.35, 0.78), 18.0)
		1:
			for ring in range(3):
				draw_arc(center + Vector2(ring * 18.0 - 18.0, 0.0), 42.0 + ring * 12.0, 0.0, TAU, 32, Color(0.30, 0.20, 0.35, 0.66), 11.0)
		2:
			for streak in range(5):
				var offset := -100.0 + streak * 48.0
				draw_line(center + Vector2(offset, -55.0), center + Vector2(offset + 64.0, 58.0), Color(0.36, 0.22, 0.37, 0.72), 13.0)


func _draw_bottom_wet(zone: Rect2) -> void:
	if not bool(window_state.get("bottom_wet", false)):
		return
	for drop in range(7):
		var x := zone.position.x + zone.size.x * (0.10 + drop * 0.13)
		var top := zone.position.y + 16.0 + (drop % 3) * 18.0
		draw_line(Vector2(x, top), Vector2(x - 8.0, top + 80.0 + (drop % 2) * 35.0), Color(0.43, 0.75, 0.94, 0.86), 7.0)
		draw_circle(Vector2(x - 8.0, top + 86.0 + (drop % 2) * 35.0), 9.0, Color(0.43, 0.75, 0.94, 0.78))


func _draw_falling_dust(glass: Rect2) -> void:
	for particle in range(12):
		var x := glass.position.x + glass.size.x * (0.08 + (particle % 6) * 0.17)
		var stagger := float(particle / 6) * 0.18
		var travel := fposmod(_fall_progress + stagger, 1.0)
		var y := glass.position.y + glass.size.y * travel
		draw_circle(Vector2(x, y), 6.0, Color(0.72, 0.61, 0.58, 0.88 * (1.0 - travel * 0.45)))


func _is_clean() -> bool:
	return not bool(window_state.get("top_dust", true)) \
		and not bool(window_state.get("middle_stain", true)) \
		and not bool(window_state.get("bottom_wet", false)) \
		and not bool(window_state.get("dust_spread", false))
