class_name StayStory
extends RefCounted

const NODES := ["EDS_CENTRAL_HALL","EDS_DINING_ROOM","EDS_TABLE_OBJECTS","EDS_FINAL_FRAME"]
const OWNERS := {"edgar":"에드가","mara1":"마라 1","luca":"루카","iris":"이리스","mara2":"마라 2"}
const HALL := {
	"clock":["대시계","열세 번째 칸이 숨지 않고 XIII / MANUAL로 표시된다. 시계가 다음 수면을 명령하지 않는다."],
	"schedule":["일정표","명령형 시간이 지워지고 빈칸과 제안 메모만 남아 있다. 마지막 확인자 칸은 비어 있다."],
	"door":["현관문","외부 투영임을 알리는 프레임 라벨이 있다. 이 문이 연결하는 곳은 정원까지이며 현실의 출구는 아니다."],
	"carpet":["중앙 카펫","카펫 문양 아래 시설 배선이 함께 보인다. 지우지 않은 접속 번호가 발끝을 따라간다."],
	"cord":["호출끈","누군가를 강제로 부르는 종 대신 공용 통신 채널 선택이 열린다. 응답할지는 상대가 정한다."]
}
const TABLE := {
	"mara1":["지워지지 않은 얼룩","이 얼룩은 안 지울 겁니다. 기록임다. 제가 이런 말도 하네.","마라 1이 얼룩을 닦으려다가 주인공의 시선을 보고 멈춘다."],
	"luca":["매번 달라지는 차","차 온도는... 오늘은 직접 정해 주세요. 틀려도, 다시 데우면 되니까요...","익숙한 온도의 차가 놓였다. 그래도 온도를 고르는 항목은 닫히지 않는다."],
	"iris":["창밖의 계절","봄을 남겨 둘까요? 실제 바람과 다르다는 표시는 지우지 않을게요.","이상적인 봄 옆에 MODEL 라벨이 붙어 있다. 외부 관측값과는 다른 표시다."],
	"mara2":["초상화 이름표","매일 이름표를 바꾸자! 네가 틀리면 내가 이기고, 내가 잊으면... 네가 알려 줘. 원본 인덱스는 그대로야!","마라 2가 자기 이름표를 두 번 확인한다. 위치가 바뀌어도 원본 인덱스는 남는다."],
	"edgar":["내려놓은 레이피어","내일의 취침 시각도 직접 정하시겠습니까? 레이피어는 손이 닿지 않는 곳에 두었습니다.","레이피어는 곧게 세워져 있지만 칼집 잠금은 풀려 있다. 에드가는 일정표를 확정하지 않는다."]
}
const SENTENCES := ["내일도 같은 날일 수 있다.","하지만 같은 선택일 필요는 없다."]
const RESEARCHERS := preload("res://scripts/systems/researcher_confrontation.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const OVERLAYS := {
	"original_attribution":"삭제 금지 목록에 자기 이름과 책임자명을 남겼다.","protected_identifiers":"개인 식별자 보호 절차를 공동 규칙에 추가했다.",
	"external_truth":"외부 센서값을 투영보다 먼저 표시한다.","shelter_projection":"투영과 외부값을 나란히 표시하고 언제든 끌 수 있다.",
	"full_disclosure":"생명 유지 경고 전부를 공동 열람한다.","stabilize_first":"장치 안정 확인 뒤 같은 경고를 모두 공개한다.",
	"responsibility_recorded":"감금 결정을 운영 기록에서 삭제하지 않는다.","authority_returned":"기상과 취침의 최종 확인자는 주인공이다.",
	"merged":"현재 기억과 돌아온 주석을 한 인덱스로 유지한다.","separated":"두 액자를 따로 보존하고 교차 링크를 남긴다. 두 목소리가 위치 바꾸기를 제안한다."
}

static func table_lines(state: Dictionary, owner: String) -> Array:
	var complete: bool = state["meta_progress"]["servants"][owner]["core_event_complete"]
	var lines: Array = [{"speaker":OWNERS[owner] if complete else "SYSTEM","text":TABLE[owner][1 if complete else 2]}]
	if complete and not WAKE.farewell(state,owner)["warning"]:
		var outcome: String = state["meta_progress"]["event_history"][WAKE.EVENTS[owner]]["outcome_id"]
		lines.append({"speaker":"SYSTEM","text":OVERLAYS[outcome]})
	if owner == "iris":
		var responses := {"inferred_only":"외부 센서값과 연출값을 비교할 수 있어요.","denied":"그 해석에는 동의하지 않아요. 그래도 계절 변경 권한은 돌려드려요.","withheld":"말하지 못한 부분이 있어도 변경 이력은 모두 공개할게요.","indirect":"계절 장치를 멈출 권한도 공동 규칙에 넣어요.","direct_private":"둘이 나눈 말은 공동 규칙의 명분으로 이용하지 않을게요.","public":"모두 앞에서 인정한 책임은 남아요. 그 책임을 지우지 않고 규칙을 써요."}
		lines.append({"speaker":"이리스","text":responses[RESEARCHERS.iris_state(state)]})
	return lines

