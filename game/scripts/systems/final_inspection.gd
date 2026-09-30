class_name FinalInspection
extends RefCounted

const OBJECTS := {
	"wake":"기상 절차\n확정: 외부 신체 연결, 현재 생존 신호, 다섯 인격의 자동 저전력 보존.\n불확정: 외부 장기 생존, 다른 생존자, 귀환과 미래 신체 이전 가능성. 같은 코어 상태로 즉시 돌아오는 것은 보장되지 않는다.\n손등에 닿는 공기는 먼지와 금속 냄새를 품었다. 냉각 팬은 루카의 맥박과 다른 간격으로 돈다.",
	"stay":"안정화 루프 복원\n확정: 현재 기억과 관계 유지, 다섯 인격의 의식 활동 지속, 강제 일과와 수면 대신 합의 규칙 재작성.\n불확정: 시설 수명, 외부 신체와 시설의 자원 균형, 장기 심리 변화. 현재 시설에서는 연구원들을 새 신체로 옮길 수 없다.\n난로 열기와 음식 향 뒤로 전력 코일의 진동이 함께 느껴진다. 목재 옆의 시설 프레임은 사라지지 않는다."
}
const SUMMARIES := {
	"wake":"현실 기상: 외부 현실에서 물리적으로 행동할 수 있다. 신체·환경 위험과 보존 설비 유지를 감수하며 사용인과의 즉시 대화는 끊긴다. 외부 신체 연결과 다섯 인격 저전력 보존은 확정되지만 장기 생존·타인·미래 이전 기반은 불확실하다.",
	"stay":"안정화 잔류: 익숙한 환경과 다섯 인격의 즉시 지속이 가능하다. 거짓임을 아는 삶과 시설·외부 신체의 자원 소비를 감수한다. 현재 기억과 의식 활동은 유지되지만 시설 수명·자원 균형·장기 심리 변화는 불확실하다."
}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"entered":false,"seen":[],"last_device":"","summary_seen":false,"choice_open":false}
	local.merge(state["loop_state"]["event_local_states"].get("F3",{}),true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if not knowledge.get("F2_complete",false) or state["ending_run"]["final_decision"]!="unset": return {"ok":false,"text":"대면 기록과 최종 결정 상태를 확인한다."}
	var local := progress(state)
	var text := ""
	match action:
		"enter":
			local["entered"] = true
			state["loop_state"]["location_id"] = "H0_CORE_CHAMBER"
			state["fracture_state"]["final_sleep_lock"] = true
			text = "두 장치 사이에 주인공 수첩이 놓였다. 두 절차 모두 아직 실행되지 않았다. 지금은 세계 내 수면을 할 수 없지만 저장과 불러오기는 가능하다."
		"inspect":
			if not local["entered"] or str(value) not in ["wake","stay","notebook"]: return {"ok":false,"text":"세 조사 대상 중 하나를 선택한다."}
			if str(value) not in local["seen"]: local["seen"].append(str(value))
			local["choice_open"] = false
			if str(value)=="notebook":
				var intent: String = knowledge.get("f0_provisional_intent","undecided")
				text = "주인공 수첩\n확인한 사실: 내 외부 몸과 다섯 결합 인격은 현재 유지되고 있다. 최종 권한은 내게 있다.\n불확실한 사실: 외부 장기 생존, 시설의 영속, 미래 신체 이전.\n이전에 적은 임시 의향: "+str({"reality":"현실 지향","stay":"잔류 지향","undecided":"미정"}.get(intent,"미정"))+"\n이 문장은 결정이 아니다. 지우거나 바꾸어도 이전의 내가 사라지는 것은 아니다."
			else:
				local["last_device"] = str(value)
				text = OBJECTS[str(value)]
		"summary":
			if local["seen"].size()!=3: return {"ok":false,"text":"기상 장치·안정화 장치·수첩을 모두 조사한다."}
			var first := "stay" if local["last_device"]=="wake" else "wake"
			text = SUMMARIES[first]+"\n"+SUMMARIES["wake" if first=="stay" else "stay"]+"\n현실은 용기의 보상, 잔류는 도피의 처벌로 판정되지 않는다. 어느 쪽도 아직 실행하지 않았다."
			local["summary_seen"] = true
		"open":
			if not local["summary_seen"]: return {"ok":false,"text":"두 절차의 확정·불확정 사항을 먼저 확인한다."}
			local["choice_open"] = true
			knowledge["F3_complete"] = true
			state["meta_progress"]["event_history"]["F3"] = {"event_id":"F3","lifecycle":"completed"}
			text = "최종 선택 확인 단계가 열렸다. 아직 결정이 저장되지는 않았다."
		"cancel":
			local["choice_open"] = false
			text = "장치 조사로 돌아간다. 최종 결정은 미정이다."
		_: return {"ok":false,"text":"정의되지 않은 최종 확인 행동이다."}
	state["loop_state"]["event_local_states"]["F3"] = local
	return {"ok":true,"state":state,"text":text}
