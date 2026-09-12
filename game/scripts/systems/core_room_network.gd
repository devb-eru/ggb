class_name CoreRoomNetwork
extends RefCounted

const ROOMS := ["greenhouse", "kitchen", "bedroom", "library"]
const NAMES := {"greenhouse": "온실", "kitchen": "주방", "bedroom": "침실", "library": "기록 내실"}
const DIRECTIONS := ["북", "동", "남", "서"]
const PORTS := {"greenhouse": "환경 제어 · 실선", "kitchen": "생명 유지 유체 · 실선", "bedroom": "신경 신호 · 점선", "library": "연출 피드백 · 점선 + 중앙 코어 요청"}
const NOTES := "[방 기능 자료]\nP5: 실내 계절은 외부 대기와 달라도 유지되었다.\nP4: 주방 아래 유체 공급의 맥박은 침실의 몸과 이어진다.\nP1·E1: 침실의 몸에서 신경 신호가 나온다.\nJ4: 기억 인덱스와 관리 권한은 기록 내실로 모인다.\n[고정 포트]\n외부 대기는 북쪽에서 들어온다. 중앙 코어의 관리 요청 단자는 서쪽에 있다.\n네 방의 출력 화살표는 방위 슬롯을 가리킨다. 내실은 중앙 요청과 별개로 계절 연출 데이터를 온실에 돌려보내야 한다."

static func progress(state: Dictionary) -> Dictionary:
	var local := {"tiles": ["library", "bedroom", "greenhouse", "kitchen"], "directions": [0, 0, 0, 0], "attempts": 0, "feedback": "", "selected": -1}
	local.merge(state["loop_state"]["event_local_states"].get("F0_A", {}), true)
	return local

static func evaluate(local: Dictionary) -> Dictionary:
	var tiles: Array = local["tiles"]
	var directions: Array = local["directions"]
	if tiles.size() != 4 or directions.size() != 4: return {"ok": false, "text": "네 방 포트를 확인한다."}
	var visited: Array = []
	var path: PackedStringArray = []
	var broken: PackedStringArray = []
	for slot in range(4):
		if tiles[slot] not in ROOMS or int(directions[slot]) not in range(4): return {"ok": false, "text": "유효하지 않은 포트다."}
		if tiles[slot] in visited: return {"ok": false, "text": "같은 방을 두 번 배치할 수 없다."}
		visited.append(tiles[slot])
		var target := int(directions[slot])
		path.append("%s %s → %s %s" % [DIRECTIONS[slot], NAMES[tiles[slot]], DIRECTIONS[target], NAMES[tiles[target]]])
		var expected_next: String = ROOMS[(ROOMS.find(tiles[slot]) + 1) % 4]
		if tiles[target] != expected_next: broken.append("%s 출력: %s의 수신 기능과 맞지 않음" % [DIRECTIONS[slot], NAMES[tiles[target]]])
	if tiles[0] != "greenhouse": broken.append("북쪽 외부 대기 입력: 환경 제어 수신 불일치")
	if tiles[3] != "library": broken.append("서쪽 중앙 코어 요청: 관리 인덱스 응답 없음")
	# Adjacent ring connectors cannot jump across or terminate on their own tile.
	for slot in range(4):
		if int(directions[slot]) != (slot + 1) % 4: broken.append("%s 회랑 연결: 출력이 다음 실물 포트에 닿지 않음" % DIRECTIONS[slot])
	return {"ok": broken.is_empty(), "text": "약한 신호 경로\n" + "\n".join(path) + ("\n물질 공급과 데이터 피드백이 한 회로로 돌아온다. 중앙 요청 포트까지 연결되었다." if broken.is_empty() else "\n\n끊긴 포트\n" + "\n".join(broken))}

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if not knowledge.get("f0_entered", false) or state["loop_state"]["location_id"] != "H0_CORE_PATH": return {"ok": false, "text": "코어 접근로에 진입한 뒤 확인한다."}
	if knowledge.get("f0_room_feedback_loop_solved", false): return {"ok": false, "text": "네 방의 연결은 이미 검증했다."}
	var local := progress(state)
	var text := ""
	match action:
		"select":
			if not value is int or value not in range(4): return {"ok": false, "text": "네 방 슬롯 중 하나를 고른다."}
			if int(local["selected"]) < 0:
				local["selected"] = value
				text = "%s 슬롯 선택. 다른 슬롯을 누르면 타일과 출력 방향을 함께 교환한다." % DIRECTIONS[value]
			else:
				var first := int(local["selected"])
				var tile: String = local["tiles"][first]
				var direction := int(local["directions"][first])
				local["tiles"][first] = local["tiles"][value]
				local["directions"][first] = local["directions"][value]
				local["tiles"][value] = tile
				local["directions"][value] = direction
				local["selected"] = -1
				text = "타일을 교환했다." if first != value else "선택을 취소했다."
		"rotate":
			if not value is int or value not in range(4): return {"ok": false, "text": "회전할 타일을 고른다."}
			local["directions"][value] = (int(local["directions"][value]) + 1) % 4
			text = "%s 타일 출력 → %s" % [DIRECTIONS[value], DIRECTIONS[local["directions"][value]]]
		"notes": text = NOTES
		"signal":
			local["attempts"] += 1
			var result := evaluate(local)
			text = result["text"]
			local["feedback"] = text
			if result["ok"]:
				knowledge["f0_room_feedback_loop_solved"] = true
				state["meta_progress"]["event_history"]["F0_A"] = {"event_id": "F0_A", "lifecycle": "completed"}
		_: return {"ok": false, "text": "정의되지 않은 회로 조작이다."}
	state["loop_state"]["event_local_states"]["F0_A"] = local
	return {"ok": true, "state": state, "text": text}
