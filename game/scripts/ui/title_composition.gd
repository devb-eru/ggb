extends Control
## The scene owns the composition. Runtime only moves artwork and follows focus.
var screen: Control
var character: TextureRect
var _cursor := Vector2.ZERO
var _menu: VBoxContainer
var _scroll: ScrollContainer
var _background: TextureRect
var _background_rest: Rect2
var _character_rest: Rect2

func bind_screen(owner_screen: Control) -> void:
	screen = owner_screen
	character = get_node("TitleProtagonist")
	_menu = get_node("TitleMenuLayout")
	_scroll = _menu.get_node("TitleMenuScroll")
	_background = screen.get_node("TitleBackground")
	_background_rest = _offsets(_background)
	_character_rest = _offsets(character)
	_scroll.resized.connect(func(): _reveal_focus.call_deferred())
	for child in screen._menu_container.get_children():
		if child is Button: child.focus_entered.connect(func(): _reveal_focus.call_deferred())

func _offsets(control: Control) -> Rect2:
	return Rect2(control.offset_left, control.offset_top, control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)

func _move_art(control: Control, rest: Rect2, offset: Vector2) -> void:
	control.offset_left = rest.position.x + offset.x
	control.offset_top = rest.position.y + offset.y
	control.offset_right = rest.end.x + offset.x
	control.offset_bottom = rest.end.y + offset.y

func _reveal_focus() -> void:
	if screen._active_modal() != null: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _menu.is_ancestor_of(focused): return
	var rect := focused.get_global_rect()
	var bounds := _scroll.get_global_rect()
	if rect.end.y > bounds.end.y - 2:
		_scroll.scroll_vertical += ceili(rect.end.y - bounds.end.y) + 3
	elif rect.position.y < bounds.position.y + 2:
		_scroll.scroll_vertical -= ceili(bounds.position.y - rect.position.y) + 3

func _process(delta: float) -> void:
	if not is_instance_valid(screen): return
	var save_hint: Label = screen._menu_container.get_node("SaveAvailabilityHint")
	save_hint.text = screen._continue_button.tooltip_text
	_update_artwork(delta, get_local_mouse_position(), get_window().has_focus())

func _update_artwork(delta: float, pointer: Vector2, window_focused: bool) -> void:
	var enabled: bool = screen._profile.get("motion_mode", "standard") == "standard" and not screen._input_suspended and window_focused and is_visible_in_tree()
	var target := Vector2.ZERO
	if enabled and Rect2(Vector2.ZERO, size).has_point(pointer): target = (pointer / size * 2 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_cursor = _cursor.lerp(target, 1 - exp(-delta / 0.14)) if enabled else Vector2.ZERO
	_move_art(_background, _background_rest, _cursor * Vector2(12, 8))
	_position_character()

func _position_character() -> void:
	_move_art(character, _character_rest, -_cursor * Vector2(4, 3))
