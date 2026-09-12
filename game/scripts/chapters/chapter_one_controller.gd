class_name ChapterOneController
extends PrologueController

const SESSION_SCRIPT := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const CHAPTER_NAMES := {"M2_BEDROOM": "주인공의 침실", "M1_CENTRAL_HALL": "중앙홀", "M1_SERVANT_COMMON": "사용인 공용실", "M1_PARLOR": "대응접실", "M1_LIBRARY_OUTER": "외부 서고", "M1_LIBRARY_INNER": "기록 내실", "M1_GREAT_CLOCK": "서쪽 대시계", "M1_NORTH_ARCHIVE_HALL": "북쪽 기록 회랑"}
const OBJECTIVES := {"A1": "수첩에 다음 아침과 비교할 표식을 남긴다", "AS": "익숙한 일과를 마치고 침실에서 잠든다", "A2": "다음 아침의 수첩 표식을 확인한다", "B1": "사용인 공용실의 문서 두 장 이상으로 빈 시간대를 추론한다", "B2": "일과를 마치고 외부 서고를 통해 기록 내실에 접근한다", "J1": "책상의 압지 조각을 배열해 첫 페이지를 복원한다", "B3_A": "네 방의 시계 탁본을 모아 배선을 연결한다", "B3_B": "역할과 전달 시점을 설정해 시계망을 작동한다", "BF": "남은 조사 후 침실에서 잠든다 · 실패 정보는 남는다", "B4": "공명통에 남은 파형을 수첩에 기록한다", "B5": "기록 내실에서 파형과 두 번째 페이지를 겹친다", "J2_COMPLETE": "첫 장의 기록을 확인한다 · 다음은 검은 거울"}

var session: ChapterOneSession
var _swap_from := -1
var _edgar_timer: Timer
var _rendering := false
var _world_focus := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_apply_accessibility_profile()
	_edgar_timer = Timer.new()
	_edgar_timer.one_shot = true
	_edgar_timer.wait_time = 6.0
	_edgar_timer.timeout.connect(_on_edgar_timeout)
	add_child(_edgar_timer)
	session = _make_session()
	var result := session.initialize()
	_render_room()
	_feedback(result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_edgar_timer):
		_edgar_timer.paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(_edgar_timer):
		_edgar_timer.paused = false


func _make_session() -> ChapterOneSession:
	return SESSION_SCRIPT.new(GameState, SaveManager, _slot_id)


func _save_progress(_save_point_id: String = "SAVE_NEW_GAME", _prologue_complete: bool = false) -> bool:
	# Chapter actions are persisted by ChapterOneSession before this view refreshes.
	return true


func _enter_room(room_id: String) -> void:
	_do("move", room_id)


func _rebuild_current_room_content() -> void:
	_render_room()


func _remember_world_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _hotspot_layer.is_ancestor_of(focused):
		_world_focus = String(focused.name)


func _restore_world_focus() -> void:
	if _interaction_blocked() or not is_inside_tree():
		return
	var target := _hotspot_layer.get_node_or_null(NodePath(_world_focus)) as Control if not _world_focus.is_empty() else null
	if target != null and target.is_visible_in_tree() and target.focus_mode == Control.FOCUS_ALL:
		target.grab_focus()
		return
	for child in _hotspot_layer.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			child.grab_focus()
			return


func _show_dialogue(lines: Array, after: Callable = Callable()) -> void:
	_remember_world_focus()
	super._show_dialogue(lines, after)


func _advance_dialogue() -> void:
	super._advance_dialogue()
	if not _dialogue_active:
		call_deferred("_restore_world_focus")
		if session != null and session.stage() in ["J2_COMPLETE", "J3_COMPLETE"]:
			campaign_requested.emit(_slot_id)


func _show_modal(title: String, body: String, actions: Array) -> void:
	_remember_world_focus()
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()
	super._show_modal(title, body, actions)


func _close_modal() -> void:
	super._close_modal()
	call_deferred("_restore_world_focus")


func _update_objective() -> void:
	if session != null:
		_objective_label.text = OBJECTIVES.get(session.stage(), "수첩을 확인한다")


func _do(action: String, value: Variant = null, show_text: bool = true) -> void:
	if _interaction_blocked():
		return
	var result := session.act(action, value)
	_render_room()
	if show_text:
		_feedback(result)
	elif not result.get("ok", false):
		_set_status(result.get("text", str(result.get("error_ids", []))))


