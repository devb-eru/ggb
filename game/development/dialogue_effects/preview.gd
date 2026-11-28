extends VBoxContainer

signal back_requested

const HUD := preload("res://scenes/ui/dialogue_hud.tscn")
const EDGAR := preload("res://assets/ui/design_2026_10/character_edgar.png")
const ALTERNATE_SAMPLE := preload("res://assets/ui/design_2026_10/character_iris.png")
const TEXT_OPTIONS := {
	"typewriter": "타이핑", "pause": "짧은 멈춤", "chunks": "구절 단위 출력",
	"emphasis": "단어 강조", "instant": "즉시 표시",
}
const STANDING_OPTIONS := {
	"": "스탠딩 효과 없음", "focus": "화자 전환", "bounce": "짧은 바운스",
	"shake": "좌우 흔들림", "flinch": "움찔", "enter": "입장",
	"exit": "퇴장", "expression": "표정 이미지 교체",
}
const SCREEN_OPTIONS := {
	"": "화면 FX 없음", "shake": "화면 흔들림", "flicker": "국소 깜빡임",
	"fade_in": "페이드 인", "fade_out": "페이드 아웃", "vignette": "주변부 어두워짐",
}
const MOTION_OPTIONS := {"standard": "움직임: 일반", "reduced": "움직임: 감소", "static": "움직임: 정적"}

@onready var _world: SubViewport = %World
@onready var _sample: LineEdit = %Sample

var _hud: Control
var _background: TextureRect
var _portrait: TextureRect
var _partner: TextureRect
var _base_texture: Texture2D
var _speaker: Label
var _body: Label


func _ready() -> void:
	_fill_options(%TextEffect, TEXT_OPTIONS)
	_fill_options(%StandingEffect, STANDING_OPTIONS)
	_fill_options(%ScreenEffect, SCREEN_OPTIONS)
	_fill_options(%Motion, MOTION_OPTIONS)
	_build_stage()
	_reset_stage()
	%Back.pressed.connect(back_requested.emit)
	%Play.pressed.connect(_play)
	%Reset.pressed.connect(_reset_stage)
	_sample.text_submitted.connect(func(_text: String): _play())
	%Play.grab_focus()


func _fill_options(button: OptionButton, options: Dictionary) -> void:
	for value: String in options:
		button.add_item(options[value])
		button.set_item_metadata(button.item_count - 1, value)
	button.select(0)


func _build_stage() -> void:
	_hud = HUD.instantiate()
	_world.add_child(_hud)
	_hud.offset_right = 0
	_background = _hud.get_node("PreviewBackground")
	_background.offset_right = 0
	_portrait = _hud.get_node("StandingPortrait")
	_base_texture = _portrait.texture
	_partner = _portrait.duplicate() as TextureRect
	_partner.texture = EDGAR
	_hud.add_child(_partner)
	_hud.move_child(_partner, _portrait.get_index() + 1)
	_portrait.position = Vector2(200, 305)
	_portrait.scale = Vector2.ONE * 0.6
	_partner.position = Vector2(1030, 75)
	_partner.scale = Vector2.ONE * 0.85
	_speaker = _hud.get_node("DialogueBacking/Margin/Body/SpeakerLabel")
	_body = _hud.get_node("DialogueBacking/Margin/Body/DialogueScroll/DialogueText")
	for path in ["DialogueHistory", "DialogueChoicePanel", "NotebookButton", "MenuButton", "LocationDivider", "LocationLabel"]:
		_hud.get_node(path).hide()
	%Stage.texture = _world.get_texture()


func _reset_stage() -> void:
	_hud.reset_effects()
	_portrait.texture = _base_texture
	_portrait.modulate = Color.WHITE
	_partner.modulate = Color(0.45, 0.45, 0.45)
	_portrait.show()
	_speaker.text = "나"
	_body.text = _sample.text
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0


func _play() -> void:
	_reset_stage()
	var motion := _selected(%Motion)
	_hud.text_effects.present(_body, _sample.text, _text_options(_selected(%TextEffect)), motion)
	_play_standing(_selected(%StandingEffect), motion)
	var screen := _screen_options(_selected(%ScreenEffect))
	var portraits: Array[TextureRect] = [_portrait, _partner]
	if not screen.is_empty():
		_hud.screen_effects.present(screen, _background, portraits, motion)


func _selected(button: OptionButton) -> String:
	return String(button.get_item_metadata(button.selected))


func _text_options(kind: String) -> Dictionary:
	match kind:
		"pause":
			var marker := "…" if _sample.text.contains("…") else _first_word()
			return {"pause_after": {marker: 0.4}}
		"chunks":
			return {"kind": kind, "chunk_words": 2}
		"emphasis":
			var word := "지금" if _sample.text.contains("지금") else _first_word()
			return {"emphasis": word}
	return {"kind": kind}


func _first_word() -> String:
	return _sample.text.strip_edges().get_slice(" ", 0)


func _play_standing(kind: String, motion: String) -> void:
	if kind.is_empty(): return
	if kind == "focus":
		_speaker.text = "에드가"
		_portrait.modulate = Color(0.45, 0.45, 0.45)
		_partner.modulate = Color.WHITE
		_hud.standing_effects.focus(_portrait, 1.0, motion)
		_hud.standing_effects.focus(_partner, 0.45, motion)
		return
	var effect := {"kind": kind}
	if kind == "expression":
		effect.texture = ALTERNATE_SAMPLE
	_hud.standing_effects.present(_portrait, effect, motion)


func _screen_options(kind: String) -> Dictionary:
	match kind:
		"":
			return {}
		"flicker":
			return {"kind": kind, "rect": [0.44, 0.25, 0.13, 0.24], "photosensitivity_protection": %Protection.button_pressed}
		"fade_in":
			return {"kind": "fade", "from": 1.0, "to": 0.0}
		"fade_out":
			return {"kind": "fade", "from": 0.0, "to": 1.0}
	return {"kind": kind}
