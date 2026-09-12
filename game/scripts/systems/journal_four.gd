class_name JournalFour
extends RefCounted

const EVENTS := ["E3_1", "E3_2", "E3_3", "E3_4", "E3_5"]
const OWNERS := ["mara1", "iris", "luca", "edgar", "mara2"]
const NAMES := ["대각선 · 마라 1", "꽃잎 · 이리스", "이중 맥박 · 루카", "수직선 · 에드가", "이중 액자 · 마라 2"]
const MINUTES := [[9, 14], [10, 15], [9, 14], [12, 18], [10, 16]]
const ORDER := ["promise", "transition", "roles", "activation"]
const PAGES := {"promise": "약속 · 미래의 삶을 약속한 날짜 조각", "transition": "전환 · 약속 뒤 생체 신경 코어와 인격 프로세스 결합", "roles": "역할 고정 · 전환된 연구원들이 저택의 관리자가 됨", "activation": "주인공 기동 · 역할이 고정된 뒤 사용인들이 의식을 강제로 깨움"}
const BASE_TEXT := "나는 그들에게 미래의 삶을 약속했다.\n그 약속이 육체를 뜻하는지, 기억의 지속을 뜻하는지 끝까지 분명하게 말하지 않았다.\n\n그들은 집을 움직일 수 있다. 계절을 고치고, 심장을 유지하고, 문을 잠글 수 있다.\n하지만 집 밖으로 나가는 문과 누가 이 삶의 주인인지 정하는 권한은 주지 않았다.\n\n그들이 너를 깨운 것은 보호만도, 복수만도 아니었다. 너를 붙잡으면 내가 남긴 약속도 아직 끝나지 않았다고 믿을 수 있었기 때문이다."
const LAST_TEXT := "마지막 문은 내가 열 수 없도록 남겨 두었다. 그것을 배려라고 부를 생각은 없다.\n너에게 선택권을 돌려준 것이 아니라, 내가 끝내 빼앗지 못한 한 조각이 남아 있었을 뿐이다.\n이번에는 누구도 네 대답을 대신 적어서는 안 된다."

