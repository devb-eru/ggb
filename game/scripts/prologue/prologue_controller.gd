class_name PrologueController
extends Control

signal return_to_title_requested

const MANSION_BACKGROUND := preload("res://assets/prologue/prologue_mansion_hall_v01.png")
const ROOMS_PRIMARY_ATLAS := preload("res://assets/prologue/prologue_rooms_primary_atlas_v01.png")
const ROOMS_SECONDARY_ATLAS := preload("res://assets/prologue/prologue_rooms_secondary_atlas_v01.png")
const SERVANT_ATLAS := preload("res://assets/prologue/prologue_servants_atlas_v01.png")
const ROOM_ART_SCRIPT := preload("res://scripts/prologue/prologue_room_art.gd")
const WINDOW_INSPECTION_ART_SCRIPT := preload("res://scripts/prologue/prologue_window_inspection_art.gd")
const INVENTORY_DRAG_SLOT_SCRIPT := preload("res://scripts/ui/inventory_drag_slot.gd")
const INVENTORY_DROP_TARGET_SCRIPT := preload("res://scripts/ui/inventory_drop_target.gd")

const ROOM_NAMES := {
	"M2_BEDROOM": "주인공의 침실",
	"M1_CENTRAL_HALL": "중앙홀",
	"M1_PARLOR": "대응접실",
	"M1_LIBRARY_OUTER": "외부 서고",
	"M1_NORTH_ARCHIVE_HALL": "북쪽 기록 회랑",
	"M1_KITCHEN": "주방",
	"M1_GREENHOUSE_VESTIBULE": "온실 앞",
}
const PORTRAIT_REGIONS := {
	"EDGAR": Rect2(0, 0, 350, 941),
	"MARA1": Rect2(330, 0, 410, 941),
	"MARA2": Rect2(650, 0, 380, 941),
	"LUCA": Rect2(1000, 0, 300, 941),
	"IRIS": Rect2(1230, 0, 442, 941),
}
const ROOM_ATLAS_REGIONS := {
	"M2_BEDROOM": {"atlas": "primary", "region": Rect2(0, 0, 836, 470)},
	"M1_PARLOR": {"atlas": "primary", "region": Rect2(836, 0, 836, 470)},
	"M1_LIBRARY_OUTER": {"atlas": "primary", "region": Rect2(0, 470, 836, 471)},
	"M1_KITCHEN": {"atlas": "primary", "region": Rect2(836, 470, 836, 471)},
	"M1_NORTH_ARCHIVE_HALL": {"atlas": "secondary", "region": Rect2(0, 0, 836, 470)},
	"M1_GREENHOUSE_VESTIBULE": {"atlas": "secondary", "region": Rect2(836, 0, 836, 470)},
	"M2_BEDROOM_NIGHT": {"atlas": "secondary", "region": Rect2(0, 470, 836, 471)},
	"M2_BEDROOM_RESET": {"atlas": "secondary", "region": Rect2(836, 470, 836, 471)},
}
const P3_BOOKS := {
	"BOOK_MECHANICAL": {"label": "기계 도면집", "shelf": "SHELF_CLOCK"},
	"BOOK_FLORA": {"label": "온실 식물지", "shelf": "SHELF_FLOWER"},
	"BOOK_LEDGER": {"label": "식탁 업무록", "shelf": "SHELF_CUP"},
}
const P3_JOURNAL_CHOICES := {
	"author": {
		"label": "누가 쓴 장부입니까?",
		"response": "주인님의 기록입니다.",
	},
	"locked": {
		"label": "왜 잠겨 있습니까?",
		"response": "손상된 기록은 잘못 읽히기 쉽습니다.",
	},
	"silent": {
		"label": "말없이 내려놓는다",
		"response": "",
	},
}
const P3B_LABELS := {
	"EDGAR": "에드가 · LOCK",
	"MARA1": "마라 1 · MAINT",
	"LUCA": "루카 · BIO",
	"IRIS": "이리스 · CLIMATE",
	"MARA2": "마라 2 · ARCHIVE",
}
const P3B_OWNERS := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
const TEA_STEPS := [
	"빈 잔 데우기",
	"데운 물 버리기",
	"찻잎 한 스푼",
	"뜨거운 물 붓기",
	"모래시계 기다리기",
	"잔에 따르기",
]
const TEA_STEP_ITEMS := ["HOT_WATER", "CUP", "TEA_LEAVES", "HOT_WATER", "TIMER", "TEAPOT"]
const TEA_STEP_ITEM_LABELS := ["뜨거운 물", "빈 찻잔", "찻잎", "뜨거운 물", "모래시계", "찻주전자"]

var _slot_id := "slot_01"
var _resume_id := "P1_ENTRY"
var _test_mode := false
var _progress: Dictionary = {}
var _selected_item := ""
var _current_room := "M2_BEDROOM"

var _background: TextureRect
var _room_art
var _hotspot_layer: Control
var _location_label: Label
var _objective_label: Label
var _status_label: Label
var _notebook_button: Button
var _inventory_panel: PanelContainer
var _inventory_slots: Array[Button] = []
var _menu_button: Button
var _dialogue_layer: Control
var _portrait: TextureRect
var _speaker_label: Label
var _dialogue_label: Label
var _dialogue_next: Button
var _dialogue_choice_blocker: ColorRect
var _dialogue_choice_panel: PanelContainer
var _dialogue_choice_buttons: Array[Button] = []
var _dialogue_choice_focus_index := 0
var _dialogue_choice_active := false
var _modal_layer: Control
var _modal_panel: PanelContainer
var _modal_body: VBoxContainer
var _inspection_layer: Control
var _inspection_panel: PanelContainer
var _window_title: Label
var _window_hint_label: Label
var _window_feedback_label: Label
var _window_art
var _window_drop_targets: Dictionary = {}
var _inspected_window := -1
var _inspection_active := false
var _fade: ColorRect

var _dialogue_lines: Array = []
var _dialogue_index := 0
var _dialogue_after := Callable()
var _dialogue_active := false
var _modal_active := false
var _p3_journal_prompt_active := false


func configure_session(slot_id: String, resume_id: String, test_mode: bool = false) -> void:
	_slot_id = slot_id
	_resume_id = resume_id
	_test_mode = test_mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_load_progress()
	_apply_accessibility_profile()
	if _is_prologue_complete():
		_show_after_reset()
		return
	_enter_room(String(_progress.get("current_room", "M2_BEDROOM")))
	if not bool(_progress.get("P1_complete", false)):
		_show_p1_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook_toggle"):
		if _dialogue_choice_active:
			_focus_p3_silent_choice()
		elif _inspection_active:
			_close_window_inspection()
		elif _modal_active:
			_close_modal()
		else:
			_open_notebook()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _dialogue_choice_active:
			_focus_p3_silent_choice()
		elif _inspection_active:
			_close_window_inspection()
		elif _modal_active:
			_close_modal()
		elif _dialogue_active:
			_advance_dialogue()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_background = TextureRect.new()
	_background.name = "MansionBackground"
	_background.texture = MANSION_BACKGROUND
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_meta("asset_id", "BG_PROLOGUE_MANSION_HALL_V01")
	_background.set_meta("is_generated", true)
	add_child(_background)

	var atmosphere := ColorRect.new()
	atmosphere.color = Color(0.02, 0.015, 0.06, 0.14)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	_room_art = ROOM_ART_SCRIPT.new()
	_room_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room_art.modulate = Color(1.0, 1.0, 1.0, 0.32)
	add_child(_room_art)

	_hotspot_layer = Control.new()
	_hotspot_layer.name = "Hotspots"
	_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotspot_layer)

	_build_window_inspection_ui()
	_build_persistent_ui()
	_build_dialogue_ui()
	_build_modal_ui()

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)


func _build_window_inspection_ui() -> void:
	_inspection_layer = Control.new()
	_inspection_layer.name = "WindowInspectionLayer"
	_inspection_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspection_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspection_layer.visible = false
	add_child(_inspection_layer)

	var dimmer := ColorRect.new()
	dimmer.name = "InspectionDimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(dimmer, Rect2(0, 86, 1680, 994))
	_inspection_layer.add_child(dimmer)

	_inspection_panel = PanelContainer.new()
	_inspection_panel.name = "WindowInspectionPanel"
	_inspection_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.018, 0.050, 0.99), Color(0.70, 0.42, 0.23, 0.98), 5, 12))
	_place(_inspection_panel, Rect2(210, 115, 1390, 850))
	_inspection_layer.add_child(_inspection_panel)

	var content := Control.new()
	content.name = "WindowInspectionContent"
	_inspection_panel.add_child(content)

	_window_title = Label.new()
	_window_title.name = "WindowInspectionTitle"
	_window_title.add_theme_font_size_override("font_size", 32)
	_window_title.add_theme_color_override("font_color", Color(0.96, 0.79, 0.52))
	_place(_window_title, Rect2(48, 28, 820, 48))
	content.add_child(_window_title)

	_window_hint_label = Label.new()
	_window_hint_label.name = "WindowInspectionHint"
	_window_hint_label.text = "오른쪽 인벤토리의 도구를 위·가운데·아래 영역으로 드래그하십시오."
	_window_hint_label.add_theme_font_size_override("font_size", 20)
	_window_hint_label.add_theme_color_override("font_color", Color(0.91, 0.89, 0.84))
	_place(_window_hint_label, Rect2(48, 78, 1180, 36))
	content.add_child(_window_hint_label)

	_window_art = WINDOW_INSPECTION_ART_SCRIPT.new()
	_window_art.name = "WindowInspectionArt"
	_place(_window_art, Rect2(70, 120, 1250, 590))
	content.add_child(_window_art)

	var zone_specs := [
		{"id": "TOP", "label": "위쪽", "rect": Rect2(160, 170, 1070, 140)},
		{"id": "MIDDLE", "label": "가운데", "rect": Rect2(160, 335, 1070, 155)},
		{"id": "BOTTOM", "label": "아래", "rect": Rect2(160, 515, 1070, 145)},
	]
	for spec_value in zone_specs:
		var spec: Dictionary = spec_value
		var zone_id := String(spec["id"])
		var target = INVENTORY_DROP_TARGET_SCRIPT.new()
		target.name = "WindowDrop%s" % zone_id.capitalize()
		target.configure("WINDOW_ZONE_%s" % zone_id)
		target.text = String(spec["label"])
		target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target.add_theme_font_size_override("font_size", 22)
		target.add_theme_stylebox_override("normal", _style(Color(0.04, 0.025, 0.07, 0.34), Color(0.73, 0.61, 0.44, 0.72), 3, 8))
		target.add_theme_stylebox_override("hover", _style(Color(0.18, 0.08, 0.16, 0.62), Color(0.98, 0.72, 0.34, 0.98), 5, 8))
		target.add_theme_stylebox_override("focus", _style(Color(0.12, 0.05, 0.15, 0.66), Color(0.60, 0.82, 1.0, 0.98), 5, 8))
		_place(target, spec["rect"])
		target.inventory_item_dropped.connect(_on_window_item_dropped)
		target.pressed.connect(_on_window_zone_pressed.bind(zone_id))
		_window_drop_targets[zone_id] = target
		content.add_child(target)

	_window_feedback_label = Label.new()
	_window_feedback_label.name = "WindowFeedback"
	_window_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_window_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window_feedback_label.add_theme_font_size_override("font_size", 21)
	_window_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.53))
	_place(_window_feedback_label, Rect2(120, 708, 1110, 72))
	content.add_child(_window_feedback_label)

	var close_button := _make_button("확대 닫기", Rect2(1160, 24, 170, 58), _close_window_inspection)
	close_button.name = "CloseWindowInspection"
	content.add_child(close_button)


