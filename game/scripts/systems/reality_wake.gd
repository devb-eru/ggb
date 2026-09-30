class_name RealityWake
extends RefCounted

const CONFRONTATION := preload("res://scripts/systems/researcher_confrontation.gd")
const OWNERS := ["edgar", "mara1", "luca", "iris", "mara2"]
const EVENTS := {"edgar":"E3_4", "mara1":"E3_1", "luca":"E3_3", "iris":"E3_2", "mara2":"E3_5"}
const NAMES := {"edgar":"에드가", "mara1":"마라 1", "luca":"루카", "iris":"이리스", "mara2":"마라 2"}
const NODES := ["EDR_FAREWELL", "EDR_DISCONNECT", "EDR_WAKE_BODY", "EDR_BODY_CHECK"]
const COMPLETE := {
	"edgar":"기상 절차를 승인했습니다. 이번 명령은 제가 아니라 아가씨께서 내린 것입니다.",
	"mara1":"밖에 공구함이 있으면 13밀리부터 챙기십쇼. 아니, 다 챙기십쇼. 세상은 꼭 없는 규격부터 고장 납니다.",
	"luca":"처음 숨은... 깊게 쉬지 마세요. 짧게, 천천히... 호흡, 관절, 수분 순서로... 인계 페이지에 남겨 둘게요.",
	"iris":"우후후, 바깥의 계절은 제 정원과 다를 거예요. 이번에는 제가 아니라 당신이 먼저 보아 주세요.",
	"mara2":"밖이 재미없으면 후기 남겨! 별 하나면 찾아갈 거야! ...찾아갈 수 있으면. 내 이름도, 남겨 줘!"
}
const INCOMPLETE := {
	"edgar":"기상 절차를 수행합니다. 확인된 위험과 운영 기록은 인계 페이지에 남겼습니다.",
	"mara1":"마라 1이 마지막 먼지를 닦고 통로를 확보한 모습이 기록에 남아 있다.",
	"luca":"생체 수치는... 기록되어 있어요. 장치 해제 순서도... 인계했어요.",
	"iris":"외부 환경 모델은 실제 관측값이 아니에요. 모델이 틀릴 수 있다는 경고는 지우지 않을게요.",
	"mara2":"익명 인격 인덱스. 빠른 세 음 뒤에 한 박자 비어 있다. 이름을 대신 채우는 해설은 없다."
}
const OVERLAYS := {
	"edgar":{"responsibility_recorded":"에드가의 감사 서명이 종료 로그에 남아 있다.","authority_returned":"빈 CUSTODIAN 슬롯 옆으로 SUBJECT 서명이 남는다."},
	"mara1":{"original_attribution":"책임자명이 남은 감사 사본을 보존함에 넣는다.","protected_identifiers":"식별자를 가린 사본과 원본 해시를 함께 보존한다."},
	"luca":{"full_disclosure":"위험표 전부가 현실 수첩 인계 페이지로 전송된다.","stabilize_first":"안정화 완료 시각 뒤로 같은 위험표가 순서대로 전송된다."},
	"iris":{"external_truth":"실제 계절 확인을 먼저 부탁하는 주석이 남는다.","shelter_projection":"온실 투영을 끄는 스위치 권한이 주인공에게 넘어온다."},
	"mara2":{"merged":"한 목소리가 인덱스를 닫는다. 마지막 음이 잠깐 떨린다.","separated":"원본과 주석이 번갈아 말한다. ‘둘 다 기억해.’ 두 인덱스는 별도로 보존된다."}
}
const IRIS := {
	"inferred_only":"계절 모델과 관측값을 혼동하지 말아 주세요.",
	"denied":"그 로그의 해석에는 동의하지 않아요. 그래도 기상을 막지는 않겠어요.",
	"withheld":"감금에 가담한 책임과, 끝내 말하지 못한 부분이 남아 있어요.",
	"indirect":"당신이 사라지면 끝날 줄 알았어요. 그 바람이 옳았다는 말은 아니에요.",
	"direct_private":"둘이 있을 때 한 말은... 기억하고 있나요? 여기서 다시 말하지는 않을게요.",
	"public":"당신이 죽기를 바랐던 감정과 감금에 가담한 책임을, 모두 앞에서 인정했어요. 그 책임은 남아요."
}
const BODY := {
	"OBJ_REALITY_HAND":["손", "손가락을 굽히자 통증과 느린 떨림이 따라온다. 피부는 화면 속 손보다 무겁다.", "아픈 만큼 움직였다."],
	"OBJ_REALITY_BREATH_MONITOR":["호흡 표시기", "표시기가 짧게 3회, 멈춤, 길게 1회의 회복 안내를 보인다. 첫 호흡은 이미 시작되었다. 입력 속도로 성패를 판정하지 않는다.", "기계와 내 숨의 간격이 조금씩 달라진다."],
	"OBJ_REALITY_RESTRAINT":["고정 벨트", "비상 해제 손잡이가 이미 반쯤 풀려 있다. 손끝으로 닿는 곳이다.", "누군가는 내가 혼자 풀 수 있게 남겨 두었다."]
}

static func index(state: Dictionary) -> int:
	return int(state["loop_state"]["event_local_states"].get("EDR_FAREWELL", {}).get("index", 0))

static func farewell(state: Dictionary, owner: String) -> Dictionary:
	var servant: Dictionary = state["meta_progress"]["servants"][owner]
	var complete: bool = servant["core_event_complete"]
	var lines: Array = [{"speaker":"SYSTEM", "text":"연결 해제 전 남긴 인계 기록이다. 보존 중인 인격에게 질문을 보내는 통로는 아니다."}]
	lines.append({"speaker":NAMES[owner] if complete or owner not in ["mara1","mara2"] else "SYSTEM", "text":COMPLETE[owner] if complete else INCOMPLETE[owner]})
	var event: Dictionary = state["meta_progress"]["event_history"].get(EVENTS[owner], {})
	var outcome: String = event.get("outcome_id", "")
	var warning: bool = complete and (not OVERLAYS[owner].has(outcome) or event.get("lifecycle", "") != "completed" or not servant["researcher_record_acquired"])
	if complete and not warning: lines.append({"speaker":"SYSTEM", "text":OVERLAYS[owner][outcome]})
	if owner == "mara2" and state["meta_progress"]["knowledge_entries"].get("mara2_name_written", false):
		lines.append({"speaker":"SYSTEM", "text":"현실 수첩 인계 페이지의 이름 필드가 강조된다. 주인공이 적었던 이름과 연결된 표식이다."})
	if owner == "iris": lines.append({"speaker":"이리스", "text":IRIS[CONFRONTATION.iris_state(state)]})
	if complete:
		var bond := int(servant["bond"])
		lines.append({"speaker":"SYSTEM", "text":"기록 속 시선은 공식적인 인계 위치에 머문다." if bond < 2 else ("잠깐 시선을 맞추고 인계 물건을 손에 직접 건넨다. 말끝이 늦어진다." if bond >= 4 else "시선을 유지한 채 인계를 마친다.")})
	var alert := int(servant["alert"])
	lines.append({"speaker":"SYSTEM", "text":"확인 뒤 한 걸음 물러난다." if alert < 2 else ("가까이 남지만 제어권에는 손대지 않는다." if alert >= 4 else "기록 속에서 절차를 한 번 확인한다. 주인공에게 추가 확인을 요구하지 않는다.")})
	return {"lines":lines, "warning":warning}

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var node: String = run.get("current_node_id", "")
	if not run.get("branch_committed", false) or run.get("branch_id") != "reality" or node not in NODES: return {"ok":false,"text":"현실 기상 사건에서 이어진다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var next_node := node
	match action:
		"farewell":
			var current := index(state)
			if node != "EDR_FAREWELL" or current >= OWNERS.size() or value != OWNERS[current]: return {"ok":false,"text":"첫 미완료 인계 기록을 확인한다."}
			if farewell(state, str(value))["warning"]:
				state["meta_progress"]["knowledge_entries"]["ENDING_OUTCOME_INTEGRITY_WARNING"] = true
				state["meta_progress"]["knowledge_entries"]["ENDING_OUTCOME_INTEGRITY_WARNING_"+str(value)] = true
			state["loop_state"]["event_local_states"]["EDR_FAREWELL"] = {"index":current+1}
			if current+1 == OWNERS.size(): next_node = "EDR_DISCONNECT"
		"continue":
			if value != node or node not in ["EDR_DISCONNECT","EDR_WAKE_BODY"]: return {"ok":false,"text":"현재 감각 기록을 확인한다."}
			next_node = "EDR_WAKE_BODY" if node == "EDR_DISCONNECT" else "EDR_BODY_CHECK"
			if node == "EDR_DISCONNECT":
				state["loop_state"]["location_id"] = "R0_CRYO_CHAMBER"
				state["fracture_state"]["world_phase"] = "R0"
		"body":
			if node != "EDR_BODY_CHECK" or str(value) not in BODY: return {"ok":false,"text":"손·호흡 표시기·고정 벨트를 확인한다."}
			if not ending.has("required_interactions_seen"): ending["required_interactions_seen"] = []
			if value not in ending["required_interactions_seen"]: ending["required_interactions_seen"].append(value)
			ending["required_interactions_seen"].sort()
		"body_finish":
			var seen := 0
			for object in ending.get("required_interactions_seen", []):
				if object in BODY: seen += 1
			if node != "EDR_BODY_CHECK" or seen < 2: return {"ok":false,"text":"서로 다른 두 대상을 먼저 확인한다."}
			next_node = "EDR_FIELD_NOTEBOOK"
		_: return {"ok":false,"text":"정의되지 않은 기상 행동이다."}
	if next_node != node:
		if not ending.has("completed_nodes"): ending["completed_nodes"] = []
		if node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next_node
	return {"ok":true,"state":state,"text":""}