static func progress(state: Dictionary) -> Dictionary:
	var local := {"hall":[],"table":[],"written":[],"tea":"usual","elapsed":0}
	local.merge(state["loop_state"]["event_local_states"].get("STAY_STORY",{}),true)
	# JSON numbers may reload as floats; membership must stay idempotent.
	var written: Array = []
	for value in local["written"]:
		if (value is int or value is float) and int(value) == value and int(value) in [0,1] and int(value) not in written: written.append(int(value))
	written.sort()
	local["written"] = written
	return local

static func seating(state: Dictionary) -> String:
	var count := 0
	for owner in OWNERS:
		if state["meta_progress"]["servants"][owner]["core_event_complete"]: count += 1
	var text := "주인공만 앉는다. 양옆에 선 인물도 퇴장과 착석을 선택할 수 있다." if count < 2 else ("다섯 인물이 각자의 이름과 경계를 유지한 채 앉는다." if count == 5 else ("네 인물이 앉는다. 빈 자리에는 기능 패널 대신 이름표가 남는다." if count == 4 else "관계 완료 인물은 앉고, 다른 인물은 자신이 고른 일을 하며 왕래한다."))
	for owner in OWNERS:
		text += "\n" + OWNERS[owner] + (": 앉을 자리를 직접 고른다." if count >= 2 and state["meta_progress"]["servants"][owner]["core_event_complete"] else ": 서 있거나 이동할 자리를 직접 고른다.")
	return text

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var node: String = run.get("current_node_id","")
	if not run.get("branch_committed",false) or run.get("branch_id") != "stay" or node not in NODES: return {"ok":false,"text":"잔류의 후속 저녁에서 확인한다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var local := progress(state)
	var next := node
	match action:
		"channel":
			if node != "EDS_CENTRAL_HALL" or str(value) not in OWNERS: return {"ok":false,"text":"공용 통신 채널을 선택한다."}
			local["channel"] = value
			if "cord" not in local["hall"]: local["hall"].append("cord")
		"hall":
			if node != "EDS_CENTRAL_HALL" or str(value) not in HALL: return {"ok":false,"text":"중앙홀의 대상을 확인한다."}
			if value not in local["hall"]: local["hall"].append(value)
		"dine":
			if node != "EDS_CENTRAL_HALL": return {"ok":false,"text":"중앙홀에서 식당으로 간다."}
			next = "EDS_DINING_ROOM"
			state["loop_state"]["location_id"] = "M1_DINING_ROOM"
		"sit":
			if node != "EDS_DINING_ROOM": return {"ok":false,"text":"식당의 자리를 확인한다."}
			next = "EDS_TABLE_OBJECTS"
		"table":
			if node != "EDS_TABLE_OBJECTS" or str(value) not in TABLE: return {"ok":false,"text":"식탁의 오브젝트를 확인한다."}
			if value not in local["table"]: local["table"].append(value)
			if WAKE.farewell(state,str(value))["warning"]: state["meta_progress"]["knowledge_entries"]["ENDING_OUTCOME_INTEGRITY_WARNING"] = true
		"tea":
			if node != "EDS_TABLE_OBJECTS" or str(value) not in ["warm","hot"]: return {"ok":false,"text":"차의 온도를 고른다."}
			local["tea"] = value
		"write":
			if node != "EDS_TABLE_OBJECTS" or not value is int or value not in [0,1]: return {"ok":false,"text":"수첩의 두 문장을 직접 선택해 쓴다."}
			if value not in local["written"]: local["written"].append(value)
			local["written"].sort()
			if local["written"].size() == 2:
				var seen: Array = ending.get("required_interactions_seen",[]).duplicate()
				if "OBJ_STAY_NOTEBOOK" not in seen: seen.append("OBJ_STAY_NOTEBOOK")
				seen.sort()
				ending["required_interactions_seen"] = seen
		"final":
			if node != "EDS_TABLE_OBJECTS" or local["written"].size() != 2: return {"ok":false,"text":"수첩의 두 문장을 먼저 쓴다."}
			for required in ["EDS_MEMORY_CHARTER","EDS_APPEARANCE_CONTROL","EDS_AUTONOMY_CHARTER"]:
				if required not in ending["completed_nodes"]: return {"ok":false,"text":"세 원칙 확인이 필요하다."}
			next = "EDS_FINAL_FRAME"
		"tick":
			if node != "EDS_FINAL_FRAME": return {"ok":false,"text":"마지막 저녁 장면이 아니다."}
			local["elapsed"] = mini(int(local["elapsed"])+1,2)
		"finish":
			if node != "EDS_FINAL_FRAME" or local["elapsed"] < 2: return {"ok":false,"text":"각자가 선택한 자리와 행동을 확인한다."}
			next = "CREDITS_STAY"
		_: return {"ok":false,"text":"정의되지 않은 저녁 행동이다."}
	state["loop_state"]["event_local_states"]["STAY_STORY"] = local
	if next != node:
		if node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next
	return {"ok":true,"state":state,"text":""}