func _build_persistent_ui() -> void:
	var top_shade := ColorRect.new()
	top_shade.color = Color(0.015, 0.01, 0.03, 0.78)
	_place(top_shade, Rect2(0, 0, 1920, 86))
	add_child(top_shade)

	_menu_button = _make_button("메뉴", Rect2(22, 18, 136, 52), _open_menu)
	_menu_button.name = "MenuButton"
	add_child(_menu_button)

	_location_label = Label.new()
	_location_label.name = "LocationLabel"
	_location_label.add_theme_font_size_override("font_size", 24)
	_location_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_location_label, Rect2(180, 18, 430, 52))
	add_child(_location_label)

	var objective_panel := PanelContainer.new()
	objective_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.018, 0.055, 0.88), Color(0.48, 0.26, 0.55, 0.85), 2, 10))
	_place(objective_panel, Rect2(635, 14, 760, 60))
	add_child(objective_panel)
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 20)
	objective_panel.add_child(_objective_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.53))
	_place(_status_label, Rect2(500, 90, 920, 44))
	add_child(_status_label)

	_notebook_button = _make_button("수첩\nN", Rect2(24, 912, 116, 132), _open_notebook)
	_notebook_button.name = "NotebookButton"
	_notebook_button.add_theme_font_size_override("font_size", 22)
	add_child(_notebook_button)

	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.018, 0.045, 0.91), Color(0.64, 0.25, 0.18, 0.94), 4, 6))
	_place(_inventory_panel, Rect2(1692, 90, 204, 930))
	add_child(_inventory_panel)
	var inventory_margin := MarginContainer.new()
	inventory_margin.add_theme_constant_override("margin_left", 12)
	inventory_margin.add_theme_constant_override("margin_top", 14)
	inventory_margin.add_theme_constant_override("margin_right", 12)
	inventory_margin.add_theme_constant_override("margin_bottom", 14)
	_inventory_panel.add_child(inventory_margin)
	var inventory_column := VBoxContainer.new()
	inventory_column.add_theme_constant_override("separation", 12)
	inventory_margin.add_child(inventory_column)
	var inventory_title := Label.new()
	inventory_title.text = "인벤토리"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_font_size_override("font_size", 19)
	inventory_column.add_child(inventory_title)
	for index in range(6):
		var slot: Button = INVENTORY_DRAG_SLOT_SCRIPT.new()
		slot.name = "InventorySlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(170, 126)
		slot.text = "비어 있음"
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_theme_font_size_override("font_size", 17)
		slot.add_theme_stylebox_override("normal", _style(Color(0.08, 0.035, 0.075, 0.96), Color(0.63, 0.26, 0.18, 0.92), 4, 4))
		slot.add_theme_stylebox_override("hover", _style(Color(0.17, 0.055, 0.13, 0.98), Color(0.90, 0.47, 0.26, 1.0), 5, 4))
		slot.pressed.connect(_on_inventory_slot_pressed.bind(index))
		slot.drag_started.connect(_on_inventory_drag_started)
		_inventory_slots.append(slot)
		inventory_column.add_child(slot)


func _build_dialogue_ui() -> void:
	_dialogue_layer = Control.new()
	_dialogue_layer.name = "DialogueLayer"
	_dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.visible = false
	add_child(_dialogue_layer)

	_portrait = TextureRect.new()
	_portrait.name = "StandingPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_portrait, Rect2(40, 110, 650, 940))
	_dialogue_layer.add_child(_portrait)

	var backing := PanelContainer.new()
	backing.name = "DialogueBacking"
	backing.add_theme_stylebox_override("panel", _style(Color(0.008, 0.006, 0.014, 0.91), Color(0.36, 0.18, 0.36, 0.92), 3, 8))
	_place(backing, Rect2(185, 735, 1490, 310))
	_dialogue_layer.add_child(backing)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 400)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 24)
	backing.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_font_size_override("font_size", 25)
	_speaker_label.add_theme_color_override("font_color", Color(0.93, 0.72, 0.44))
	body.add_child(_speaker_label)
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueText"
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 24)
	_dialogue_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.91))
	body.add_child(_dialogue_label)
	_dialogue_next = Button.new()
	_dialogue_next.name = "DialogueNext"
	_dialogue_next.text = "계속"
	_dialogue_next.custom_minimum_size = Vector2(170, 46)
	_dialogue_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dialogue_next.pressed.connect(_advance_dialogue)
	body.add_child(_dialogue_next)

	_dialogue_choice_blocker = ColorRect.new()
	_dialogue_choice_blocker.name = "DialogueChoiceInputBlocker"
	_dialogue_choice_blocker.color = Color(0.0, 0.0, 0.0, 0.16)
	_dialogue_choice_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_choice_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_choice_blocker.visible = false
	_dialogue_layer.add_child(_dialogue_choice_blocker)
	_dialogue_layer.move_child(_dialogue_choice_blocker, 0)

	_dialogue_choice_panel = PanelContainer.new()
	_dialogue_choice_panel.name = "DialogueChoicePanel"
	_dialogue_choice_panel.add_theme_stylebox_override("panel", _style(Color(0.01, 0.008, 0.018, 0.72), Color(0.29, 0.36, 0.48, 0.64), 2, 3))
	_place(_dialogue_choice_panel, Rect2(1190, 255, 470, 365))
	_dialogue_choice_panel.visible = false
	_dialogue_layer.add_child(_dialogue_choice_panel)
	var choice_margin := MarginContainer.new()
	choice_margin.add_theme_constant_override("margin_left", 12)
	choice_margin.add_theme_constant_override("margin_top", 12)
	choice_margin.add_theme_constant_override("margin_right", 12)
	choice_margin.add_theme_constant_override("margin_bottom", 12)
	_dialogue_choice_panel.add_child(choice_margin)
	var choice_list := VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 10)
	choice_margin.add_child(choice_list)
	var choice_header := Label.new()
	choice_header.text = "장부에 대해 묻는다"
	choice_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	choice_header.add_theme_font_size_override("font_size", 18)
	choice_header.add_theme_color_override("font_color", Color(0.78, 0.81, 0.88))
	choice_list.add_child(choice_header)
	for choice_id in ["author", "locked", "silent"]:
		var button := Button.new()
		button.name = "JournalChoice%s" % choice_id.capitalize()
		button.set_meta("choice_id", choice_id)
		button.custom_minimum_size = Vector2(420, 88)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 23)
		button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.95))
		button.add_theme_stylebox_override("normal", _choice_style(Color(0.015, 0.012, 0.022, 0.88), Color(0.22, 0.24, 0.31, 0.76), 3))
		button.add_theme_stylebox_override("hover", _choice_style(Color(0.055, 0.075, 0.09, 0.94), Color(0.37, 0.79, 0.86, 0.94), 5))
		button.add_theme_stylebox_override("focus", _choice_style(Color(0.055, 0.075, 0.09, 0.98), Color(0.42, 0.86, 0.92, 1.0), 6))
		button.pressed.connect(_answer_p3_journal_choice.bind(choice_id))
		button.focus_entered.connect(_on_dialogue_choice_focused.bind(_dialogue_choice_buttons.size()))
		button.mouse_entered.connect(_focus_dialogue_choice.bind(_dialogue_choice_buttons.size()))
		_dialogue_choice_buttons.append(button)
		choice_list.add_child(button)


func _build_modal_ui() -> void:
	_modal_layer = Control.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.visible = false
	add_child(_modal_layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.76)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(dimmer)
	_modal_panel = PanelContainer.new()
	_modal_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.022, 0.060, 0.99), Color(0.66, 0.35, 0.58, 0.95), 4, 12))
	_place(_modal_panel, Rect2(510, 190, 900, 700))
	_modal_layer.add_child(_modal_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 42)
	_modal_panel.add_child(margin)
	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 18)
	margin.add_child(_modal_body)


func _load_progress() -> void:
	_progress = _default_progress()
	if _test_mode:
		_normalize_window_states()
		return
	var event_states: Dictionary = GameState.get_value(&"loop_state.event_local_states", {})
	if event_states.get("PROLOGUE") is Dictionary:
		var stored_progress: Dictionary = event_states["PROLOGUE"]
		_progress.merge(stored_progress, true)
		if not stored_progress.has("window_states"):
			_progress["window_states"] = _window_states_from_stages(Array(stored_progress.get("windows", [0, 0, 0])))
		var legacy_journal_choice := String(_progress.get("p3_journal_choice", ""))
		if legacy_journal_choice in ["author", "locked"]:
			var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
			if legacy_journal_choice not in asked_questions:
				asked_questions.append(legacy_journal_choice)
			_progress["p3_journal_questions_asked"] = asked_questions
			_progress["p3_journal_choice"] = "pending"
	_normalize_window_states()
	_current_room = String(_progress.get("current_room", "M2_BEDROOM"))


func _default_progress() -> Dictionary:
	return {
		"P1_complete": false,
		"P2_complete": false,
		"P3_complete": false,
		"P3B_complete": false,
		"P4_complete": false,
		"P5_complete": false,
		"P6_complete": false,
		"iris_greeting_seen": false,
		"current_room": "M2_BEDROOM",
		"time_block": "morning",
		"p1_inspections": [],
		"windows": [0, 0, 0],
		"window_states": _make_default_window_states(),
		"bird_observed": false,
		"p2_brush_hint_seen": false,
		"p2_spanner_hint_seen": false,
		"p3_placed": {},
		"p3_journal_seen": false,
		"p3_journal_choice": "",
		"p3_journal_questions_asked": [],
		"p3b_placed": {},
		"tea_step": 0,
		"p5_observations": [],
		"introduced": [],
		"notebook_entries": ["오늘의 일과: 대응접실 창문, 외부 서고 책, 북쪽 회랑 초상화."],
		"intros_seen": [],
	}


func _apply_accessibility_profile() -> void:
	var profile_result := AccessibilityProfileStore.new().load_profile()
	var profile: Dictionary = profile_result.get("profile", {})
	var scale := float(profile.get("text_scale", 1.0))
	var ui_theme := Theme.new()
	ui_theme.default_font_size = int(round(19.0 * scale))
	theme = ui_theme


func _show_p1_intro() -> void:
	_add_unique("introduced", "EDGAR")
	_show_dialogue([
		{"speaker": "SYSTEM", "text": "커튼 사이의 아침빛이 눈꺼풀보다 먼저 같은 자리를 밝힌다."},
		{"speaker": "SYSTEM", "text": "[문밖] 레이피어 끝이 바닥에 닿고, 정확히 세 번의 노크가 이어진다."},
		{"speaker": "에드가", "portrait": "EDGAR", "text": "기상 시각입니다, 아가씨. 오늘 일정은 준비되어 있습니다."},
		{"speaker": "에드가", "portrait": "EDGAR", "text": "방 안을 확인하신 뒤 나와 주십시오. 대응접실의 창문, 외부 서고의 책, 북쪽 기록 회랑의 초상화를 부탁드립니다."},
	], func() -> void: _set_status("빛과 사물 중 마음에 걸리는 것을 조사해 보십시오."))


