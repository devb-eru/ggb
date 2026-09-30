class_name LastEvening
extends RefCounted

const OWNERS := ["edgar", "mara1", "luca", "iris", "mara2"]
const EVENTS := ["E3_4", "E3_1", "E3_3", "E3_2", "E3_5"]
const NAMES := ["에드가 · 수직선", "마라 1 · 대각선", "루카 · 이중 맥박", "이리스 · 꽃잎", "마라 2 · 이중 액자"]
const QUESTIONS := {
	"wish": "나한테 무엇을 바라고 있어요?",
	"leave": "내가 떠나면 여러분은 어떻게 돼요?",
	"stay": "내가 남으면 무엇이 달라져요?",
}
const ANSWERS := {
	"wish": "에드가: 안전을 확보하고 싶습니다. 그렇다고 귀하의 답을 대신 정할 권한은 없습니다.\n루카: 다치지 않으셨으면... 해요. 제 바람과 아가씨의 결정은... 같은 것이 아니니까요.",
	"leave": "루카: 여기 남은 생체 신경 코어의 유지가 바로 끝나는 건... 아니에요. 다만 얼마나 오래 가능한지, 바깥에서 무엇을 만날지는... 보장할 수 없어요.\n에드가: 귀하의 기상과 저희의 육체 복원은 별개의 절차입니다.",
	"stay": "에드가: 이전의 강제 기동을 정당화하는 선택이 아닙니다. 남는다면 귀하가 알고 동의한 안정화 절차여야 합니다.\n루카: 익숙한 아침이어도... 모르던 때로 돌아가는 건 아니에요.",
}
const INSERTS := {
	"edgar": "에드가: 강제 기동을 막지 않았고, 돌려드릴 권한을 붙잡았습니다. 관리였다는 말로 책임을 지우지 않겠습니다.",
	"mara1": "마라 1: 고친 손이 지운 손이기도 했슴다. 스패너만 닦는다고 없어지는 건 아니더라고요.",
	"luca": "루카: 위험을 말하지 않으면... 보호할 수 있을 줄 알았어요. 결정할 시간을 제가 가져간 건데...",
	"iris": "이리스: 우후후... 돌봐 주고 싶다는 말 안에, 제 바람도 섞여 있었네요. 오늘은 당신의 말부터 들을게요.",
	"mara2": "마라 2: 남의 이름은 다 외워 놓고 내 이름만 자꾸 확인했어! ...지금은 한 번만 물어볼게. 기억해 줄 거지?",
}
const DISTANCE := {
	"edgar": "에드가: 최소 접근 절차를 확인했습니다. 코어 경로까지 안내하겠습니다.",
	"mara1": "마라 1: 배선은 버티고 있슴다. 저녁에 정전은 없을 겁니다! ...아마 같은 말은 안 붙일게요.",
	"luca": "루카: 지금 생존 신호는... 유지되고 있어요. 외부 안전까지 뜻하는 건... 아니에요.",
	"iris": "이리스: 환경 전력 로그는 확인할 수 있어요. 창밖의 계절로 바깥 안전을 판단하지는 말아요.",
	"mara2": "익명 인덱스: 기록 채널 응답 정상. 사용 가능한 사건 인덱스를 제공합니다.",
}
const OVERLAYS := {
	"responsibility_recorded": "에드가가 감사 로그를 식탁에 둔다.",
	"authority_returned": "에드가가 비어 있는 SUBJECT 슬롯을 주인공 쪽으로 돌린다.",
	"original_attribution": "마라 1의 기록에 모든 책임자 이름이 남아 있다.",
	"protected_identifiers": "마라 1의 기록에서 보호 대상 식별자는 가려져 있다.",
	"full_disclosure": "루카가 생존 신호 옆에 위험 수치도 나란히 놓는다.",
	"stabilize_first": "루카가 안정화 완료 시각을 먼저 보여 준다. 위험 기록은 그 아래 남아 있다.",
	"external_truth": "이리스 앞의 계절 표시는 실제 외부 센서값이다.",
	"shelter_projection": "이리스 앞의 투영 계절은 채도를 낮췄다. 투영이라는 표시는 지우지 않는다.",
	"merged": "마라 2의 한 목소리에 잠깐 낯선 억양이 섞인다.",
	"separated": "마라 2의 두 인덱스가 서로의 문장을 확인하며 교차 응답한다.",
}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"entered": false, "seated": false, "question": "", "seen": []}
	local.merge(state["loop_state"]["event_local_states"].get("E5", {}), true)
	return local

static func tier(state: Dictionary) -> String:
	var count := 0
	for owner in OWNERS:
		if state["meta_progress"]["servants"][owner]["core_event_complete"]: count += 1
	return "ALL" if count == 5 else ("HIGH" if count == 4 else ("MID" if count >= 2 else "LOW"))

