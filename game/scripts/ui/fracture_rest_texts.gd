extends RefCounted

const GUIDANCE_300 := {
	"EDGAR": {
		"bond_ko": "에드가의 진단 투사: 두 휴식 경로는 모두 유효합니다. 어느 쪽을 택할지는 아가씨께서 결정하십시오.",
		"bond_en": "Edgar's diagnostic projection: Both routes to rest are valid. You will decide which one to take, my lady.",
		"alert_ko": "에드가의 진단 투사: 절차 밖의 이동은 기록 중입니다. 그래도 수면 경로 선택은 아가씨의 권한입니다.",
		"alert_en": "Edgar's diagnostic projection: Movement outside procedure is being logged. Even so, the route to rest remains your decision, my lady.",
	},
	"MARA1": {
		"bond_ko": "마라 1의 진단 잔상: 길은 둘 다 열어뒀슴다. 이번엔 아가씨가 정할 때까지 안 재촉하겠슴다.",
		"bond_en": "Mara 1's diagnostic trace: Both routes are open. This time, I won't rush you before you decide.",
		"alert_ko": "마라 1의 진단 잔상: 어느 길로 가는지는 지켜보겠슴다. 막지는 않겠지만요.",
		"alert_en": "Mara 1's diagnostic trace: I'll be watching which route you take. I won't stop you, though.",
	},
	"LUCA": {
		"bond_ko": "루카의 진단 잔상: 두 길은... 같은 곳으로 이어져요. 그래도 고르는 건 아가씨가 하셔야 해요...",
		"bond_en": "Luca's diagnostic trace: Both routes... lead to the same place. Even so, you should be the one to choose...",
		"alert_ko": "루카의 진단 잔상: 어느 쪽을 고르셔도... 장치는 기록해요. 저는, 막지 않을게요...",
		"alert_en": "Luca's diagnostic trace: Whichever route you choose... the system will record it. I won't stop you...",
	},
	"IRIS": {
		"bond_ko": "이리스의 진단 잔상: 우후후... 어느 쪽이 덜 무서운지는 정해 드릴 수 없네요. 기다리고 있을게요.",
		"bond_en": "Iris's diagnostic trace: Oh-ho-ho... I cannot decide which route is less frightening for you. I will wait.",
		"alert_ko": "이리스의 진단 잔상: 어느 쪽으로 가셔도 결과는 같을까요? 우후후... 선택은 돌려드릴게요.",
		"alert_en": "Iris's diagnostic trace: Will the outcome be the same whichever route you take? Oh-ho-ho... I leave the choice with you.",
	},
	"MARA2": {
		"bond_ko": "마라 2의 진단 잔상: 두 길, 같은 목적지! 그래도 네가 고른 쪽은 내가 제대로 기억해 둘게!",
		"bond_en": "Mara 2's diagnostic trace: Two routes, one destination! I'll still remember which one you chose!",
		"alert_ko": "마라 2의 진단 잔상: 어느 쪽이 함정인지는 안 알려줄 거야! ...둘 다 막지는 않았지만.",
		"alert_en": "Mara 2's diagnostic trace: I won't tell you which one's a trap! ...Not that I blocked either of them.",
	},
}

const SLEEP_TRANSITION_KO := {
	"bedroom": [
		"이불 끝을 쥔 손가락부터 감각이 느려진다.\n\nSUBJECT SIGNAL ........ PERSIST",
		"캐노피 그림자가 눈꺼풀보다 먼저 닫힌다. 침대 아래 곡면이 아주 낮게 울린다.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED",
		"익숙한 침실의 냄새가 사라지고 소독약 냄새만 남는다. 돌아갈 기준점은 응답하지 않는다.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED\nCAMOUFLAGE MASK ....... NO BASELINE",
	],
	"capsule": [
		"투사된 이불 무늬 아래로 투명 덮개가 천천히 닫힌다.\n\nSUBJECT SIGNAL ........ PERSIST",
		"금속 곡면이 등과 손목의 위치를 읽는다. 바로 아래에서 자신의 것과 비슷한 맥박이 늦게 답한다.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED",
		"직물 무늬가 꺼지고 소독약 냄새만 남는다. 돌아갈 기준점은 응답하지 않는다.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED\nCAMOUFLAGE MASK ....... NO BASELINE",
	],
}

