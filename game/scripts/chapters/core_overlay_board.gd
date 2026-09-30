extends Control

const RULES := preload("res://scripts/systems/core_overlay.gd")
var state: Dictionary = RULES.initial()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.05, 0.95))
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 11.0
	for point in [Vector2.ZERO, Vector2(2,1),Vector2(1,2),Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
		draw_circle(center + point * unit, 7, Color(0.5,0.5,0.5), false, 2)
	for layer in RULES.LAYERS:
		var color := Color(1,0.8,0.4) if layer == "B4" else (Color(0.4,0.8,1) if layer == "C5" else Color.WHITE)
		color.a = float(state[layer]["opacity"]) / 100.0
		var points: Array = [Vector2.ZERO, Vector2(-2,-1)] if layer == "B4" else ([Vector2(0,3), Vector2.ZERO, Vector2(3,0), Vector2.ZERO, Vector2(0,-3), Vector2.ZERO, Vector2(-3,0),Vector2.ZERO,Vector2(1,2),Vector2(2,1)] if layer == "C5" else [Vector2(3,0),Vector2.ZERO,Vector2(0,3),Vector2.ZERO,Vector2(-3,0),Vector2.ZERO,Vector2(0,-3)])
		for index in range(points.size()-1):
			var a: Vector2 = center + RULES.point(points[index], state[layer]) * unit
			var b: Vector2 = center + RULES.point(points[index+1], state[layer]) * unit
			if layer == "B4": draw_dashed_line(a,b,color,3,7)
			else: draw_line(a,b,color,2 if layer == "D4" else 4)
		var anchor: Vector2 = center + RULES.point(Vector2.ZERO, state[layer]) * unit
		draw_string(ThemeDB.fallback_font, anchor + Vector2(8, -12 - RULES.LAYERS.find(layer)*18), layer, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var ring: Vector2 = center + RULES.point(Vector2(2,1), state["C5"]) * unit
	draw_arc(ring, unit*0.35,0,TAU,32,Color(0.4,0.8,1,float(state["C5"]["opacity"])/100.0),3)
