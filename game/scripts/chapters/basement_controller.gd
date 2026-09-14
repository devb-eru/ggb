class_name BasementController
extends BlackMirrorController

const BASEMENT_SESSION := preload("res://scripts/systems/basement_session.gd")
const BASEMENT_RULES := preload("res://data/puzzles/puzzle_basement.tres")
const ENDING_SIGNATURE := preload("res://scripts/ui/ending_signature.gd")
const ENDING_TEXTS := preload("res://scripts/ui/ending_decision_texts.gd")
const FIELD_TEXTS := preload("res://scripts/ui/field_notebook_texts.gd")
const STAY_TEXTS := preload("res://scripts/ui/stay_charter_texts.gd")
const STORY_TEXTS := preload("res://scripts/ui/stay_story_texts.gd")
const WAKE_TEXTS := preload("res://scripts/ui/reality_wake_texts.gd")
const SURFACE_TEXTS := preload("res://scripts/ui/reality_surface_texts.gd")
const CREDITS_TEXTS := preload("res://scripts/ui/ending_credits_texts.gd")
const GALLERY_TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")
const D5_TRANSITION_ART := preload("res://scripts/ui/d5_transition_art.gd")
const FRACTURE_REST_TEXTS := preload("res://scripts/ui/fracture_rest_texts.gd")
var _surface_active_seconds := 0.0
var _stay_inspection_open := false
var _demo_stinger_seconds := 0.0
var _demo_stinger_save_failed := false
var _d5_hold_seconds := 0.0
var _d5_hold_active := false
var _d6_guidance_seconds := 0.0
var _d6_guidance_failed := false
var _d6_sleep_transition_seconds := 0.0
var _d6_sleep_transition_active := false
var _d6_sleep_transition_route := ""
var _d6_sleep_transition_failed := false
const FULL_D5_HOLD_SECONDS := 10.0
const D6_SLEEP_TRANSITION_SECONDS := 6.0
const FULL_D5_HOLD_KO := [
	"손가락을 편다.\n손잡이는 바로 떨어지지 않고 손바닥의 떨림을 한 번 더 끌고 간다.",
	"톱니의 진동이 손금 사이에 남는다.\n꽃무늬 벽지는 배선 격자에서 천천히 밀려난다.",
	"촛불은 흔들리지 않는데 열이 사라진다.\n방이 망가진 것이 아니라, 숨기기를 멈추고 있다.",
]
const FULL_D5_HOLD_EN := [
	"You open your fingers.\nThe handle does not fall away at once. It drags the tremor across your palm one last time.",
	"The gears keep vibrating between the lines of your hand.\nThe floral wallpaper slowly slips away from a wiring grid.",
	"The candle does not flicker, but its heat disappears.\nThe room is not breaking. It is ceasing to hide.",
]
const DEMO_STINGER_BEATS := [
	"열세 번째 울림이 멎는다.\n벽의 꽃무늬는 한 박자 늦게 떨림을 멈춘다.",
	"벽지 아래로 가느다란 배선이 드러난다.\n찢어진 것은 벽이 아니라, 벽처럼 보이던 겉면이다.",
	"금속 이음새를 따라 차가운 빛이 이어진다.\n익숙한 복도의 윤곽은 아직 그 위에 남아 있다.",
	"멀리 사용인의 윤곽이 두 겹으로 어긋난다.\n누군가 말을 꺼내려다 멈춘다.",
	"저택 아래에서 규칙적인 진동이 돌아온다.\n차가 우러나던 동안 들었던 간격과 닮아 있다.",
	"주인공은 수첩을 쥔다.\n벽은 달라졌지만, 자신이 적은 글자는 남아 있다."
]
const OBJECTIVE_TEXT := {"D_SLEEP": "J3를 기억한 채 잠들어 다음 아침을 맞는다", "D0": "기록 내실의 세 눌림점에서 평면도를 꺼낸다", "D0_A": "C5 투명지와 저택 도면의 방향·기준점을 검증한다", "D1": "세 축의 순서와 깊이를 도면대로 적용한다", "DF": "압력핀 잠김 · 같은 침실에서 잠든다", "D2": "지하창고의 반복 구조를 조사한다", "D4": "태엽 심장의 연동 링과 정상 기동을 확인한다", "D5": "위장 필터 너머 드러난 공간을 확인한다", "DEMO_END": "데모 공개 구간 종료", "D6": "파열된 저택을 확인한 뒤 침실로 돌아간다", "E1_ENTRY": "같은 침실의 다른 아침"}

func _make_session() -> ChapterOneSession:
	return BASEMENT_SESSION.new(GameState, SaveManager, _slot_id)

func _supported_hint_stages() -> Array:
	return ["D0_A", "D1", "DF", "D4", "F0_A", "F0_B", "F0_C", "F0_D", "F0_E"]