func _enter_room(room_id: String) -> void:
	_close_window_inspection(false)
	_current_room = room_id
	_progress["current_room"] = room_id
	_location_label.text = String(ROOM_NAMES.get(room_id, room_id))
	_set_room_background(room_id)
	_selected_item = ""
	_update_inventory([])
	_clear_hotspots()
	_room_art.set_room(room_id, _progress)
	match room_id:
		"M2_BEDROOM":
			_build_bedroom()
		"M1_CENTRAL_HALL":
			_build_hall()
		"M1_PARLOR":
			_build_parlor()
		"M1_LIBRARY_OUTER":
			_build_library()
		"M1_NORTH_ARCHIVE_HALL":
			_build_archive()
		"M1_KITCHEN":
			_build_kitchen()
		"M1_GREENHOUSE_VESTIBULE":
			_build_greenhouse()
	_update_objective()
	_save_progress()


func _rebuild_current_room_content() -> void:
	_clear_hotspots()
	_room_art.set_room(_current_room, _progress)
	match _current_room:
		"M1_PARLOR":
			_build_parlor()
		"M1_LIBRARY_OUTER":
			_build_library()
		"M1_NORTH_ARCHIVE_HALL":
			_build_archive()
		"M1_KITCHEN":
			_build_kitchen()
	_update_objective()


func _build_bedroom() -> void:
	if bool(_progress.get("P4_complete", false)):
		_progress["time_block"] = "night"
		_add_hotspot("BED", "침대\n오늘을 끝낸다", Rect2(245, 640, 480, 170), _on_sleep_bed)
		_add_hotspot("WINDOW", "밤의 창문", Rect2(1280, 210, 300, 380), _inspect_bedroom.bind("window"))
		_add_hotspot("HALL", "조금 더 둘러본다", Rect2(790, 870, 360, 92), _enter_room.bind("M1_CENTRAL_HALL"))
		if not _intro_seen("P6"):
			_mark_intro("P6")
			_show_dialogue([
				{"speaker": "에드가", "portrait": "EDGAR", "text": "오늘 일정은 종료되었습니다. 침실 상태도 확인했습니다."},
				{"speaker": "에드가", "portrait": "EDGAR", "text": "이제 쉬시는 편이 좋겠습니다."},
			])
		return

	_add_hotspot("BED", "침대", Rect2(180, 610, 560, 210), _inspect_bedroom.bind("bed"))
	_add_hotspot("WINDOW", "침실 창문", Rect2(1250, 180, 330, 410), _inspect_bedroom.bind("window"))
	_add_hotspot("PHOTO", "아버지 사진", Rect2(930, 245, 190, 245), _inspect_bedroom.bind("photo"))
	_add_hotspot("NOTEBOOK", "낙서 수첩", Rect2(610, 690, 180, 115), _inspect_bedroom.bind("notebook"))
	_add_hotspot("EXIT", "방을 나선다", Rect2(825, 850, 300, 100), _leave_bedroom_morning)


func _inspect_bedroom(object_id: String) -> void:
	if _dialogue_active or _modal_active:
		return
	_add_unique("p1_inspections", object_id)
	var lines := {
		"bed": "막 일어난 자리인데도 주름 하나 없이 반듯하다. 천 아래에는 매트리스보다 단단한 곡면이 닿는다.",
		"window": "정원은 맑다. 그런데 유리는 햇빛보다 미지근하고, 멀리 있는 새는 한 번도 고도를 바꾸지 않는다.",
		"photo": "아버지와 함께 찍힌 사진이다. 익숙한 얼굴인데 이 장면으로 이어지는 기억은 없다. 사진 표면만 차갑다.",
		"notebook": "고딕 저택 낙서와 빈 페이지. 연필 압흔은 내가 쓰기 전부터 다음 장까지 이어져 있다.",
	}
	if object_id == "notebook":
		_add_notebook("수첩의 빈 페이지 아래에 이전 필압 같은 자국이 남아 있다.")
	_show_dialogue([{"speaker": "주인공", "text": String(lines[object_id])}])
	_room_art.set_room(_current_room, _progress)
	_save_progress()


func _leave_bedroom_morning() -> void:
	if _dialogue_active or _modal_active:
		return
	if Array(_progress.get("p1_inspections", [])).size() < 2:
		_show_modal(
			"에드가의 확인",
			"아직 방 안을 충분히 살펴보지 않았습니다. 그래도 일과를 시작합니까?",
			[
				{"label": "일과를 시작한다", "action": _complete_p1},
				{"label": "조금 더 살펴본다", "action": _close_modal},
			]
		)
		return
	_complete_p1()


func _complete_p1() -> void:
	_close_modal()
	_progress["P1_complete"] = true
	_progress["time_block"] = "morning"
	_add_unique("introduced", "EDGAR")
	_save_progress()
	_enter_room("M1_CENTRAL_HALL")
	_show_dialogue([
		{"speaker": "SYSTEM", "text": "계단 아래에서 저택의 세 방향이 한눈에 들어온다."},
		{"speaker": "에드가", "portrait": "EDGAR", "text": "순서는 정하지 않겠습니다. 완료한 일은 중앙홀에서 확인할 수 있습니다."},
	])


func _build_hall() -> void:
	var morning_complete := _morning_tasks_complete()
	if not bool(_progress.get("P4_complete", false)):
		_add_hotspot("PARLOR", _task_label("대응접실 · 창문", "P2_complete"), Rect2(110, 410, 350, 180), _enter_room.bind("M1_PARLOR"))
		_add_hotspot("LIBRARY", _task_label("외부 서고 · 책", "P3_complete"), Rect2(1120, 445, 300, 180), _enter_room.bind("M1_LIBRARY_OUTER"))
		_add_hotspot("ARCHIVE", _task_label("북쪽 회랑 · 초상화", "P3B_complete"), Rect2(690, 240, 350, 150), _enter_room.bind("M1_NORTH_ARCHIVE_HALL"))
		if morning_complete:
			_add_hotspot("KITCHEN", "주방 · 차 준비", Rect2(1430, 430, 260, 180), _enter_room.bind("M1_KITCHEN"))
		else:
			_add_hotspot("REPORT", "에드가에게 보고", Rect2(760, 650, 360, 105), _report_tasks)
		return

	_progress["time_block"] = "evening_free"
	_add_hotspot("GREENHOUSE", _task_label("온실 앞 · 선택 조사", "P5_complete"), Rect2(1415, 405, 275, 190), _enter_room.bind("M1_GREENHOUSE_VESTIBULE"))
	_add_hotspot("BEDROOM", "침실로 돌아간다", Rect2(720, 220, 420, 150), _enter_room.bind("M2_BEDROOM"))
	_add_hotspot("PARLOR", "조용해진 대응접실", Rect2(120, 430, 330, 160), _evening_ambient.bind("대응접실의 창문은 아침에 닦은 흔적 그대로인데, 바깥빛만 한 치도 움직이지 않았다."))
	_add_hotspot("LIBRARY", "잠긴 서재 방향", Rect2(1110, 460, 310, 160), _evening_ambient.bind("기록 내실의 유리문 뒤에서 종이 넘기는 소리가 난다. 안에는 아무도 보이지 않는다."))


func _report_tasks() -> void:
	var missing: Array[String] = []
	for pair in [["P2_complete", "대응접실 창문"], ["P3_complete", "외부 서고 책"], ["P3B_complete", "북쪽 회랑 초상화"]]:
		if not bool(_progress.get(pair[0], false)):
			missing.append(pair[1])
	_show_dialogue([{"speaker": "에드가", "portrait": "EDGAR", "text": "아직 남은 일과가 있습니다. %s. 순서는 자유지만 확인 없이 넘길 수는 없습니다." % ", ".join(missing)}])


func _build_parlor() -> void:
	_normalize_window_states()
	_sync_window_stages()
	_update_inventory([
		{"id": "SOFT_CLOTH", "label": "부드러운 천"},
		{"id": "COARSE_BRUSH", "label": "거친 솔"},
		{"id": "WATER", "label": "물병"},
		{"id": "SPANNER", "label": "마라 1의 스패너"},
	])
	var windows: Array = _progress.get("windows", [0, 0, 0])
	for index in range(3):
		var stage := int(windows[index])
		_add_hotspot("WINDOW_%d" % index, "창 %d · 확대\n%s" % [index + 1, _window_stage_name(stage)], Rect2(300 + index * 420, 250, 300, 390), _on_window_pressed.bind(index))
	_add_hotspot("CLOCK", "대응접실 시계", Rect2(1450, 185, 180, 190), _show_dialogue.bind([{"speaker": "주인공", "text": "열두 칸이 모두 같은 폭인데, 마지막 칸 아래에 지워진 홈이 하나 더 있다."}]))
	_add_back_to_hall()
	if not _intro_seen("P2"):
		_mark_intro("P2")
		_add_unique("introduced", "MARA1")
		_show_dialogue([
			{"speaker": "마라 1", "portrait": "MARA1", "text": "오셨슴까, 아가씨. 전 위쪽을 맡을 테니 아래쪽 세 장만 부탁드림다."},
			{"speaker": "마라 1", "portrait": "MARA1", "text": "부드러운 천을 고르고 위의 먼지부터 아래로. 스패너는 쓰지 마십쇼. 저도 방금 쓸 뻔했으니까."},
		])


func _on_window_pressed(index: int) -> void:
	if _dialogue_active or _modal_active:
		return
	_open_window_inspection(index)


func _open_window_inspection(index: int) -> void:
	_normalize_window_states()
	if index < 0 or index >= Array(_progress.get("window_states", [])).size():
		return
	_inspected_window = index
	_inspection_active = true
	_inspection_layer.visible = true
	_selected_item = ""
	_refresh_inventory_selection()
	_set_window_feedback("도구를 원하는 오염 영역으로 드래그하십시오.")
	_refresh_window_inspection()
	_set_status("창 %d 확대 조사 중" % (index + 1))


func _close_window_inspection(update_status: bool = true) -> void:
	if _inspection_layer != null:
		_inspection_layer.visible = false
	_inspection_active = false
	_inspected_window = -1
	if update_status and _status_label != null:
		_set_status("창문 확대를 닫았다. 다른 창을 선택할 수 있다.")
	_refresh_inventory_selection()


func _refresh_window_inspection() -> void:
	if not _inspection_active or _inspected_window < 0:
		return
	var states: Array = _progress.get("window_states", [])
	if _inspected_window >= states.size():
		return
	var state: Dictionary = states[_inspected_window]
	_window_title.text = "창 %d 확대 · %s" % [_inspected_window + 1, _window_stage_name(_stage_from_window_state(state))]
	_window_art.set_window_state(_inspected_window, state)
	var clean := _is_window_clean(state)
	var top = _window_drop_targets["TOP"]
	var middle = _window_drop_targets["MIDDLE"]
	var bottom = _window_drop_targets["BOTTOM"]
	top.text = "위쪽\n%s" % ("먼지가 양옆으로 퍼짐" if bool(state.get("dust_spread", false)) else ("먼지" if bool(state.get("top_dust", true)) else "정리됨"))
	middle.text = "가운데\n%s" % ("얼룩" if bool(state.get("middle_stain", true)) else "정리됨")
	bottom.text = "아래\n%s" % ("물기" if bool(state.get("bottom_wet", false)) else "마른 상태")
	for target_value in _window_drop_targets.values():
		target_value.set_drop_enabled(not clean)
	_window_hint_label.text = "완료된 창입니다. 오염 패턴을 다시 확인할 수 있습니다." if clean else "오른쪽 인벤토리의 도구를 위·가운데·아래 영역으로 드래그하십시오."
	_refresh_inventory_selection()


