class_name ChapterOneSession
extends RefCounted

const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const SAVE_POINT := "SAVE_CAMPAIGN_PROGRESS"
const LOCAL_KEY := "CHAPTER_ONE"
const MARKS := {"sentence": "내일 아침, 이 문장을 읽어.", "house_glyph": "창문 셋, 뾰족한 지붕, 왼쪽으로 기운 문", "ink_corner": "페이지 모서리의 잉크 한 방울"}
const CLOCK_ROOMS := {"M2_BEDROOM": "bedroom", "M1_PARLOR": "parlor", "M1_LIBRARY_OUTER": "library_outer", "M1_GREAT_CLOCK": "great_clock"}
const ROOMS := ["M2_BEDROOM", "M1_CENTRAL_HALL", "M1_SERVANT_COMMON", "M1_PARLOR", "M1_LIBRARY_OUTER", "M1_LIBRARY_INNER", "M1_GREAT_CLOCK", "M1_NORTH_ARCHIVE_HALL"]
const DOCUMENTS := {
	"edgar": "업무 장부. 아침 인사 후 외부 서고 감독. 오후 차 회수 확인. 서쪽 대시계 점검. 저녁 종 뒤 기록 내실 복귀.\n정정: '오후 차 회수 직후부터 저녁 종 직전까지'로 고침.",
	"luca": "오후 차 회수 뒤: 따뜻한 물 한 주전자, 마른 천 두 장, 손잡이가 작은 잔 하나. 전달 장소: 서쪽 대시계실.\n서명은 대시계 점검대에서 받을 것. 잔이 식기 전에 돌아올 것.",
	"mara1": "서재 복도: 오전 먼지 제거, 오후 차 회수 전 바닥 마감. 차 회수 뒤에는 도구 반납. 저녁 종 전 재진입 없음.\n사다리 바퀴에 기름을 너무 많이 칠했슴다. 정말 잘 굴러가서 제가 잡으러 뛰어갔슴다.",
	"mara2": "초상 기록 반출: 오후 차 직후 완료. 대상 인덱스 다섯. 반환 예정: 저녁 종 뒤.\n중복 아니야! 둘 다 나야!",
}
const J1_FRAGMENTS := [
	"네가 어제를 기억한다면,\n얼굴이 가리키는 시각부터 믿지는 마라.",
	"하나는 하루를 세고,\n하나는 멈춘 채 떨림을 다음 방으로 넘기며,\n하나는 목소리를 잃은 채 마지막 문을 울린다.",
	"틀린 것은 시간이 아니다.\n모두 끝났다고 믿은 뒤에도, 한 칸 남아 있는 소리다. ·",
]
const J2_TEXT := "열세 번째 소리는 문을 여는 열쇠가 아니다.\n한동안 굳어 있던 표면을 잠시 느슨하게 만드는 신호다.\n\n긴 떨림이 길을 만들고, 두 번의 짧은 반사가 갈라진 자리를 찾으며, 마지막 잔향이 바깥을 닫는다.\n\n그때 검은 표면을 지워라. 너무 강한 것은 얼룩뿐 아니라, 그 아래의 길까지 없앤다.\n부드러운 천을 쓰고, 서로를 삼키지 않는 세 재료를 먼저 확인해라."

var slot_id: String
var _game: Node
var _save: Node
var _writer: StateWriter


func _init(game: Node, save: Node, slot: String) -> void:
	_game = game
	_save = save
	slot_id = slot
	_writer = StateWriter.new(game)


func snapshot() -> Dictionary:
	return _game.get_snapshot()


func local_state(state: Dictionary = {}) -> Dictionary:
	var source := snapshot() if state.is_empty() else state
	var stored: Dictionary = source["loop_state"]["event_local_states"].get(LOCAL_KEY, {})
	var result := {"routine_done": false, "rubbed": [], "clock_locked": false, "board": CLOCK.default_board(), "roles": {}, "phase": "0", "layout_attempts": 0, "attention": 0, "inspected": [], "edgar_state": "absent", "edgar_visit_done": false, "signal_generated": false, "j1_order": [], "j1_front": [false, false, false], "wave_rotation": 90}
	result.merge(stored, true)
	return result


func known(key: String) -> bool:
	return bool(snapshot()["meta_progress"]["knowledge_entries"].get(key, false))


