extends Node
## Dialogue-only FX. Canvas shaders move the art while its controls keep their layout.

const SHAKE_SHADER := """
shader_type canvas_item;

uniform vec2 world_offset;
uniform vec2 cover_half_size;

void vertex() {
	vec2 offset = (inverse(MODEL_MATRIX) * vec4(world_offset, 0.0, 0.0)).xy;
	if (cover_half_size.x > 0.0 && cover_half_size.y > 0.0) {
		VERTEX += (VERTEX - cover_half_size) * abs(offset) / cover_half_size;
	}
	VERTEX += offset;
}
"""

const OVERLAY_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform int effect_kind;
uniform float strength;
uniform vec4 region;

void fragment() {
	if (effect_kind == 1 || effect_kind == 2) {
		vec2 point = abs((UV - region.xy) / region.zw * 2.0 - 1.0);
		float edge = max(point.x, point.y);
		float shape = 1.0 - smoothstep(0.8, 1.0, edge);
		if (effect_kind == 2) {
			shape *= smoothstep(0.62, 0.82, edge);
		}
		COLOR = vec4(vec3(0.9, 0.87, 0.82), shape * strength);
	} else if (effect_kind == 3) {
		float edge = length(abs(UV * 2.0 - 1.0) * vec2(0.94, 0.72));
		COLOR = vec4(vec3(0.018, 0.012, 0.025), smoothstep(0.38, 1.0, edge) * strength);
	} else {
		COLOR = vec4(vec3(0.0), strength);
	}
}
"""

var _playback: Tween
var _suspended := false
var _overlay: ColorRect
var _overlay_material: ShaderMaterial
var _shake_shader: Shader
var _shake_materials: Dictionary[Control, ShaderMaterial] = {}


func present(effect: Dictionary, world: Control, portraits: Array[TextureRect], motion_mode: String = "standard") -> void:
	reset()
	match String(effect.get("kind", "")):
		"shake":
			if motion_mode == "standard":
				_start_shake(effect, world, portraits)
		"flicker":
			_start_local_light(effect, motion_mode)
		"fade":
			_start_tint(effect, 0, 1.0, 0.0, 1.0, motion_mode)
		"vignette":
			_start_tint(effect, 3, 0.0, 0.4, 0.6, motion_mode)


func reset() -> void:
	if _playback != null:
		if _playback.is_valid():
			_playback.kill()
		_playback = null
	_clear_shake()
	if is_instance_valid(_overlay):
		_overlay.hide()


func set_suspended(value: bool) -> void:
	_suspended = value
	if _playback == null or not _playback.is_valid():
		return
	if _suspended:
		_playback.pause()
	else:
		_playback.play()


func _exit_tree() -> void:
	reset()


func _new_playback() -> Tween:
	_playback = create_tween()
	if _suspended:
		_playback.pause()
	return _playback


func _start_shake(effect: Dictionary, world: Control, portraits: Array[TextureRect]) -> void:
	var amplitude := clampf(float(effect.get("pixels", 4.0)), 0.0, 4.0)
	var duration := clampf(float(effect.get("duration", 0.28)), 0.08, 0.4)
	if amplitude == 0.0:
		return
	if _shake_shader == null:
		_shake_shader = Shader.new()
		_shake_shader.code = SHAKE_SHADER
	_attach_shake(world, true)
	for portrait: TextureRect in portraits:
		_attach_shake(portrait)
	if _shake_materials.is_empty():
		return
	var tween := _new_playback()
	tween.tween_method(_set_shake_phase.bind(amplitude), 0.0, 1.0, duration)
	tween.finished.connect(_clear_shake)


func _attach_shake(target: Control, cover_edges: bool = false) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree() or target.material != null:
		return
	var material := ShaderMaterial.new()
	material.shader = _shake_shader
	if cover_edges:
		material.set_shader_parameter("cover_half_size", target.size * 0.5)
	target.material = material
	_shake_materials[target] = material


func _set_shake_phase(phase: float, amplitude: float) -> void:
	var direction := Vector2(0.98, 0.199)
	var world_offset := direction * (sin(phase * TAU * 1.5) * (1.0 - phase) * amplitude)
	for material: ShaderMaterial in _shake_materials.values():
		material.set_shader_parameter("world_offset", world_offset)


func _clear_shake() -> void:
	for target in _shake_materials:
		if is_instance_valid(target) and target.material == _shake_materials[target]:
			target.material = null
	_shake_materials.clear()


func _start_local_light(effect: Dictionary, motion_mode: String) -> void:
	var bounds := _local_rect(effect.get("rect", Rect2(0.46, 0.3, 0.12, 0.14)))
	var protected := bool(effect.get("photosensitivity_protection", true)) or motion_mode != "standard"
	var duration := clampf(float(effect.get("duration", 0.32)), 0.18, 1.0)
	var strength := clampf(float(effect.get("strength", 0.16)), 0.0, 0.24)
	_show_overlay(2 if protected else 1)
	_overlay_material.set_shader_parameter("region", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	if motion_mode != "standard":
		_set_strength(strength)
		return
	var tween := _new_playback()
	tween.tween_method(_set_strength, 0.0, strength, duration if protected else duration * 0.5)
	if not protected:
		tween.tween_method(_set_strength, strength, 0.0, duration * 0.5)


func _local_rect(value: Variant) -> Rect2:
	var region := Rect2(0.46, 0.3, 0.12, 0.14)
	if value is Rect2:
		region = value
	elif value is Array and value.size() == 4:
		region = Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	region.size = region.size.clamp(Vector2(0.02, 0.02), Vector2(0.35, 0.35))
	region.position = region.position.clamp(Vector2.ZERO, Vector2.ONE - region.size)
	return region


func _start_tint(effect: Dictionary, kind: int, default_from: float, default_to: float, maximum: float, motion_mode: String) -> void:
	var start := clampf(float(effect.get("from", default_from)), 0.0, maximum)
	var finish := clampf(float(effect.get("to", default_to)), 0.0, maximum)
	var duration := clampf(float(effect.get("duration", 0.45)), 0.3, 1.0)
	_show_overlay(kind)
	if motion_mode != "standard":
		_set_strength(finish)
		return
	_set_strength(start)
	var tween := _new_playback()
	tween.tween_method(_set_strength, start, finish, duration).set_trans(Tween.TRANS_SINE)


func _show_overlay(kind: int) -> void:
	if not is_instance_valid(_overlay):
		var hud := get_parent() as Control
		_overlay = ColorRect.new()
		_overlay.name = "DialogueScreenOverlay"
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = OVERLAY_SHADER
		_overlay_material.shader = shader
		_overlay.material = _overlay_material
		hud.add_child(_overlay)
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var readability := hud.get_node_or_null("DialogueReadability")
		if readability != null:
			hud.move_child(_overlay, readability.get_index())
	_overlay_material.set_shader_parameter("effect_kind", kind)
	_set_strength(0.0)
	_overlay.show()


func _set_strength(alpha: float) -> void:
	_overlay_material.set_shader_parameter("strength", alpha)