func _puzzle_hint_text(level: int) -> String:
	if session.stage().begins_with("F0_"):
		return preload("res://scripts/ui/core_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())
	return preload("res://scripts/ui/basement_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())

func _puzzle_hint_title() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if session.stage().begins_with("F0_"):
		return ("Core puzzle hints · " if english else "코어 퍼즐 생각 정리 · ") + session.stage().replace("_", "-")
	match session.stage():
		"D0_A": return "Floorplan overlay hints" if english else "저택 도면 생각 정리"
		"D1", "DF": return "Pressure axis hints" if english else "압력축 생각 정리"
		_: return "Clockwork heart hints" if english else "태엽 심장 생각 정리"

func _basement() -> BasementSession:
	return session as BasementSession

func _history_enabled() -> bool:
	if session == null:
		return false
	var current_stage := session.stage()
	if current_stage in ["DEMO_END", "ENDING_CREDITS", "POST_CREDITS", "ENDING_BODY_PENDING"]:
		return false
	return not (current_stage == "D5" and SaveManager.get_build_flavor() == "demo")

func _feedback(result: Dictionary) -> void:
	if session != null and session.stage() == "D5" and SaveManager.get_build_flavor() == "demo" and result.get("ok", false):
		_set_status("위장 필터 해제 연출이 진행됩니다. 메뉴를 열면 일시정지합니다.")
		return
	var displayed := result.duplicate(true)
	var original := String(result.get("text", ""))
	displayed["text"] = _d6_text(ENDING_TEXTS.feedback(original, TranslationServer.get_locale()))
	if displayed["text"] != original and String(result.get("speaker", "주인공")) == "주인공":
		displayed["speaker"] = "Protagonist"
	super._feedback(displayed)

func _update_objective() -> void:
	if session != null: _objective_label.text = OBJECTIVE_TEXT.get(session.stage(), "수첩을 확인한다")

func _render_room() -> void:
	set_process(false)
	super._render_room()
	if session == null: return
	if session.stage() == "D6":
		_clear_hotspots()
		_build_d6_inspection()
		call_deferred("_restore_world_focus")
		return
	if session.stage() in ["ENDING_CREDITS","POST_CREDITS"]:
		_clear_hotspots()
		_build_ending_credits()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "STAY_STORY":
		_clear_hotspots()
		_build_stay_story()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "STAY_CHARTER":
		_clear_hotspots()
		_build_stay_charter()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "REALITY_SURFACE":
		_clear_hotspots()
		_build_reality_surface()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "FIELD_NOTEBOOK":
		_clear_hotspots()
		_build_field_notebook()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "REALITY_WAKE":
		_clear_hotspots()
		_build_reality_wake()
		call_deferred("_restore_world_focus")
		return
	if session.stage() in ["D5", "DEMO_END", "E1_ENTRY", "LUCA_GUIDE", "LUCA_S2", "E2_INTRO", "E3_3", "E_HUB", "E3_1", "E3_2", "E3_4", "E3_5", "J4", "E3_4M", "E5", "E6", "F0_A", "F0_B", "F0_C", "F0_D", "F0_E", "F1", "F2", "F3", "EDC", "ENDING_SEQUENCE", "ENDING_BODY_PENDING"]:
		_clear_hotspots()
		if session.stage() == "D5":
			_add_d5_transition_art(_demo_stinger_seconds / 60.0 if SaveManager.get_build_flavor() == "demo" else (_d5_hold_seconds / FULL_D5_HOLD_SECONDS if _d5_hold_active else 0.0))
			if SaveManager.get_build_flavor() == "demo":
				_objective_label.text = "위장 필터 해제"
				_board_label(_demo_stinger_beat(mini(5, int(_demo_stinger_seconds / 10.0))), Rect2(350, 300, 1200, 240))
				if _demo_stinger_save_failed:
					_action("D5_SAVE_RETRY", "완료 기록 저장 재시도", Rect2(510,640,870,130), "d_fracture")
				else:
					set_process(true)
			else:
				if _d5_hold_active:
					_objective_label.text = "INPUT HOLD · CAMOUFLAGE FILTER SEPARATING" if TranslationServer.get_locale().begins_with("en") else "입력 고정 · 위장 필터 분리 중"
					_board_label(_full_d5_hold_beat(), Rect2(350, 300, 1200, 260))
					set_process(true)
				else:
					_board_label("벽의 문양 사이로 배선이 드러난다.\n방금까지 하나였던 윤곽과 서명이 조금씩 어긋난다.", Rect2(350, 300, 1200, 240))
					_add_hotspot("D5_CONFIRM", "Release the handle and look around" if TranslationServer.get_locale().begins_with("en") else "손잡이를 놓고 드러난 공간을 확인한다", Rect2(510, 640, 870, 130), _begin_full_fracture_hold)
		elif session.stage() == "DEMO_END":
			_board_label("데모는 여기까지입니다.\n기록과 선택은 저장되어 있습니다. 본편의 저장 가져오기는 별도 승인을 거쳐 처리됩니다.", Rect2(330, 280, 1260, 280))
			_add_hotspot("RETURN_TITLE", "타이틀로 돌아간다", Rect2(520, 650, 830, 120), _return_to_title)
		elif session.stage() == "E1_ENTRY":
			_location_label.text = "같은 침실의 다른 아침"
			_objective_label.text = "서로 다른 세 곳을 확인한다" if not session.known("E1_complete") else "문이 열렸다. 남은 조사도 할 수 있다"
			var seen: Array = session.snapshot()["meta_progress"]["knowledge_entries"].get("E1_objects_seen", [])
			for index in range(4):
				var id: String = ["bed", "window", "mirror", "call_cord"][index]
				var label: String = ["천 아래의 침대", "그림자 없는 창문", "늦게 숨 쉬는 거울", "응답 없는 호출끈"][index]
				_action("E1_" + id, label + (" · 확인함" if id in seen else ""), Rect2(280 + (index % 2) * 730, 220 + (index / 2) * 190, 650, 140), "e1_inspect", id)
			_action("E1_EXIT", "침실 문을 연다", Rect2(510, 680, 870, 100), "move", "M1_CENTRAL_HALL")
		else:
			_build_fracture_intro()
		call_deferred("_restore_world_focus")
		return
	match _current_room:
		"M1_BASEMENT_ENTRY":
			_location_label.text = "서쪽 지하 계단문"
			_action("DESCEND", "지하 계단으로", Rect2(470, 310, 970, 260), "move", "B1_BASEMENT_STAIR", false)
			_replace_back("M1_GREAT_CLOCK", "대시계로")
		"B1_BASEMENT_STAIR":
			_location_label.text = "지하 계단"
			_action("AXIS_ROOM", "세 축 장치실", Rect2(470, 310, 970, 260), "move", "B1_AXIS_CHAMBER", false)
			_replace_back("M1_BASEMENT_ENTRY", "계단문으로")
		"B1_AXIS_CHAMBER":
			_location_label.text = "세 축 장치실"
			_build_axes()
			_replace_back("B1_BASEMENT_STAIR", "지하 계단으로")
		"B1_STORAGE":
			_location_label.text = "지하창고"
			for index in range(4):
				var id: String = ["barrel", "cable", "filter", "drawing"][index]
				var label: String = ["빈 와인통", "케이블 릴", "위장 필터 부품", "낙서 조각"][index]
				_action("STORE_" + id, label, Rect2(310 + (index % 2) * 700, 220 + (index / 2) * 190, 600, 130), "d_storage", id)
			_action("HEART_DOOR", "반복 구조의 중심", Rect2(500, 680, 900, 120), "move", "B1_CLOCKWORK_HEART", false)
			_replace_back("B1_AXIS_CHAMBER", "세 축 장치실로")
		"B1_CLOCKWORK_HEART":
			_location_label.text = "태엽 심장실"
			_build_heart()
			_replace_back("B1_STORAGE", "지하창고로")
	call_deferred("_restore_world_focus")


func _build_d6_inspection() -> void:
	var saved_route := String(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("fracture_rest_route", ""))
	if not _d6_sleep_transition_active and not _d6_sleep_transition_failed and _d6_sleep_transition_route.is_empty() and saved_route in ["bedroom", "emergency_capsule"]:
		_d6_sleep_transition_route = "capsule" if saved_route == "emergency_capsule" else "bedroom"
		_d6_sleep_transition_active = true
		_d6_sleep_transition_seconds = 0.0
	if _d6_sleep_transition_active or _d6_sleep_transition_failed:
		_build_d6_sleep_transition()
		return
	var checkpoint := int(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("guidance_checkpoint", 0))
	_d6_guidance_seconds = maxf(_d6_guidance_seconds, float(checkpoint))
	set_process(checkpoint < 480 and not _d6_guidance_failed)
	var room := String(session.snapshot()["loop_state"]["location_id"])
	_objective_label.text = "달라진 통로를 조사하거나 쉴 곳을 선택한다"
	if Array(session.snapshot()["meta_progress"]["knowledge_entries"].get("D6_objects_seen", [])).size() >= 2:
		_objective_label.text = "복구 절차는 수면 중 실행됩니다 · 더 조사하거나 쉴 곳을 선택한다"
	if room == "H0_SERVICE_SPINE":
		_location_label.text = "드러난 서비스 통로"
		var ids := ["wall", "sign", "trace", "capsule"]
		var labels := ["벗겨진 벽지", "서비스 척추 표지", "사용인 진단 잔상", "비상 캡슐의 표면"]
		for index in range(4):
			_action("D6_INSPECT_" + ids[index], labels[index], Rect2(280 + index % 2 * 700, 210 + index / 2 * 180, 610, 130), "d6_inspect", ids[index])
		_action("D6_INSPECT_notebook", "수첩의 낙서와 배선을 겹쳐 본다", Rect2(280, 550, 1310, 70), "d6_inspect", "notebook")
		_action("D6_BEDROOM", "침실로 돌아간다", Rect2(280, 640, 610, 100), "d6_move", "M2_BEDROOM", false)
		_add_hotspot("D6_CAPSULE", "가까운 비상 캡슐에서 쉰다", Rect2(980, 640, 610, 100), _confirm_d6_rest.bind("capsule"))
	elif room == "M2_BEDROOM":
		_location_label.text = "주인공의 침실 · 파열 이후"
		_action("D6_RETURN", "통로를 조금 더 본다", Rect2(280, 420, 610, 130), "d6_move", "H0_SERVICE_SPINE", false)
		_add_hotspot("D6_BED", "침대에서 쉰다", Rect2(980, 420, 610, 130), _confirm_d6_rest.bind("bedroom"))
	else:
		_board_label("벽지 뒤에서 드러난 서비스 통로에 두 휴식 경로가 표시되어 있다.", Rect2(350, 280, 1200, 200))
		_action("D6_SPINE", "드러난 서비스 통로로", Rect2(510, 600, 870, 130), "d6_move", "H0_SERVICE_SPINE", false)
	if checkpoint >= 480:
		_objective_label.text = "휴식 경로: 침실 또는 비상 캡슐 · 조사는 계속할 수 있다"
	if _d6_guidance_failed:
		_add_hotspot("D6_GUIDANCE_RETRY", "안내 기록 저장 재시도", Rect2(510, 810, 870, 70), _retry_d6_guidance)
	_objective_label.text = _d6_text(_objective_label.text)
	_location_label.text = _d6_text(_location_label.text)
	for node in _hotspot_layer.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.text = _d6_text(node.text)
		if node is Button:
			node.add_theme_font_size_override("font_size", int(round(20 * _reading_text_scale)))
	if _reading_text_scale > 1.0:
		var expanded := {
			"D6_INSPECT_notebook": Rect2(280, 550, 1310, 90),
			"D6_BEDROOM": Rect2(280, 665, 610, 140),
			"D6_CAPSULE": Rect2(980, 665, 610, 140),
			"D6_GUIDANCE_RETRY": Rect2(510, 850, 870, 110)
		}
		for id in expanded:
			var control := _hotspot_layer.get_node_or_null(NodePath(id)) as Control
			if control != null: _place(control, expanded[id])


func _d6_text(source: String) -> String:
	return FRACTURE_REST_TEXTS.text(source, TranslationServer.get_locale())


func _d6_guidance_text(checkpoint: int) -> String:
	if checkpoint == 300:
		return FRACTURE_REST_TEXTS.guidance_300(_basement().d5_reaction(), TranslationServer.get_locale())
	return _d6_text({180: "[취침 종: 깨진 간격으로 열한 번] 아직 통로를 더 살펴볼 수 있다.", 480: "침실 또는 가까운 비상 캡슐에서 쉴 수 있다. 지금 잠들 필요는 없다."}.get(checkpoint, ""))


func _localized_notebook_entry(entry: String) -> String:
	return _d6_text(super._localized_notebook_entry(entry))


func _retry_d6_guidance() -> void:
	_d6_guidance_failed = false
	_tick_d6_guidance(0.0)


func _tick_d6_guidance(delta: float) -> void:
	if session.stage() != "D6" or _interaction_blocked() or _d6_guidance_failed: return
	var checkpoint := int(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("guidance_checkpoint", 0))
	if checkpoint >= 480: return
	_d6_guidance_seconds = minf(480.0, _d6_guidance_seconds + maxf(delta, 0.0))
	var next := 180 if checkpoint < 180 else (300 if checkpoint < 300 else 480)
	if _d6_guidance_seconds < next: return
	var result := session.act("d6_guidance", str(next))
	_d6_guidance_failed = not result.get("ok", false)
	_render_room()
	if _d6_guidance_failed:
		_set_status(_d6_text("안내 기록을 저장하지 못했다. 다시 시도하거나 조사를 계속할 수 있다."))
	else:
		_set_status(_d6_guidance_text(next))


func _confirm_d6_rest(route: String) -> void:
	var sensation := "익숙한 이불 아래로 캡슐의 곡면이 만져진다. 이불 끝을 한 번 더 끌어당긴다." if route == "bedroom" else "금속 표면에 이불의 질감이 투사된다. 손끝이 매끄럽게 미끄러진다. 침대도 처음부터 이런 장치였을까."
	_show_modal(_d6_text("잠깐 눈을 감는다"), _d6_text(sensation) + "\n\n" + _d6_text("복구 절차를 실행하면 현재 파열 상태를 기준으로 수면 전환이 시작됩니다.\n결과는 확인되지 않았습니다."), [
		{"label": _d6_text("조금 더 본다"), "action": _close_modal},
		{"label": _d6_text("잠든다"), "action": _start_d6_rest.bind(route)},
	])


func _start_d6_rest(route: String) -> void:
	_close_modal()
	var result := session.act("d6_rest", route)
	if not result.get("ok", false):
		_feedback(result)
		return
	_begin_d6_sleep_transition(route)


func _begin_d6_sleep_transition(route: String) -> void:
	_d6_sleep_transition_route = "capsule" if route == "capsule" or route == "emergency_capsule" else "bedroom"
	_d6_sleep_transition_seconds = 0.0
	_d6_sleep_transition_failed = false
	_d6_sleep_transition_active = true
	set_process(true)
	_render_room()


func _build_d6_sleep_transition() -> void:
	_location_label.text = _d6_text("수면 전환 · 비상 캡슐" if _d6_sleep_transition_route == "capsule" else "수면 전환 · 침실")
	_objective_label.text = _d6_text("눈을 감은 뒤의 상태를 확인한다")
	var shade := ColorRect.new()
	shade.name = "D6SleepShade"
	shade.color = Color(0.012, 0.015, 0.024, 0.30 + 0.55 * clampf(_d6_sleep_transition_seconds / D6_SLEEP_TRANSITION_SECONDS, 0.0, 1.0))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(shade)
	_place(shade, Rect2(0, 90, 1920, 990))
	if _d6_sleep_transition_failed:
		_board_label(_d6_text("수면 전환을 저장하지 못했습니다. 현재 파열 상태와 선택한 경로는 유지됩니다."), Rect2(300, 280, 1320, 260))
		_add_hotspot("D6_SLEEP_RETRY", _d6_text("수면 전환 저장 재시도"), Rect2(510, 650, 900, 130), _retry_d6_sleep_transition)
		return
	var presentation: Dictionary = FRACTURE_REST_TEXTS.sleep_transition(_d6_sleep_transition_route, _d6_sleep_transition_seconds, TranslationServer.get_locale())
	_board_label(String(presentation["body"]), Rect2(300, 230, 1320, 480))
	set_process(true)


func _retry_d6_sleep_transition() -> void:
	_d6_sleep_transition_seconds = 0.0
	_d6_sleep_transition_failed = false
	_d6_sleep_transition_active = true
	set_process(true)
	_render_room()


func _tick_d6_sleep_transition(delta: float) -> void:
	if not _d6_sleep_transition_active or _interaction_blocked() or session.stage() != "D6":
		return
	var previous_beat := 0 if _d6_sleep_transition_seconds < 2.0 else (1 if _d6_sleep_transition_seconds < 4.0 else 2)
	_d6_sleep_transition_seconds = minf(D6_SLEEP_TRANSITION_SECONDS, _d6_sleep_transition_seconds + maxf(delta, 0.0))
	if _d6_sleep_transition_seconds >= D6_SLEEP_TRANSITION_SECONDS:
		_d6_sleep_transition_active = false
		set_process(false)
		var result := session.sleep()
		_d6_sleep_transition_failed = not result.get("ok", false)
		if not _d6_sleep_transition_failed:
			_d6_sleep_transition_route = ""
		_render_room()
		_feedback(result)
		return
	var current_beat := 0 if _d6_sleep_transition_seconds < 2.0 else (1 if _d6_sleep_transition_seconds < 4.0 else 2)
	if current_beat != previous_beat:
		_render_room()


func _present_dialogue_line() -> void:
	super._present_dialogue_line()
	_refresh_d5_focus_controls()


func _refresh_d5_focus_controls() -> void:
	var panel := _dialogue_layer.get_node_or_null("D5Focus") as Control
	var allowed: bool = session != null and session.stage() == "D5" and SaveManager.get_build_flavor() == "full" and _dialogue_active and bool(_dialogue_lines[_dialogue_index].get("d5_focus_allowed", false))
	if not allowed:
		if panel != null: panel.visible = false
		return
	var owners := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
	if panel == null:
		panel = Control.new()
		panel.name = "D5Focus"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dialogue_layer.add_child(panel)
		for index in range(5):
			var button := _make_button("", Rect2(250 + index * 290, 330, 270, 190), _select_d5_focus.bind(owners[index]))
			button.name = owners[index]
			panel.add_child(button)
	panel.visible = true
	var english := TranslationServer.get_locale().begins_with("en")
	var names := ["Edgar", "Mara 1", "Luca", "Iris", "Mara 2"] if english else ["에드가", "마라 1", "루카", "이리스", "마라 2"]
	var patterns := ["| |", "/ /", "|| . ||", "( * )", "[ [ ] ]"]
	var selected := String(session.snapshot()["loop_state"]["event_local_states"].get("D5", {}).get("D5_FOCUS_OWNER", ""))
	_update_d5_transition_art(1.0)
	for index in range(5):
		var button := panel.get_node(owners[index]) as Button
		button.text = names[index] + "\n" + patterns[index] + ("\n" + ("Looking" if english else "바라보는 중") if selected == owners[index] else "")
		button.add_theme_font_size_override("font_size", int(round(18 * _reading_text_scale)))


func _select_d5_focus(owner: String) -> void:
	if not _dialogue_active or not bool(_dialogue_lines[_dialogue_index].get("d5_focus_allowed", false)) or _modal_active:
		return
	var result := session.act("d5_focus", owner)
	if result.get("ok", false):
		_set_status("")
		_refresh_d5_focus_controls()
	else:
		_set_status("Could not save the viewing choice. Try again or continue reading." if TranslationServer.get_locale().begins_with("en") else "시선 기록을 저장하지 못했다. 다시 선택하거나 계속 읽을 수 있다.")


func _show_full_fracture_transition() -> void:
	if _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	_update_d5_transition_art(1.0)
	_show_dialogue(preload("res://scripts/ui/fracture_transition_texts.gd").lines(TranslationServer.get_locale(), _basement().d5_reaction()), _do.bind("d_fracture", null, false))


func _add_d5_transition_art(progress: float) -> void:
	var art := Control.new()
	art.set_script(D5_TRANSITION_ART)
	art.name = "D5TransitionArt"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(art)
	_hotspot_layer.move_child(art, 0)
	art.present(progress, _d5_visual_owner(), _d5_motion_mode())


func _update_d5_transition_art(progress: float) -> void:
	var art = _hotspot_layer.get_node_or_null("D5TransitionArt")
	if art != null:
		art.present(progress, _d5_visual_owner(), String(art.motion_mode))


func _d5_visual_owner() -> String:
	var local: Dictionary = session.snapshot()["loop_state"]["event_local_states"].get("D5", {})
	var selected := String(local.get("D5_FOCUS_OWNER", ""))
	return selected if not selected.is_empty() else String(_basement().d5_reaction().get("owner", ""))


func _d5_motion_mode() -> String:
	return String(AccessibilityProfileStore.new().load_profile().get("profile", {}).get("motion_mode", "standard"))


func _begin_full_fracture_hold() -> void:
	if _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	_d5_hold_seconds = 0.0
	_d5_hold_active = true
	_set_status("")
	_render_room()


func _full_d5_hold_beat() -> String:
	var source := FULL_D5_HOLD_EN if TranslationServer.get_locale().begins_with("en") else FULL_D5_HOLD_KO
	var index := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	return source[index]


func _tick_full_d5_hold(delta: float) -> void:
	if not _d5_hold_active or _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	var previous_beat := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	_d5_hold_seconds = minf(FULL_D5_HOLD_SECONDS, _d5_hold_seconds + maxf(delta, 0.0))
	_update_d5_transition_art(_d5_hold_seconds / FULL_D5_HOLD_SECONDS)
	if _d5_hold_seconds >= FULL_D5_HOLD_SECONDS:
		_d5_hold_active = false
		set_process(false)
		_show_full_fracture_transition()
		return
	var current_beat := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	if current_beat != previous_beat:
		_render_room()


func _demo_stinger_beat(index: int) -> String:
	var text := String(DEMO_STINGER_BEATS[clampi(index, 0, DEMO_STINGER_BEATS.size() - 1)])
	if index != 3:
		return text
	var line: Dictionary = preload("res://scripts/ui/fracture_transition_texts.gd").reaction(_basement().d5_reaction(), TranslationServer.get_locale())
	if line.is_empty():
		return text
	return text + "\n\n" + String(line["speaker"]) + ": " + String(line["text"])


func _build_fracture_intro() -> void:
	match session.stage():
		"EDC":
			_build_ending_decision()
			return
		"ENDING_SEQUENCE":
			_build_ending_entry()
			return
		"ENDING_BODY_PENDING":
			_objective_label.text = "엔딩 진행 상태 확인 필요"
			var ending: Dictionary = session.snapshot()["ending_run"]
			_board_label("이 버전에서 엔딩의 다음 장면을 확인할 수 없습니다.\n이 화면에서는 진행을 변경하지 않습니다.\n타이틀로 돌아가 저장 파일과 게임 버전을 확인하십시오.\n진단용 노드: " + String(ending.get("current_node_id", "없음")), Rect2(350,250,1200,330))
			_add_hotspot("ENDING_UNAVAILABLE_TITLE", "타이틀로 돌아간다", Rect2(520,650,880,110), _return_to_title)
			return
		"F3":
			_build_final_inspection()
			return
		"F2":
			_build_confrontation()
			return
		"F1":
			_build_father_record()
			return
		"F0_E":
			_build_core_self()
			return
		"F0_D":
			_build_core_roles()
			return
		"F0_C":
			_build_core_overlay()
			return
		"F0_B":
			_build_core_samples()
			return
		"F0_A":
			_build_core_room_network()
			return
		"E6":
			_build_core_approach()
			return
		"E5":
			_build_last_evening()
			return
		"J4", "E3_4M":
			_build_journal_four()
		"E3_5":
			_build_mara2_relationship()
		"E3_4":
			_build_edgar_relationship()
		"E3_3":
			_build_luca_relationship()
		"E3_2":
			_build_iris_relationship()
		"E3_1":
			_build_mara1_relationship()
		"LUCA_GUIDE":
			_objective_label.text = "주방의 이중 맥박 표식을 확인한다"
			_board_label("중앙홀은 잠깐 비어 있다.\n연두 보조등과 이중 맥박 문양이 주방 쪽을 가리킨다.", Rect2(340, 220, 1250, 220))
			_action("LUCA_GUIDE", "사용인 통로를 지나 주방으로", Rect2(410, 520, 1100, 120), "move", "M1_KITCHEN")
			_action("E1_RETURN", "침실의 남은 조사", Rect2(510, 720, 850, 90), "move", "M2_BEDROOM", false)
		"LUCA_S2":
			_objective_label.text = "루카의 차가운 손"
			_board_label("조리대 아래 낮은 경고음이 손목 맥박과 맞물린다.\n루카는 손을 숨긴다. 가까이 다가가자 피부가 아니라 냉각관 같은 한기가 닿는다.", Rect2(270, 190, 1380, 230))
			for index in range(3):
				_action("LUCA_S2_%d" % index, ["무슨 소리예요?", "손을 잡는다", "물러난다"][index], Rect2(400, 470 + index * 125, 1100, 100), "e2_luca", ["ask", "hold", "withdraw"][index])
		"E2_INTRO":
			_objective_label.text = "다섯 사용인의 보고와 합의"
			_action("E2_REPORT", "에드가의 보고를 듣는다", Rect2(380, 180, 1170, 100), "e2_report")
			if session.known("E2_report_seen"):
				for index in range(3):
					_action("E2_Q_%d" % index, ["저택은 어떻게 된 거예요?", "제 몸은 괜찮아요?", "왜 모두 기억하고 있어요?"][index], Rect2(380, 320 + index * 110, 1170, 85), "e2_question", ["house", "body", "memory"][index])
				_action("E2_FINISH", "목적지와 핵심 보고를 정리한다", Rect2(380, 710, 1170, 100), "e2_finish")
		"E_HUB":
			_add_hotspot("J4_CONFIRM", "조사를 마치고 기록 정리", Rect2(570, 885, 800, 60), _show_j4_confirmation)
			_objective_label.text = "사용인을 찾아가거나 지금까지의 기록을 정리한다"
			_board_label("마라 1은 배선실로 향했다.\n이리스는 온실에서 기다리고 있다.\n루카는 주방 아래의 장치를 살피고 있다.\n에드가는 대시계 쪽에 있다.\n마라 2는 북쪽 기록 회랑으로 돌아갔다.\n누구를 먼저 찾아갈지, 조사를 언제 마칠지는 내가 정한다.", Rect2(330, 130, 1260, 390))
			_action("MARA1_ENTRY", "마라 1 · 배선실로", Rect2(330, 550, 620, 90), "move", "M1_SERVICE_HALL", false)
			_action("IRIS_ENTRY", "이리스 · 온실로", Rect2(990, 550, 620, 90), "move", "M1_GREENHOUSE", false)
			_action("LUCA_ENTRY", "루카 · 생명 유지실로", Rect2(330, 670, 620, 90), "move", "M1_KITCHEN", false)
			_action("EDGAR_ENTRY", "에드가 · 대시계로", Rect2(990, 670, 620, 90), "move", "M1_GREAT_CLOCK", false)
			_action("MARA2_ENTRY", "마라 2 · 북쪽 기록 회랑", Rect2(330, 790, 620, 80), "move", "M1_NORTH_ARCHIVE_HALL", false)
			_action("E1_RETURN", "침실의 남은 조사", Rect2(990, 790, 620, 80), "move", "M2_BEDROOM", false)


func _build_mara1_relationship() -> void:
	_objective_label.text = "마라 1 · 끊긴 배선과 삭제 기록"
	if _current_room == "M1_SERVICE_HALL":
		_location_label.text = "사용인 작업 회랑"
		_board_label("마라 1이 스패너로 배선 덮개를 붙든다.\n마른 종이 냄새가 난다. '이건... 닦는 걸로 끝나지 않겠슴다.'", Rect2(300, 230, 1300, 220))
		_action("WIRING_ENTER", "배선실로", Rect2(450, 520, 1000, 110), "move", "M1_WIRING_ROOM", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "배선실"
	var rules = BasementSession.MARA1_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_1_complete"):
		_board_label("기록을 보존했다. 사건과 명령자·수행자의 책임은 남아 있다.\n수첩에서 REC_MARA1을 다시 확인할 수 있다.", Rect2(300, 260, 1300, 250))
	elif not local["panel"]:
		_action("MARA_PANEL", "패널과 세 단자의 신호를 조사한다", Rect2(300, 300, 1300, 220), "mara1_panel")
	elif not local["bridge"]:
		for index in range(3):
			var x := 210 + index * 520
			_board_label(["대각 나사선 · 솔 마찰음", "손바닥 승인각 · 두 번 확인음", "끊긴 사각 · 늦은 경고음"][index] + ("\n출처 확인함" if local["sources"].has(str(index)) else ""), Rect2(x, 190, 490, 110))
			for source_index in range(3):
				var source: String = rules.SOURCES[source_index]
				_action("MARA_SOURCE_%d_%d" % [index, source_index], source, Rect2(x, 330 + source_index * 105, 490, 85), "mara1_source", [index, source])
		_action("MARA_BRIDGE", "스패너로 가짜 브리지를 해제한다", Rect2(340, 680, 1220, 100), "mara1_bridge")
	elif not local["restored"]:
		_board_label("날짜와 문서 참조, 닦임 방향을 대조해 파편을 순서대로 놓는다.\n선택한 파편 수: %d / 3" % local["order"].size(), Rect2(290, 150, 1340, 120))
		for index in range(3):
			var id: String = ["command", "consent", "failure"][index]
			_action("MARA_LOG_" + id, rules.LOGS[id], Rect2(220 + index * 520, 310, 490, 260), "mara1_log", id)
		_action("MARA_CLEAR", "파편을 다시 펼친다", Rect2(260, 640, 650, 100), "mara1_clear")
		_action("MARA_RESTORE", "기록 순서를 검증한다", Rect2(980, 640, 650, 100), "mara1_restore")
	else:
		_action("MARA_CONFESS", "마라 1의 이야기를 듣는다", Rect2(330, 250, 1250, 150), "mara1_confess")
		if local["confessed"]:
			_add_hotspot("MARA_CHOICE", "기록 보존 방식을 정한다", Rect2(330, 520, 1250, 150), _show_mara1_choice)
	_replace_back("M1_SERVICE_HALL", "작업 회랑으로 · 진행 보존")


func _show_mara1_choice() -> void:
	_show_recorded_choice("기록을 어떻게 남길까", "두 방식 모두 사건과 명령자·수행자의 책임을 보존한다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "책임자와 원문을 그대로 남긴다", "action": _modal_act.bind("mara1_choose", "original_attribution")},
		{"label": "피해자 식별 정보만 보호한다", "action": _modal_act.bind("mara1_choose", "protected_identifiers")},
	])


func _build_iris_relationship() -> void:
	_objective_label.text = "이리스 · 계절 센서와 빼앗긴 전력"
	if _current_room == "M1_GREENHOUSE":
		_location_label.text = "온실"
		_board_label("빛은 따뜻하지만 공기는 차갑다.\n흙은 젖지 않은 채 젖은 냄새만 난다. 이리스가 웃는다. '안쪽을 보실래요?'", Rect2(300, 210, 1300, 230))
		_action("IRIS_CONTROL", "계절 제어실로", Rect2(400, 530, 1100, 130), "move", "H0_CLIMATE_CONTROL", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "계절 제어실"
	var rules = BasementSession.IRIS_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_2_complete"):
		_board_label("외부값의 결손과 승인 도용 기록을 보존했다.\n수첩에서 REC_IRIS를 확인할 수 있다.", Rect2(300, 250, 1300, 250))
	elif not local["panel"]:
		_action("IRIS_PANEL", "세 계기와 입력 출처를 조사한다", Rect2(300, 260, 1300, 240), "iris_panel")
	elif local["channels"].size() < 9:
		for row in range(3):
			var gauge: String = ["temperature", "humidity", "light"][row]
			_board_label(["온도", "습도", "광량"][row], Rect2(130, 200 + row * 170, 140, 100))
			for index in range(3):
				var clue: String = rules.CLUES[rules.CHANNELS[gauge][index]]
				var key := "%s_%d" % [gauge, index]
				_add_hotspot("IRIS_CHANNEL_" + key, clue + ("\n확인함" if local["channels"].has(key) else ""), Rect2(280 + index * 510, 200 + row * 170, 470, 135), _show_iris_channel.bind(gauge, index))
	elif not local["power"]:
		_board_label("날짜와 앞 문서의 참조로 전력 기록을 연결한다. 선택 %d / 5" % local["order"].size(), Rect2(270, 130, 1380, 90))
		for index in range(5):
			var id: String = ["audit", "warning", "conversion", "loss", "command"][index]
			_action("IRIS_LOG_" + id, rules.LOGS[id], Rect2(270, 250 + index * 90, 1380, 80), "iris_log", id)
		_action("IRIS_CLEAR", "다시 펼친다", Rect2(280, 740, 640, 85), "iris_clear")
		_action("IRIS_RESTORE", "순서 검증", Rect2(1000, 740, 640, 85), "iris_restore")
	elif not local["mismatch"]:
		_board_label("경고 제출자: 이리스\n명령 실행자: 아버지 / 사용 자격: 이리스\n감사 책임자: 이리스\n무엇이 어긋났는가?", Rect2(320, 180, 1250, 250))
		_action("IRIS_AUDIT_WRONG", "경고가 승인으로 바뀌었다", Rect2(330, 510, 1250, 95), "iris_audit", "warning_is_consent")
		_action("IRIS_AUDIT", "자격 소유자를 실행자로 기록했다", Rect2(330, 650, 1250, 95), "iris_audit", "credential_owner_not_executor")
	else:
		_action("IRIS_CONFRONT", "이리스의 이야기를 듣는다", Rect2(330, 280, 1250, 140), "iris_confront")
		if local["confronted"]:
			_add_hotspot("IRIS_CHOICE", "기록과 현재 온실을 어떻게 둘까", Rect2(330, 520, 1250, 140), _show_iris_choice)
	_replace_back("M1_GREENHOUSE", "온실로 · 진행 보존")


func _show_iris_channel(gauge: String, index: int) -> void:
	var actions: Array = [{"label": "문양과 날짜를 다시 본다", "action": _close_modal}]
	for source in BasementSession.IRIS_RELATIONSHIP.SOURCES:
		actions.append({"label": {"PROJECTION": "투사 연출", "EXTERNAL": "외부 센서", "MEMORY": "기억 모델"}[source], "action": _modal_act.bind("iris_source", [gauge, index, source])})
	_show_modal("입력 출처", "꽃잎의 반복 / 유리의 결손 파형 / 후광의 과거 날짜를 대조한다.", actions)


func _show_iris_choice() -> void:
	_show_recorded_choice("지금의 온실", "두 방식 모두 외부값과 책임 기록을 보존한다. 현재 보이는 계절 연출을 유지할지 정한다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "불완전한 외부값과 책임 로그를 그대로 남긴다", "action": _modal_act.bind("iris_choose", "external_truth")},
		{"label": "외부값은 보존하고 현재 온실 연출은 유지한다", "action": _modal_act.bind("iris_choose", "shelter_projection")},
	])


func _build_luca_relationship() -> void:
	_objective_label.text = "루카 · 생명 유지 장치와 유예된 기상"
	if _current_room == "M1_KITCHEN":
		_location_label.text = "주방"
		_board_label("조리대 아래의 배관이 손목과 비슷한 주기로 뛴다.\n루카가 문을 연다. '이번에는... 아가씨 기준부터 볼게요.'", Rect2(300, 240, 1300, 220))
		_action("LIFE_SUPPORT_ENTER", "생명 유지실로", Rect2(400, 530, 1100, 130), "move", "H0_LIFE_SUPPORT", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "생명 유지실"
	var rules = BasementSession.LUCA_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_3_complete"):
		_board_label("현재 생존 신호는 유지된다. 기상 안전은 확정되지 않았다.\n수첩에서 REC_LUCA를 다시 확인할 수 있다.", Rect2(300, 260, 1300, 240))
	elif not local["panel"]:
		_action("LUCA_PANEL", "배관의 맥박과 진단 패널 조사", Rect2(300, 300, 1300, 220), "luca_panel")
	elif not local["matched"]:
		for index in range(3):
			var id: String = ["decoration", "main", "aux"][index]
			var label: String = ["장식 매듭 · 맥박 없음", "BIO MAIN · 굵은 이중 맥박", "AUX · 점선 한 번 응답"][index]
			_action("LUCA_PIPE_" + id, label + (" · 연결 선택" if id in local["pipes"] else ""), Rect2(320, 240 + index * 135, 1300, 105), "luca_pipe", id)
		_action("LUCA_MATCH", "선택한 두 관을 진단 패널에 연결", Rect2(320, 690, 1300, 100), "luca_match")
	elif not local["stable"]:
		_board_label("두 번의 주관 맥박 → 보조관 응답 → 안전 밸브\n시간 제한은 없다. 배치한 주기를 언제든 미리 확인할 수 있다.", Rect2(250, 140, 1420, 130))
		for index in range(4):
			var phase: String = local["slots"].get(str(index), "")
			_add_hotspot("LUCA_SLOT_%d" % index, "슬롯 %d\n%s" % [index + 1, rules.PHASE_LABELS.get(phase, "미배치")], Rect2(260 + index * 360, 350, 320, 150), _show_luca_slot.bind(index))
		_action("LUCA_PREVIEW", "전체 주기 미리 확인", Rect2(300, 610, 610, 110), "luca_preview")
		_action("LUCA_RUN", "주기 실행과 안전 밸브 확인", Rect2(1000, 610, 610, 110), "luca_run")
	elif local["logs"].size() < 3:
		for index in range(3):
			var id: String = ["preservation", "approval", "blank"][index]
			_action("LUCA_LOG_" + id, rules.LOGS[id] + (" · 확인함" if id in local["logs"] else ""), Rect2(300, 210 + index * 180, 1300, 140), "luca_log", id)
	else:
		_action("LUCA_CONFESS", "루카의 이야기를 듣는다", Rect2(330, 270, 1250, 150), "luca_confess")
		if local["confessed"]: _add_hotspot("LUCA_CHOICE", "위험 기록을 읽을 순서를 정한다", Rect2(330, 510, 1250, 150), _show_luca_choice)
	_replace_back("M1_KITCHEN", "주방으로 · 진행 보존")


func _show_luca_slot(index: int) -> void:
	var actions: Array = [{"label": "아직 배치하지 않는다", "action": _close_modal}]
	for phase in BasementSession.LUCA_RELATIONSHIP.PHASES:
		actions.append({"label": BasementSession.LUCA_RELATIONSHIP.PHASE_LABELS[phase], "action": _modal_act.bind("luca_slot", [index, phase])})
	_show_modal("밸브 위상", "시간이 아니라 순서를 맞춘다. 전체 주기는 미리 확인할 수 있다.", actions)


func _show_luca_choice() -> void:
	_show_recorded_choice("확인할 순서", "두 선택 모두 같은 위험 기록을 읽는다. 지금 생존한다는 사실이 기상 안전을 보장하지는 않는다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "위험 수치를 먼저 전부 읽는다", "action": _modal_act.bind("luca_choose", "full_disclosure")},
		{"label": "장치를 안정시킨 뒤 기록을 함께 읽는다", "action": _modal_act.bind("luca_choose", "stabilize_first")},
	])


func _build_edgar_relationship() -> void:
	_objective_label.text = "에드가 · 보안 코어와 선택 권한"
	if _current_room == "M1_GREAT_CLOCK":
		_location_label.text = "대시계"
		_board_label("대시계 뒤 수직 잠금선이 드러난다.\n에드가가 레이피어로 네 선의 경계를 짚는다. '확인하실 기록이 있습니다.'", Rect2(300, 240, 1300, 210))
		_action("EDGAR_MACHINE", "보안 기계실로", Rect2(400, 530, 1100, 130), "move", "H0_CLOCK_MACHINE", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "대시계 기계실"
	var rules = BasementSession.EDGAR_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_4_complete"):
		_board_label("선택권은 SUBJECT, 주인공에게 있다.\n수첩의 REC_EDGAR에서 책임 기록을 확인할 수 있다.", Rect2(300, 270, 1300, 220))
	elif not local["audit"]:
		_board_label("네 권한 변경 이력을 선행 사건 순서로 놓는다. 선택 %d / 4" % local["order"].size(), Rect2(300, 120, 1300, 90))
		for index in range(4):
			var id: String = ["vacancy", "protocol", "extension", "consent"][index]
			_action("EDGAR_LOG_" + id, rules.LOGS[id], Rect2(300, 240 + index * 105, 1300, 95), "edgar_log", id)
		_action("EDGAR_CLEAR", "다시 펼친다", Rect2(300, 720, 600, 90), "edgar_clear")
		_action("EDGAR_AUDIT", "이력 순서를 확인한다", Rect2(1000, 720, 600, 90), "edgar_audit")
	elif not local["validated"]:
		var functions: Array = rules.OWNERS.keys()
		for index in range(4):
			var function: String = functions[index]
			var owner: String = local["owners"].get(function, "미배치")
			_add_hotspot("EDGAR_OWNER_" + function, rules.CLUES[function] + "\n현재 토큰: " + owner, Rect2(300, 180 + index * 125, 1300, 105), _show_edgar_owner.bind(function))
		_action("EDGAR_VALIDATE", "현재 권한 배치 검증", Rect2(300, 720, 1300, 100), "edgar_validate")
	else:
		_action("EDGAR_CONFESS", "명령과 에드가의 결정을 대조한다", Rect2(300, 270, 1300, 150), "edgar_confess")
		if local["confessed"]: _add_hotspot("EDGAR_CHOICE", "책임을 남길 방식을 정한다", Rect2(300, 540, 1300, 150), _show_edgar_choice)
	_replace_back("M1_GREAT_CLOCK", "대시계로 · 진행 보존")


func _show_edgar_owner(function: String) -> void:
	var actions: Array = [{"label": "근거를 다시 읽는다", "action": _close_modal}]
	for owner in BasementSession.EDGAR_RELATIONSHIP.OWNERS.values():
		actions.append({"label": owner, "action": _modal_act.bind("edgar_owner", [function, owner])})
	_show_modal(function, BasementSession.EDGAR_RELATIONSHIP.CLUES[function], actions)


func _show_edgar_choice() -> void:
	_show_recorded_choice("책임의 기록", "두 선택 모두 현재 선택권은 주인공에게 반환된다. 용서 여부나 엔딩을 결정하는 선택이 아니다.", [
		{"label": "기록을 다시 읽는다", "action": _close_modal},
		{"label": "당신이 한 결정도 공식 기록에 남겨요.", "action": _modal_act.bind("edgar_choose", "responsibility_recorded")},
		{"label": "기록보다 먼저, 내 권한을 내게 직접 돌려줘요.", "action": _modal_act.bind("edgar_choose", "authority_returned")},
	])


func _build_mara2_relationship() -> void:
	_objective_label.text = "마라 2 · 원본과 분산된 주석"
	var rules = BasementSession.MARA2_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if _current_room in ["M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY"]:
		_location_label.text = "북쪽 기록 회랑" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "색분해실 입구"
		_board_label("마라 2가 이중 윤곽의 이름표를 바로 세운다.\n'천재의 작업실에 온 걸 환영해요! 손대다 망가뜨려도 제 탓은 아니고요!'", Rect2(300, 240, 1300, 230))
		_action("MARA2_FORWARD", "안쪽으로", Rect2(400, 540, 1100, 120), "move", "M1_COLOR_ROOM_ENTRY" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "H0_COLOR_SEPARATION", false)
		_replace_back("M1_CENTRAL_HALL" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "M1_NORTH_ARCHIVE_HALL", "회랑으로")
		return
	if _current_room == "H0_COLOR_SEPARATION":
		_location_label.text = "색분해실"
		if local["sources"].size() < 15:
			for column in range(3):
				var portrait: String = ["A", "B", "C"][column]
				_board_label("초상화 " + portrait, Rect2(230 + column * 510, 150, 470, 70))
				for index in range(5):
					var owner: String = rules.OWNERS[(index + column) % 5]
					_add_hotspot("MARA2_SOURCE_" + portrait + owner, rules.SIGNS[owner] + (" · 확인" if local["sources"].has(portrait + "_" + owner) else ""), Rect2(230 + column * 510, 260 + index * 105, 470, 90), _show_mara2_source.bind(portrait, owner))
		elif not local["overlay"]:
			for index in range(3):
				var id: String = ["A", "B", "C"][index]
				var data: Dictionary = rules.PORTRAITS[id]
				var x := 230 + index * 510
				_board_label("초상화 %s\n열화 단계 %d\n3음 시작 표식 %d · 윤곽 기준선 %d" % [id, data["wear"], data["start"] + 1, data["outline"] + 1], Rect2(x, 170, 470, 170))
				_action("MARA2_ORDER_" + id, "이 시점의 조각 놓기", Rect2(x, 370, 470, 85), "mara2_portrait", id)
				_add_hotspot("MARA2_START_" + id, "3음 시작점", Rect2(x, 485, 470, 85), _show_mara2_alignment.bind(id, "start"))
				_add_hotspot("MARA2_OUTLINE_" + id, "이중 윤곽 기준점", Rect2(x, 600, 470, 85), _show_mara2_alignment.bind(id, "outline"))
			_action("MARA2_CLEAR", "시점 순서 다시 놓기", Rect2(250, 760, 630, 80), "mara2_clear")
			_action("MARA2_OVERLAY", "기록 중첩 검증", Rect2(1000, 760, 630, 80), "mara2_overlay")
		else:
			_board_label("세 시점 모두 같은 3·7·11칸이 비어 있다.\n마라 2가 먼저 문을 연다. 뒤돌아보지 않는다.", Rect2(300, 260, 1300, 230))
			_action("ARCHIVE_ENTER", "인격 아카이브로", Rect2(400, 550, 1100, 130), "move", "H0_PERSONALITY_ARCHIVE", false)
		_replace_back("M1_COLOR_ROOM_ENTRY", "입구로 · 진행 보존")
		return
	_location_label.text = "인격 아카이브"
	if session.known("E3_5_complete"):
		_board_label("원본과 감정 주석을 보존했다.\n수첩에서 REC_MARA2를 확인할 수 있다.", Rect2(300, 270, 1300, 230))
	elif not local["solved"]:
		for index in range(4):
			var owner: String = rules.OWNERS[index]
			_action("MARA2_BACKUP_" + owner, owner + " 보조 영역" + (" · 확인" if owner in local["backups"] else ""), Rect2(240 + index * 380, 180, 340, 100), "mara2_backup", owner)
		for index in range(12):
			var rect := Rect2(240 + (index % 6) * 250, 360 + (index / 6) * 135, 220, 110)
			var label := "%d · %s" % [index + 1, local["cells"].get(str(index), "결손")]
			if index in rules.GAPS: _add_hotspot("MARA2_CELL_%d" % index, label, rect, _show_mara2_cell.bind(index))
			else: _board_label(label, rect)
		_action("MARA2_CHECKSUM", "12칸 체크섬 비교", Rect2(400, 720, 1100, 100), "mara2_checksum")
	else:
		_action("MARA2_CONFESS", "자기 저장 영역 양도 기록을 듣는다", Rect2(300, 270, 1300, 150), "mara2_confess")
		if local["confessed"]: _add_hotspot("MARA2_CHOICE", "원본과 주석 보존 방식", Rect2(300, 520, 1300, 150), _show_mara2_choice)
	_replace_back("H0_COLOR_SEPARATION", "색분해실로 · 진행 보존")


func _show_mara2_source(portrait: String, owner: String) -> void:
	var actions: Array = [{"label": "문양을 다시 본다", "action": _close_modal}]
	for candidate in BasementSession.MARA2_RELATIONSHIP.OWNERS:
		actions.append({"label": candidate, "action": _modal_act.bind("mara2_source", [portrait, owner, candidate])})
	_show_modal("초상화 " + portrait, BasementSession.MARA2_RELATIONSHIP.SIGNS[owner], actions)


func _show_mara2_alignment(portrait: String, kind: String) -> void:
	var actions: Array = [{"label": "표식을 다시 본다", "action": _close_modal}]
	for index in range(3): actions.append({"label": "기준점 %d" % [index + 1], "action": _modal_act.bind("mara2_align", [portrait, kind, index])})
	_show_modal("초상화 " + portrait, "3음 시작 표식과 이중 윤곽 기준선을 맞춘다.", actions)


func _show_mara2_cell(index: int) -> void:
	var actions: Array = [{"label": "보조 기록을 다시 본다", "action": _close_modal}]
	for glyph in ["선", "점", "호"]: actions.append({"label": glyph, "action": _modal_act.bind("mara2_cell", [index, glyph])})
	_show_modal("결손 %d칸" % [index + 1], "원본 참조가 같은 조각을 대조한다.", actions)


func _show_mara2_choice() -> void:
	_show_recorded_choice("기록의 보존", "둘 다 원본과 감정 주석을 보존한다. 병합은 완전 회복의 약속이 아니며, 분리는 포기가 아니다.", [
		{"label": "설명을 다시 생각한다", "action": _close_modal},
		{"label": "감정 주석을 원본에 다시 합친다.", "action": _modal_act.bind("mara2_choose", "merged")},
		{"label": "원본과 주석을 분리해 서로 참조하게 한다.", "action": _modal_act.bind("mara2_choose", "separated")},
	])


func _show_j4_confirmation() -> void:
	var totals: Dictionary = BasementSession.JOURNAL_FOUR.summary(session.snapshot())
	var remaining := String(totals["remaining_names"])
	var time_text := "남은 선택 사건 없음" if remaining.is_empty() else "%d~%d분" % [totals["minutes_min"], totals["minutes_max"]]
	var body := "남은 사용인 사건은 이후 완료할 수 없습니다. 메인 진행과 두 최종 선택지는 유지됩니다.\n완료: %d / 5 · 연구원 기록: %d / 5\n미완료: %s\n남은 예상 시간: %s" % [totals["core_complete_ids"].size(), totals["researcher_record_count"], "없음" if remaining.is_empty() else remaining, time_text]
	if not totals["edgar_core_complete"]: body += "\n에드가 전체 사건은 최소 접근 절차로 대체됩니다. 최소 절차는 기록·관계·완료 수를 제공하지 않습니다."
	_show_modal("조사 종료 확인", body, [
		{"label": "계속 조사한다", "action": _close_modal},
		{"label": "기록을 정리한다", "action": _modal_act.bind("j4_confirm", true)},
	])
	var confirm := _modal_body.get_child(4) as Button
	confirm.disabled = true
	get_tree().create_timer(0.5, false).timeout.connect(_enable_j4_confirm.bind(weakref(confirm)))


func _enable_j4_confirm(reference: WeakRef) -> void:
	var button = reference.get_ref()
	if is_instance_valid(button) and _modal_active and button.is_inside_tree(): button.disabled = false


func _build_final_inspection() -> void:
	_objective_label.text = _ending_text("f3_objective")
	_location_label.text = _ending_text("location")
	var local: Dictionary = BasementSession.FINAL_INSPECTION.progress(session.snapshot())
	if not local["entered"]:
		_action("F3_ENTER",_ending_text("f3_enter"),Rect2(400,400,1100,130),"f3_enter")
		return
	_action("F3_WAKE",_ending_text("f3_wake"),Rect2(200,250,700,220),"f3_inspect","wake")
	_action("F3_STAY",_ending_text("f3_stay"),Rect2(1020,250,700,220),"f3_inspect","stay")
	_action("F3_NOTEBOOK",_ending_text("f3_notebook"),Rect2(610,530,700,130),"f3_inspect","notebook")
	if local["seen"].size()==3:
		_action("F3_SUMMARY",_ending_text("f3_summary"),Rect2(400,720,1100,85),"f3_summary")
	if local["summary_seen"]:
		_action("F3_OPEN",_ending_text("f3_open"),Rect2(400,830,1100,85),"f3_open")


func _build_ending_entry() -> void:
	var locale := TranslationServer.get_locale()
	_location_label.text = GALLERY_TEXTS.text("entry_location",locale)
	var rules = BasementSession.ENDING_ENTRY
	var node: String = session.snapshot()["ending_run"]["current_node_id"]
	_objective_label.text = GALLERY_TEXTS.text("identity_objective" if node == "ED_ALL_CEREMONY" else "entry_objective",locale)
	if node != "ED_ALL_CEREMONY":
		_board_label(GALLERY_TEXTS.entry(node,locale), Rect2(250,170,1420,510))
		_add_hotspot("ENDING_CONTINUE", GALLERY_TEXTS.text("entry_continue",locale), Rect2(450,770,1020,100), _ending_read.bind([{"speaker":"SYSTEM", "text":GALLERY_TEXTS.entry(node,locale)}], "continue", node))
		return
	var local: Dictionary = rules.progress(session.snapshot())
	var index: int = local["identity_index"]
	_board_label(GALLERY_TEXTS.text("identity_neutral",locale), Rect2(250,150,1420,130))
	if index < rules.OWNERS.size():
		var identity := {"speaker":GALLERY_TEXTS.WAKE.name_for(rules.OWNERS[index],locale),"text":GALLERY_TEXTS.identity(index,locale)}
		_board_label(GALLERY_TEXTS.text("identity_progress",locale) % [index + 1, identity["speaker"]], Rect2(300,360,1320,140))
		_add_hotspot("ENDING_IDENTITY", GALLERY_TEXTS.text("identity_listen",locale), Rect2(450,650,1020,120), _ending_read.bind([identity], "identity", rules.OWNERS[index]))
	elif not local["authority_seen"]:
		_add_hotspot("ENDING_AUTHORITY", GALLERY_TEXTS.text("authority_listen",locale), Rect2(450,450,1020,120), _ending_read.bind([{"speaker":GALLERY_TEXTS.WAKE.name_for("edgar",locale), "portrait":"EDGAR", "text":GALLERY_TEXTS.text("authority",locale)}], "authority", null))
	else:
		_board_label(GALLERY_TEXTS.text("signature_guide",locale), Rect2(250,320,1420,120))
		var signature = ENDING_SIGNATURE.new()
		signature.name = "ENDING_SIGNATURE"
		_hotspot_layer.add_child(signature)
		_place(signature, Rect2(460,510,1000,170))
		signature.signed.connect(_finish_ending_signature)
		signature.assistance_suggested.connect(func(): _set_status(GALLERY_TEXTS.text("signature_assistance",TranslationServer.get_locale())))
		_add_hotspot("ENDING_AUTO_SIGN", GALLERY_TEXTS.text("auto_sign",locale), Rect2(600,760,720,100), signature.finish_signature)


func _ending_read(lines: Array, action: String, value: Variant, prefix: String = "ending_") -> void:
	if _interaction_blocked(): return
	_show_dialogue(lines, _do.bind(prefix + action, value, false))


func _build_reality_wake() -> void:
	var rules = BasementSession.REALITY_WAKE
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	_location_label.text = WAKE_TEXTS.text("location_body" if node in ["EDR_WAKE_BODY","EDR_BODY_CHECK"] else "location_handoff", locale)
	_objective_label.text = WAKE_TEXTS.text("objective", locale) % WAKE_TEXTS.text(node, locale)
	if node in ["EDR_WAKE_BODY","EDR_BODY_CHECK"]:
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.075,0.095,0.105)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotspot_layer.add_child(backdrop)
		_place(backdrop, Rect2(0,90,1920,990))
	match node:
		"EDR_FAREWELL":
			var owner: String = rules.OWNERS[rules.index(state)]
			_board_label(WAKE_TEXTS.text("handoff_board", locale) % WAKE_TEXTS.name_for(owner, locale), Rect2(300,230,1320,270))
			_add_hotspot("REALITY_FAREWELL", WAKE_TEXTS.text("farewell", locale), Rect2(450,680,1020,120), _ending_read.bind(WAKE_TEXTS.farewell(state,owner,locale)["lines"], "farewell", owner, "reality_"))
		"EDR_DISCONNECT":
			_add_hotspot("REALITY_DISCONNECT", WAKE_TEXTS.text("disconnect", locale), Rect2(450,450,1020,150), _reality_disconnect)
		"EDR_WAKE_BODY":
			_board_label(WAKE_TEXTS.text("wake_board", locale), Rect2(300,260,1320,300))
			_add_hotspot("REALITY_WAKE", WAKE_TEXTS.text("wake", locale), Rect2(450,730,1020,120), _ending_read.bind([{"speaker":"SYSTEM","text":WAKE_TEXTS.text("wake_body", locale)}],"continue",node,"reality_"))
		"EDR_BODY_CHECK":
			var seen: Array = state["ending_run"].get("required_interactions_seen", [])
			var index := 0
			var count := 0
			for object in rules.BODY:
				var data: Array = WAKE_TEXTS.body(object, locale)
				var repeated: bool = object in seen
				if repeated: count += 1
				_add_hotspot(object, data[0] + (WAKE_TEXTS.text("checked", locale) if repeated else ""), Rect2(400,250+index*170,1120,120), _ending_read.bind([{"speaker":WAKE_TEXTS.text("protagonist", locale) if repeated else "SYSTEM","text":data[2] if repeated else data[1]}],"body",object,"reality_"))
				index += 1
			if count >= 2: _action("REALITY_BODY_FINISH",WAKE_TEXTS.text("body_finish", locale),Rect2(400,800,1120,100),"reality_body_finish",null,false)


func _reality_disconnect() -> void:
	if _interaction_blocked(): return
	var locale := TranslationServer.get_locale()
	_show_dialogue([
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_heat", locale)},
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_pressure", locale)},
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_taste", locale)},
	], _reality_fade)


func _open_notebook() -> void:
	if session != null and session.stage() in ["FIELD_NOTEBOOK","REALITY_SURFACE"]:
		_open_field_page("FIELD_NOTEBOOK_COVER",false)
		return
	if session != null and str(session.snapshot()["loop_state"]["location_id"]).begins_with("R0_"):
		_set_status(WAKE_TEXTS.text("notebook_unavailable", TranslationServer.get_locale()))
		return
	super._open_notebook()


func _build_field_notebook() -> void:
	var rules = BasementSession.FIELD_NOTEBOOK
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var at_exit: bool = state["ending_run"]["current_node_id"] == "EDR_EXIT_PANEL"
	_location_label.text = FIELD_TEXTS.text("location_exit" if at_exit else "location_book", locale)
	_objective_label.text = FIELD_TEXTS.text("objective_exit" if at_exit else "objective_book", locale)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.075,0.095,0.105)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(backdrop)
	_place(backdrop,Rect2(0,90,1920,990))
	var seen: Array = state["ending_run"].get("required_interactions_seen",[])
	if at_exit:
		var index := 0
		var complete := true
		for id in rules.EXIT:
			if id not in seen: complete = false
			_add_hotspot(id,FIELD_TEXTS.exit_text(id,0,locale)+(FIELD_TEXTS.text("checked",locale) if id in seen else ""),Rect2(400,210+index*170,1120,120),_ending_read.bind([{"speaker":"SYSTEM","text":FIELD_TEXTS.exit_text(id,1,locale)}],"inspect",id,"field_"))
			index += 1
		if complete: _action("FIELD_UNLOCK",FIELD_TEXTS.text("unlock",locale),Rect2(400,780,1120,100),"field_unlock",null,false)
		return
	var pages: Array = state["loop_state"]["event_local_states"].get("FIELD_NOTEBOOK",{}).get("pages",[])
	var index := 0
	for id in rules.PAGES:
		_add_hotspot(id,FIELD_TEXTS.title(id,locale)+(FIELD_TEXTS.text("read",locale) if id in pages else (FIELD_TEXTS.text("required",locale) if id in rules.REQUIRED else "")),Rect2(200+(index%3)*520,170+(index/3)*180,480,140),_open_field_page.bind(id,false))
		index += 1
	if rules.REQUIRED[0] in seen and rules.REQUIRED[1] in seen: _action("FIELD_FINISH",FIELD_TEXTS.text("finish",locale),Rect2(400,790,1120,100),"field_finish",null,false)


func _build_reality_surface() -> void:
	var rules = BasementSession.REALITY_SURFACE
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var location: String = state["loop_state"]["location_id"]
	var progress: Dictionary = rules.local(state)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.19,0.17,0.14) if location == "R0_SURFACE_THRESHOLD" else Color(0.075,0.095,0.105)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(backdrop)
	_place(backdrop,Rect2(0,90,1920,990))
	_location_label.text = SURFACE_TEXTS.text(location,locale)
	_objective_label.text = SURFACE_TEXTS.text("objective",locale)
	if node == "EDR_FINAL_FRAME":
		_objective_label.text = SURFACE_TEXTS.text("final_objective",locale)
		_board_label(SURFACE_TEXTS.final_frame(progress["look"],locale),Rect2(250,260,1420,250))
		var index := 0
		for direction in ["left","center","right"]:
			_action("SURFACE_LOOK_"+direction,SURFACE_TEXTS.view_text(direction,0,locale),Rect2(250+index*500,650,440,100),"surface_look",direction,false)
			index += 1
		set_process(true)
		return
	if node == "EDR_AIRLOCK_CONFIRM":
		_board_label(SURFACE_TEXTS.text("airlock_board",locale),Rect2(300,250,1320,260))
		_action("SURFACE_CANCEL",SURFACE_TEXTS.text("cancel",locale),Rect2(300,630,620,120),"surface_cancel",null,false)
		_action("SURFACE_ENTER",SURFACE_TEXTS.text("enter",locale),Rect2(1000,630,620,120),"surface_enter",null,false)
		return
	var index := 0
	for id in rules.OBJECTS:
		if rules.OBJECTS[id][0] != location: continue
		_add_hotspot("SURFACE_OBJ_"+id,SURFACE_TEXTS.object_text(id,0,locale)+(SURFACE_TEXTS.text("checked",locale) if id in progress["seen"] else ""),Rect2(350,200+index*160,1220,110),_ending_read.bind([{"speaker":"SYSTEM","text":SURFACE_TEXTS.object_text(id,1,locale)}],"inspect",id,"surface_"))
		index += 1
	if node == "EDR_FACILITY_FREE_LOOK":
		var target := "R0_CRYO_CHAMBER" if location == "R0_FACILITY_EXIT" else "R0_FACILITY_EXIT"
		_action("SURFACE_MOVE",SURFACE_TEXTS.text("move_cryo" if target == "R0_CRYO_CHAMBER" else "move_exit",locale),Rect2(250,760,650,100),"surface_move",target,false)
		if location == "R0_FACILITY_EXIT": _action("SURFACE_AIRLOCK",SURFACE_TEXTS.text("airlock",locale),Rect2(1020,760,650,100),"surface_airlock",null,false)
	else:
		_action("SURFACE_OUTSIDE",SURFACE_TEXTS.text("outside",locale),Rect2(400,760,1120,100),"surface_outside",null,false)