func stage() -> String:
	var state := snapshot()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if int(meta["journal_stage"]) >= 2:
		return "J2_COMPLETE"
	if knowledge.get("b4_waveform_acquired", false):
		return "B5"
	if local_state(state)["signal_generated"]:
		return "B4"
	if int(meta["journal_stage"]) >= 1:
		if local_state(state)["clock_locked"]:
			return "BF"
		return "B3_B" if knowledge.get("clock_network_layout_solved", false) else "B3_A"
	if knowledge.get("KN_B1_LIBRARY_WINDOW", false):
		return "J1" if state["loop_state"]["location_id"] == "M1_LIBRARY_INNER" else "B2"
	if meta["notebook_persistence_confirmed"]:
		return "B1"
	if knowledge.has("self_authored_mark"):
		return "A2" if int(state["loop_state"]["day_index"]) > int(knowledge["self_authored_mark"]["day"]) else "AS"
	return "A1"


func initialize() -> Dictionary:
	var state := snapshot()
	if String(state["reset_state"]["phase"]) != "idle":
		var reset_result := ResetCoordinator.new(_game, _save).resume_pending_reset(slot_id)
		if not reset_result.get("ok", false):
			return reset_result
		state = snapshot()
	if not bool(state["meta_progress"]["knowledge_entries"].get("PROLOGUE_COMPLETE", false)):
		return _reject("프롤로그를 마친 뒤 진입할 수 있다.")
	if state["loop_state"]["location_id"] == "M1_BEDROOM":
		state["loop_state"]["location_id"] = "M2_BEDROOM"
	state["loop_state"]["event_local_states"][LOCAL_KEY] = local_state(state)
	var last: Dictionary = local_state(state).get("last_feedback", {})
	return _commit(state, String(last.get("text", "같은 아침이다. 방의 흔적과 수첩을 비교해 본다.")), String(last.get("speaker", "주인공")))


