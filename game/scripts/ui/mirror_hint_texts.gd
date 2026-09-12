extends RefCounted

const HINTS := {
	"C3": [
		["청소 기록과 약품 라벨을 총량, 재료 사이 비율, 투입 순서로 나누어 보자. 이 셋은 별개의 조건이다. 잘못 만든 용액은 폐기하고 같은 날 다시 만들 수 있다.", "Separate the cleaning record and chemical labels into total quantity, ingredient ratios, and pouring order. These are separate constraints. An incorrect mixture can be discarded and remade on the same day."],
		["원액 A는 안정제 S의 두 배다. 원액을 먼저 정하기보다 안정제 한 단위에 원액이 얼마나 따라오는지 묶어 보자.", "Active solution A is twice stabilizer S. Instead of guessing A first, group each unit of stabilizer with the active solution it requires."],
		["물 W는 안정제와 원액을 합친 양보다 두 단위 많다. 세 재료의 합은 여덟이다. 안정제 한 단위를 늘렸을 때 다른 두 재료도 얼마나 늘어나는지 비교하자.", "Water W is two units greater than stabilizer and active solution combined. All three total eight. Compare how increasing stabilizer by one unit also increases the other ingredients."],
		["안정제 S를 한 단위로 놓고 검산하자. 원액은 그 두 배이고, 물은 둘의 합보다 두 단위 많아야 한다. 병의 여덟 눈금과 맞는지 확인한다.", "Use one unit of stabilizer S as a reference. Active solution is twice that, and water is two more than their sum. Check the result against the bottle's eight-unit mark."],
		["물을 다섯 단위 먼저 넣고 안정제 한 단위를 확산시킨 뒤 원액 두 단위를 넣는다. 천천히 한 번 혼합하고 시험지로 확인하자. 순서가 잘못된 용액은 양만 맞춰도 거울용이 되지 않는다.", "Pour five units of water first, disperse one unit of stabilizer, then add two units of active solution. Mix slowly once and test it. Correct quantities cannot rescue a mixture made in the wrong order."],
	],
	"C4": [
		["B4 파형과 J2 문장을 함께 보자. 긴 진입, 두 번의 짧은 반사, 닫히는 잔향이 거울의 직선·분기·고리와 어떻게 이어지는지 살펴보자.", "Compare the B4 waveform with the J2 passage. Consider how the long entry, two short reflections, and closing resonance relate to the mirror's straight line, fork, and loop."],
		["중첩과 닦기 순서를 따로 확인하자. 열세 번째 큰 파동은 거울 아래쪽 진동점과 비교한다. 겹치는 시작점이 어긋나면 올바른 경로도 소용없다.", "Check the overlay separately from the tracing order. Compare the thirteenth large wave with the vibration point below the mirror. A correct route cannot compensate for a misplaced starting point."],
		["이 자료는 서재 탁본과 같은 변환을 요구하지 않는다. 앞뒤를 바꾸지 않은 채 회전해 비교하자. 거울 작업 전에는 마른 천 시험으로 확인할 수 있다.", "This record does not use the same transformation as the library rubbing. Compare rotations without turning it over. Before applying solution, check with a dry cloth."],
		["좌우 반전 없이 시계 방향 90도로 돌리고 열세 번째 파동을 하단 진동점에 맞춘다. 이제 분기의 양쪽을 빠뜨리지 않는 경로인지 확인하자.", "Rotate 90 degrees clockwise without mirroring, then align the thirteenth wave with the lower vibration point. Check that your route includes both sides of the fork."],
		["직선 진입, 분기의 짧은 쪽, 긴 쪽, 고리의 시계 방향 순서로 계획한다. 중첩·기준점을 다시 확인하고 마른 시험을 거친다. 이미 코팅이 굳었다면 힌트로 복구할 수 없으며 잠든 뒤 다시 준비해야 한다.", "Plan straight entry, short branch, long branch, then the loop clockwise. Recheck the overlay and anchor and use the dry test. If the coating has already hardened, hints cannot repair it; sleep and prepare again."],
	],
}

static func text(stage: String, level: int, locale: String) -> String:
	var key := "C4" if stage == "CF" else stage
	if not HINTS.has(key) or level < 0 or level >= 5:
		return ""
	return HINTS[key][level][1 if locale.begins_with("en") else 0]
