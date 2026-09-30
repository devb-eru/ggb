class_name FatherFinalRecord
extends RefCounted

const TITLES := ["외부 붕괴","주인공 냉각","차와 낙서 저택","연구원 전환","존재 방식","실행 불가능한 해방","강제 기동 · 사후 기록","미완성 권한"]
const SEGMENTS := [
	"네가 이 기록을 듣는다면, 저택은 더는 네가 그렸던 모습만으로 남아 있지 않을 것이다.\n밖의 지구는 내가 너를 잠들게 했을 때 이미 무너지고 있었다. 공기와 물은 지역마다 달랐고, 사람이 다시 살 수 있다는 계산은 끝내 하나로 모이지 않았다.",
	"나는 네 몸을 냉각 장치에 남겼다. 살릴 방법을 찾기 위해서였다고 말할 수 있다. 하지만 네게 묻지 않았다는 사실은 그 말로 없어지지 않는다.",
	"이 저택은 네 낙서에서 가져왔다. 네가 두려워하지 않을 집을 만들고 싶었다. 결국 나는 네가 의심하기 어려운 감옥의 모양을 알고 있었던 셈이다.\n네가 차를 내올 때마다 잔 손잡이를 내 왼손 쪽으로 돌려놓았지. 저택 그림에 문이 없다고 했을 때는 함께 한 줄을 그었다. 나는 문을 네가 고르는 곳에 두자고 말했다. 그 말을 해 놓고도 네가 열 수 없는 문을 만들었다.",
	"연구원들에게는 미래의 몸을 약속했다. 그들이 동의한 것은 새로운 삶이었다. 내가 실제로 만든 것은 생체 신경 코어와 인격 프로세스를 결합해 시스템 역할에 묶은 지속이었다.",
	"저장된 기억만 따로 복사해도 지금의 그들이 되는 것은 아니다.\n[첨부 기술 로그] 아카이브 우선순위는 마라 2에게 맡겨졌다. 자동 삭제 정책은 완전히 해제되지 않았다. 다른 연구원 원본을 보존하려 자기 저장 영역을 양도한 흔적이 있다. 이를 중단할 권한은 공유되지 않았다.",
	"그들의 원래 몸은 돌아갈 수 없게 되었다. 새 몸으로 옮길 배양·접속 모듈은 네 냉각 장치와 생명 유지 전원을 살리기 위해 분해했다. 도면은 남았지만 이 시설에는 새 몸도, 다시 만들 공장도 없다. 지금 분리를 실행하면 그들을 풀어 주는 것이 아니라 기억과 신경을 되돌릴 수 없게 끊을 수 있다.\n[기록 종료 이력] 해제 권한은 설계자의 사망 시점까지 미완성이었다. 임시 전환에는 끝나는 날짜가 없었다.",
	"[시스템 사후 기록 · 아버지 음성 아님]\n설계자 사망 이후 사용인들이 주인공 의식을 강제로 기동했다. 외부 안전 복구 완료 신호는 없었다.\n외로움과 분노, 보호와 보복이 함께 작용한 정황이 남아 있다. 이를 이해하는 것과 용서할 의무는 같지 않다.",
	"밖은 아직 안전하다고 말할 수 없다. 안은 네가 원한다면 삶이 될 수 있지만, 진실을 지운 채 유지한다면 다시 내가 만든 감옥이 된다.\n나는 어느 쪽이 옳다고 적지 않겠다. 그 침묵조차 마지막까지 책임을 미루는 일일 수 있다. 그래도 이번 답은 네가 쓰는 문장이어야 한다.\n나는 네가 눈을 뜨면 어디에 있는지, 내가 무엇을 했는지 먼저 말하겠다고 약속했다. 그 다음은 네가 정한다고도 말했다. 나는 그 약속을 지키지 못했다."
]
const J5_TEXT := "나는 너를 살린다는 이유로 네 시간을 멈췄다. 그들을 구한다는 말로 그들의 시간을 역할 속에 묶었다.\n밖은 아직 안전하다고 약속할 수 없다. 안은 거짓에서 시작됐지만, 네가 고른다면 전부 거짓인 삶은 아닐 수 있다.\n나는 용서를 요구하지 않는다. 무엇을 선택하라고 남길 권리도 없다.\n마지막 두 줄은 비워 둔다. 어디로 갈지를 쓰기 전에, 누가 이 문장을 쓰고 있는지 먼저 확인해라."

