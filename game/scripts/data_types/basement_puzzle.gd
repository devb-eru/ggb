class_name BasementPuzzle
extends Resource

const AXES := ["line", "branch", "ring"]
const AXIS_NAMES := {"line": "직선축", "branch": "분기축", "ring": "환형축"}
const DEPTHS := {"line": 2, "branch": 1, "ring": 3}
const RING_TARGET := [1, 2, 3]
const HANDLES := {"A": [1, 1, 0], "B": [0, 1, 1], "C": [0, 0, 1]}


func inspect_overlay(rotation: int, flipped: bool, anchor: String) -> Dictionary:
	var valid := posmod(rotation, 360) == 270 and flipped and anchor == "great_clock"
	return {"ok": valid, "text": "세 기준점과 지하 좌표가 함께 맞는다. 직선 II → 분기 I → 환형 III." if valid else "거울 자료의 방향과 집의 방향이 아직 어긋난다. 세 기준점과 글자 방향을 함께 비교한다.", "depths": DEPTHS.duplicate() if valid else {}}


func axis_default() -> Dictionary:
	return {"depths": {"line": 1, "branch": 1, "ring": 1}, "pushed": [], "locked": false, "open": false, "reverse_warning_seen": false, "failure": {}}


func axis_action(previous: Dictionary, action: String, value: Variant = null, confirmed: bool = false) -> Dictionary:
	var state := previous.duplicate(true)
	if state["locked"]: return _rejected(previous, "압력핀이 내려갔다. 같은 침실에서 잠든 뒤 다시 준비한다.")
	if state["open"]: return _rejected(previous, "지하창고 문이 이미 열렸다.")
	var text := ""
	match action:
		"depth":
			if not value is Array or value.size() != 2 or value[0] not in AXES or int(value[1]) not in [1, 2, 3]:
				return _rejected(previous, "축과 깊이 홈 1·2·3을 선택한다.")
			if value[0] in state["pushed"]: return _rejected(previous, "이미 밀어 넣은 축은 오늘 되돌릴 수 없다.")
			state["depths"][value[0]] = int(value[1])
		"push":
			var axis := String(value)
			if axis not in AXES or axis in state["pushed"]: return _rejected(previous, "아직 밀지 않은 축을 선택한다.")
			if not confirmed: return _rejected(previous, "압력핀은 축을 민 뒤 되돌릴 수 없다. 깊이를 확인하고 확정한다.")
			var expected: String = AXES[state["pushed"].size()]
			if axis != expected:
				_fail_axis(state, "order_wrong", axis, "압력이 역류하며 핀이 내려간다. 먼저 통과한 축의 기록은 남는다.")
			elif state["depths"][axis] != DEPTHS[axis]:
				_fail_axis(state, "depth_wrong", axis, "압력이 허용 홈을 벗어났다. 오늘의 장치가 잠긴다.")
			else:
				state["pushed"].append(axis)
				text = AXIS_NAMES[axis] + "의 게이지가 안정된다. 손바닥보다 치아에 압력이 먼저 닿는다."
		"central":
			if state["pushed"] != AXES: return _rejected(previous, "세 축의 압력을 먼저 안정시킨다.")
			if String(value) not in ["clockwise", "counterclockwise"]: return _rejected(previous, "중앙 손잡이 방향을 선택한다.")
			if value == "counterclockwise":
				if not state["reverse_warning_seen"]:
					state["reverse_warning_seen"] = true
					text = "역회전 방지턱에 닿았다. 아직 멈출 수 있다. 강행하면 중앙 잠금이 내려간다."
				elif confirmed:
					_fail_axis(state, "direction_wrong", "central", "역방향을 강행하자 중앙 잠금이 내려간다.")
				else:
					text = "손잡이에서 힘을 뺀다. 시계 방향을 다시 선택할 수 있다."
			elif confirmed:
				state["open"] = true
				text = "중앙 손잡이를 시계 방향으로 반 바퀴 돌린다. 세 압력이 균형을 이루고 지하창고 문이 열린다."
			else: return _rejected(previous, "시계 방향 반 바퀴 실행을 확인한다.")
		_:
			return _rejected(previous, "알 수 없는 축 조작이다.")
	if state["locked"]: text = state["failure"]["text"]
	return {"ok": true, "state": state, "text": text, "hard_failure": state["locked"]}


