extends Control

const RULES := preload("res://scripts/systems/core_overlay.gd")
const PUBLIC_LABELS := preload("res://scripts/systems/notebook_puzzle_labels.gd")
const POINTS := {
	"B4": [[0,0],[-2,-1]],
	"C5": [[0,3],[0,0],[3,0],[0,0],[0,-3],[0,0],[-3,0],[0,0],[1,2],[2,1]],
	"D4": [[3,0],[0,0],[0,3],[0,0],[-3,0],[0,0],[0,-3]],
}
const MARKERS := [[0,0],[2,1],[1,2],[3,0],[-3,0],[0,3],[0,-3]]
var state: Dictionary = RULES.initial()


static func visual_manifest(layer: String) -> Dictionary:
	return {"kind":"core_overlay_v1", "layer":layer, "path":POINTS[layer].duplicate(true), "markers":MARKERS.duplicate(true),
		"pattern":"dashed" if layer == "B4" else "solid", "stroke_width":3 if layer == "B4" else (4 if layer == "C5" else 2),
		"ring_center":[2,1] if layer == "C5" else [], "ring_radius":0.35 if layer == "C5" else 0.0,
		"transform_order":["reflect_x", "rotate_clockwise", "anchor_offset"], "anchor_offsets":{"-1":[0,0], "0":[0,0], "1":[1,0], "2":[0,1]},
		"variables":{"degrees":"degrees", "flipped":"flipped", "anchor":"anchor", "opacity":"opacity"}}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.05, 0.95))
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 11.0
	for point in MARKERS:
		draw_circle(center + Vector2(point[0], point[1]) * unit, 7, Color(0.5,0.5,0.5), false, 2)
	for layer in RULES.LAYERS:
		var color := Color(1,0.8,0.4) if layer == "B4" else (Color(0.4,0.8,1) if layer == "C5" else Color.WHITE)
		color.a = float(state[layer]["opacity"]) / 100.0
		var points: Array = []
		for point in POINTS[layer]: points.append(Vector2(point[0], point[1]))
		for index in range(points.size()-1):
			var a: Vector2 = center + RULES.point(points[index], state[layer]) * unit
			var b: Vector2 = center + RULES.point(points[index+1], state[layer]) * unit
			if layer == "B4": draw_dashed_line(a,b,color,3,7)
			else: draw_line(a,b,color,2 if layer == "D4" else 4)
		var anchor: Vector2 = center + RULES.point(Vector2.ZERO, state[layer]) * unit
		draw_string(get_theme_font("font"), anchor + Vector2(8, -12 - RULES.LAYERS.find(layer)*18), PUBLIC_LABELS.layer_name(layer, TranslationServer.get_locale()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var ring: Vector2 = center + RULES.point(Vector2(2,1), state["C5"]) * unit
	draw_arc(ring, unit*0.35,0,TAU,32,Color(0.4,0.8,1,float(state["C5"]["opacity"])/100.0),3)
