extends RefCounted

const HINTS := {
	"D0_A": [
		["C5 투명지는 거울에서 얻은 자료다. 집의 도면에 곧바로 놓기 전에 글자의 방향과 세 기준점을 비교하자.", "The C5 transparency came from a mirror. Before placing it on the house plan, compare the lettering and the three landmarks."],
		["종이 없어도 울리는 대시계를 기준으로 삼자. 그 점 하나만 맞추는 것으로 끝내지 말고 온실과 침실도 함께 확인한다.", "Use the great clock that rings without a bell as your reference. Do not stop at one matching point: check the greenhouse and bedroom too."],
		["이번 투명지는 좌우를 바꿔 비교해야 한다. 검은 거울에 파형을 놓았던 변환을 그대로 반복하는 퍼즐이 아니다.", "Compare this transparency after mirroring it horizontally. This is not a repetition of the transformation used to place the waveform on the black mirror."],
		["좌우 반전 뒤 반시계 방향으로 90도 돌려 보자. 화면이 시계 방향 90도씩만 움직인다면 세 번 회전한 상태다.", "After mirroring horizontally, rotate 90 degrees counterclockwise. If the control advances clockwise by 90 degrees, that is three turns."],
		["좌우 반전과 반시계 90도 회전 상태에서 대시계 기준점을 고정한다. 온실·침실까지 맞는지 검증하면 직선 II, 분기 I, 환형 III의 깊이를 읽을 수 있다.", "With horizontal mirroring and a 90-degree counterclockwise rotation, anchor the great clock. Verify the greenhouse and bedroom too to read the depths: straight II, branch I, ring III."],
	],
	"D1": [
		["도면의 화살표는 축을 미는 순서이고 로마 숫자는 깊이다. 축의 종류, 깊이, 실행을 서로 다른 선택으로 구분하자.", "The arrows on the plan give the order of pushing; the Roman numerals give depths. Treat axis identity, depth, and execution as separate choices."],
		["직선에서 시작해 분기를 지나 고리로 닫히는 흐름을 따라가자. 처음부터 모든 순서를 시험할 필요 없이 검증한 도면을 다시 읽을 수 있다.", "Follow the flow from the straight line through the branch to the closing ring. Re-read the verified plan instead of trying every possible order."],
		["각 축은 밀기 전까지만 깊이를 바꿀 수 있다. 이미 밀린 축을 되돌리려 하지 말고, 수첩의 깊이와 아직 남은 축의 홈을 비교하자.", "An axis's depth can be changed only before it is pushed. Do not try to undo a pushed axis; compare the recorded depths with the remaining axes' notches."],
		["첫 축은 직선이고 깊이는 II, 즉 2다. 그다음 분기는 I, 환형은 III와 대응한다. 깊이 설정만으로 압력이 전달되지는 않으며 밀기는 별도로 확인해야 한다.", "The first axis is straight at depth II, or 2. Branch corresponds to I and ring to III. Selecting depth does not transmit pressure; pushing still requires separate confirmation."],
		["직선 2 → 분기 1 → 환형 3 순서로 각각 밀고 중앙 손잡이를 시계 방향 반 바퀴 돌린다. 이미 핀이 내려갔다면 잠든 뒤 재준비해야 한다. 검증된 설정을 적용해도 실제 밀기는 직접 확인한다.", "Push straight 2, then branch 1, then ring 3; turn the central handle half a turn clockwise. If the pin has already dropped, sleep and prepare again. Applying verified settings still leaves each push for you to confirm."],
	],
	"D4": [
		["손잡이 하나가 링 하나만 움직인다고 가정하지 말자. 움직이는 두 링과 움직이지 않는 링을 함께 관찰한다.", "Do not assume one handle moves only one ring. Observe both the rings that move and the one that stays still."],
		["외곽 손잡이는 외곽·중간을, 중간 손잡이는 중간·안쪽을 움직인다. 안쪽 손잡이는 안쪽 링만 움직인다. 영향을 덜 되돌리려면 바깥부터 맞추는 편이 낫다.", "The outer handle moves outer and middle; the middle handle moves middle and inner. The inner handle moves only the inner ring. Work from outside inward to avoid disturbing completed work."],
		["외곽 XIII 홈, 중간 분기 접점, 안쪽 가장 낮은 심장 노드가 목표다. 네 위치가 순환하므로 이미 지나친 문양도 다시 돌아온다. 동력 연결 전의 초기화로 연동을 재확인할 수 있다.", "The targets are the outer XIII notch, middle branch junction, and inner lowest heart node. Four positions cycle, so passed symbols return. Before connecting power, resetting lets you recheck the coupling."],
		["링을 맞춘 뒤 정상 레버를 XII까지 감으면 STABLE이 표시된다. 이 표시가 모든 동작의 끝인지, 시계망에서 정상 완료 뒤 남았던 한 번을 떠올려 보자.", "After aligning the rings, wind the normal lever to XII to reach STABLE. Consider whether that display ends every operation: recall the extra signal after normal completion in the clock network."],
		["초기 위치로 되돌린 상태라면 외곽 A 한 번, 중간 B 한 번, 안쪽 C 두 번으로 정렬된다. 현재 위치에 무조건 더하는 횟수가 아니다. 링을 고정하고 XII 정상 기동을 확인한 뒤 숨은 보조 레버를 조사해 한 번 더 실행한다.", "From the reset starting position, turn outer A once, middle B once, and inner C twice. These are not extra turns to add blindly to your current position. Fix the rings, complete normal XII startup, then inspect the hidden auxiliary lever and execute it once."],
	],
}

static func text(stage: String, level: int, locale: String) -> String:
	var key := "D1" if stage == "DF" else stage
	if not HINTS.has(key) or level < 0 or level >= 5:
		return ""
	return HINTS[key][level][1 if locale.begins_with("en") else 0]
