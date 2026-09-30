class_name UITitlePlaceholderArt
extends Control

@export var asset_id: StringName = &"UI_TITLE"
@export var overlay_only := false

var _motion_mode := "standard"
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("asset_id", String(asset_id))
	set_meta("is_placeholder", true)
	queue_redraw()


func _process(delta: float) -> void:
	if _motion_mode == "static":
		return
	_elapsed = fmod(_elapsed + delta, 12.0)
	queue_redraw()


func set_motion_mode(mode: String) -> void:
	_motion_mode = mode
	queue_redraw()


func _draw() -> void:
	var canvas_size := size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return
	if not overlay_only:
		_draw_background(canvas_size)
		_draw_checker_floor(canvas_size)
		_draw_gothic_frames(canvas_size)
		_draw_rose_window(canvas_size)
		_draw_crooked_portraits(canvas_size)
	_draw_data_layer(canvas_size)
	_draw_fractures(canvas_size)


func _draw_background(canvas_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color("05040d"))
	var band_height := canvas_size.y / 8.0
	for index in range(8):
		var intensity := 0.012 + float(index) * 0.004
		var color := Color(0.035 + intensity, 0.018 + intensity, 0.09 + intensity * 2.1, 1.0)
		draw_rect(Rect2(0.0, index * band_height, canvas_size.x, band_height + 1.0), color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(canvas_size.x * 0.48, 0.0),
			Vector2(canvas_size.x, 0.0),
			Vector2(canvas_size.x, canvas_size.y * 0.64),
			Vector2(canvas_size.x * 0.34, canvas_size.y * 0.53),
		]),
		Color(0.02, 0.16, 0.18, 0.19)
	)
	var vignette_width := canvas_size.x * 0.18
	var vignette_steps := 12
	var step_width := vignette_width / float(vignette_steps)
	for step in range(vignette_steps):
		var alpha := lerpf(0.48, 0.015, float(step) / float(vignette_steps - 1))
		draw_rect(Rect2(step * step_width, 0.0, step_width + 1.0, canvas_size.y), Color(0.01, 0.015, 0.03, alpha))
		draw_rect(
			Rect2(canvas_size.x - (step + 1) * step_width, 0.0, step_width + 1.0, canvas_size.y),
			Color(0.01, 0.015, 0.03, alpha)
		)


func _draw_checker_floor(canvas_size: Vector2) -> void:
	var horizon_y := canvas_size.y * 0.56
	var vanishing := Vector2(canvas_size.x * 0.61, horizon_y)
	var columns := 14
	var rows := 9
	for row in range(rows):
		var near_t := float(row + 1) / float(rows)
		var far_t := float(row) / float(rows)
		var near_depth := pow(near_t, 1.55)
		var far_depth := pow(far_t, 1.55)
		for column in range(columns):
			var bottom_left := lerpf(-canvas_size.x * 0.18, canvas_size.x * 1.18, float(column) / float(columns))
			var bottom_right := lerpf(-canvas_size.x * 0.18, canvas_size.x * 1.18, float(column + 1) / float(columns))
			var points := PackedVector2Array([
				Vector2(lerpf(vanishing.x, bottom_left, far_depth), lerpf(horizon_y, canvas_size.y, far_depth)),
				Vector2(lerpf(vanishing.x, bottom_right, far_depth), lerpf(horizon_y, canvas_size.y, far_depth)),
				Vector2(lerpf(vanishing.x, bottom_right, near_depth), lerpf(horizon_y, canvas_size.y, near_depth)),
				Vector2(lerpf(vanishing.x, bottom_left, near_depth), lerpf(horizon_y, canvas_size.y, near_depth)),
			])
			var color := Color(0.04, 0.24, 0.24, 0.30) if (row + column) % 2 == 0 else Color(0.34, 0.015, 0.31, 0.27)
			draw_colored_polygon(points, color)
	draw_line(Vector2(0.0, horizon_y), Vector2(canvas_size.x, horizon_y), Color(0.79, 0.05, 0.46, 0.20), 2.0)


func _draw_gothic_frames(canvas_size: Vector2) -> void:
	var baseline := canvas_size.y * 0.83
	for index in range(5):
		var frame_color := Color(0.58, 0.04, 0.48, 0.64) if index % 2 == 0 else Color(0.02, 0.43, 0.39, 0.60)
		var glow_color := Color(frame_color.r, frame_color.g, frame_color.b, 0.12)
		var center_x := canvas_size.x * (0.08 + float(index) * 0.205)
		var width := canvas_size.x * 0.17
		var height := canvas_size.y * (0.48 + float(index % 2) * 0.07)
		var left := center_x - width * 0.5
		var top := baseline - height
		draw_rect(Rect2(left - 5.0, top + width * 0.5, width + 10.0, height - width * 0.5), glow_color)
		draw_line(Vector2(left, baseline), Vector2(left, top + width * 0.5), frame_color, 2.0)
		draw_line(Vector2(left + width, baseline), Vector2(left + width, top + width * 0.5), frame_color, 2.0)
		draw_arc(Vector2(center_x, top + width * 0.5), width * 0.5, PI, TAU, 48, frame_color, 2.0)
		draw_line(Vector2(center_x, top), Vector2(center_x, baseline), Color(frame_color.r, frame_color.g, frame_color.b, 0.28), 1.0)
	draw_line(Vector2(0.0, baseline), Vector2(canvas_size.x, baseline), Color(0.79, 0.16, 0.42, 0.24), 2.0)


