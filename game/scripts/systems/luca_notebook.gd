extends RefCounted

const RULES := preload("res://scripts/systems/luca_relationship.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_LUCA_"
const SCREEN := {
	"ENTRY": "조리대 아래의 배관이 손목과 비슷한 주기로 뛴다.\n루카가 문을 연다. '이번에는... 아가씨 기준부터 볼게요.'",
	"COMPLETE": "현재 생존 신호는 유지된다. 기상 안전은 확정되지 않았다.\n수첩에서 REC_LUCA를 다시 확인할 수 있다.",
	"CYCLE": "두 번의 주관 맥박 → 보조관 응답 → 안전 밸브\n시간 제한은 없다. 배치한 주기를 언제든 미리 확인할 수 있다.",
	"PIPE_DECORATION": "장식 매듭 · 맥박 없음",
	"PIPE_MAIN": "BIO MAIN · 굵은 이중 맥박",
	"PIPE_AUX": "AUX · 점선 한 번 응답",
}
const SLOT_TITLE := "밸브 위상"
const SLOT_BODY := "시간이 아니라 순서를 맞춘다. 전체 주기는 미리 확인할 수 있다."
const SLOT_LABELS := ["아직 배치하지 않는다", "주관 맥박 1", "주관 맥박 2", "보조관 응답 1", "안전 밸브 확인"]
const CYCLE_TEMPLATE := "{slot_0} → {slot_1} → {slot_2} → {slot_3}"
const TITLES := {
	"PANEL": ["손목과 배관의 맥박", "Pulses in My Wrist and the Pipes"],
	"PANEL_S2": ["차갑다는 말의 대상", "What the Cold Signal Meant"],
	"PIPE": ["진단 패널의 관 대조", "Comparing Pipes at the Diagnostic Panel"],
	"MATCH": ["아바타와 외부 신체의 신호", "Signals from Avatar and External Body"],
	"SLOT": ["밸브 위상 배치", "Assigning a Valve Phase"],
	"CYCLE": ["배치한 주기 확인", "Reviewing the Arranged Cycle"],
	"RUN_SUCCESS": ["안정된 주기와 기록 잠금", "The Stable Cycle and Record Lock"],
	"RUN_FAILURE": ["안전 밸브의 압력 복귀", "Pressure Released by the Safety Valve"],
	"CONFESS": ["루카의 이야기", "Luca's Account"],
	"RISK": ["남아 있는 기상 위험", "Remaining Awakening Risks"],
	"STABLE": ["현재 유지되는 순환", "Circulation Maintained for Now"],
	"LOG_PRESERVATION": ["냉각 유지 목적", "The Purpose of Cooling"],
	"LOG_APPROVAL": ["기상 공동 승인", "Joint Approval for Awakening"],
	"LOG_BLANK": ["비어 있는 기상 기준", "Missing Awakening Criteria"],
	"ENTRY": ["주방 아래 생명 유지 신호", "Life-Support Signals Beneath the Kitchen"],
	"COMPLETE": ["보존된 루카의 기록", "Luca's Preserved Record"],
	"PIPE_DECORATION": ["맥박 없는 장식관", "The Decorative Pipe Without a Pulse"],
	"PIPE_MAIN": ["주관의 이중 맥박", "The Main Pipe's Paired Pulse"],
	"PIPE_AUX": ["보조관의 응답", "The Auxiliary Pipe's Response"],
	"MATCH_SOURCES": ["다시 확인할 생체 신호", "Biological Signals to Check Again"],
}


static func paragraphs(keys: Array, cycle_values: Dictionary = {}) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		var id: String = PREFIX + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: cycle_values.duplicate(true) if key == "CYCLE" else {}}))
	return result


static func slot_options() -> Dictionary:
	var segments := {}
	for segment in CONTENT.definition(PREFIX + "SLOT_OPTIONS", 1).get("visible_segment_ids", []): segments[segment] = {}
	return CONTENT.descriptor(PREFIX + "SLOT_OPTIONS", 1, segments)


static func write(state: Dictionary, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "RECORD", RULES.RECORD, context, locale)


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in RULES.TEXT: rows[key] = _row(RULES.TEXT[key], TITLES[key], "dialogue", "feedback")
	rows.CYCLE = _row(CYCLE_TEMPLATE, TITLES.CYCLE, "dialogue", "feedback")
	for key in RULES.LOGS:
		var id := "LOG_" + String(key).to_upper()
		rows[id] = _row(RULES.LOGS[key], TITLES[id], "dialogue", "feedback")
		rows["SCREEN_" + id] = _row(RULES.LOGS[key], TITLES[id], "document_segment", "displayed")
	for key in SCREEN: rows["SCREEN_" + key] = _row(SCREEN[key], TITLES[key], "document_segment", "displayed")
	for key in RULES.STATUS: rows["STATUS_" + key] = _row(RULES.STATUS[key], TITLES[key], "document_segment", "displayed")
	rows.RECORD = _row(RULES.RECORD, ["루카의 연구 기록", "Luca's Research Record"], "document_segment", "recorded")
	return rows


static func _row(text: String, titles: Array, kind: String, variant: String) -> Dictionary:
	return {"text": text, "titles": titles, "kind": kind, "variant": variant}