func _process(delta: float) -> void:
	if not get_window().has_focus() or _interaction_blocked(): return
	if session.stage() == "D5" and SaveManager.get_build_flavor() == "full" and _d5_hold_active:
		_tick_full_d5_hold(minf(delta, 0.1))
		return
	if session.stage() == "D6":
		if _d6_sleep_transition_active:
			_tick_d6_sleep_transition(minf(delta, 0.1))
			return
		_tick_d6_guidance(minf(delta, 0.1))
		return
	if session.stage() == "D5" and SaveManager.get_build_flavor() == "demo":
		_tick_demo_stinger(minf(delta, 0.1))
		return
	_surface_active_seconds += minf(delta,0.1)
	if _surface_active_seconds >= 1.0:
		_surface_active_seconds -= 1.0
		if session.stage() == "STAY_STORY":
			var result := session.act("story_tick")
			if result.get("ok",false): _render_room()
			else: _feedback(result)
		else: _on_surface_tick()


func _tick_demo_stinger(delta: float) -> void:
	if _interaction_blocked(): return
	if _demo_stinger_save_failed or session.stage() != "D5" or SaveManager.get_build_flavor() != "demo": return
	var previous_beat := int(_demo_stinger_seconds / 10.0)
	_demo_stinger_seconds = minf(60.0, _demo_stinger_seconds + maxf(0.0, delta))
	_update_d5_transition_art(_demo_stinger_seconds / 60.0)
	if _demo_stinger_seconds >= 60.0:
		var result := session.act("d_fracture")
		_demo_stinger_save_failed = not result.get("ok", false)
		_render_room()
		if _demo_stinger_save_failed: _feedback(result)
	elif int(_demo_stinger_seconds / 10.0) != previous_beat:
		_render_room()


