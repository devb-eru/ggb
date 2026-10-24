extends PanelContainer
## Native scene nodes own layout, images and base typography.
signal back_requested
signal profile_applied(profile: Dictionary, section: String)
signal first_run_completed

const Display := preload("res://scripts/systems/display_settings.gd")
const Bindings := preload("res://scripts/systems/key_bindings.gd")
const SCALES := [1.0, 1.25, 1.5, 2.0]
const SIGNATURES := ["color_pattern_label", "pattern_label", "label_only"]
const MOTIONS := ["standard", "reduced", "static"]
const CATEGORIES := ["accessibility", "display", "audio", "controls", "language"]
var profile_store := AccessibilityProfileStore.new()
var preview: RefCounted
var _saved: Dictionary = {}
var _draft: Dictionary = {}
var _locale := "ko-KR"
var _page := "accessibility"
var _first_run := false
var _syncing := false
var _capture := ""
var _capture_index := 0
var _fonts: Dictionary = {}
var _sizes: Dictionary = {}
var _option_sizes: Dictionary = {}
var _label_widths: Dictionary = {}
var _key_targets: Dictionary = {}
var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var sliders: Dictionary = {}
var labels: Dictionary = {}
var buttons: Dictionary = {}

@onready var back: Button = $Surface/Back
@onready var apply: Button = $Surface/Apply
@onready var restore: Button = $Surface/Defaults
@onready var close: Button = $Surface/Close
@onready var message: Label = $Surface/Message
@onready var heading: Label = $Surface/Category
@onready var confirmation: Control = $Confirmation
@onready var keep: Button = $Confirmation/Center/Paper/Margin/Body/Buttons/Keep
@onready var revert: Button = $Confirmation/Center/Paper/Margin/Body/Buttons/Revert
@onready var countdown: Label = $Confirmation/Center/Paper/Margin/Body/Countdown
@onready var text_size = $Surface/ContentScroll/Pages/Accessibility/Fields/TextSize/Options
@onready var signature: OptionButton = $Surface/ContentScroll/Pages/Accessibility/Fields/Signature/Options
@onready var motion = $Surface/ContentScroll/Pages/Accessibility/Fields/Motion/Options
@onready var captions = $Surface/ContentScroll/Pages/Accessibility/Fields/Captions/Options
@onready var mode = $Surface/ContentScroll/Pages/Display/Fields/Mode/Options
@onready var resolution: OptionButton = $Surface/ContentScroll/Pages/Display/Fields/Resolution/Options
@onready var mute = $Surface/ContentScroll/Pages/Audio/Mute/Options
@onready var choice = $Surface/ContentScroll/Pages/Language/Languages
@onready var cancel_capture: Button = $Surface/CancelCapture
@onready var error_label: Label = $Surface/Message

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if preview == null: preview = Display.Preview.new(Display.WindowBackend.new(get_window()), Display.validate)
	for control in find_children("*", "Control", true, false):
		if control is Label or control is Button or control is OptionButton:
			_fonts[control] = control.get_theme_font_size("font_size")
		if control is Button and control.get_meta("scale_minimum", false):
			_sizes[control] = control.custom_minimum_size
		if control is OptionButton: _option_sizes[control] = control.custom_minimum_size
		if control is Label and control.custom_minimum_size.x > 0: _label_widths[control] = control.custom_minimum_size.x
	for index in CATEGORIES.size():
		var id: String = CATEGORIES[index]
		_pages[id] = get_node("Surface/ContentScroll/Pages/" + id.capitalize())
		_tabs[id] = get_node("Surface/Tabs/" + id.capitalize())
		_tabs[id].pressed.connect(show_page.bind(id))
	for id: String in ["master", "bgm", "ambience", "effects"]:
		var row := get_node("Surface/ContentScroll/Pages/Audio/" + id.capitalize())
		sliders[id] = row.get_node("Slider")
		labels[id] = row.get_node("Caption")
		sliders[id].value_changed.connect(_audio_changed.bind(id))
	for id: String in Bindings.ACTIONS:
		var target := find_child("Key_" + id, true, false) as Button
		buttons[id] = target
		_key_targets[id] = [target]
		target.pressed.connect(begin_capture.bind(id, 0))
	var alternate := find_child("Key_confirm_alt", true, false) as Button
	_key_targets.confirm.append(alternate)
	alternate.pressed.connect(begin_capture.bind("confirm", 1))
	text_size.item_selected.connect(_access_changed.bind("text_scale"))
	signature.item_selected.connect(_access_changed.bind("signature_mode"))
	motion.item_selected.connect(_access_changed.bind("motion_mode"))
	captions.item_selected.connect(_access_changed.bind("captions_enabled"))
	mode.item_selected.connect(_display_changed)
	resolution.item_selected.connect(_display_changed)
	mute.item_selected.connect(_mute_changed)
	choice.item_selected.connect(_language_changed)
	back.pressed.connect(request_back)
	close.pressed.connect(request_back)
	apply.pressed.connect(apply_current)
	restore.pressed.connect(restore_defaults)
	keep.pressed.connect(_keep)
	revert.pressed.connect(_revert)
	cancel_capture.pressed.connect(_cancel_capture)
	visibility_changed.connect(_visibility_changed)
	present(profile_store.load_profile().profile, TranslationServer.get_locale())

