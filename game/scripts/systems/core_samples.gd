class_name CoreSamples
extends RefCounted

const ROOMS := ["greenhouse", "kitchen", "bedroom", "library"]
const NAMES := {"greenhouse": "온실", "kitchen": "주방", "bedroom": "침실", "library": "기록 내실"}
const SAMPLES := {
	"greenhouse": [
		{"label": "외부 대기 수치", "trace": "센서값이 실내 계절과 무관하게 변한다. 연결선은 외부 흡입구에서 환경 조절기를 지나 생명 유지 공급으로 이어진다."},
		{"label": "꽃향기 설정", "trace": "꽃이 없는 화면에서도 향 이름은 같은 순서로 반복된다. 출력은 온실 장면의 감각 효과에서 끝난다."}],
	"kitchen": [
		{"label": "생명 유지 유체 흐름", "trace": "두 번의 낮은 맥박 뒤 바닥 아래 응답이 온다. 파이프 경로는 주방을 지나 침실 냉각 장치에 닿는다."},
		{"label": "차 메뉴 반복 기록", "trace": "메뉴 날짜는 바뀌지만 같은 차 이름으로 되돌아온다. 출력선은 찻잔의 향과 온도 표현으로 끝난다."}],
	"bedroom": [
		{"label": "현재 생체 신호", "trace": "주인공의 움직임을 멈춰도 미세한 신호는 계속된다. 침실 캡슐의 신경 입력이 기록 내실로 전송된다."},
		{"label": "아가씨 역할 애니메이션", "trace": "매번 같은 순간에 눈을 깜빡인다. 프레임을 멈추면 값도 멈춘다. 연결 끝은 거울 속 표층 인물이다."}],
	"library": [
		{"label": "지속 기억 인덱스", "trace": "서가가 리셋되어도 인덱스의 이전 항목은 남는다. 신경 입력과 인격 저장 영역을 연결해 현재 인격의 연속성을 유지한다."},
		{"label": "고딕 장서 목록", "trace": "표지와 책등을 바꾸는 명령이다. 연결선은 고딕 서가의 배치에서 끝나고 인격 저장 영역에 닿지 않는다."}],
}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"selected": {}, "inspected": [], "verified": [], "mistakes": 0, "hint_seen": false, "feedback": ""}
	local.merge(state["loop_state"]["event_local_states"].get("F0_B", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if not knowledge.get("f0_room_feedback_loop_solved", false) or state["loop_state"]["location_id"] != "H0_CORE_PATH": return {"ok": false, "text": "네 방 회로를 먼저 검증한다."}
	if knowledge.get("f0_system_samples_verified", false): return {"ok": false, "text": "네 시스템 표본은 이미 검증했다."}
	var local := progress(state)
	var text := ""
	if action == "inspect":
		if not value is Array or value.size() != 2 or value[0] not in ROOMS or not value[1] is int or value[1] not in [0, 1]: return {"ok": false, "text": "방과 표본을 선택한다."}
		var room: String = value[0]
		var index: int = value[1]
		local["selected"][room] = index
		var key := "%s:%d" % [room, index]
		if key not in local["inspected"]: local["inspected"].append(key)
		text = NAMES[room] + " · " + SAMPLES[room][index]["label"] + "\n" + SAMPLES[room][index]["trace"]
	elif action == "send":
		var room := str(value)
		if room not in ROOMS or not local["selected"].has(room): return {"ok": false, "text": "표본의 연결을 먼저 조사한다."}
		if room in local["verified"]: return {"ok": false, "text": "이 방의 유지 채널은 이미 검증했다."}
		if int(local["selected"][room]) == 0:
			local["verified"].append(room)
			text = NAMES[room] + ": MAINTENANCE DATA · 실제 유지 데이터\n검증된 채널 %d / 4" % local["verified"].size()
		else:
			local["mistakes"] += 1
			text = NAMES[room] + ": PRESENTATION DATA · 표현용 데이터 반환\n표본과 다른 검증 채널은 손상되지 않았다. 연결 끝을 다시 조사할 수 있다."
			if int(local["mistakes"]) >= 3 and not local["hint_seen"]:
				local["hint_seen"] = true
				text += "\n주인공: 몸을 유지하는 것과 저택을 연출하는 것을 나눠 봐야 해."
		if local["verified"].size() == 4:
			knowledge["f0_system_samples_verified"] = true
			state["meta_progress"]["event_history"]["F0_B"] = {"event_id": "F0_B", "lifecycle": "completed"}
			text += "\n4 CHANNELS VERIFIED / ACCESS DENIED\n네 유지 채널 검증 완료 / 접근 권한 없음\n낮은 맥박은 안정되었지만 문은 열리지 않는다. 네 개의 연결선 옆에 이름 없는 빈자리가 남는다."
	else: return {"ok": false, "text": "정의되지 않은 표본 조작이다."}
	local["feedback"] = text
	state["loop_state"]["event_local_states"]["F0_B"] = local
	return {"ok": true, "state": state, "text": text}