func _build_stay_story() -> void:
	var rules = BasementSession.STAY_STORY
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var local: Dictionary = rules.progress(state)
	_location_label.text = _story_text("hall_location" if node == "EDS_CENTRAL_HALL" else "dining_location")
	_objective_label.text = _story_text("objective")
	if state["ending_run"].get("ending_appearance_mode","") == "layered" or _stay_inspection_open:
		for x in [160,960,1760]:
			var line := ColorRect.new()
			line.color = Color(0.7,0.8,0.85,0.3)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hotspot_layer.add_child(line)
			_place(line,Rect2(x,110,3,810))
	var appearance_mode: String = state["ending_run"].get("ending_appearance_mode","contextual")
	_board_label(_stay_text("display_status") % _stay_text("mode_"+appearance_mode),Rect2(200,105,1520,55))
	_add_hotspot("STORY_INSPECT",_stay_text("inspect"),Rect2(200,970,700,60),_toggle_stay_inspection)
	_add_hotspot("STORY_APPEARANCE",_stay_text("settings"),Rect2(1020,970,700,60),_show_stay_mode_settings)
	match node:
		"EDS_CENTRAL_HALL":
			if local.has("channel"): _board_label(_story_text("channel_selected") % STAY_TEXTS.owner(local["channel"],locale),Rect2(250,720,1420,55))
			var index := 0
			for id in rules.HALL:
				_add_hotspot("STORY_HALL_"+id,STORY_TEXTS.hall(id,0,locale),Rect2(250+(index%2)*750,210+(index/2)*170,670,120),_story_channel_menu if id == "cord" else _ending_read.bind([{"speaker":"SYSTEM","text":STORY_TEXTS.hall(id,1,locale)}],"hall",id,"story_"))
				index += 1
			_action("STORY_DINE",_story_text("dine"),Rect2(400,800,1120,100),"story_dine",null,false)
		"EDS_DINING_ROOM":
			_board_label(STORY_TEXTS.seating(state,locale),Rect2(250,200,1420,440))
			_add_hotspot("STORY_SIT",_story_text("sit"),Rect2(400,780,1120,100),_ending_read.bind([{"speaker":"SYSTEM","text":STORY_TEXTS.seating(state,locale)}],"sit",null,"story_"))
		"EDS_TABLE_OBJECTS":
			for index in range(2):
				var prefix := _story_text("written" if index in local["written"] else "write")
				_action("STORY_WRITE_%d"%index,prefix+STORY_TEXTS.sentence(index,locale),Rect2(250,180+index*105,1420,85),"story_write",index,false)
			var index := 0
			for owner in rules.TABLE:
				_add_hotspot("STORY_TABLE_"+owner,STORY_TEXTS.table_title(owner,locale),Rect2(250+(index%2)*750,420+(index/2)*110,670,85),_ending_read.bind(STORY_TEXTS.table_lines(state,owner,locale),"table",owner,"story_"))
				index += 1
			_action("STORY_TEA_WARM",_story_text("warm")+(_story_text("selected") if local["tea"] == "warm" else ""),Rect2(250,755,670,60),"story_tea","warm",false)
			_action("STORY_TEA_HOT",_story_text("hot")+(_story_text("selected") if local["tea"] == "hot" else ""),Rect2(1000,755,670,60),"story_tea","hot",false)
			if local["written"].size() == 2: _action("STORY_FINAL",_story_text("final"),Rect2(400,850,1120,80),"story_final",null,false)
		"EDS_FINAL_FRAME":
			_objective_label.text = _story_text("final_objective")
			var opening := "You sit facing forward. The servants stand on either side as they once did." if locale.begins_with("en") else "주인공이 정면을 보고 앉았다. 사용인들은 과거처럼 양옆에 서 있다."
			var text: String = opening if local["elapsed"] < 2 else STORY_TEXTS.seating(state,locale)
			var sensory := "\nBehind the hearth's scent remains the smell of metal; behind birdsong, the turning fan.\nThe five signatures do not merge. Each retains its own boundary." if locale.begins_with("en") else "\n난로 향 뒤에 금속 냄새, 새소리 뒤에 팬 회전음이 남는다.\n다섯 서명은 섞이지 않고 각자의 경계를 유지한다."
			_board_label(text+sensory,Rect2(250,200,1420,500))
			if local["elapsed"] < 2: set_process(true)
			else: _action("STORY_FINISH",_story_text("finish"),Rect2(400,800,1120,100),"story_finish",null,false)


