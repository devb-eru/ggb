@tool
extends Button

@export var slot_id := "slot_01"
@export var autosave := false
@export var show_divider := true
@export var selected := false:
	set(value):
		selected = value
		if is_node_ready(): _update_selection()

@onready var title_label: Label = $Text/Title
@onready var detail_label: Label = $Text/Detail
@onready var date_label: Label = $Timing/Date
@onready var duration_label: Label = $Timing/Duration
@onready var thumbnail: TextureRect = $Thumbnail
var summary: Dictionary = {}

func _ready() -> void:
	_update_selection()

func _update_selection() -> void:
	$SelectedRow.visible = selected and not autosave
	$AutosaveFill.visible = selected and autosave
	$AutosaveFrame.visible = autosave
	$Divider.visible = show_divider and not selected and not autosave

func show_summary(value: Dictionary, locale: String) -> void:
	summary = value.duplicate(true)
	var english := locale.begins_with("en")
	var available := bool(value.get("available", false))
	var location := preload("res://scripts/ui/save_slot_text.gd").location(value.get("location_id", ""), locale)
	title_label.text = ("Autosave" if english else "자동 저장") if autosave else location
	if not available: title_label.text = "Empty" if english else "비어 있음"
	$Empty.text = "Empty" if english else "비어 있음"
	$Empty.visible = not available
	for label in [title_label, detail_label, date_label, duration_label]: label.visible = available
	detail_label.text = location if autosave and available else (("Day %d" if english else "%d일차") % (int(value.get("day_index", 0)) + 1) if available else "")
	date_label.text = preload("res://scripts/ui/save_slot_text.gd").date(int(value.get("updated_at_utc", 0))) if available else ""
	duration_label.text = preload("res://scripts/ui/save_slot_text.gd").duration(value.get("play_seconds", -1)) if available else ""
	var image: Texture2D = value.get("thumbnail")
	thumbnail.texture = image if available and image != null else preload("res://assets/ui/save_load/textures/empty_thumbnail.tres")
	$ThumbnailFrame.visible = available and image != null
	accessibility_description = " · ".join(PackedStringArray([title_label.text, detail_label.text, date_label.text, duration_label.text]))
	tooltip_text = ""
