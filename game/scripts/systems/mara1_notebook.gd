extends RefCounted

const RULES := preload("res://scripts/systems/mara1_relationship.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_MARA1_"
const SCREEN := {
	"ENTRY": "마라 1이 스패너로 배선 덮개를 붙든다.\n마른 종이 냄새가 난다. '이건... 닦는 걸로 끝나지 않겠슴다.'",
	"COMPLETE": "기록을 보존했다. 사건과 명령자·수행자의 책임은 남아 있다.\n수첩에서 마라 1의 연구 기록을 다시 확인할 수 있다.",
	"TERMINAL_0": "대각 나사선 · 솔 마찰음",
	"TERMINAL_1": "손바닥 승인각 · 두 번 확인음",
	"TERMINAL_2": "끊긴 사각 · 늦은 경고음",
	"ORDER": "날짜와 문서 참조, 닦임 방향을 대조해 파편을 순서대로 놓는다.",
}
const TITLES := {
	"PANEL": ["세 단자의 출처", "Three Terminal Sources"],
	"SOURCE_MISMATCH": ["일치하지 않는 단자", "A Mismatched Terminal"],
	"SOURCE_MAINT": ["정비 출처 확인", "Maintenance Source Identified"],
	"SOURCE_CONSENT": ["동의 출처 확인", "Consent Source Identified"],
	"SOURCE_AUDIT": ["감사 출처 확인", "Audit Source Identified"],
	"BRIDGE": ["가짜 브리지 해제", "Removing the False Bridge"],
	"CLEAR": ["다시 펼친 파편", "Fragments Laid Out Again"],
	"RESTORE": ["이어진 삭제 기록", "The Reconnected Deletion Record"],
	"CONFESS": ["마라 1의 고백", "Mara 1's Account"],
	"CHOOSE_ORIGINAL_ATTRIBUTION": ["원문과 책임 보존", "Preserving the Record and Responsibility"],
	"CHOOSE_PROTECTED_IDENTIFIERS": ["피해자 식별 정보 보호", "Protecting Victim Identifiers"],
	"LOG_CONSENT": ["전환 전날의 승인 원본", "Original Approval Before Conversion"],
	"LOG_FAILURE": ["전환 당일의 실패 보고", "Failure Report on Conversion Day"],
	"LOG_COMMAND": ["실패 뒤의 정리 명령", "The Cleanup Order After the Failure"],
	"ENTRY": ["닦는 것으로 끝나지 않는 일", "More Than Cleaning"],
	"COMPLETE": ["보존된 마라 1의 기록", "Mara 1's Preserved Record"],
	"TERMINAL_0": ["대각 나사선의 신호", "The Diagonal Screw-Line Signal"],
	"TERMINAL_1": ["손바닥 승인각의 신호", "The Palm Approval-Angle Signal"],
	"TERMINAL_2": ["끊긴 사각의 신호", "The Broken-Square Signal"],
	"ORDER": ["파편의 날짜와 닦임", "Dates and Wipe Marks on the Fragments"],
	"BRIDGE_SOURCES": ["분리 전 확인할 출처", "Sources to Check Before Disconnecting"],
	"RESTORE_ORDER": ["이어지지 않는 문서 참조", "Disconnected Document References"],
}


static func feedback_text(key: String) -> String:
	if key.begins_with("LOG_"): return RULES.LOGS.get(key.trim_prefix("LOG_").to_lower(), "")
	return RULES.TEXT.get(key, "")


static func paragraphs(key: String) -> Array:
	if not ROLLOUT.enabled(): return []
	var id := PREFIX + key
	var result: Array = []
	for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
		result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func record_text(outcome: String) -> String:
	return RULES.TEXT["CHOOSE_" + outcome.to_upper()] + "\n" + RULES.RECORD_BODY


static func write(state: Dictionary, outcome: String, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "RECORD_" + outcome.to_upper(), record_text(outcome), context, locale)


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in RULES.TEXT: rows[key] = _row(RULES.TEXT[key], TITLES[key], "dialogue", "feedback")
	for key in RULES.LOGS:
		var id := "LOG_" + String(key).to_upper()
		rows[id] = _row(RULES.LOGS[key], TITLES[id], "dialogue", "feedback")
		rows["SCREEN_" + id] = _row(RULES.LOGS[key], TITLES[id], "document_segment", "displayed")
	for key in SCREEN: rows["SCREEN_" + key] = _row(SCREEN[key], TITLES[key], "document_segment", "displayed")
	for key in RULES.STATUS: rows["STATUS_" + key] = _row(RULES.STATUS[key], TITLES[key], "document_segment", "displayed")
	for outcome in ["original_attribution", "protected_identifiers"]:
		var key: String = "RECORD_" + outcome.to_upper()
		rows[key] = _row(record_text(outcome), ["마라 1의 연구 기록", "Mara 1's Research Record"], "document_segment", "recorded")
	return rows


static func _row(text: String, titles: Array, kind: String, variant: String) -> Dictionary:
	return {"text": text, "titles": titles, "kind": kind, "variant": variant}
