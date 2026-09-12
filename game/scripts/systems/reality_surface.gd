class_name RealitySurface
extends RefCounted

const NODES := ["EDR_FACILITY_FREE_LOOK","EDR_AIRLOCK_CONFIRM","EDR_SURFACE_THRESHOLD","EDR_FINAL_FRAME"]
const OBJECTS := {
	"glass":["R0_CRYO_CHAMBER","캡슐 유리","안쪽 손자국과 바깥 정비 자국이 겹친다. 자국의 시간은 서로 다르다. 어느 손이 마지막이었는지는 알 수 없다."],
	"stand":["R0_CRYO_CHAMBER","빈 보존대","다른 누군가의 자리였을 수도, 예비대였을 수도 있다. 비어 있다는 사실만으로 어느 쪽도 확정할 수 없다."],
	"tools":["R0_FACILITY_EXIT","공구함","마라 1의 수첩과 같은 규격 번호가 보인다. 몇 칸은 비어 있다. 공구의 윤곽만 먼지 위에 남았다."],
	"plant":["R0_FACILITY_EXIT","투명 화분","말라붙은 줄기와 생장 기록이 남았다. 이리스의 계절 모델 속 정원과 다르다. 실제 생장은 기록의 예측을 따르지 않았다."],
	"names":["R0_FACILITY_EXIT","벽면 이름 목록","다섯 연구원 이름과 판독할 수 없는 일부 이름이 나란하다. 읽히지 않는 이름을 살아 있는 누군가라고 단정하지 않는다."],
	"signal":["R0_SURFACE_THRESHOLD","멀리 점멸하는 빛","빛은 한 번 끊겼다가 다시 나타난다. 사람인지 자동 장치인지 센서 오류인지 알 수 없다. 시선은 자동으로 확대되지 않는다."]
}
const REQUIRED_NODES := ["EDR_BODY_CHECK","EDR_FIELD_NOTEBOOK","EDR_EXIT_PANEL"]

static func local(state: Dictionary) -> Dictionary:
	var result := {"seen":[],"look":"center","elapsed":0}
	result.merge(state["loop_state"]["event_local_states"].get("REALITY_SURFACE",{}),true)
	return result

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var node: String = run.get("current_node_id","")
	if not run.get("branch_committed",false) or run.get("branch_id") != "reality" or node not in NODES: return {"ok":false,"text":"현실 시설과 지표 경계에서 확인한다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var progress := local(state)
	var next := node
	match action:
		"move":
			if node != "EDR_FACILITY_FREE_LOOK" or str(value) not in ["R0_CRYO_CHAMBER","R0_FACILITY_EXIT"]: return {"ok":false,"text":"시설 내부의 두 구역만 조사할 수 있다."}
			state["loop_state"]["location_id"] = value
		"inspect":
			if str(value) not in OBJECTS or node not in ["EDR_FACILITY_FREE_LOOK","EDR_SURFACE_THRESHOLD"] or OBJECTS[str(value)][0] != state["loop_state"]["location_id"]: return {"ok":false,"text":"현재 위치의 대상을 확인한다."}
			if value not in progress["seen"]: progress["seen"].append(value)
			if value == "signal" and "EDR_DISTANT_SIGNAL" not in ending["completed_nodes"]: ending["completed_nodes"].append("EDR_DISTANT_SIGNAL")
		"airlock":
			if node != "EDR_FACILITY_FREE_LOOK" or state["loop_state"]["location_id"] != "R0_FACILITY_EXIT": return {"ok":false,"text":"시설 출구로 돌아가 에어록을 확인한다."}
			next = "EDR_AIRLOCK_CONFIRM"
		"cancel":
			if node != "EDR_AIRLOCK_CONFIRM": return {"ok":false,"text":"에어록 확인 단계가 아니다."}
			next = "EDR_FACILITY_FREE_LOOK"
		"enter":
			if node != "EDR_AIRLOCK_CONFIRM": return {"ok":false,"text":"에어록에서 바깥 상태를 확인한다."}
			next = "EDR_SURFACE_THRESHOLD"
			state["loop_state"]["location_id"] = "R0_SURFACE_THRESHOLD"
		"outside":
			if node != "EDR_SURFACE_THRESHOLD": return {"ok":false,"text":"지표 경계에서 밖을 본다."}
			for required in REQUIRED_NODES:
				if required not in ending["completed_nodes"]: return {"ok":false,"text":"신체·현장 수첩·출입 점검 기록이 필요하다."}
			next = "EDR_FINAL_FRAME"
		"look":
			if node != "EDR_FINAL_FRAME" or str(value) not in ["left","center","right"]: return {"ok":false,"text":"문턱에 선 채 시선을 옮긴다."}
			progress["look"] = value
		"tick":
			if node != "EDR_FINAL_FRAME": return {"ok":false,"text":"마지막 자유 시점이 아니다."}
			progress["elapsed"] = mini(int(progress["elapsed"])+1,8)
			if progress["elapsed"] == 8: next = "CREDITS_REALITY"
		_: return {"ok":false,"text":"정의되지 않은 시설 행동이다."}
	progress["seen"].sort()
	state["loop_state"]["event_local_states"]["REALITY_SURFACE"] = progress
	if next != node:
		if action != "cancel" and node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next
	return {"ok":true,"state":state,"text":""}