static func progress(state: Dictionary) -> Dictionary:
	var local := {"entered":false,"authenticated":false,"next":0,"j5_read":false}
	local.merge(state["loop_state"]["event_local_states"].get("F1",{}),true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("F0_E_complete",false) or not knowledge.get("subject_authority_restored",false) or int(meta["journal_stage"]) >= 5: return {"ok":false,"text":"주인공 권한을 확인한다."}
	var local := progress(state)
	var text := ""
	match action:
		"enter":
			local["entered"] = true
			state["loop_state"]["location_id"] = "H0_CORE_RECORDS"
			text = "코어 기록실. 재생 장치가 기다리고 있다. 기록은 스스로 시작되지 않는다."
		"inspect":
			if not local["entered"]: return {"ok":false,"text":"기록실에 먼저 들어간다."}
			text = "서버 랙 사이에 종이 냄새가 남아 있다. 냉각관에 손을 대면 소리가 뼈 안쪽에서 울리는 것 같다.\n편집 이력: J1~J4는 원본 기록에서 파생되었으며 시스템과 사용인이 일부를 잘라 표시했다. 원본 음성과 사후 첨부 로그는 별도 출처로 표시된다."
		"authenticate":
			var mark: Dictionary = knowledge.get("self_authored_mark",{})
			if not local["entered"] or str(value) != str(mark.get("type","")) or str(value).is_empty(): return {"ok":false,"text":"수첩에 남긴 자기 표시를 입력한다."}
			local["authenticated"] = true
			text = "CURRENT REQUESTER: SUBJECT / CREATOR LOG: ORIGINAL / EDIT HISTORY: PRESENT\n현재 요청자: 주인공 · 원본 기록 · 편집 이력 있음\n재생할 준비가 되면 직접 시작한다."
		"play":
			if not local["authenticated"]: return {"ok":false,"text":"현재 요청자를 먼저 인증한다."}
			var index: int = value if value is int else -1
			if index < 0 or index >= SEGMENTS.size() or index > int(local["next"]): return {"ok":false,"text":"첫 재생은 기록 순서대로 진행한다."}
			text = TITLES[index]+"\n"+SEGMENTS[index]
			if index == int(local["next"]): local["next"] += 1
			if local["next"] == SEGMENTS.size():
				for flag in ["father_final_record_played","CREATOR_LOG_ORIGINAL","KN_F1_BODY_PRESERVATION","KN_F1_RESEARCHER_CONVERSION","KN_F1_RESIDENT_CORE_CONTINUITY","KN_F1_RELEASE_HARDWARE_LOST","KN_F1_FORCED_AWAKENING","KN_F1_UNFINISHED_RELEASE_AUTHORITY","MEM_FATHER_CHOICE_PROMISE_COMPLETE"]: knowledge[flag] = true
				meta["event_history"]["F1"] = {"event_id":"F1","lifecycle":"completed"}
		"page":
			if not knowledge.get("father_final_record_played",false): return {"ok":false,"text":"원본 기록을 먼저 확인한다."}
			local["j5_read"] = true
			text = J5_TEXT
		"write":
			if not local["j5_read"] or str(value) != "subject": return {"ok":false,"text":"남의 문장이 아니라 지금의 주인공이 마지막 두 줄을 쓴다."}
			if state["ending_run"]["final_decision"] != "unset": return {"ok":false,"text":"최종 결정 상태를 확인해야 한다."}
			text = "이 문장은 지금의 내가 쓴다.\n마지막 결정은 아직 확정하지 않는다.\n다섯 번째 일지가 복원되었다."
			meta["journal_stage"] = 5
			knowledge["J5_complete"] = true
			var notes: Dictionary = knowledge.get("chapter_notebook",{})
			notes["J5"] = J5_TEXT+"\n"+text
			knowledge["chapter_notebook"] = notes
			meta["event_history"]["J5"] = {"event_id":"J5","lifecycle":"completed"}
		_: return {"ok":false,"text":"정의되지 않은 기록 행동이다."}
	state["loop_state"]["event_local_states"]["F1"] = local
	return {"ok":true,"state":state,"text":text}
