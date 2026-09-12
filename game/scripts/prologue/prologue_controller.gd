class_name PrologueController
extends Control

signal return_to_title_requested
signal campaign_requested(slot_id: String)

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
const P4_FATHER_CHOICES := {
	"father_tea": {
		"label": "아버지가 좋아한 차인가요?",
		"response": "네... 비슷한 향을 좋아하셨어요.\n정확히 같은지는... 이제 자신이 없지만요.",
	},
	"mansion_age": {
		"label": "이 저택은 언제부터 있었나요?",
		"response": "아가씨가 기억하는 만큼 오래됐다고... 들었어요.",
	},
	"luca_tenure": {
		"label": "루카는 여기서 오래 일했나요?",
		"response": "오래요... 아주 오래요.\n그런데 며칠이라고 세면, 늘 같은 수가 나와서...",
	},
}
const P4_FATHER_CHOICE_ORDER := ["father_tea", "mansion_age", "luca_tenure"]
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

var _dialogue_texts := DialogueRepository.new()
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
var _dialogue_scroll: ScrollContainer
var _reading_text_scale := 1.0
var _dialogue_next: Button
var _dialogue_choice_blocker: ColorRect
var _dialogue_choice_panel: PanelContainer
var _dialogue_choice_header: Label
var _dialogue_choice_buttons: Array[Button] = []
var _dialogue_choice_focus_index := 0
var _dialogue_choice_active := false
var _dialogue_choice_mode := ""
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
	if _modal_active and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var body_scroll := _modal_body.get_child(2) as ScrollContainer
		if body_scroll != null:
			var direction := -1 if event.keycode == KEY_PAGEUP else 1
			body_scroll.scroll_vertical += direction * maxi(40, int(body_scroll.size.y * 0.8))
			get_viewport().set_input_as_handled()
			return
	if _dialogue_layer.visible and not _modal_active and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var direction := -1 if event.keycode == KEY_PAGEUP else 1
		_dialogue_scroll.scroll_vertical += direction * maxi(40, int(_dialogue_scroll.size.y * 0.8))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook_toggle"):
		if _dialogue_choice_active:
			_handle_dialogue_choice_cancel()
		elif _inspection_active:
			_close_window_inspection()
		elif _modal_active:
			_close_modal()
		else:
			_open_notebook()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _dialogue_choice_active:
			_handle_dialogue_choice_cancel()
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

	var close_button := _make_button(_dialogue_ui_text("UI_P_CLOSE_ZOOM"), Rect2(1160, 24, 170, 58), _close_window_inspection)
	close_button.name = "CloseWindowInspection"
	content.add_child(close_button)


func _build_persistent_ui() -> void:
	var top_shade := ColorRect.new()
	top_shade.color = Color(0.015, 0.01, 0.03, 0.78)
	_place(top_shade, Rect2(0, 0, 1920, 86))
	add_child(top_shade)

	_menu_button = _make_button(_dialogue_ui_text("UI_P_MENU"), Rect2(22, 18, 136, 52), _open_menu)
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

	_notebook_button = _make_button(_dialogue_ui_text("UI_P_NOTEBOOK"), Rect2(24, 912, 116, 132), _open_notebook)
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
	inventory_title.text = _dialogue_ui_text("UI_INVENTORY")
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_font_size_override("font_size", 19)
	inventory_column.add_child(inventory_title)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.name = "InventoryScroll"
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.custom_minimum_size.y = 100
	inventory_scroll.follow_focus = true
	inventory_column.add_child(inventory_scroll)
	var slots_column := VBoxContainer.new()
	slots_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_column.add_theme_constant_override("separation", 12)
	inventory_scroll.add_child(slots_column)
	for index in range(6):
		var slot: Button = INVENTORY_DRAG_SLOT_SCRIPT.new()
		slot.name = "InventorySlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(170, 126)
		slot.text = _dialogue_ui_text("UI_INV_EMPTY")
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_theme_font_size_override("font_size", 17)
		slot.add_theme_stylebox_override("normal", _style(Color(0.08, 0.035, 0.075, 0.96), Color(0.63, 0.26, 0.18, 0.92), 4, 4))
		slot.add_theme_stylebox_override("hover", _style(Color(0.17, 0.055, 0.13, 0.98), Color(0.90, 0.47, 0.26, 1.0), 5, 4))
		slot.pressed.connect(_on_inventory_slot_pressed.bind(index))
		slot.drag_started.connect(_on_inventory_drag_started)
		_inventory_slots.append(slot)
		slots_column.add_child(slot)


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
	_dialogue_scroll = ScrollContainer.new()
	_dialogue_scroll.name = "DialogueScroll"
	_dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.custom_minimum_size.y = 80
	_dialogue_scroll.focus_mode = Control.FOCUS_ALL
	body.add_child(_dialogue_scroll)
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueText"
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 24)
	_dialogue_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.91))
	_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.add_child(_dialogue_label)
	_dialogue_next = Button.new()
	_dialogue_next.name = "DialogueNext"
	_dialogue_next.text = _dialogue_ui_text("UI_DIALOGUE_CONTINUE")
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
	_dialogue_choice_panel.resized.connect(func() -> void:
		_dialogue_choice_panel.position.x = maxf(24.0, 1660.0 - _dialogue_choice_panel.size.x)
	)
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
	_dialogue_choice_header = Label.new()
	_dialogue_choice_header.name = "DialogueChoiceHeader"
	_dialogue_choice_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialogue_choice_header.add_theme_font_size_override("font_size", 18)
	_dialogue_choice_header.add_theme_color_override("font_color", Color(0.78, 0.81, 0.88))
	choice_list.add_child(_dialogue_choice_header)
	for index in range(3):
		var button := Button.new()
		button.name = "DialogueChoice%d" % (index + 1)
		button.custom_minimum_size = Vector2(420, 88)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 23)
		button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.95))
		button.add_theme_stylebox_override("normal", _choice_style(Color(0.015, 0.012, 0.022, 0.88), Color(0.22, 0.24, 0.31, 0.76), 3))
		button.add_theme_stylebox_override("hover", _choice_style(Color(0.055, 0.075, 0.09, 0.94), Color(0.37, 0.79, 0.86, 0.94), 5))
		button.add_theme_stylebox_override("focus", _choice_style(Color(0.055, 0.075, 0.09, 0.98), Color(0.42, 0.86, 0.92, 1.0), 6))
		button.pressed.connect(_on_dialogue_choice_pressed.bind(index))
		button.focus_entered.connect(_on_dialogue_choice_focused.bind(index))
		button.mouse_entered.connect(_focus_dialogue_choice.bind(index))
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
		if bool(_progress.get("P4_complete", false)):
			_progress["p4_phase"] = "complete"
			_progress["p4_memory_anchor_seen"] = true
		elif int(_progress.get("tea_step", 0)) >= TEA_STEPS.size() and String(_progress.get("p4_phase", "brewing")) == "brewing":
			_progress["p4_phase"] = "memory_anchor"
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
		"p4_phase": "brewing",
		"p4_life_support_seen": false,
		"p4_life_support_recorded": false,
		"p4_memory_anchor_seen": false,
		"p4_handle_return_used": false,
		"p4_father_question": "",
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
	_apply_reading_text_scale(scale)

