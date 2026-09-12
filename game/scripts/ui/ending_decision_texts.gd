extends RefCounted

const DECISION := preload("res://scripts/systems/ending_decision.gd")
const INSPECTION := preload("res://scripts/systems/final_inspection.gd")

const LABELS := {
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
}

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
