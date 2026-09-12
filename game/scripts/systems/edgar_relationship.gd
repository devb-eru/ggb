class_name EdgarRelationship
extends RefCounted

const OWNERS := {"PROTECTION": "SYSTEM", "SURVEILLANCE": "CUSTODIAN", "MEMORY": "RESIDENT", "CHOICE": "SUBJECT"}
const CLUES := {"PROTECTION": "보호한다 · 안전 모듈은 생체를 보호하지만 종료를 결정하지 않는다.", "SURVEILLANCE": "관찰한다 · 관리자는 관찰·보고·접근 제한을 수행한다.", "MEMORY": "기억한다 · 기억의 원 소유권은 거주 인격에게 있다.", "CHOICE": "결정한다 · 기상과 잔류는 대상자 본인이 정한다."}
const ORDER := ["consent", "protocol", "vacancy", "extension"]
const LOGS := {
	"consent": "동의 취합 시점 / 에드가: 연구 윤리·운영 책임자로 서명. 미래의 새 육체 약속과 달리 원래 신체 소실·신경 코어 결합 설명은 불완전함. 기억 주체는 연구원 인격으로 남음.",
	"protocol": "취합 뒤 절차 위반 확인 / 연구 중단보다 인격 보존을 우선. SYSTEM 보호와 CUSTODIAN 감시를 활성화했으나 대상자 동의 절차는 미완성.",
	"vacancy": "아버지 사망 뒤 / 창조자 최종 권한과 기상 해제 절차 미완성. 불완전한 관리자 권한만 사용인들이 공유함.",
	"extension": "권한 공백 이후 / 에드가: 외부 위험을 이유로 수면 연장. 선택 권한을 CUSTODIAN이 대행. 강제 시뮬레이션 기동에는 반대했으나 정지하지도, 당사자 권한을 반환하지도 않음.",
}
const RECORD := "에드가는 연구 윤리·운영 책임자로 불완전한 전환 동의를 취합했다. 아버지는 최종 창조자 권한과 기상 해제 절차를 완수하지 못했다. 그 뒤 수면 연장은 에드가 자신의 결정이었다. 강제 기동을 막지 못했고 선택 권한을 계속 반환하지 않았다. 보호는 SYSTEM, 감시는 CUSTODIAN, 기억은 RESIDENT, 선택은 SUBJECT에 귀속된다. 현재 선택권은 주인공에게 돌아갔다."

