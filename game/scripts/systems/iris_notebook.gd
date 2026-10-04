extends RefCounted

const RULES := preload("res://scripts/systems/iris_relationship.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_IRIS_"
const SCREEN := {
	"ENTRY": "빛은 따뜻하지만 공기는 차갑다.\n흙은 젖지 않은 채 젖은 냄새만 난다. 이리스가 웃는다. '안쪽을 보실래요?'",
	"COMPLETE": "외부값의 결손과 승인 도용 기록을 보존했다.\n수첩에서 이리스의 연구 기록을 확인할 수 있다.",
	"ORDER": "날짜와 앞 문서의 참조로 전력 기록을 연결한다.",
	"AUDIT": "경고 제출자: 이리스\n명령 실행자: 아버지 / 사용 자격: 이리스\n감사 책임자: 이리스\n무엇이 어긋났는가?",
}
const CHANNEL_TITLE := "입력 출처"
const CHANNEL_BODY := "꽃잎의 반복 / 유리의 결손 파형 / 후광의 과거 날짜를 대조한다."
const CHANNEL_LABELS := ["문양과 날짜를 다시 본다", "투사 연출", "외부 센서", "기억 모델"]
const TITLES := {
	"PANEL": ["겹쳐 있는 계절 입력", "Overlapping Seasonal Inputs"],
	"SOURCE_MISMATCH": ["일치하지 않는 계절 출처", "A Mismatched Seasonal Source"],
	"SOURCE_MATCH": ["분리된 입력과 빈 외부값", "Separated Inputs and Missing External Readings"],
	"CLEAR": ["다시 대조하는 전력 기록", "Comparing the Power Records Again"],
	"RESTORE": ["복원한 전력 기록", "The Restored Power Record"],
	"AUDIT": ["자격 소유자와 명령 실행자", "Credential Owner and Command Executor"],
	"CONFRONT": ["이리스의 이야기", "Iris's Account"],
	"CHOOSE_EXTERNAL_TRUTH": ["외부값과 책임 기록 보존", "Preserving Readings and Responsibility"],
	"CHOOSE_SHELTER_PROJECTION": ["기록 보존과 온실 연출 유지", "Preserving Records and the Greenhouse Projection"],
	"CONFESSION_DIRECT_PRIVATE": ["이리스의 응답", "Iris's Response"],
	"CONFESSION_INDIRECT": ["이리스의 응답", "Iris's Response"],
	"CONFESSION_DENIED": ["이리스의 응답", "Iris's Response"],
	"CONFESSION_WITHHELD": ["이리스의 응답", "Iris's Response"],
	"ALERT": ["가늘고 날카로워진 목소리", "A Thin, Sharp Voice"],
	"LOG_WARNING": ["최초 전력 경고", "The Initial Power Warning"],
	"LOG_COMMAND": ["냉각 우선 명령", "The Cooling-Priority Order"],
	"LOG_LOSS": ["명령 뒤 설비 손실", "Facility Loss After the Order"],
	"LOG_AUDIT": ["자동 감사의 책임자", "Responsibility in the Automated Audit"],
	"LOG_CONVERSION": ["처리되지 않은 정정 요청", "The Unresolved Correction Request"],
	"ENTRY": ["빛과 공기가 다른 온실", "Warm Light and Cold Air"],
	"COMPLETE": ["보존된 이리스의 기록", "Iris's Preserved Record"],
	"ORDER": ["전력 문서의 날짜와 참조", "Dates and References in the Power Documents"],
	"RESTORE_ORDER": ["이어지지 않는 전력 기록", "Disconnected Power Records"],
	"AUDIT_MISMATCH": ["경고와 승인 사이의 차이", "The Difference Between Warning and Approval"],
}


static func paragraphs(keys: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		var id: String = PREFIX + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func channel_options() -> Dictionary:
	var segments := {}
	for segment in CONTENT.definition(PREFIX + "CHANNEL_OPTIONS", 1).get("visible_segment_ids", []): segments[segment] = {}
	return CONTENT.descriptor(PREFIX + "CHANNEL_OPTIONS", 1, segments)


static func write(state: Dictionary, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "RECORD", RULES.RECORD, context, locale)


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in RULES.TEXT: rows[key] = _row(RULES.TEXT[key], TITLES[key], "dialogue", "feedback")
	for key in RULES.LOGS:
		var id := "LOG_" + String(key).to_upper()
		rows[id] = _row(RULES.LOGS[key], TITLES[id], "dialogue", "feedback")
		rows["SCREEN_" + id] = _row(RULES.LOGS[key], TITLES[id], "document_segment", "displayed")
	for key in SCREEN: rows["SCREEN_" + key] = _row(SCREEN[key], TITLES[key], "document_segment", "displayed")
	for gauge in RULES.CHANNELS:
		for index in range(3):
			var id := "SCREEN_CHANNEL_%s_%d" % [String(gauge).to_upper(), index]
			var names: Array = {"temperature": ["온도", "Temperature"], "humidity": ["습도", "Humidity"], "light": ["광량", "Light"]}[gauge]
			rows[id] = _row(RULES.CLUES[RULES.CHANNELS[gauge][index]], ["%s 입력 %d" % [names[0], index + 1], "%s Input %d" % [names[1], index + 1]], "document_segment", "displayed")
	for key in RULES.STATUS: rows["STATUS_" + key] = _row(RULES.STATUS[key], TITLES[key], "document_segment", "displayed")
	rows.RECORD = _row(RULES.RECORD, ["이리스의 연구 기록", "Iris's Research Record"], "document_segment", "recorded")
	return rows


static func _row(text: String, titles: Array, kind: String, variant: String) -> Dictionary:
	return {"text": text, "titles": titles, "kind": kind, "variant": variant}