func present(profile: Dictionary, locale: String, first_run: bool = false, page: String = "accessibility") -> void:
	preview.revert()
	_saved = profile_store.default_profile()
	_saved.merge(profile.duplicate(true), true)
	_saved["locale"] = profile.get("locale", locale)
	_draft = _saved.duplicate(true)
	_locale = "en-US" if locale.begins_with("en") else "ko-KR"
	_first_run = first_run
	_capture = ""
	message.text = ""
	_sync_controls()
	_localize()
	_apply_text_scale()
	show_page(page, false)

func show_page(id: String, focus_tab: bool = true) -> void:
	if not CATEGORIES.has(id) or preview.pending: return
	_capture = ""
	cancel_capture.hide()
	_page = id
	for key in _pages:
		_pages[key].visible = key == id
		_tabs[key].set_pressed_no_signal(key == id)
	heading.text = _tabs[id].get_node("Caption").text
	restore.visible = id != "language"
	apply.visible = id in ["display", "language"] or (_first_run and id == "accessibility")
	apply.text = _l("시작하기", "Start") if _first_run and id == "accessibility" else _l("적용", "Apply")
	message.text = ""
	$Surface/ContentScroll.scroll_vertical = 0
	_refresh_key_captions()
	_focus_cycle()
	if focus_tab: _tabs[id].grab_focus()

func _localize() -> void:
	for control in _fonts:
		if control.has_meta("ko"):
			control.text = control.get_meta("en" if _locale.begins_with("en") else "ko")
	signature.clear()
	for caption in ( ["Color + pattern + name", "Pattern + name", "Name only"] if _locale.begins_with("en") else ["색상 + 문양 + 이름", "문양 + 이름", "이름만"] ): signature.add_item(caption)
	signature.select(SIGNATURES.find(_draft.signature_mode))
	resolution.clear()
	for size: Vector2i in Display.SIZES: resolution.add_item("%d × %d" % [size.x, size.y])
	resolution.select(Display.SIZES.find(Vector2i(int(_draft.display.width), int(_draft.display.height))))
	_refresh_previews()
	_refresh_key_captions()
	for id: String in sliders: _update_percentage(id)

func _apply_text_scale() -> void:
	var scale: float = _saved.text_scale
	for control in _fonts:
		var amount := minf(scale, 1.3) if control.has_meta("chrome") else scale
		if control.get_meta("fixed_scale", false): amount = 1.0
		control.add_theme_font_size_override("font_size", roundi(_fonts[control] * amount))
	for control in _sizes:
		control.custom_minimum_size = Vector2(_sizes[control].x * (scale if control.get_meta("scale_width", true) else 1.0), _sizes[control].y * scale)
	for control in _label_widths: control.custom_minimum_size.x = _label_widths[control] * minf(scale, 1.5)
	_refresh_previews()
	_fit_fields.call_deferred()

