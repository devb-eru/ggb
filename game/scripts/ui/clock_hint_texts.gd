extends RefCounted

const HINTS := {
	"B3_A": [
		["네 탁본의 나사 구멍과 가장자리 선을 비교해 보자. 종이의 방향이 시계의 위치와 꼭 같지는 않다.", "Compare the screw holes and edge lines on all four rubbings. A sheet's orientation need not match its clock's position."],
		["침실 탁본에서는 모든 선이 가장자리에 닿기 전에 끝난다. 다른 방으로 신호를 넘기는 조각과 나란히 놓고 차이를 보자.", "Every line on the bedroom rubbing ends before reaching an edge. Compare it with a piece that can carry a signal into another room."],
		["외부 서고 탁본의 뒷면에 흑연이 번져 있다. 회전만으로 선이 이어지지 않는다면 이 조각은 뒤집어 비교해 보자.", "Graphite has smudged onto the back of the outer-library rubbing. If rotation cannot join its lines, compare it after flipping it over."],
		["연결 하나를 기준으로 삼자. 대응접실에서 나온 선은 외부 서고로 이어진다. 이 두 조각의 경계를 먼저 맞추고 나머지를 살펴보자.", "Use one connection as your reference: the parlor leads into the outer library. Match that boundary first, then examine the remaining pieces."],
		["침실은 연결에서 제외하고, 외부 서고는 뒤집는다. 대응접실→외부 서고→서쪽 대시계의 경로를 만들자. 각 조각의 방향은 약한 진동으로 확인할 수 있다.", "Exclude the bedroom and flip the outer-library piece. Build the path parlor → outer library → western great clock. Use the weak vibration to check the pieces' orientations."],
	],
	"B3_B": [
		["각 시계가 신호를 시작하는지, 전달하는지, 소리로 내보내는지 비교해 보자. 연결이 없는 시계에는 다른 역할이 필요하다.", "Compare which clock starts the signal, which relays it, and which sounds it out. The disconnected clock needs a different role."],
		["탁본에서 확인한 신호 방향과 시계의 기능을 함께 보자. 일지의 마지막 문장과 대시계의 XII 뒤 빈 홈도 서로 닮아 있다.", "Compare the signal direction established by the rubbings with each clock's function. The journal's final sentence also echoes the empty notch after XII on the great clock."],
		["역할과 전달 시점은 서로 다른 설정이다. 약한 시험은 역할 연결만 확인한다. 위상은 '모두 끝난 뒤에도 한 칸 남은 소리'를 기준으로 생각하자.", "Roles and timing are separate settings. The weak test checks role connections only. For phase, consider the sound that remains one step after everything seems finished."],
		["대응접실을 기준 시계로 삼는다. 신호가 시작되는 이 위치를 출발점으로 놓고, 약한 시험으로 다음 연결을 확인하자. 실제 작동은 아직 필요하지 않다.", "The parlor is the reference clock. Start from that signal source and use the weak test to check the next connection. You do not need to activate the network yet."],
		["기준은 대응접실, 중계는 외부 서고, 출력은 서쪽 대시계, 제외는 침실이다. 위상의 0과 +1을 비교하자. 필요한 것은 정상 종과 동시가 아니라 정상 완료 뒤 한 칸 늦은 전달이다. 실제 오작동은 오늘의 핀을 잠근다.", "Reference: parlor. Relay: outer library. Output: western great clock. Excluded: bedroom. Compare phase 0 with +1: the required signal comes one step after normal completion, not at the same time. A failed real activation locks today's pin."],
	],
}

static func text(stage: String, level: int, locale: String) -> String:
	var key := "B3_B" if stage == "BF" else stage
	if not HINTS.has(key) or level < 0 or level >= 5:
		return ""
	return HINTS[key][level][1 if locale.begins_with("en") else 0]