func act(action: String, value: Variant = null) -> Dictionary:
	var state := snapshot()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var loop: Dictionary = state["loop_state"]
	var local := local_state(state)
	loop["event_local_states"][LOCAL_KEY] = local
	var room := String(loop["location_id"])
	var text := ""
	var speaker := "주인공"
	match action:
		"move":
			var target := String(value)
			if target not in available_rooms():
				return _reject("아직 갈 수 없는 장소다.")
			if not _rooms_connected(room, target, knowledge):
				return _reject("연결된 문을 통해 이동한다.")
			if room == "M1_LIBRARY_INNER" and local["edgar_state"] in ["entering", "hidden", "present"]:
				return _reject("먼저 에드가가 지나가기를 기다리거나 말을 건넨다.")
			if target == "M1_LIBRARY_INNER":
				if not knowledge.get("KN_B1_LIBRARY_WINDOW", false) or not local["routine_done"]:
					return _reject("기록 내실이 비는 구간을 확인하고 오늘의 일과를 마쳐야 한다.")
				if room not in ["M1_LIBRARY_OUTER", "M1_NORTH_ARCHIVE_HALL"]:
					return _reject("외부 서고의 내실문으로 접근한다.")
				if room == "M1_NORTH_ARCHIVE_HALL" and not knowledge.get("north_library_shortcut", false):
					return _reject("연결문 걸쇠는 안쪽에서 잠겨 있다.")
			loop["location_id"] = target
			text = "문턱을 넘는다."
		"mark":
			if room != "M2_BEDROOM" or stage() != "A1" or not MARKS.has(String(value)):
				return _reject("지금은 새 표식을 작성할 수 없다.")
			knowledge["self_authored_mark"] = {"type": String(value), "text": MARKS[String(value)], "day": int(loop["day_index"])}
			_note(knowledge, "A1", "자기 표식: %s\n다음 아침에 동일성을 확인한다." % MARKS[String(value)])
			text = "표식을 남겼다. 아직 내일의 내가 읽기 전이라 증거는 완성되지 않았다."
		"confirm_mark":
			if room != "M2_BEDROOM" or stage() != "A2":
				return _reject("표식을 남긴 뒤 잠들어 다음 아침에 비교해야 한다.")
			meta["notebook_persistence_confirmed"] = true
			if state["fracture_state"]["world_phase"] == "S0":
				state["fracture_state"]["world_phase"] = "S1"
			_note(knowledge, "A2", "같은 표식이 남았다. 방의 물리 상태는 되돌아와도 수첩의 기록은 유지된다.")
			text = "내가 쓴 표식이다. 수첩은 방과 다른 시간 위에 놓여 있다."
		"routine":
			if not knowledge.has("self_authored_mark"):
				return _reject("다음 아침과 비교할 표식을 먼저 남긴다.")
			local["routine_done"] = true
			loop["time_block"] = "evening_free"
			text = "젖은 천이 어제와 같은 호를 그린다. 책등 세 권과 다섯 이름표를 정리하고, 물이 끓는 동안 모래시계를 뒤집는다. 익숙한 일과가 끝났다."
		"read_schedule":
			if room != "M1_SERVANT_COMMON" or not meta["notebook_persistence_confirmed"] or not DOCUMENTS.has(String(value)):
				return _reject("수첩의 지속을 확인한 뒤 사용인 공용실에서 조사한다.")
			knowledge["schedule_" + String(value)] = true
			text = DOCUMENTS[String(value)]
			_note(knowledge, "B1_" + String(value), text)
		"schedule_window":
			var count := 0
			for source in ["edgar", "luca", "mara1"]:
				count += int(bool(knowledge.get("schedule_" + source, false)))
			if room != "M1_SERVANT_COMMON" or count < 2:
				return _reject("시간 표현을 교차 확인할 핵심 문서가 두 장 이상 필요하다.")
			if String(value) != "after_tea_before_bell":
				return _reject("그 시간에는 기록 내실 감독 또는 복귀 서명이 남아 있다. 차 회수와 저녁 종 사이를 비교한다.")
			knowledge["KN_B1_LIBRARY_WINDOW"] = true
			text = "오후 차를 치운 뒤, 저녁 종이 울리기 전에는 기록 내실이 비어 있다."
			_note(knowledge, "B1", text)
		"inspect_inner":
			if room != "M1_LIBRARY_INNER" or local["edgar_state"] != "absent":
				return _reject("발소리가 가까워졌다. 숨을지, 남아서 말을 걸지 정한다.")
			if String(value) not in ["desk", "index", "drawer", "alcove", "gap", "link"]:
				return _reject("알 수 없는 조사 대상이다.")
			if String(value) not in local["inspected"]:
				local["inspected"].append(String(value))
				if String(value) in ["index", "drawer"]:
					local["attention"] = int(local["attention"]) + 1
			if value == "link" and int(meta["journal_stage"]) >= 1:
				knowledge["north_library_shortcut"] = true
			var observations := {"desk": "손상된 일지와 압지 세 장. 모서리 홈과 눌림선을 맞추면 읽을 수 있을 것 같다.", "index": "색인 카드를 넘기는 소리가 문 쪽으로 선명하게 번진다.", "drawer": "서랍이 걸리며 나무가 짧게 운다.", "alcove": "점검 벽감의 안쪽이 비어 있다. 몸을 숨길 수 있다.", "gap": "마침표 뒤 한 칸의 빈 공간, 그 다음에 잉크점. 끝난 뒤에도 남아 있는 소리.", "link": "초상화 패널의 안쪽 걸쇠다. 복원된 일지와 경로를 확인해야 열 수 있다."}
			text = observations[String(value)]
			if value == "gap":
				knowledge["KN_J1_POST_COMPLETION_GAP"] = true
			if knowledge.get("north_library_shortcut", false) and value == "link":
				text = "안쪽 걸쇠를 열었다. 다음 아침에는 이 구조를 기억해 연결문을 빠르게 열 수 있다."
			var threshold := 1 if int(meta["servants"]["edgar"]["alert"]) >= 4 else 2
			if knowledge.get("schedule_mara2", false):
				threshold += 1
			if int(local["attention"]) >= threshold and not local["edgar_visit_done"]:
				local["edgar_state"] = "entering"
				text += "\n문밖에서 발소리가 멎는다. 잠금쇠가 돌아간다."
		"edgar_hide", "edgar_talk", "edgar_leave":
			if room != "M1_LIBRARY_INNER":
				return _reject("에드가는 지금 이 방에 없다.")
			if action == "edgar_hide":
				if local["edgar_state"] != "entering" or "alcove" not in local["inspected"]:
					return _reject("먼저 숨을 수 있는 점검 벽감을 확인한다.")
				local["edgar_state"] = "hidden"
				text = "벽감 안에서 숨을 고른다. 에드가가 들어와 책상과 잠금선을 확인한다."
			else:
				if local["edgar_state"] not in ["entering", "hidden"]:
					return _reject("점검은 이미 끝났다.")
				if action == "edgar_leave" and local["edgar_state"] != "hidden":
					return _reject("에드가가 대답을 기다린다.")
				if action == "edgar_talk":
					speaker = "에드가"
					text = "보고 싶은 책이 있으십니까? 열람이 끝나면 제자리에 두십시오."
					if int(meta["servants"]["edgar"]["alert"]) >= 4:
						text += "\n우연히 이 시간에 오신 것이라면, 다음에도 같은 우연이 생기지는 않겠습니까."
					var memory: Array = meta["servants"]["edgar"]["residual_memory"]
					if "B2_CAUGHT" not in memory:
						memory.append("B2_CAUGHT")
				else:
					text = "발소리가 다시 멀어진다. 에드가는 문을 닫고 나갔다. 압지와 일지는 그대로다."
				local["edgar_state"] = "absent"
				local["edgar_visit_done"] = true
		"j1_piece", "j1_flip", "j1_clear", "j1_restore":
			if room != "M1_LIBRARY_INNER" or local["edgar_state"] != "absent" or "desk" not in local["inspected"]:
				return _reject("책상의 압지를 확인하고 조용히 펼칠 자리를 확보한다.")
			if int(meta["journal_stage"]) >= 1:
				return _reject("첫 페이지는 이미 복원되어 있다.")
			if action == "j1_clear":
				local["j1_order"] = []
			elif action in ["j1_piece", "j1_flip"]:
				var index := int(value)
				if index < 0 or index > 2:
					return _reject("압지 조각을 선택한다.")
				if action == "j1_flip":
					local["j1_front"][index] = not bool(local["j1_front"][index])
				elif index not in local["j1_order"]:
					local["j1_order"].append(index)
			else:
				if local["j1_order"] != [0, 1, 2]:
					return _reject("눌림 자국이 한 줄 어긋난다. 조각은 손상되지 않았다.")
				if false in local["j1_front"]:
					return _reject("잉크가 손끝에 묻지만 문장은 드러나지 않는다. 압지의 앞뒤를 확인한다.")
				meta["journal_stage"] = 1
				knowledge["KN_J1_CLOCK_ROLES"] = true
				knowledge["KN_J1_POST_COMPLETION_GAP"] = true
				text = "\n\n".join(J1_FRAGMENTS)
				_note(knowledge, "J1", text)
		"rub_clock":
			if int(meta["journal_stage"]) < 1 or not CLOCK_ROOMS.has(room):
				return _reject("일지의 첫 페이지를 복원한 뒤 각 방의 시계에서 탁본을 뜬다.")
			var clock_id: String = CLOCK_ROOMS[room]
			if clock_id not in local["rubbed"]:
				local["rubbed"].append(clock_id)
			knowledge["clock_observed_" + clock_id] = true
			text = CLOCK.CLUES[clock_id]
			_note(knowledge, "CLOCK_" + clock_id, text)
		"board_swap", "board_rotate", "board_flip", "board_check":
			if room != "M1_GREAT_CLOCK" or local["rubbed"].size() != 4 or local["clock_locked"]:
				return _reject("당일 탁본 네 장과 움직일 수 있는 점검함이 필요하다.")
			var board: Dictionary = local["board"]
			if action == "board_swap":
				if not value is Array or value.size() != 2 or int(value[0]) not in range(4) or int(value[1]) not in range(4):
					return _reject("교환할 두 자리를 선택한다.")
				for field in ["pieces", "rotations"]:
					var old: Variant = board[field][int(value[0])]
					board[field][int(value[0])] = board[field][int(value[1])]
					board[field][int(value[1])] = old
			elif action == "board_rotate":
				if int(value) not in range(4):
					return _reject("회전할 자리를 선택한다.")
				board["rotations"][int(value)] = (int(board["rotations"][int(value)]) + 90) % 360
			elif action == "board_flip":
				board["library_back"] = not bool(board["library_back"])
			else:
				local["layout_attempts"] = int(local["layout_attempts"]) + 1
				var checked: Dictionary = CLOCK.inspect_layout(board)
				text = "일치한 구간: %d / 4" % int(checked["matched"])
				if int(local["layout_attempts"]) >= 2:
					text += "\n" + String(checked["reason"])
				if checked["ok"]:
					knowledge["clock_network_layout_solved"] = true
					knowledge["clock_verified_board"] = board.duplicate(true)
					text = "대응접실 → 외부 서고 → 서쪽 대시계. 침실은 단절. 네 조각의 배치를 검증했다."
					_note(knowledge, "B3_A", text)
		"role", "phase", "test_clock", "activate_clock":
			if room != "M1_GREAT_CLOCK" or not knowledge.get("clock_network_layout_solved", false) or local["rubbed"].size() != 4:
				return _reject("먼저 당일 탁본으로 배치를 확인한다.")
			if local["clock_locked"] or local["signal_generated"] or knowledge.get("b4_waveform_acquired", false):
				return _reject("오늘의 시계망 작동은 끝났다. 결과를 확인한다.")
			if action == "role":
				if not value is Array or value.size() != 2 or value[0] not in CLOCK.ROLES or value[1] not in CLOCK.CLOCKS:
					return _reject("역할과 시계를 확인한다.")
				for role_key in local["roles"].keys():
					if local["roles"][role_key] == value[1]:
						local["roles"].erase(role_key)
				local["roles"][value[0]] = value[1]
			elif action == "phase":
				if String(value) not in CLOCK.PHASES:
					return _reject("표시된 네 전달 시점 중 하나를 선택한다.")
				local["phase"] = String(value)
			else:
				if action == "activate_clock" and value != true:
					return _reject("봉인핀 파손 가능성을 확인한 뒤 작동한다.")
				var check: Dictionary = CLOCK.inspect_roles(local["roles"]) if action == "test_clock" else CLOCK.activate(local["roles"], local["phase"])
				text = check["text"]
				if action == "activate_clock":
					if check["ok"]:
						local["signal_generated"] = true
					else:
						local["clock_locked"] = true
						var failures: Dictionary = meta["failure_knowledge"]
						var old_failure: Dictionary = failures.get("B3_B", {})
						failures["B3_B"] = {"source_event_id": "B3_B", "status": "active", "attempts": int(old_failure.get("attempts", 0)) + 1, "category": check["category"], "verified_roles": check["verified"], "submitted_phase": local["phase"], "text": text}
						text += "\n봉인핀이 꺾였다. 오늘 다시 움직일 수 없다. 잠들면 핀은 돌아오고, 확인한 결과는 수첩에 남는다."
						_note(knowledge, "BF", text)
						var memory: Array = meta["servants"]["edgar"]["residual_memory"]
						if "B3_B_FAILURE_HEARD" not in memory:
							memory.append("B3_B_FAILURE_HEARD")
						text += "\n에드가: 같은 소리가 다시 나지 않도록 점검할 의무가 있습니다. 원인을 기록하셨다면, 점검 순서를 확인하겠습니다."
		"shortcut":
			if room != "M2_BEDROOM":
				return _reject("같은 침실에서 수첩을 펼치고 준비 동선을 시작한다.")
			if not knowledge.get("clock_network_layout_solved", false) or not meta["failure_knowledge"].has("B3_B") or local["clock_locked"]:
				return _reject("리셋 뒤 검증한 배치와 실패 기록이 있어야 준비를 축약할 수 있다.")
			local["routine_done"] = true
			local["rubbed"] = CLOCK.CLOCKS.duplicate()
			local["board"] = knowledge["clock_verified_board"].duplicate(true)
			local["roles"] = meta["failure_knowledge"]["B3_B"]["verified_roles"].duplicate(true)
			loop["time_block"] = "evening_free"
			loop["location_id"] = "M1_GREAT_CLOCK"
			text = "같은 침실에서 일과를 마쳤다. 기록해 둔 순서로 네 방의 탁본을 새로 뜨고, 검증한 배선과 역할만 다시 놓는다. 전달 시점은 직접 정한다."
		"record_wave":
			if room != "M1_GREAT_CLOCK" or not local["signal_generated"]:
				return _reject("공명통에 신호가 남아 있어야 파형을 기록할 수 있다.")
			knowledge["b4_waveform_acquired"] = true
			knowledge["thirteenth_bell_known"] = true
			if meta["failure_knowledge"].has("B3_B"):
				meta["failure_knowledge"]["B3_B"]["status"] = "resolved"
			text = "길고 낮은 진입파, 짧게 갈라지는 두 반사파, 바깥을 닫는 느린 잔류파를 투명지에 기록했다."
			_note(knowledge, "B4", text)
		"wave_rotate", "restore_j2":
			if int(meta["journal_stage"]) >= 2:
				return _reject("두 번째 페이지는 이미 복원되어 있다. 수첩에서 다시 읽는다.")
			if room != "M1_LIBRARY_INNER" or not knowledge.get("b4_waveform_acquired", false) or local["edgar_state"] != "absent":
				return _reject("기록 내실의 두 번째 페이지와 수첩의 파형이 필요하다.")
			if action == "wave_rotate":
				local["wave_rotation"] = (int(local["wave_rotation"]) + 90) % 360
			elif int(local["wave_rotation"]) != 0:
				return _reject("진입파가 긴 홈과 어긋난다. 반사파의 두 갈래와 마지막 문단을 함께 비교한다.")
			else:
				meta["journal_stage"] = 2
				knowledge["j2_restored_day"] = int(loop["day_index"])
				knowledge["KN_J2_MIRROR_WINDOW"] = true
				knowledge["KN_J2_BELL_IS_SIGNAL"] = true
				knowledge["KN_J2_WAVE_SEGMENTS"] = true
				text = J2_TEXT
				_note(knowledge, "J2", text)
		_:
			return _reject("정의되지 않은 행동이다: " + action)
	return _commit(state, text, speaker)


