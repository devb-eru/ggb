class_name ChapterOneDisplayTexts
extends RefCounted

const LOCATION_NAMES := {
	"M2_BEDROOM": ["주인공의 침실", "Subject's Bedroom"],
	"M1_CENTRAL_HALL": ["중앙홀", "Central Hall"],
	"M1_SERVANT_COMMON": ["사용인 공용실", "Servants' Common Room"],
	"M1_PARLOR": ["대응접실", "Parlor"],
	"M1_LIBRARY_OUTER": ["외부 서고", "Outer Library"],
	"M1_LIBRARY_INNER": ["기록 내실", "Inner Archive"],
	"M1_GREAT_CLOCK": ["서쪽 대시계", "West Great Clock"],
	"M1_NORTH_ARCHIVE_HALL": ["북쪽 기록 회랑", "North Archive Hall"],
}

const UI_TEXT := {
	"inner_door": ["기록 내실문", "Door to the Inner Archive"],
	"north_link": ["서재 연결문", "Library Connecting Door"],
	"north_known": ["구조를 기억한다", "I remember how it opens"],
	"north_locked": ["안쪽 걸쇠 잠김", "Latched from the inside"],
	"mara2_memory_action": ["마라 2에게 이름표를 묻는다", "Ask Mara 2 about the nameplates"],
	"mara2_memory_line": ["어제도 고쳤잖아! 이름표가 돌아왔다고 내가 잊어버린 건 아니거든!", "We fixed them yesterday! Just because the nameplates reset doesn't mean I forgot!"],
	"back_outer": ["외부 서고로", "To the Outer Library"],
	"back_hall": ["중앙홀로", "To the Central Hall"],
	"save_error": ["저장 오류: %s", "Save error: %s"],
}

const FEEDBACK_EN := {
	"같은 아침이다. 방의 흔적과 수첩을 비교해 본다.": "It is the same morning. I compare the room's traces with my notebook.",
	"프롤로그를 마친 뒤 진입할 수 있다.": "This chapter becomes available after completing the prologue.",
	"아직 갈 수 없는 장소다.": "I cannot go there yet.",
	"연결된 문을 통해 이동한다.": "I need to use a door connected to this room.",
	"먼저 에드가가 지나가기를 기다리거나 말을 건넨다.": "I should wait for Edgar to leave or speak to him first.",
	"기록 내실이 비는 구간을 확인하고 오늘의 일과를 마쳐야 한다.": "I need to identify when the inner archive is empty and finish today's routine.",
	"외부 서고의 내실문으로 접근한다.": "I need to enter through the inner-archive door in the outer library.",
	"연결문 걸쇠는 안쪽에서 잠겨 있다.": "The connecting door is latched from the inside.",
	"문턱을 넘는다.": "I cross the threshold.",
	"지금은 새 표식을 작성할 수 없다.": "I cannot make a new mark right now.",
	"표식을 남겼다. 아직 내일의 내가 읽기 전이라 증거는 완성되지 않았다.": "I left a mark. It will not be proof until tomorrow's me reads it.",
	"표식을 남긴 뒤 잠들어 다음 아침에 비교해야 한다.": "I need to leave a mark, sleep, and compare it the next morning.",
	"내가 쓴 표식이다. 수첩은 방과 다른 시간 위에 놓여 있다.": "This is the mark I wrote. The notebook sits outside the room's time.",
	"다음 아침과 비교할 표식을 먼저 남긴다.": "I should first leave a mark to compare with the next morning.",
	"젖은 천이 어제와 같은 호를 그린다. 책등 세 권과 다섯 이름표를 정리하고, 물이 끓는 동안 모래시계를 뒤집는다. 익숙한 일과가 끝났다.": "The damp cloth traces the same arc as yesterday. I straighten three book spines and five nameplates, then turn the hourglass while the water boils. The familiar routine is done.",
	"당일 탁본 네 장과 움직일 수 있는 점검함이 필요하다.": "I need all four rubbings from today and an inspection panel that can still move.",
	"교환할 두 자리를 선택한다.": "Select two positions to swap.",
	"회전할 자리를 선택한다.": "Select a position to rotate.",
	"대응접실 → 외부 서고 → 서쪽 대시계. 침실은 단절. 네 조각의 배치를 검증했다.": "Parlor -> Outer Library -> West Great Clock. The bedroom is isolated. I verified the four-piece layout.",
	"먼저 당일 탁본으로 배치를 확인한다.": "First verify the layout with today's rubbings.",
	"오늘의 시계망 작동은 끝났다. 결과를 확인한다.": "Today's clock-network operation is over. I should examine the result.",
	"역할과 시계를 확인한다.": "Check the role and the selected clock.",
	"표시된 네 전달 시점 중 하나를 선택한다.": "Select one of the four displayed transmission timings.",
	"봉인핀 파손 가능성을 확인한 뒤 작동한다.": "Acknowledge the risk of breaking the locking pin before activation.",
	"오늘의 일과를 마친 뒤 같은 침실에서 잠든다.": "Finish today's routine, then sleep in the same bedroom.",
	"네 탁본과 방향을 모두 확인해야 한다.": "I need to check all four rubbings and their orientations.",
	"외부 서고의 선이 서쪽 공명통이 아닌 동쪽으로 향한다. 뒷면에도 흑연이 묻어 있다.": "The outer-library line points east instead of toward the west resonator. There is graphite on the back as well.",
}


static func is_english(locale: String) -> bool:
	return locale.begins_with("en")


static func location_name(location_id: String, locale: String) -> String:
	if not LOCATION_NAMES.has(location_id):
		return location_id
	return String(LOCATION_NAMES[location_id][1 if is_english(locale) else 0])


static func location_header(location_id: String, morning: int, locale: String) -> String:
	var room := location_name(location_id, locale)
	return "%s · Morning %d" % [room, morning] if is_english(locale) else "%s · %d번째 아침 이후" % [room, morning]


static func ui(id: String, locale: String, values: Array = []) -> String:
	if not UI_TEXT.has(id):
		return id
	var result := String(UI_TEXT[id][1 if is_english(locale) else 0])
	return result % values if not values.is_empty() else result


static func feedback(source: String, locale: String) -> String:
	if source.is_empty() or not is_english(locale):
		return source
	if FEEDBACK_EN.has(source):
		return String(FEEDBACK_EN[source])
	if source.begins_with("정의되지 않은 행동이다: "):
		return "Undefined action: " + source.trim_prefix("정의되지 않은 행동이다: ")
	if source.begins_with("일치한 구간: "):
		var translated := PackedStringArray()
		for line in source.split("\n"):
			translated.append(_layout_line(String(line)))
		return "\n".join(translated)
	return source


static func _layout_line(source: String) -> String:
	if source.begins_with("일치한 구간: "):
		return "Matched sections: " + source.trim_prefix("일치한 구간: ")
	for index in range(1, 5):
		if source == "%d번 자리의 배선이 옆 조각과 이어지지 않는다." % index:
			return "The wiring in position %d does not connect to the neighboring piece." % index
		if source == "%d번 자리의 모서리 홈과 나사 구멍이 어긋난다." % index:
			return "The corner groove and screw hole in position %d do not align." % index
	return String(FEEDBACK_EN.get(source, source))
