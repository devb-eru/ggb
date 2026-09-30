extends RefCounted

const DEFAULT := {"mode": "borderless", "width": 1280, "height": 720}
const MODES := ["windowed", "borderless", "fullscreen"]
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3: return false
	if typeof(value.get("mode")) != TYPE_STRING or value.mode not in MODES: return false
	for field in ["width", "height"]:
		var number: Variant = value.get(field)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(number)) or float(number) != floor(float(number)) or number < 1 or number > 16384: return false
	return Vector2i(int(value.width), int(value.height)) in SIZES

class WindowBackend extends RefCounted:
	var window: Window

	func _init(target: Window) -> void:
		window = target

	func capture() -> Dictionary:
		return {"mode": window.mode, "position": window.position, "size": window.size,
			"screen": window.current_screen, "borderless": window.borderless, "min_size": window.min_size}

	func available_size() -> Vector2i:
		if DisplayServer.get_name() == "headless": return Vector2i(3840, 2160)
		# Leave space for the operating system's title bar and resize borders.
		return DisplayServer.screen_get_usable_rect(window.current_screen).size - Vector2i(24, 64)

	func apply(value: Dictionary) -> bool:
		if DisplayServer.get_name() == "headless": return true
		var size := Vector2i(int(value.width), int(value.height))
		if value.mode == "windowed" and (size.x > available_size().x or size.y > available_size().y): return false
		window.min_size = Vector2i(1280, 720)
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		if value.mode == "windowed":
			window.size = size
			var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
			window.position = usable.position + (usable.size - size) / 2
		else:
			# Fullscreen modes use the current monitor's native resolution.
			window.mode = Window.MODE_FULLSCREEN if value.mode == "borderless" else Window.MODE_EXCLUSIVE_FULLSCREEN
		return true

	func restore(snapshot: Dictionary) -> void:
		if DisplayServer.get_name() == "headless": return
		window.mode = Window.MODE_WINDOWED
		window.min_size = snapshot.min_size
		window.current_screen = clampi(int(snapshot.screen), 0, DisplayServer.get_screen_count() - 1)
		window.borderless = snapshot.borderless
		window.size = snapshot.size
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = Vector2i(
			clampi(snapshot.position.x, usable.position.x, maxi(usable.position.x, usable.end.x - window.size.x)),
			clampi(snapshot.position.y, usable.position.y, maxi(usable.position.y, usable.end.y - window.size.y)))
		window.mode = snapshot.mode

class Preview extends RefCounted:
	const CONFIRM_MSEC := 15000
	var backend: RefCounted
	var validator: Callable
	var pending := false
	var deadline_msec := 0
	var candidate: Dictionary = {}
	var _snapshot: Dictionary = {}

	func _init(value: RefCounted, validate_settings: Callable) -> void:
		backend = value
		validator = validate_settings

	func begin(settings: Dictionary, now_msec: int) -> bool:
		if pending or not validator.call(settings): return false
		_snapshot = backend.capture().duplicate(true)
		if not backend.apply(settings):
			backend.restore(_snapshot)
			_snapshot.clear()
			return false
		candidate = settings.duplicate(true)
		pending = true
		deadline_msec = now_msec + CONFIRM_MSEC
		return true

	func keep(now_msec: int) -> bool:
		if not pending: return false
		if now_msec >= deadline_msec:
			revert()
			return false
		pending = false
		_snapshot.clear()
		return true

	func expire(now_msec: int) -> bool:
		if not pending or now_msec < deadline_msec: return false
		revert()
		return true

	func revert() -> void:
		if not pending: return
		backend.restore(_snapshot)
		pending = false
		_snapshot.clear()
		candidate.clear()