static func scene(state: Dictionary) -> String:
	var variant := tier(state)
	var text := "주인공이 북쪽 정면석에 앉는다."
	match variant:
		"LOW": text += " 사용인들은 업무 위치에 서 있다. 식기 소리가 멎고 긴 침묵이 남는다."
		"MID": text += " 이야기를 나눈 사용인들은 앉고, 나머지는 서비스 경계에 선다. 가까워진 몇 사람의 선이 닿지만 하나로 섞이지 않는다."
		"HIGH": text += " 네 사람이 앉는다. 남은 의자에도 원래 문양이 있다. 그 주인은 출입문 곁에서 이곳을 보고 있다."
		"ALL": text += " 다섯 자리에 이름표가 놓였다. 주인공이 바라보자 마지막까지 서 있던 에드가도 앉는다."
	for index in range(5):
		var owner: String = OWNERS[index]
		var complete: bool = state["meta_progress"]["servants"][owner]["core_event_complete"]
		text += "\n" + String(INSERTS[owner] if complete else DISTANCE[owner])
		if owner == "iris" and complete:
			var iris: Dictionary = state["meta_progress"]["servants"]["iris"]
			if int(iris["bond"]) >= 4:
				text += "\n이리스: 아까 둘이 나눈 말을, 여기서 다른 사람의 말로 바꾸지는 않을게요."
			elif int(iris["bond"]) >= 2:
				text += "\n이리스: 그때의 계절이 그리웠어요. 당신이 바라는 계절까지 같다고 생각해서는 안 됐겠죠."
			else:
				text += "\n이리스는 환경 전력 로그를 접는다. 더 사적인 말은 덧붙이지 않는다."
		if complete:
			var outcome: String = state["meta_progress"]["event_history"].get(EVENTS[index], {}).get("outcome_id", "")
			if OVERLAYS.has(outcome): text += "\n" + String(OVERLAYS[outcome])
	if variant == "ALL": text += "\n마라 2: 에드가, 마라 1, 루카, 이리스... 그리고 나는?\n다섯 이름표의 문양은 경계를 유지한 채 한 식탁에 남는다. 누구도 다른 사람의 책임을 대신 용서하지 않는다."
	return text

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var local := progress(state)
	var text := ""
	if not knowledge.get("J4_complete", false) or not (meta["servants"]["edgar"]["core_event_complete"] or knowledge.get("edgar_minimum_access", false)):
		return {"ok": false, "text": "일지와 최소 접근 절차를 먼저 확인한다."}
	if knowledge.get("e5_locked_in", false): return {"ok": false, "text": "저녁의 결산은 이미 마쳤다."}
	match action:
		"enter":
			if local["entered"]: return {"ok": false, "text": "이미 저녁 자리에 도착했다."}
			local["entered"] = true
			state["loop_state"]["location_id"] = "M1_DINING_ROOM"
			meta["event_history"]["E5"] = {"event_id": "E5", "lifecycle": "active", "variant_id": tier(state)}
			text = "중앙홀의 시계는 저녁인데 창밖은 아침의 같은 프레임이다.\n에드가: 저녁 준비가 되었습니다."
			if tier(state) in ["HIGH", "ALL"]: text += " 자리에 가셔도 괜찮겠습니까?"
			text += "\n식당 문이 열린다. 긴 식탁의 절반은 목재, 절반은 생명 유지 프레임이다.\n루카: 음식은... 향과 온도, 식감 데이터예요. 오늘은... 숨기지 않을게요."
		"inspect":
			if not local["entered"]: return {"ok": false, "text": "식당에 먼저 들어간다."}
			match str(value):
				"table": text = "목재와 금속이 맞닿은 경계에 손끝을 댄다. 따뜻한 접시 아래 프레임이 일정하게 진동한다. 배고픔을 달래는 감각과 바깥 몸의 생존은 같은 일이 아니다."
				"seats": text = "북쪽 정면은 내 자리. 왼쪽에는 이리스와 마라 2, 오른쪽에는 루카와 마라 1. 출입문 쪽 에드가의 자리에는 수직선이 있다. 사용인의 의자는 내 착석 지점이 아니다."
				"hall":
					state["loop_state"]["location_id"] = "M1_CENTRAL_HALL"
					text = "홀로 돌아와 시계를 본다. 저녁을 가리키는 바늘 아래 아침빛이 멈춰 있다. 종료한 관계 사건을 다시 시작할 수는 없다."
				"dining":
					state["loop_state"]["location_id"] = "M1_DINING_ROOM"
					text = "식당의 주인공 자리로 돌아온다. 아무도 대답을 재촉하지 않는다."
				_: return {"ok": false, "text": "확인할 대상을 고른다."}
			if str(value) not in local["seen"]: local["seen"].append(str(value))
		"sit":
			if not local["entered"] or local["seated"] or state["loop_state"]["location_id"] != "M1_DINING_ROOM": return {"ok": false, "text": "식당의 자기 자리에서 시작한다."}
			local["seated"] = true
			text = scene(state)
		"question":
			if not local["seated"] or not String(local["question"]).is_empty() or not QUESTIONS.has(str(value)): return {"ok": false, "text": "공동 질문은 하나만 고른다."}
			local["question"] = str(value)
			text = "주인공: " + String(QUESTIONS[str(value)]) + "\n" + String(ANSWERS[str(value)])
		"finish":
			if value != true or String(local["question"]).is_empty(): return {"ok": false, "text": "대화를 마친 뒤 준비 여부를 직접 확인한다."}
			knowledge["e5_locked_in"] = true
			knowledge["all_servants_complete"] = tier(state) == "ALL"
			var complete: Array = []
			for owner in OWNERS:
				if meta["servants"][owner]["core_event_complete"]: complete.append(owner.to_upper())
			meta["event_history"]["E5"] = {"event_id": "E5", "lifecycle": "completed", "variant_id": tier(state), "completed_owner_ids": complete}
			text = "이 저녁의 말을 가지고 코어 접근 준비를 마친다. 아직 남을지 떠날지는 정하지 않았다."
		_: return {"ok": false, "text": "정의되지 않은 저녁 행동이다."}
	state["loop_state"]["event_local_states"]["E5"] = local
	return {"ok": true, "state": state, "text": text}