func _on_window_zone_pressed(zone_id: String) -> void:
	if _selected_item.is_empty():
		_set_window_feedback("먼저 인벤토리에서 도구를 드래그하십시오. 키보드 조작은 도구 선택 후 영역을 누릅니다.")
		return
	_on_window_item_dropped(_selected_item, "WINDOW_ZONE_%s" % zone_id)


func _on_window_item_dropped(item_id: String, target_id: String) -> void:
	if _dialogue_active or _modal_active or not _inspection_active:
		return
	var zone_id := target_id.trim_prefix("WINDOW_ZONE_")
	_apply_window_tool(item_id, zone_id)


func _apply_window_tool(item_id: String, zone_id: String) -> void:
	var states: Array = _progress.get("window_states", [])
	if _inspected_window < 0 or _inspected_window >= states.size():
		return
	var state: Dictionary = states[_inspected_window].duplicate(true)
	if _is_window_clean(state):
		_set_window_feedback("이미 깨끗한 창이다.")
		return
	var feedback_kind := "neutral"
	match item_id:
		"SPANNER":
			_set_window_feedback("스패너는 창문에 사용할 수 없다. 마라 1이 황급히 손을 내민다.")
			if not bool(_progress.get("p2_spanner_hint_seen", false)):
				_progress["p2_spanner_hint_seen"] = true
				_show_dialogue([{"speaker": "마라 1", "portrait": "MARA1", "text": "그걸로 닦으면 창문보다 벽부터 열릴 검다. 천을 쓰십쇼, 천."}])
		"COARSE_BRUSH":
			state["top_dust"] = true
			state["dust_spread"] = true
			feedback_kind = "wrong"
			_set_window_feedback("거친 솔이 먼지를 양옆으로 퍼뜨렸다. 부드러운 천으로 바로 복구할 수 있다.")
			if not bool(_progress.get("p2_brush_hint_seen", false)):
				_progress["p2_brush_hint_seen"] = true
				_show_dialogue([{"speaker": "마라 1", "portrait": "MARA1", "text": "아가씨, 그 솔 말고 부드러운 천 말임다! 퍼진 먼지는 위에서부터 다시 모으면 됨다."}])
		"WATER":
			if zone_id == "MIDDLE" and not bool(state.get("top_dust", true)) and bool(state.get("middle_stain", true)):
				state["middle_stain"] = false
				state["bottom_wet"] = true
				feedback_kind = "water"
				_set_window_feedback("물로 얼룩이 풀렸다. 아래에 흐른 물기를 부드러운 천의 마른 면으로 걷어내야 한다.")
			elif zone_id == "BOTTOM" and not bool(state.get("top_dust", true)) and not bool(state.get("middle_stain", true)):
				state["bottom_wet"] = true
				feedback_kind = "water"
				_set_window_feedback("깨끗한 아래쪽이 다시 젖었다. 부드러운 천의 마른 면이 필요하다.")
			else:
				feedback_kind = "wrong"
				_set_window_feedback("먼지가 남은 상태에서 물을 쓰면 얼룩만 번진다. 위쪽 먼지부터 정리해야 한다.")
		"SOFT_CLOTH":
			match zone_id:
				"TOP":
					state["top_dust"] = false
					state["dust_spread"] = false
					feedback_kind = "correct"
					_set_window_feedback("위쪽 먼지를 아래 방향으로 모아 걷어냈다.")
					if _inspected_window == 2 and not bool(_progress.get("bird_observed", false)):
						_progress["bird_observed"] = true
						_add_notebook("같은 새가 18초 간격으로 같은 궤도를 두 번 지나갔다.")
						_show_dialogue([
							{"speaker": "SYSTEM", "text": "같은 새가 같은 날갯짓으로 다시 창을 가로지른다."},
							{"speaker": "마라 1", "portrait": "MARA1", "text": "일은 천천히 하시는데 눈은 좋으심다. 저 새까지 닦아낼 생각은 하지 마십쇼. ...농담입니다. 아마도."},
						])
				"MIDDLE":
					if bool(state.get("top_dust", true)):
						feedback_kind = "falling_dust"
						_set_window_feedback("아래부터 닦자 위쪽 먼지가 다시 떨어졌다. 위에서 아래 순서로 진행해야 한다.")
					elif bool(state.get("middle_stain", true)):
						state["middle_stain"] = false
						feedback_kind = "correct"
						_set_window_feedback("가운데 얼룩을 원형으로 닦아냈다.")
					else:
						_set_window_feedback("가운데는 이미 깨끗하다.")
				"BOTTOM":
					if bool(state.get("top_dust", true)) or bool(state.get("middle_stain", true)):
						feedback_kind = "falling_dust"
						_set_window_feedback("아래부터 닦자 위쪽 오염이 다시 떨어졌다. 위에서 아래 순서로 진행해야 한다.")
					elif bool(state.get("bottom_wet", false)):
						state["bottom_wet"] = false
						feedback_kind = "correct"
						_set_window_feedback("부드러운 천의 마른 면으로 아래 물기를 걷어냈다.")
					else:
						_set_window_feedback("아래쪽은 이미 마른 상태다.")
		_:
			_set_window_feedback("이 물건은 창문 닦기에 사용할 수 없다.")
	states[_inspected_window] = state
	_progress["window_states"] = states
	_sync_window_stages()
	_room_art.set_room("M1_PARLOR", _progress)
	_refresh_window_inspection()
	match feedback_kind:
		"falling_dust":
			_window_art.play_falling_dust()
		"wrong":
			_window_art.play_feedback(Color(0.78, 0.20, 0.18))
		"water":
			_window_art.play_feedback(Color(0.25, 0.62, 0.90))
		"correct":
			_window_art.play_feedback(Color(0.92, 0.72, 0.30))
	_save_progress()
	if _all_windows_clean() and not bool(_progress.get("P2_complete", false)):
		_complete_p2()


func _complete_p2() -> void:
	_progress["P2_complete"] = true
	_add_notebook("대응접실의 세 창을 닦았다. 주황빛 닦임 자국이 천보다 한순간 먼저 움직였다.")
	_update_objective()
	_save_progress()
	_show_dialogue([
		{"speaker": "마라 1", "portrait": "MARA1", "text": "깔끔함다! 다음에도 이 정도면 제가 일손 부족 얘기는 반만 하겠슴다."},
	], func() -> void:
		_close_window_inspection(false)
		_enter_room("M1_CENTRAL_HALL")
	)


func _set_window_feedback(message: String) -> void:
	_window_feedback_label.text = message
	_set_status(message)


func _build_library() -> void:
	var inventory: Array = []
	var placed: Dictionary = _progress.get("p3_placed", {})
	for book_id in P3_BOOKS:
		if book_id not in placed.values():
			inventory.append({"id": book_id, "label": String(P3_BOOKS[book_id]["label"])})
	_update_inventory(inventory)
	var shelves := [
		["SHELF_CLOCK", "시계·수직선\n기계공학", Rect2(315, 300, 285, 300)],
		["SHELF_FLOWER", "꽃잎·후광\n식물·환경", Rect2(720, 300, 285, 300)],
		["SHELF_CUP", "찻잔·이중고리\n생활 기록", Rect2(1125, 300, 285, 300)],
	]
	for shelf in shelves:
		var occupant := String(placed.get(shelf[0], ""))
		var label := String(shelf[1]) if occupant.is_empty() else "%s\n[정리됨]" % P3_BOOKS[occupant]["label"]
		_add_inventory_drop_hotspot(String(shelf[0]), label, shelf[2], _on_shelf_pressed.bind(String(shelf[0])), _on_shelf_item_dropped)
	_add_hotspot("INNER_DOOR", "기록 내실 유리문\n잠김", Rect2(1460, 210, 205, 460), _inspect_inner_door)
	_add_back_to_hall()
	var needs_journal_choice := bool(_progress.get("p3_journal_seen", false)) \
		and String(_progress.get("p3_journal_choice", "")) in ["", "pending"] \
		and not _p3_journal_prompt_active
	if not _intro_seen("P3"):
		_mark_intro("P3")
		_show_dialogue([
			{"speaker": "에드가", "portrait": "EDGAR", "text": "외부 서고의 반납분입니다. 책등 문양과 선반 표식을 맞춰 주십시오."},
			{"speaker": "에드가", "portrait": "EDGAR", "text": "기록 내실은 정리 대상이 아닙니다."},
		], _resume_p3_journal_choice if needs_journal_choice else Callable())
	elif needs_journal_choice:
		call_deferred("_resume_p3_journal_choice")


func _on_shelf_pressed(shelf_id: String) -> void:
	if _interaction_blocked() or bool(_progress.get("P3_complete", false)):
		return
	if _selected_item not in P3_BOOKS:
		_set_status("오른쪽 인벤토리의 책을 선반으로 드래그하십시오.")
		return
	var expected := String(P3_BOOKS[_selected_item]["shelf"])
	if shelf_id != expected:
		_set_status("책은 들어가지만 책등 높이가 맞지 않는다. 문양과 선반 표식을 다시 비교한다.")
		return
	var placed: Dictionary = _progress.get("p3_placed", {})
	placed[shelf_id] = _selected_item
	_progress["p3_placed"] = placed
	var journal_discovered := false
	if _selected_item == "BOOK_MECHANICAL" and not bool(_progress.get("p3_journal_seen", false)):
		_progress["p3_journal_seen"] = true
		_progress["p3_journal_choice"] = "pending"
		_p3_journal_prompt_active = true
		journal_discovered = true
		_add_notebook("기계 도면집 뒤에서 낡은 연구 장부가 떨어졌다. 안쪽 면에는 내가 그린 듯한 고딕 저택 낙서가 있다.")
	_selected_item = ""
	_save_progress()
	_rebuild_current_room_content()
	if journal_discovered:
		_show_dialogue([
			{"speaker": "SYSTEM", "text": "반납 슬롯 안쪽에서 낡은 일지 한 권이 떨어진다. 표지는 읽히지 않고, 본문 잉크는 한 방향으로 밀린 것처럼 겹쳐 있다."},
			{"speaker": "에드가", "portrait": "EDGAR", "text": "오래된 연구 장부입니다. 현재는 열람 대상이 아닙니다. 제자리에 두시는 편이 좋겠습니다."},
		], _show_p3_journal_choices)
		return
	_finish_p3_book_placement()


func _show_p3_journal_choices() -> void:
	_p3_journal_prompt_active = true
	_dialogue_active = false
	_dialogue_lines.clear()
	_dialogue_after = Callable()
	_dialogue_choice_active = true
	_dialogue_layer.visible = true
	_dialogue_choice_blocker.visible = true
	_dialogue_choice_panel.visible = true
	_dialogue_next.visible = false
	_speaker_label.text = "주인공"
	_dialogue_label.text = "에드가는 장부를 내려놓으라는 듯 손을 내민다. 무엇을 물어볼까."
	_set_dialogue_portrait("EDGAR")
	_refresh_p3_journal_choice_labels()
	_focus_dialogue_choice(_first_unasked_p3_choice_index())