func _apply_reading_text_scale(scale: float) -> void:
	_reading_text_scale = clampf(scale, 1.0, 2.0)
	_dialogue_label.add_theme_font_size_override("font_size", int(round(24 * _reading_text_scale)))
	_speaker_label.add_theme_font_size_override("font_size", int(round(25 * _reading_text_scale)))
	_dialogue_next.add_theme_font_size_override("font_size", int(round(20 * _reading_text_scale)))
	for button in _dialogue_choice_buttons:
		button.add_theme_font_size_override("font_size", int(round(23 * _reading_text_scale)))
	_apply_window_text_scale()
	for slot in _inventory_slots:
		slot.add_theme_font_size_override("font_size", int(round(17 * _reading_text_scale)))


func _apply_window_text_scale() -> void:
	_window_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window_title.add_theme_font_size_override("font_size", int(round(32 * _reading_text_scale)))
	_window_hint_label.add_theme_font_size_override("font_size", int(round(20 * _reading_text_scale)))
	_window_feedback_label.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	var enlarged := _reading_text_scale > 1.0
	_place(_window_title, Rect2(48, 28, 1080, 160) if enlarged else Rect2(48, 28, 1080, 48))
	_place(_window_hint_label, Rect2(48, 190, 1250, 110) if enlarged else Rect2(48, 78, 1180, 36))
	_place(_window_art, Rect2(70, 310, 1250, 370) if enlarged else Rect2(70, 120, 1250, 590))
	_place(_window_feedback_label, Rect2(48, 690, 1250, 140) if enlarged else Rect2(120, 708, 1110, 72))
	var normal_rects := [Rect2(160, 170, 1070, 140), Rect2(160, 335, 1070, 155), Rect2(160, 515, 1070, 145)]
	var zones := ["TOP", "MIDDLE", "BOTTOM"]
	for index in range(zones.size()):
		var target = _window_drop_targets[zones[index]]
		target.add_theme_font_size_override("font_size", int(round(22 * _reading_text_scale)))
		_place(target, Rect2(160, 315 + 115 * index, 1070, 110) if enlarged else normal_rects[index])
	_refresh_window_inspection()
	for index in range(zones.size()):
		_place(_window_drop_targets[zones[index]], Rect2(160, 315 + 115 * index, 1070, 110) if enlarged else normal_rects[index])


func _show_p1_intro() -> void:
	_add_unique("introduced", "EDGAR")
	var texts := _dialogue_texts
	var locale := TranslationServer.get_locale()
	_show_dialogue([
		{"speaker": "SYSTEM", "text": texts.get_text(&"P1_WAKE_LIGHT", locale)},
		{"speaker": "SYSTEM", "text": texts.get_text(&"P1_WAKE_KNOCK", locale)},
		{"speaker": "에드가", "portrait": "EDGAR", "text": texts.get_text(&"P1_WAKE_EDGAR", locale)},
		{"speaker": "에드가", "portrait": "EDGAR", "text": texts.get_text(&"P1_WAKE_TASKS", locale)},
	], func() -> void: _set_status(texts.get_text(&"P1_WAKE_OBJECTIVE", locale)))