func _feedback(result: Dictionary) -> void:
	var text := String(result.get("text", ""))
	if text.is_empty():
		if not result.get("ok", false):
			_set_status("저장 오류: " + str(result.get("error_ids", [])))
		return
	if not result.get("ok", false):
		_set_status(text)
		return
	var speaker := String(result.get("speaker", "주인공"))
	var lines: Array = []
	for paragraph in text.split("\n"):
		if not paragraph.is_empty():
			lines.append({"speaker": speaker, "portrait": "EDGAR" if speaker == "에드가" else "", "text": paragraph})
	_show_dialogue(lines)


func _render_room() -> void:
	if _rendering or session == null:
		return
	_rendering = true
	_remember_world_focus()
	var state := session.snapshot()
	if _current_room != state["loop_state"]["location_id"]:
		_swap_from = -1
		_world_focus = ""
	_current_room = state["loop_state"]["location_id"]
	var local := session.local_state(state)
	_progress = {"notebook_entries": [], "P1_complete": true}
	_update_inventory([])
	_inventory_panel.visible = false
	_clear_hotspots()
	var background_id := _current_room
	if _current_room in ["M1_LIBRARY_INNER", "M1_SERVANT_COMMON"]:
		background_id = "M1_LIBRARY_OUTER" if _current_room == "M1_LIBRARY_INNER" else "M1_KITCHEN"
	_set_room_background(background_id)
	_room_art.set_room(background_id, {})
	_location_label.text = "%s · %d번째 아침 이후" % [CHAPTER_NAMES.get(_current_room, _current_room), int(state["loop_state"]["day_index"]) + 1]
	_update_objective()
	if _current_room == "M1_LIBRARY_INNER" and local["edgar_state"] != "absent":
		_build_edgar_pressure(local)
		_rendering = false
		call_deferred("_restore_world_focus")
		return
	match _current_room:
		"M2_BEDROOM":
			_build_loop_bedroom(local)
		"M1_CENTRAL_HALL":
			var destinations := ["M1_SERVANT_COMMON", "M1_PARLOR", "M1_LIBRARY_OUTER", "M1_GREAT_CLOCK", "M1_NORTH_ARCHIVE_HALL", "M2_BEDROOM"]
			for index in range(destinations.size()):
				_action("GO_" + destinations[index], CHAPTER_NAMES[destinations[index]], Rect2(240 + (index % 3) * 490, 230 + (index / 3) * 210, 410, 140), "move", destinations[index], false)
		"M1_SERVANT_COMMON":
			for index in range(4):
				var owner: String = ["edgar", "luca", "mara1", "mara2"][index]
				var label: String = ["에드가 업무 장부", "루카 전달표", "마라 1 청소표", "마라 2 기록 반출표 (선택)"][index]
				if session.known("schedule_" + owner):
					label += " · 읽음"
				_action("DOC_" + owner, label, Rect2(260 + (index % 2) * 720, 210 + (index / 2) * 165, 640, 115), "read_schedule", owner)
			_add_hotspot("B1_BOARD", "문서의 시간 표현을 연결한다", Rect2(610, 610, 650, 110), _open_schedule_board)
		"M1_LIBRARY_OUTER":
			_action("INNER_DOOR", "기록 내실문", Rect2(1180, 230, 350, 390), "move", "M1_LIBRARY_INNER", false)
			_clock_hotspot()
		"M1_LIBRARY_INNER":
			_build_inner(local, int(state["meta_progress"]["journal_stage"]))
		"M1_PARLOR":
			_clock_hotspot()
		"M1_GREAT_CLOCK":
			_build_great_clock(local)
		"M1_NORTH_ARCHIVE_HALL":
			_action("NORTH_LINK", "서재 연결문\n" + ("구조를 기억한다" if session.known("north_library_shortcut") else "안쪽 걸쇠 잠김"), Rect2(580, 250, 700, 260), "move", "M1_LIBRARY_INNER", false)
			_add_hotspot("MARA2_MEMORY", "마라 2에게 이름표를 묻는다", Rect2(600, 570, 600, 110), _show_dialogue.bind([{"speaker": "마라 2", "portrait": "MARA2", "text": "어제도 고쳤잖아! 이름표가 돌아왔다고 내가 잊어버린 건 아니거든!"}]))
	if _current_room == "M1_LIBRARY_INNER":
		_action("BACK", "외부 서고로", Rect2(700, 944, 400, 72), "move", "M1_LIBRARY_OUTER", false)
	elif _current_room != "M1_CENTRAL_HALL":
		_action("BACK", "중앙홀로", Rect2(700, 944, 400, 72), "move", "M1_CENTRAL_HALL", false)
	_rendering = false
	call_deferred("_restore_world_focus")


func _action(id: String, label: String, rect: Rect2, action: String, value: Variant = null, show_text: bool = true) -> void:
	_add_hotspot(id, label, rect, _do.bind(action, value, show_text))


