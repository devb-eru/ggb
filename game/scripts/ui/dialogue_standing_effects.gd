extends Node

const FOCUS_SECONDS := 0.2

class PortraitAnimation:
	var portrait: TextureRect
	var kind: StringName
	var elapsed := 0.0
	var duration := 0.0
	var distance := 0.0
	var direction := 1.0
	var offset := Vector2.ZERO
	var opacity := 1.0
	var next_texture: Texture2D
	var focus_elapsed := FOCUS_SECONDS
	var focus_from := Color.WHITE
	var focus_to := Color.WHITE

var _animations: Dictionary[int, PortraitAnimation] = {}
var _suspended := false


func _ready() -> void:
	_update_processing()


func focus(portrait: TextureRect, previous_brightness: float, motion_mode: String = "standard") -> void:
	var animation := _animation_for(portrait)
	animation.focus_to = portrait.modulate
	animation.focus_elapsed = FOCUS_SECONDS
	if motion_mode == "standard" and not is_equal_approx(previous_brightness, animation.focus_to.r):
		animation.focus_from = Color(previous_brightness, previous_brightness, previous_brightness, animation.focus_to.a)
		animation.focus_elapsed = 0.0
		portrait.modulate = animation.focus_from
	_discard_if_finished(animation)
	_update_processing()


func present(portrait: TextureRect, effect: Dictionary, motion_mode: String = "standard") -> void:
	var kind := StringName(effect.get("kind", ""))
	var default_duration: float
	var default_distance: float
	match kind:
		&"bounce":
			default_duration = 0.26
			default_distance = 8.0
		&"shake":
			default_duration = 0.33
			default_distance = 6.0
		&"flinch":
			default_duration = 0.20
			default_distance = 7.0
		&"enter", &"exit":
			default_duration = 0.27
			default_distance = 14.0
		&"expression":
			default_duration = 0.16
			if not effect.get("texture") is Texture2D:
				return
		_:
			return

	var animation := _animation_for(portrait)
	_finish_reaction(animation)
	animation.kind = kind
	animation.elapsed = 0.0
	animation.duration = clampf(_number(effect, "duration", default_duration), 0.05, 0.6)
	animation.distance = clampf(_number(effect, "pixels", default_distance), 0.0, 24.0)
	animation.direction = -1.0 if _number(effect, "direction", 1.0) < 0.0 else 1.0
	animation.opacity = portrait.self_modulate.a
	animation.next_texture = effect.get("texture") as Texture2D if kind == &"expression" else null
	if kind == &"enter":
		portrait.show()
	if motion_mode != "standard" or not portrait.visible or portrait.texture == null:
		_finish_reaction(animation)
	else:
		_apply_reaction(animation, 0.0)
	_discard_if_finished(animation)
	_update_processing()


func reset() -> void:
	for animation: PortraitAnimation in _animations.values():
		if is_instance_valid(animation.portrait):
			_finish_reaction(animation)
			if animation.focus_elapsed < FOCUS_SECONDS:
				animation.portrait.modulate = animation.focus_to
	_animations.clear()
	_update_processing()


func set_suspended(value: bool) -> void:
	_suspended = value
	_update_processing()


func _process(delta: float) -> void:
	for id: int in _animations.keys():
		var animation: PortraitAnimation = _animations[id]
		if not is_instance_valid(animation.portrait):
			_animations.erase(id)
			continue
		if animation.focus_elapsed < FOCUS_SECONDS:
			animation.focus_elapsed = minf(animation.focus_elapsed + delta, FOCUS_SECONDS)
			var progress := smoothstep(0.0, FOCUS_SECONDS, animation.focus_elapsed)
			animation.portrait.modulate = animation.focus_from.lerp(animation.focus_to, progress)
		if animation.kind != &"":
			animation.elapsed += delta
			if animation.elapsed >= animation.duration:
				_finish_reaction(animation)
			else:
				_apply_reaction(animation, animation.elapsed / animation.duration)
		_discard_if_finished(animation)
	_update_processing()


func _apply_reaction(animation: PortraitAnimation, progress: float) -> void:
	var horizontal := animation.distance * animation.direction
	match animation.kind:
		&"bounce":
			_apply_offset(animation, Vector2.UP * animation.distance * sin(PI * progress))
		&"shake":
			_apply_offset(animation, Vector2.RIGHT * horizontal * sin(TAU * 2.5 * progress) * (1.0 - progress))
		&"flinch":
			_apply_offset(animation, Vector2.RIGHT * horizontal * sin(PI * pow(progress, 0.55)))
		&"enter", &"exit":
			var visibility := smoothstep(0.0, 1.0, progress)
			if animation.kind == &"exit":
				visibility = 1.0 - visibility
			_apply_offset(animation, Vector2.RIGHT * horizontal * (1.0 - visibility))
			animation.portrait.self_modulate.a = animation.opacity * visibility
		&"expression":
			if progress >= 0.5:
				animation.portrait.texture = animation.next_texture
			animation.portrait.self_modulate.a = animation.opacity * (1.0 - 0.35 * sin(PI * progress))


func _finish_reaction(animation: PortraitAnimation) -> void:
	if animation.kind == &"":
		return
	_apply_offset(animation, Vector2.ZERO)
	match animation.kind:
		&"exit":
			animation.portrait.hide()
			animation.portrait.self_modulate.a = animation.opacity
		&"enter":
			animation.portrait.self_modulate.a = animation.opacity
		&"expression":
			animation.portrait.texture = animation.next_texture
			animation.portrait.self_modulate.a = animation.opacity
	animation.kind = &""
	animation.next_texture = null


func _apply_offset(animation: PortraitAnimation, offset: Vector2) -> void:
	# Use a delta so a simultaneous screen shake can move the same visual.
	animation.portrait.position += offset - animation.offset
	animation.offset = offset


func _animation_for(portrait: TextureRect) -> PortraitAnimation:
	var id := portrait.get_instance_id()
	if not _animations.has(id):
		var animation := PortraitAnimation.new()
		animation.portrait = portrait
		_animations[id] = animation
	return _animations[id]


func _discard_if_finished(animation: PortraitAnimation) -> void:
	if animation.kind == &"" and animation.focus_elapsed >= FOCUS_SECONDS:
		_animations.erase(animation.portrait.get_instance_id())


func _update_processing() -> void:
	set_process(not _suspended and not _animations.is_empty())


func _number(effect: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = effect.get(key)
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback
