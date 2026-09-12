class_name EndingEntry
extends RefCounted

const OWNERS := ["edgar", "mara1", "luca", "iris", "mara2"]
const IDENTITIES := [
	{"speaker":"에드가", "text":"에드가입니다. 수직 잠금선, 낮은 시계음. 관리 기록의 주체임을 확인합니다."},
	{"speaker":"마라 1", "text":"마라예요! 대각선 닦임 자국, 마른 솔 소리. 정비 기록은 제 거 맞슴다. 이번엔 이름표 안 헷갈렸죠?"},
	{"speaker":"루카", "text":"루카...예요. 이중 맥박과 생체 신호음... 생명 유지 기록의 담당 인격이에요... 여기 있어요."},
	{"speaker":"이리스", "text":"이리스예요. 꽃잎과 후광, 유리와 바람 소리. 환경 기록은 제 것이랍니다. 우후후... 이름은 남는군요."},
	{"speaker":"마라 2", "text":"마라 2! 겹친 액자, 이중 윤곽, 빠른 세 음! 아카이브 원본 인격 인증! 다섯 기록의 분산 백업 체크섬, 전부 일치해! 이름 빼먹지 마!"}
]
const NODES := ["ED_ALL_CEREMONY", "EDR_ENTRY", "EDR_ARCHIVE_STATUS", "EDS_ENTRY", "EDS_STABILIZE"]
const TEXT := {
	"EDR_ENTRY": "기상 절차가 확정되었다.\n코어는 선택을 다시 묻지 않는다. 손바닥 아래 종이의 마지막 획이 아직 눌려 있다.",
	"EDR_ARCHIVE_STATUS": "RESIDENT 인격 아카이브: 저전력 보존으로 전환\n인격 구성: 생체 신경 코어 + 인격 프로세스\n다섯 채널 보존 · 즉시 삭제 실행하지 않음\n무정비 보수 진단: 18개월\n정기 정비 추정: 12~20년 / 보증 아님\n현재 신체 이전: 실행 불가\n저전력 상태에서는 일상적인 대화를 지속할 수 없다. 정비용 단문 출력은 대화의 대체가 아니다.",
	"EDS_ENTRY": "안정화 루프 복원이 확정되었다.\n저택의 윤곽 아래 시설 프레임이 남아 있다. 어느 쪽도 이제는 없었던 것으로 만들지 않는다.",
	"EDS_STABILIZE": "세계 상태: S5 STABILIZED FRACTURE\n진실 기억: 유지\n주인공 기상 권한: 유지\n사용인 역할 강제: 완화\n외부 센서 연결: 읽기 전용 유지\n다섯 인격: 활동 의식 유지\n다음 수면: 주인공 확인 필요\n정상 리셋으로 돌아가지 않는다. 지금은 다음 수면을 실행하지 않는다."
}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"identity_index":0, "authority_seen":false}
	local.merge(state["loop_state"]["event_local_states"].get("ED_ALL_CEREMONY", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var source_ending: Dictionary = source["ending_run"]
	if not source_ending.get("branch_committed", false): return {"ok":false, "text":"최종 결정 이후의 장면이다."}
	var node: String = source_ending.get("current_node_id", "")
	if node not in NODES: return {"ok":false, "text":"현재 엔딩 사건에서 이어진다."}
	if (node.begins_with("EDR_") and source_ending["branch_id"] != "reality") or (node.begins_with("EDS_") and source_ending["branch_id"] != "stay"):
		return {"ok":false, "text":"저장된 분기와 사건이 일치하지 않는다."}
	if node == "ED_ALL_CEREMONY":
		for servant in source["meta_progress"]["servants"].values():
			if not servant["core_event_complete"]: return {"ok":false, "text":"전원 인증 장면의 상태를 확인한다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	if not ending.has("completed_nodes"): ending["completed_nodes"] = []
	if not ending.has("all_ceremony_seen"): ending["all_ceremony_seen"] = false
	var local := progress(state)
	var next_node := node
	match action:
		"identity":
			if node != "ED_ALL_CEREMONY" or local["identity_index"] >= OWNERS.size() or value != OWNERS[local["identity_index"]]: return {"ok":false, "text":"첫 미완료 인격의 인증을 확인한다."}
			local["identity_index"] += 1
		"authority":
			if node != "ED_ALL_CEREMONY" or local["identity_index"] != OWNERS.size() or local["authority_seen"]: return {"ok":false, "text":"다섯 인격의 인증 뒤 권한을 확인한다."}
			local["authority_seen"] = true
		"sign":
			if node != "ED_ALL_CEREMONY" or not local["authority_seen"]: return {"ok":false, "text":"이름과 권한 확인 뒤 서명을 남긴다."}
			ending["all_ceremony_seen"] = true
			next_node = "EDR_ENTRY" if ending["branch_id"] == "reality" else "EDS_ENTRY"
		"continue":
			if value != node or node == "ED_ALL_CEREMONY": return {"ok":false, "text":"현재 표시된 기록을 확인한다."}
			next_node = {"EDR_ENTRY":"EDR_ARCHIVE_STATUS", "EDR_ARCHIVE_STATUS":"EDR_FAREWELL", "EDS_ENTRY":"EDS_STABILIZE", "EDS_STABILIZE":"EDS_MEMORY_CHARTER"}[node]
			if node in ["EDR_ARCHIVE_STATUS", "EDS_STABILIZE"]:
				var channels := {}
				for owner in OWNERS: channels[owner] = "low_power" if ending["branch_id"] == "reality" else "active"
				state["meta_progress"]["knowledge_entries"]["ending_resident_channels"] = channels
			if node == "EDS_STABILIZE": state["fracture_state"]["world_phase"] = "S5"
		_: return {"ok":false, "text":"정의되지 않은 엔딩 행동이다."}
	state["loop_state"]["event_local_states"]["ED_ALL_CEREMONY"] = local
	if next_node != node:
		if node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next_node
	return {"ok":true, "state":state, "text":""}
