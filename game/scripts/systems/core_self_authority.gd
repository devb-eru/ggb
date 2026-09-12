class_name CoreSelfAuthority
extends RefCounted

const MARKS := {"sentence":["내일 아침,", "이 문장을", "읽어."], "house_glyph":["지붕", "몸체", "문"], "ink_corner":["모서리 첫 접촉", "안쪽 두 번째 접촉", "마지막 잉크점"]}
const INTENTS := {"reality":"지금은 밖으로 나가는 쪽으로 마음이 기운다.", "stay":"지금은 이곳에 남는 쪽으로 마음이 기운다.", "undecided":"아직 정하지 않았다."}
const REACTIONS := {"reality":"밖을 직접 보고 싶다.", "stay":"여기서 계속 살아가는 것도 내 선택일 수 있어.", "undecided":"모든 걸 본 뒤 정하겠다."}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"sequence":[], "past_verified":false, "current_verified":false}
	local.merge(state["loop_state"]["event_local_states"].get("F0_E",{}),true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("f0_record_roles_solved",false) or knowledge.get("F0_E_complete",false) or state["loop_state"]["location_id"] != "H0_CORE_PATH": return {"ok":false,"text":"기록 역할을 먼저 확인한다."}
	if state["ending_run"]["final_decision"] != "unset": return {"ok":false,"text":"최종 선택이 기록된 상태에서는 임시 의향을 다시 쓰지 않는다."}
	var mark: Dictionary = knowledge.get("self_authored_mark",{})
	if not MARKS.has(mark.get("type","")): return {"ok":false,"text":"A1 표시의 유형 기록을 확인할 수 없다. 저장 자료 확인이 필요하다."}
	var local := progress(state)
	var text := ""
	match action:
		"piece":
			if local["past_verified"] or str(value) not in MARKS[mark["type"]]: return {"ok":false,"text":"당시 표시의 조각을 선택한다."}
			if str(value) not in local["sequence"]: local["sequence"].append(str(value))
			text = "표시 조각을 놓았다."
		"clear":
			if local["past_verified"]: return {"ok":false,"text":"과거 연속성은 확인했다."}
			local["sequence"] = []
			text = "표시 조각을 다시 펼친다."
		"past":
			if local["sequence"] != MARKS[mark["type"]]: return {"ok":false,"text":"이전 표시와 순서가 다르다. 수첩의 원래 표시를 다시 확인한다."}
			local["past_verified"] = true
			text = "PAST SELF / CONTINUITY VERIFIED\n과거 자기 기록의 연속성이 확인되었다. 현재의 빈 줄은 아직 쓰이지 않았다."
		"author":
			if not local["past_verified"]: return {"ok":false,"text":"과거 자기 기록을 먼저 확인한다."}
			if str(value) != "subject": return {"ok":false,"text":"문장 내용이 아니라 작성 주체가 다르다. 현재의 주인공이 직접 작성해야 한다."}
			local["current_verified"] = true
			knowledge["subject_authority_restored"] = true
			text = "주인공이 빈 줄에 직접 쓴다.\n이 문장은 지금의 내가 쓴다.\nCURRENT AUTHOR: SUBJECT / AUTHORITY RESTORED\n현재 작성자: 주인공 · 권한 복원. 아직 현실이나 잔류를 고른 것은 아니다."
		"intent":
			if not local["current_verified"] or not INTENTS.has(str(value)): return {"ok":false,"text":"현재 작성자 확인 뒤 마음의 방향을 기록한다."}
			knowledge["f0_provisional_intent"] = str(value)
			knowledge["F0_E_complete"] = true
			meta["event_history"]["F0_E"] = {"event_id":"F0_E","lifecycle":"completed","variant_id":"INTENT_"+str(value).to_upper()}
			text = "주인공: "+REACTIONS[str(value)]+"\n비공개 임시 의향 기록 · 구속력 없음\n주인공 권한 복원 · 최종 결정 미정\n이 기록은 사용인에게 전달되지 않는다. 마지막 선택에서 다시 결정할 수 있다."
		_: return {"ok":false,"text":"정의되지 않은 인증 행동이다."}
	state["loop_state"]["event_local_states"]["F0_E"] = local
	return {"ok":true,"state":state,"text":text}
