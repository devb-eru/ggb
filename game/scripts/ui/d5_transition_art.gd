extends Control

# Developer visualization. Final masks, projections and sky assets replace this node.
const OWNERS := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
const PATTERNS := {
	"EDGAR": "vertical_lock",
	"MARA1": "diagonal_wipe",
	"LUCA": "double_pulse",
	"IRIS": "petal_halo",
	"MARA2": "stacked_frame",
}
const SIGNATURE_COLORS := {
	"EDGAR": Color("1f2a5a"),
	"MARA1": Color("e9782d"),
	"LUCA": Color("b7f34a"),
	"IRIS": Color("f5d978"),
	"MARA2": Color("8d5bd6"),
}

var reveal_progress := 0.0
var focus_owner := ""
var motion_mode := "standard"
var elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("asset_id", "D5_TRANSITION_DEVELOPER_LAYER")
	set_meta("is_placeholder", true)
	set_meta("final_asset_pending", true)
	set_process(motion_mode == "standard")
	queue_redraw()


func present(progress: float, selected_owner: String, mode: String) -> void:
	reveal_progress = clampf(progress, 0.0, 1.0)
	focus_owner = selected_owner if selected_owner in OWNERS else ""
	motion_mode = mode if mode in ["standard", "reduced", "static"] else "standard"
	set_process(motion_mode == "standard")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + minf(delta, 0.1), 8.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var progress := smoothstep(0.0, 1.0, reveal_progress)
	draw_rect(Rect2(0, 90, size.x, size.y - 90), Color(0.015, 0.012, 0.025, 0.08 + progress * 0.34))
	_draw_wiring(progress)
	_draw_peeling_edges(progress)
	_draw_sky(progress)
	_draw_projections(progress)


func _draw_wiring(progress: float) -> void:
	if progress <= 0.08:
		return
	var alpha := clampf((progress - 0.08) / 0.45, 0.0, 1.0)
	for index in range(12):
		var x := size.x * (0.08 + float(index) * 0.078)
		var bend := sin(float(index) * 1.7) * 44.0
		var color := Color(0.08, 0.72, 0.58, 0.10 + alpha * 0.28) if index % 2 == 0 else Color(0.75, 0.05, 0.46, 0.08 + alpha * 0.24)
		draw_polyline(PackedVector2Array([
			Vector2(x, 100),
			Vector2(x + bend, size.y * 0.36),
			Vector2(x - bend * 0.4, size.y * 0.68),
			Vector2(x + bend * 0.7, size.y),
		]), color, 2.0, true)
	for row in range(5):
		var y := size.y * (0.25 + float(row) * 0.14)
		draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.90, y + sin(float(row)) * 22.0), Color(0.16, 0.55, 0.62, 0.08 + alpha * 0.14), 1.0, true)


func _draw_peeling_edges(progress: float) -> void:
	if progress <= 0.20:
		return
	var alpha := clampf((progress - 0.20) / 0.45, 0.0, 1.0)
	var left := size.x * lerpf(0.48, 0.12, alpha)
	var right := size.x * lerpf(0.52, 0.88, alpha)
	var top := 112.0
	var bottom := size.y * 0.82
	var edge := Color(0.86, 0.69, 0.48, 0.16 + alpha * 0.32)
	draw_polyline(PackedVector2Array([
		Vector2(left, top),
		Vector2(left + 30, top + 120),
		Vector2(left - 18, top + 250),
		Vector2(left + 22, bottom),
	]), edge, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(right, top),
		Vector2(right - 34, top + 145),
		Vector2(right + 20, top + 300),
		Vector2(right - 18, bottom),
	]), edge, 4.0, true)


func _draw_sky(progress: float) -> void:
	if progress <= 0.42:
		return
	var alpha := clampf((progress - 0.42) / 0.38, 0.0, 1.0)
	var center := Vector2(size.x * 0.60, size.y * 0.19)
	var half_width := size.x * (0.08 + alpha * 0.15)
	var slit := PackedVector2Array([
		center + Vector2(-half_width, -36),
		center + Vector2(-half_width * 0.82, 44),
		center + Vector2(half_width, 28),
		center + Vector2(half_width * 0.90, -48),
	])
	draw_colored_polygon(slit, Color(0.005, 0.012, 0.055, 0.30 + alpha * 0.58))
	draw_polyline(PackedVector2Array([slit[0], slit[1], slit[2], slit[3], slit[0]]), Color(0.52, 0.30, 0.78, 0.18 + alpha * 0.38), 2.0, true)
	for index in range(15):
		var px := lerpf(center.x - half_width * 0.78, center.x + half_width * 0.78, float((index * 7) % 15) / 14.0)
		var py := center.y + lerpf(-24.0, 25.0, float((index * 11) % 15) / 14.0)
		draw_circle(Vector2(px, py), 1.5 + float(index % 3), Color(0.83, 0.87, 0.98, 0.24 + alpha * 0.58))


func _draw_projections(progress: float) -> void:
	if progress <= 0.62:
		return
	var alpha := clampf((progress - 0.62) / 0.30, 0.0, 1.0)
	var pulse := 1.0
	if motion_mode == "standard":
		pulse = 0.88 + sin(elapsed * 2.1) * 0.12
	for index in range(OWNERS.size()):
		var owner: String = OWNERS[index]
		var center := Vector2(size.x * (0.18 + float(index) * 0.16), size.y * 0.55)
		var selected := focus_owner == owner
		var width := 5.0 if selected else 2.0
		var owner_alpha := alpha * (0.88 if selected else 0.36) * (pulse if selected else 1.0)
		var color: Color = SIGNATURE_COLORS[owner]
		color.a = owner_alpha
		draw_circle(center + Vector2(0, -55), 30, Color(0.03, 0.04, 0.07, owner_alpha * 0.48))
		draw_arc(center + Vector2(0, -55), 30, 0, TAU, 40, color, width, true)
		draw_rect(Rect2(center + Vector2(-34, -20), Vector2(68, 110)), color, false, width)
		_draw_signature(owner, center, color, width)


func _draw_signature(owner: String, center: Vector2, color: Color, width: float) -> void:
	match PATTERNS[owner]:
		"vertical_lock":
			for offset in [-18, 0, 18]:
				draw_line(center + Vector2(offset, -102), center + Vector2(offset, 104), color, width, true)
		"diagonal_wipe":
			for offset in [-28, -8, 12, 32]:
				draw_line(center + Vector2(-52, offset + 50), center + Vector2(52, offset - 50), color, width, true)
		"double_pulse":
			draw_arc(center + Vector2(-18, -55), 42, -PI * 0.65, PI * 0.65, 32, color, width, true)
			draw_arc(center + Vector2(18, -55), 42, PI * 0.35, PI * 1.65, 32, color, width, true)
		"petal_halo":
			for angle in range(0, 360, 60):
				var direction := Vector2.from_angle(deg_to_rad(float(angle)))
				draw_circle(center + Vector2(0, -55) + direction * 48, 10, color, false, width, true)
		"stacked_frame":
			draw_rect(Rect2(center + Vector2(-48, -105), Vector2(78, 190)), color, false, width)
			draw_rect(Rect2(center + Vector2(-30, -92), Vector2(78, 190)), color, false, width)
