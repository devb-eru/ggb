extends PanelContainer

signal apply_requested(settings: Dictionary)
signal back_requested

var sliders: Dictionary = {}
var labels: Dictionary = {}
var mute := CheckButton.new()
var back := Button.new()
var apply := Button.new()
var heading := Label.new()
var error_label := Label.new()
var _english := false
const NAMES := {
	"master": ["전체 음량", "Master volume"],
	"bgm": ["배경 음악", "Music"],
	"ambience": ["공간음", "Ambience"],
	"effects": ["효과음", "Sound effects"],
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.15
	anchor_right = 0.85
	anchor_top = 0.1
	anchor_bottom = 0.9
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	body.add_child(heading)
	for key: String in NAMES:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		labels[key] = label
		body.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.y = 32
		sliders[key] = slider
		body.add_child(slider)
		slider.value_changed.connect(func(_value: float): _update_label(key))
	body.add_child(mute)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(error_label)
	var buttons := HBoxContainer.new()
	body.add_child(buttons)
	buttons.add_child(back)
	buttons.add_child(apply)
	back.pressed.connect(func(): back_requested.emit())
	apply.pressed.connect(func(): apply_requested.emit(values()))
	hide()

func load_values(settings: Dictionary, locale: String) -> void:
	_english = locale.begins_with("en")
	heading.text = "Audio settings" if _english else "음향 설정"
	mute.text = "Mute all audio" if _english else "전체 음소거"
	back.text = "Back" if _english else "뒤로"
	apply.text = "Apply" if _english else "적용"
	error_label.text = ""
	for key: String in sliders:
		sliders[key].value = float(settings.get(key, 1.0)) * 100.0
		_update_label(key)
	mute.button_pressed = bool(settings.get("muted", false))

func values() -> Dictionary:
	var result := {"muted": mute.button_pressed}
	for key: String in sliders:
		result[key] = sliders[key].value / 100.0
	return result

func show_save_error() -> void:
	error_label.text = "Could not save audio settings. Please retry." if _english else "음향 설정을 저장하지 못했습니다. 다시 시도해 주세요."

func interactive_controls() -> Array[Control]:
	var controls: Array[Control] = [mute, back, apply]
	for slider: HSlider in sliders.values():
		controls.append(slider)
	return controls

func _update_label(key: String) -> void:
	var caption: String = NAMES[key][1 if _english else 0]
	labels[key].text = "%s: %d%%" % [caption, int(sliders[key].value)]
	sliders[key].tooltip_text = labels[key].text