static func progress(state: Dictionary) -> Dictionary:
	var local := {"order": [], "audit": false, "owners": {}, "validated": false, "confessed": false}
	local.merge(state["loop_state"]["event_local_states"].get("E3_4", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("relationship_hub_open", false) or state["loop_state"]["location_id"] != "H0_CLOCK_MACHINE": return {"ok": false, "text": "합의 뒤 대시계 기계실에서 조사한다."}
	if knowledge.get("E3_4_complete", false): return {"ok": false, "text": "현재 선택권은 이미 주인공에게 있다. 관계 선택을 재적용하지 않는다."}
	var local := progress(state)
	if local["validated"] and action in ["clear", "owner", "validate"]: return {"ok": false, "text": "검증한 현재 권한은 유지한다. 책임 보고를 확인할 수 있다."}
	var text := ""
	match action:
		"log":
			if not LOGS.has(str(value)): return {"ok": false, "text": "확인할 변경 이력을 선택한다."}
			if str(value) not in local["order"]: local["order"].append(str(value))
			text = LOGS[str(value)]
		"clear":
			local["order"] = []
			text = "네 변경 이력을 다시 펼친다."
		"audit":
			if local["order"] != ORDER: return {"ok": false, "text": "권한이 비기 전에 공백 이후 결정을 둘 수는 없다. 각 문서의 선행 사건을 대조한다."}
			local["audit"] = true
			knowledge["edgar_lock_audit_read"] = true
			text = "처음 명령과 이후 운영자의 결정이 분리된다. 네 기능이 같은 권한은 아니다."
		"owner":
			if not local["audit"] or not value is Array or value.size() != 2 or not OWNERS.has(str(value[0])) or str(value[1]) not in OWNERS.values(): return {"ok": false, "text": "이력을 확인한 뒤 기능과 소유자를 배치한다."}
			for function in local["owners"].keys():
				if local["owners"][function] == str(value[1]): local["owners"].erase(function)
			local["owners"][str(value[0])] = str(value[1])
			text = "기능 아래 소유자 토큰을 놓는다. 같은 토큰은 한 곳에서만 사용한다."
		"validate":
			if not local["audit"]: return {"ok": false, "text": "변경 이력을 먼저 확인한다."}
			var contradictions: PackedStringArray = []
			for function in OWNERS:
				var owner := str(local["owners"].get(function, ""))
				if owner == OWNERS[function]: continue
				var reason: String = CLUES[function]
				if function == "CHOICE" and owner == "SYSTEM": reason = "보호 명령은 종료 여부를 결정할 수 없다."
				elif function == "CHOICE" and owner == "CUSTODIAN": reason = "관리 권한과 당사자 동의가 충돌한다."
				elif function == "SURVEILLANCE" and owner == "SUBJECT": reason = "관찰자와 관찰 대상이 뒤바뀌었다."
				elif function == "MEMORY" and owner == "CUSTODIAN": reason = "보관자가 원 소유자로 등록되어 있다."
				contradictions.append(reason)
				local["owners"].erase(function)
			if contradictions.is_empty():
				local["validated"] = true
				knowledge["edgar_authority_owners_matched"] = true
				knowledge["edgar_authority_layout_validated"] = true
				text = "선택 권한선이 관리 회로에서 빠져나온다. 종이와 연필 질감의 SUBJECT 단자로 연결된다."
			else: text = "\n".join(contradictions) + "\n모순인 카드만 되돌린다. 다른 배치는 유지된다."
		"confess":
			if not local["validated"]: return {"ok": false, "text": "현재 권한 배치를 먼저 검증한다."}
			local["confessed"] = true
			var edgar: Dictionary = meta["servants"]["edgar"]
			text = "레이피어 끝이 권한선의 경계를 짚는다. 꼬리가 한 번 바닥을 친다.\n주인공이 묻는다. '아버지가 시켰습니까?'\n[대시계 저음: 네 번, 정지]\n처음에는 명령이었습니다. 그 이후는 제 판단입니다. 강제 기동에 반대했지만, 정지시키지도 선택권을 반환하지도 않았습니다."
			if int(edgar["bond"]) >= 4: text += "\n보호한다는 말로 선택을 빼앗았습니다. 사과드립니다."
			elif int(edgar["bond"]) >= 2: text += "\n귀하가 잃어버린 시간도 제 책임입니다."
			if int(edgar["alert"]) >= 4: text += "\n다음 행동은 무엇입니까? ...대신 결정하려는 질문이 되어서는 안 됩니다."
		"choose":
			if not local["confessed"] or str(value) not in ["responsibility_recorded", "authority_returned"]: return {"ok": false, "text": "에드가의 책임 보고를 먼저 확인한다."}
			var direct := str(value) == "authority_returned"
			var edgar: Dictionary = meta["servants"]["edgar"]
			edgar["bond"] = clampi(int(edgar["bond"]) + (2 if direct else 1), 0, 5)
			edgar["alert"] = clampi(int(edgar["alert"]) + (1 if direct else -1), 0, 5)
			edgar["core_event_complete"] = true
			edgar["researcher_record_acquired"] = true
			for flag in ["E3_4_complete", "REC_EDGAR", "subject_role_identified", "edgar_detention_decision_known"]: knowledge[flag] = true
			meta["event_history"]["E3_4"] = {"event_id": "E3_4", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "E3_4_COMPLETION", "relationship_delta_applied": true, "completed_at_story_phase": "BROKEN_RESET"}
			var notes: Dictionary = knowledge.get("chapter_notebook", {})
			notes["REC_EDGAR"] = RECORD
			knowledge["chapter_notebook"] = notes
			text = "에드가가 레이피어를 내려놓고 SUBJECT 단자를 주인공에게 넘긴다.\n귀하의 권한입니다." if direct else "에드가가 자신의 운영 서명을 감사 기록에 남긴다.\n제 판단과 책임으로 기록합니다. 선택 권한은 귀하에게 있습니다."
		_:
			return {"ok": false, "text": "정의되지 않은 권한 조사다."}
	state["loop_state"]["event_local_states"]["E3_4"] = local
	return {"ok": true, "state": state, "text": text}
