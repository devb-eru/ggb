extends "res://scripts/ui/notebook_mirror_overlay_v1.gd"

var overlay_transparency := "balanced"


func layer_visibility() -> Dictionary:
	match overlay_transparency:
		"low": return {"groove": 0.45, "wave": 1.0}
		"high": return {"groove": 1.0, "wave": 0.4}
	return {"groove": 1.0, "wave": 1.0}


func _draw() -> void:
	var center := size * Vector2(0.48, 0.49)
	var scale_factor := minf(size.x / 3.8, size.y / 2.8)
	var visibility := layer_visibility()
	var groove := Color(0.75, 0.72, 0.62, visibility.groove)
	var wave := Color(0.55, 0.85, 1.0, visibility.wave)
	var branches: Array = [[Vector2(0, 1), Vector2(0, -0.1)], [Vector2(0, -0.1), Vector2(-0.6, -0.45)], [Vector2(0, -0.1), Vector2(1, -0.55)]]
	var ring: Array[Vector2] = []
	for index in range(33): ring.append(Vector2(0.72, -0.55) + Vector2.RIGHT.rotated(TAU * index / 32.0) * 0.28)
	branches.append(ring)
	for branch in branches:
		for index in range(branch.size() - 1):
			draw_line(center + branch[index] * scale_factor, center + branch[index + 1] * scale_factor, groove, 5.0, true)
			draw_dashed_line(center + _overlay_point(branch[index]) * scale_factor, center + _overlay_point(branch[index + 1]) * scale_factor, wave, 2.0, 5.0)
	var target := center + Vector2(0, 1) * scale_factor
	draw_circle(target, 9.0, Color(0.9, 0.85, 0.7), false, 2.0)
	var source := center + _overlay_point(Vector2(0, 1)) * scale_factor
	draw_rect(Rect2(source - Vector2(6, 6), Vector2(12, 12)), wave, false, 2.0)
