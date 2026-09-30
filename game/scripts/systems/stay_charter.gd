class_name StayCharter
extends RefCounted

const NODES := ["EDS_MEMORY_CHARTER","EDS_APPEARANCE_CONTROL","EDS_AUTONOMY_CHARTER"]
const PRINCIPLES := [
	"주인공은 저택이 시뮬레이션임을 기억한다. 익숙함을 선택해도 확인한 진실을 지우지는 않는다.",
	"사용인은 연구원 인격과 감금 책임을 삭제하지 않는다. 같은 이름으로 살아가는 일은 책임을 없었던 것으로 만드는 일이 아니다.",
	"다음 수면·기상·기억 변경은 주인공의 명시적 확인 없이는 실행하지 않는다. 지금 이 장면에서는 실제 다음 수면을 실행하지 않는다."
]
const OWNERS := {"edgar":"에드가", "mara1":"마라 1", "luca":"루카", "iris":"이리스", "mara2":"마라 2"}
const MODES := {"layered":"고딕 외피와 시설 골격을 함께 표시", "contextual":"평소 외피, 조사 시 시설 골격 표시"}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"principles":[],"proposed":[]}
	local.merge(state["loop_state"]["event_local_states"].get("STAY_CHARTER",{}),true)
	var principles: Array = []
	for value in local["principles"]:
		if (value is int or value is float) and int(value) == value and int(value) in [0,1,2] and int(value) not in principles: principles.append(int(value))
	principles.sort()
	local["principles"] = principles
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var node: String = run.get("current_node_id","")
	if not run.get("branch_committed",false) or run.get("branch_id") != "stay": return {"ok":false,"text":"잔류 선택 이후의 원칙이다."}
	var mode_edit: bool = action == "appearance" and (node == "EDS_APPEARANCE_CONTROL" or "EDS_APPEARANCE_CONTROL" in run.get("completed_nodes",[]))
	if node not in NODES and not mode_edit: return {"ok":false,"text":"현재 잔류 사건에서 이어진다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var local := progress(state)
	var next := node
	var object_id := ""
	match action:
		"memory":
			if node != "EDS_MEMORY_CHARTER" or not value is int or value < 0 or value >= PRINCIPLES.size(): return {"ok":false,"text":"세 기억 원칙 중 하나를 읽는다."}
			if value not in local["principles"]: local["principles"].append(value)
		"memory_finish":
			if node != "EDS_MEMORY_CHARTER" or local["principles"].size() != 3: return {"ok":false,"text":"세 원칙을 읽은 뒤 유지한다."}
			next = "EDS_APPEARANCE_CONTROL"
			object_id = "OBJ_STAY_MEMORY_CHARTER"
			state["meta_progress"]["knowledge_entries"]["EDS_truth_memory_confirmed"] = true
		"appearance":
			if not mode_edit or str(value) not in MODES: return {"ok":false,"text":"두 표시 방식 중 하나를 선택한다."}
			ending["ending_appearance_mode"] = value
		"appearance_finish":
			if node != "EDS_APPEARANCE_CONTROL" or ending.get("ending_appearance_mode","") not in MODES: return {"ok":false,"text":"외형 표시 방식을 선택한다. 이후에도 바꿀 수 있다."}
			next = "EDS_AUTONOMY_CHARTER"
			object_id = "OBJ_STAY_APPEARANCE_CONTROL"
		"propose":
			if node != "EDS_AUTONOMY_CHARTER" or str(value) not in OWNERS: return {"ok":false,"text":"다섯 역할의 강제 여부를 확인한다."}
			if value not in local["proposed"]: local["proposed"].append(value)
		"autonomy_finish":
			if node != "EDS_AUTONOMY_CHARTER" or local["proposed"].size() != OWNERS.size(): return {"ok":false,"text":"다섯 사용인 모두의 역할을 제안으로 전환한다."}
			next = "EDS_CENTRAL_HALL"
			object_id = "OBJ_STAY_AUTONOMY_CHARTER"
			state["meta_progress"]["knowledge_entries"]["EDS_servant_autonomy_confirmed"] = true
			state["loop_state"]["location_id"] = "M1_CENTRAL_HALL"
		_: return {"ok":false,"text":"정의되지 않은 잔류 원칙 행동이다."}
	local["principles"].sort()
	local["proposed"].sort()
	state["loop_state"]["event_local_states"]["STAY_CHARTER"] = local
	if next != node:
		var required: Array = ending.get("required_interactions_seen",[]).duplicate()
		if object_id not in required: required.append(object_id)
		required.sort()
		ending["required_interactions_seen"] = required
		if node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next
	return {"ok":true,"state":state,"text":""}
