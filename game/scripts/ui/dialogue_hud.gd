@tool
extends Control
## Layout, textures and base typography belong to dialogue_hud.tscn.
## Only reading accessibility and the invisible click region are adapted here.

@export_group("Reading accessibility")
@export_range(0.0, 400.0, 1.0) var enlarged_reading_extra_height := 170.0
@export var align_name_rule_to_speaker := true
@export var name_rule_gap := 12.0
@export_range(0.0, 80.0, 1.0) var scrollbar_click_clearance := 30.0

var _base_fonts: Dictionary = {}
var _base_tops: Dictionary = {}
var _base_rule_bottom := 0.0
var _reading_scale := 1.0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	for path in ["DialogueBacking/Margin/Body/SpeakerLabel", "DialogueBacking/Margin/Body/DialogueScroll/DialogueText", "DialogueChoicePanel/Margin/Choices/DialogueChoice1", "DialogueChoicePanel/Margin/Choices/DialogueChoice2", "DialogueChoicePanel/Margin/Choices/DialogueChoice3"]:
		var control: Control = get_node(path)
		_base_fonts[path] = control.get_theme_font_size("font_size")
	for path in ["DialogueBacking", "DialogueReadability", "DialogueOrnament", "SpeakerNameplateArt"]:
		_base_tops[path] = get_node(path).offset_top
	_base_rule_bottom = get_node("SpeakerNameplateArt").offset_bottom
	resized.connect(_sync_reading_regions.call_deferred)
	get_node("DialogueBacking/Margin/Body/SpeakerLabel").resized.connect(_sync_reading_regions.call_deferred)
	get_node("DialogueBacking/Margin/Body/DialogueScroll").resized.connect(_sync_reading_regions.call_deferred)
	_sync_reading_regions.call_deferred()

func prepare_for_gameplay() -> void:
	get_node("PreviewBackground").hide()
	get_node("StandingPortrait").texture = null
	get_node("DialogueChoicePanel").hide()
	get_node("DialogueChoiceInputBlocker").hide()
	hide()

func apply_reading_scale(value: float) -> void:
	var scale := clampf(value, 1.0, 2.0)
	_reading_scale = scale
	for path: String in _base_fonts:
		get_node(path).add_theme_font_size_override("font_size", roundi(_base_fonts[path] * scale))
	for path: String in _base_tops:
		get_node(path).offset_top = _base_tops[path] - enlarged_reading_extra_height * (scale - 1.0)
	get_node("SpeakerNameplateArt").offset_bottom = _base_rule_bottom - enlarged_reading_extra_height * (scale - 1.0)
	_sync_reading_regions.call_deferred()

func _sync_reading_regions() -> void:
	if Engine.is_editor_hint() or not is_inside_tree(): return
	var speaker: Label = get_node("DialogueBacking/Margin/Body/SpeakerLabel")
	var art: TextureRect = get_node("SpeakerNameplateArt")
	if align_name_rule_to_speaker and _reading_scale > 1.0:
		art.position.y = speaker.get_global_rect().end.y - global_position.y - art.size.y * 0.5 + name_rule_gap
	var scroll: ScrollContainer = get_node("DialogueBacking/Margin/Body/DialogueScroll")
	var body_click: Button = get_node("DialogueNext")
	body_click.position = scroll.global_position - global_position
	body_click.size = Vector2(maxf(0, scroll.size.x - scrollbar_click_clearance), scroll.size.y)
