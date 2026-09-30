extends "res://scripts/chapters/mirror_overlay_diagram.gd"

const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const LIGHT := Color(0.65, 0.92, 1.0)
const STOP := Color(1.0, 0.65, 0.36)
const ENTRY := Vector2(0, 1)
const FORK := Vector2(0, -0.1)
const SHORT := Vector2(-0.6, -0.45)
const RING := Vector2(1, -0.55)
const STEP_SECONDS := 0.95

var segments: Array = []
var verdict: Dictionary = {}
var steps: Array[PackedVector2Array] = []
var motion_mode := "standard"
var elapsed := 0.0
var finished := false


func configure(local: Dictionary, mode: String) -> void:
	turn_degrees = int(local["rotation"])
	mirrored = bool(local["flipped"])
	fixed_anchor = bool(local["anchored"])
	segments = local["path"].duplicate()
	verdict = RULES.inspect_trace(turn_degrees, mirrored, fixed_anchor, segments)
	motion_mode = mode
	steps.clear()
	if verdict["category"] == "anchor_missing":
		# The signal cannot enter the grooves until both reference frames align.
		steps.append(PackedVector2Array([_overlay_point(ENTRY), _overlay_point(ENTRY).lerp(ENTRY, 0.45)]))
	else:
		var position_on_route := ENTRY
		var verified_count: int = verdict["verified_prefix"].size()
		for index in range(mini(segments.size(), verified_count + 1)):
			var points := _segment_points(String(segments[index]), position_on_route)
			if index == verified_count and not verdict["ok"]:
				points = _portion(points, 0.45)
			steps.append(points)
			position_on_route = points[points.size() - 1]
	if steps.is_empty():
		steps.append(PackedVector2Array([ENTRY, ENTRY]))
	replay()


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(600, 280)
	replay()


func replay() -> void:
	elapsed = 0.0
	finished = motion_mode != "standard"
	set_process(not finished)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed = minf(elapsed + delta, steps.size() * STEP_SECONDS)
	finished = elapsed >= steps.size() * STEP_SECONDS
	set_process(not finished)
	queue_redraw()


func _segment_points(segment: String, start: Vector2) -> PackedVector2Array:
	match segment:
		"entry": return PackedVector2Array([start, ENTRY, FORK])
		"short_branch": return PackedVector2Array([start, FORK, SHORT, FORK])
		"long_branch": return PackedVector2Array([start, FORK, RING])
		"clockwise_ring", "counterclockwise_ring":
			var points := PackedVector2Array([start, RING])
			var direction := 1.0 if segment == "clockwise_ring" else -1.0
			for index in range(1, 49):
				points.append(Vector2(0.72, -0.55) + Vector2.RIGHT.rotated(direction * TAU * index / 48.0) * 0.28)
			return points
	return PackedVector2Array([start, start])


func _portion(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	var remaining := length * clampf(fraction, 0.0, 1.0)
	var result := PackedVector2Array([points[0]])
	for index in range(1, points.size()):
		var distance := points[index - 1].distance_to(points[index])
		if distance > remaining and distance > 0.0:
			result.append(points[index - 1].lerp(points[index], remaining / distance))
			return result
		result.append(points[index])
		remaining -= distance
	return result


func _screen(point: Vector2) -> Vector2:
	return size * Vector2(0.48, 0.49) + point * minf(size.x / 3.8, size.y / 2.8)


func _draw() -> void:
	super._draw()
	if steps.is_empty():
		return
	var progress := float(steps.size()) if finished else elapsed / STEP_SECONDS
	var head := _screen(steps[0][0])
	for index in range(steps.size()):
		if index > progress:
			break
		var portion := _portion(steps[index], clampf(progress - index, 0.0, 1.0))
		for point_index in range(1, portion.size()):
			var start := _screen(portion[point_index - 1])
			var end := _screen(portion[point_index])
			draw_line(start, end, Color(LIGHT, 0.12), 16.0, true)
			draw_line(start, end, LIGHT, 3.0, true)
			if start.distance_to(end) > 12.0:
				var middle := start.lerp(end, 0.6)
				var back := (start - end).normalized() * 7.0
				draw_line(middle, middle + back.rotated(0.6), LIGHT, 2.0, true)
				draw_line(middle, middle + back.rotated(-0.6), LIGHT, 2.0, true)
		head = _screen(portion[portion.size() - 1])
		# A separate tangent arrow remains legible on finely sampled circular grooves.
		if progress - index >= 0.6:
			var arrow_tail := _portion(steps[index], 0.54)
			var arrow_tip := _portion(steps[index], 0.6)
			var tip := _screen(arrow_tip[arrow_tip.size() - 1])
			var back := (_screen(arrow_tail[arrow_tail.size() - 1]) - tip).normalized() * 10.0
			draw_line(tip, tip + back.rotated(0.6), LIGHT, 2.0, true)
			draw_line(tip, tip + back.rotated(-0.6), LIGHT, 2.0, true)
		if not finished and index == mini(int(progress), steps.size() - 1):
			for particle in range(1, 7):
				var trail := _portion(steps[index], maxf(0.0, progress - index - particle * 0.035))
				draw_circle(_screen(trail[trail.size() - 1]), 4.0 - particle * 0.4, Color(LIGHT, 0.65 - particle * 0.08))
	if finished:
		if verdict.get("ok", false):
			draw_circle(head, 14.0, LIGHT, false, 3.0, true)
			draw_line(head + Vector2(-7, 0), head + Vector2(-1, 6), LIGHT, 3.0, true)
			draw_line(head + Vector2(-1, 6), head + Vector2(9, -7), LIGHT, 3.0, true)
		else:
			draw_line(head - Vector2(9, 9), head + Vector2(9, 9), STOP, 4.0, true)
			draw_line(head + Vector2(-9, 9), head + Vector2(9, -9), STOP, 4.0, true)
	else:
		draw_circle(head, 12.0, Color(LIGHT, 0.18))
		draw_circle(head, 5.0, Color.WHITE)