func _answer_p3_journal_choice(choice_id: String) -> void:
	if not P3_JOURNAL_CHOICES.has(choice_id):
		return
	_hide_dialogue_choices()
	if choice_id == "silent":
		_dialogue_layer.visible = false
		_p3_journal_prompt_active = false
		_progress["p3_journal_choice"] = "silent"
		_save_progress()
		_set_status("말없이 장부를 내려놓았다. 에드가는 잠금쇠가 닫힌 것을 확인한다.")
		_finish_p3_book_placement()
		return
	var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
	if choice_id not in asked_questions:
		asked_questions.append(choice_id)
	_progress["p3_journal_questions_asked"] = asked_questions
	_progress["p3_journal_choice"] = "pending"
	_save_progress()
	var response := String(P3_JOURNAL_CHOICES[choice_id]["response"])
	_show_dialogue([
		{"speaker": "에드가", "portrait": "EDGAR", "text": response},
	], _show_p3_journal_choices)


func _resume_p3_journal_choice() -> void:
	if _current_room != "M1_LIBRARY_OUTER" or _dialogue_active or _modal_active or _p3_journal_prompt_active:
		return
	_p3_journal_prompt_active = true
	_progress["p3_journal_choice"] = "pending"
	_save_progress()
	_show_dialogue([
		{"speaker": "SYSTEM", "text": "내려놓지 못한 낡은 장부가 아직 손안에 있다. 표지의 글자는 읽히지 않는다."},
		{"speaker": "에드가", "portrait": "EDGAR", "text": "오래된 연구 장부입니다. 현재는 열람 대상이 아닙니다. 제자리에 두시는 편이 좋겠습니다."},
	], _show_p3_journal_choices)


func _finish_p3_book_placement() -> void:
	var placed: Dictionary = _progress.get("p3_placed", {})
	if placed.size() >= 3 and not bool(_progress.get("P3_complete", false)):
		_progress["P3_complete"] = true
		_save_progress()
		_rebuild_current_room_content()
		_show_dialogue([{"speaker": "에드가", "portrait": "EDGAR", "text": "분류가 끝났습니다. 기록 내실은 그대로 두십시오."}], func() -> void: _enter_room("M1_CENTRAL_HALL"))
		return
	_save_progress()
	_rebuild_current_room_content()


func _on_shelf_item_dropped(item_id: String, shelf_id: String) -> void:
	_selected_item = item_id
	_on_shelf_pressed(shelf_id)


func _inspect_inner_door() -> void:
	_show_dialogue([{"speaker": "주인공", "text": "손잡이보다 안쪽 걸쇠가 먼저 버틴다. 문틀에는 열쇠구멍 대신 레이피어 날처럼 가는 세로 홈이 있다."}])


func _build_archive() -> void:
	var inventory: Array = []
	var placed: Dictionary = _progress.get("p3b_placed", {})
	for owner_id in P3B_LABELS:
		if owner_id not in placed.values():
			inventory.append({"id": "LABEL_%s" % owner_id, "label": String(P3B_LABELS[owner_id])})
	_update_inventory(inventory)
	var visuals := ["용의 뿔·레이피어", "여우 귀·스패너", "쥐 귀·이중 맥박", "백금발·판형 날개", "박쥐 귀·이중 액자"]
	for index in range(5):
		var owner: String = String(P3B_OWNERS[index])
		var assigned := _owner_at_portrait(index)
		var suffix := "\n[%s]" % P3B_LABELS[assigned] if not assigned.is_empty() else ""
		_add_inventory_drop_hotspot("PORTRAIT_%d" % index, "%s%s" % [visuals[index], suffix], Rect2(205 + index * 280, 260 + (index % 2) * 35, 235, 310), _on_portrait_pressed.bind(index, owner), _on_portrait_item_dropped)
	_add_back_to_hall()
	if not _intro_seen("P3B"):
		_mark_intro("P3B")
		_add_unique("introduced", "MARA2")
		_show_dialogue([
			{"speaker": "마라 2", "portrait": "MARA2", "text": "늦었어! 엄청 늦었어! 다섯 장밖에 안 되는데 설마 못 맞히는 건 아니지?!"},
			{"speaker": "마라 2", "portrait": "MARA2", "text": "색 말고 귀, 소품, 프레임 문양, 기능 라벨을 같이 봐. 틀려도 괜찮아. 내가 아주 오래 놀릴 수 있으니까!"},
		])


func _on_portrait_pressed(index: int, expected_owner: String) -> void:
	if _interaction_blocked() or bool(_progress.get("P3B_complete", false)):
		return
	if not _selected_item.begins_with("LABEL_"):
		_set_status("오른쪽 인벤토리의 이름표를 초상화로 드래그하십시오.")
		return
	var selected_owner := _selected_item.trim_prefix("LABEL_")
	if selected_owner != expected_owner:
		_show_dialogue([{"speaker": "마라 2", "portrait": "MARA2", "text": "색 하나만 믿으면 틀려! 외형과 기능 라벨을 같이 봐. 기본이잖아!"}])
		return
	var placed: Dictionary = _progress.get("p3b_placed", {})
	placed[str(index)] = selected_owner
	_progress["p3b_placed"] = placed
	_selected_item = ""
	if placed.size() >= 5:
		_progress["P3B_complete"] = true
		_add_notebook("다섯 사용인의 데이터 서명: LOCK, MAINT, BIO, CLIMATE, ARCHIVE. 색이 없어도 문양과 소리로 구별할 수 있다.")
		_save_progress()
		_rebuild_current_room_content()
		_show_dialogue([
			{"speaker": "SYSTEM", "text": "수직선, 대각 닦임, 이중 맥박, 꽃잎 후광, 이중 액자가 차례로 반응한다."},
			{"speaker": "마라 2", "portrait": "MARA2", "text": "정답! 이제 여기 있는 이름은 전부 알겠네. 잊어버리면 다시 물어봐. 내가 기억하고 있을 테니까!"},
			{"speaker": "마라 2", "portrait": "MARA2", "text": "마라 2. 기록실. 보라 이중 프레임. ...맞지? 내가 쓴 이름이니까 당연히 맞지!"},
		], func() -> void: _enter_room("M1_CENTRAL_HALL"))
		return
	_save_progress()
	_rebuild_current_room_content()


func _on_portrait_item_dropped(item_id: String, target_id: String) -> void:
	var index := int(target_id.trim_prefix("PORTRAIT_"))
	if index < 0 or index >= P3B_OWNERS.size():
		return
	_selected_item = item_id
	_on_portrait_pressed(index, String(P3B_OWNERS[index]))


func _owner_at_portrait(index: int) -> String:
	var placed: Dictionary = _progress.get("p3b_placed", {})
	return String(placed.get(str(index), ""))


func _build_kitchen() -> void:
	_update_inventory([
		{"id": "CUP", "label": "빈 찻잔"},
		{"id": "HOT_WATER", "label": "뜨거운 물"},
		{"id": "TEA_LEAVES", "label": "찻잎"},
		{"id": "SPOON", "label": "계량 숟가락"},
		{"id": "TIMER", "label": "모래시계"},
		{"id": "TEAPOT", "label": "찻주전자"},
	])
	var step := int(_progress.get("tea_step", 0))
	for index in range(TEA_STEPS.size()):
		var done := index < step
		var label := "%d. %s\n%s%s" % [index + 1, TEA_STEPS[index], TEA_STEP_ITEM_LABELS[index], " · 완료" if done else ""]
		_add_inventory_drop_hotspot("TEA_%d" % index, label, Rect2(320 + (index % 3) * 390, 300 + (index / 3) * 170, 330, 120), _on_tea_target_pressed.bind(index), _on_tea_item_dropped)
	if not _intro_seen("P4"):
		_mark_intro("P4")
		_add_unique("introduced", "LUCA")
		_show_dialogue([
			{"speaker": "루카", "portrait": "LUCA", "text": "아, 아가씨... 오셨네요... 차는 제가 준비하려고 했는데, 오늘 일과에 들어 있다고 해서요... 같이 해도 괜찮을까요?"},
			{"speaker": "루카", "portrait": "LUCA", "text": "잔을 먼저 데우고... 찻잎은 한 스푼만. 물을 부은 뒤에는 모래시계 한 칸을 기다려 주세요..."},
		])


func _on_tea_step(index: int) -> void:
	if _interaction_blocked() or bool(_progress.get("P4_complete", false)):
		return
	var step := int(_progress.get("tea_step", 0))
	if index != step:
		_set_status("순서가 맞지 않는다. 지금 필요한 단계는 '%s'이다." % TEA_STEPS[step])
		return
	_progress["tea_step"] = step + 1
	_set_status("%s: 완료" % TEA_STEPS[index])
	if step + 1 >= TEA_STEPS.size():
		_complete_p4()
		return
	_save_progress()
	_rebuild_current_room_content()


func _on_tea_target_pressed(index: int) -> void:
	if _selected_item.is_empty():
		_set_status("필요한 도구를 인벤토리에서 단계 위로 드래그하십시오.")
		return
	_on_tea_item_dropped(_selected_item, "TEA_%d" % index)


func _on_tea_item_dropped(item_id: String, target_id: String) -> void:
	var index := int(target_id.trim_prefix("TEA_"))
	if index < 0 or index >= TEA_STEPS.size():
		return
	if item_id != String(TEA_STEP_ITEMS[index]):
		_set_status("'%s' 단계에는 %s이(가) 필요하다." % [TEA_STEPS[index], TEA_STEP_ITEM_LABELS[index]])
		return
	_selected_item = item_id
	_on_tea_step(index)


func _complete_p4() -> void:
	_progress["P4_complete"] = true
	_progress["iris_greeting_seen"] = true
	_progress["time_block"] = "evening_free"
	_add_unique("introduced", "IRIS")
	_add_notebook("차를 따르자 손이 먼저 찻잔 손잡이를 왼쪽으로 돌렸다. 아버지가 늘 그렇게 마셨던 것 같다.")
	_save_progress()
	_show_dialogue([
		{"speaker": "주인공", "text": "왜 이쪽이어야 하지?"},
		{"speaker": "루카", "portrait": "LUCA", "text": "그렇게 두시면... 늘 맞았어요."},
		{"speaker": "SYSTEM", "text": "주전자 바닥에서 두 번의 낮은 맥박이 울리고, 루카의 귀 안쪽이 한 박자 늦게 반짝인다."},
		{"speaker": "이리스", "portrait": "IRIS", "text": "우후후, 아가씨도 계셨네요. 오늘도 참 평온한 얼굴이라 다행이에요."},
		{"speaker": "이리스", "portrait": "IRIS", "text": "시간이 남으면 온실 앞에 들러 보세요. 오늘은 안쪽에만 비가 와서, 제법 예쁘답니다."},
	], func() -> void: _enter_room("M1_CENTRAL_HALL"))