func _enter_room(room_id: String) -> void:
	_close_window_inspection(false)
	_current_room = room_id
	_progress["current_room"] = room_id
	_location_label.text = _dialogue_ui_text("ROOM_" + room_id) if ROOM_NAMES.has(room_id) else room_id
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
		_add_hotspot("BED", _dialogue_ui_text("P6_NIGHT_BED"), Rect2(245, 640, 480, 170), _on_sleep_bed)
		_add_hotspot("WINDOW", _dialogue_ui_text("P6_NIGHT_WINDOW"), Rect2(1280, 210, 300, 380), _inspect_bedroom.bind("window"))
		_add_hotspot("HALL", _dialogue_ui_text("P6_NIGHT_EXPLORE"), Rect2(790, 870, 360, 92), _enter_room.bind("M1_CENTRAL_HALL"))
		if not _intro_seen("P6"):
			_mark_intro("P6")
			_show_dialogue([
				{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P6_NIGHT_EDGAR_DONE")},
				{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P6_NIGHT_EDGAR_REST")},
			])
		return

	_add_hotspot("BED", _dialogue_ui_text("P1_LABEL_BED"), Rect2(180, 610, 560, 210), _inspect_bedroom.bind("bed"))
	_add_hotspot("WINDOW", _dialogue_ui_text("P1_LABEL_WINDOW"), Rect2(1250, 180, 330, 410), _inspect_bedroom.bind("window"))
	_add_hotspot("PHOTO", _dialogue_ui_text("P1_LABEL_PHOTO"), Rect2(930, 245, 190, 245), _inspect_bedroom.bind("photo"))
	_add_hotspot("NOTEBOOK", _dialogue_ui_text("P1_LABEL_NOTEBOOK"), Rect2(610, 690, 180, 115), _inspect_bedroom.bind("notebook"))
	_add_hotspot("EXIT", _dialogue_ui_text("P1_LABEL_EXIT"), Rect2(825, 850, 300, 100), _leave_bedroom_morning)


func _inspect_bedroom(object_id: String) -> void:
	if _dialogue_active or _modal_active:
		return
	_add_unique("p1_inspections", object_id)
	var lines := {
		"bed": "P1_INSPECT_BED",
		"window": "P1_INSPECT_WINDOW",
		"photo": "P1_INSPECT_PHOTO",
		"notebook": "P1_INSPECT_NOTEBOOK",
	}
	if object_id == "notebook":
		_add_notebook("수첩의 빈 페이지 아래에 이전 필압 같은 자국이 남아 있다.")
	_show_dialogue([{"speaker": "주인공", "text": _dialogue_ui_text(String(lines[object_id]))}])
	_room_art.set_room(_current_room, _progress)
	_save_progress()


func _leave_bedroom_morning() -> void:
	if _dialogue_active or _modal_active:
		return
	if Array(_progress.get("p1_inspections", [])).size() < 2:
		_show_modal(
			_dialogue_ui_text("P1_EXIT_TITLE"),
			_dialogue_ui_text("P1_EXIT_CONFIRM"),
			[
				{"label": _dialogue_ui_text("P1_EXIT_START"), "action": _complete_p1},
				{"label": _dialogue_ui_text("P1_EXIT_STAY"), "action": _close_modal},
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
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P1_HALL_VIEW")},
		{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P1_HALL_EDGAR")},
	])


func _build_hall() -> void:
	var morning_complete := _morning_tasks_complete()
	if not bool(_progress.get("P4_complete", false)):
		_add_hotspot("PARLOR", _task_label(_dialogue_ui_text("UI_DUTY_PARLOR"), "P2_complete"), Rect2(110, 410, 350, 180), _enter_room.bind("M1_PARLOR"))
		_add_hotspot("LIBRARY", _task_label(_dialogue_ui_text("UI_DUTY_LIBRARY"), "P3_complete"), Rect2(1120, 445, 300, 180), _enter_room.bind("M1_LIBRARY_OUTER"))
		_add_hotspot("ARCHIVE", _task_label(_dialogue_ui_text("UI_DUTY_ARCHIVE"), "P3B_complete"), Rect2(690, 240, 350, 150), _enter_room.bind("M1_NORTH_ARCHIVE_HALL"))
		if morning_complete:
			_add_hotspot("KITCHEN", _dialogue_ui_text("UI_DUTY_KITCHEN"), Rect2(1430, 430, 260, 180), _enter_room.bind("M1_KITCHEN"))
		else:
			_add_hotspot("REPORT", _dialogue_ui_text("UI_DUTY_REPORT"), Rect2(760, 650, 360, 105), _report_tasks)
		return

	_progress["time_block"] = "evening_free"
	_add_hotspot("GREENHOUSE", _task_label(_dialogue_ui_text("PF_GREENHOUSE"), "P5_complete"), Rect2(1415, 405, 275, 190), _enter_room.bind("M1_GREENHOUSE_VESTIBULE"))
	_add_hotspot("BEDROOM", _dialogue_ui_text("PF_BEDROOM"), Rect2(720, 220, 420, 150), _enter_room.bind("M2_BEDROOM"))
	_add_hotspot("PARLOR", _dialogue_ui_text("PF_PARLOR"), Rect2(120, 430, 330, 160), _evening_ambient.bind(_dialogue_ui_text("PF_LIGHT")))
	_add_hotspot("LIBRARY", _dialogue_ui_text("PF_LIBRARY"), Rect2(1110, 460, 310, 160), _evening_ambient.bind(_dialogue_ui_text("PF_PAGES")))


func _report_tasks() -> void:
	var missing: Array[String] = []
	for pair in [["P2_complete", "UI_DUTY_PARLOR"], ["P3_complete", "UI_DUTY_LIBRARY"], ["P3B_complete", "UI_DUTY_ARCHIVE"]]:
		if not bool(_progress.get(pair[0], false)):
			missing.append(_dialogue_ui_text(pair[1]))
	_show_dialogue([{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("UI_DUTY_REMAINING", {"tasks": ", ".join(missing)})}])


func _build_parlor() -> void:
	_normalize_window_states()
	_sync_window_stages()
	_update_inventory([
		{"id": "SOFT_CLOTH", "label": _dialogue_ui_text("P2_TOOL_CLOTH")},
		{"id": "COARSE_BRUSH", "label": _dialogue_ui_text("P2_TOOL_BRUSH")},
		{"id": "WATER", "label": _dialogue_ui_text("P2_TOOL_WATER")},
		{"id": "SPANNER", "label": _dialogue_ui_text("P2_TOOL_SPANNER")},
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
			{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_INTRO")},
			{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_GUIDE")},
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
	_set_window_feedback(_dialogue_ui_text("P2_DRAG"))
	_refresh_window_inspection()
	_set_status(_dialogue_ui_text("P2_INSPECTING", {"index": index + 1}))


func _close_window_inspection(update_status: bool = true) -> void:
	if _inspection_layer != null:
		_inspection_layer.visible = false
	_inspection_active = false
	_inspected_window = -1
	if update_status and _status_label != null:
		_set_status(_dialogue_ui_text("P2_CLOSED"))
	_refresh_inventory_selection()


func _refresh_window_inspection() -> void:
	if not _inspection_active or _inspected_window < 0:
		return
	var states: Array = _progress.get("window_states", [])
	if _inspected_window >= states.size():
		return
	var state: Dictionary = states[_inspected_window]
	_window_title.text = _dialogue_ui_text("P2_TITLE", {"index": _inspected_window + 1, "state": _window_stage_name(_stage_from_window_state(state))})
	_window_art.set_window_state(_inspected_window, state)
	var clean := _is_window_clean(state)
	var top = _window_drop_targets["TOP"]
	var middle = _window_drop_targets["MIDDLE"]
	var bottom = _window_drop_targets["BOTTOM"]
	top.text = _dialogue_ui_text("P2_TOP", {"state": _dialogue_ui_text("P2_SPREAD" if bool(state.get("dust_spread", false)) else ("P2_DUST" if bool(state.get("top_dust", true)) else "P2_CLEAR"))})
	middle.text = _dialogue_ui_text("P2_MIDDLE", {"state": _dialogue_ui_text("P2_STAIN" if bool(state.get("middle_stain", true)) else "P2_CLEAR")})
	bottom.text = _dialogue_ui_text("P2_BOTTOM", {"state": _dialogue_ui_text("P2_WET" if bool(state.get("bottom_wet", false)) else "P2_DRY")})
	for target_value in _window_drop_targets.values():
		if _reading_text_scale > 1.0:
			target_value.text = target_value.text.replace("\n", " · ")
		target_value.set_drop_enabled(not clean)
	_window_hint_label.text = _dialogue_ui_text("P2_CLEAN_HINT" if clean else "P2_ACTIVE_HINT")
	_refresh_inventory_selection()


func _on_window_zone_pressed(zone_id: String) -> void:
	if _selected_item.is_empty():
		_set_window_feedback(_dialogue_ui_text("P2_SELECT_HINT"))
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
		_set_window_feedback(_dialogue_ui_text("P2_TOOL_ALREADY"))
		return
	var feedback_kind := "neutral"
	match item_id:
		"SPANNER":
			_set_window_feedback(_dialogue_ui_text("P2_TOOL_SPANNER_FEEDBACK"))
			if not bool(_progress.get("p2_spanner_hint_seen", false)):
				_progress["p2_spanner_hint_seen"] = true
				_show_dialogue([{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_SPANNER_LINE")}])
		"COARSE_BRUSH":
			state["top_dust"] = true
			state["dust_spread"] = true
			feedback_kind = "wrong"
			_set_window_feedback(_dialogue_ui_text("P2_TOOL_BRUSH_FEEDBACK"))
			if not bool(_progress.get("p2_brush_hint_seen", false)):
				_progress["p2_brush_hint_seen"] = true
				_show_dialogue([{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_BRUSH_LINE")}])
		"WATER":
			if zone_id == "MIDDLE" and not bool(state.get("top_dust", true)) and bool(state.get("middle_stain", true)):
				state["middle_stain"] = false
				state["bottom_wet"] = true
				feedback_kind = "water"
				_set_window_feedback(_dialogue_ui_text("P2_TOOL_WATER_STAIN"))
			elif zone_id == "BOTTOM" and not bool(state.get("top_dust", true)) and not bool(state.get("middle_stain", true)):
				state["bottom_wet"] = true
				feedback_kind = "water"
				_set_window_feedback(_dialogue_ui_text("P2_TOOL_WATER_BOTTOM"))
			else:
				feedback_kind = "wrong"
				_set_window_feedback(_dialogue_ui_text("P2_TOOL_WATER_WRONG"))
		"SOFT_CLOTH":
			match zone_id:
				"TOP":
					state["top_dust"] = false
					state["dust_spread"] = false
					feedback_kind = "correct"
					_set_window_feedback(_dialogue_ui_text("P2_TOOL_TOP_CLEAN"))
					if _inspected_window == 2 and not bool(_progress.get("bird_observed", false)):
						_progress["bird_observed"] = true
						_add_notebook("같은 새가 18초 간격으로 같은 궤도를 두 번 지나갔다.")
						_show_dialogue([
							{"speaker": "SYSTEM", "text": _dialogue_ui_text("P2_TOOL_BIRD")},
							{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_BIRD_LINE")},
						])
				"MIDDLE":
					if bool(state.get("top_dust", true)):
						feedback_kind = "falling_dust"
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_MIDDLE_ORDER"))
					elif bool(state.get("middle_stain", true)):
						state["middle_stain"] = false
						feedback_kind = "correct"
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_MIDDLE_CLEAN"))
					else:
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_MIDDLE_ALREADY"))
				"BOTTOM":
					if bool(state.get("top_dust", true)) or bool(state.get("middle_stain", true)):
						feedback_kind = "falling_dust"
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_BOTTOM_ORDER"))
					elif bool(state.get("bottom_wet", false)):
						state["bottom_wet"] = false
						feedback_kind = "correct"
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_BOTTOM_CLEAN"))
					else:
						_set_window_feedback(_dialogue_ui_text("P2_TOOL_BOTTOM_ALREADY"))
		_:
			_set_window_feedback(_dialogue_ui_text("P2_TOOL_INVALID"))
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
		{"speaker": "마라 1", "portrait": "MARA1", "text": _dialogue_ui_text("P2_TOOL_COMPLETE_LINE")},
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
			inventory.append({"id": book_id, "label": _dialogue_ui_text("P3_NAME_" + String(book_id))})
	_update_inventory(inventory)
	var shelves := [
		["SHELF_CLOCK", _dialogue_ui_text("P3_SHELF_CLOCK"), Rect2(315, 300, 285, 300)],
		["SHELF_FLOWER", _dialogue_ui_text("P3_SHELF_FLOWER"), Rect2(720, 300, 285, 300)],
		["SHELF_CUP", _dialogue_ui_text("P3_SHELF_CUP"), Rect2(1125, 300, 285, 300)],
	]
	for shelf in shelves:
		var occupant := String(placed.get(shelf[0], ""))
		var label := String(shelf[1]) if occupant.is_empty() else _dialogue_ui_text("P3_PLACED", {"book": _dialogue_ui_text("P3_NAME_" + occupant)})
		_add_inventory_drop_hotspot(String(shelf[0]), label, shelf[2], _on_shelf_pressed.bind(String(shelf[0])), _on_shelf_item_dropped)
	_add_hotspot("INNER_DOOR", _dialogue_ui_text("P3_INNER_DOOR"), Rect2(1460, 210, 205, 460), _inspect_inner_door)
	_add_back_to_hall()
	var needs_journal_choice := bool(_progress.get("p3_journal_seen", false)) \
		and String(_progress.get("p3_journal_choice", "")) in ["", "pending"] \
		and not _p3_journal_prompt_active
	if not _intro_seen("P3"):
		_mark_intro("P3")
		_show_dialogue([
			{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P3_INTRO")},
			{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P3_RESTRICTED")},
		], _resume_p3_journal_choice if needs_journal_choice else Callable())
	elif needs_journal_choice:
		call_deferred("_resume_p3_journal_choice")


func _on_shelf_pressed(shelf_id: String) -> void:
	if _interaction_blocked() or bool(_progress.get("P3_complete", false)):
		return
	if _selected_item not in P3_BOOKS:
		_set_status(_dialogue_ui_text("P3_SELECT"))
		return
	var expected := String(P3_BOOKS[_selected_item]["shelf"])
	if shelf_id != expected:
		_set_status(_dialogue_ui_text("P3_WRONG"))
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
			{"speaker": "SYSTEM", "text": _dialogue_ui_text("P3_DISCOVER")},
			{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P3_LEDGER")},
		], _show_p3_journal_choices)
		return
	_finish_p3_book_placement()


func _localized_p3_choices() -> Dictionary:
	var choices := P3_JOURNAL_CHOICES.duplicate(true)
	for choice_id in choices:
		choices[choice_id]["label"] = _dialogue_ui_text("P3_Q_" + String(choice_id).to_upper())
		if choice_id != "silent":
			choices[choice_id]["response"] = _dialogue_ui_text("P3_A_" + String(choice_id).to_upper())
	return choices


func _show_p3_journal_choices() -> void:
	_p3_journal_prompt_active = true
	_show_dialogue_choice_set(
		"p3_journal",
		_dialogue_ui_text("P3_HEADER"),
		"주인공",
		_dialogue_ui_text("P3_PROMPT"),
		"EDGAR",
		["author", "locked", "silent"],
		_localized_p3_choices()
	)


func _show_dialogue_choice_set(
	mode: String,
	header: String,
	speaker: String,
	prompt: String,
	portrait_id: String,
	choice_order: Array,
	choice_data: Dictionary
) -> void:
	_dialogue_active = false
	_dialogue_lines.clear()
	_dialogue_after = Callable()
	_dialogue_choice_mode = mode
	_dialogue_choice_active = true
	_dialogue_layer.visible = true
	_dialogue_choice_blocker.visible = true
	_dialogue_choice_panel.visible = true
	_dialogue_next.visible = false
	_dialogue_choice_header.text = header
	_speaker_label.text = _localized_speaker(speaker)
	_dialogue_label.text = prompt
	_dialogue_scroll.scroll_vertical = 0
	_set_dialogue_portrait(portrait_id)
	for index in range(_dialogue_choice_buttons.size()):
		var button := _dialogue_choice_buttons[index]
		var choice_id := String(choice_order[index]) if index < choice_order.size() else ""
		button.set_meta("choice_id", choice_id)
		button.set_meta("choice_label", String(choice_data.get(choice_id, {}).get("label", "")))
		button.visible = not choice_id.is_empty()
	_refresh_dialogue_choice_labels()
	var initial_index := _first_unasked_p3_choice_index() if mode == "p3_journal" else 0
	_focus_dialogue_choice(initial_index)


func _answer_p3_journal_choice(choice_id: String) -> void:
	if not P3_JOURNAL_CHOICES.has(choice_id):
		return
	_hide_dialogue_choices()
	if choice_id == "silent":
		_dialogue_layer.visible = false
		_p3_journal_prompt_active = false
		_progress["p3_journal_choice"] = "silent"
		_save_progress()
		_set_status(_dialogue_ui_text("P3_SILENT_STATUS"))
		_finish_p3_book_placement()
		return
	var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
	if choice_id not in asked_questions:
		asked_questions.append(choice_id)
	_progress["p3_journal_questions_asked"] = asked_questions
	_progress["p3_journal_choice"] = "pending"
	_save_progress()
	var response := String(_localized_p3_choices()[choice_id]["response"])
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
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P3_RESUME")},
		{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P3_LEDGER")},
	], _show_p3_journal_choices)


func _finish_p3_book_placement() -> void:
	var placed: Dictionary = _progress.get("p3_placed", {})
	if placed.size() >= 3 and not bool(_progress.get("P3_complete", false)):
		_progress["P3_complete"] = true
		_save_progress()
		_rebuild_current_room_content()
		_show_dialogue([{"speaker": "에드가", "portrait": "EDGAR", "text": _dialogue_ui_text("P3_COMPLETE")}], func() -> void: _enter_room("M1_CENTRAL_HALL"))
		return
	_save_progress()
	_rebuild_current_room_content()


func _on_shelf_item_dropped(item_id: String, shelf_id: String) -> void:
	_selected_item = item_id
	_on_shelf_pressed(shelf_id)


func _inspect_inner_door() -> void:
	_show_dialogue([{"speaker": "주인공", "text": _dialogue_ui_text("P3_DOOR")}])


func _build_archive() -> void:
	var inventory: Array = []
	var placed: Dictionary = _progress.get("p3b_placed", {})
	for owner_id in P3B_LABELS:
		if owner_id not in placed.values():
			inventory.append({"id": "LABEL_%s" % owner_id, "label": _dialogue_ui_text("P3B_" + String(owner_id))})
	_update_inventory(inventory)
	var visuals := [_dialogue_ui_text("P3B_V_EDGAR"), _dialogue_ui_text("P3B_V_MARA1"), _dialogue_ui_text("P3B_V_LUCA"), _dialogue_ui_text("P3B_V_IRIS"), _dialogue_ui_text("P3B_V_MARA2")]
	for index in range(5):
		var owner: String = String(P3B_OWNERS[index])
		var assigned := _owner_at_portrait(index)
		var suffix := "\n[%s]" % _dialogue_ui_text("P3B_" + assigned) if not assigned.is_empty() else ""
		_add_inventory_drop_hotspot("PORTRAIT_%d" % index, "%s%s" % [visuals[index], suffix], Rect2(205 + index * 280, 260 + (index % 2) * 35, 235, 310), _on_portrait_pressed.bind(index, owner), _on_portrait_item_dropped)
	_add_back_to_hall()
	if not _intro_seen("P3B"):
		_mark_intro("P3B")
		_add_unique("introduced", "MARA2")
		_show_dialogue([
			{"speaker": "마라 2", "portrait": "MARA2", "text": _dialogue_ui_text("P3B_INTRO")},
			{"speaker": "마라 2", "portrait": "MARA2", "text": _dialogue_ui_text("P3B_HINT")},
		])


func _on_portrait_pressed(index: int, expected_owner: String) -> void:
	if _interaction_blocked() or bool(_progress.get("P3B_complete", false)):
		return
	if not _selected_item.begins_with("LABEL_"):
		_set_status(_dialogue_ui_text("P3B_DRAG"))
		return
	var selected_owner := _selected_item.trim_prefix("LABEL_")
	if selected_owner != expected_owner:
		_show_dialogue([{"speaker": "마라 2", "portrait": "MARA2", "text": _dialogue_ui_text("P3B_WRONG")}])
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
			{"speaker": "SYSTEM", "text": _dialogue_ui_text("P3B_PATTERNS")},
			{"speaker": "마라 2", "portrait": "MARA2", "text": _dialogue_ui_text("P3B_COMPLETE")},
			{"speaker": "마라 2", "portrait": "MARA2", "text": _dialogue_ui_text("P3B_NAME")},
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
	var step := int(_progress.get("tea_step", 0))
	if step < TEA_STEPS.size():
		_update_inventory([
			{"id": "CUP", "label": _dialogue_ui_text("P4_TEA_ITEM_CUP")},
			{"id": "HOT_WATER", "label": _dialogue_ui_text("P4_TEA_ITEM_HOT_WATER")},
			{"id": "TEA_LEAVES", "label": _dialogue_ui_text("P4_TEA_ITEM_TEA_LEAVES")},
			{"id": "SPOON", "label": _dialogue_ui_text("P4_TEA_ITEM_SPOON")},
			{"id": "TIMER", "label": _dialogue_ui_text("P4_TEA_ITEM_TIMER")},
			{"id": "TEAPOT", "label": _dialogue_ui_text("P4_TEA_ITEM_TEAPOT")},
		])
		for index in range(TEA_STEPS.size()):
			var done := index < step
			var label := "%d. %s\n%s%s" % [index + 1, _dialogue_ui_text("P4_TEA_STEP_%d" % index), _dialogue_ui_text("P4_TEA_ITEM_" + String(TEA_STEP_ITEMS[index])), " · " + _dialogue_ui_text("UI_DUTY_COMPLETE") if done else ""]
			_add_inventory_drop_hotspot("TEA_%d" % index, label, Rect2(320 + (index % 3) * 390, 300 + (index / 3) * 170, 330, 120), _on_tea_target_pressed.bind(index), _on_tea_item_dropped)
	else:
		_update_inventory([])
		var handle_label := _dialogue_ui_text("P4_LINK_HANDLE")
		if bool(_progress.get("p4_handle_return_used", false)):
			handle_label += _dialogue_ui_text("P4_LINK_RETURNED")
		_add_hotspot("P4_CUP_HANDLE", handle_label, Rect2(420, 320, 440, 230), _turn_p4_cup_handle)
		var cup := Control.new()
		cup.set_script(load("res://scripts/prologue/prologue_cup_art.gd"))
		cup.name = "P4_CUP_ART"
		cup.position = Vector2(570, 160)
		cup.size = Vector2(140, 140)
		_hotspot_layer.add_child(cup)
		_add_hotspot("P4_ASK_LUCA", _dialogue_ui_text("P4_LINK_ASK"), Rect2(1010, 340, 430, 190), _show_p4_father_choices)
	if bool(_progress.get("p4_life_support_seen", false)) and not bool(_progress.get("p4_life_support_recorded", false)):
		_add_hotspot("P4_RECORD_PULSE", _dialogue_ui_text("P4_LINK_RECORD"), Rect2(710, 690, 500, 100), _record_p4_life_support_pulse)
	if not _intro_seen("P4"):
		_mark_intro("P4")
		_add_unique("introduced", "LUCA")
		_show_dialogue([
			{"speaker": "루카", "portrait": "LUCA", "text": _dialogue_ui_text("P4_LINK_INTRO")},
			{"speaker": "루카", "portrait": "LUCA", "text": _dialogue_ui_text("P4_LINK_GUIDE")},
		])
	elif bool(_progress.get("P4_complete", false)) and not bool(_progress.get("iris_greeting_seen", false)):
		call_deferred("_show_p4_iris_greeting")
	elif String(_progress.get("p4_phase", "")) == "memory_anchor":
		call_deferred("_resume_p4_memory_anchor")
	elif String(_progress.get("p4_phase", "")) == "question_answered":
		call_deferred("_resume_p4_question_answer")
	elif String(_progress.get("p4_phase", "")) == "question" and String(_progress.get("p4_father_question", "")).is_empty():
		call_deferred("_show_p4_father_choices")


func _on_tea_step(index: int) -> void:
	if _interaction_blocked() or bool(_progress.get("P4_complete", false)):
		return
	var step := int(_progress.get("tea_step", 0))
	if step >= TEA_STEPS.size():
		return
	if index != step:
		_set_status(_dialogue_ui_text("P4_TEA_ORDER", {"step": _dialogue_ui_text("P4_TEA_STEP_%d" % step)}))
		return
	_progress["tea_step"] = step + 1
	_set_status(_dialogue_ui_text("P4_TEA_DONE", {"step": _dialogue_ui_text("P4_TEA_STEP_%d" % index)}))
	if step + 1 >= TEA_STEPS.size():
		_begin_p4_memory_anchor()
		return
	_save_progress()
	_rebuild_current_room_content()
	if index == 4 and not bool(_progress.get("p4_life_support_seen", false)):
		_show_p4_life_support_foreshadow()


func _on_tea_target_pressed(index: int) -> void:
	if _selected_item.is_empty():
		_set_status(_dialogue_ui_text("P4_TEA_DRAG"))
		return
	_on_tea_item_dropped(_selected_item, "TEA_%d" % index)


func _on_tea_item_dropped(item_id: String, target_id: String) -> void:
	var index := int(target_id.trim_prefix("TEA_"))
	if index < 0 or index >= TEA_STEPS.size():
		return
	if item_id != String(TEA_STEP_ITEMS[index]):
		_set_status(_dialogue_ui_text("P4_TEA_REQUIRES", {"step": _dialogue_ui_text("P4_TEA_STEP_%d" % index), "item": _dialogue_ui_text("P4_TEA_ITEM_" + String(TEA_STEP_ITEMS[index]))}))
		return
	_selected_item = item_id
	_on_tea_step(index)


func _show_p4_life_support_foreshadow() -> void:
	_progress["p4_life_support_seen"] = true
	_save_progress()
	_rebuild_current_room_content()
	_show_dialogue([
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_PULSE")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_EARS")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_REPLY")},
	])


func _record_p4_life_support_pulse() -> void:
	if _interaction_blocked() or bool(_progress.get("p4_life_support_recorded", false)):
		return
	if not bool(_progress.get("p4_life_support_seen", false)):
		return
	_progress["p4_life_support_recorded"] = true
	_add_notebook("주방의 규칙적인 진동")
	_save_progress()
	_rebuild_current_room_content()
	_set_status(_dialogue_ui_text("P4_MEMORY_NOTE"))


func _begin_p4_memory_anchor() -> void:
	_progress["p4_phase"] = "memory_anchor"
	_progress["p4_memory_anchor_seen"] = true
	_save_progress()
	_rebuild_current_room_content()
	_resume_p4_memory_anchor()


func _resume_p4_memory_anchor() -> void:
	if _interaction_blocked() or _current_room != "M1_KITCHEN" or String(_progress.get("p4_phase", "")) != "memory_anchor":
		return
	_progress["p4_memory_anchor_seen"] = true
	_show_dialogue([
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_GROOVE")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_SCRAPE")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_HAND")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_ABSENCE")},
		{"speaker": "주인공", "text": _dialogue_ui_text("P4_MEMORY_WHY")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_MEMORY_PAUSE")},
		{"speaker": "루카", "portrait": "LUCA", "text": _dialogue_ui_text("P4_MEMORY_HABIT")},
	], _finish_p4_memory_anchor)


func _finish_p4_memory_anchor() -> void:
	_progress["p4_phase"] = "memory_anchor_ready"
	_save_progress()


func _turn_p4_cup_handle() -> void:
	if _interaction_blocked() or int(_progress.get("tea_step", 0)) < TEA_STEPS.size():
		return
	if bool(_progress.get("p4_handle_return_used", false)):
		_show_dialogue([{"speaker": "주인공", "text": _dialogue_ui_text("P4_MEMORY_ALREADY")}])
		return
	_progress["p4_handle_return_used"] = true
	_save_progress()
	_rebuild_current_room_content()
	_show_dialogue([
		{"speaker": "SYSTEM", "cup_pose": "turned", "text": _dialogue_ui_text("P4_MEMORY_TURN")},
		{"speaker": "SYSTEM", "cup_pose": "returned", "text": _dialogue_ui_text("P4_MEMORY_RETURN")},
	])


func _localized_p4_choices() -> Dictionary:
	var choices := P4_FATHER_CHOICES.duplicate(true)
	for choice_id in choices:
		choices[choice_id]["label"] = _dialogue_ui_text("P4_Q_" + String(choice_id).to_upper())
		choices[choice_id]["response"] = _dialogue_ui_text("P4_A_" + String(choice_id).to_upper())
	return choices


func _show_p4_father_choices() -> void:
	if _dialogue_active or _modal_active or bool(_progress.get("P4_complete", false)):
		return
	if int(_progress.get("tea_step", 0)) < TEA_STEPS.size() or not bool(_progress.get("p4_memory_anchor_seen", false)):
		return
	_progress["p4_phase"] = "question"
	_save_progress()
	_show_dialogue_choice_set(
		"p4_father",
		_dialogue_ui_text("P4_HEADER"),
		"주인공",
		_dialogue_ui_text("P4_PROMPT"),
		"LUCA",
		P4_FATHER_CHOICE_ORDER,
		_localized_p4_choices()
	)


func _answer_p4_father_choice(choice_id: String) -> void:
	if not P4_FATHER_CHOICES.has(choice_id) or not String(_progress.get("p4_father_question", "")).is_empty():
		return
	if String(_progress.get("p4_phase", "")) != "question" or not _dialogue_choice_active or _dialogue_choice_mode != "p4_father":
		return
	_hide_dialogue_choices()
	_progress["p4_father_question"] = choice_id
	_progress["p4_phase"] = "question_answered"
	_save_progress()
	_present_p4_question_answer(choice_id)


func _resume_p4_question_answer() -> void:
	if _dialogue_active or _dialogue_choice_active or bool(_progress.get("P4_complete", false)):
		return
	var choice_id := String(_progress.get("p4_father_question", ""))
	if P4_FATHER_CHOICES.has(choice_id):
		_present_p4_question_answer(choice_id)


func _present_p4_question_answer(choice_id: String) -> void:
	var lines: Array = [{"speaker": "루카", "portrait": "LUCA", "text": String(_localized_p4_choices()[choice_id]["response"])}]
	if choice_id == "luca_tenure":
		lines.append({"speaker": "SYSTEM", "text": _dialogue_ui_text("P4_TENURE_PAUSE")})
		lines.append({"speaker": "루카", "portrait": "LUCA", "text": _dialogue_ui_text("P4_SERVE")})
	_show_dialogue(lines, _finish_p4_after_question)


func _finish_p4_after_question() -> void:
	_progress["P4_complete"] = true
	_progress["p4_phase"] = "complete"
	_progress["time_block"] = "evening_free"
	_save_progress()
	_show_p4_iris_greeting()


func _show_p4_iris_greeting() -> void:
	if _dialogue_active or bool(_progress.get("iris_greeting_seen", false)):
		return
	_add_unique("introduced", "IRIS")
	_show_dialogue([
		{"speaker": "이리스", "portrait": "IRIS", "text": _dialogue_ui_text("P4_LINK_IRIS_HELLO")},
		{"speaker": "이리스", "portrait": "IRIS", "text": _dialogue_ui_text("P4_LINK_IRIS_INVITE")},
	], _complete_p4_iris_greeting)


func _complete_p4_iris_greeting() -> void:
	_progress["iris_greeting_seen"] = true
	_save_progress()
	_enter_room("M1_CENTRAL_HALL")


func _build_greenhouse() -> void:
	_clear_hotspots()
	var observations: Array = _progress.get("p5_observations", [])
	_add_hotspot("CORRIDOR_WINDOW", _observed_label(_dialogue_ui_text("P5_CORRIDOR_LABEL"), "corridor", observations), Rect2(230, 245, 300, 350), _observe_weather.bind("corridor", _dialogue_ui_text("P5_CORRIDOR")))
	_add_hotspot("GREENHOUSE_GLASS", _observed_label(_dialogue_ui_text("P5_GLASS_LABEL"), "glass", observations), Rect2(670, 205, 420, 430), _observe_weather.bind("glass", _dialogue_ui_text("P5_GLASS")))
	_add_hotspot("THRESHOLD", _observed_label(_dialogue_ui_text("P5_THRESHOLD_LABEL"), "threshold", observations), Rect2(1140, 570, 350, 150), _observe_weather.bind("threshold", _dialogue_ui_text("P5_THRESHOLD")))
	if observations.size() >= 3 and not bool(_progress.get("P5_complete", false)):
		_add_hotspot("RECORD", _dialogue_ui_text("P5_RECORD"), Rect2(700, 760, 500, 100), _complete_p5)
	_add_back_to_hall()
	if not _intro_seen("P5"):
		_mark_intro("P5")
		_show_dialogue([
			{"speaker": "이리스", "portrait": "IRIS", "text": _dialogue_ui_text("P5_HELLO")},
			{"speaker": "이리스", "portrait": "IRIS", "text": _dialogue_ui_text("P5_OUTSIDE")},
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
		{"speaker": "주인공", "text": _dialogue_ui_text("P5_QUESTION")},
		{"speaker": "이리스", "portrait": "IRIS", "text": _dialogue_ui_text("P5_ANSWER")},
	], func() -> void: _enter_room("M1_CENTRAL_HALL"))


func _on_sleep_bed() -> void:
	if _interaction_blocked():
		return
	_show_modal(
		_dialogue_ui_text("P6_TITLE"),
		_dialogue_ui_text("P6_BODY"),
		[
			{"label": _dialogue_ui_text("P6_SLEEP"), "action": _begin_first_sleep},
			{"label": _dialogue_ui_text("P6_CANCEL"), "action": _close_modal},
		]
	)


func _begin_first_sleep() -> void:
	_close_modal()
	var previous_progress := _progress.duplicate(true)
	_progress["P6_complete"] = true
	_add_notebook("오늘을 끝내고 잠든다.")
	if _test_mode:
		_progress["prologue_complete"] = true
		return
	var saved := _save_progress("SAVE_P6_COMPLETE", true)
	if not saved:
		_progress = previous_progress
		_set_status(_dialogue_ui_text("P6_SAVE_ERROR"))
		return
	_show_dialogue([
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P6_DARK")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("P6_SOUND")},
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
	_location_label.text = _dialogue_ui_text("R1_ROOM")
	_clear_hotspots()
	_update_inventory([])
	_room_art.set_room("M2_BEDROOM", _progress)
	_objective_label.text = _dialogue_ui_text("R1_OBJECTIVE")
	_show_dialogue([
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("R1_WAKE")},
		{"speaker": "주인공", "text": _dialogue_ui_text("R1_SAME")},
		{"speaker": "SYSTEM", "text": _dialogue_ui_text("R1_NOTES")},
	], func() -> void: campaign_requested.emit(_slot_id))


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
	_add_hotspot("BACK", _dialogue_ui_text("UI_P_BACK"), Rect2(720, 875, 400, 90), _enter_room.bind("M1_CENTRAL_HALL"))


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
	_set_status(_dialogue_ui_text("UI_INV_SELECTED", {"item": _inventory_slots[index].text}))
	_refresh_inventory_selection()


func _on_inventory_drag_started(item_id: String) -> void:
	_selected_item = item_id
	var display_name := item_id
	for slot in _inventory_slots:
		if String(slot.get_meta("item_id", "")) == item_id:
			display_name = slot.text.replace("\n", " ")
			break
	_set_status(_dialogue_ui_text("UI_INV_DRAGGING", {"item": display_name}))
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
			slot.tooltip_text = _dialogue_ui_text("UI_INV_DRY_HINT" if drying_hint else "UI_INV_DRAG_HINT")
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


func _dialogue_ui_text(text_id: String, variables: Dictionary = {}) -> String:
	return _dialogue_texts.get_text(text_id, TranslationServer.get_locale(), variables)


func _localized_speaker(speaker: String) -> String:
	var names := {
		"SYSTEM": "SYSTEM", "주인공": "SUBJECT", "SUBJECT": "SUBJECT",
		"에드가": "EDGAR", "EDGAR": "EDGAR", "마라 1": "MARA1", "MARA1": "MARA1",
		"마라 2": "MARA2", "MARA2": "MARA2", "루카": "LUKA", "LUKA": "LUKA",
		"이리스": "IRIS", "IRIS": "IRIS"
	}
	if not names.has(speaker):
		return speaker
	return _dialogue_ui_text("UI_SPEAKER_" + String(names[speaker]))


func _present_dialogue_line() -> void:
	var line: Dictionary = _dialogue_lines[_dialogue_index]
	if line.get("cup_pose", "") in ["turned", "returned"]:
		var cup := _hotspot_layer.get_node_or_null("P4_CUP_ART")
		if cup != null:
			var profile: Dictionary = AccessibilityProfileStore.new().load_profile().get("profile", {})
			cup.show_angle(TAU if line["cup_pose"] == "turned" else PI, String(profile.get("motion_mode", "standard")) != "standard")
	_speaker_label.text = _localized_speaker(String(line.get("speaker", "SYSTEM")))
	_dialogue_label.text = String(line.get("text", ""))
	_dialogue_scroll.scroll_vertical = 0
	var portrait_id := String(line.get("portrait", ""))
	_set_dialogue_portrait(portrait_id)
	_dialogue_next.visible = true
	_dialogue_next.text = _dialogue_ui_text("UI_DIALOGUE_FINISH" if _dialogue_index >= _dialogue_lines.size() - 1 else "UI_DIALOGUE_CONTINUE")
	call_deferred("_focus_visible_control", weakref(_dialogue_next))


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


func _refresh_dialogue_choice_labels() -> void:
	var asked_questions: Array = _progress.get("p3_journal_questions_asked", [])
	for index in range(_dialogue_choice_buttons.size()):
		var button := _dialogue_choice_buttons[index]
		var choice_id := String(button.get_meta("choice_id", ""))
		var label := String(button.get_meta("choice_label", choice_id))
		var prefix := "▶ " if index == _dialogue_choice_focus_index else "   "
		var suffix := "  [%s]" % _dialogue_ui_text("UI_P_CHECKED") if _dialogue_choice_mode == "p3_journal" and choice_id in asked_questions else ""
		button.text = "%s%s%s" % [prefix, label, suffix]


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
	_refresh_dialogue_choice_labels()
	call_deferred("_focus_visible_control", weakref(_dialogue_choice_buttons[_dialogue_choice_focus_index]))


func _on_dialogue_choice_focused(index: int) -> void:
	_dialogue_choice_focus_index = clampi(index, 0, _dialogue_choice_buttons.size() - 1)
	_refresh_dialogue_choice_labels()


func _on_dialogue_choice_pressed(index: int) -> void:
	if not _dialogue_choice_active or index < 0 or index >= _dialogue_choice_buttons.size():
		return
	var choice_id := String(_dialogue_choice_buttons[index].get_meta("choice_id", ""))
	match _dialogue_choice_mode:
		"p3_journal":
			_answer_p3_journal_choice(choice_id)
		"p4_father":
			_answer_p4_father_choice(choice_id)


func _focus_p3_silent_choice() -> void:
	for index in range(_dialogue_choice_buttons.size()):
		if String(_dialogue_choice_buttons[index].get_meta("choice_id", "")) == "silent":
			_focus_dialogue_choice(index)
			break
	_set_status("선택 구간을 끝내려면 '말없이 내려놓는다'를 선택하십시오.")


func _handle_dialogue_choice_cancel() -> void:
	if _dialogue_choice_mode == "p3_journal":
		_focus_p3_silent_choice()
	else:
		_set_status("루카에게 건넬 질문 하나를 선택해야 한다.")


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
	_show_modal(_dialogue_ui_text("UI_P_MENU"), _dialogue_ui_text("UI_P_AUTOSAVE"), [
		{"label": _dialogue_ui_text("UI_DIALOGUE_CONTINUE"), "action": _close_modal},
		{"label": _dialogue_ui_text("UI_P_RETURN_TITLE"), "action": _return_to_title},
	])


func _localized_notebook_entry(entry: String) -> String:
	# Legacy saves contain Korean prose; translate for display without rewriting history.
	var texts := _dialogue_texts
	for text_id in ["NOTE_P_DUTIES","NOTE_P_IMPRESSIONS","NOTE_P_BIRD","NOTE_P_WINDOWS","NOTE_P_JOURNAL","NOTE_P_SIGNATURES","NOTE_P_PULSE","NOTE_P_WEATHER","NOTE_P_SLEEP","NOTE_P_TEA"]:
		if entry == texts.get_text(text_id, "ko-KR"):
			return texts.get_text(text_id, TranslationServer.get_locale())
	return entry


func _open_notebook() -> void:
	if _dialogue_active or _dialogue_choice_active:
		return
	var entries: Array = _progress.get("notebook_entries", [])
	var body := _dialogue_ui_text("UI_NOTE_EMPTY") if entries.is_empty() else "\n\n".join(entries.map(func(value: Variant) -> String: return "- %s" % _localized_notebook_entry(String(value))))
	_show_modal(_dialogue_ui_text("UI_NOTE_TITLE"), body, [{"label": _dialogue_ui_text("UI_NOTE_CLOSE"), "action": _close_modal}])


func _show_modal(title: String, body: String, actions: Array) -> void:
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
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
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", int(round(23 * _reading_text_scale)))
	body_label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.90))
	var body_scroll := ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.custom_minimum_size.y = 100
	body_scroll.focus_mode = Control.FOCUS_ALL
	_modal_body.add_child(body_scroll)
	body_scroll.add_child(body_label)
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
		call_deferred("_focus_visible_control", weakref(_modal_body.get_child(3)))


func _focus_visible_control(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


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
	knowledge["prologue_notebook_entries"] = Array(_progress.get("notebook_entries", [])).duplicate(true)
	for servant_id in Array(_progress.get("introduced", [])):
		knowledge["INTRO_%s" % servant_id] = true
	if bool(_progress.get("p3_journal_seen", false)):
		knowledge["NOTE_JOURNAL"] = true
	if bool(_progress.get("P3B_complete", false)):
		knowledge["CLR_00_SIGNATURES"] = true
	if bool(_progress.get("p4_life_support_seen", false)):
		knowledge["OBS_KITCHEN_REGULAR_PULSE"] = true
	if bool(_progress.get("p4_memory_anchor_seen", false)):
		knowledge["MEM_FATHER_TEA_HAND_FRAGMENT"] = "sensory_fragment"
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
		_objective_label.text = _dialogue_ui_text("UI_OBJECTIVE_P1")
	elif not _morning_tasks_complete():
		var count := int(bool(_progress.get("P2_complete", false))) + int(bool(_progress.get("P3_complete", false))) + int(bool(_progress.get("P3B_complete", false)))
		_objective_label.text = _dialogue_ui_text("UI_OBJECTIVE_MORNING", {"count": count})
	elif not bool(_progress.get("P4_complete", false)):
		if int(_progress.get("tea_step", 0)) >= TEA_STEPS.size():
			_objective_label.text = _dialogue_ui_text("UI_OBJECTIVE_TEA_MEMORY")
		else:
			_objective_label.text = _dialogue_ui_text("UI_OBJECTIVE_TEA")
	else:
		_objective_label.text = _dialogue_ui_text("UI_OBJECTIVE_EVENING")


func _task_label(label: String, flag: String) -> String:
	return "%s\n%s" % [label, _dialogue_ui_text("UI_DUTY_COMPLETE" if bool(_progress.get(flag, false)) else "UI_DUTY_PENDING")]


func _window_stage_name(stage: int) -> String:
	return _dialogue_ui_text(["P2_STAGE_TOP", "P2_STAGE_MIDDLE", "P2_STAGE_BOTTOM", "UI_DUTY_COMPLETE"][clampi(stage, 0, 3)])


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
	return "%s%s" % [label, "\n[%s]" % _dialogue_ui_text("UI_P_CHECKED") if observation_id in observations else ""]


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
		if index == 4:
			if not bool(_progress.get("p4_life_support_seen", false)):
				errors.append("P4 life-support foreshadow did not trigger while tea steeped")
			if _dialogue_lines.size() != 3 or "두 번" not in String(_dialogue_lines[0].get("text", "")):
				errors.append("P4 life-support sensory sequence is incomplete")
		_dismiss_dialogue_for_test()
	if not bool(_progress.get("p4_memory_anchor_seen", false)) or bool(_progress.get("P4_complete", false)):
		errors.append("P4 memory anchor did not pause completion after six tea steps")
	if _hotspot_layer.get_node_or_null("P4_CUP_HANDLE") == null or _hotspot_layer.get_node_or_null("P4_ASK_LUCA") == null:
		errors.append("P4 memory-anchor interaction hotspots are missing")
	_record_p4_life_support_pulse()
	if "주방의 규칙적인 진동" not in Array(_progress.get("notebook_entries", [])):
		errors.append("P4 notebook pulse entry is missing or over-explained")
	_turn_p4_cup_handle()
	if not bool(_progress.get("p4_handle_return_used", false)) or _dialogue_lines.size() != 2:
		errors.append("P4 cup handle did not return exactly once after release")
	_dismiss_dialogue_for_test()
	_show_p4_father_choices()
	if not _dialogue_choice_active or _dialogue_choice_mode != "p4_father":
		errors.append("P4 father question choices did not open")
	var expected_p4_choice_text := {
		"father_tea": ["아버지가 좋아한 차인가요?", "네... 비슷한 향을 좋아하셨어요.\n정확히 같은지는... 이제 자신이 없지만요."],
		"mansion_age": ["이 저택은 언제부터 있었나요?", "아가씨가 기억하는 만큼 오래됐다고... 들었어요."],
		"luca_tenure": ["루카는 여기서 오래 일했나요?", "오래요... 아주 오래요.\n그런데 며칠이라고 세면, 늘 같은 수가 나와서..."],
	}
	for index in range(P4_FATHER_CHOICE_ORDER.size()):
		var expected_choice_id := String(P4_FATHER_CHOICE_ORDER[index])
		var button := _dialogue_choice_buttons[index]
		if String(button.get_meta("choice_id", "")) != expected_choice_id:
			errors.append("P4 father question order mismatch: %s" % expected_choice_id)
		if String(button.get_meta("choice_label", "")) != String(expected_p4_choice_text[expected_choice_id][0]):
			errors.append("P4 father question label mismatch: %s" % expected_choice_id)
		if String(P4_FATHER_CHOICES[expected_choice_id]["response"]) != String(expected_p4_choice_text[expected_choice_id][1]):
			errors.append("P4 father answer text mismatch: %s" % expected_choice_id)
	var tenure_button := _dialogue_choice_buttons[2]
	tenure_button.pressed.emit()
	if not _dialogue_active or _dialogue_lines.size() != 3 or "늘 같은 수" not in String(_dialogue_lines[0].get("text", "")):
		errors.append("P4 Luca tenure answer or topic-change beat is missing")
	_answer_p4_father_choice("father_tea")
	if String(_progress.get("p4_father_question", "")) != "luca_tenure":
		errors.append("P4 accepted more than one father question")
	while _dialogue_active:
		_advance_dialogue()
	if not bool(_progress.get("P4_complete", false)) or not bool(_progress.get("iris_greeting_seen", false)):
		errors.append("P4 or Iris greeting did not complete")
	if String(_progress.get("p4_father_question", "")) != "luca_tenure":
		errors.append("P4 selected father question was not recorded")

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