func _fail_axis(state: Dictionary, category: String, axis: String, text: String) -> void:
	var verified := {}
	for item in state["pushed"]: verified[item] = DEPTHS[item]
	state["locked"] = true
	state["failure"] = {"source_event_id": "D1", "category": category, "axis": axis, "submitted_depth": state["depths"].get(axis, 0), "verified_depths": verified, "text": text}


func heart_default() -> Dictionary:
	return {"rings": [0, 0, 0], "fixed": false, "unlock_used": false, "wind": 0, "stable_attempt_seen": false, "auxiliary_seen": false, "filter_off": false}


func heart_action(previous: Dictionary, action: String, value: Variant = null, confirmed: bool = false) -> Dictionary:
	var state := previous.duplicate(true)
	if state["filter_off"]: return _rejected(previous, "위장 필터는 이미 해제되었다.")
	var text := ""
	match action:
		"turn", "reset":
			if state["fixed"] or int(state["wind"]) > 0: return _rejected(previous, "링이 고정되어 있다. 기동 전이라면 고정을 해제할 수 있다.")
			if action == "reset": state["rings"] = [0, 0, 0]
			elif HANDLES.has(String(value)):
				for index in range(3): state["rings"][index] = (int(state["rings"][index]) + HANDLES[String(value)][index]) % 4
				text = {"A": "외곽과 중간 링이 함께 움직인다.", "B": "중간과 안쪽 링이 함께 움직인다.", "C": "안쪽 링만 움직인다."}[String(value)]
			else: return _rejected(previous, "표시된 손잡이를 선택한다.")
		"fix":
			if state["rings"] != RING_TARGET: return _rejected(previous, "XIII 홈, 분기 접점, 최하단 심장 문양이 아직 맞지 않는다.")
			state["fixed"] = true
			text = "세 문양을 고정했다. 정상 레버를 감을 수 있다."
		"unfix":
			if not state["fixed"] or state["unlock_used"] or int(state["wind"]) > 0: return _rejected(previous, "기동 전 고정 해제는 한 번만 가능하다.")
			state["fixed"] = false
			state["unlock_used"] = true
		"wind":
			if not state["fixed"]: return _rejected(previous, "링을 먼저 정렬하고 고정한다.")
			if int(state["wind"]) >= 12: return _rejected(previous, "정상 레버는 XII에서 멈춘다.")
			state["wind"] = int(state["wind"]) + 1
			text = "정상 레버가 한 칸 감긴다."
		"stabilize":
			if int(state["wind"]) != 12: return _rejected(previous, "정상 레버를 XII까지 감아야 한다.")
			state["stable_attempt_seen"] = true
			text = "STABLE. 고딕 저택의 윤곽이 잠깐 반듯해졌다가 준비 상태로 돌아온다. 끝난 뒤 한 칸이 아직 남아 있다."
		"inspect_auxiliary":
			if not state["stable_attempt_seen"]: return _rejected(previous, "정상 안정화 절차의 결과를 먼저 확인한다.")
			state["auxiliary_seen"] = true
			text = "패널 뒤에 보조 레버가 있다. 정상 절차 바깥의 입력이다."
		"pull_auxiliary":
			if not state["auxiliary_seen"] or not state["fixed"] or int(state["wind"]) != 12: return _rejected(previous, "보조 레버와 현재 기동 상태를 확인한다.")
			if not confirmed: return _rejected(previous, "이 입력 뒤에는 현재 위장 상태를 유지할 수 없다. 아직 당기지 않을 수 있다.")
			state["filter_off"] = true
			text = "XIII. CAMOUFLAGE FILTER OFF. 벽의 안쪽에서 낯선 공간이 드러난다."
		_:
			return _rejected(previous, "알 수 없는 심장 조작이다.")
	return {"ok": true, "state": state, "text": text, "filter_off": state["filter_off"]}


func _rejected(state: Dictionary, text: String) -> Dictionary:
	return {"ok": false, "state": state.duplicate(true), "text": text}
