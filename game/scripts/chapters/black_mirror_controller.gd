class_name BlackMirrorController
extends ChapterOneController

const MIRROR_SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const MIRROR_RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const OVERLAY_DIAGRAM := preload("res://scripts/chapters/mirror_overlay_diagram.gd")
const MIRROR_OBJECTIVES := {"C_SLEEP": "일지를 기억한 채 잠든다", "C0": "대응접실 남쪽 거울 회랑의 검은 거울을 확인한다", "C1": "거울의 코팅과 일지의 신호를 연결한다", "C2": "청소도구실 기록과 주방 약품 라벨을 비교한다", "C3": "주방에서 직접 계량·혼합하고 시험지로 검증한다", "C_BELL": "대시계에서 검증한 열세 번째 신호를 다시 보낸다", "C4": "거울에서 중첩과 경로를 시험한 뒤 실제로 닦는다", "CF": "당일 거울 잠김 · 같은 침실에서 잠든다", "C5_INFO": "다섯 채널을 대조해 회로 투명지를 기록한다", "J3": "기록 내실에서 탁본과 일지 문장을 비교한다", "J3_COMPLETE": "지하의 기준점을 기억한다 · 다음은 저택의 심장"}

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
		_cycle_support_focus()


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
	_cycle_support_focus()