func _fit_fields() -> void:
	if not is_inside_tree(): return
	var scale: float = _saved.text_scale
	for control in _option_sizes:
		var font: Font = control.get_theme_font("font")
		var style: StyleBox = control.get_theme_stylebox("normal")
		var available := maxf(40, control.size.x - style.get_minimum_size().x - 50)
		var reading := font.get_multiline_string_size(control.text, HORIZONTAL_ALIGNMENT_CENTER, available, control.get_theme_font_size("font_size"))
		control.custom_minimum_size.y = maxf(_option_sizes[control].y * scale, reading.y + style.get_minimum_size().y + 8)

func _sync_controls() -> void:
	_syncing = true
	text_size.select(SCALES.find(float(_draft.text_scale)))
	signature.select(SIGNATURES.find(_draft.signature_mode))
	motion.select(MOTIONS.find(_draft.motion_mode))
	captions.select(0 if _draft.captions_enabled else 1)
	mode.select(Display.MODES.find(_draft.display.mode))
	resolution.select(Display.SIZES.find(Vector2i(int(_draft.display.width), int(_draft.display.height))))
	resolution.disabled = _draft.display.mode != "windowed"
	for id: String in sliders:
		sliders[id].set_value_no_signal(float(_draft.audio[id]) * 100)
		_update_percentage(id)
	mute.select(0 if _draft.audio.muted else 1)
	choice.select(1 if _draft.locale.begins_with("en") else 0)
	_refresh_key_captions()
	_refresh_previews()
	_syncing = false

func _access_changed(index: int, field: String) -> void:
	if _syncing: return
	match field:
		"text_scale": _draft[field] = SCALES[index]
		"signature_mode": _draft[field] = SIGNATURES[index]
		"motion_mode": _draft[field] = MOTIONS[index]
		"captions_enabled": _draft[field] = index == 0
	_commit("accessibility")

func _audio_changed(value: float, id: String) -> void:
	if _syncing: return
	_draft.audio[id] = value / 100.0
	_update_percentage(id)
	_commit("audio")

func _mute_changed(index: int) -> void:
	if _syncing: return
	_draft.audio.muted = index == 0
	_commit("audio")

func _update_percentage(id: String) -> void:
	sliders[id].get_parent().get_node("Value").text = "%d%%" % roundi(sliders[id].value)
	sliders[id].tooltip_text = "%s · %d%%" % [labels[id].text, roundi(sliders[id].value)]

func _display_changed(_index: int) -> void:
	if _syncing: return
	var size: Vector2i = Display.SIZES[resolution.selected]
	_draft.display = {"mode": Display.MODES[mode.selected], "width": size.x, "height": size.y}
	resolution.disabled = mode.selected != 0

func _language_changed(index: int) -> void:
	if _syncing: return
	_draft.locale = "en-US" if index == 1 else "ko-KR"
	_refresh_previews()

func _refresh_previews() -> void:
	if _draft.is_empty(): return
	var access: Control = _pages.accessibility
	access.get_node("Preview/Margin/Body/Sample").text = _l("종이 위쪽에 작은 흠이 있다.", "There is a small nick at the top of the paper.")
	access.get_node("Preview/Margin/Body/Captions").text = _l("[멀리서 종소리가 들린다]", "[A bell rings in the distance]")
	access.get_node("Preview/Margin/Body/Captions").visible = _draft.captions_enabled
	var language: Control = _pages.language
	language.get_node("Preview/Margin/Body/Sample").text = "There is a small nick at the top of the paper.\n\nI should note it in my notebook." if _draft.locale.begins_with("en") else "종이 위쪽에 작은 흠이 있다.\n\n수첩에 기록해 두자."
	for index in choice.get_child_count():
		var radio: Panel = choice.get_child(index).get_node("Radio")
		radio.add_theme_stylebox_override("panel", load("res://assets/ui/settings/styles/radio_checked.tres" if choice.selected == index else "res://assets/ui/settings/styles/radio_unchecked.tres"))

