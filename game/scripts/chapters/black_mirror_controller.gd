class_name BlackMirrorController
extends ChapterOneController

const MIRROR_SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const MIRROR_RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const OVERLAY_DIAGRAM := preload("res://scripts/chapters/mirror_overlay_diagram.gd")
const MIRROR_TEXTS := preload("res://scripts/ui/black_mirror_display_texts.gd")

func _make_session() -> ChapterOneSession:
	return MIRROR_SESSION.new(GameState, SaveManager, _slot_id)


func _supported_hint_stages() -> Array:
	return ["C3", "C4", "CF"]


func _open_notebook() -> void:
	if _interaction_blocked():
		return
	super._open_notebook()
	if session.stage() == "C3":
		var button := Button.new()
		button.name = "CleanerQuantityTable"
		button.text = "Compare quantities" if TranslationServer.get_locale().begins_with("en") else "수첩에서 양을 정리한다"
		button.custom_minimum_size.y = 58
		button.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
		button.pressed.connect(_open_cleaner_quantity_table)
		_modal_body.add_child(button)
		_cycle_modal_focus()


func _open_cleaner_quantity_table() -> void:
	if session == null or session.stage() != "C3":
		return
	var english := TranslationServer.get_locale().begins_with("en")
	_show_modal("Compare quantities" if english else "세정제 양 비교", "", [{"label": "Close" if english else "닫기", "action": _close_modal}])
	var scroll := _modal_body.get_child(2) as ScrollContainer
	scroll.custom_minimum_size.y = 180
	var label := scroll.get_child(0) as Label
	var ratio := CheckButton.new()
	ratio.name = "QuantityRatio"
	ratio.text = "A = 2 × S" if english else "원액 A = 안정제 S의 두 배"
	ratio.custom_minimum_size.y = 58
	ratio.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	var difference := CheckButton.new()
	difference.name = "QuantityWaterDifference"
	difference.text = "W = S + A + 2" if english else "물 W = 안정제 S + 원액 A + 2"
	difference.custom_minimum_size.y = 58
	difference.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	_modal_body.add_child(ratio)
	_modal_body.add_child(difference)
	var refresh := func(_pressed: bool = false):
		var table := preload("res://scripts/ui/cleaner_quantity_table.gd")
		label.text = table.describe(table.candidates(ratio.button_pressed, difference.button_pressed), TranslationServer.get_locale())
		scroll.scroll_vertical = 0
	ratio.toggled.connect(refresh)
	difference.toggled.connect(refresh)
	refresh.call()
	_cycle_modal_focus()