func _build_loop_bedroom(local: Dictionary) -> void:
	if session.stage() == "A1":
		_add_hotspot("A1_MARK", "수첩의 빈 페이지에 표식을 남긴다", Rect2(510, 320, 830, 160), _open_mark_choices)
	elif session.stage() == "A2":
		_action("A2_CONFIRM", "수첩 표식과 방의 흔적을 비교한다", Rect2(510, 320, 830, 160), "confirm_mark")
	else:
		_add_hotspot("NOTEBOOK", "수첩의 기록", Rect2(350, 240, 470, 100), _open_notebook)
	_action("AS_ROUTINE", "익숙한 순서대로 일과를 마친다" + (" · 완료" if local["routine_done"] else ""), Rect2(350, 550, 650, 100), "routine")
	_add_hotspot("SLEEP", "침대 · 잠든다", Rect2(1090, 580, 510, 140), _confirm_sleep)
	if int(session.snapshot()["meta_progress"]["journal_stage"]) < 2 and session.snapshot()["meta_progress"]["failure_knowledge"].has("B3_B") and not local["clock_locked"]:
		_action("BSHORT", "수첩의 검증 정보로 준비를 축약한다", Rect2(360, 730, 880, 100), "shortcut")
	_clock_hotspot()


func _open_mark_choices() -> void:
	var actions: Array = []
	for id in SESSION_SCRIPT.MARKS:
		actions.append({"label": _dialogue_ui_text("CH1_MARK_" + String(id).to_upper()), "action": _modal_act.bind("mark", id)})
	_show_modal(_dialogue_ui_text("CH1_MARK_TITLE"), _dialogue_ui_text("CH1_MARK_PROMPT"), actions)


func _open_schedule_board() -> void:
	_show_modal("기록 내실이 비는 구간", "읽은 문서에서 에드가의 위치와 복도 작업의 끝을 비교한다.", [
		{"label": "아침부터 오후 차 전", "action": _modal_act.bind("schedule_window", "morning")},
		{"label": "오후 차 회수 뒤부터 저녁 종 전", "action": _modal_act.bind("schedule_window", "after_tea_before_bell")},
		{"label": "저녁 종 뒤", "action": _modal_act.bind("schedule_window", "after_bell")},
	])


func _modal_act(action: String, value: Variant = null) -> void:
	_close_modal()
	_do(action, value)


func _confirm_sleep() -> void:
	_show_modal(_dialogue_ui_text("CH1_SLEEP_TITLE"), _dialogue_ui_text("CH1_SLEEP_RULE"), [
		{"label": _dialogue_ui_text("P6_CANCEL"), "action": _close_modal},
		{"label": _dialogue_ui_text("P6_SLEEP"), "action": _sleep_now},
	])


func _sleep_now() -> void:
	_close_modal()
	var result := session.sleep()
	_render_room()
	_feedback(result)


func _build_inner(local: Dictionary, journal: int) -> void:
	var ids := ["desk", "index", "drawer", "alcove", "gap", "link"]
	var labels := ["일지 책상", "색인함", "작은 서랍", "점검 벽감 · 숨을 공간", "일지의 마지막 여백", "초상화 뒤 연결문 걸쇠"]
	for index in range(ids.size()):
		_action("INNER_" + ids[index], labels[index], Rect2(150 + (index % 3) * 540, 145 + (index / 3) * 94, 485, 70), "inspect_inner", ids[index])
	if journal == 0 and "desk" in local["inspected"]:
		for index in range(3):
			var fragment_id: int = [2, 0, 1][index]
			var fragment := String(SESSION_SCRIPT.J1_FRAGMENTS[fragment_id])
			var face := "앞면 · 홈이 읽힘" if bool(local["j1_front"][fragment_id]) else "뒷면 · 번진 잉크"
			_action("J1_PIECE_%d" % fragment_id, fragment + "\n" + face, Rect2(130 + index * 565, 368, 535, 200), "j1_piece", fragment_id, false)
			_action("J1_FLIP_%d" % fragment_id, "앞뒤 뒤집기", Rect2(160 + index * 565, 580, 470, 56), "j1_flip", fragment_id, false)
		var order: Array[String] = []
		for id in local["j1_order"]:
			order.append(String(SESSION_SCRIPT.J1_FRAGMENTS[int(id)]).split("\n")[0])
		_board_label("선택한 순서: " + " → ".join(order), Rect2(170, 660, 1550, 70))
		_action("J1_CLEAR", "배열 다시 놓기", Rect2(450, 768, 450, 75), "j1_clear", null, false)
		_action("J1_RESTORE", "눌림선과 문장 확인", Rect2(990, 768, 450, 75), "j1_restore")
	elif session.known("b4_waveform_acquired") and journal < 2:
		_board_label("페이지: 긴 홈이 위에서 시작 → 두 문장으로 갈라짐 → 바깥 문단을 감쌈\n투명지 시작점: " + _direction(int(local["wave_rotation"])), Rect2(260, 390, 1370, 190))
		_action("B5_ROTATE", "투명지 90° 회전", Rect2(300, 650, 580, 95), "wave_rotate", null, false)
		_action("J2_RESTORE", "세 눌림 구간 대조", Rect2(990, 650, 580, 95), "restore_j2")
	else:
		_add_hotspot("JOURNAL_READ", "복원된 일지 다시 읽기", Rect2(440, 520, 950, 150), _open_notebook)