func _draw_rose_window(canvas_size: Vector2) -> void:
	var center := Vector2(canvas_size.x * 0.61, canvas_size.y * 0.19)
	var radius := minf(canvas_size.x, canvas_size.y) * 0.115
	draw_circle(center, radius + 16.0, Color(0.01, 0.02, 0.04, 0.74))
	for ring in range(1, 5):
		var ring_color := Color(0.82, 0.04, 0.48, 0.42) if ring % 2 == 0 else Color(0.20, 0.04, 0.62, 0.46)
		draw_circle(center, radius * float(ring) / 4.0, ring_color, false, 3.0)
	for spoke in range(16):
		var angle := TAU * float(spoke) / 16.0 + _elapsed * 0.008
		var inner := center + Vector2.from_angle(angle) * radius * 0.18
		var outer := center + Vector2.from_angle(angle + sin(float(spoke)) * 0.08) * radius
		draw_line(inner, outer, Color(0.92, 0.08, 0.58, 0.46), 2.0)
	draw_circle(center, radius * 0.16, Color(0.02, 0.48, 0.42, 0.40), false, 3.0)


func _draw_crooked_portraits(canvas_size: Vector2) -> void:
	var portraits := [
		{"position": Vector2(canvas_size.x * 0.35, canvas_size.y * 0.18), "size": Vector2(92, 132), "rotation": -0.10},
		{"position": Vector2(canvas_size.x * 0.79, canvas_size.y * 0.20), "size": Vector2(76, 106), "rotation": 0.12},
		{"position": Vector2(canvas_size.x * 0.86, canvas_size.y * 0.34), "size": Vector2(62, 86), "rotation": -0.07},
	]
	for index in range(portraits.size()):
		var portrait: Dictionary = portraits[index]
		var portrait_size: Vector2 = portrait["size"]
		draw_set_transform(portrait["position"], float(portrait["rotation"]))
		draw_rect(Rect2(-portrait_size * 0.5, portrait_size), Color(0.03, 0.01, 0.05, 0.78))
		var frame_color := Color(0.70, 0.08, 0.23, 0.58) if index % 2 == 0 else Color(0.03, 0.55, 0.38, 0.50)
		draw_rect(Rect2(-portrait_size * 0.5, portrait_size), frame_color, false, 5.0)
		draw_circle(Vector2.ZERO, minf(portrait_size.x, portrait_size.y) * 0.24, Color(0.43, 0.02, 0.42, 0.30), false, 3.0)
		draw_set_transform(Vector2.ZERO)


func _draw_data_layer(canvas_size: Vector2) -> void:
	var scan_alpha := 0.075
	if _motion_mode == "reduced":
		scan_alpha = 0.045
	elif _motion_mode == "static":
		scan_alpha = 0.025
	var scan_offset := 0.0 if _motion_mode == "static" else fmod(_elapsed * 18.0, 24.0)
	for y in range(int(-24.0 + scan_offset), int(canvas_size.y), 24):
		draw_line(Vector2(0.0, y), Vector2(canvas_size.x, y), Color(0.70, 0.10, 0.58, scan_alpha), 1.0)
	var grid_color := Color(0.10, 0.82, 0.58, 0.065)
	for x in range(int(canvas_size.x * 0.57), int(canvas_size.x), 42):
		draw_line(Vector2(x, 0.0), Vector2(x, canvas_size.y), grid_color, 1.0)
	for y in range(0, int(canvas_size.y), 42):
		draw_line(Vector2(canvas_size.x * 0.57, y), Vector2(canvas_size.x, y), grid_color, 1.0)


func _draw_fractures(canvas_size: Vector2) -> void:
	var origin := Vector2(canvas_size.x * 0.72, canvas_size.y * 0.23)
	var fracture_color := Color(0.84, 0.05, 0.62, 0.46)
	var branches := [
		[Vector2.ZERO, Vector2(42, 28), Vector2(76, 22), Vector2(112, 58)],
		[Vector2.ZERO, Vector2(-28, 42), Vector2(-18, 84), Vector2(-62, 116)],
		[Vector2.ZERO, Vector2(12, -36), Vector2(46, -74), Vector2(38, -118)],
	]
	for branch in branches:
		var points := PackedVector2Array()
		for point in branch:
			points.append(origin + point)
		draw_polyline(points, fracture_color, 2.0, true)
	var pulse := 0.12
	if _motion_mode == "standard":
		pulse += sin(_elapsed * 1.4) * 0.035
	draw_circle(origin, 10.0, Color(0.12, 0.94, 0.61, pulse), false, 2.0)