static func summary(state: Dictionary) -> Dictionary:
	var complete: Array = []
	var incomplete: Array = []
	var names: PackedStringArray = []
	var records := 0
	var lower := 0
	var upper := 0
	for index in range(5):
		var servant: Dictionary = state["meta_progress"]["servants"][OWNERS[index]]
		if servant["core_event_complete"]: complete.append(EVENTS[index])
		else:
			incomplete.append(EVENTS[index])
			names.append(NAMES[index])
			lower += MINUTES[index][0]
			upper += MINUTES[index][1]
		if servant["researcher_record_acquired"]: records += 1
	return {"core_complete_ids": complete, "incomplete_ids": incomplete, "researcher_record_count": records, "edgar_core_complete": "E3_4" in complete, "remaining_names": ", ".join(names), "minutes_min": lower, "minutes_max": upper}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"pages": [], "ordered": false}
	local.merge(state["loop_state"]["event_local_states"].get("J4", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var local := progress(state)
	var text := ""
	if not state["fracture_state"]["broken_reset_triggered"] or not knowledge.get("E2_INTRO_complete", false): return {"ok": false, "text": "파열 이후 합의를 먼저 확인한다."}
	if action == "confirm":
		if value != true or knowledge.get("j4_confirmed", false) or not knowledge.get("relationship_hub_open", false) or state["loop_state"]["location_id"] != "M1_CENTRAL_HALL": return {"ok": false, "text": "중앙홀에서 남은 사건을 확인한 뒤 진행한다."}
		var totals := summary(state)
		knowledge["j4_confirmation_snapshot"] = totals
		knowledge["j4_confirmed"] = true
		knowledge["relationship_hub_open"] = false
		for event in totals["incomplete_ids"]:
			meta["event_history"][event] = {"event_id": event, "lifecycle": "superseded", "reason": "J4_confirmed"}
		text = "완충 전력을 코어 경로와 마지막 저녁에 재배분한다. 남은 사건의 진행은 보관된다. 이는 실패나 완료가 아니다."
	else:
		if not knowledge.get("j4_confirmed", false): return {"ok": false, "text": "조사 종료를 먼저 확인한다."}
		if action == "minimum":
			if int(meta["journal_stage"]) < 4 or meta["servants"]["edgar"]["core_event_complete"] or knowledge.get("edgar_minimum_access", false): return {"ok": false, "text": "최소 접근 절차가 필요한 상태가 아니다."}
			knowledge["edgar_minimum_access"] = true
			text = "대시계 기계실 입구에서 에드가가 수직 핀을 건넨다.\n이것으로 코어 접근로까지는 열립니다. 그 이상은 귀하께서 확인해야 합니다. 지금 설명하면 제 변명이 먼저 남습니다.\n주인공이 핀을 꽂는다. 연구원 기록이나 관계 완료는 추가되지 않는다."
		else:
			if int(meta["journal_stage"]) >= 4: return {"ok": false, "text": "네 번째 일지는 이미 복원했다."}
			match action:
				"page":
					if not PAGES.has(str(value)): return {"ok": false, "text": "일지의 날짜 조각을 확인한다."}
					if str(value) not in local["pages"]: local["pages"].append(str(value))
					text = PAGES[str(value)]
				"clear":
					local["pages"] = []
					local["ordered"] = false
					text = "날짜 조각을 다시 펼친다. 없는 연구원 기록은 오답이 아니라 빈 인덱스다."
				"order":
					if local["pages"] != ORDER: return {"ok": false, "text": "앞 사건과 뒤 사건이 맞지 않는다. 약속과 전환, 고정된 역할과 기동을 대조한다."}
					local["ordered"] = true
					text = "네 사건 축이 이어진다. 미래를 약속했지만 선택 권한을 나누지 않았다는 모순이 남는다."
				"read":
					if not local["ordered"]: return {"ok": false, "text": "페이지를 배열한 뒤 모순 문장을 조사한다."}
					var totals := summary(state)
					var count := int(totals["researcher_record_count"])
					var full: bool = count == 5 and totals["core_complete_ids"].size() == 5
					var variant := "J4_FULL" if full else ("J4_EXPANDED" if count >= 2 else "J4_BASE")
					knowledge["j4_variant"] = variant
					text = "복원 인덱스: 사용인들은 연구원 인격이다. 저택의 관리 권한과 주인공 자신의 결정을 실행하는 권한은 서로 다르다.\n\n" + BASE_TEXT
					if count >= 2:
						for index in range(5):
							if meta["servants"][OWNERS[index]]["researcher_record_acquired"]:
								var key: String = "REC_" + String(OWNERS[index]).to_upper()
								text += "\n\n" + str(knowledge.get("chapter_notebook", {}).get(key, key + " · 획득한 기록 인덱스"))
					if full: text += "\n\n마라 2는 다른 네 사람의 이름과 감정 주석을 자기 저장 영역에 나누어 보관했다. 공간이 모자랄 때마다 자기 이름의 확인 기록부터 비웠다. 나는 중단시킬 권한을 끝까지 나누지 않았다."
					text += "\n\n" + LAST_TEXT
					meta["journal_stage"] = 4
					if not meta["servants"]["edgar"]["core_event_complete"]:
						state["loop_state"]["location_id"] = "H0_CLOCK_MACHINE"
					for flag in ["J4_complete", "researcher_personalities_known", "subject_only_core_procedure_known"]: knowledge[flag] = true
					var notes: Dictionary = knowledge.get("chapter_notebook", {})
					notes["J4"] = text
					knowledge["chapter_notebook"] = notes
				_:
					return {"ok": false, "text": "정의되지 않은 결산 행동이다."}
	state["loop_state"]["event_local_states"]["J4"] = local
	return {"ok": true, "state": state, "text": text}
