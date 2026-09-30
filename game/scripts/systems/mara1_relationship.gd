class_name Mara1Relationship
extends RefCounted

const SOURCES := ["MAINT", "CONSENT", "AUDIT"]
const LOGS := {
	"consent": "전환 전날 · 승인 원본 / 손바닥 승인각\n미래에 새 육체로 살아갈 것이라는 약속. 원래 신체 소실과 생체 신경 코어 결합 전환의 고지란은 비어 있다. 다음 장으로 이어지는 대각 닦임이 아래로 향한다.",
	"failure": "전환 당일 · 앞 승인 원본 참조 / 끊긴 사각\n전환 실험 실패 발생. 고지되지 않은 절차가 실행됐다. 윗쪽 닦임이 승인 원본의 아랫쪽과 이어진다. 일부 피해자 이름은 열 손상으로 읽히지 않는다.",
	"command": "실패 보고 직후 · 실패 보고 참조 / 대각 나사선\n아버지의 명령: '운영 안정성을 위해 정리.' 수행자: 마라 1. 실패 로그와 동의 절차 모순을 정비 이력으로 덮음.",
}

static func progress(state: Dictionary) -> Dictionary:
	var result := {"panel": false, "sources": {}, "bridge": false, "order": [], "restored": false, "confessed": false}
	result.merge(state["loop_state"]["event_local_states"].get("E3_1", {}), true)
	return result

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	if not meta["knowledge_entries"].get("relationship_hub_open", false) or state["loop_state"]["location_id"] != "M1_WIRING_ROOM":
		return {"ok": false, "text": "합의 뒤 배선실에서 조사한다."}
	if meta["knowledge_entries"].get("E3_1_complete", false): return {"ok": false, "text": "기록은 이미 보존했다. 선택을 다시 적용하지 않는다."}
	var local := progress(state)
	var text := ""
	match action:
		"panel":
			local["panel"] = true
			text = "탄 피복 아래 마른 종이 냄새가 난다. 대각 나사선은 솔 마찰음, 손바닥 승인각은 두 번 확인음, 끊긴 사각은 늦은 경고음이다. 승인과 감사 선이 정비 출력에 합쳐져 있다."
		"source":
			if not local["panel"] or not value is Array or value.size() != 2: return {"ok": false, "text": "먼저 패널 단자를 조사한다."}
			var index := int(value[0])
			if index < 0 or index >= SOURCES.size(): return {"ok": false, "text": "알 수 없는 단자다."}
			if String(value[1]) != SOURCES[index]:
				text = "출처가 다른 단자다. 이 단자만 안전 차단됐다. 선을 떼고 다시 대조할 수 있다."
			else:
				local["sources"][str(index)] = SOURCES[index]
				if local["sources"].size() == 3: meta["knowledge_entries"]["mara1_trace_sources_identified"] = true
				text = "문양과 신호가 일치한다. " + SOURCES[index]
		"bridge":
			if local["sources"].size() != 3: return {"ok": false, "text": "그거부터 풀면 다 같이 날아감다. 세 출처를 먼저 봐주십쇼."}
			local["bridge"] = true
			meta["knowledge_entries"]["mara1_delete_bridge_removed"] = true
			text = "스패너로 가짜 브리지를 해제한다. 승인과 감사가 정비 기록에서 분리되고 세 파편이 드러난다."
		"log":
			if not local["bridge"] or not LOGS.has(str(value)): return {"ok": false, "text": "브리지를 해제한 뒤 파편을 확인한다."}
			if str(value) not in local["order"]: local["order"].append(str(value))
			text = LOGS[str(value)]
		"clear":
			local["order"] = []
			text = "파편을 다시 펼친다. 이미 조사한 출처는 유지된다."
		"restore":
			if local["order"] != ["consent", "failure", "command"]: return {"ok": false, "text": "날짜와 문서 참조가 이어지지 않는다. 파편을 다시 펼쳐 대조한다."}
			local["restored"] = true
			meta["knowledge_entries"]["mara1_log_order_restored"] = true
			text = "동의 원본, 실패 보고, 정리 명령이 이어진다. 일부 이름은 복구할 수 없다. 빈칸을 추측해서 채우지 않는다."
		"confess":
			if not local["restored"]: return {"ok": false, "text": "로그를 먼저 복원한다."}
			local["confessed"] = true
			text = "청소가 좀 과했슴다...\n마라 1의 귀와 꼬리가 멎는다.\n아버님 명령으로 제가 지웠슴다. 이상한 건 알았는데, 시설을 살리는 정비라고 믿고 싶었어요. 용서해 달라는 말은 못 하겠슴다. 이걸 어떻게 남길지, 정해 주십쇼."
		"choose":
			if not local["confessed"] or str(value) not in ["original_attribution", "protected_identifiers"]: return {"ok": false, "text": "복원한 기록과 마라 1의 말을 먼저 확인한다."}
			var protected := str(value) == "protected_identifiers"
			var servant: Dictionary = meta["servants"]["mara1"]
			servant["bond"] = clampi(int(servant["bond"]) + (1 if protected else 2), 0, 5)
			servant["alert"] = clampi(int(servant["alert"]) + (-1 if protected else 1), 0, 5)
			servant["core_event_complete"] = true
			servant["researcher_record_acquired"] = true
			meta["knowledge_entries"]["E3_1_complete"] = true
			meta["knowledge_entries"]["REC_MARA1"] = true
			meta["event_history"]["E3_1"] = {"event_id": "E3_1", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "E3_1_COMPLETION", "relationship_delta_applied": true, "completed_at_story_phase": "BROKEN_RESET"}
			text = "피해자 식별 정보만 보호한다. 사건 원문, 명령자 아버지와 수행자 마라 1의 책임은 남긴다." if protected else "명령자와 수행자의 책임, 피해 기록과 원문을 그대로 남긴다."
			var notes: Dictionary = meta["knowledge_entries"].get("chapter_notebook", {})
			notes["REC_MARA1"] = text + "\n연구원들은 새 육체를 약속받았으나 원래 신체 소실과 신경 코어 전환은 고지받지 못했다. 마라 1은 운영 안정화 명령으로 실패와 동의 모순을 지웠다. 그 업무는 지금의 청소 강박으로 남았다."
			meta["knowledge_entries"]["chapter_notebook"] = notes
		_:
			return {"ok": false, "text": "정의되지 않은 정비 행동이다."}
	state["loop_state"]["event_local_states"]["E3_1"] = local
	return {"ok": true, "state": state, "text": text}