func _story_channel_menu() -> void:
	if _interaction_blocked(): return
	var actions: Array = [{"label":_story_text("close"),"action":_close_modal}]
	for owner in BasementSession.STAY_STORY.OWNERS:
		actions.append({"label":STAY_TEXTS.owner(owner,TranslationServer.get_locale()),"action":_modal_act.bind("story_channel",owner)})
	_show_modal(_story_text("channel_title"), _story_text("channel_body"), actions)


func _story_text(id: String) -> String:
	return STORY_TEXTS.text(id, TranslationServer.get_locale())


func _build_ending_credits() -> void:
	var state := session.snapshot()
	var locale := TranslationServer.get_locale()
	_location_label.text = CREDITS_TEXTS.text(state["ending_run"]["branch_id"],locale)
	_objective_label.text = CREDITS_TEXTS.text("objective",locale)
	if session.stage() == "POST_CREDITS":
		_board_label(CREDITS_TEXTS.text("post_body",locale),Rect2(300,210,1320,210))
		_add_hotspot("CREDITS_RESELECT",CREDITS_TEXTS.text("reselect",locale),Rect2(450,590,1020,110),_reselect_menu)
		_add_hotspot("CREDITS_GALLERY",CREDITS_TEXTS.text("gallery",locale),Rect2(450,470,1020,95),_gallery_menu)
		_add_hotspot("CREDITS_TITLE",CREDITS_TEXTS.text("title",locale),Rect2(450,760,1020,110),_return_to_title)
		return
	if not state["ending_run"].get("credits_started",false):
		var meta: Dictionary = session.ensure_ending_meta()
		if not meta.get("ok", false):
			_board_label(CREDITS_TEXTS.text("save_error",locale) % meta.get("error", "unknown"),Rect2(300,210,1320,300))
			_action("CREDITS_RETRY",CREDITS_TEXTS.text("retry",locale),Rect2(450,650,1020,100),"credits_start",null,false)
			return
		_action("CREDITS_START",CREDITS_TEXTS.text("start",locale),Rect2(450,440,1020,130),"credits_start",null,false)
		return
	var rules = BasementSession.ENDING_CREDITS
	var index: int = rules.page(state)
	_board_label(CREDITS_TEXTS.page(index,locale),Rect2(300,210,1320,460))
	if index < rules.PAGES.size()-1: _action("CREDITS_NEXT",CREDITS_TEXTS.text("next",locale),Rect2(450,770,1020,100),"credits_next",index,false)
	else: _action("CREDITS_FINISH",CREDITS_TEXTS.text("finish",locale),Rect2(450,770,1020,100),"credits_finish",null,false)


