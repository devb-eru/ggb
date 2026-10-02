extends RefCounted

const REST := preload("res://scripts/ui/fracture_rest_texts.gd")
const COMMON := preload("res://scripts/ui/fracture_common_display_texts.gd")
const BASEMENT := preload("res://scripts/ui/basement_display_texts.gd")
const TRANSITION := preload("res://scripts/ui/fracture_transition_texts.gd")
const PREFIX := "NB_FRACTURE_SURFACE_"
const HOLD_KO := [
	"손가락을 편다.\n손잡이는 바로 떨어지지 않고 손바닥의 떨림을 한 번 더 끌고 간다.",
	"톱니의 진동이 손금 사이에 남는다.\n꽃무늬 벽지는 배선 격자에서 천천히 밀려난다.",
	"촛불은 흔들리지 않는데 열이 사라진다.\n방이 망가진 것이 아니라, 숨기기를 멈추고 있다.",
]
const HOLD_EN := [
	"You open your fingers.\nThe handle does not fall away at once. It drags the tremor across your palm one last time.",
	"The gears keep vibrating between the lines of your hand.\nThe floral wallpaper slowly slips away from a wiring grid.",
	"The candle does not flicker, but its heat disappears.\nThe room is not breaking. It is ceasing to hide.",
]
const GUIDANCE := {
	180: "[취침 종: 깨진 간격으로 열한 번] 아직 통로를 더 살펴볼 수 있다.",
	480: "침실 또는 가까운 비상 캡슐에서 쉴 수 있다. 지금 잠들 필요는 없다.",
}
const ENTRY := "벽지 뒤에서 드러난 서비스 통로에 두 휴식 경로가 표시되어 있다."
const CHOICES := {"LUCA": ["luca_s2_ask", "luca_s2_hold", "luca_s2_withdraw"], "E2": ["e2_question_house", "e2_question_body", "e2_question_memory"]}


static func demo_key(index: int, reaction: Dictionary) -> String:
	var key := TRANSITION.reaction_key(reaction) if index == 3 else ""
	return "DEMO_%d" % index + ("_" + key if not key.is_empty() else "")


static func demo_text(index: int, reaction: Dictionary, locale: String) -> String:
	var text := BASEMENT.demo_beat(index, locale)
	var line := TRANSITION.reaction(reaction, locale) if index == 3 else {}
	return text + "\n\n" + String(line.speaker) + ": " + String(line.text) if not line.is_empty() else text


static func guidance_key(checkpoint: int, reaction: Dictionary) -> String:
	if checkpoint != 300: return "GUIDANCE_%d" % checkpoint
	var owner := String(reaction.get("owner", ""))
	return "GUIDANCE_300_" + owner + ("_ALERT" if reaction.get("mode") == "alert" else "_BOND") if REST.GUIDANCE_300.has(owner) else "GUIDANCE_300_DEFAULT"


static func guidance_text(checkpoint: int, reaction: Dictionary, locale: String) -> String:
	return REST.guidance_300(reaction, locale) if checkpoint == 300 else REST.text(GUIDANCE.get(checkpoint, ""), locale)


static func choice_text(group: String, locale: String) -> String:
	var labels := PackedStringArray()
	for id in CHOICES[group]: labels.append(COMMON.ui(id, locale))
	return "\n".join(labels)


static func retry_text(locale: String) -> String:
	return "Record not saved. Retry before continuing" if locale.begins_with("en") else "기록이 저장되지 않았습니다 · 저장 재시도 후 계속"


static func authored_rows() -> Dictionary:
	var result := {}
	_add(result, "D5_IDLE", "D5", ["드러난 기계", "The Exposed Machine"], BASEMENT.ui("d5_idle", "ko-KR"), BASEMENT.ui("d5_idle", "en-US"))
	for index in range(3): _add(result, "HOLD_%d" % index, "D5", ["손잡이를 놓은 뒤", "After Releasing the Handle"], HOLD_KO[index], HOLD_EN[index])
	for index in range(6): _add(result, demo_key(index, {}), "D5", ["드러나는 저택", "The Mansion Revealed"], demo_text(index, {}, "ko-KR"), demo_text(index, {}, "en-US"))
	for owner in TRANSITION.REACTIONS:
		for mode in ["bond", "alert"]:
			if not TRANSITION.REACTIONS[owner].has(mode + "_ko"): continue
			var reaction := {"owner": owner, "mode": mode}
			_add(result, demo_key(3, reaction), "D5", ["겹친 사용인의 윤곽", "The Servant's Double Outline"], demo_text(3, reaction, "ko-KR"), demo_text(3, reaction, "en-US"))
	for route in ["bedroom", "capsule"]:
		for index in range(3): _add(result, "SLEEP_%s_%d" % [route.to_upper(), index], "D6", ["눈을 감은 뒤의 신호", "Signals After Closing Your Eyes"], REST.sleep_transition(route, index * 2.0, "ko-KR").body, REST.sleep_transition(route, index * 2.0, "en-US").body)
	for checkpoint in [180, 300, 480]: _add(result, guidance_key(checkpoint, {}), "D6", ["휴식 경로 안내", "Guidance Toward Rest"], guidance_text(checkpoint, {}, "ko-KR"), guidance_text(checkpoint, {}, "en-US"))
	for owner in REST.GUIDANCE_300:
		for mode in ["bond", "alert"]:
			var reaction := {"owner": owner, "mode": mode}
			_add(result, guidance_key(300, reaction), "D6", ["사용인의 휴식 안내", "A Servant's Guidance Toward Rest"], guidance_text(300, reaction, "ko-KR"), guidance_text(300, reaction, "en-US"))
	_add(result, "D6_ENTRY", "D6", ["두 휴식 경로", "Two Routes to Rest"], ENTRY, REST.text(ENTRY, "en-US"))
	for stage in ["LUCA_GUIDE", "LUCA_S2", "E_HUB"]:
		var key: String = "hub_board" if stage == "E_HUB" else stage.to_lower() + "_board"
		_add(result, stage, stage, ["달라진 저택의 모습", "The Changed Mansion"], COMMON.ui(key, "ko-KR"), COMMON.ui(key, "en-US"))
	for group in CHOICES:
		var stage := "LUCA_S2" if group == "LUCA" else "E2_INTRO"
		_add(result, "OPTIONS_" + group, stage, ["표시된 질문과 행동", "Presented Questions and Actions"], choice_text(group, "ko-KR"), choice_text(group, "en-US"), "options_presented")
		for index in range(3): _add(result, "SELECT_%s_%d" % [group, index], stage, ["선택한 질문과 행동", "Selected Question or Action"], COMMON.ui(CHOICES[group][index], "ko-KR"), COMMON.ui(CHOICES[group][index], "en-US"), "choice_confirmed")
	return result


static func _add(result: Dictionary, key: String, stage: String, title: Array, ko: String, en: String, kind: String = "document_segment") -> void:
	result[key] = {"stage": stage, "title": title, "ko": ko, "en": en, "kind": kind}