func _puzzle_hint_text(level: int) -> String:
	return preload("res://scripts/ui/mirror_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())


func _puzzle_hint_title() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if session.stage() == "C3":
		return "Cleaning solution hints" if english else "세정제 생각 정리"
	return "Black mirror hints" if english else "검은 거울 생각 정리"


func _update_objective() -> void:
	if session != null:
		_objective_label.text = "J2를 기억한 채 잠들어 다음 아침을 맞는다" if session.stage() == "C_SLEEP" else MIRROR_OBJECTIVES.get(session.stage(), "기록을 확인한다")


func _mirror() -> BlackMirrorSession:
	return session as BlackMirrorSession


func _render_room() -> void:
	super._render_room()
	if session == null: return
	var local := _mirror().mirror_local()
	match _current_room:
		"M1_PARLOR":
			_action("MIRROR_DOOR", "남쪽 거울 회랑", Rect2(340, 350, 770, 250), "move", "M1_MIRROR_GALLERY", false)
		"M1_SERVANT_COMMON":
			_action("TOOL_DOOR", "청소도구실", Rect2(300, 770, 570, 100), "move", "M1_TOOL_ROOM", false)
			_action("KITCHEN_DOOR", "주방 조합대", Rect2(1030, 770, 570, 100), "move", "M1_KITCHEN", false)
		"M1_NORTH_ARCHIVE_HALL":
			_action("COLOR_DOOR", "색분해실 외부", Rect2(420, 780, 850, 90), "move", "M1_COLOR_ROOM_ENTRY", false)
		"M1_TOOL_ROOM":
			_location_label.text = "청소도구실"
			_action("C2_RECORD", "마라 1의 청소 기록", Rect2(370, 270, 1120, 190), "c_read_cleaning")
			_board_label("기록은 사용인이 자리를 비워도 읽을 수 있다.\n눈금병과 부드러운 천, 고정 공구가 가지런히 놓여 있다.", Rect2(370, 500, 1120, 170))
			_replace_back("M1_SERVANT_COMMON", "사용인 공용실로")
		"M1_KITCHEN":
			_location_label.text = "주방 · 세정제 조합대"
			_build_chemical_bench(local)
			_replace_back("M1_SERVANT_COMMON", "사용인 공용실로")
		"M1_MIRROR_GALLERY":
			_location_label.text = "대응접실 남쪽 · 거울 회랑"
			_build_black_mirror(local)
			_replace_back("M1_PARLOR", "대응접실로")
		"M1_COLOR_ROOM_ENTRY":
			_location_label.text = "색분해실 외부"
			_board_label("외부 렌즈에 다섯 문양이 겹친다. 내부 기능은 아직 열리지 않았다." if session.known("color_room_entry_inspectable") else "장식처럼 보이는 렌즈와 필터판. 아직 기능을 알 수 없다.", Rect2(390, 350, 1120, 250))
			_replace_back("M1_NORTH_ARCHIVE_HALL", "북쪽 기록 회랑으로")
	call_deferred("_restore_world_focus")


func _replace_back(destination: String, label: String) -> void:
	var old := _hotspot_layer.get_node_or_null("BACK")
	if old != null:
		_hotspot_layer.remove_child(old)
		old.queue_free()
	_action("BACK", label, Rect2(700, 944, 400, 72), "move", destination, false)


func _build_loop_bedroom(local: Dictionary) -> void:
	super._build_loop_bedroom(local)
	if session.snapshot()["meta_progress"]["failure_knowledge"].has("C4") and not _mirror().mirror_local()["locked"]:
		_action("CSHORT", "기록한 동선으로 재료만 다시 준비한다", Rect2(340, 755, 1000, 90), "c_shortcut")


func _build_great_clock(_local: Dictionary) -> void:
	_board_label("두 번째 일지가 말한 것은 열쇠가 아니라 표면을 잠시 느슨하게 만드는 신호다.\n수첩에 검증한 설정으로 신호를 다시 보낼 수 있다.", Rect2(330, 300, 1250, 200))
	_action("C_BELL_REPLAY", "검증한 시계망으로 열세 번째 종 재현", Rect2(440, 600, 1030, 130), "c_bell")


func _build_chemical_bench(local: Dictionary) -> void:
	_action("C21_LABELS", "약품 라벨·접힌 메모 조사", Rect2(240, 150, 720, 80), "c_read_chemicals")
	_action("C_PREPARE", "새 재료와 천 준비", Rect2(1050, 150, 600, 80), "c_prepare")
	var mix: Dictionary = local["mixture"]
	_board_label("8단위 병: 물 %d / 안정제 %d / 원액 %d\n확산: %s · 혼합: %d회 · %s" % [mix["water"], mix["stabilizer"], mix["active"], "완료" if mix["dispersed"] else "미확인", mix["mixed"], "거품 있음" if mix["foamy"] else "거품 없음"], Rect2(310, 290, 1310, 140))
	for index in range(3):
		var material: String = MIRROR_RULES.MATERIALS[index]
		_action("POUR_" + material, MIRROR_RULES.MATERIAL_NAMES[material] + " 1단위 붓기", Rect2(270 + index * 490, 475, 430, 85), "c_pour", material, false)
	var actions := ["c_disperse", "c_mix", "c_settle", "c_test", "c_discard"]
	var labels := ["안정제 확산 확인", "천천히 혼합", "거품 가라앉히기", "시험지로 검증", "폐기하고 병 헹구기"]
	for index in range(actions.size()):
		_action(actions[index], labels[index], Rect2(250 + (index % 3) * 510, 620 + (index / 3) * 115, 450, 85), actions[index])
	if local["cleaner_ready"]:
		_board_label("중성 세정제 확보 · " + ("거울 회랑에서 경로를 대조한다" if local["signal_ready"] else "다음 목적지는 서쪽 대시계"), Rect2(750, 850, 820, 62))


func _build_black_mirror(local: Dictionary) -> void:
	if not session.known("c0_mirror_seen"):
		_action("C0", "검은 거울 조사", Rect2(470, 300, 1000, 280), "c_observe")
		return
	if not session.known("c1_cleaning_hypothesis"):
		_action("C1", "일지의 신호와 코팅을 연결한다", Rect2(470, 300, 1000, 280), "c_hypothesis")
		return
	if local["locked"]:
		_board_label("당일 코팅 경화 또는 도구 회수\n기록은 남았다. 잠든 뒤 재료를 다시 준비할 수 있다.", Rect2(430, 340, 1070, 240))
		return
	if session.known("mirror_tracing_acquired"):
		if not local["surface_open"]:
			_location_label.text = "거울 회랑 · 수첩의 진단면 사본 검토"
		for index in range(5):
			var owner: String = MIRROR_SESSION.CHANNELS.keys()[index]
			var text: String = MIRROR_SESSION.CHANNELS[owner]
			_action("SCAN_" + owner, text + (" · 대조 완료" if owner in local["channels_scanned"] else ""), Rect2(230 + (index % 2) * 780, 170 + (index / 2) * 170, 720, 130), "c_scan", owner)
		_action("C5_INFO", "회로·기준점·다섯 채널을 수첩에 고정", Rect2(420, 750, 1110, 115), "c_record")
		return
	var names: Array[String] = []
	for segment in local["path"]: names.append(MIRROR_RULES.SEGMENT_NAMES[segment])
	_board_label("투명지 %d° · %s · 하단 기준점 %s\n계획: %s" % [local["rotation"], "반전" if local["flipped"] else "반전 없음", "고정" if local["anchored"] else "미고정", " → ".join(names)], Rect2(170, 140, 1580, 120))
	var transforms := ["c_rotate", "c_flip", "c_anchor", "c_clear_plan"]
	var transform_labels := ["90° 회전", "좌우 반전", "하단 큰 파동 고정", "경로 다시 놓기"]
	for index in range(4):
		_action(transforms[index], transform_labels[index], Rect2(180 + index * 430, 295, 380, 75), transforms[index], null, false)
	for index in range(5):
		var segment: String = MIRROR_RULES.SEGMENTS[index]
		_action("SEG_" + segment, MIRROR_RULES.SEGMENT_NAMES[segment], Rect2(200 + (index % 3) * 530, 420 + (index / 3) * 100, 470, 78), "c_segment", segment, false)
	_add_hotspot("TRACE_COMPARE", "거울 홈과 투명지 확대 대조", Rect2(1260, 520, 470, 78), _open_trace_overlay)
	_action("C_DRY", "마른 천으로 시험", Rect2(220, 665, 500, 85), "c_dry")
	_action("C_VERIFY", "시험한 계획 확정", Rect2(770, 665, 430, 85), "c_verify_plan")
	_add_hotspot("C_WET", "젖은 천으로 실행", Rect2(1250, 665, 480, 85), _confirm_wet_trace)
	_add_hotspot("C_PATROL", "에드가의 순찰 확인·대응", Rect2(540, 810, 830, 80), _open_patrol)


func _open_trace_overlay() -> void:
	var local := _mirror().mirror_local()
	_show_modal("거울 홈과 투명지", "굵은 실선·원: 거울 회로와 하단 진동점\n가는 점선·사각: 투명지 파형과 열세 번째 큰 파동\n두 기준과 비대칭 분기가 함께 맞는지 비교한다.", [{"label": "현재 배치로 돌아간다", "action": _close_modal}])
	var diagram := OVERLAY_DIAGRAM.new()
	diagram.turn_degrees = local["rotation"]
	diagram.mirrored = local["flipped"]
	diagram.fixed_anchor = local["anchored"]
	_modal_body.add_child(diagram)
	_modal_body.move_child(diagram, 3)


func _open_patrol() -> void:
	_show_modal("회랑의 발소리", "경계가 높으면 에드가가 젖은 천을 점검할 수 있다. 처리 방식은 정답 경로를 바꾸지 않는다.", [
		{"label": "순찰이 지나갈 때까지 기다린다", "action": _modal_act.bind("c_handle_patrol", "wait")},
		{"label": "일지 문장을 질문한다", "action": _modal_act.bind("c_handle_patrol", "question")},
		{"label": "일반 천을 앞에 둔다", "action": _modal_act.bind("c_handle_patrol", "cloth")},
	])


func _confirm_wet_trace() -> void:
	_show_modal("오늘은 되돌릴 수 없는 닦기", "세정제를 묻히면 오류가 있는 경로의 코팅이 굳을 수 있다. 에드가의 순찰도 확인해야 한다. 실패하면 같은 침실에서 잠든 뒤 재료를 다시 준비한다.", [
		{"label": "계획을 다시 확인한다", "action": _close_modal},
		{"label": "마른 천으로 시험한다", "action": _modal_act.bind("c_dry", null)},
		{"label": "세정제를 묻혀 실행한다", "action": _modal_act.bind("c_wet", true)},
	])


func _build_inner(local: Dictionary, journal: int) -> void:
	if not session.known("c5_info_complete") or journal >= 3:
		super._build_inner(local, journal)
		return
	var mirror_local := _mirror().mirror_local()
	_action("J3_OVERLAY", "C5 투명지를 빈 테두리에 놓고 세 기준점 비교", Rect2(230, 145, 1460, 100), "j3_overlay")
	for index in range(4):
		var part: int = [2, 0, 3, 1][index]
		_action("J3_PART_%d" % part, MIRROR_SESSION.J3_PARTS[part], Rect2(170 + (index % 2) * 860, 315 + (index / 2) * 190, 790, 155), "j3_piece", part, false)
	var order: Array[String] = []
	for part in mirror_local["j3_order"]: order.append(String(MIRROR_SESSION.J3_PARTS[part]).split("\n")[0])
	_board_label(" → ".join(order), Rect2(240, 700, 1430, 95))
	_action("J3_CLEAR", "문장 배열 다시 놓기", Rect2(300, 825, 610, 80), "j3_clear", null, false)
	_action("J3_RESTORE", "세 번째 페이지 복원", Rect2(1020, 825, 610, 80), "j3_restore")
