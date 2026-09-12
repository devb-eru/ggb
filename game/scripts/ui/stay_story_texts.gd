extends RefCounted

const RULES := preload("res://scripts/systems/stay_story.gd")
const CHARTER := preload("res://scripts/ui/stay_charter_texts.gd")
const LABELS := {
	"hall_location": ["잔류 · 중앙홀", "Staying · Central hall"],
	"dining_location": ["잔류 · 식당", "Staying · Dining room"],
	"objective": ["같은 저택의 다른 규칙", "Different rules in the same mansion"],
	"channel_selected": ["선택된 통신 채널: %s · 응답은 상대가 선택", "Selected channel: %s · The other person chooses whether to respond"],
	"dine": ["조사를 마치고 식당으로", "Finish investigating and go to the dining room"],
	"sit": ["주인공 자리로 간다", "Take your place"],
	"written": ["쓴 문장: ", "Written: "],
	"write": ["수첩에 쓴다: ", "Write in notebook: "],
	"warm": ["차 · 따뜻하게", "Tea · Warm"],
	"hot": ["차 · 더 뜨겁게", "Tea · Hotter"],
	"selected": [" · 선택함", " · Selected"],
	"final": ["이 저녁을 바라본다", "Look upon this evening"],
	"final_objective": ["ED_B 안정화 잔류 · FINAL DECISION: STAY", "ED_B Stabilized stay · FINAL DECISION: STAY"],
	"finish": ["이 저녁을 남긴다", "Let this evening remain"],
	"close": ["닫기", "Close"],
	"channel_title": ["공용 통신 채널", "Shared communication channel"],
	"channel_body": ["연결 대상을 선택해도 응답이나 이동을 강제하지 않는다.", "Selecting a recipient does not compel them to respond or move."],
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

const HALL := {
	"clock": ["Great clock", "The thirteenth position is no longer hidden: XIII / MANUAL. The clock does not order the next sleep."],
	"schedule": ["Schedule", "Mandatory times have been erased, leaving blank spaces and proposed notes. The final confirmation box is empty."],
	"door": ["Entrance door", "A frame label identifies the view as an outside projection. This door leads only to the garden, not an exit into reality."],
	"carpet": ["Central carpet", "Facility wiring is visible beneath the carpet pattern. Connection numbers left unerased follow your feet."],
	"cord": ["Call cord", "Instead of a bell that summons someone by force, a shared communication channel selector opens. The other person decides whether to answer."],
}
const TABLE := {
	"mara1": ["The stain left unerased", "I'm not cleaning this stain. It's a record. Hah, listen to me saying that.", "Mara 1 starts to wipe the stain, then notices your gaze and stops."],
	"luca": ["Tea that can change each time", "The tea's temperature... please choose it yourself today. If it's wrong, we can warm it again...", "Tea at the familiar temperature is set down. Even so, the temperature choice remains available."],
	"iris": ["The season outside", "Shall we keep spring? I won't erase the label saying it differs from the real wind.", "A MODEL label sits beside the ideal spring. This display is separate from outside observations."],
	"mara2": ["Portrait nameplate", "Let's swap nameplates every day! If you get it wrong, I win. If I forget... you tell me. The original index stays put!", "Mara 2 checks her own nameplate twice. Its position can change; the original index remains."],
	"edgar": ["The rapier set aside", "Will you also choose tomorrow's bedtime yourself? I have placed the rapier out of reach.", "The rapier stands straight, but its scabbard lock is open. Edgar does not finalize the schedule."],
}
const OVERLAYS := {
	"original_attribution": "Their own name and the responsible person's name remain on the do-not-delete list.",
	"protected_identifiers": "Personal identifier safeguards have been added to the shared rules.",
	"external_truth": "Outside sensor readings appear before the projection.",
	"shelter_projection": "The projection and outside readings appear side by side; the projection can be turned off at any time.",
	"full_disclosure": "All life-support warnings are available for shared review.",
	"stabilize_first": "After device stability is verified, all the same warnings are disclosed.",
	"responsibility_recorded": "The decision to confine you is not deleted from the operating record.",
	"authority_returned": "You have final confirmation over waking and bedtime.",
	"merged": "Current memories and returned annotations are retained in one index.",
	"separated": "The two frames are preserved separately with cross-links. Two voices propose swapping places.",
}
const SENTENCES := ["Tomorrow may be the same day again.", "But it does not have to be the same choice."]
const IRIS := {
	"외부 센서값과 연출값을 비교할 수 있어요.": "You can compare outside sensor readings with the displayed values.",
	"그 해석에는 동의하지 않아요. 그래도 계절 변경 권한은 돌려드려요.": "I do not agree with that interpretation. Still, I return control over changing the season to you.",
	"말하지 못한 부분이 있어도 변경 이력은 모두 공개할게요.": "Even with things I could not say, I will disclose the entire change history.",
	"계절 장치를 멈출 권한도 공동 규칙에 넣어요.": "Let us also put the right to stop the seasonal device into the shared rules.",
	"둘이 나눈 말은 공동 규칙의 명분으로 이용하지 않을게요.": "I will not use what we said in private as a justification for the shared rules.",
	"모두 앞에서 인정한 책임은 남아요. 그 책임을 지우지 않고 규칙을 써요.": "The responsibility I acknowledged before everyone remains. Let us write the rules without erasing it.",
}

static func hall(id: String, index: int, locale: String) -> String:
	return (HALL if locale.begins_with("en") else RULES.HALL)[id][index]

static func table_title(owner: String, locale: String) -> String:
	return (TABLE if locale.begins_with("en") else RULES.TABLE)[owner][0]

static func sentence(index: int, locale: String) -> String:
	return (SENTENCES if locale.begins_with("en") else RULES.SENTENCES)[index]

static func table_lines(state: Dictionary, owner: String, locale: String) -> Array:
	var lines: Array = RULES.table_lines(state, owner).duplicate(true)
	if not locale.begins_with("en"):
		return lines
	var translations: Dictionary = IRIS.duplicate()
	for id in RULES.TABLE:
		for index in [1, 2]: translations[RULES.TABLE[id][index]] = TABLE[id][index]
	for outcome in RULES.OVERLAYS: translations[RULES.OVERLAYS[outcome]] = OVERLAYS[outcome]
	for line in lines:
		line["text"] = translations.get(line["text"], line["text"])
		for id in RULES.OWNERS:
			if line["speaker"] == RULES.OWNERS[id]: line["speaker"] = CHARTER.owner(id, "en")
	return lines

static func seating(state: Dictionary, locale: String) -> String:
	var original: String = RULES.seating(state)
	if not locale.begins_with("en"): return original
	var translations := {
		"주인공만 앉는다. 양옆에 선 인물도 퇴장과 착석을 선택할 수 있다.": "Only you sit. Those standing on either side may also choose to leave or take a seat.",
		"다섯 인물이 각자의 이름과 경계를 유지한 채 앉는다.": "All five sit, retaining their own names and boundaries.",
		"네 인물이 앉는다. 빈 자리에는 기능 패널 대신 이름표가 남는다.": "Four sit. A nameplate, not a function panel, remains at the empty place.",
		"관계 완료 인물은 앉고, 다른 인물은 자신이 고른 일을 하며 왕래한다.": "Those whose relationship events are complete sit; the others come and go, doing work they have chosen.",
	}
	for id in RULES.OWNERS:
		translations[RULES.OWNERS[id] + ": 앉을 자리를 직접 고른다."] = CHARTER.owner(id, "en") + ": chooses where to sit."
		translations[RULES.OWNERS[id] + ": 서 있거나 이동할 자리를 직접 고른다."] = CHARTER.owner(id, "en") + ": chooses where to stand or move."
	var result := PackedStringArray()
	for paragraph in original.split("\n"): result.append(translations.get(paragraph, paragraph))
	return "\n".join(result)