func _build_greenhouse() -> void:
	var observations: Array = _progress.get("p5_observations", [])
	_add_hotspot("CORRIDOR_WINDOW", _observed_label("복도 창\n맑은 하늘", "corridor", observations), Rect2(230, 245, 300, 350), _observe_weather.bind("corridor", "복도 밖은 맑고 난간은 완전히 말라 있다."))
	_add_hotspot("GREENHOUSE_GLASS", _observed_label("온실 유리\n안쪽의 비", "glass", observations), Rect2(670, 205, 420, 430), _observe_weather.bind("glass", "유리 안쪽에는 빗줄기와 젖은 잎이 보인다. 빗소리는 천장 배관 쪽에서 난다."))
	_add_hotspot("THRESHOLD", _observed_label("문턱·계절판\n봄·맑음", "threshold", observations), Rect2(1140, 570, 350, 150), _observe_weather.bind("threshold", "문턱의 흙은 마르고 계절판은 '봄·맑음'에 고정되어 있다."))
	if observations.size() >= 3 and not bool(_progress.get("P5_complete", false)):
		_add_hotspot("RECORD", "수첩에 모순을 기록한다", Rect2(700, 760, 500, 100), _complete_p5)
	_add_back_to_hall()
	if not _intro_seen("P5"):
		_mark_intro("P5")
		_show_dialogue([
			{"speaker": "이리스", "portrait": "IRIS", "text": "우후후, 정말 오셨네요. 비는 안쪽에서만 오는 날도 있어요."},
			{"speaker": "이리스", "portrait": "IRIS", "text": "밖이 언제나 바깥인 건 아니니까요."},
		])


func _observe_weather(observation_id: String, text: String) -> void:
	if _interaction_blocked():
		return
	_add_unique("p5_observations", observation_id)
	_show_dialogue([{"speaker": "주인공", "text": text}])
	_save_progress()
	_build_greenhouse()


func _complete_p5() -> void:
	_progress["P5_complete"] = true
	_add_notebook("복도와 온실의 날씨가 동시에 다르다. 소리는 나지만 문턱은 젖지 않는다.")
	_save_progress()
	_build_greenhouse()
	_show_dialogue([
		{"speaker": "주인공", "text": "이 비는 진짜인가요?"},
		{"speaker": "이리스", "portrait": "IRIS", "text": "아가씨가 차갑다고 느끼면 진짜고, 아무것도 느끼지 못하면... 다른 이름이 필요하겠죠."},
	], func() -> void: _enter_room("M1_CENTRAL_HALL"))


func _on_sleep_bed() -> void:
	if _interaction_blocked():
		return
	_show_modal(
		"오늘을 끝냅니다",
		"침대가 몸을 감싸기 전에 시야가 먼저 어두워질 것 같은 기분이 듭니다.",
		[
			{"label": "잠든다", "action": _begin_first_sleep},
			{"label": "조금 더 조사한다", "action": _close_modal},
		]
	)


func _begin_first_sleep() -> void:
	_close_modal()
	_progress["P6_complete"] = true
	_add_notebook("오늘을 끝내고 잠든다.")
	if _test_mode:
		_progress["prologue_complete"] = true
		return
	var saved := _save_progress("SAVE_P6_COMPLETE", true)
	if not saved:
		_set_status("진행을 저장하지 못해 수면 절차를 시작할 수 없습니다.")
		return
	_show_dialogue([
		{"speaker": "SYSTEM", "text": "침대가 몸을 감싸기 전에 시야가 먼저 어두워진다."},
		{"speaker": "SYSTEM", "text": "낮은 시계음. 두 번의 맥박. 빠른 세 음의 마지막이 잘린다."},
	], _perform_normal_reset)


func _perform_normal_reset() -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.0, 0.0, 0.0, 1.0), 1.2)
	await tween.finished
	var result: Dictionary = get_parent().request_sleep_transition(_slot_id)
	if not bool(result.get("ok", false)):
		_fade.visible = false
		_set_status("리셋 절차 오류: %s" % ", ".join(result.get("error_ids", [])))
		return
	_progress = _default_progress()
	_progress["current_room"] = "M2_BEDROOM"
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_show_after_reset()
	var reveal := create_tween()
	reveal.tween_property(_fade, "color", Color(0.0, 0.0, 0.0, 0.0), 1.4)
	await reveal.finished
	_fade.visible = false


func _show_after_reset() -> void:
	_current_room = "M2_BEDROOM"
	_set_room_background("M2_BEDROOM_RESET")
	_location_label.text = "주인공의 침실 · 두 번째 아침"
	_clear_hotspots()
	_update_inventory([])
	_room_art.set_room("M2_BEDROOM", _progress)
	_objective_label.text = "프롤로그 완료 · 같은 침실의 같은 아침"
	_show_dialogue([
		{"speaker": "SYSTEM", "text": "새가 우는 소리에 눈을 뜬다."},
		{"speaker": "주인공", "text": "커튼 사이의 빛도, 침대보의 주름도, 어제 아침과 같은 자리에 있다."},
		{"speaker": "SYSTEM", "text": "하지만 수첩 안의 문장들은 사라지지 않았다."},
	], func() -> void:
		_show_modal(
			"프롤로그 완료",
			"첫 번째 수면 뒤 세계의 물리 상태가 되돌아왔습니다. 수첩과 확인한 정보는 다음 루프에도 남습니다.",
			[
				{"label": "같은 아침을 바라본다", "action": _close_modal},
				{"label": "타이틀로 돌아간다", "action": _return_to_title},
			]
		)
	)


func _set_room_background(room_id: String) -> void:
	var resolved_room := room_id
	if room_id == "M2_BEDROOM" and bool(_progress.get("P4_complete", false)):
		resolved_room = "M2_BEDROOM_NIGHT"
	if not ROOM_ATLAS_REGIONS.has(resolved_room):
		_background.texture = MANSION_BACKGROUND
		return
	var spec: Dictionary = ROOM_ATLAS_REGIONS[resolved_room]
	var texture := AtlasTexture.new()
	texture.atlas = ROOMS_PRIMARY_ATLAS if String(spec["atlas"]) == "primary" else ROOMS_SECONDARY_ATLAS
	texture.region = spec["region"]
	_background.texture = texture


func _evening_ambient(text: String) -> void:
	_show_dialogue([{"speaker": "주인공", "text": text}])


func _add_back_to_hall() -> void:
	_add_hotspot("BACK", "중앙홀로", Rect2(720, 875, 400, 90), _enter_room.bind("M1_CENTRAL_HALL"))


func _add_hotspot(id: String, label: String, rect: Rect2, action: Callable) -> void:
	var button := _make_button(label, rect, action)
	button.name = id
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_stylebox_override("normal", _style(Color(0.04, 0.02, 0.065, 0.72), Color(0.69, 0.39, 0.34, 0.84), 3, 7))
	button.add_theme_stylebox_override("hover", _style(Color(0.15, 0.045, 0.14, 0.90), Color(0.95, 0.59, 0.31, 1.0), 5, 7))
	button.add_theme_stylebox_override("focus", _style(Color(0.10, 0.03, 0.12, 0.88), Color(0.59, 0.78, 0.98, 1.0), 5, 7))
	_hotspot_layer.add_child(button)


func _add_inventory_drop_hotspot(id: String, label: String, rect: Rect2, click_action: Callable, drop_action: Callable) -> void:
	var target = INVENTORY_DROP_TARGET_SCRIPT.new()
	target.name = id
	target.configure(id)
	target.text = label
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target.add_theme_font_size_override("font_size", 20)
	target.add_theme_stylebox_override("normal", _style(Color(0.04, 0.02, 0.065, 0.72), Color(0.69, 0.39, 0.34, 0.84), 3, 7))
	target.add_theme_stylebox_override("hover", _style(Color(0.15, 0.045, 0.14, 0.90), Color(0.95, 0.59, 0.31, 1.0), 5, 7))
	target.add_theme_stylebox_override("focus", _style(Color(0.10, 0.03, 0.12, 0.88), Color(0.59, 0.78, 0.98, 1.0), 5, 7))
	_place(target, rect)
	target.pressed.connect(click_action)
	target.inventory_item_dropped.connect(drop_action)
	_hotspot_layer.add_child(target)


func _clear_hotspots() -> void:
	for child in _hotspot_layer.get_children():
		_hotspot_layer.remove_child(child)
		child.queue_free()


func _make_button(label: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _style(Color(0.055, 0.025, 0.075, 0.96), Color(0.60, 0.30, 0.24, 0.94), 3, 7))
	button.add_theme_stylebox_override("hover", _style(Color(0.15, 0.045, 0.14, 0.98), Color(0.95, 0.57, 0.30, 1.0), 4, 7))
	button.add_theme_stylebox_override("focus", _style(Color(0.10, 0.035, 0.12, 0.98), Color(0.55, 0.77, 0.98, 1.0), 4, 7))
	_place(button, rect)
	button.pressed.connect(action)
	return button


func _update_inventory(items: Array) -> void:
	_progress["inventory"] = items.duplicate(true)
	for index in range(_inventory_slots.size()):
		var slot := _inventory_slots[index]
		if index < items.size():
			var item: Dictionary = items[index]
			slot.set_inventory_item(String(item.get("id", "")), String(item.get("label", item.get("id", ""))))
		else:
			slot.set_inventory_item("", "")
	_refresh_inventory_selection()


func _on_inventory_slot_pressed(index: int) -> void:
	if _interaction_blocked() or index >= _inventory_slots.size():
		return
	var item_id := String(_inventory_slots[index].get_meta("item_id", ""))
	if item_id.is_empty():
		return
	_selected_item = item_id
	_set_status("선택: %s · 대상 위로 드래그하거나 대상을 누르십시오." % _inventory_slots[index].text)
	_refresh_inventory_selection()


func _on_inventory_drag_started(item_id: String) -> void:
	_selected_item = item_id
	var display_name := item_id
	for slot in _inventory_slots:
		if String(slot.get_meta("item_id", "")) == item_id:
			display_name = slot.text.replace("\n", " ")
			break
	_set_status("드래그 중: %s" % display_name)
	_refresh_inventory_selection()


func _refresh_inventory_selection() -> void:
	for slot in _inventory_slots:
		var item_id := String(slot.get_meta("item_id", ""))
		var selected := item_id == _selected_item and not _selected_item.is_empty()
		var drying_hint := false
		if _inspection_active and _inspected_window >= 0 and item_id == "SOFT_CLOTH":
			var states: Array = _progress.get("window_states", [])
			if _inspected_window < states.size():
				drying_hint = bool((states[_inspected_window] as Dictionary).get("bottom_wet", false))
		if not item_id.is_empty():
			slot.tooltip_text = "마른 면으로 아래 물기를 제거" if drying_hint else "대상으로 드래그하여 사용"
		slot.add_theme_stylebox_override("normal", _style(
			Color(0.18, 0.055, 0.13, 0.98) if selected else (Color(0.11, 0.13, 0.18, 0.98) if drying_hint else Color(0.08, 0.035, 0.075, 0.96)),
			Color(0.97, 0.68, 0.31, 1.0) if selected else (Color(0.55, 0.84, 1.0, 1.0) if drying_hint else Color(0.63, 0.26, 0.18, 0.92)),
			5 if selected or drying_hint else 4,
			4
		))


