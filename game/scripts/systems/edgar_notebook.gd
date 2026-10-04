extends RefCounted

const RULES := preload("res://scripts/systems/edgar_relationship.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_EDGAR_"
const SCREEN := {
	"ENTRY": "대시계 뒤 수직 잠금선이 드러난다.\n에드가가 레이피어로 네 선의 경계를 짚는다. '확인하실 기록이 있습니다.'",
	"COMPLETE": "선택권은 SUBJECT, 주인공에게 있다.\n수첩의 에드가 연구 기록에서 책임 내용을 확인할 수 있다.",
	"ORDER": "네 권한 변경 이력을 선행 사건 순서로 놓는다.",
}
const OWNER_LABELS := ["근거를 다시 읽는다", "SYSTEM", "CUSTODIAN", "RESIDENT", "SUBJECT"]
const TITLES := {
	"CLEAR": ["다시 펼친 권한 이력", "Reopened Authority History"],
	"AUDIT": ["명령과 운영자의 결정", "Commands and the Operator's Decisions"],
	"OWNER": ["기능과 소유자 토큰", "Functions and Owner Tokens"],
	"VALIDATED": ["돌아온 선택 권한선", "The Returned Choice-Authority Line"],
	"RESET_INVALID": ["모순인 배치의 복귀", "Returning Contradictory Assignments"],
	"CONFESS": ["에드가의 책임 보고", "Edgar's Responsibility Report"],
	"CHOOSE_DIRECT": ["직접 돌려받은 권한", "Authority Returned Directly"],
	"CHOOSE_RECORDED": ["감사 기록의 운영 서명", "The Operational Signature in the Audit"],
	"LOG_CONSENT": ["전환 동의 취합", "Collecting Consent for Conversion"],
	"LOG_PROTOCOL": ["절차 위반과 인격 보존", "Procedural Violations and Personality Preservation"],
	"LOG_VACANCY": ["사망 뒤의 권한 공백", "The Authority Vacancy After Father's Death"],
	"LOG_EXTENSION": ["공백 이후의 수면 연장", "Sleep Extension After the Vacancy"],
	"ENTRY": ["대시계 뒤의 잠금선", "Lock Lines Behind the Great Clock"],
	"COMPLETE": ["보존된 에드가의 기록", "Edgar's Preserved Record"],
	"ORDER": ["권한 변경의 선행 사건", "Events Preceding Authority Changes"],
	"AUDIT_ORDER": ["이어지지 않는 권한 이력", "Disconnected Authority History"],
}


static func paragraphs(keys: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		var id: String = PREFIX + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func options(key: String) -> Dictionary:
	var segments := {}
	var id := PREFIX + key + "_OPTIONS"
	for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []): segments[segment] = {}
	return CONTENT.descriptor(id, 1, segments)


static func write(state: Dictionary, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "RECORD", RULES.RECORD, context, locale)


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in RULES.TEXT:
		var titles: Array = TITLES.get(key, ["권한 배치의 모순", "A Contradiction in Authority Assignment"])
		if String(key).begins_with("CONFESS_"): titles = ["에드가의 응답", "Edgar's Response"]
		rows[key] = _row(RULES.TEXT[key], titles, "dialogue", "feedback")
	for key in RULES.LOGS:
		var id := "LOG_" + String(key).to_upper()
		rows[id] = _row(RULES.LOGS[key], TITLES[id], "dialogue", "feedback")
		rows["SCREEN_" + id] = _row(RULES.LOGS[key], TITLES[id], "document_segment", "displayed")
	for key in SCREEN: rows["SCREEN_" + key] = _row(SCREEN[key], TITLES[key], "document_segment", "displayed")
	for function in RULES.CLUES:
		rows["SCREEN_FUNCTION_" + function] = _row(RULES.CLUES[function], [function + " 기능", function + " Function"], "document_segment", "displayed")
	rows.STATUS_AUDIT_ORDER = _row(RULES.STATUS.AUDIT_ORDER, TITLES.AUDIT_ORDER, "document_segment", "displayed")
	rows.RECORD = _row(RULES.RECORD, ["에드가의 연구 기록", "Edgar's Research Record"], "document_segment", "recorded")
	return rows


static func modal_rows() -> Dictionary:
	var rows := {}
	for function in RULES.CLUES:
		rows["OWNER_" + function] = {"title": function, "body": RULES.CLUES[function], "labels": OWNER_LABELS, "choice_group": "OWNER", "titles": ["기능의 소유자 선택", "Choosing a Function's Owner"]}
	return rows


static func source_ids() -> Array:
	var ids: Array = ["NB_EDGAR_AUDIT", "NB_EDGAR_VALIDATED", "NB_EDGAR_CONFESS", "NB_MODAL_EDGAR_SELECT_1", "NB_MODAL_EDGAR_SELECT_2"]
	for key in RULES.LOGS:
		ids.append(PREFIX + "LOG_" + String(key).to_upper())
		ids.append(PREFIX + "SCREEN_LOG_" + String(key).to_upper())
	return ids


static func _row(text: String, titles: Array, kind: String, variant: String) -> Dictionary:
	return {"text": text, "titles": titles, "kind": kind, "variant": variant}
