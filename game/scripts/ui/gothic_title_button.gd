class_name GothicTitleButton
extends Button

@export var menu_index := "00"
@export_enum("primary", "secondary") var chrome_role := "primary"

var _motion_mode := "standard"
var _elapsed := 0.0


func _ready() -> void:
	mouse_entered.connect(_queue_visual_refresh)
	mouse_exited.connect(_queue_visual_refresh)
	focus_entered.connect(_queue_visual_refresh)
	focus_exited.connect(_queue_visual_refresh)
	button_down.connect(_queue_visual_refresh)
	button_up.connect(_queue_visual_refresh)
	resized.connect(_queue_visual_refresh)
	_apply_text_treatment()
	queue_redraw()


func _process(delta: float) -> void:
	if _motion_mode != "standard" or disabled or not has_focus():
		return
	_elapsed = fmod(_elapsed + delta, TAU)
	queue_redraw()


func set_motion_mode(mode: String) -> void:
	_motion_mode = mode
	set_process(mode == "standard")
	queue_redraw()


func _queue_visual_refresh() -> void:
	queue_redraw()


func _apply_text_treatment() -> void:
	add_theme_color_override("font_color", Color(0.9, 0.87, 0.84, 1.0))
	add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.76, 1.0))
	add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.5, 1.0))
	add_theme_color_override("font_focus_color", Color(1.0, 0.93, 0.76, 1.0))
	add_theme_color_override("font_outline_color", Color(0.015, 0.008, 0.02, 0.96))
	add_theme_constant_override("outline_size", 4)


func _draw() -> void:
	if size.x < 48.0 or size.y < 24.0:
		return
	var active := not disabled and (is_hovered() or has_focus() or button_pressed)
	var primary := chrome_role == "primary"
	var frame_color := Color(0.72, 0.08, 0.18, 0.78) if primary else Color(0.42, 0.12, 0.28, 0.62)
	var accent_color := Color(1.0, 0.37, 0.09, 0.96) if primary else Color(0.35, 0.82, 0.78, 0.78)
	if active:
		frame_color = Color(0.94, 0.08, 0.36, 0.94)
	if disabled:
		frame_color.a = 0.24
		accent_color.a = 0.22
	var pulse := 1.0
	if active and has_focus() and _motion_mode == "standard":
		pulse = 0.86 + sin(_elapsed * 4.0) * 0.12
		accent_color.a *= pulse

	var left := 7.0
	var right := size.x - 7.0
	var top := 6.0
	var bottom := size.y - 6.0
	var notch := minf(12.0, size.y * 0.2)
	var outline := PackedVector2Array([
		Vector2(left + notch, top),
		Vector2(right - notch * 1.4, top),
		Vector2(right, top + notch),
		Vector2(right, bottom - notch * 0.55),
		Vector2(right - notch * 0.55, bottom),
		Vector2(left + notch * 0.55, bottom),
		Vector2(left, bottom - notch),
		Vector2(left, top + notch * 0.55),
		Vector2(left + notch, top),
	])
	draw_polyline(outline, frame_color, 2.0, true)
	draw_line(Vector2(left + 20.0, top + 4.0), Vector2(right - 28.0, top + 4.0), _alpha(frame_color, frame_color.a * 0.34), 1.0, true)
	draw_line(Vector2(left + 34.0, bottom - 4.0), Vector2(right - 14.0, bottom - 4.0), _alpha(frame_color, frame_color.a * 0.25), 1.0, true)

	var center_y := size.y * 0.5
	var marker_center := Vector2(left + 10.0, center_y)
	var marker_size := 5.0 if primary else 4.0
	var marker := PackedVector2Array([
		marker_center + Vector2(0.0, -marker_size),
		marker_center + Vector2(marker_size, 0.0),
		marker_center + Vector2(0.0, marker_size),
		marker_center + Vector2(-marker_size, 0.0),
	])
	draw_colored_polygon(marker, accent_color)
	if active:
		draw_arc(marker_center, marker_size + 5.0, -PI * 0.75, PI * 0.75, 16, accent_color, 1.5, true)
		draw_line(Vector2(left + 21.0, center_y), Vector2(left + 31.0, center_y), accent_color, 2.0, true)
	else:
		draw_circle(marker_center, marker_size + 3.0, _alpha(frame_color, frame_color.a * 0.5), false, 1.0, true)

	_draw_corner_cap(Vector2(right - 2.0, top + 2.0), Vector2(-1.0, 1.0), accent_color)
	_draw_corner_cap(Vector2(left + 2.0, bottom - 2.0), Vector2(1.0, -1.0), _alpha(frame_color, frame_color.a * 0.7))
	_draw_index(accent_color if active else _alpha(frame_color, frame_color.a * 0.72))


func _draw_corner_cap(origin: Vector2, direction: Vector2, color: Color) -> void:
	draw_line(origin, origin + Vector2(direction.x * 12.0, 0.0), color, 2.0, true)
	draw_line(origin, origin + Vector2(0.0, direction.y * 12.0), color, 2.0, true)
	draw_circle(origin + direction * 3.0, 1.8, color)


func _draw_index(color: Color) -> void:
	if menu_index.is_empty():
		return
	var font := get_theme_font("font")
	var index_size := maxi(10, int(round(float(get_theme_font_size("font_size")) * 0.52)))
	var bounds := font.get_string_size(menu_index, HORIZONTAL_ALIGNMENT_LEFT, -1.0, index_size)
	var baseline := Vector2(size.x - 15.0 - bounds.x, (size.y + bounds.y * 0.5) * 0.5)
	draw_string(font, baseline, menu_index, HORIZONTAL_ALIGNMENT_LEFT, -1.0, index_size, color)


func _alpha(color: Color, value: float) -> Color:
	return Color(color.r, color.g, color.b, value)