func _gallery_menu(page: int = 0) -> void:
	if _dialogue_active or session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	if _modal_active: _close_modal()
	var store = preload("res://scripts/systems/ending_gallery_store.gd").new()
	var entries: Array[Dictionary] = store.list_entries()
	var actions: Array = [{"label":GALLERY_TEXTS.text("close",locale),"action":_close_modal}]
	for index in range(page * 4, mini(entries.size(), page * 4 + 4)):
		var entry: Dictionary = entries[index]
		var label: String = GALLERY_TEXTS.text(entry["branch"],locale)
		actions.append({"label":GALLERY_TEXTS.text("record",locale) % [label,index + 1],"action":_gallery_page.bind(entry["id"],0)})
	if page > 0: actions.append({"label":GALLERY_TEXTS.text("previous_list",locale),"action":_gallery_menu.bind(page-1)})
	if (page+1)*4 < entries.size(): actions.append({"label":GALLERY_TEXTS.text("next_list",locale),"action":_gallery_menu.bind(page+1)})
	_show_modal(GALLERY_TEXTS.text("title",locale), GALLERY_TEXTS.text("empty" if entries.is_empty() else "description",locale), actions)


func _gallery_page(id: String, page: int) -> void:
	if session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	var entry: Dictionary = preload("res://scripts/systems/ending_gallery_store.gd").new().read_entry(id)
	if not entry.get("ok", false): return
	var pages: Array[Dictionary] = preload("res://scripts/systems/ending_gallery_pages.gd").build(entry["state"],locale)
	if page < 0 or page >= pages.size(): return
	if _modal_active: _close_modal()
	var actions: Array = [{"label":GALLERY_TEXTS.text("back",locale),"action":_gallery_menu}]
	if page > 0: actions.append({"label":GALLERY_TEXTS.text("previous_record",locale),"action":_gallery_page.bind(id,page-1)})
	if page+1 < pages.size(): actions.append({"label":GALLERY_TEXTS.text("next_record",locale),"action":_gallery_page.bind(id,page+1)})
	_show_modal("%s · %d/%d" % [pages[page]["title"],page+1,pages.size()], pages[page]["text"], actions)


func _reselect_source() -> String:
	return str(session.snapshot()["meta_progress"]["knowledge_entries"].get("reselect_source_slot_id", _slot_id))


func _reselect_menu(page: int = 0) -> void:
	if _dialogue_active or session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	if _modal_active: _close_modal()
	var source := _reselect_source()
	var entries: Array[Dictionary] = SaveManager.list_reselect_slots(source)
	var actions: Array = [{"label":CREDITS_TEXTS.text("cancel",locale),"action":_close_modal}]
	if SaveManager.load_f3_reselect(source).get("ok", false):
		actions.append({"label":CREDITS_TEXTS.text("new_copy",locale),"action":_confirm_reselect})
	for index in range(page * 4, mini(entries.size(), page * 4 + 4)):
		var entry: Dictionary = entries[index]
		actions.append({"label":CREDITS_TEXTS.text("resume_copy",locale) % [index + 1, entry["save_point_id"]],"action":_resume_reselect.bind(entry["slot_id"])})
	if page > 0: actions.append({"label":CREDITS_TEXTS.text("previous_list",locale),"action":_reselect_menu.bind(page - 1)})
	if (page + 1) * 4 < entries.size(): actions.append({"label":CREDITS_TEXTS.text("next_list",locale),"action":_reselect_menu.bind(page + 1)})
	_show_modal(CREDITS_TEXTS.text("reselect_title",locale), CREDITS_TEXTS.text("reselect_body",locale), actions)


func _confirm_reselect() -> void:
	_close_modal()
	var locale := TranslationServer.get_locale()
	_show_modal(CREDITS_TEXTS.text("confirm_title",locale), CREDITS_TEXTS.text("confirm_body",locale), [{"label":CREDITS_TEXTS.text("cancel",locale),"action":_close_modal},{"label":CREDITS_TEXTS.text("create",locale),"action":_create_reselect}])


func _create_reselect() -> void:
	if session.stage() != "POST_CREDITS": return
	_close_modal()
	var result: Dictionary = SaveManager.create_f3_reselect_slot(_reselect_source())
	if not result.get("ok", false):
		_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("create_failed",TranslationServer.get_locale())}])
		return
	_resume_reselect(result["slot_id"])


func _resume_reselect(target: String) -> void:
	if session.stage() != "POST_CREDITS": return
	var allowed := false
	for entry in SaveManager.list_reselect_slots(_reselect_source()):
		if entry["slot_id"] == target: allowed = true
	if not allowed: return
	if _modal_active: _close_modal()
	var result := LoadCoordinator.new(GameState, SaveManager).load_and_install(target)
	if not result.get("ok", false):
		_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("load_failed",TranslationServer.get_locale())}])
		return
	_slot_id = target
	session = _make_session()
	_render_room()
	_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("copy_entered",TranslationServer.get_locale())}])


func _on_surface_tick() -> void:
	if session == null or session.stage() != "REALITY_SURFACE" or session.snapshot()["ending_run"]["current_node_id"] != "EDR_FINAL_FRAME":
		set_process(false)
		return
	if not get_window().has_focus() or _interaction_blocked(): return
	var result := session.act("surface_tick")
	if not result.get("ok",false):
		_feedback(result)
		return
	if session.stage() != "REALITY_SURFACE": _render_room()


func _open_field_page(page: String, expanded: bool) -> void:
	if _dialogue_active: return
	if _modal_active: _close_modal()
	var rules = BasementSession.FIELD_NOTEBOOK
	var locale := TranslationServer.get_locale()
	var text: String = FIELD_TEXTS.page_text(session.snapshot(),page,expanded,locale)
	var pages: Array = rules.PAGES.keys()
	var next_page: String = pages[(pages.find(page)+1)%pages.size()]
	_show_recorded_choice(FIELD_TEXTS.title(page,locale),text,[
		{"label":FIELD_TEXTS.text("close",locale),"action":_modal_act.bind("field_read",{"page":page,"expanded":expanded})},
		{"label":FIELD_TEXTS.text("summary" if expanded else "expand",locale),"action":_open_field_page.bind(page,not expanded)},
		{"label":FIELD_TEXTS.text("next",locale) + FIELD_TEXTS.title(next_page,locale),"action":_open_field_page.bind(next_page,false)},
	])


func _reality_fade() -> void:
	var shade := ColorRect.new()
	shade.color = Color.BLACK
	shade.modulate.a = 0.0
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_modal_active = true
	var tween := create_tween()
	tween.tween_property(shade,"modulate:a",1.0,0.5)
	tween.tween_property(shade,"modulate:a",0.0,0.5)
	tween.tween_callback(func():
		shade.queue_free()
		_modal_active = false
		_do("reality_continue","EDR_DISCONNECT",false)
	)


func _finish_ending_signature() -> void:
	if _interaction_blocked(): return
	var reality: bool = session.snapshot()["ending_run"]["branch_id"] == "reality"
	var text := "다섯 서명이 저전력 보존 인덱스로 접힌다. 문양과 이름은 지워지지 않는다." if reality else "다섯 서명이 서로의 경계를 유지한 채 저택 각 방향으로 흩어진다. 누구의 이름도 하나로 합쳐지지 않는다."
	_ending_read([{"speaker":"SYSTEM", "text":text}], "sign", null)


func _build_ending_decision() -> void:
	_objective_label.text = _ending_text("objective")
	_location_label.text = _ending_text("location")
	_board_label(_ending_text("notice"), Rect2(250,150,1420,100))
	_add_hotspot("EDC_REALITY", _ending_text("reality"), Rect2(200,300,700,220), _confirm_ending.bind("reality"))
	_add_hotspot("EDC_STAY", _ending_text("stay"), Rect2(1020,300,700,220), _confirm_ending.bind("stay"))
	_add_hotspot("EDC_SUBJECT", _ending_text("notebook"), Rect2(610,580,700,130), _edc_summary)
	_action("EDC_CANCEL", _ending_text("cancel"), Rect2(400,790,1100,100), "f3_cancel")
	_world_focus = "EDC_SUBJECT"
	call_deferred("_restore_world_focus")


func _restore_world_focus() -> void:
	if session != null and session.stage() == "EDC": _world_focus = "EDC_SUBJECT"
	if session != null and session.stage() == "STAY_CHARTER" and session.snapshot()["ending_run"]["current_node_id"] == "EDS_APPEARANCE_CONTROL": _world_focus = "STAY_MODE_NEUTRAL"
	super._restore_world_focus()


