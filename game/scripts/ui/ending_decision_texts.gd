extends RefCounted

const DECISION := preload("res://scripts/systems/ending_decision.gd")
const INSPECTION := preload("res://scripts/systems/final_inspection.gd")

const LABELS := {
	"f3_objective": ["F3 · 마지막 확인", "F3 · Final inspection"],
	"f3_enter": ["두 장치와 수첩을 확인한다", "Examine both devices and your notebook"],
	"f3_wake": ["기상 장치\n확정·불확정 사항 조사", "Waking device\nInspect what is assured and what is uncertain"],
	"f3_stay": ["안정화 장치\n확정·불확정 사항 조사", "Stabilization device\nInspect what is assured and what is uncertain"],
	"f3_notebook": ["주인공 수첩\n사실·불확실성·임시 의향 구분", "Your notebook\nSeparate facts, uncertainties, and provisional intent"],
	"f3_summary": ["두 절차의 균형 요약", "Balanced summary of both procedures"],
	"f3_open": ["최종 선택을 확인한다", "Review the final choice"],
	"objective": ["EDC · 최종 선택 확인", "EDC · Confirm your final choice"],
	"location": ["코어실", "Core chamber"],
	"notice": ["두 절차 모두 현재 연구원들을 새 신체로 해방시키지는 못한다.\n어느 절차도 아직 실행되지 않았다.", "Neither procedure can currently transfer the researchers into new bodies.\nNeither procedure has been executed."],
	"reality": ["기상 절차 실행\n외부 신체 기상 · 다섯 인격 저전력 보존\n외부 환경과 장기 생존은 불확실", "Execute waking procedure\nWake in your physical body · Preserve five personalities at low power\nOutside conditions and long-term survival are uncertain"],
	"stay": ["안정화 루프 복원\n현재 기억 · 다섯 인격의 활동 의식 유지\n시설 수명과 자원 균형은 불확실", "Restore the stabilization loop\nRetain current memories · Keep five personalities conscious\nFacility lifespan and resource balance are uncertain"],
	"notebook": ["주인공 수첩대\n두 절차의 요약 다시 읽기", "Your notebook stand\nReread both procedure summaries"],
	"cancel": ["결정하지 않고 장치 조사로 돌아간다", "Return to inspecting the devices without deciding"],
	"summary_title": ["두 절차의 요약", "Both procedure summaries"],
	"return": ["선택 화면으로", "Return to the choice screen"],
	"confirm_title": ["내 선택 확인", "Confirm my choice"],
	"confirm_notice": ["현재 연구원들의 새 신체 이전은 실행할 수 없다.\n이 절차를 지금 확정할까요?", "The researchers cannot currently be transferred into new bodies.\nConfirm this procedure now?"],
	"confirm_cancel": ["취소하고 장치를 다시 조사한다", "Cancel and inspect the devices again"],
	"confirm_commit": ["내 선택으로 확정한다", "Confirm this as my choice"],
	"unavailable_objective": ["엔딩 진행 상태 확인 필요", "Ending Progress Requires Attention"],
	"unavailable_return": ["타이틀로 돌아간다", "Return to Title"],
}

const UNAVAILABLE_BODY := [
	"이 버전에서 엔딩의 다음 장면을 확인할 수 없습니다.\n이 화면에서는 진행을 변경하지 않습니다.\n타이틀로 돌아가 저장 파일과 게임 버전을 확인하십시오.\n진단용 노드: {node}",
	"The next ending scene is unavailable in this version.\nThis screen will not change your progress.\nReturn to the title and check the save file and game version.\nDiagnostic node: {node}",
]

const SUMMARIES_EN := {
	"wake": "Waking in reality: You can act physically in the outside world. You accept risks to your body and environment and the upkeep of the preservation equipment; immediate conversation with the servants ends. Connection to your physical body and low-power preservation of all five personalities are assured, but long-term survival, other people, and the infrastructure for future transfers remain uncertain.",
	"stay": "Staying in the stabilized loop: The familiar environment and immediate continued presence of all five personalities remain available. You accept a life you know is simulated and the resources consumed by the facility and your physical body. Current memories and conscious activity are retained, but the facility's lifespan, resource balance, and long-term psychological changes remain uncertain.",
}

const CONFIRMATIONS_EN := {
	"reality": "Execute the waking procedure.\nYou wake in your physical body; all five personalities are automatically preserved at low power. Outside conditions, long-term survival, the lifespan of the preservation equipment, and the infrastructure for future transfers are not guaranteed.",
	"stay": "Restore the stabilization loop.\nYou retain current memories and the conscious activity of all five personalities, and regain control of the loop. Facility lifespan, sensory changes, resources for your physical body, and opportunities for recovery outside are not guaranteed.",
}

static func text(id: String, locale: String) -> String:
	if not LABELS.has(id):
		push_error("Unknown ending decision text: " + id)
		return id
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func summary(procedure: String, locale: String) -> String:
	return String((SUMMARIES_EN if locale.begins_with("en") else INSPECTION.SUMMARIES).get(procedure, ""))

