class_name CoreRecordRoles
extends RefCounted

const ROLES := ["CREATOR", "CUSTODIAN", "RESIDENT", "SYSTEM", "SUBJECT"]
const LABELS := ["CR_AT_R", "C_ST_D_AN", "R_S_D_NT", "SY_T_M", "S_BJ_CT"]
const RECORDS := ["father", "passphrase", "residents", "command", "notebook"]
const NAMES := {"father":"아버지 일지", "passphrase":"에드가 접근 암구호", "residents":"연구원 기록 묶음", "command":"D4 복구 명령", "notebook":"주인공 수첩"}
const FACTS := {"father":"설계 도면과 생성 기록. 저택의 규칙을 만들었지만 현재의 선택 주체는 아니다.", "passphrase":"문을 지키고 접근을 허가하는 관리 기록. 주인공의 삶에 대한 최종 결정을 대신할 수 없다.", "residents":"저택 안에 계속 존재하는 연구원 인격의 인덱스. 외부 신체 복원과는 별개의 지속 기록이다.", "command":"특정 조건이 충족되면 위장 필터를 해제하는 자동 실행 기록이다.", "notebook":"어제와 오늘을 겪는 주인공의 직접 기록. 이 삶의 선택 결과를 겪는 사람이 남겼다."}
const SENTENCES := ["집을 만들었다", "문을 지키고 허가했다", "집 안에서 계속 존재한다", "조건에 따라 자동 실행된다", "이 삶의 결과를 겪는다"]

static func progress(state: Dictionary) -> Dictionary:
	var local := {"slots":["","","","",""], "selected":"", "failures":0, "locked":-1, "feedback":""}
	local.merge(state["loop_state"]["event_local_states"].get("F0_D", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("f0_overlay_complete", false) or knowledge.get("f0_record_roles_solved", false) or state["loop_state"]["location_id"] != "H0_CORE_PATH": return {"ok":false,"text":"포트 구조를 먼저 조사한다."}
	var local := progress(state)
	var text := ""
	match action:
		"select":
			if str(value) not in RECORDS: return {"ok":false,"text":"기록 카드를 선택한다."}
			local["selected"] = str(value)
			text = NAMES[str(value)] + "\n" + FACTS[str(value)]
			if str(value) == "residents" and not meta["servants"]["mara2"]["researcher_record_acquired"]:
				knowledge["ANON_PURPLE_RESIDENT_INDEX"] = true
				text += "\n익명 인덱스: 기능 정보는 보존되어 있다. 개인 음성과 감정 주석은 없다."
		"place":
			if not value is int or value not in range(5) or String(local["selected"]).is_empty(): return {"ok":false,"text":"카드와 역할 슬롯을 선택한다."}
			if value == local["locked"]: return {"ok":false,"text":"검증해 고정한 슬롯이다."}
			var previous: int = local["slots"].find(local["selected"])
			if previous == local["locked"] and previous >= 0: return {"ok":false,"text":"고정한 기록은 이동하지 않는다."}
			if previous >= 0: local["slots"][previous] = local["slots"][value]
			local["slots"][value] = local["selected"]
			local["selected"] = ""
			text = "기록을 배치했다. 다섯 슬롯을 채운 뒤 함께 검증한다."
		"verify":
			if "" in local["slots"]: return {"ok":false,"text":"다섯 역할 슬롯을 모두 채운다."}
			var count := 0
			for index in range(5):
				if local["slots"][index] == RECORDS[index]: count += 1
			if count == 5:
				knowledge["f0_record_roles_solved"] = true
				meta["event_history"]["F0_D"] = {"event_id":"F0_D","lifecycle":"completed"}
				text = "SUBJECT RECORD FOUND / CONTINUITY VERIFIED / CURRENT AUTHORITY REQUIRED\n주인공 기록 발견 · 과거 연속성 확인 · 현재 권한 확인 필요\n다섯 역할이 구분되었다. 주인공 수첩에만 현재의 응답을 요구한다."
			else:
				local["failures"] += 1
				text = "일치한 역할 %d / 5" % count
				if local["failures"] >= 2:
					for index in range(5): text += "\n" + LABELS[index] + " : " + SENTENCES[index]
				if local["failures"] >= 3: text += "\n현재 올바르게 놓인 슬롯 하나를 선택해 고정할 수 있다."
		"lock":
			if not value is int or value not in range(5) or int(local["failures"]) < 3 or int(local["locked"]) >= 0: return {"ok":false,"text":"세 번 비교한 뒤 슬롯 하나를 고정할 수 있다."}
			if local["slots"][value] != RECORDS[value]: return {"ok":false,"text":"이 슬롯은 아직 검증되지 않았다."}
			local["locked"] = value
			text = "올바른 역할 슬롯 하나를 고정했다. 다른 슬롯은 계속 바꿀 수 있다."
		_: return {"ok":false,"text":"정의되지 않은 기록 조작이다."}
	local["feedback"] = text
	state["loop_state"]["event_local_states"]["F0_D"] = local
	return {"ok":true,"state":state,"text":text}