func sleep() -> Dictionary:
	var state := snapshot()
	if state["loop_state"]["location_id"] != "M2_BEDROOM" or not local_state(state)["routine_done"]:
		return _reject("오늘의 일과를 마친 뒤 같은 침실에서 잠든다.")
	var result := ResetCoordinator.new(_game, _save).request_normal_reset(slot_id)
	if not result.get("ok", false):
		return result
	return initialize()


func available_rooms() -> Array:
	return ROOMS


func _rooms_connected(from: String, to: String, knowledge: Dictionary) -> bool:
	if from == to:
		return true
	if from == "M1_LIBRARY_INNER" or to == "M1_LIBRARY_INNER":
		var other := to if from == "M1_LIBRARY_INNER" else from
		return other == "M1_LIBRARY_OUTER" or (other == "M1_NORTH_ARCHIVE_HALL" and knowledge.get("north_library_shortcut", false))
	return from == "M1_CENTRAL_HALL" or to == "M1_CENTRAL_HALL"


func _note(knowledge: Dictionary, id: String, text: String) -> void:
	var notes: Dictionary = knowledge.get("chapter_notebook", {})
	notes[id] = text
	knowledge["chapter_notebook"] = notes


func _commit(state: Dictionary, text: String, speaker: String = "주인공") -> Dictionary:
	var local := local_state(state)
	if not text.is_empty():
		local["last_feedback"] = {"text": text, "speaker": speaker}
	state["loop_state"]["event_local_states"][LOCAL_KEY] = local
	var inventory: Array = state["loop_state"]["inventory"]
	# Rebuild only this chapter's physical items; unrelated inventory is preserved.
	for clock_id in CLOCK.CLOCKS:
		var item_id := "RUB_" + String(clock_id).to_upper()
		inventory.erase(item_id)
		if clock_id in local["rubbed"]:
			inventory.append(item_id)
	var transaction := StringName("CH1_R%06d" % (_game.revision + 1))
	var installed := _writer.install_snapshot(state, _game.revision, transaction)
	if not installed.get("ok", false):
		return installed
	var saved: Dictionary = _save.save_snapshot(slot_id, _save_point(state), _game.get_snapshot(), _game.revision, String(transaction))
	if not saved.get("ok", false):
		_game.rollback_failed_persistence(installed["previous_snapshot"], int(installed["revision"]), transaction, &"ERR_CAMPAIGN_SAVE")
		return saved
	return {"ok": true, "text": text, "speaker": speaker, "stage": stage()}


func _save_point(_state: Dictionary) -> String:
	return SAVE_POINT


func _reject(text: String) -> Dictionary:
	return {"ok": false, "text": text}