func _puzzle_hint_text(level: int) -> String:
	return preload("res://scripts/ui/mirror_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())


func _puzzle_hint_title() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if session.stage() == "C3":
		return "Cleaning solution hints" if english else "세정제 생각 정리"
	return "Black mirror hints" if english else "검은 거울 생각 정리"


func _update_objective() -> void:
	if session != null:
		_objective_label.text = MIRROR_TEXTS.objective(session.stage(), TranslationServer.get_locale())


func _display_feedback(text: String) -> String:
	var displayed := MIRROR_TEXTS.feedback(text, TranslationServer.get_locale())
	return super._display_feedback(text) if displayed == text else displayed


func _localized_notebook_entry(entry: String) -> String:
	var displayed := MIRROR_TEXTS.feedback(entry, TranslationServer.get_locale())
	return super._localized_notebook_entry(entry) if displayed == entry else displayed


func _mirror() -> BlackMirrorSession:
	return session as BlackMirrorSession


func _render_room() -> void:
	super._render_room()
	if session == null: return
	var local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	match _current_room:
		"M1_PARLOR":
			_action("MIRROR_DOOR", MIRROR_TEXTS.ui("mirror_door", locale), Rect2(340, 350, 770, 250), "move", "M1_MIRROR_GALLERY", false)
		"M1_SERVANT_COMMON":
			_action("TOOL_DOOR", MIRROR_TEXTS.ui("tool_door", locale), Rect2(300, 770, 570, 100), "move", "M1_TOOL_ROOM", false)
			_action("KITCHEN_DOOR", MIRROR_TEXTS.ui("kitchen_door", locale), Rect2(1030, 770, 570, 100), "move", "M1_KITCHEN", false)
		"M1_NORTH_ARCHIVE_HALL":
			_action("COLOR_DOOR", MIRROR_TEXTS.ui("color_door", locale), Rect2(420, 780, 850, 90), "move", "M1_COLOR_ROOM_ENTRY", false)
		"M1_TOOL_ROOM":
			_location_label.text = MIRROR_TEXTS.ui("location_tool", locale)
			_action("C2_RECORD", MIRROR_TEXTS.ui("cleaning_record", locale), Rect2(370, 270, 1120, 190), "c_read_cleaning")
			_board_label(MIRROR_TEXTS.ui("tool_room_board", locale), Rect2(370, 500, 1120, 170))
			_replace_back("M1_SERVANT_COMMON", MIRROR_TEXTS.ui("back_common", locale))
		"M1_KITCHEN":
			_location_label.text = MIRROR_TEXTS.ui("location_kitchen", locale)
			_build_chemical_bench(local)
			_replace_back("M1_SERVANT_COMMON", MIRROR_TEXTS.ui("back_common", locale))
		"M1_MIRROR_GALLERY":
			_location_label.text = MIRROR_TEXTS.ui("location_mirror", locale)
			_build_black_mirror(local)
			_replace_back("M1_PARLOR", MIRROR_TEXTS.ui("back_parlor", locale))
		"M1_COLOR_ROOM_ENTRY":
			_location_label.text = MIRROR_TEXTS.ui("location_color", locale)
			_board_label(MIRROR_TEXTS.ui("color_open" if session.known("color_room_entry_inspectable") else "color_closed", locale), Rect2(390, 350, 1120, 250))
			_replace_back("M1_NORTH_ARCHIVE_HALL", MIRROR_TEXTS.ui("back_north", locale))
	call_deferred("_restore_world_focus")


func _replace_back(destination: String, label: String) -> void:
	var old := _hotspot_layer.get_node_or_null("BACK")
	if old != null:
		_hotspot_layer.remove_child(old)
		old.queue_free()
	_action("BACK", label, Rect2(700, 944, 400, 72), "move", destination, false)


func _build_loop_bedroom(local: Dictionary) -> void:
	super._build_loop_bedroom(local)
	if _mirror().can_prepare_mirror_shortcut():
		_action("CSHORT", MIRROR_TEXTS.ui("shortcut", TranslationServer.get_locale()), Rect2(340, 755, 1000, 90), "c_shortcut")


func _build_great_clock(_local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	_board_label(MIRROR_TEXTS.ui("bell_board", locale), Rect2(330, 300, 1250, 200))
	_action("C_BELL_REPLAY", MIRROR_TEXTS.ui("bell_replay", locale), Rect2(440, 600, 1030, 130), "c_bell")


func _build_chemical_bench(local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	_action("C21_LABELS", MIRROR_TEXTS.ui("chemical_record", locale), Rect2(240, 150, 720, 80), "c_read_chemicals")
	_action("C_PREPARE", MIRROR_TEXTS.ui("prepare", locale), Rect2(1050, 150, 600, 80), "c_prepare")
	var mix: Dictionary = local["mixture"]
	_board_label(MIRROR_TEXTS.mixture_status(mix, locale), Rect2(310, 290, 1310, 140))
	for index in range(3):
		var material: String = MIRROR_RULES.MATERIALS[index]
		_action("POUR_" + material, ("Pour 1 unit of " if MIRROR_TEXTS.is_english(locale) else "") + MIRROR_TEXTS.material_name(material, locale) + ("" if MIRROR_TEXTS.is_english(locale) else " 1단위 붓기"), Rect2(270 + index * 490, 475, 430, 85), "c_pour", material, false)
	var actions := ["c_disperse", "c_mix", "c_settle", "c_test", "c_discard"]
	var labels := ["disperse", "mix", "settle", "test", "discard"]
	for index in range(actions.size()):
		_action(actions[index], MIRROR_TEXTS.ui(labels[index], locale), Rect2(250 + (index % 3) * 510, 620 + (index / 3) * 115, 450, 85), actions[index])
	if local["cleaner_ready"]:
		_board_label(MIRROR_TEXTS.ui("cleaner_ready", locale) + " · " + MIRROR_TEXTS.ui("cleaner_mirror" if local["signal_ready"] else "cleaner_clock", locale), Rect2(750, 850, 820, 62))


func _build_black_mirror(local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	if not session.known("c0_mirror_seen"):
		_action("C0", MIRROR_TEXTS.ui("observe", locale), Rect2(470, 300, 1000, 280), "c_observe")
		return
	if not session.known("c1_cleaning_hypothesis"):
		_action("C1", MIRROR_TEXTS.ui("hypothesis", locale), Rect2(470, 300, 1000, 280), "c_hypothesis")
		return
	if local["locked"]:
		_board_label(MIRROR_TEXTS.ui("locked_board", locale), Rect2(430, 340, 1070, 240))
		return
	if session.known("mirror_tracing_acquired"):
		if not local["surface_open"]:
			_location_label.text = MIRROR_TEXTS.ui("location_copy", locale)
		for index in range(5):
			var owner: String = MIRROR_SESSION.CHANNELS.keys()[index]
			var text: String = MIRROR_TEXTS.channel(owner, locale)
			_action("SCAN_" + owner, text + (MIRROR_TEXTS.ui("scan_done", locale) if owner in local["channels_scanned"] else ""), Rect2(230 + (index % 2) * 780, 170 + (index / 2) * 170, 720, 130), "c_scan", owner)
		_action("C5_INFO", MIRROR_TEXTS.ui("record_channels", locale), Rect2(420, 750, 1110, 115), "c_record")
		return
	_board_label(MIRROR_TEXTS.trace_status(local, locale), Rect2(170, 140, 1580, 120))
	var transforms := ["c_rotate", "c_flip", "c_anchor", "c_clear_plan"]
	var transform_labels := ["rotate", "flip", "anchor", "clear_plan"]
	for index in range(4):
		_action(transforms[index], MIRROR_TEXTS.ui(transform_labels[index], locale), Rect2(180 + index * 430, 295, 380, 75), transforms[index], null, false)
	for index in range(5):
		var segment: String = MIRROR_RULES.SEGMENTS[index]
		_action("SEG_" + segment, MIRROR_TEXTS.segment_name(segment, locale), Rect2(200 + (index % 3) * 530, 420 + (index / 3) * 100, 470, 78), "c_segment", segment, false)
	_add_hotspot("TRACE_COMPARE", MIRROR_TEXTS.ui("trace_compare", locale), Rect2(1260, 520, 470, 78), _open_trace_overlay)
	_action("C_DRY", MIRROR_TEXTS.ui("dry", locale), Rect2(220, 665, 500, 85), "c_dry")
	_action("C_VERIFY", MIRROR_TEXTS.ui("verify", locale), Rect2(770, 665, 430, 85), "c_verify_plan")
	_add_hotspot("C_WET", MIRROR_TEXTS.ui("wet", locale), Rect2(1250, 665, 480, 85), _confirm_wet_trace)
	_add_hotspot("C_PATROL", MIRROR_TEXTS.ui("patrol", locale), Rect2(540, 810, 830, 80), _open_patrol)


func _open_trace_overlay() -> void:
	var local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	_show_modal(MIRROR_TEXTS.ui("overlay_title", locale), MIRROR_TEXTS.ui("overlay_body", locale), [{"label": MIRROR_TEXTS.ui("overlay_back", locale), "action": _close_modal}])
	var diagram := OVERLAY_DIAGRAM.new()
	diagram.turn_degrees = local["rotation"]
	diagram.mirrored = local["flipped"]
	diagram.fixed_anchor = local["anchored"]
	_modal_body.add_child(diagram)
	_modal_body.move_child(diagram, 3)


func _open_patrol() -> void:
	var locale := TranslationServer.get_locale()
	_show_modal(MIRROR_TEXTS.ui("patrol_title", locale), MIRROR_TEXTS.ui("patrol_body", locale), [
		{"label": MIRROR_TEXTS.ui("patrol_wait", locale), "action": _modal_act.bind("c_handle_patrol", "wait")},
		{"label": MIRROR_TEXTS.ui("patrol_question", locale), "action": _modal_act.bind("c_handle_patrol", "question")},
		{"label": MIRROR_TEXTS.ui("patrol_cloth", locale), "action": _modal_act.bind("c_handle_patrol", "cloth")},
	])


func _confirm_wet_trace() -> void:
	var locale := TranslationServer.get_locale()
	_show_modal(MIRROR_TEXTS.ui("wet_title", locale), MIRROR_TEXTS.ui("wet_body", locale), [
		{"label": MIRROR_TEXTS.ui("wet_review", locale), "action": _close_modal},
		{"label": MIRROR_TEXTS.ui("wet_dry", locale), "action": _modal_act.bind("c_dry", null)},
		{"label": MIRROR_TEXTS.ui("wet_execute", locale), "action": _modal_act.bind("c_wet", true)},
	])


func _build_inner(local: Dictionary, journal: int) -> void:
	if not session.known("c5_info_complete") or journal >= 3:
		super._build_inner(local, journal)
		return
	var mirror_local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	_action("J3_OVERLAY", MIRROR_TEXTS.ui("j3_overlay", locale), Rect2(230, 145, 1460, 100), "j3_overlay")
	for index in range(4):
		var part: int = [2, 0, 3, 1][index]
		_action("J3_PART_%d" % part, MIRROR_TEXTS.j3_part(part, locale), Rect2(170 + (index % 2) * 860, 315 + (index / 2) * 190, 790, 155), "j3_piece", part, false)
	var order: Array[String] = []
	for part in mirror_local["j3_order"]: order.append(MIRROR_TEXTS.j3_part(part, locale).split("\n")[0])
	_board_label((" -> " if MIRROR_TEXTS.is_english(locale) else " → ").join(order), Rect2(240, 700, 1430, 95))
	_action("J3_CLEAR", MIRROR_TEXTS.ui("j3_clear", locale), Rect2(300, 825, 610, 80), "j3_clear", null, false)
	_action("J3_RESTORE", MIRROR_TEXTS.ui("j3_restore", locale), Rect2(1020, 825, 610, 80), "j3_restore")