func begin_capture(id: String, index: int = 0) -> void:
	if not Bindings.ACTIONS.has(id): return
	_capture = id
	_capture_index = index
	message.text = _l("새 키를 눌러 주세요.", "Press a new key.")
	cancel_capture.show()
	_refresh_key_captions()
	_focus_cycle()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _capture.is_empty() or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	var candidate: Dictionary = _draft.key_bindings.duplicate(true)
	var codes: Array = candidate[_capture]
	var code: int = event.get_keycode_with_modifiers()
	if _capture_index < codes.size(): codes[_capture_index] = code
	else: codes.append(code)
	if not Bindings.validate(candidate):
		message.text = _l("이미 할당되었거나 지원하지 않는 키입니다.", "This key is already assigned or unsupported.")
		return
	var target: Button = _key_targets[_capture][_capture_index]
	_draft.key_bindings = candidate
	_capture = ""
	cancel_capture.hide()
	_commit("controls")
	_refresh_key_captions()
	_focus_cycle()
	target.grab_focus()

func _refresh_key_captions() -> void:
	if _draft.is_empty(): return
	for id in _key_targets:
		var values: Array = _draft.key_bindings[id]
		for index in _key_targets[id].size():
			var target: Button = _key_targets[id][index]
			var arrows := {KEY_UP:"↑", KEY_DOWN:"↓", KEY_LEFT:"←", KEY_RIGHT:"→"}
			target.text = arrows.get(int(values[index]), OS.get_keycode_string(int(values[index]))) if index < values.size() else "＋"
			target.tooltip_text = Bindings.caption(values)
			target.set_pressed_no_signal(_capture == id and _capture_index == index)
			target.accessibility_name = Bindings.NAMES[id][1 if _locale.begins_with("en") else 0] + " · " + target.text

func _cancel_capture() -> void:
	_capture = ""
	cancel_capture.hide()
	message.text = ""
	_refresh_key_captions()
	_focus_cycle()
	back.grab_focus()

func restore_defaults() -> void:
	if preview.pending: return
	_capture = ""
	var defaults := profile_store.default_profile()
	match _page:
		"accessibility":
			for field in ["text_scale", "signature_mode", "motion_mode", "captions_enabled"]: _draft[field] = defaults[field]
		"display": _draft.display = defaults.display.duplicate()
		"audio": _draft.audio = defaults.audio.duplicate()
		"controls": _draft.key_bindings = defaults.key_bindings.duplicate(true)
	_sync_controls()
	if _page in ["accessibility", "audio", "controls"]: _commit(_page)
	cancel_capture.hide()

func _candidate(section: String) -> Dictionary:
	# Merge only this section into the latest persisted profile.
	var profile := profile_store.default_profile()
	profile.merge(profile_store.load_profile().profile.duplicate(true), true)
	match section:
		"accessibility":
			for field in ["text_scale", "signature_mode", "motion_mode", "captions_enabled"]: profile[field] = _draft[field]
		"audio": profile.audio = _draft.audio.duplicate()
		"controls": profile.key_bindings = _draft.key_bindings.duplicate(true)
		"display": profile.display = _draft.display.duplicate()
		"language": profile.locale = _draft.locale
		"first_run": profile.first_run_complete = true
	return profile

