class_name EndingDecision
extends RefCounted

const CONFIRMATIONS := {
	"reality": "기상 절차를 실행한다.\n외부 신체로 깨어나며 다섯 인격은 자동 저전력 보존된다. 외부 환경·장기 생존·보존 설비 수명·미래 이전 기반은 보장되지 않는다.",
	"stay": "안정화 루프를 복원한다.\n현재 기억과 다섯 인격의 활동 의식을 유지하며 루프 제어권을 돌려받는다. 시설 수명·감각 변화·외부 신체 자원·외부 회복 기회는 보장되지 않는다."
}
const MONOLOGUES := {
	"reaffirmed": "그때 기울었던 쪽을 지금 선택한다.",
	"revised": "생각은 달라졌다. 지금의 선택은 이것이다.",
	"formed": "이제 정한다."
}

static func commit(source: Dictionary, decision: String) -> Dictionary:
	var knowledge: Dictionary = source["meta_progress"]["knowledge_entries"]
	var local: Dictionary = source["loop_state"]["event_local_states"].get("F3", {})
	if decision not in CONFIRMATIONS or source["ending_run"]["final_decision"] != "unset":
		return {"ok": false, "text": "아직 확정하지 않은 두 절차 중 하나를 확인한다."}
	if not knowledge.get("F3_complete", false) or not knowledge.get("subject_authority_restored", false) or not source["fracture_state"].get("final_sleep_lock", false) or not local.get("choice_open", false):
		return {"ok": false, "text": "장치 조사와 최종 권한 확인을 먼저 마친다."}
	var state := source.duplicate(true)
	var intent: String = knowledge.get("f0_provisional_intent", "undecided")
	var relation := "formed" if intent == "undecided" else ("reaffirmed" if intent == decision else "revised")
	var ending: Dictionary = state["ending_run"]
	ending["final_decision"] = decision
	ending["selected_ending"] = decision
	ending["final_choice_relation"] = relation
	ending["branch_committed"] = true
	ending["branch_id"] = decision
	ending["current_node_id"] = "EDR_ENTRY" if decision == "reality" else "EDS_ENTRY"
	var all_complete := true
	for servant in state["meta_progress"]["servants"].values():
		if not servant["core_event_complete"]: all_complete = false
	if all_complete: ending["current_node_id"] = "ED_ALL_CEREMONY"
	state["loop_state"]["event_local_states"]["F3"]["choice_open"] = false
	state["loop_state"]["location_id"] = "H0_CORE_CHAMBER"
	state["meta_progress"]["event_history"]["EDC"] = {"event_id": "EDC", "lifecycle": "completed"}
	return {"ok": true, "state": state, "text": MONOLOGUES[relation]}