func _build_stay_charter() -> void:
	var rules = BasementSession.STAY_CHARTER
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var local: Dictionary = rules.progress(state)
	var mode: String = state["ending_run"].get("ending_appearance_mode","")
	if mode == "unset": mode = ""
	_location_label.text = _stay_text("location")
	_objective_label.text = _stay_text(node)
	if mode == "layered" or _stay_inspection_open:
		for x in [160,960,1760]:
			var line := ColorRect.new()
			line.color = Color(0.7,0.8,0.85,0.3)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hotspot_layer.add_child(line)
			_place(line,Rect2(x,110,3,810))
		_board_label(_stay_text("structure"),Rect2(200,115,1520,60))
	if not mode.is_empty():
		_board_label("FILTER: DISPLAY ONLY · "+STAY_TEXTS.mode(mode,locale)+_stay_text("changeable"),Rect2(200,900,1520,60))
		_add_hotspot("STAY_INSPECT_FRAME",_stay_text("inspect"),Rect2(200,970,700,65),_toggle_stay_inspection)
		_add_hotspot("STAY_MODE_SETTINGS",_stay_text("settings"),Rect2(1020,970,700,65),_show_stay_mode_settings)
	match node:
		"EDS_MEMORY_CHARTER":
			for index in range(3):
				_add_hotspot("STAY_MEMORY_%d"%index,_stay_text("principle")%[index+1,_stay_text("checked") if index in local["principles"] else ""],Rect2(350,220+index*170,1220,120),_ending_read.bind([{"speaker":"SYSTEM","text":STAY_TEXTS.principle(index,locale)}],"memory",index,"stay_"))
			if local["principles"].size() == 3: _action("STAY_MEMORY_FINISH",_stay_text("memory_finish"),Rect2(400,780,1120,100),"stay_memory_finish",null,false)
		"EDS_APPEARANCE_CONTROL":
			_action("STAY_LAYERED",STAY_TEXTS.mode("layered",locale),Rect2(200,260,700,200),"stay_appearance","layered",false)
			_action("STAY_CONTEXTUAL",STAY_TEXTS.mode("contextual",locale),Rect2(1020,260,700,200),"stay_appearance","contextual",false)
			_add_hotspot("STAY_MODE_NEUTRAL",_stay_text("neutral"),Rect2(460,540,1000,100),func(): _set_status(_stay_text("neutral_detail")))
			if not mode.is_empty(): _action("STAY_APPEARANCE_FINISH",_stay_text("appearance_finish"),Rect2(400,750,1120,100),"stay_appearance_finish",null,false)
		"EDS_AUTONOMY_CHARTER":
			_board_label(_stay_text("autonomy"),Rect2(200,180,1520,120))
			var index := 0
			for owner in rules.OWNERS:
				_action("STAY_ROLE_"+owner,STAY_TEXTS.owner(owner,locale)+_stay_text("proposed" if owner in local["proposed"] else "fixed"),Rect2(250+(index%2)*750,350+(index/2)*140,670,100),"stay_propose",owner,false)
				index += 1
			if local["proposed"].size() == 5: _action("STAY_AUTONOMY_FINISH",_stay_text("autonomy_finish"),Rect2(400,790,1120,85),"stay_autonomy_finish",null,false)


func _toggle_stay_inspection() -> void:
	_stay_inspection_open = not _stay_inspection_open
	_render_room()


func _show_stay_mode_settings() -> void:
	if _interaction_blocked(): return
	_show_modal(_stay_text("settings_title"), _stay_text("settings_body"), [
		{"label":_stay_text("keep"),"action":_close_modal},
		{"label":_stay_text("layered_button"),"action":_modal_act.bind("stay_appearance","layered")},
		{"label":_stay_text("contextual_button"),"action":_modal_act.bind("stay_appearance","contextual")},
	])


func _stay_text(id: String) -> String:
	return STAY_TEXTS.text(id, TranslationServer.get_locale())


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session != null and session.stage() == "EDC":
		# An interrupted confirmation never executes on focus return.
		if _modal_active: _close_modal()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and session != null and session.stage() == "EDC":
		call_deferred("_restore_world_focus")


func _edc_summary() -> void:
	if _interaction_blocked(): return
	var locale := TranslationServer.get_locale()
	_show_recorded_choice(_ending_text("summary_title"), ENDING_TEXTS.summary("wake", locale) + "\n\n" + ENDING_TEXTS.summary("stay", locale), [{"label": _ending_text("return"), "action": _close_modal}])


func _ending_text(id: String) -> String:
	return ENDING_TEXTS.text(id, TranslationServer.get_locale())


func _confirm_ending(decision: String) -> void:
	if _interaction_blocked() or session.stage() != "EDC": return
	if not BasementSession.ENDING_DECISION.CONFIRMATIONS.has(decision): return
	_show_recorded_choice(_ending_text("confirm_title"), ENDING_TEXTS.confirmation(decision, TranslationServer.get_locale()) + "\n\n" + _ending_text("confirm_notice"), [
		{"label": _ending_text("confirm_cancel"), "action": _modal_act.bind("f3_cancel")},
		{"label": _ending_text("confirm_commit"), "action": _modal_act.bind("edc_commit", decision)},
	])


func _build_confrontation() -> void:
	_objective_label.text = "F2 · 연구원들과의 대면"
	var rules = BasementSession.CONFRONTATION
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("F2_ENTER","대면 기록을 연다",Rect2(400,400,1100,130),"f2_enter")
		return
	var index := 0
	for question in ["consent","awakening","outside","release","wish"]:
		_action("F2_"+question,rules.QUESTIONS[question],Rect2(350,160+index*115,1200,95),"f2_question",question)
		index += 1
	if not local["recapped"]:
		_action("F2_RECAP","질문을 마치고 누락된 사실 확인",Rect2(350,790,1200,100),"f2_recap")
	else:
		_action("F2_FINISH","최종 권한 확인 후 다음 방으로",Rect2(350,790,1200,100),"f2_finish")


func _build_father_record() -> void:
	_objective_label.text = "F1 · 아버지의 마지막 기록"
	var rules = BasementSession.FATHER_RECORD
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("F1_ENTER","코어 기록실로 간다",Rect2(400,400,1100,130),"f1_enter")
		return
	_action("F1_INSPECT","아직 재생하지 않는다 / 기록실과 편집 이력 조사",Rect2(300,150,1300,100),"f1_inspect")
	if not local["authenticated"]:
		var mark: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"].get("self_authored_mark",{})
		_action("F1_AUTH","A1의 내 표시로 재생 권한 확인",Rect2(400,350,1100,120),"f1_authenticate",mark.get("type",""))
	else:
		for index in range(8):
			if index <= int(local["next"]):
				_action("F1_SEG_%d"%index,("재열람 · " if index < int(local["next"]) else "재생한다 · ")+rules.TITLES[index],Rect2(250+(index%2)*740,290+(index/2)*105,700,85),"f1_play",index)
		if session.known("father_final_record_played"):
			if not local["j5_read"]:
				_action("J5_PAGE","출력된 마지막 페이지를 읽는다",Rect2(400,780,1100,100),"f1_page")
			else:
				_action("J5_WRITE","지금의 내가 두 줄을 쓴다 · 최종 결정은 보류",Rect2(400,780,1100,100),"f1_write","subject")


func _build_core_self() -> void:
	_objective_label.text = "F0-E · 과거 연속성과 현재 작성자"
	var rules = BasementSession.CORE_SELF
	var local: Dictionary = rules.progress(session.snapshot())
	var mark: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"].get("self_authored_mark",{})
	if not rules.MARKS.has(mark.get("type","")):
		_board_label("A1 표시 유형 기록을 확인할 수 없다. 저장 자료 확인이 필요하다.", Rect2(300,250,1300,250))
		return
	if not local["past_verified"]:
		_board_label("A1의 원래 표시: "+str(mark.get("text",""))+"\n현재 배열: "+" → ".join(local["sequence"]), Rect2(300,130,1300,160))
		var pieces: Array = rules.MARKS[mark["type"]]
		for i in range(3):
			var piece: String = pieces[[2,0,1][i]]
			_action("F0E_PIECE_%d"%i,piece,Rect2(400,330+i*115,1100,95),"f0e_piece",piece,false)
		_action("F0E_CLEAR","다시 배열",Rect2(400,710,520,85),"f0e_clear",null,false)
		_action("F0E_PAST","과거 표시 확인",Rect2(980,710,520,85),"f0e_past")
	elif not local["current_verified"]:
		_board_label("빈 수첩 줄. 현재 문장의 작성 주체를 확인한다.\n이 단계는 남을지 떠날지를 묻지 않는다.",Rect2(300,140,1300,150))
		for i in range(4):
			var writer: String = ["father","system","subject","servant"][i]
			_action("F0E_AUTHOR_"+writer,["아버지의 기존 문장 불러오기","시스템 자동 문장 사용","지금의 내가 직접 쓴다","사용인 기록 넣기"][i],Rect2(400,330+i*115,1100,95),"f0e_author",writer)
	else:
		_board_label("비공개 임시 의향. 세 답변은 동등하며 최종 선택이 아니다.\n사용인은 이 기록을 보거나 듣지 못한다.",Rect2(300,150,1300,150))
		for i in range(3):
			var intent: String = ["reality","stay","undecided"][i]
			_action("F0E_INTENT_"+intent,rules.INTENTS[intent],Rect2(400,370+i*130,1100,105),"f0e_intent",intent)


func _build_core_roles() -> void:
	_objective_label.text = "F0-D · 기록 역할 분류"
	var rules = BasementSession.CORE_ROLES
	var local: Dictionary = rules.progress(session.snapshot())
	_board_label("왼쪽 기록을 조사한 뒤 오른쪽 역할에 배치한다.\n사용인 서명은 출처이지 역할 정답이 아니다.", Rect2(220,105,1480,100))
	for index in range(5):
		var record: String = ["notebook","command","father","residents","passphrase"][index]
		var title: String = rules.NAMES[record]
		if record == "residents" and not session.snapshot()["meta_progress"]["servants"]["mara2"]["researcher_record_acquired"]: title += " · 익명 인덱스"
		if local["selected"] == record: title += " [선택]"
		_action("F0D_CARD_"+record, title, Rect2(180,235+index*115,620,95), "f0d_select", record)
		var placed: String = local["slots"][index]
		var slot_title: String = rules.LABELS[index]+"\n"+("빈 슬롯" if placed.is_empty() else String(rules.NAMES[placed]))
		if local["locked"] == index: slot_title += " [고정]"
		_action("F0D_SLOT_%d"%index, slot_title, Rect2(880,235+index*115,650,95), "f0d_place", index, false)
		if local["failures"] >= 3 and local["locked"] < 0:
			_action("F0D_LOCK_%d"%index, "고정 확인", Rect2(1560,235+index*115,220,95), "f0d_lock", index)
	_action("F0D_VERIFY", "다섯 기록 일괄 검증", Rect2(350,850,1200,85), "f0d_verify")


func _build_core_overlay() -> void:
	_objective_label.text = "F0-C · 세 자료 중첩"
	var rules = BasementSession.CORE_OVERLAY
	var local: Dictionary = session.snapshot()["loop_state"]["event_local_states"].get("F0_C", rules.initial())
	var board := preload("res://scripts/chapters/core_overlay_board.gd").new()
	board.state = local
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(board)
	_place(board, Rect2(150,170,850,660))
	_board_label("B4 점선: 종 파형 / C5 굵은 선: 거울 회로\nD4 가는 선: 고정 포트 잔상\n기준 표식: 열두 번째 종 완료선 · 닫힌 고리 중심 · 중앙 심장 포트\n회전은 시계 방향, 반전은 원본에 먼저 적용한다.", Rect2(150,835,850,125))
	for index in range(3):
		var layer: String = rules.LAYERS[index]
		var y := 160 + index*230
		var anchor_names := ["미지정", "원점 정렬", "오른쪽 한 칸", "아래쪽 한 칸"]
		var anchor_index := clampi(int(local[layer]["anchor"]) + 1, 0, 3)
		_board_label("%s · %d도 · 반전 %s · %s" % [layer,local[layer]["turn"]*90,"있음" if local[layer]["flip"] else "없음",anchor_names[anchor_index]], Rect2(1050,y,720,55))
		if not local["locked"]:
			if layer != "D4":
				_action(layer+"_ROTATE", "90도 회전", Rect2(1050,y+65,340,55), "f0c", {"action":"rotate","layer":layer}, false)
				_action(layer+"_FLIP", "좌우 반전", Rect2(1410,y+65,340,55), "f0c", {"action":"flip","layer":layer}, false)
			_action(layer+"_ANCHOR", "기준점 순환", Rect2(1050,y+130,340,55), "f0c", {"action":"anchor","layer":layer,"value":(int(local[layer]["anchor"])+2)%4-1}, false)
		_action(layer+"_OPACITY", "투명도 %d" % local[layer]["opacity"], Rect2(1410,y+130,340,55), "f0c", {"action":"opacity","layer":layer,"value":20 if local[layer]["opacity"] >= 100 else int(local[layer]["opacity"])+10}, false)
	if not local["locked"]:
		_action("F0C_VERIFY", "중첩 확인", Rect2(1050,885,700,75), "f0c", {"action":"verify"})
	else:
		for index in range(3):
			var point: String = rules.INVESTIGATION[index]
			var point_label: String = {"PATH":"PATH · 경로", "SPLIT":"SPLIT · 분기", "AUTH":"AUTH · 인증 고리"}[point]
			_action("F0C_"+point, point_label, Rect2(1020+index*250,885,230,75), "f0c", {"action":"inspect","value":point})


func _build_core_samples() -> void:
	_objective_label.text = "F0-B · 시스템 신호 표본"
	var rules = BasementSession.CORE_SAMPLES
	var local: Dictionary = rules.progress(session.snapshot())
	_board_label("후보를 눌러 연결 목적지를 조사하고 방별로 표본을 전송한다.\n검증한 채널은 유지된다. 색이 아니라 연결 기능으로 판단한다.", Rect2(240, 110, 1440, 110))
	for index in range(4):
		var room: String = rules.ROOMS[index]
		var y := 245 + index * 160
		_board_label(rules.NAMES[room] + (" · 검증 완료" if room in local["verified"] else ""), Rect2(160, y, 290, 125))
		for column in range(2):
			var sample: int = [1, 0][column] if index % 2 == 0 else column
			var label: String = rules.SAMPLES[room][sample]["label"]
			if local["selected"].get(room, -1) == sample: label += " [선택]"
			_action("F0B_%s_%d" % [room, sample], label, Rect2(480 + column * 460, y, 430, 125), "f0b_inspect", [room, sample])
		if room not in local["verified"]:
			_action("F0B_SEND_" + room, "전송", Rect2(1410, y, 330, 125), "f0b_send", room)