func _build_edgar_pressure(local: Dictionary) -> void:
	if local["edgar_state"] == "hidden":
		_board_label("점검 벽감 안\n에드가가 책상을 확인하고 있다. 잠시 뒤 발소리가 멀어진다.", Rect2(390, 330, 1080, 230))
		if _edgar_timer.is_stopped():
			_edgar_timer.start()
		return
	_board_label("문밖의 발소리가 멎는다. 잠금쇠가 돌아간다.", Rect2(400, 250, 1120, 160))
	if "alcove" in local["inspected"]:
		_action("B2_HIDE", "점검 벽감에 숨는다", Rect2(380, 490, 540, 140), "edgar_hide")
	_action("B2_CAUGHT", "남아서 에드가에게 말을 건다", Rect2(1000, 490, 540, 140), "edgar_talk")


func _on_edgar_timeout() -> void:
	if session.local_state()["edgar_state"] != "hidden":
		return
	if _dialogue_active or _modal_active:
		_edgar_timer.start(1.0)
		return
	_do("edgar_leave")


func _clock_hotspot() -> void:
	if int(session.snapshot()["meta_progress"]["journal_stage"]) < 1:
		return
	var room_clock: String = SESSION_SCRIPT.CLOCK_ROOMS.get(_current_room, "")
	if not room_clock.is_empty():
		_action("RUB_CLOCK", "시계 배선 조사 · 탁본 뜨기", Rect2(1080, 150, 550, 140), "rub_clock")


func _build_great_clock(local: Dictionary) -> void:
	if local["clock_locked"]:
		_board_label("봉인핀 파손 · 오늘 시계망 잠김\n잠들면 핀은 원래대로 돌아온다. 수첩의 실패 기록은 남는다.", Rect2(300, 340, 1290, 230))
		return
	if local["signal_generated"] or session.known("b4_waveform_acquired"):
		_action("B4_RECORD", "공명통의 세 파형을 투명지에 기록", Rect2(440, 330, 1030, 220), "record_wave")
		return
	if local["rubbed"].size() < 4:
		_clock_hotspot()
		_board_label("당일 탁본: %d / 4\n침실 · 대응접실 · 외부 서고 · 서쪽 대시계\n각 방에서 시계를 직접 조사한다." % local["rubbed"].size(), Rect2(350, 370, 1220, 250))
		return
	if not session.known("clock_network_layout_solved"):
		_build_layout_board(local)
	else:
		_build_roles_board(local)


func _build_layout_board(local: Dictionary) -> void:
	var board: Dictionary = local["board"]
	_board_label("탁본 조립: 위쪽 모서리 홈을 맞춘 뒤 [시작 → 통과 → 공명통]으로 연결한다. 단절된 조각은 네 번째 칸.\n조각을 눌러 두 자리를 교환한다. 나사·문양과 방 이름은 색 없이도 읽을 수 있다.", Rect2(150, 145, 1620, 105))
	for index in range(4):
		var clock_id: String = board["pieces"][index]
		var back: bool = clock_id == "library_outer" and board["library_back"]
		var pattern: String = {"bedroom": "중앙에서 끊긴 선", "parlor": "굵은 시작선 →", "library_outer": "← 중계선" if back else "중계선 →", "great_clock": "선 → 빈 공명통"}[clock_id]
		var label := "%d번 자리 · %s\n모서리 홈: %s\n%s\n%s" % [index + 1, CLOCK.NAMES[clock_id], _direction(int(board["rotations"][index])), pattern, "뒷면" if back else "앞면"]
		_add_hotspot("B3_PIECE_%d" % index, label, Rect2(135 + index * 445, 320, 405, 245), _swap_piece.bind(index))
		_action("B3_ROTATE_%d" % index, "90° 회전", Rect2(155 + index * 445, 585, 365, 65), "board_rotate", index, false)
	_action("B3_FLIP", "외부 서고 탁본 뒤집기", Rect2(220, 706, 570, 90), "board_flip", null, false)
	_action("B3_CHECK", "약한 진동으로 배선 추적", Rect2(1020, 706, 630, 90), "board_check")


