extends "res://scripts/ui/d5_transition_art.gd"

var owner_id := ""
var signature_mode := "color_pattern_label"
var quiet_channel := false
const SIGNAL_BARS := {
	"EDGAR": [0.0, 0.2, 0.5, 0.8, 0.5, 0.2, 0.0, 0.0],
	"MARA1": [0.1, 0.7, 0.3, 0.5, 0.1, 0.0, 0.2, 0.0],
	"LUCA": [0.0, 0.8, 0.3, 0.0, 0.8, 0.3, 0.0, 0.0],
	"IRIS": [0.8, 0.6, 0.4, 0.3, 0.2, 0.1, 0.0, 0.0],
	"MARA2": [0.8, 0.0, 0.8, 0.0, 0.8, 0.0, 0.0, 0.0],
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("asset_id", "C5_CHANNEL_SIGNATURE_DEVELOPER_LAYER")
	set_meta("is_placeholder", true)
	set_meta("final_asset_pending", true)
	set_process(false)
	queue_redraw()


func configure(owner: String, mode: String, quiet: bool = false) -> void:
	owner_id = owner if owner in OWNERS else ""
	signature_mode = mode if mode in ["color_pattern_label", "pattern_label", "label_only"] else "color_pattern_label"
	quiet_channel = quiet
	visible = not owner_id.is_empty() and (signature_mode != "label_only" or quiet_channel)
	queue_redraw()


func ink() -> Color:
	return SIGNATURE_COLORS.get(owner_id, Color.WHITE) if signature_mode == "color_pattern_label" else Color.WHITE


func _draw() -> void:
	if owner_id.is_empty(): return
	if signature_mode != "label_only":
		var scale_factor := 0.12 if quiet_channel else 0.20
		draw_set_transform(Vector2(size.x * 0.5, size.y * (0.3 if quiet_channel else 0.5)), 0.0, Vector2.ONE * scale_factor)
		if signature_mode == "color_pattern_label": _draw_signature(owner_id, Vector2.ZERO, Color("dce4ef"), 20.0)
		_draw_signature(owner_id, Vector2.ZERO, ink(), 12.0)
		draw_set_transform(Vector2.ZERO)
	if quiet_channel:
		# Schematic cue rhythm, not a measurement of the pending final audio asset.
		for index in range(8):
			var height := 2.0 + 15.0 * float(SIGNAL_BARS[owner_id][index])
			draw_rect(Rect2(2.0 + index * 5.0, size.y - height - 2.0, 3.0, height), Color.WHITE)


static func quiet_profile(profile: Dictionary) -> bool:
	var audio: Dictionary = profile.get("audio", {})
	return audio.get("muted", false) or float(audio.get("master", 1.0)) <= 0.0 or float(audio.get("effects", 1.0)) <= 0.0
