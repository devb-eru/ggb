class_name CoreApproach
extends RefCounted

const DESTINATIONS := ["M1_CENTRAL_HALL", "M1_NORTH_ARCHIVE_HALL", "H0_CLOCK_MACHINE"]

static func pending(state: Dictionary, event: String) -> bool:
	if event == "MARA2_FU" and not state["meta_progress"]["servants"]["mara2"]["core_event_complete"]: return false
	return state["meta_progress"]["event_history"].get(event, {}).get("lifecycle", "") not in ["completed", "superseded"]

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var text := ""
	var location: String = state["loop_state"]["location_id"]
	if not knowledge.get("e5_locked_in", false) or int(meta["journal_stage"]) < 4 or not (meta["servants"]["edgar"]["core_event_complete"] or knowledge.get("edgar_minimum_access", false)):
		return {"ok": false, "text": "저녁의 결산과 코어 접근 권한을 확인한다."}
	if knowledge.get("f0_entered", false): return {"ok": false, "text": "코어 경로에 진입했다. 이전 후속 반응은 종료되었다."}
	match action:
		"move":
			if str(value) not in DESTINATIONS: return {"ok": false, "text": "안내된 후속 장소를 선택한다."}
			state["loop_state"]["location_id"] = str(value)
			text = "중앙홀의 안내선을 따라 이동한다. 종료한 관계 사건은 다시 시작되지 않는다."
		"mara2":
			if location != "M1_NORTH_ARCHIVE_HALL" or not pending(state, "MARA2_FU") or str(value) not in ["write", "call", "joke"]: return {"ok": false, "text": "기록 회랑의 미확인 이름 반응을 확인한다."}
			var owner: Dictionary = meta["servants"]["mara2"]
			var outcome: String = meta["event_history"].get("E3_5", {}).get("outcome_id", "")
			text = "마라 2: 이번에도 네가 먼저 알아봤네!" if knowledge.get("mara2_name_attention_seen", false) else "마라 2: 내 이름부터 확인해 봐! ...아니, 확인해 줄래?"
			text += "\n시끄러운 웃음 속에서 자기 목소리의 경계를 찾는다." if outcome == "merged" else "\n두 인덱스가 번갈아 자신을 가리킨다. 어느 쪽도 없는 이름이 되지 않으려 한다."
			text += "\n마라 2: 방금 거, 기록하지 않아도 돼. 대신 네가 기억해. 그게 더 오래 갈 수도 있잖아!"
			if str(value) in ["write", "call"]: owner["bond"] = clampi(int(owner["bond"]) + 1, 0, 5)
			if str(value) == "write":
				knowledge["mara2_name_written"] = true
				var notes: Dictionary = knowledge.get("chapter_notebook", {})
				notes["MARA2_NAME"] = "마라 2(가칭)"
				knowledge["chapter_notebook"] = notes
				text += "\n수첩에 '마라 2(가칭)'를 적는다. 빠른 세 음이 이번에는 끝까지 이어진다."
			elif str(value) == "call": text += "\n주인공이 이름을 다시 부른다. 이중 윤곽이 잠깐 같은 속도로 맞물린다."
			else: text += "\n주인공이 장난으로 답한다. 마라 2는 짐짓 더 큰 소리로 웃는다."
			meta["event_history"]["MARA2_FU"] = {"event_id": "MARA2_FU", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "MARA2_FU_FIRST_COMPLETE"}
		"edgar":
			if location != "H0_CLOCK_MACHINE" or not pending(state, "EDGAR_S3") or str(value) not in ["ask", "order", "wait"]: return {"ok": false, "text": "문 앞의 마지막 점검을 확인한다."}
			var owner: Dictionary = meta["servants"]["edgar"]
			if str(value) == "ask": owner["bond"] = clampi(int(owner["bond"]) + 1, 0, 5)
			text = "에드가: 문은 열겠습니다. 다만, 제가 지키려던 것이 문인지 아가씨인지 아직도 확신하지 못하겠습니다."
			text += "\n에드가: 가십시오. 이번에는 제가 뒤에서 따라가겠습니다." if owner["core_event_complete"] else "\n에드가: 최소 권한은 복구되었습니다. 그 이상은, 아가씨의 몫입니다."
			if str(value) == "order" and int(owner["bond"]) >= 4: text += "\n에드가: 명령을 받들겠습니다. 제가 돌려드려야 할 책임입니다."
			if int(owner["alert"]) >= 4: text += "\n에드가: 외부 안전은 확인되지 않았습니다. 경고는 드리되, 권한은 막지 않겠습니다."
			text += "\n열쇠 없이 잠금 해제음이 울린다. 수직선이 문틀에서 풀린다."
			knowledge["core_access_open"] = true
			meta["event_history"]["EDGAR_S3"] = {"event_id": "EDGAR_S3", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "EDGAR_S3_FIRST_COMPLETE"}
		"open":
			if location != "H0_CLOCK_MACHINE": return {"ok": false, "text": "보안 기계실의 코어 문에서 확인한다."}
			knowledge["core_access_open"] = true
			text = "권한 프레임이 열린다. 마지막 대화를 하지 않아도 길은 열려 있다. 아직 문턱은 넘지 않았다."
		"enter":
			if value != true or location != "H0_CLOCK_MACHINE" or not knowledge.get("core_access_open", false): return {"ok": false, "text": "열린 코어 경로의 일방향 진입을 확인한다."}
			for event in ["MARA2_FU", "EDGAR_S3"]:
				if pending(state, event): meta["event_history"][event] = {"event_id": event, "lifecycle": "superseded", "reason": "F0_entry"}
			knowledge["f0_entered"] = true
			knowledge["E6_complete"] = true
			meta["event_history"]["E6"] = {"event_id": "E6", "lifecycle": "completed"}
			state["loop_state"]["location_id"] = "H0_CORE_PATH"
			text = "문턱을 넘는다. 뒤의 복도는 끊어지고, 서로 다른 방의 조각이 앞에서 맞물린다. 아직 현실이나 잔류를 선택한 것은 아니다."
		_: return {"ok": false, "text": "정의되지 않은 코어 접근 행동이다."}
	if action in ["mara2", "edgar"]:
		var seen: Array = knowledge.get("short_events_seen", []).duplicate()
		var event := "MARA2_FU" if action == "mara2" else "EDGAR_S3"
		if event not in seen: seen.append(event)
		knowledge["short_events_seen"] = seen
	return {"ok": true, "state": state, "text": text}
