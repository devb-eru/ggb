extends RefCounted

const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const MARK_IDS := ["A1_SENTENCE", "A1_HOUSE_GLYPH", "A1_INK_CORNER"]
const SELF_MARK_VERIFIED := "같은 표식이 남았다. 방의 물리 상태는 되돌아와도 수첩의 기록은 유지된다."
const FAILURE_RESOLVED := "시계망의 신호를 파형으로 기록했다. 이전 실패의 원인과 꺾인 핀에 대한 기록은 지우지 않는다."


static func write(state: Dictionary, id: String, source_text: String, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, "NB_CH1_NOTE_" + id, source_text, context, locale, 2 if id in MARK_IDS else 1)


static func mark_text(type: String) -> String:
	var id := "A1_" + type.to_upper()
	if id not in MARK_IDS: return ""
	return CONTENT.definition("NB_CH1_NOTE_" + id, 2).locales["ko-KR"].body
