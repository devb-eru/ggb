class_name CoreOverlay
extends RefCounted

const LAYERS := ["B4", "C5", "D4"]
const INVESTIGATION := ["PATH", "SPLIT", "AUTH"]
const OFFSETS := [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)]

static func initial() -> Dictionary:
	return {"B4": {"turn": 0, "flip": false, "anchor": -1, "opacity": 70}, "C5": {"turn": 0, "flip": false, "anchor": -1, "opacity": 70}, "D4": {"turn": 0, "flip": false, "anchor": -1, "opacity": 70}, "locked": false, "inspected": [], "complete": false}

static func point(raw: Vector2, layer: Dictionary) -> Vector2:
	var result := Vector2(-raw.x, raw.y) if layer["flip"] else raw
	for step in range(int(layer["turn"])): result = Vector2(-result.y, result.x)
	if int(layer["anchor"]) >= 0: result += OFFSETS[int(layer["anchor"])]
	return result

static func evaluate(state: Dictionary) -> Dictionary:
	var checks: Array = []
	for layer in LAYERS: checks.append(int(state[layer]["anchor"]) == 0)
	checks.append(point(Vector2(-2, -1), state["B4"]) == Vector2(2, 1))
	var branches := true
	# These asymmetrical junctions distinguish the mirrored circuit from rotation alone.
	for pair in [[Vector2(1,2), Vector2(2,1)], [Vector2(0,3), Vector2(3,0)], [Vector2(3,0), Vector2(0,3)], [Vector2(0,-3), Vector2(-3,0)], [Vector2(-3,0), Vector2(0,-3)]]:
		branches = branches and point(pair[0], state["C5"]) == pair[1]
	checks.append(branches)
	checks.append(point(Vector2(2,1), state["C5"]) == Vector2(1,2))
	var count := checks.count(true)
	var feedback := "완전 중첩. PATH·SPLIT·AUTH 조사점이 드러난다."
	if count <= 1: feedback = "세 자료의 진동 주기가 다르다."
	elif count <= 3: feedback = "중심은 맞지만 분기선이 끊긴다."
	elif count <= 5: feedback = "빈 포트 외곽 일부가 나타난다."
	return {"matched": count, "checks": checks, "aligned": count == 6, "text": feedback}

static func act(source: Dictionary, action: String, layer: String = "", value: Variant = null) -> Dictionary:
	var state := source.duplicate(true)
	if state["complete"]: return {"ok": false, "text": "다섯 번째 포트의 구조를 이미 조사했다."}
	if action == "inspect":
		if not state["locked"]: return {"ok": false, "text": "세 자료를 먼저 완전히 중첩한다."}
		var index: int = state["inspected"].size()
		if str(value) != INVESTIGATION[index]: return {"ok": false, "text": "경로를 따라 분기를 확인하고 인증 고리를 조사한다."}
		state["inspected"].append(str(value))
		state["complete"] = state["inspected"].size() == 3
		return {"ok": true, "state": state, "text": "이름 없는 포트가 열린다." if state["complete"] else str(value) + " 조사 완료"}
	if action == "verify":
		var result := evaluate(state)
		state["locked"] = result["aligned"]
		return {"ok": true, "state": state, "text": result["text"]}
	if layer not in LAYERS: return {"ok": false, "text": "B4·C5·D4 자료 중 하나를 선택한다."}
	if action == "opacity":
		if not value is int or value < 20 or value > 100: return {"ok": false, "text": "투명도는 20~100 범위다."}
		state[layer]["opacity"] = value
	else:
		if state["locked"]: return {"ok": false, "text": "완전 중첩되어 진단판이 고정되었다."}
		match action:
			"rotate":
				if layer == "D4": return {"ok": false, "text": "D4 포트 잔상은 기준판이라 회전하지 않는다."}
				state[layer]["turn"] = (int(state[layer]["turn"]) + 1) % 4
			"flip":
				if layer == "D4": return {"ok": false, "text": "D4 포트 잔상은 기준판이라 반전하지 않는다."}
				state[layer]["flip"] = not state[layer]["flip"]
			"anchor":
				if not value is int or value not in [-1,0,1,2]: return {"ok": false, "text": "기준점을 선택한다."}
				state[layer]["anchor"] = value
			_: return {"ok": false, "text": "정의되지 않은 중첩 조작이다."}
	return {"ok": true, "state": state, "text": "자료 표시를 변경했다."}