func _commit(section: String) -> bool:
	var candidate := _candidate(section)
	if not profile_store.save_profile(candidate).get("ok", false):
		message.text = _l("설정을 저장하지 못했습니다. 이전 설정을 유지합니다.", "Could not save. Previous settings remain active.")
		# Restore only the rejected immediate section, preserving other drafts.
		if section == "accessibility":
			for field in ["text_scale", "signature_mode", "motion_mode", "captions_enabled"]: _draft[field] = _saved[field]
		elif section == "audio": _draft.audio = _saved.audio.duplicate()
		elif section == "controls": _draft.key_bindings = _saved.key_bindings.duplicate(true)
		_sync_controls()
		return false
	_saved = candidate.duplicate(true)
	if section == "controls": Bindings.apply_bindings(candidate.key_bindings)
	if section == "language":
		_locale = candidate.locale
		TranslationServer.set_locale(_locale)
		_localize()
	_apply_text_scale()
	profile_applied.emit(candidate.duplicate(true), section)
	message.text = ""
	if section == "first_run": first_run_completed.emit()
	return true

func apply_current() -> void:
	if _first_run and _page == "accessibility":
		_commit("first_run")
	elif _page == "language":
		if _commit("language"): show_page("language", false)
	elif _page == "display": _begin_preview()

func _begin_preview() -> void:
	_display_changed(0)
	if not preview.begin(_draft.display, Time.get_ticks_msec()):
		message.text = _l("현재 모니터에서 사용할 수 없는 화면 크기입니다.", "This size is unavailable on the current monitor.")
		return
	confirmation.show()
	_set_preview_scope(true)
	revert.grab_focus()
	_process(0)

func _keep() -> void:
	if not preview.pending: return
	var now := Time.get_ticks_msec()
	if preview.expire(now):
		_finish_preview(true)
		return
	if not _commit("display"):
		preview.revert()
		_finish_preview(true)
		message.text = _l("저장하지 못했습니다. 이전 화면으로 복구했습니다.", "Saving failed. The previous display has been restored.")
		return
	preview.keep(now)
	_finish_preview(false)

func _revert() -> void:
	preview.revert()
	_finish_preview(true)

func _finish_preview(restore_saved: bool) -> void:
	confirmation.hide()
	_set_preview_scope(false)
	if restore_saved:
		_draft.display = _saved.display.duplicate()
		_sync_controls()
	_focus_cycle()
	apply.grab_focus()

func _set_preview_scope(active: bool) -> void:
	for control in $Surface.find_children("*", "Control", true, false):
		if control is BaseButton or control is Slider:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
			control.focus_mode = Control.FOCUS_NONE if active else Control.FOCUS_ALL
	if active:
		revert.focus_next = revert.get_path_to(keep)
		revert.focus_previous = revert.get_path_to(keep)
		keep.focus_next = keep.get_path_to(revert)
		keep.focus_previous = keep.get_path_to(revert)

func _process(_delta: float) -> void:
	if is_node_ready(): restore.visible = _page != "language" and message.text.is_empty()
	if preview == null or not preview.pending: return
	if preview.expire(Time.get_ticks_msec()):
		_finish_preview(true)
		return
	var seconds := maxi(1, ceili((preview.deadline_msec - Time.get_ticks_msec()) / 1000.0))
	countdown.text = (_l("%d초 뒤 이전 설정으로 돌아갑니다.", "Previous settings return in %d seconds.")) % seconds

func request_back() -> void:
	if preview.pending:
		_revert()
		return
	_capture = ""
	back_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel", false, true):
		request_back()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if not _capture.is_empty(): _cancel_capture()

func _visibility_changed() -> void:
	if not is_visible_in_tree() and preview != null:
		preview.revert()
		confirmation.hide()
		_set_preview_scope(false)
		_capture = ""

func interactive_controls() -> Array[Control]:
	var result: Array[Control] = []
	for control in find_children("*", "Control", true, false):
		if control is BaseButton or control is Slider: result.append(control)
	return result

func _focus_cycle() -> void:
	if preview.pending: return
	var controls := interactive_controls().filter(func(control): return control.is_visible_in_tree() and not (control is BaseButton and control.disabled))
	for index in controls.size():
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])

func initial_focus() -> Control:
	return _tabs[_page]

func _l(ko: String, en: String) -> String:
	return en if _locale.begins_with("en") else ko

func _exit_tree() -> void:
	if preview != null: preview.revert()