func _show_dialogue(lines: Array, after: Callable = Callable()) -> void:
	_hide_dialogue_choices()
	_dialogue_lines = lines.duplicate(true)
	_dialogue_index = 0
	_dialogue_after = after
	_dialogue_active = not _dialogue_lines.is_empty()
	_dialogue_layer.visible = _dialogue_active
	if _dialogue_active:
		_present_dialogue_line()


func _present_dialogue_line() -> void:
	var line: Dictionary = _dialogue_lines[_dialogue_index]
	_speaker_label.text = String(line.get("speaker", "SYSTEM"))
	_dialogue_label.text = String(line.get("text", ""))
	var portrait_id := String(line.get("portrait", ""))
	_set_dialogue_portrait(portrait_id)
	_dialogue_next.visible = true
	_dialogue_next.text = "마침" if _dialogue_index >= _dialogue_lines.size() - 1 else "계속"
	_dialogue_next.call_deferred("grab_focus")


func _set_dialogue_portrait(portrait_id: String) -> void:
	_portrait.visible = PORTRAIT_REGIONS.has(portrait_id)
	if not _portrait.visible:
		return
	var texture := AtlasTexture.new()
	texture.atlas = SERVANT_ATLAS
	texture.region = PORTRAIT_REGIONS[portrait_id]
	_portrait.texture = texture


func _hide_dialogue_choices() -> void:
	_dialogue_choice_active = false
	if _dialogue_choice_blocker != null:
		_dialogue_choice_blocker.visible = false
	if _dialogue_choice_panel != null:
		_dialogue_choice_panel.visible = false
	if _dialogue_next != null:
		_dialogue_next.visible = true


func _refresh_p3_journal_choice_labels() -> void:
	var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
	for index in range(_dialogue_choice_buttons.size()):
		var button := _dialogue_choice_buttons[index]
		var choice_id := String(button.get_meta("choice_id", ""))
		var prefix := "▶ " if index == _dialogue_choice_focus_index else "   "
		var suffix := "  [확인함]" if choice_id in asked_questions else ""
		button.text = "%s%s%s" % [prefix, P3_JOURNAL_CHOICES[choice_id]["label"], suffix]


func _first_unasked_p3_choice_index() -> int:
	var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
	for index in range(2):
		var choice_id := String(_dialogue_choice_buttons[index].get_meta("choice_id", ""))
		if choice_id not in asked_questions:
			return index
	return 2


func _focus_dialogue_choice(index: int) -> void:
	if _dialogue_choice_buttons.is_empty():
		return
	_dialogue_choice_focus_index = clampi(index, 0, _dialogue_choice_buttons.size() - 1)
	_refresh_p3_journal_choice_labels()
	_dialogue_choice_buttons[_dialogue_choice_focus_index].call_deferred("grab_focus")


func _on_dialogue_choice_focused(index: int) -> void:
	_dialogue_choice_focus_index = clampi(index, 0, _dialogue_choice_buttons.size() - 1)
	_refresh_p3_journal_choice_labels()


func _focus_p3_silent_choice() -> void:
	_focus_dialogue_choice(2)
	_set_status("선택 구간을 끝내려면 '말없이 내려놓는다'를 선택하십시오.")


func _advance_dialogue() -> void:
	if not _dialogue_active:
		return
	_dialogue_index += 1
	if _dialogue_index < _dialogue_lines.size():
		_present_dialogue_line()
		return
	_dialogue_active = false
	_dialogue_layer.visible = false
	var after := _dialogue_after
	_dialogue_after = Callable()
	if after.is_valid():
		after.call()


func _dismiss_dialogue_for_test() -> void:
	_hide_dialogue_choices()
	_dialogue_active = false
	_dialogue_layer.visible = false
	_dialogue_lines.clear()
	_dialogue_after = Callable()


func _open_menu() -> void:
	if _dialogue_active or _dialogue_choice_active:
		return
	_show_modal("메뉴", "진행은 일과를 완료할 때와 방을 이동할 때 자동 저장됩니다.", [
		{"label": "계속", "action": _close_modal},
		{"label": "타이틀로 돌아간다", "action": _return_to_title},
	])


func _open_notebook() -> void:
	if _dialogue_active or _dialogue_choice_active:
		return
	var entries: Array = _progress.get("notebook_entries", [])
	var body := "아직 기록이 없다." if entries.is_empty() else "\n\n".join(entries.map(func(value: Variant) -> String: return "- %s" % String(value)))
	_show_modal("주인공의 수첩", body, [{"label": "닫기", "action": _close_modal}])


func _show_modal(title: String, body: String, actions: Array) -> void:
	for child in _modal_body.get_children():
		child.queue_free()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.72, 0.44))
	_modal_body.add_child(title_label)
	var rule := HSeparator.new()
	_modal_body.add_child(rule)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 23)
	body_label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.90))
	_modal_body.add_child(body_label)
	for action_value in actions:
		var action: Dictionary = action_value
		var button := Button.new()
		button.text = String(action.get("label", "확인"))
		button.custom_minimum_size = Vector2(0, 58)
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.035, 0.11, 0.98), Color(0.66, 0.35, 0.34, 0.95), 3, 7))
		button.pressed.connect(action.get("action", _close_modal))
		_modal_body.add_child(button)
	_modal_active = true
	_modal_layer.visible = true
	if _modal_body.get_child_count() > 3:
		(_modal_body.get_child(3) as Control).call_deferred("grab_focus")


func _close_modal() -> void:
	_modal_active = false
	_modal_layer.visible = false


func _return_to_title() -> void:
	_close_modal()
	_save_progress()
	return_to_title_requested.emit()


func _save_progress(save_point_id: String = "SAVE_NEW_GAME", prologue_complete: bool = false) -> bool:
	if _test_mode:
		return true
	var event_states: Dictionary = GameState.get_value(&"loop_state.event_local_states", {}).duplicate(true)
	event_states["PROLOGUE"] = _progress.duplicate(true)
	var knowledge: Dictionary = GameState.get_value(&"meta_progress.knowledge_entries", {}).duplicate(true)
	for servant_id in Array(_progress.get("introduced", [])):
		knowledge["INTRO_%s" % servant_id] = true
	if bool(_progress.get("p3_journal_seen", false)):
		knowledge["NOTE_JOURNAL"] = true
	if bool(_progress.get("P3B_complete", false)):
		knowledge["CLR_00_SIGNATURES"] = true
	if bool(_progress.get("bird_observed", false)):
		knowledge["OBS_REPEATING_BIRD"] = true
	if bool(_progress.get("P5_complete", false)):
		knowledge["OBS_WEATHER_CONTRADICTION"] = true
	if prologue_complete or bool(_progress.get("P6_complete", false)):
		knowledge["PROLOGUE_COMPLETE"] = true
	var writer := StateWriter.new(GameState)
	var transaction_id := StringName("PROLOGUE_R%06d" % (GameState.revision + 1))
	var result := writer.commit_atomic([
		{"state_path": "loop_state.event_local_states", "operation": "set", "value": event_states},
		{"state_path": "loop_state.location_id", "operation": "set", "value": _current_room},
		{"state_path": "loop_state.time_block", "operation": "set", "value": String(_progress.get("time_block", "morning"))},
		{"state_path": "loop_state.inventory", "operation": "set", "value": _inventory_item_ids()},
		{"state_path": "meta_progress.knowledge_entries", "operation": "set", "value": knowledge},
	], GameState.revision, transaction_id)
	if not bool(result.get("ok", false)):
		_set_status("상태 기록 실패: %s" % ", ".join(result.get("error_ids", [])))
		return false
	var save_result := SaveManager.save_snapshot(_slot_id, save_point_id, GameState.get_snapshot(), GameState.revision, String(transaction_id))
	if not bool(save_result.get("ok", false)):
		GameState.rollback_failed_persistence(result["previous_snapshot"], int(result["revision"]), transaction_id, StringName(save_result.get("error_id", &"ERR_SAVE_UNKNOWN")))
		_set_status("자동 저장 실패: %s" % ", ".join(save_result.get("error_ids", [])))
		return false
	return true


func _inventory_item_ids() -> Array:
	var ids: Array = []
	for slot in _inventory_slots:
		var item_id := String(slot.get_meta("item_id", ""))
		if not item_id.is_empty():
			ids.append(item_id)
	return ids


func _is_prologue_complete() -> bool:
	if _test_mode:
		return false
	var knowledge: Dictionary = GameState.get_value(&"meta_progress.knowledge_entries", {})
	return bool(knowledge.get("PROLOGUE_COMPLETE", false)) and int(GameState.get_value(&"loop_state.day_index", 0)) >= 1


func _morning_tasks_complete() -> bool:
	return bool(_progress.get("P2_complete", false)) and bool(_progress.get("P3_complete", false)) and bool(_progress.get("P3B_complete", false))


func _update_objective() -> void:
	if not bool(_progress.get("P1_complete", false)):
		_objective_label.text = "침실을 살펴보고 아침 일과를 시작한다"
	elif not _morning_tasks_complete():
		var count := int(bool(_progress.get("P2_complete", false))) + int(bool(_progress.get("P3_complete", false))) + int(bool(_progress.get("P3B_complete", false)))
		_objective_label.text = "아침 일과 %d / 3 · 순서는 자유" % count
	elif not bool(_progress.get("P4_complete", false)):
		_objective_label.text = "주방에서 차를 준비한다"
	else:
		_objective_label.text = "저녁 자유 조사 · 온실은 선택 · 침실에서 하루 종료"


func _task_label(label: String, flag: String) -> String:
	return "%s\n%s" % [label, "완료" if bool(_progress.get(flag, false)) else "미완료"]


func _window_stage_name(stage: int) -> String:
	return ["위쪽 먼지", "가운데 얼룩", "아래쪽 물기", "완료"][clampi(stage, 0, 3)]


func _make_default_window_states() -> Array:
	var states: Array = []
	for _index in range(3):
		states.append({
			"top_dust": true,
			"middle_stain": true,
			"bottom_wet": false,
			"dust_spread": false,
		})
	return states


func _window_states_from_stages(stages: Array) -> Array:
	var states: Array = []
	for index in range(3):
		var stage := int(stages[index]) if index < stages.size() else 0
		states.append({
			"top_dust": stage <= 0,
			"middle_stain": stage <= 1,
			"bottom_wet": stage == 2,
			"dust_spread": false,
		})
	return states


func _normalize_window_states() -> void:
	var states_value: Variant = _progress.get("window_states", [])
	if not (states_value is Array) or states_value.size() != 3:
		_progress["window_states"] = _window_states_from_stages(Array(_progress.get("windows", [0, 0, 0])))
		return
	var normalized: Array = []
	for state_value in states_value:
		var state: Dictionary = state_value if state_value is Dictionary else {}
		normalized.append({
			"top_dust": bool(state.get("top_dust", true)),
			"middle_stain": bool(state.get("middle_stain", true)),
			"bottom_wet": bool(state.get("bottom_wet", false)),
			"dust_spread": bool(state.get("dust_spread", false)),
		})
	_progress["window_states"] = normalized


func _sync_window_stages() -> void:
	_normalize_window_states()
	var stages: Array = []
	for state_value in Array(_progress.get("window_states", [])):
		stages.append(_stage_from_window_state(state_value))
	_progress["windows"] = stages