func _build_core_room_network() -> void:
	_objective_label.text = "F0-A · 네 방의 피드백 회로"
	var rules = BasementSession.CORE_ROOMS
	var local: Dictionary = rules.progress(session.snapshot())
	_board_label("외부 대기 입력: 북\n코어 요청 단자: 서\n고정 회랑: 북→동→남→서→북\n타일 두 개를 눌러 교환한다.\n출력 방향은 별도로 회전한다.", Rect2(650, 345, 620, 245))
	var positions := [Vector2(675, 110), Vector2(1275, 345), Vector2(675, 650), Vector2(75, 345)]
	for slot in range(4):
		var pos: Vector2 = positions[slot]
		var room: String = local["tiles"][slot]
		var label := "%s · %s%s\n%s\n출력 → %s" % [rules.DIRECTIONS[slot], rules.NAMES[room], " [선택]" if local["selected"] == slot else "", rules.PORTS[room], rules.DIRECTIONS[local["directions"][slot]]]
		_action("F0A_TILE_%d" % slot, label, Rect2(pos, Vector2(550, 150)), "f0a_select", slot, false)
		_action("F0A_ROTATE_%d" % slot, "출력 90도 회전", Rect2(pos + Vector2(0, 160), Vector2(550, 65)), "f0a_rotate", slot, false)
	_action("F0A_NOTES", "P1·P4·P5·일지 자료", Rect2(180, 930, 720, 60), "f0a_notes")
	_action("F0A_SIGNAL", "약한 신호를 보낸다", Rect2(1020, 930, 720, 60), "f0a_signal")


func _build_core_approach() -> void:
	_objective_label.text = "코어 접근 · 남은 후속 반응"
	var state := session.snapshot()
	var rules = BasementSession.CORE_APPROACH
	var location: String = state["loop_state"]["location_id"]
	if location == "M1_NORTH_ARCHIVE_HALL" and rules.pending(state, "MARA2_FU"):
		_board_label("마라 2가 자신의 이름을 확인해 달라고 한다.\n기록하거나 불러 주거나 장난으로 답할 수 있다.", Rect2(300, 150, 1300, 150))
		for index in range(3):
			var id: String = ["write", "call", "joke"][index]
			_action("MARA2_FU_" + id, ["수첩에 마라 2(가칭)를 적는다", "이름을 다시 불러 준다", "장난으로 넘긴다"][index], Rect2(350, 335 + index * 110, 1200, 90), "e6_mara2", id)
	elif location == "H0_CLOCK_MACHINE":
		if rules.pending(state, "EDGAR_S3"):
			for index in range(3):
				var id: String = ["ask", "order", "wait"][index]
				_action("EDGAR_S3_" + id, ["열어 주세요.", "명령이에요. 열어요.", "아무 말 없이 기다린다"][index], Rect2(350, 250 + index * 100, 1200, 85), "e6_edgar", id)
		if not session.known("core_access_open"):
			_action("E6_OPEN", "후속 대화 없이 접근로를 연다", Rect2(350, 570, 1200, 90), "e6_open")
		else:
			_add_hotspot("E6_ENTER", "코어 경로 진입 확인", Rect2(350, 570, 1200, 90), _show_core_entry_confirmation)
	else:
		_board_label("남은 후속 반응은 선택 사항이다.\n코어 문턱을 넘기 전까지 확인할 수 있다.", Rect2(300, 250, 1300, 200))
	if location != "M1_NORTH_ARCHIVE_HALL" and rules.pending(state, "MARA2_FU"):
		_action("E6_ARCHIVE", "북쪽 기록 회랑 · 마라 2 후속", Rect2(250, 735, 680, 85), "e6_move", "M1_NORTH_ARCHIVE_HALL", false)
	if location != "H0_CLOCK_MACHINE":
		_action("E6_CLOCK", "보안 기계실 · 다음 경로", Rect2(980, 735, 680, 85), "e6_move", "H0_CLOCK_MACHINE", false)
	_action("E6_HALL", "중앙홀로 돌아간다", Rect2(350, 850, 1200, 70), "e6_move", "M1_CENTRAL_HALL", false)


func _show_core_entry_confirmation() -> void:
	_show_modal("코어 경로 진입", "진입하면 이전 공간으로 돌아갈 수 없고, 미확인 후속 반응은 종료됩니다. 완료한 관계와 저녁의 결산은 유지됩니다. 현실·잔류 선택은 아직 하지 않습니다.", [
		{"label": "아직 조사한다", "action": _close_modal},
		{"label": "문턱을 넘는다", "action": _modal_act.bind("e6_enter", true)},
	])


func _build_last_evening() -> void:
	_objective_label.text = "마지막으로 정상인 저녁"
	var rules = BasementSession.LAST_EVENING
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("E5_ENTER", "저녁 준비를 따라 식당으로 간다", Rect2(400, 400, 1100, 140), "e5_enter")
		return
	if session.snapshot()["loop_state"]["location_id"] == "M1_CENTRAL_HALL":
		_action("E5_RETURN", "식당으로 돌아간다", Rect2(400, 400, 1100, 140), "e5_inspect", "dining")
		return
	_action("E5_TABLE", "식탁의 목재와 프레임", Rect2(260, 220, 680, 100), "e5_inspect", "table")
	_action("E5_SEATS", "다섯 사용인의 자리와 문양", Rect2(980, 220, 680, 100), "e5_inspect", "seats")
	_action("E5_HALL", "중앙홀 시계를 다시 본다", Rect2(260, 345, 1400, 85), "e5_inspect", "hall")
	if not local["seated"]:
		_action("E5_SIT", "북쪽 정면의 내 자리에 앉는다", Rect2(350, 510, 1200, 140), "e5_sit")
	elif String(local["question"]).is_empty():
		var index := 0
		for question in ["wish", "leave", "stay"]:
			_action("E5_QUESTION_" + question, rules.QUESTIONS[question], Rect2(350, 475 + index * 110, 1200, 95), "e5_question", question)
			index += 1
	else:
		_add_hotspot("E5_FINISH", "코어 접근 준비를 마친다", Rect2(350, 600, 1200, 140), _show_e5_confirmation)


func _show_e5_confirmation() -> void:
	_show_modal("코어 접근 준비", "저녁의 결산을 마칩니다. 남을지 떠날지는 코어에서 다시 확인합니다.", [
		{"label": "아직 준비되지 않았다", "action": _close_modal},
		{"label": "준비를 마친다", "action": _modal_act.bind("e5_finish", true)},
	])


func _build_journal_four() -> void:
	_objective_label.text = "네 번째 일지 · 약속과 권한"
	if session.stage() == "E3_4M":
		_board_label("에드가의 전체 관계 사건은 종료되었다.\n최소 접근 핀은 기록이나 관계 보상이 아니다.", Rect2(300, 250, 1300, 250))
		_action("EDGAR_MINIMUM", "코어 접근 핀을 받아 꽂는다", Rect2(400, 590, 1100, 120), "j4_minimum")
	else:
		var rules = BasementSession.JOURNAL_FOUR
		var local: Dictionary = rules.progress(session.snapshot())
		if local["ordered"]:
			_action("J4_READ", "약속과 권한의 모순 문장을 읽는다", Rect2(300, 320, 1300, 230), "j4_read")
		else:
			_board_label("획득하지 않은 기록은 빈 인덱스다.\n아버지 일지와 시스템 날짜만으로도 네 사건을 배열할 수 있다.", Rect2(280, 140, 1360, 120))
			var selected: PackedStringArray = []
			for page in local["pages"]: selected.append(String(rules.PAGES[page]).split(" · ")[0])
			_board_label("현재 배열: " + ("없음" if selected.is_empty() else " → ".join(selected)), Rect2(300, 695, 1300, 50))
			for index in range(4):
				var id: String = ["roles", "promise", "activation", "transition"][index]
				_action("J4_PAGE_" + id, rules.PAGES[id], Rect2(300, 290 + index * 100, 1300, 85), "j4_page", id)
			_action("J4_CLEAR", "다시 펼친다", Rect2(300, 750, 610, 90), "j4_clear")
			_action("J4_ORDER", "순서를 확인한다", Rect2(1000, 750, 610, 90), "j4_order")

func _build_great_clock(_local: Dictionary) -> void:
	_action("BASEMENT_DOOR", "서쪽 지하 계단문", Rect2(430, 300, 1050, 230), "move", "M1_BASEMENT_ENTRY", false)

func _build_loop_bedroom(local: Dictionary) -> void:
	super._build_loop_bedroom(local)
	for id in ["CSHORT", "RUB_CLOCK"]:
		var old := _hotspot_layer.get_node_or_null(id)
		if old != null:
			_hotspot_layer.remove_child(old)
			old.queue_free()
	if _basement().can_use_basement_shortcut(true):
		_action("D_FASTPATH", "검증한 절차로 지하창고 다시 열기", Rect2(350, 770, 1050, 90), "d_fastpath")
	elif _basement().can_use_basement_shortcut():
		_action("DSHORT", "도면과 검증한 깊이로 준비 축약", Rect2(350, 770, 1050, 90), "d_shortcut")

func _build_inner(_local: Dictionary, _journal: int) -> void:
	var local := _basement().basement_local()
	if not local["floorplan_ready"]:
		_board_label("책상 이중 바닥의 세 눌림점\nC5 투명지와 J3의 침실·온실·대시계 기준점을 비교한다.", Rect2(290, 210, 1350, 220))
		for index in range(3):
			var id: String = ["bedroom", "greenhouse", "great_clock"][index]
			_action("DRAWER_" + id, ["침실 점", "온실 점", "대시계 점"][index], Rect2(280 + index * 510, 540, 450, 140), "d_drawer_point", id)
		return
	var anchor_label: String = {"bedroom": "침실", "greenhouse": "온실", "great_clock": "대시계"}.get(String(local["anchor"]), "미선택")
	_board_label("평면도와 C5 투명지\n회전 %d° · %s · 고정점 %s\n세 기준점뿐 아니라 거울에 뒤집힌 글자의 방향도 확인한다." % [local["rotation"], "좌우 반전" if local["flipped"] else "반전 없음", anchor_label], Rect2(260, 180, 1390, 210))
	_action("D_ROTATE", "90° 회전", Rect2(360, 440, 520, 90), "d_rotate", null, false)
	_action("D_FLIP", "좌우 반전", Rect2(1030, 440, 520, 90), "d_flip", null, false)
	for index in range(3):
		_action("D_ANCHOR_%d" % index, ["침실 고정", "온실 고정", "대시계 고정"][index], Rect2(280 + index * 510, 575, 450, 85), "d_anchor", ["bedroom", "greenhouse", "great_clock"][index], false)
	_action("D_OVERLAY", "방향과 지하 좌표 검증", Rect2(510, 745, 880, 105), "d_overlay")

func _build_axes() -> void:
	var axes: Dictionary = _basement().basement_local()["axes"]
	if axes["locked"]:
		_board_label("압력핀 하강 · 당일 입력 잠김\n수첩의 검증 결과는 남는다. 같은 침실에서 잠든다.", Rect2(380, 310, 1140, 250))
		return
	if axes["open"]:
		_action("STORAGE_ENTER", "열린 지하창고로", Rect2(470, 330, 980, 250), "move", "B1_STORAGE", false)
		return
	for index in range(3):
		var axis: String = BASEMENT_RULES.AXES[index]
		_board_label(BASEMENT_RULES.AXIS_NAMES[axis] + (" · 밀기 완료" if axis in axes["pushed"] else " · 깊이 " + str(axes["depths"][axis])), Rect2(240 + index * 520, 230, 460, 110))
		for depth in range(1, 4):
			_action("DEPTH_%s_%d" % [axis, depth], str(depth), Rect2(245 + index * 520 + (depth - 1) * 155, 410, 140, 85), "d_axis_depth", [axis, depth], false)
		_add_hotspot("PUSH_" + axis, "축을 민다", Rect2(250 + index * 520, 560, 430, 100), _confirm_axis.bind(axis))
	_add_hotspot("CENTRAL_CW", "중앙 시계 방향 반 바퀴", Rect2(320, 755, 610, 105), _confirm_central.bind("clockwise"))
	_add_hotspot("CENTRAL_CCW", "중앙 반시계 방향", Rect2(1030, 755, 580, 105), _confirm_central.bind("counterclockwise"))

func _confirmation_notebook() -> void:
	_close_modal()
	_open_notebook()

func _confirm_axis(axis: String) -> void:
	_show_modal("압력핀 확인", "축을 밀면 이 루프에서는 되돌릴 수 없다. 도면의 순서와 깊이를 먼저 확인한다.", [
		{"label": "수첩 도면을 본다", "action": _confirmation_notebook},
		{"label": "깊이를 다시 확인한다", "action": _close_modal},
		{"label": "축을 민다", "action": _modal_act.bind("d_axis_push", {"value": axis, "confirmed": true})},
	])

func _confirm_central(direction: String) -> void:
	_show_modal("중앙 손잡이", "역방향에는 방지턱이 있다. 경고 뒤 강행하면 오늘 장치가 잠긴다.", [
		{"label": "다시 확인한다", "action": _close_modal},
		{"label": "선택한 방향으로 움직인다", "action": _modal_act.bind("d_axis_central", {"value": direction, "confirmed": true})},
	])

func _build_heart() -> void:
	var heart: Dictionary = _basement().basement_local()["heart"]
	var glyphs := [["XII 표시", "XIII 홈", "작은 홈", "빈 테두리"], ["닫힌 갈래", "직선 접점", "C5 분기 접점", "환형 접점"], ["빈 중심", "창 문양", "문 문양", "최하단 심장"]]
	var labels: Array[String] = []
	for index in range(3): labels.append(glyphs[index][heart["rings"][index]])
	_board_label("외곽 · 중간 · 안쪽\n" + " / ".join(labels) + "\n정상 레버: %d / XII" % heart["wind"], Rect2(270, 175, 1370, 180))
	var operations := ["turn", "turn", "turn", "reset", "fix", "unfix", "wind", "stabilize", "inspect_auxiliary"]
	var names := ["손잡이 A", "손잡이 B", "손잡이 C", "링 초기 위치로", "링 고정", "기동 전 고정 해제", "정상 레버 한 칸", "정상 안정화 실행", "패널 뒤 조사"]
	for index in range(operations.size()):
		_action("HEART_%d" % index, names[index], Rect2(235 + (index % 3) * 515, 415 + (index / 3) * 115, 455, 85), "d_heart", {"action": operations[index], "value": ["A", "B", "C"][index] if index < 3 else null})
	_add_hotspot("AUXILIARY", "보조 레버 확인", Rect2(510, 805, 880, 88), _confirm_auxiliary)

func _confirm_auxiliary() -> void:
	_show_modal("정상 절차 밖의 입력", "보조 레버를 실행하면 현재 위장 상태를 유지할 수 없다.", [
		{"label": "아직 당기지 않는다", "action": _close_modal},
		{"label": "기록을 다시 확인한다", "action": _confirmation_notebook},
		{"label": "보조 레버를 당긴다", "action": _modal_act.bind("d_heart", {"action": "pull_auxiliary", "confirmed": true})},
	])
