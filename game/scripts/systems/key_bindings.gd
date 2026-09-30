extends RefCounted

# One logical binding updates both gameplay and Godot GUI actions.
const ACTIONS := {
	"confirm": ["ui_accept", "interact_confirm"],
	"cancel": ["ui_cancel"],
	"next": ["ui_focus_next", "focus_next"],
	"previous": ["ui_focus_prev", "focus_previous"],
	"notebook": ["notebook_toggle"],
	"inventory": ["inventory_toggle"],
	"up": ["ui_up"], "down": ["ui_down"],
	"left": ["ui_left"], "right": ["ui_right"],
	"page_up": ["ui_page_up"], "page_down": ["ui_page_down"],
}
const NAMES := {
	"confirm": ["선택 / 상호작용", "Confirm / interact"],
	"cancel": ["취소 / 메뉴", "Cancel / menu"],
	"next": ["다음 포커스", "Next focus"],
	"previous": ["이전 포커스", "Previous focus"],
	"notebook": ["수첩", "Notebook"], "inventory": ["소지품", "Inventory"],
	"up": ["위", "Up"], "down": ["아래", "Down"],
	"left": ["왼쪽", "Left"], "right": ["오른쪽", "Right"],
	"page_up": ["이전 페이지 스크롤", "Scroll page up"],
	"page_down": ["다음 페이지 스크롤", "Scroll page down"],
}

static func defaults() -> Dictionary:
	return {
		"confirm": [KEY_ENTER, KEY_SPACE], "cancel": [KEY_ESCAPE],
		"next": [KEY_TAB], "previous": [KEY_TAB | KEY_MASK_SHIFT],
		"notebook": [KEY_N], "inventory": [KEY_I],
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"page_up": [KEY_PAGEUP], "page_down": [KEY_PAGEDOWN],
	}

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != ACTIONS.size(): return false
	var used: Array[int] = []
	for id: String in ACTIONS:
		if not value.get(id) is Array or value[id].is_empty() or value[id].size() > 2: return false
		for code: Variant in value[id]:
			if typeof(code) not in [TYPE_INT, TYPE_FLOAT]: return false
			if not is_finite(float(code)) or float(code) != floor(float(code)) or float(code) < 1 or float(code) > 0x3FFFFFFF: return false
			var key := int(code)
			var base := key & KEY_CODE_MASK
			if base in [KEY_NONE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]: return false
			if OS.get_keycode_string(base).is_empty() or key in used: return false
			used.append(key)
	return true

static func apply_bindings(value: Dictionary) -> bool:
	if not validate(value): return false
	for id: String in ACTIONS:
		for action: String in ACTIONS[id]:
			if not InputMap.has_action(action): InputMap.add_action(action)
			# Keyboard replacement must not remove mouse or controller bindings.
			for old: InputEvent in InputMap.action_get_events(action):
				if old is InputEventKey: InputMap.action_erase_event(action, old)
			for code: Variant in value[id]:
				InputMap.action_add_event(action, key_event(int(code)))
	return true

static func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code & KEY_CODE_MASK
	event.shift_pressed = bool(code & KEY_MASK_SHIFT)
	event.ctrl_pressed = bool(code & KEY_MASK_CTRL)
	event.alt_pressed = bool(code & KEY_MASK_ALT)
	event.meta_pressed = bool(code & KEY_MASK_META)
	return event

static func caption(value: Array) -> String:
	var names := PackedStringArray()
	for code: Variant in value: names.append(OS.get_keycode_string(int(code)))
	return " / ".join(names)