static func confirmation(decision: String, locale: String) -> String:
	return String((CONFIRMATIONS_EN if locale.begins_with("en") else DECISION.CONFIRMATIONS).get(decision, ""))

static func unavailable(node_id: String, locale: String) -> String:
	var displayed_id := node_id if not node_id.is_empty() else ("None" if locale.begins_with("en") else "없음")
	return String(UNAVAILABLE_BODY[1 if locale.begins_with("en") else 0]).format({"node": displayed_id})

# Compatibility lookup for existing saves containing Korean feedback, not text IDs.
static func feedback(source: String, locale: String) -> String:
	if not locale.begins_with("en"):
		return source
	var translations := {
		INSPECTION.OBJECTS["wake"]: "Waking procedure\nAssured: connection to your physical body, current signs of life, and automatic low-power preservation of all five personalities.\nUncertain: long-term survival outside, other survivors, a return, and future transfer into new bodies. An immediate return to the same core state is not guaranteed.\nThe air against the back of your hand smells of dust and metal. The cooling fan turns at a different rhythm from Luca's pulse.",
		INSPECTION.OBJECTS["stay"]: "Restore the stabilization loop\nAssured: retention of current memories and relationships, continued conscious activity of all five personalities, and agreed rules replacing compulsory routines and sleep.\nUncertain: facility lifespan, the balance of resources between your physical body and the facility, and long-term psychological changes. This facility cannot currently transfer the researchers into new bodies.\nBehind the warmth of the hearth and the smell of food, you also feel the power coil's vibration. The facility frame beside the wood does not disappear.",
		"두 장치 사이에 주인공 수첩이 놓였다. 두 절차 모두 아직 실행되지 않았다. 지금은 세계 내 수면을 할 수 없지만 저장과 불러오기는 가능하다.": "Your notebook rests between the two devices. Neither procedure has been executed. You cannot sleep in the world now, but you can still save and load.",
		"대면 기록과 최종 결정 상태를 확인한다.": "Check the confrontation record and the status of the final decision.",
		"세 조사 대상 중 하나를 선택한다.": "Choose one of the three objects to inspect.",
		"기상 장치·안정화 장치·수첩을 모두 조사한다.": "Inspect the waking device, stabilization device, and notebook.",
		"두 절차의 확정·불확정 사항을 먼저 확인한다.": "First review what is assured and uncertain for both procedures.",
		"최종 선택 확인 단계가 열렸다. 아직 결정이 저장되지는 않았다.": "Final choice review is now available. No decision has been saved yet.",
		"장치 조사로 돌아간다. 최종 결정은 미정이다.": "Return to inspecting the devices. The final decision remains unset.",
		"정의되지 않은 최종 확인 행동이다.": "This final inspection action is not defined.",
		"아직 확정하지 않은 두 절차 중 하나를 확인한다.": "Review one of the two procedures before a final decision is committed.",
		"장치 조사와 최종 권한 확인을 먼저 마친다.": "Complete the device inspection and final authority check first.",
		DECISION.MONOLOGUES["reaffirmed"]: "I choose now the path I leaned toward then.",
		DECISION.MONOLOGUES["revised"]: "My thoughts have changed. This is my choice now.",
		DECISION.MONOLOGUES["formed"]: "Now I decide.",
	}
	for intent in [["현실 지향", "leaning toward reality"], ["잔류 지향", "leaning toward staying"], ["미정", "undecided"]]:
		var original: String = "주인공 수첩\n확인한 사실: 내 외부 몸과 다섯 결합 인격은 현재 유지되고 있다. 최종 권한은 내게 있다.\n불확실한 사실: 외부 장기 생존, 시설의 영속, 미래 신체 이전.\n이전에 적은 임시 의향: " + intent[0] + "\n이 문장은 결정이 아니다. 지우거나 바꾸어도 이전의 내가 사라지는 것은 아니다."
		translations[original] = "Your notebook\nVerified facts: my physical body and all five linked personalities are currently sustained. Final authority is mine.\nUncertainties: long-term survival outside, the facility's permanence, and future transfer into new bodies.\nProvisional intent recorded earlier: " + intent[1] + "\nThis sentence is not a decision. Erasing or changing it does not erase who I was."
	for first in ["wake", "stay"]:
		var second := "stay" if first == "wake" else "wake"
		translations[INSPECTION.SUMMARIES[first] + "\n" + INSPECTION.SUMMARIES[second] + "\n현실은 용기의 보상, 잔류는 도피의 처벌로 판정되지 않는다. 어느 쪽도 아직 실행하지 않았다."] = SUMMARIES_EN[first] + "\n" + SUMMARIES_EN[second] + "\nReality is not judged as a reward for courage, nor staying as a punishment for avoidance. Neither procedure has been executed."
	return String(translations.get(source, source))
