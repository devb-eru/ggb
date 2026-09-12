extends Control

# Developer illustration: final kettle, portrait and sound assets remain separate.
var elapsed := 0.0
var still := false
var beat := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func present(value: String, reduced_motion: bool) -> void:
	if value == beat and reduced_motion == still:
		return
	beat = value
	still = reduced_motion
	elapsed = 0.0
	visible = not beat.is_empty()
	set_process(visible and not still)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed = minf(elapsed + delta, 3.0)
	queue_redraw()
	if elapsed >= 3.0:
		set_process(false)

func pulse_at(time: float, start: float) -> float:
	var progress := (time - start) / 0.65
	return sin(progress * PI) if progress >= 0.0 and progress <= 1.0 else 0.0

func _draw() -> void:
	draw_style_box(_backing(), Rect2(Vector2.ZERO, size))
	var ink := Color("d4c8b5")
	var kettle := Vector2(160, 125)
	var face := Vector2(475, 130)
	draw_circle(kettle, 48, Color("51433c"))
	draw_arc(kettle, 48, 0, TAU, 48, ink, 3, true)
	draw_line(kettle + Vector2(-45, -8), kettle + Vector2(-75, -37), ink, 9, true)
	draw_arc(kettle + Vector2(48, 0), 27, -PI / 2, PI / 2, 32, ink, 5, true)
	draw_line(kettle + Vector2(-28, -48), kettle + Vector2(28, -48), ink, 5, true)
	draw_circle(kettle + Vector2(0, -57), 7, ink)
	var pulse := maxf(pulse_at(elapsed, 0.0), pulse_at(elapsed, 0.9))
	var floor_pulse := pulse_at(elapsed, 2.05)
	if still or beat != "pulse":
		pulse = 0.65
		floor_pulse = 0.65 if beat == "reply" else 0.0
	# Ear shape and expanding paired lines carry the signal without hue alone.
	for offset in [-1, 1]:
		var ear := face + Vector2(offset * 45, -45)
		draw_circle(ear, 31, Color("111317"))
		draw_arc(ear, 30, 0, TAU, 40, ink, 2, true)
		draw_circle(ear, 22, Color("B7F34A").darkened(0.65 - pulse * 0.35))
		draw_arc(ear, 25 + pulse * 5, 0, TAU, 40, ink, 1 + pulse * 2, true)
	draw_circle(face, 46, Color("111317"))
	draw_arc(face, 46, 0, TAU, 48, ink, 2, true)
	for offset in [-1, 1]:
		draw_line(face + Vector2(offset * 16, -3), face + Vector2(offset * 16, 7), ink, 3, true)
	for index in range(2):
		var y := 190.0 + index * 10.0 + pulse * 5.0
		draw_line(Vector2(112, y), Vector2(208, y), ink, 1 + pulse * 3, true)
	draw_line(Vector2(70, 236), Vector2(570, 236), Color("51433c"), 4, true)
	draw_arc(Vector2(320, 238), 14 + floor_pulse * 18, 0, PI, 32, ink, 1 + floor_pulse * 3, true)

func _backing() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.035, 0.055, 0.96)
	style.border_color = Color("51433c")
	style.set_border_width_all(2)
	return style
