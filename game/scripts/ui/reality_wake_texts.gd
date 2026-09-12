extends RefCounted

const RULES := preload("res://scripts/systems/reality_wake.gd")
const NAMES := {"edgar":"Edgar", "mara1":"Mara 1", "luca":"Luca", "iris":"Iris", "mara2":"Mara 2"}
const LABELS := {
	"location_body": ["현실 · 냉각실", "Reality · Cryo chamber"],
	"location_handoff": ["코어실 · 연결 해제 전 인계 기록", "Core room · Recorded handoff before disconnection"],
	"objective": ["현실 기상 · %s", "Waking into reality · %s"],
	"EDR_FAREWELL": ["마지막 인계", "Final handoff"],
	"EDR_DISCONNECT": ["연결 해제", "Disconnection"],
	"EDR_WAKE_BODY": ["첫 호흡", "First breath"],
	"EDR_BODY_CHECK": ["신체 확인", "Check your body"],
	"handoff_board": ["연결 해제 전 남긴 다섯 인격의 인계 기록\n현재 저전력 보존 상태와 별개의 마지막 재생이다.\n%s", "Handoff recordings left by the five personalities before disconnection.\nThis final playback is separate from their current low-power preservation.\n%s"],
	"farewell": ["인계 기록을 듣는다", "Listen to the handoff recording"],
	"disconnect": ["연결 해제와 감각 전환", "Disconnect and follow the change in sensation"],
	"wake_board": ["눈꺼풀을 실제로 들어 올리는 무게.\n짧고 얕은 첫 호흡은 이미 시작되었다.\n속도를 맞추거나 버튼을 연타할 필요는 없다.", "The weight of lifting your physical eyelids.\nThe first short, shallow breath has already begun.\nThere is no need to match a rhythm or press buttons rapidly."],
	"wake": ["열린 캡슐 안을 확인한다", "Look inside the open capsule"],
	"wake_body": ["첫 호흡이 돌아온다. 얕지만 끊기지 않는다. 손과 호흡 표시기, 풀린 고정 벨트가 보인다.", "Your first breath returns. Shallow, but unbroken. You can see your hand, a breathing monitor, and a loosened restraint."],
	"checked": [" · 확인함", " · Checked"],
	"protagonist": ["주인공", "Protagonist"],
	"body_finish": ["캡슐 아래의 수첩을 확인한다", "Examine the notebook beneath the capsule"],
	"disconnect_heat": ["가상 난로의 열기가 사라진다.", "The warmth of the simulated fireplace disappears."],
	"disconnect_pressure": ["귀 안쪽에 낮은 압력이 걸린다.", "A low pressure settles inside your ears."],
	"disconnect_taste": ["혀에 금속 맛이 남는다.", "A metallic taste lingers on your tongue."],
	"notebook_unavailable": ["시뮬레이션 수첩은 이곳에서 펼칠 수 없다. 캡슐 아래의 물리적 현장 수첩은 별개의 물건이다.", "The simulation notebook cannot be opened here. The physical field notebook beneath the capsule is a separate object."],
}
const BODY := {
	"OBJ_REALITY_HAND": ["Hand", "Pain and a slow tremor follow as you bend your fingers. Your skin feels heavier than the hand on the screen.", "It moved, even as it hurt."],
	"OBJ_REALITY_BREATH_MONITOR": ["Breathing monitor", "The monitor displays recovery guidance: three short pulses, a pause, then one long pulse. Your first breath has already begun. Input speed does not determine success or failure.", "The gap between the machine's rhythm and my breathing keeps changing."],
	"OBJ_REALITY_RESTRAINT": ["Restraint", "The emergency release handle is already halfway loose. It is within reach of your fingertips.", "Someone left it so I could undo it on my own."],
}
const COMPLETE := {
	"edgar":"The waking procedure is authorized. This time, the order came from you, not me.",
	"mara1":"If there's a toolbox outside, grab the 13-millimeter first. Actually, grab the lot. The world always breaks in the size you haven't got.",
	"luca":"Your first breaths... don't breathe too deeply. Short, slow... breathing, joints, then water... I'll leave it on the handoff page.",
	"iris":"Heehee, the seasons outside will be different from my garden's. This time, please be the first to see them, not me.",
	"mara2":"If it's boring out there, leave a review! One star and I'll come find you! ...If I can. Leave my name there, too!",
}
const INCOMPLETE := {
	"edgar":"I will carry out the waking procedure. The verified risks and operating records are on the handoff page.",
	"mara1":"The recording shows Mara 1 wiping away the last dust and clearing the passage.",
	"luca":"Your vital signs... they're recorded. The order for releasing the equipment... I handed that over, too.",
	"iris":"The external environment model is not an actual observation. I will not erase the warning that the model may be wrong.",
	"mara2":"An anonymous personality index. Three quick notes, then a missing beat. No explanation supplies a name in its place.",
}
const OVERLAYS := {
	"edgar":{"responsibility_recorded":"Edgar's audit signature remains in the shutdown log.", "authority_returned":"A SUBJECT signature remains beside the empty CUSTODIAN slot."},
	"mara1":{"original_attribution":"The audit copy, still bearing the responsible person's name, goes into preservation.", "protected_identifiers":"The redacted copy and the original hash are preserved together."},
	"luca":{"full_disclosure":"The full risk table is sent to the physical notebook's handoff page.", "stabilize_first":"The same risk table is sent in sequence, after the stabilization completion timestamp."},
	"iris":{"external_truth":"A note remains, asking you to check the actual season first.", "shelter_projection":"Control of the switch that turns off the greenhouse projection passes to you."},
	"mara2":{"merged":"One voice closes the index. The last note briefly trembles.", "separated":"The original and the annotation take turns speaking. 'Remember both of us.' The two indices are preserved separately."},
}
const IRIS := {
	"inferred_only":"Please do not confuse the seasonal model with observed readings.",
	"denied":"I do not agree with that interpretation of the log. Still, I will not stop you from waking.",
	"withheld":"My responsibility for taking part in your confinement remains, along with what I never managed to say.",
	"indirect":"I thought it would end if you disappeared. That does not mean the wish was right.",
	"direct_private":"Do you remember... what I said when we were alone? I will not repeat it here.",
	"public":"Before everyone, I acknowledged wishing for your death and taking part in your confinement. That responsibility remains.",
}
const NARRATION := {
	"연결 해제 전 남긴 인계 기록이다. 보존 중인 인격에게 질문을 보내는 통로는 아니다.": "This is a handoff recording made before disconnection. It is not a channel for sending questions to the preserved personality.",
	"현실 수첩 인계 페이지의 이름 필드가 강조된다. 주인공이 적었던 이름과 연결된 표식이다.": "The name field on the physical notebook's handoff page is highlighted. It is linked to the name you wrote.",
	"기록 속 시선은 공식적인 인계 위치에 머문다.": "In the recording, their gaze stays at the formal handoff position.",
	"잠깐 시선을 맞추고 인계 물건을 손에 직접 건넨다. 말끝이 늦어진다.": "Their eyes meet yours briefly as they place the handoff item directly in your hand. The last words come slowly.",
	"시선을 유지한 채 인계를 마친다.": "They maintain eye contact as the handoff ends.",
	"확인 뒤 한 걸음 물러난다.": "After confirming, they take a step back.",
	"가까이 남지만 제어권에는 손대지 않는다.": "They remain close but do not touch the controls.",
	"기록 속에서 절차를 한 번 확인한다. 주인공에게 추가 확인을 요구하지 않는다.": "In the recording, they check the procedure once. They do not ask you for another confirmation.",
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func name_for(owner: String, locale: String) -> String:
	return (NAMES if locale.begins_with("en") else RULES.NAMES)[owner]

static func body(id: String, locale: String) -> Array:
	return (BODY if locale.begins_with("en") else RULES.BODY)[id].duplicate()

static func farewell(state: Dictionary, owner: String, locale: String) -> Dictionary:
	# Canonical rules select the disclosure and integrity branches before translation.
	var result: Dictionary = RULES.farewell(state, owner).duplicate(true)
	if not locale.begins_with("en"): return result
	var translations: Dictionary = NARRATION.duplicate()
	for id in RULES.OWNERS:
		translations[RULES.COMPLETE[id]] = COMPLETE[id]
		translations[RULES.INCOMPLETE[id]] = INCOMPLETE[id]
		for outcome in RULES.OVERLAYS[id]: translations[RULES.OVERLAYS[id][outcome]] = OVERLAYS[id][outcome]
	for disclosure in RULES.IRIS: translations[RULES.IRIS[disclosure]] = IRIS[disclosure]
	for line in result["lines"]:
		line["text"] = translations.get(line["text"], line["text"])
		for id in RULES.OWNERS:
			if line["speaker"] == RULES.NAMES[id]: line["speaker"] = NAMES[id]
	return result
