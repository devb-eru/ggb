extends Control

var turn_degrees := 0
var mirrored := false
var fixed_anchor := false

func _ready() -> void:
	custom_minimum_size = Vector2(600, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * Vector2(0.48, 0.49)
	var scale_factor := minf(size.x / 3.8, size.y / 2.8)
	var branches: Array = [
		[Vector2(0, 1), Vector2(0, -0.1)],
		[Vector2(0, -0.1), Vector2(-0.6, -0.45)],
		[Vector2(0, -0.1), Vector2(1, -0.55)],
	]
	var ring: Array[Vector2] = []
	for index in range(33):
		ring.append(Vector2(0.72, -0.55) + Vector2.RIGHT.rotated(TAU * index / 32.0) * 0.28)
	branches.append(ring)
	for branch in branches:
		for index in range(branch.size() - 1):
			draw_line(center + branch[index] * scale_factor, center + branch[index + 1] * scale_factor, Color(0.75, 0.72, 0.62), 5.0, true)
			var start := center + _overlay_point(branch[index]) * scale_factor
			var end := center + _overlay_point(branch[index + 1]) * scale_factor
			draw_dashed_line(start, end, Color(0.55, 0.85, 1.0), 2.0, 5.0)
	var target := center + Vector2(0, 1) * scale_factor
	draw_circle(target, 9.0, Color(0.9, 0.85, 0.7), false, 2.0)
	var source := center + _overlay_point(Vector2(0, 1)) * scale_factor
	draw_rect(Rect2(source - Vector2(6, 6), Vector2(12, 12)), Color(0.55, 0.85, 1.0), false, 2.0)


func _overlay_point(point: Vector2) -> Vector2:
	# Raw waveform starts a quarter turn away from the mirror's circuit.
	var transformed := point.rotated(-PI / 2.0)
	if mirrored: transformed.x = -transformed.x
	transformed = transformed.rotated(deg_to_rad(turn_degrees))
	if not fixed_anchor: transformed += Vector2(0.18, -0.16)
	return transformed
