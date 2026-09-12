class_name ResearcherConfrontation
extends RefCounted

const FACTS := {
	"KN_F2_PROMISED_FUTURE_BODIES":"에드가: 연구원들이 동의한 것은 미래의 육체와 새로운 삶이었습니다.",
	"KN_F2_RESEARCHERS_CONVERTED":"인격 인덱스: 실제 전환은 생체 신경 코어와 인격 프로세스를 결합한 지속이다. 기억 파일만 복사해 현재의 한 사람을 옮길 수는 없다.",
	"KN_F2_RELEASE_NOT_CURRENTLY_EXECUTABLE":"인격 인덱스: 호환 신체와 배양·접속 모듈이 없다. 불완전 분리는 기억 파편화·신경 손상·현재 인격 소실 위험을 가진다. 현실 분기의 기본 절차는 저전력 보존이다. 미래 복구는 외부 기반 발견 여부에 달려 있으며, 지금 즉시 해방하는 제3 선택은 없다.",
	"KN_F2_FORCED_SUBJECT_ACTIVATION":"에드가: 아버님 사망 뒤 외로움과 원망, 보호 욕구를 이유로 귀하를 강제로 기동했습니다. 관리 판단이라는 말로 책임이 없어지지는 않습니다.",
	"KN_F2_EXTERNAL_SURVIVAL_UNCERTAIN":"루카: 바깥 몸의 생존 신호는 있어요... 기상과 외부 생활의 안전까지 보장하지는 않아요.\n이리스: 외부 환경은 아직 안전하다고 말할 수 없어요.",
	"KN_F2_FINAL_AUTHORITY_BELONGS_TO_SUBJECT":"에드가: 현실의 안전도, 이곳의 영속도 보증할 수 없습니다. 그러므로 어느 쪽도 귀하를 대신하여 확정하지 않겠습니다."
}
const QUESTIONS := {"consent":"아버지와 어떤 동의를 했나요?","awakening":"왜 나를 강제로 깨웠나요?","outside":"밖은 어떤 상태인가요?","release":"연구원들을 해방할 수 있나요?","wish":"지금 무엇을 바라나요?"}
const TOPICS := {"consent":["KN_F2_PROMISED_FUTURE_BODIES","KN_F2_RESEARCHERS_CONVERTED"],"awakening":["KN_F2_FORCED_SUBJECT_ACTIVATION"],"outside":["KN_F2_EXTERNAL_SURVIVAL_UNCERTAIN"],"release":["KN_F2_RELEASE_NOT_CURRENTLY_EXECUTABLE"],"wish":["KN_F2_FINAL_AUTHORITY_BELONGS_TO_SUBJECT"]}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"entered":false,"questions":[],"facts":[],"recapped":false}
	local.merge(state["loop_state"]["event_local_states"].get("F2",{}),true)
	return local

static func tier(state: Dictionary) -> String:
	var count := 0
	for owner in state["meta_progress"]["servants"]:
		if state["meta_progress"]["servants"][owner]["core_event_complete"]: count += 1
	return "ALL" if count == 5 else ("HIGH" if count == 4 else ("MID" if count >= 2 else "LOW"))

static func iris_state(state: Dictionary) -> String:
	var iris: Dictionary = state["meta_progress"]["servants"]["iris"]
	if tier(state)=="ALL": return "public"
	if not iris["core_event_complete"]: return "inferred_only"
	if int(iris["bond"])>=4: return "direct_private"
	if int(iris["bond"])>=2: return "indirect"
	return "denied" if int(iris["alert"])>=4 else "withheld"

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if int(meta["journal_stage"])<5 or not knowledge.get("subject_authority_restored",false) or knowledge.get("F2_complete",false): return {"ok":false,"text":"마지막 일지와 주인공 권한을 확인한다."}
	var local := progress(state)
	var text := ""
	match action:
		"enter":
			if local["entered"]: return {"ok":false,"text":"대면 기록이 이미 열렸다."}
			local["entered"] = true
			text = "에드가: 대면 기록은 SUBJECT 권한으로 열렸습니다. 누구도 귀하의 종료 결정을 대신 쓸 수 없습니다.\n루카: 외부 신체의 생존 신호와... 기상 위험이 함께 있어요.\n마라 1: 삭제하고 고친 기록이 있었슴다. 지금 이 대면 로그는 지울 수 없어요.\n이리스: 외부 안전은 보장할 수 없어요.\n인격 인덱스: 다섯 RESIDENT는 아버지와 일한 연구원 인격이다."
			text += "\n[환경 인증 기록] 아버지가 이리스의 인증을 도용해 복구 전력을 냉각과 시뮬레이션으로 전용했다. 생태 표본 손실과 감사 책임이 이리스에게 전가됐다. 주인공은 그 결정을 내리지 않았다."
			match iris_state(state):
				"public": text += "\n이리스: 당신이 죽기를 바랐어요. 빼앗긴 것들의 책임을 당신에게 돌렸죠. 감금에 가담한 것도 제 책임이에요. 다른 누구의 용서로 지울 수 없어요."
				"direct_private": text += "\n이리스: 둘이 있을 때 한 말은 사실이에요. 여기서 다시 낭독해 달라고 요구하지는 않을게요."
				"indirect": text += "\n이리스: 당신이 없으면 끝날 거라 생각했어요."
				"denied": text += "\n이리스: 그 로그가 제 의도까지 증명하지는 않아요."
				"withheld": text += "\n이리스: 가두는 일에 가담했어요. 그 책임은 인정해요."
				_: text += "\n주인공은 전력 기록과 이리스의 행동 사이 모순을 읽는다. 이리스는 직접 인정하지 않는다."
		"question":
			if not local["entered"] or not QUESTIONS.has(str(value)): return {"ok":false,"text":"대면 후 질문을 고른다."}
			if str(value) not in local["questions"]: local["questions"].append(str(value))
			for fact in TOPICS[str(value)]:
				text += FACTS[fact]+"\n"
				if fact not in local["facts"]: local["facts"].append(fact)
		"recap":
			if not local["entered"]: return {"ok":false,"text":"먼저 대면 기록을 연다."}
			for fact in FACTS:
				if fact not in local["facts"]:
					text += FACTS[fact]+"\n"
					local["facts"].append(fact)
			local["recapped"] = true
			text += "마라 1: 동의 절차를 숨긴 기록에 제 손도 있었슴다.\n인격 인덱스: 체크섬은 의식의 백업이 아니라 현재 인격의 손상 여부를 확인하는 자료다.\nFINAL DECISION: UNSET · 최종 결정 미정\n미정은 빈칸이 아니라 주인공이 아직 쓰지 않았다는 기록이다."
		"finish":
			if not local["recapped"] or local["facts"].size()!=6: return {"ok":false,"text":"누락된 필수 사실을 확인한다."}
			knowledge["F2_complete"] = true
			meta["event_history"]["F2"] = {"event_id":"F2","lifecycle":"completed","variant_id":tier(state)}
			text = "대면 기록을 닫는다. 다음 방의 두 장치와 주인공 수첩이 마지막 확인을 기다린다."
		_: return {"ok":false,"text":"정의되지 않은 대면 행동이다."}
	for fact in local["facts"]: knowledge[fact] = true
	state["loop_state"]["event_local_states"]["F2"] = local
	return {"ok":true,"state":state,"text":text}