const SLEEP_TRANSITION_EN := {
	"bedroom": [
		"Sensation slows from the fingers gripping the blanket's edge.\n\nSUBJECT SIGNAL ........ PERSIST",
		"The canopy shadow closes before your eyelids do. A low vibration answers from the curve beneath the bed.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED",
		"The familiar scent of the bedroom disappears, leaving only antiseptic. The restoration baseline does not answer.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED\nCAMOUFLAGE MASK ....... NO BASELINE",
	],
	"capsule": [
		"The transparent cover closes slowly beneath the projected blanket pattern.\n\nSUBJECT SIGNAL ........ PERSIST",
		"The metal curve reads the position of your back and wrist. A pulse much like your own answers late from directly below.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED",
		"The fabric pattern goes dark, leaving only antiseptic. The restoration baseline does not answer.\n\nSUBJECT SIGNAL ........ PERSIST\nRESIDENT MEMORY ....... PERSIST\nWORLD GEOMETRY ........ DEGRADED\nCAMOUFLAGE MASK ....... NO BASELINE",
	],
}

const EN := {
	"달라진 통로를 조사하거나 쉴 곳을 선택한다": "Explore the changed passage or choose somewhere to rest",
	"복구 절차는 수면 중 실행됩니다 · 더 조사하거나 쉴 곳을 선택한다": "Recovery runs during sleep · Keep exploring or choose a place to rest",
	"드러난 서비스 통로": "Exposed service passage",
	"벗겨진 벽지": "Peeled wallpaper",
	"서비스 척추 표지": "Service spine sign",
	"사용인 진단 잔상": "Servant diagnostic traces",
	"비상 캡슐의 표면": "Emergency capsule surface",
	"수첩의 낙서와 배선을 겹쳐 본다": "Compare the notebook sketch with the wiring",
	"침실로 돌아간다": "Return to the bedroom",
	"가까운 비상 캡슐에서 쉰다": "Rest in the nearby emergency capsule",
	"주인공의 침실 · 파열 이후": "Protagonist's bedroom · After the fracture",
	"통로를 조금 더 본다": "Explore the passage a little longer",
	"침대에서 쉰다": "Rest in bed",
	"벽지 뒤에서 드러난 서비스 통로에 두 휴식 경로가 표시되어 있다.": "Two routes to a resting place are marked in the service passage exposed beneath the wallpaper.",
	"드러난 서비스 통로로": "Enter the exposed service passage",
	"휴식 경로: 침실 또는 비상 캡슐 · 조사는 계속할 수 있다": "Rest routes: bedroom or emergency capsule · You may keep exploring",
	"안내 기록 저장 재시도": "Retry saving the guidance record",
	"안내 기록을 저장하지 못했다. 다시 시도하거나 조사를 계속할 수 있다.": "The guidance record could not be saved. Retry or keep exploring.",
	"[취침 종: 깨진 간격으로 열한 번] 아직 통로를 더 살펴볼 수 있다.": "[Bedtime bell: eleven strokes at broken intervals] You can still explore the passage.",
	"에드가 방송: 휴식 경로는 열려 있습니다. 이동 여부는 귀하가 결정하시면 됩니다.": "Edgar's broadcast: The routes to rest remain open. The decision to move is yours.",
	"침실 또는 가까운 비상 캡슐에서 쉴 수 있다. 지금 잠들 필요는 없다.": "You can rest in the bedroom or the nearby emergency capsule. You do not have to sleep now.",
	"잠깐 눈을 감는다": "Close your eyes for a while",
	"조금 더 본다": "Look around a little longer",
	"잠든다": "Go to sleep",
	"익숙한 이불 아래로 캡슐의 곡면이 만져진다. 이불 끝을 한 번 더 끌어당긴다.": "You feel the curve of a capsule beneath the familiar blanket. You pull its edge closer once more.",
	"금속 표면에 이불의 질감이 투사된다. 손끝이 매끄럽게 미끄러진다. 침대도 처음부터 이런 장치였을까.": "A blanket's texture is projected onto metal. Your fingertips slide smoothly across it. Was the bed a device like this all along?",
	"복구 절차를 실행하면 현재 파열 상태를 기준으로 수면 전환이 시작됩니다.\n결과는 확인되지 않았습니다.": "Starting recovery will begin the sleep transition from the current fractured state.\nThe outcome has not been confirmed.",
	"익숙한 복도의 외피 아래로 휴식 경로가 이어진다.": "Beneath the shell of the familiar corridor, a route leads toward rest.",
	"벗겨진 벽지 뒤 금속 격자는 기억하는 방보다 좁다. 손끝에는 종이와 금속의 경계가 동시에 닿는다.": "The metal grid behind the peeled wallpaper is narrower than the room you remember. Your fingertips touch paper and metal at the same boundary.",
	"서비스 척추 표지의 다섯 기능실 방향과 SUBJECT 방향이 갈라져 있다. 아직 기능실로 들어갈 수는 없다.": "The service spine sign separates the five function rooms from the SUBJECT route. The function rooms are not accessible yet.",
	"몸은 없는데 문양만 일정한 간격으로 지나간다. 잠금선, 닦임 자국, 이중 맥박, 꽃잎, 겹친 액자. 알아보는 것은 색만이 아니다.": "No bodies are here, but patterns pass at regular intervals: locking lines, wipe marks, paired pulses, petals, overlapping frames. Colour is not the only thing you recognise.",
	"비상 캡슐 표면에 침실 침대와 같은 직물 무늬가 투사된다. 가까이서는 천의 결 아래 매끄러운 곡면이 느껴진다.": "The same fabric pattern as your bed is projected onto the emergency capsule. Up close, you feel a smooth curve beneath the weave.",
	"수첩의 낙서 저택을 펼쳐 배선과 겹쳐 본다. 복도 끝에서 꺾인 선이 같다. 내가 그린 선을 누군가 이곳의 길로 만들었다. 종이를 접어도 벽의 선은 사라지지 않는다.": "You open the notebook's mansion sketch and compare it with the wiring. The line turns at the same corridor end. Someone made your drawn lines into paths here. Folding the paper does not erase the lines on the wall.",
	"조금 눈을 감는다. 이번에는 무엇이 돌아올지 알 수 없다.": "You close your eyes for a while. This time, you do not know what will return.",
	"표시된 휴식 경로를 따른다.": "Follow a marked route to rest.",
	"드러난 서비스 통로를 지나 침실로 간다.": "Go through the exposed service passage to reach the bedroom.",
	"통로에서 조사할 대상을 확인한다.": "Choose something to examine in the passage.",
	"현재 위치의 휴식 장치를 확인한다.": "Check the rest device at your current location.",
	"이전 일과와 장치 조작은 끝났다. 드러난 통로와 휴식 경로를 확인한다.": "The old routines and device procedures are over. Examine the exposed passage and rest routes.",
	"다음 안내 시점을 확인한다.": "Check the next guidance checkpoint.",
	"휴식할 침실이나 확인한 비상 캡슐에서 잠든다.": "Sleep in the bedroom or in the emergency capsule you have confirmed."
	,"수면 전환 · 침실": "Sleep transition · Bedroom"
	,"수면 전환 · 비상 캡슐": "Sleep transition · Emergency capsule"
	,"눈을 감은 뒤의 상태를 확인한다": "Observe what remains after closing your eyes"
	,"수면 전환 저장 재시도": "Retry saving the sleep transition"
	,"수면 전환을 저장하지 못했습니다. 현재 파열 상태와 선택한 경로는 유지됩니다.": "The sleep transition could not be saved. The current fractured state and selected route are preserved."
}

static func text(source: String, locale: String) -> String:
	return EN.get(source, source) if locale.begins_with("en") else source


static func guidance_300(reaction_state: Dictionary, locale: String) -> String:
	var owner := String(reaction_state.get("owner", ""))
	if not GUIDANCE_300.has(owner):
		return text("에드가 방송: 휴식 경로는 열려 있습니다. 이동 여부는 귀하가 결정하시면 됩니다.", locale)
	var mode := String(reaction_state.get("mode", "bond"))
	if mode != "alert":
		mode = "bond"
	return String(GUIDANCE_300[owner][mode + ("_en" if locale.begins_with("en") else "_ko")])


static func sleep_transition(route: String, seconds: float, locale: String) -> Dictionary:
	var normalized := "capsule" if route == "capsule" or route == "emergency_capsule" else "bedroom"
	var beat := 0 if seconds < 2.0 else (1 if seconds < 4.0 else 2)
	var source: Dictionary = SLEEP_TRANSITION_EN if locale.begins_with("en") else SLEEP_TRANSITION_KO
	return {
		"title": text("수면 전환 · 비상 캡슐" if normalized == "capsule" else "수면 전환 · 침실", locale),
		"body": String(source[normalized][beat]),
	}
