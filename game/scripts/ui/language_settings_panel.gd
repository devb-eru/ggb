extends PanelContainer
signal apply_requested(locale: String)
signal back_requested
const DESIGN := preload("res://scripts/ui/design_theme.gd")
var choice := OptionButton.new()
var back := Button.new()
var apply := Button.new()
var heading := Label.new()
var message := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.2
	anchor_right = 0.8
	anchor_top = 0.2
	anchor_bottom = 0.8
	theme = DESIGN.make_theme()
	var body := VBoxContainer.new()
	add_child(body)
	for control in [heading, choice, message, back, apply]: body.add_child(control)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice.add_item("한국어")
	choice.add_item("English")
	back.pressed.connect(func(): back_requested.emit())
	apply.pressed.connect(func(): apply_requested.emit("en-US" if choice.selected == 1 else "ko-KR"))
	DESIGN.skin_tree(self)
	hide()

func present(locale: String, text_scale: float) -> void:
	theme = DESIGN.make_theme(false, roundi(20 * text_scale))
	var english := locale.begins_with("en")
	heading.text = "Language" if english else "언어"
	message.text = "Changes the title and the language used when the story opens. Your progress is preserved." if english else "타이틀과 이후 열리는 이야기의 언어를 바꿉니다. 진행 상황은 유지됩니다."
	back.text = "Back" if english else "뒤로"
	apply.text = "Save and apply" if english else "저장하고 적용"
	choice.select(1 if english else 0)
	show()

func interactive_controls() -> Array[Control]:
	return [choice, back, apply]