func _stage_from_window_state(state: Dictionary) -> int:
	if bool(state.get("top_dust", true)) or bool(state.get("dust_spread", false)):
		return 0
	if bool(state.get("middle_stain", true)):
		return 1
	if bool(state.get("bottom_wet", false)):
		return 2
	return 3


func _is_window_clean(state: Dictionary) -> bool:
	return _stage_from_window_state(state) == 3


func _all_windows_clean() -> bool:
	var states: Array = _progress.get("window_states", [])
	return states.size() == 3 and states.all(func(state: Variant) -> bool: return state is Dictionary and _is_window_clean(state))


func _observed_label(label: String, observation_id: String, observations: Array) -> String:
	return "%s%s" % [label, "\n[확인함]" if observation_id in observations else ""]


func _set_status(message: String) -> void:
	_status_label.text = message


func _add_notebook(entry: String) -> void:
	var entries: Array = _progress.get("notebook_entries", [])
	if entry not in entries:
		entries.append(entry)
	_progress["notebook_entries"] = entries


func _add_unique(key: String, value: String) -> void:
	var values: Array = _progress.get(key, [])
	if value not in values:
		values.append(value)
	_progress[key] = values


func _intro_seen(intro_id: String) -> bool:
	return intro_id in Array(_progress.get("intros_seen", []))


func _mark_intro(intro_id: String) -> void:
	_add_unique("intros_seen", intro_id)


func _interaction_blocked() -> bool:
	return _dialogue_active or _dialogue_choice_active or _modal_active


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func _style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _choice_style(background: Color, border: Color, left_border_width: int) -> StyleBoxFlat:
	var box := _style(background, border, 1, 2)
	box.border_width_left = left_border_width
	box.content_margin_left = 22.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


func run_smoke_scenario() -> PackedStringArray:
	var errors := PackedStringArray()
	_progress = _default_progress()
	_progress["P1_complete"] = true
	_enter_room("M1_PARLOR")
	_dismiss_dialogue_for_test()
	for item_id in ["SOFT_CLOTH", "COARSE_BRUSH", "WATER", "SPANNER"]:
		if item_id not in _inventory_item_ids():
			errors.append("P2 inventory item missing: %s" % item_id)
	_on_window_pressed(0)
	if not _inspection_active or not _inspection_layer.visible or _inspected_window != 0:
		errors.append("P2 window click did not open inspection view")
	if _window_drop_targets.size() != 3:
		errors.append("P2 inspection does not expose three pollution zones")
	var initial_state: Dictionary = (Array(_progress["window_states"])[0] as Dictionary).duplicate(true)
	_drag_inventory_item_to_target_for_smoke("SPANNER", _window_drop_targets["TOP"], errors)
	_dismiss_dialogue_for_test()
	if Array(_progress["window_states"])[0] != initial_state:
		errors.append("P2 spanner changed window state")
	_drag_inventory_item_to_target_for_smoke("COARSE_BRUSH", _window_drop_targets["TOP"], errors)
	_dismiss_dialogue_for_test()
	if not bool((Array(_progress["window_states"])[0] as Dictionary).get("dust_spread", false)):
		errors.append("P2 coarse brush did not spread dust")
	_drag_inventory_item_to_target_for_smoke("SOFT_CLOTH", _window_drop_targets["BOTTOM"], errors)
	if _stage_from_window_state(Array(_progress["window_states"])[0]) != 0:
		errors.append("P2 bottom-first mistake advanced the window")
	_drag_inventory_item_to_target_for_smoke("SOFT_CLOTH", _window_drop_targets["TOP"], errors)
	_drag_inventory_item_to_target_for_smoke("WATER", _window_drop_targets["MIDDLE"], errors)
	if not bool((Array(_progress["window_states"])[0] as Dictionary).get("bottom_wet", false)):
		errors.append("P2 water did not leave removable bottom moisture")
	if "SOFT_CLOTH" not in _inventory_item_ids():
		errors.append("P2 tool was consumed after use")
	_drag_inventory_item_to_target_for_smoke("SOFT_CLOTH", _window_drop_targets["BOTTOM"], errors)
	for window_index in range(1, 3):
		_on_window_pressed(window_index)
		_drag_inventory_item_to_target_for_smoke("SOFT_CLOTH", _window_drop_targets["TOP"], errors)
		_dismiss_dialogue_for_test()
		_drag_inventory_item_to_target_for_smoke("SOFT_CLOTH", _window_drop_targets["MIDDLE"], errors)
	_dismiss_dialogue_for_test()
	if not bool(_progress.get("P2_complete", false)):
		errors.append("P2 did not complete")

	_run_p3_silent_close_smoke(errors)
	_enter_room("M1_LIBRARY_OUTER")
	_dismiss_dialogue_for_test()
	for book_id in P3_BOOKS:
		if book_id not in _inventory_item_ids():
			errors.append("P3 inventory book missing: %s" % book_id)
	var p3_book_order := ["BOOK_FLORA", "BOOK_LEDGER", "BOOK_MECHANICAL"]
	for book_id in p3_book_order:
		var shelf_id := String(P3_BOOKS[book_id]["shelf"])
		_drag_inventory_item_to_target_for_smoke(book_id, _hotspot_layer.get_node(shelf_id), errors)
		if book_id != "BOOK_MECHANICAL":
			_dismiss_dialogue_for_test()
			continue
		if not _dialogue_active or _dialogue_lines.size() != 2:
			errors.append("P3 journal discovery dialogue missing")
		while _dialogue_active:
			_advance_dialogue()
		if not _dialogue_choice_active or not _dialogue_choice_panel.visible or _dialogue_next.visible:
			errors.append("P3 dialogue choice list missing after Edgar dialogue")
		if _modal_active:
			errors.append("P3 journal choices still use the centered modal")
		var choice_labels: Array[String] = []
		var author_button: Button
		var locked_button: Button
		var silent_button: Button
		for button in _dialogue_choice_buttons:
			var choice_id := String(button.get_meta("choice_id", ""))
			choice_labels.append(String(P3_JOURNAL_CHOICES[choice_id]["label"]))
			match choice_id:
				"author":
					author_button = button
				"locked":
					locked_button = button
				"silent":
					silent_button = button
		for choice_id in ["author", "locked", "silent"]:
			if String(P3_JOURNAL_CHOICES[choice_id]["label"]) not in choice_labels:
				errors.append("P3 journal choice missing: %s" % choice_id)
		if author_button == null or locked_button == null or silent_button == null:
			errors.append("P3 journal choice button unavailable")
			return errors
		author_button.pressed.emit()
		if not _dialogue_active or _dialogue_label.text != "주인님의 기록입니다.":
			errors.append("P3 journal selected answer was not presented")
		_advance_dialogue()
		if not _dialogue_choice_active or bool(_progress.get("P3_complete", false)):
			errors.append("P3 author answer did not return to choices")
		locked_button.pressed.emit()
		if not _dialogue_active or _dialogue_label.text != "손상된 기록은 잘못 읽히기 쉽습니다.":
			errors.append("P3 journal locked answer was not presented")
		_advance_dialogue()
		if not _dialogue_choice_active or bool(_progress.get("P3_complete", false)):
			errors.append("P3 locked answer did not return to choices")
		var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
		if "author" not in asked_questions or "locked" not in asked_questions:
			errors.append("P3 asked question history missing")
		silent_button.pressed.emit()
		if _dialogue_choice_active:
			errors.append("P3 silent choice did not close choice list")
		_dismiss_dialogue_for_test()
	if not bool(_progress.get("P3_complete", false)) or not bool(_progress.get("p3_journal_seen", false)):
		errors.append("P3 did not complete with journal")
	if String(_progress.get("p3_journal_choice", "")) != "silent":
		errors.append("P3 journal choice section ended without silent choice")

	_enter_room("M1_NORTH_ARCHIVE_HALL")
	_dismiss_dialogue_for_test()
	for index in range(P3B_OWNERS.size()):
		_drag_inventory_item_to_target_for_smoke("LABEL_%s" % P3B_OWNERS[index], _hotspot_layer.get_node("PORTRAIT_%d" % index), errors)
		_dismiss_dialogue_for_test()
	if not bool(_progress.get("P3B_complete", false)):
		errors.append("P3B did not complete")

	_enter_room("M1_KITCHEN")
	_dismiss_dialogue_for_test()
	for index in range(TEA_STEPS.size()):
		_drag_inventory_item_to_target_for_smoke(String(TEA_STEP_ITEMS[index]), _hotspot_layer.get_node("TEA_%d" % index), errors)
		_dismiss_dialogue_for_test()
	if not bool(_progress.get("P4_complete", false)) or not bool(_progress.get("iris_greeting_seen", false)):
		errors.append("P4 or Iris greeting did not complete")

	_enter_room("M1_GREENHOUSE_VESTIBULE")
	_dismiss_dialogue_for_test()
	for pair in [["corridor", "corridor"], ["glass", "glass"], ["threshold", "threshold"]]:
		_observe_weather(pair[0], pair[1])
		_dismiss_dialogue_for_test()
	_complete_p5()
	_dismiss_dialogue_for_test()
	if not bool(_progress.get("P5_complete", false)):
		errors.append("P5 did not complete")
	if _inventory_slots.size() != 6 or _menu_button == null or _notebook_button == null:
		errors.append("persistent UI contract missing")
	return errors


func _run_p3_silent_close_smoke(errors: PackedStringArray) -> void:
	_enter_room("M1_LIBRARY_OUTER")
	_dismiss_dialogue_for_test()
	_drag_inventory_item_to_target_for_smoke("BOOK_MECHANICAL", _hotspot_layer.get_node("SHELF_CLOCK"), errors)
	while _dialogue_active:
		_advance_dialogue()
	var silent_button: Button
	for button in _dialogue_choice_buttons:
		if String(button.get_meta("choice_id", "")) == "silent":
			silent_button = button
			break
	if silent_button == null:
		errors.append("P3 silent close test could not find choice button")
	else:
		silent_button.pressed.emit()
		if _dialogue_layer.visible or _dialogue_choice_active:
			errors.append("P3 silent choice left dialogue UI visible before book sorting completed")
		if bool(_progress.get("P3_complete", false)):
			errors.append("P3 silent close test completed event with books remaining")
	_dismiss_dialogue_for_test()
	_progress["P3_complete"] = false
	_progress["p3_placed"] = {}
	_progress["p3_journal_seen"] = false
	_progress["p3_journal_choice"] = ""
	_progress["p3_journal_questions_asked"] = []
	_p3_journal_prompt_active = false
	_selected_item = ""


func _drag_inventory_item_to_target_for_smoke(item_id: String, target: Control, errors: PackedStringArray) -> bool:
	var source: Button
	for slot in _inventory_slots:
		if String(slot.get_meta("item_id", "")) == item_id:
			source = slot
			break
	if source == null:
		errors.append("inventory drag source not found: %s" % item_id)
		return false
	var data: Variant = source.get_drag_payload_for_test()
	if not (data is Dictionary) or String(data.get("item_id", "")) != item_id:
		errors.append("inventory drag payload mismatch: %s" % item_id)
		return false
	if not target._can_drop_data(Vector2.ZERO, data):
		errors.append("inventory target rejected drag payload: %s -> %s" % [item_id, target.name])
		return false
	target._drop_data(Vector2.ZERO, data)
	return true
