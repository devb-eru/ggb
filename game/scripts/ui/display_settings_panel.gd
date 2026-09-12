extends PanelContainer

signal back_requested
signal confirmed(settings: Dictionary)
const Settings := preload("res://scripts/systems/display_settings.gd")
var profile_store := AccessibilityProfileStore.new()
var preview: RefCounted
var mode := OptionButton.new()
var resolution := OptionButton.new()
var back := Button.new()
var apply := Button.new()
var keep := Button.new()
var revert := Button.new()
var message := Label.new()
var heading := Label.new()
var _mode_label := Label.new()
var _size_label := Label.new()
var _english := false
var _saved: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if preview == null: preview = Settings.Preview.new(Settings.WindowBackend.new(get_window()), Settings.validate)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.03, 0.045, 0.99)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 20)
	add_theme_stylebox_override("panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.1
	anchor_right = 0.9
	anchor_top = 0.1
	anchor_bottom = 0.9
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	for control: Control in [heading, _mode_label, mode, _size_label, resolution, message, back, apply, revert, keep]: body.add_child(control)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for size: Vector2i in Settings.SIZES: resolution.add_item("%d x %d" % [size.x, size.y])
	mode.item_selected.connect(func(_index: int): _refresh_controls())
	back.pressed.connect(func():
		preview.revert()
		back_requested.emit())
	apply.pressed.connect(_begin_preview)
	revert.pressed.connect(_revert)
	keep.pressed.connect(_keep)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): preview.revert())
	hide()

func load_values(value: Dictionary, locale: String) -> void:
	preview.revert()
	_saved = value.duplicate(true)
	_english = locale.begins_with("en")
	heading.text = "Display settings" if _english else "화면 설정"
	_mode_label.text = "Window mode" if _english else "화면 모드"
	_size_label.text = "Window size (fullscreen uses the monitor resolution)" if _english else "창 크기 (전체 화면은 모니터 해상도 사용)"
	mode.clear()
	for name_text: String in (["Windowed", "Borderless fullscreen", "Exclusive fullscreen"] if _english else ["창 모드", "테두리 없는 전체 화면", "전체 화면"]): mode.add_item(name_text)
	back.text = "Cancel / back" if _english else "취소 / 뒤로"
	apply.text = "Preview for 15 seconds" if _english else "15초 미리보기"
	revert.text = "Restore previous display" if _english else "이전 화면으로 복구"
	keep.text = "Keep and save" if _english else "유지하고 저장"
	_restore_controls()
	message.text = "Nothing is saved until you confirm. An unanswered preview automatically reverts." if _english else "확인하기 전에는 저장하지 않습니다. 응답하지 않으면 이전 화면으로 돌아갑니다."

func _restore_controls() -> void:
	mode.select(Settings.MODES.find(_saved.mode))
	resolution.select(Settings.SIZES.find(Vector2i(int(_saved.width), int(_saved.height))))
	_refresh_controls()

func values() -> Dictionary:
	var size: Vector2i = Settings.SIZES[resolution.selected]
	return {"mode": Settings.MODES[mode.selected], "width": size.x, "height": size.y}

func _begin_preview() -> void:
	if not preview.begin(values(), Time.get_ticks_msec()):
		message.text = "This display size is unavailable on the current monitor." if _english else "현재 모니터에서 사용할 수 없는 화면 크기입니다."
		return
	_refresh_controls()
	revert.grab_focus()
	_process(0.0)

func _keep() -> void:
	if not preview.pending: return
	var confirmed_at := Time.get_ticks_msec()
	if preview.expire(confirmed_at):
		_show_reverted()
		return
	var candidate: Dictionary = preview.candidate.duplicate(true)
	var profile: Dictionary = profile_store.load_profile().profile.duplicate(true)
	profile["display"] = candidate
	if not profile_store.save_profile(profile).get("ok", false):
		preview.revert()
		_restore_controls()
		message.text = "Saving failed. The previous display has been restored." if _english else "저장하지 못했습니다. 이전 화면으로 복구했습니다."
		back.grab_focus()
		return
	# The user's confirmation was received before the deadline; disk time is not input time.
	preview.keep(confirmed_at)
	_saved = candidate
	_refresh_controls()
	message.text = "Display settings saved." if _english else "화면 설정을 저장했습니다."
	confirmed.emit(candidate.duplicate(true))
	back.grab_focus()

func _process(_delta: float) -> void:
	if not preview.pending: return
	if preview.expire(Time.get_ticks_msec()):
		_show_reverted()
		return
	var remaining := maxi(1, int(ceil((preview.deadline_msec - Time.get_ticks_msec()) / 1000.0)))
	message.text = ("Keep this display? Reverting in %d seconds." if _english else "이 화면을 유지합니까? %d초 뒤 이전 화면으로 복구합니다.") % remaining

func _revert() -> void:
	preview.revert()
	_show_reverted()

func _show_reverted() -> void:
	_restore_controls()
	message.text = "Previous display restored. Nothing was saved." if _english else "이전 화면으로 돌아왔습니다. 변경 사항은 저장하지 않았습니다."
	back.grab_focus()

func _refresh_controls() -> void:
	mode.disabled = preview.pending
	resolution.disabled = preview.pending or mode.selected != 0
	apply.visible = not preview.pending
	keep.visible = preview.pending
	revert.visible = preview.pending
	var controls: Array[Control] = []
	for control: Control in interactive_controls():
		if control.visible and not control.disabled: controls.append(control)
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])

func interactive_controls() -> Array[Control]:
	return [mode, resolution, back, apply, revert, keep]

func _exit_tree() -> void:
	if preview != null: preview.revert()
