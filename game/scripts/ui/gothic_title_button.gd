@tool
class_name GothicTitleButton
extends Button

@export var menu_index := "00"
@export_enum("primary", "secondary") var chrome_role := "primary"

func _ready() -> void:
	for event in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]: event.connect(queue_redraw)

func set_motion_mode(_mode: String) -> void:
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(size.x * 0.08, size.y - 1), Vector2(size.x * 0.92, size.y - 1), Color(0.67, 0.61, 0.47, 0.35), 1, true)
	for x in [size.x * 0.025, size.x * 0.975]:
		var center := Vector2(x, size.y * 0.5)
		var color := Color("a49ab5") if not disabled else Color("68616e")
		draw_polyline(PackedVector2Array([center + Vector2(0,-5), center + Vector2(3,0), center + Vector2(0,5), center + Vector2(-3,0), center + Vector2(0,-5)]), color, 1, true)