func _swap_piece(index: int) -> void:
	if _interaction_blocked():
		return
	if _swap_from < 0:
		_swap_from = index
		_set_status("%d번 조각 선택 · 교환할 다른 자리를 누른다." % (index + 1))
		return
	var from := _swap_from
	_swap_from = -1
	_do("board_swap", [from, index], false)


func _build_roles_board(local: Dictionary) -> void:
	_board_label("배치와 역할은 별도 설정이다. 약한 시험은 배선만 확인하며 전달 시점은 확인하지 않는다.", Rect2(180, 145, 1570, 80))
	for index in range(4):
		var role: String = CLOCK.ROLES[index]
		var selected: String = local["roles"].get(role, "")
		var button := OptionButton.new()
		button.name = "ROLE_" + role
		button.add_item(CLOCK.ROLE_NAMES[role] + " · 시계 선택", 0)
		for clock_id in CLOCK.CLOCKS:
			button.add_item(CLOCK.ROLE_NAMES[role] + " · " + CLOCK.NAMES[clock_id])
		button.select(CLOCK.CLOCKS.find(selected) + 1)
		button.add_theme_font_size_override("font_size", 22)
		_place(button, Rect2(180 + index * 430, 325, 385, 105))
		button.item_selected.connect(_role_selected.bind(role))
		_hotspot_layer.add_child(button)
	var names := ["-1 · 마지막 종 전", "0 · 열두 번째 종과 동시", "+1 · 정상 종 뒤 한 칸", "HALF · 종 사이"]
	for index in range(4):
		var phase: String = CLOCK.PHASES[index]
		_action("PHASE_%d" % index, names[index] + (" · 선택" if local["phase"] == phase else ""), Rect2(180 + index * 430, 480, 385, 112), "phase", phase, false)
	_action("B3_TEST", "약한 시험 진동", Rect2(380, 700, 490, 100), "test_clock")
	_add_hotspot("B3_ACTIVATE", "저녁 시계망 실제 작동", Rect2(1020, 700, 530, 100), _confirm_clock)


func _role_selected(index: int, role: String) -> void:
	if index > 0:
		_do("role", [role, CLOCK.CLOCKS[index - 1]], false)


func _confirm_clock() -> void:
	_show_modal("봉인핀 확인", "오류가 있으면 봉인핀이 꺾여 오늘 다시 시도할 수 없다. 잠든 뒤 같은 아침에서 다시 준비한다.", [
		{"label": "약한 시험 진동을 다시 보낸다", "action": _modal_act.bind("test_clock", null)},
		{"label": "현재 설정으로 작동한다", "action": _modal_act.bind("activate_clock", true)},
		{"label": "설정을 고친다", "action": _close_modal},
	])


func _direction(degrees: int) -> String:
	return {0: "위 ↑", 90: "오른쪽 →", 180: "아래 ↓", 270: "왼쪽 ←"}.get(degrees, "?")


func _board_label(text: String, rect: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.018, 0.045, 0.94), Color(0.60, 0.40, 0.30), 2, 6))
	_place(panel, rect)
	_hotspot_layer.add_child(panel)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)


func _open_notebook() -> void:
	if _interaction_blocked():
		return
	var knowledge: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"]
	var notes: Dictionary = knowledge.get("chapter_notebook", {})
	_show_modal(_dialogue_ui_text("UI_NOTE_PERMANENT"), _dialogue_ui_text("UI_NOTE_PERSIST"), [{"label": _dialogue_ui_text("UI_NOTE_CLOSE"), "action": _close_modal}])
	var scroll := _modal_body.get_child(2) as ScrollContainer
	scroll.custom_minimum_size = Vector2(0, 430)
	var label := scroll.get_child(0) as Label
	var pages: Array[String] = []
	for entry in knowledge.get("prologue_notebook_entries", []):
		pages.append(_localized_notebook_entry(String(entry)))
	if pages.is_empty() and knowledge.get("MEM_FATHER_TEA_HAND_FRAGMENT", "") == "sensory_fragment":
		pages.append(_dialogue_ui_text("NOTE_P_TEA"))
	for key in notes:
		pages.append(String(notes[key]))
	label.text = "\n\n".join(pages) if not pages.is_empty() else _dialogue_ui_text("UI_NOTE_COMPARE_EMPTY")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(round(22 * _reading_text_scale)))
