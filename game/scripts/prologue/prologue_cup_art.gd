extends Control

var handle_angle := PI
var _motion: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 65, Color("d4c8b5"))
	draw_arc(center, 59, 0, TAU, 64, Color("51433c"), 2, true)
	var handle := center + Vector2.from_angle(handle_angle) * 48
	draw_arc(handle, 16, 0, TAU, 32, Color("eee3cd"), 8, true)
	draw_circle(center, 42, Color("eee3cd"))
	draw_circle(center, 33, Color("593c29"))

func show_angle(target: float, reduced_motion: bool) -> void:
	if _motion != null: _motion.kill()
	if reduced_motion:
		handle_angle = target
		queue_redraw()
		return
	_motion = create_tween()
	_motion.tween_method(_set_angle, handle_angle, target, 0.45)

func _set_angle(value: float) -> void:
	handle_angle = value
	queue_redraw()
