extends RefCounted

const OBJECTIVES := {
	"D_SLEEP": ["J3를 기억한 채 잠들어 다음 아침을 맞는다", "Sleep with J3 in mind and reach the next morning"],
	"D0": ["기록 내실의 세 눌림점에서 평면도를 꺼낸다", "Retrieve the floorplan from the three impressions in the inner archive"],
	"D0_A": ["C5 투명지와 저택 도면의 방향·기준점을 검증한다", "Verify the orientation and landmarks of the C5 transparency and mansion plan"],
	"D1": ["세 축의 순서와 깊이를 도면대로 적용한다", "Apply the three-axis order and depths shown on the plan"],
	"DF": ["압력핀 잠김 · 같은 침실에서 잠든다", "Pressure pins locked · Sleep in the same bedroom"],
	"D2": ["지하창고의 반복 구조를 조사한다", "Investigate the repeating structure of the basement storage"],
	"D4": ["태엽 심장의 연동 링과 정상 기동을 확인한다", "Inspect the clockwork heart's coupled rings and normal startup"],
	"D5": ["위장 필터 너머 드러난 공간을 확인한다", "Examine the space revealed beyond the camouflage filter"],
	"DEMO_END": ["데모 공개 구간 종료", "End of the public demo"],
	"default": ["수첩을 확인한다", "Check the notebook"],
}

const LOCATIONS := {
	"M1_BASEMENT_ENTRY": ["서쪽 지하 계단문", "West Basement Stair Door"],
	"B1_BASEMENT_STAIR": ["지하 계단", "Basement Stairs"],
	"B1_AXIS_CHAMBER": ["세 축 장치실", "Three-Axis Mechanism Room"],
	"B1_STORAGE": ["지하창고", "Basement Storage"],
	"B1_CLOCKWORK_HEART": ["태엽 심장실", "Clockwork Heart Room"],
}

const UI := {
	"basement_door": ["서쪽 지하 계단문", "West Basement Stair Door"],
	"descend": ["지하 계단으로", "To the Basement Stairs"],
	"back_clock": ["대시계로", "To the Great Clock"],
	"axis_room": ["세 축 장치실", "To the Three-Axis Room"],
	"back_entry": ["계단문으로", "To the Stair Door"],
	"back_stair": ["지하 계단으로", "To the Basement Stairs"],
	"back_axes": ["세 축 장치실로", "To the Three-Axis Room"],
	"back_storage": ["지하창고로", "To Basement Storage"],
	"heart_door": ["반복 구조의 중심", "Center of the Repeating Structure"],
	"fastpath": ["검증한 절차로 지하창고 다시 열기", "Reopen the basement storage with the verified procedure"],
	"shortcut": ["도면과 검증한 깊이로 준비 축약", "Shorten preparation with the plan and verified depths"],
	"drawer_board": ["책상 이중 바닥의 세 눌림점\nC5 투명지와 J3의 침실·온실·대시계 기준점을 비교한다.", "Three impressions in the desk's false bottom\nCompare the bedroom, greenhouse, and great-clock landmarks from the C5 transparency and J3."],
	"point_bedroom": ["침실 점", "Bedroom Point"],
	"point_greenhouse": ["온실 점", "Greenhouse Point"],
	"point_great_clock": ["대시계 점", "Great-Clock Point"],
	"rotate_90": ["90° 회전", "Rotate 90°"],
	"flip_horizontal": ["좌우 반전", "Mirror Horizontally"],
	"anchor_bedroom": ["침실 고정", "Anchor Bedroom"],
	"anchor_greenhouse": ["온실 고정", "Anchor Greenhouse"],
	"anchor_great_clock": ["대시계 고정", "Anchor Great Clock"],
	"verify_overlay": ["방향과 지하 좌표 검증", "Verify Orientation and Underground Coordinates"],
	"axis_locked": ["압력핀 하강 · 당일 입력 잠김\n수첩의 검증 결과는 남는다. 같은 침실에서 잠든다.", "Pressure pins lowered · Inputs locked for today\nThe verified notebook record remains. Sleep in the same bedroom."],
	"storage_enter": ["열린 지하창고로", "Enter the Open Basement Storage"],
	"axis_push": ["축을 민다", "Push Axis"],
	"central_cw": ["중앙 시계 방향 반 바퀴", "Central Handle · Half Turn Clockwise"],
	"central_ccw": ["중앙 반시계 방향", "Central Handle · Counterclockwise"],
	"axis_modal_title": ["압력핀 확인", "Confirm Pressure Pin"],
	"axis_modal_body": ["축을 밀면 이 루프에서는 되돌릴 수 없다. 도면의 순서와 깊이를 먼저 확인한다.", "Once pushed, an axis cannot be reversed during this loop. Check the plan's order and depth first."],
	"review_plan": ["수첩 도면을 본다", "Review the Notebook Plan"],
	"review_depth": ["깊이를 다시 확인한다", "Review the Depth"],
	"central_modal_title": ["중앙 손잡이", "Central Handle"],
	"central_modal_body": ["역방향에는 방지턱이 있다. 경고 뒤 강행하면 오늘 장치가 잠긴다.", "A stop blocks the reverse direction. Forcing it after the warning will lock the mechanism for today."],
	"review_direction": ["다시 확인한다", "Review the Direction"],
	"move_selected": ["선택한 방향으로 움직인다", "Move in the Selected Direction"],
	"heart_outer_middle_inner": ["외곽 · 중간 · 안쪽", "Outer · Middle · Inner"],
	"normal_lever": ["정상 레버", "Normal Lever"],
	"handle_a": ["손잡이 A", "Handle A"],
	"handle_b": ["손잡이 B", "Handle B"],
	"handle_c": ["손잡이 C", "Handle C"],
	"reset_rings": ["링 초기 위치로", "Reset Ring Positions"],
	"fix_rings": ["링 고정", "Fix Rings"],
	"unfix_rings": ["기동 전 고정 해제", "Release Before Startup"],
	"wind_lever": ["정상 레버 한 칸", "Wind Normal Lever One Step"],
	"stabilize": ["정상 안정화 실행", "Run Normal Stabilization"],
	"inspect_panel": ["패널 뒤 조사", "Inspect Behind Panel"],
	"auxiliary_check": ["보조 레버 확인", "Inspect Auxiliary Lever"],
	"auxiliary_modal_title": ["정상 절차 밖의 입력", "Input Outside Normal Procedure"],
	"auxiliary_modal_body": ["보조 레버를 실행하면 현재 위장 상태를 유지할 수 없다.", "Pulling the auxiliary lever will make the current camouflage state impossible to maintain."],
	"do_not_pull": ["아직 당기지 않는다", "Do Not Pull It Yet"],
	"review_record": ["기록을 다시 확인한다", "Review the Record"],
	"pull_auxiliary": ["보조 레버를 당긴다", "Pull the Auxiliary Lever"],
	"d5_demo_objective": ["위장 필터 해제", "Camouflage Filter Off"],
	"d5_save_retry": ["완료 기록 저장 재시도", "Retry Saving Completion Record"],
	"d5_idle": ["벽의 문양 사이로 배선이 드러난다.\n방금까지 하나였던 윤곽과 서명이 조금씩 어긋난다.", "Wiring appears between the patterns on the walls.\nOutlines and signatures that were one a moment ago begin to drift apart."],
	"demo_end": ["데모는 여기까지입니다.\n기록과 선택은 저장되어 있습니다. 본편의 저장 가져오기는 별도 승인을 거쳐 처리됩니다.", "This is the end of the demo.\nYour records and choices have been saved. Importing this save into the full game will require separate confirmation."],
	"return_title": ["타이틀로 돌아간다", "Return to Title"],
	"d5_demo_running": ["위장 필터 해제 연출이 진행됩니다. 메뉴를 열면 일시정지합니다.", "The camouflage-filter sequence is playing. Opening the menu will pause it."],
}

const STORAGE := {
	"barrel": ["빈 와인통", "Empty Wine Barrel"],
	"cable": ["케이블 릴", "Cable Reel"],
	"filter": ["위장 필터 부품", "Camouflage Filter Component"],
	"drawing": ["낙서 조각", "Drawing Fragment"],
}

const AXES := {
	"line": ["직선축", "Straight Axis"],
	"branch": ["분기축", "Branch Axis"],
	"ring": ["환형축", "Ring Axis"],
}

const ANCHORS := {
	"bedroom": ["침실", "Bedroom"],
	"greenhouse": ["온실", "Greenhouse"],
	"great_clock": ["대시계", "Great Clock"],
	"": ["미선택", "Not Selected"],
}

const GLYPHS := [
	[["XII 표시", "XII Mark"], ["XIII 홈", "XIII Notch"], ["작은 홈", "Small Notch"], ["빈 테두리", "Empty Border"]],
	[["닫힌 갈래", "Closed Branch"], ["직선 접점", "Straight Junction"], ["C5 분기 접점", "C5 Branch Junction"], ["환형 접점", "Ring Junction"]],
	[["빈 중심", "Empty Center"], ["창 문양", "Window Glyph"], ["문 문양", "Door Glyph"], ["최하단 심장", "Lowest Heart"]],
]

const DEMO_BEATS := [
	["열세 번째 울림이 멎는다.\n벽의 꽃무늬는 한 박자 늦게 떨림을 멈춘다.", "The thirteenth resonance stops.\nThe floral pattern on the wall stops trembling one beat later."],
	["벽지 아래로 가느다란 배선이 드러난다.\n찢어진 것은 벽이 아니라, 벽처럼 보이던 겉면이다.", "Fine wiring appears beneath the wallpaper.\nIt is not the wall that has torn, but the surface that looked like one."],
	["금속 이음새를 따라 차가운 빛이 이어진다.\n익숙한 복도의 윤곽은 아직 그 위에 남아 있다.", "Cold light runs along metal seams.\nThe outline of the familiar corridor still remains over them."],
	["멀리 사용인의 윤곽이 두 겹으로 어긋난다.\n누군가 말을 꺼내려다 멈춘다.", "In the distance, a servant's outline splits into two misaligned layers.\nSomeone starts to speak, then stops."],
	["저택 아래에서 규칙적인 진동이 돌아온다.\n차가 우러나던 동안 들었던 간격과 닮아 있다.", "A steady vibration returns beneath the mansion.\nIts interval resembles the pulse heard while the tea was steeping."],
	["주인공은 수첩을 쥔다.\n벽은 달라졌지만, 자신이 적은 글자는 남아 있다.", "You grip the notebook.\nThe walls have changed, but the words you wrote remain."],
]

const FEEDBACK_EN := {
	"기록 내실에서 평면도와 지하 좌표를 먼저 검증한다.": "Verify the floorplan and underground coordinates in the inner archive first.",
	"세 축 장치 뒤의 지하창고 문이 잠겨 있다.": "The basement storage door behind the three-axis mechanism is locked.",
	"반복되는 선반 사이에서 같은 부품의 방향을 비교한다.": "Compare the orientation of matching components among the repeating shelves.",
	"복원한 세 번째 일지를 기억한 채 잠들고 다음 아침에 조사한다.": "Sleep with the restored third journal entry in mind, then investigate the next morning.",
	"이전 지하 장치 절차는 끝났다.": "The earlier basement-mechanism procedure is over.",
	"기록 내실 책상의 세 눌림점을 확인한다.": "Inspect the three impressions on the inner archive desk.",
	"거울 회로 투명지를 먼저 수첩에 기록한다.": "Record the mirror-circuit transparency in the notebook first.",
	"이중 바닥에서 평면도를 꺼내 C5 투명지와 일지 좌표를 함께 펼쳤다. 자료는 모였지만 방향은 아직 검증하지 않았다.": "I retrieve the floorplan from the false bottom and lay it beside the C5 transparency and journal coordinates. The evidence is assembled, but its orientation is not yet verified.",
	"서재 작업대에 세 자료를 준비한다.": "Prepare all three records on the archive worktable.",
	"세 기준점 중 하나를 고정한다.": "Anchor one of the three landmarks.",
	"지하의 세 축 장치에서 도면을 적용한다.": "Apply the plan at the three-axis mechanism below.",
	"조작 대상과 비가역 확인이 필요하다.": "Select the mechanism and acknowledge the irreversible action.",
	"당일 입력 잠김. 잠든 뒤 도면과 검증한 깊이는 남는다.": "Inputs locked for today. The plan and verified depths will remain after sleep.",
	"세 축과 중앙 반 바퀴로 지하창고 접근 경로를 검증했다.": "I verified the route into the basement storage with the three axes and a half turn of the central handle.",
	"수면 뒤 닫힌 지하창고를 다시 준비할 때 사용하는 동선이다. 이미 열린 문이나 파열 이후에는 이전 절차를 반복하지 않는다.": "This route prepares the closed basement storage after sleep. It does not repeat the old procedure once the door is open or after the fracture.",
	"리셋 뒤 같은 침실에서 준비 동선을 시작한다.": "Begin the preparation route from the same bedroom after the reset.",
	"실패 뒤 확인한 축 기록이 필요하다.": "I need the axis record confirmed after the failed attempt.",
	"지하창고를 한 번 직접 열어야 한다.": "I need to open the basement storage manually at least once.",
	"일과를 마치고 평면도를 다시 꺼냈다. 검증한 깊이만 미리 맞췄다. 축을 미는 것은 직접 결정한다.": "After finishing the routine, I lay out the floorplan again. The verified depths are preset, but I must decide when to push each axis.",
	"기록한 순서로 물리 장치를 다시 작동했다. 지하창고 문이 열린다.": "I operate the physical mechanism again in the recorded order. The basement storage door opens.",
	"지하창고의 선반을 조사한다.": "Investigate the shelves in the basement storage.",
	"빈 와인통 안쪽에 같은 나사 간격이 반복된다.": "The same screw spacing repeats inside the empty wine barrel.",
	"케이블 릴의 선이 선반 뒤로 모인다. 먼지 아래 방향이 하나로 이어진다.": "Lines from the cable reel converge behind the shelves. Beneath the dust, their directions join into one.",
	"장식 테두리와 닮은 부품. 안쪽에는 위장 필터라는 표식이 있다.": "A component resembling a decorative border. Its inner face is marked CAMOUFLAGE FILTER.",
	"찢어진 낙서 조각의 중심과 선반의 빈자리가 겹친다.": "The center of the torn drawing aligns with the empty space among the shelves.",
	"반복 구조의 중심에 태엽 심장실 문이 드러난다.": "A door to the clockwork heart room appears at the center of the repeating structure.",
	"태엽 심장실에서 조작한다.": "Operate the mechanism in the clockwork heart room.",
	"XII 뒤 보조 입력을 실행했다. 위장 필터 해제. 정상 안정화만으로는 닿지 않는 공간이었다.": "I executed the auxiliary input after XII. CAMOUFLAGE FILTER OFF. Normal stabilization alone could never reach this space.",
	"위장 필터를 해제한 뒤 확인한다.": "Inspect the space after disabling the camouflage filter.",
	"시계는 잠깐 정상적으로 움직인다. 벽지의 무늬가 벗겨지며 배선과 진단 문자가 드러난다. 사용인의 윤곽에서 서로 다른 서명이 조금씩 어긋난다.": "The clock runs normally for a moment. The wallpaper pattern peels away, revealing wiring and diagnostic text. Distinct signatures begin to slip out of alignment with the servants' outlines.",
	"정의되지 않은 지하 조사다.": "That basement action is not defined.",
	"세 기준점과 지하 좌표가 함께 맞는다. 직선 II → 분기 I → 환형 III.": "All three landmarks align with the underground coordinates. Straight II -> Branch I -> Ring III.",
	"거울 자료의 방향과 집의 방향이 아직 어긋난다. 세 기준점과 글자 방향을 함께 비교한다.": "The mirror record and the mansion still face different directions. Compare all three landmarks and the lettering together.",
	"압력핀이 내려갔다. 같은 침실에서 잠든 뒤 다시 준비한다.": "The pressure pins have dropped. Sleep in the same bedroom, then prepare again.",
	"지하창고 문이 이미 열렸다.": "The basement storage door is already open.",
	"축과 깊이 홈 1·2·3을 선택한다.": "Select an axis and one of the depth notches 1, 2, or 3.",
	"이미 밀어 넣은 축은 오늘 되돌릴 수 없다.": "An axis already pushed cannot be reversed today.",
	"아직 밀지 않은 축을 선택한다.": "Select an axis that has not yet been pushed.",
	"압력핀은 축을 민 뒤 되돌릴 수 없다. 깊이를 확인하고 확정한다.": "The pressure pin cannot be reversed after pushing the axis. Check the depth and confirm.",
	"압력이 역류하며 핀이 내려간다. 먼저 통과한 축의 기록은 남는다.": "Pressure flows backward and the pins drop. The axes already passed remain in the record.",
	"압력이 허용 홈을 벗어났다. 오늘의 장치가 잠긴다.": "The pressure leaves the permitted notch. The mechanism locks for today.",
	"세 축의 압력을 먼저 안정시킨다.": "Stabilize all three axis pressures first.",
	"중앙 손잡이 방향을 선택한다.": "Select a direction for the central handle.",
	"역회전 방지턱에 닿았다. 아직 멈출 수 있다. 강행하면 중앙 잠금이 내려간다.": "The handle has reached the reverse stop. I can still stop. Forcing it will drop the central lock.",
	"역방향을 강행하자 중앙 잠금이 내려간다.": "Forcing the reverse direction drops the central lock.",
	"손잡이에서 힘을 뺀다. 시계 방향을 다시 선택할 수 있다.": "I release the pressure on the handle. I can choose clockwise again.",
	"중앙 손잡이를 시계 방향으로 반 바퀴 돌린다. 세 압력이 균형을 이루고 지하창고 문이 열린다.": "I turn the central handle half a turn clockwise. The three pressures balance, and the basement storage door opens.",
	"시계 방향 반 바퀴 실행을 확인한다.": "Confirm the clockwise half turn.",
	"알 수 없는 축 조작이다.": "That axis operation is unknown.",
	"위장 필터는 이미 해제되었다.": "The camouflage filter is already off.",
	"링이 고정되어 있다. 기동 전이라면 고정을 해제할 수 있다.": "The rings are fixed. Before startup, the lock can still be released.",
	"외곽과 중간 링이 함께 움직인다.": "The outer and middle rings move together.",
	"중간과 안쪽 링이 함께 움직인다.": "The middle and inner rings move together.",
	"안쪽 링만 움직인다.": "Only the inner ring moves.",
	"표시된 손잡이를 선택한다.": "Select one of the marked handles.",
	"XIII 홈, 분기 접점, 최하단 심장 문양이 아직 맞지 않는다.": "The XIII notch, branch junction, and lowest-heart glyph are not yet aligned.",
	"세 문양을 고정했다. 정상 레버를 감을 수 있다.": "The three glyphs are fixed. The normal lever can now be wound.",
	"기동 전 고정 해제는 한 번만 가능하다.": "The pre-start lock can be released only once.",
	"링을 먼저 정렬하고 고정한다.": "Align and fix the rings first.",
	"정상 레버는 XII에서 멈춘다.": "The normal lever stops at XII.",
	"정상 레버가 한 칸 감긴다.": "The normal lever winds forward one step.",
	"정상 레버를 XII까지 감아야 한다.": "Wind the normal lever to XII first.",
	"STABLE. 고딕 저택의 윤곽이 잠깐 반듯해졌다가 준비 상태로 돌아온다. 끝난 뒤 한 칸이 아직 남아 있다.": "STABLE. The Gothic mansion's outline briefly straightens, then returns to standby. One step remains after the apparent end.",
	"정상 안정화 절차의 결과를 먼저 확인한다.": "Check the result of normal stabilization first.",
	"패널 뒤에 보조 레버가 있다. 정상 절차 바깥의 입력이다.": "An auxiliary lever sits behind the panel. It is an input outside the normal procedure.",
	"보조 레버와 현재 기동 상태를 확인한다.": "Inspect the auxiliary lever and the current startup state.",
	"이 입력 뒤에는 현재 위장 상태를 유지할 수 없다. 아직 당기지 않을 수 있다.": "After this input, the current camouflage state cannot be maintained. I can still choose not to pull it.",
	"XIII. CAMOUFLAGE FILTER OFF. 벽의 안쪽에서 낯선 공간이 드러난다.": "XIII. CAMOUFLAGE FILTER OFF. An unfamiliar space emerges from within the walls.",
	"알 수 없는 심장 조작이다.": "That clockwork-heart operation is unknown.",
}

static func is_english(locale: String) -> bool:
	return locale.begins_with("en")

static func _pair(table: Dictionary, id: String, locale: String) -> String:
	if not table.has(id):
		return id
	return String(table[id][1 if is_english(locale) else 0])

static func objective(stage: String, locale: String) -> String:
	return _pair(OBJECTIVES, stage if OBJECTIVES.has(stage) else "default", locale)

static func location(id: String, locale: String) -> String:
	return _pair(LOCATIONS, id, locale)

static func ui(id: String, locale: String) -> String:
	return _pair(UI, id, locale)

static func storage_name(id: String, locale: String) -> String:
	return _pair(STORAGE, id, locale)

static func axis_name(id: String, locale: String) -> String:
	return _pair(AXES, id, locale)

static func anchor_name(id: String, locale: String) -> String:
	return _pair(ANCHORS, id if ANCHORS.has(id) else "", locale)

static func glyph(ring: int, position: int, locale: String) -> String:
	return String(GLYPHS[ring][position][1 if is_english(locale) else 0])

static func floorplan_status(local: Dictionary, locale: String) -> String:
	if not is_english(locale):
		return "평면도와 C5 투명지\n회전 %d° · %s · 고정점 %s\n세 기준점뿐 아니라 거울에 뒤집힌 글자의 방향도 확인한다." % [local["rotation"], "좌우 반전" if local["flipped"] else "반전 없음", anchor_name(String(local["anchor"]), locale)]
	return "Floorplan and C5 transparency\nRotation %d° · %s · Anchor: %s\nCheck both the three landmarks and the direction of the mirror-reversed lettering." % [local["rotation"], "Horizontally mirrored" if local["flipped"] else "Not mirrored", anchor_name(String(local["anchor"]), locale)]

static func axis_status(axis: String, axes: Dictionary, locale: String) -> String:
	if not is_english(locale):
		return axis_name(axis, locale) + (" · 밀기 완료" if axis in axes["pushed"] else " · 깊이 " + str(axes["depths"][axis]))
	return axis_name(axis, locale) + (" · Pushed" if axis in axes["pushed"] else " · Depth " + str(axes["depths"][axis]))

static func heart_status(heart: Dictionary, locale: String) -> String:
	var labels: Array[String] = []
	for index in range(3):
		labels.append(glyph(index, int(heart["rings"][index]), locale))
	return "%s\n%s\n%s: %d / XII" % [ui("heart_outer_middle_inner", locale), " / ".join(labels), ui("normal_lever", locale), heart["wind"]]

static func demo_beat(index: int, locale: String) -> String:
	return String(DEMO_BEATS[clampi(index, 0, DEMO_BEATS.size() - 1)][1 if is_english(locale) else 0])

static func feedback(source: String, locale: String) -> String:
	if source.is_empty() or not is_english(locale):
		return source
	if FEEDBACK_EN.has(source):
		return String(FEEDBACK_EN[source])
	var translated := PackedStringArray()
	for line in source.split("\n"):
		translated.append(_feedback_line(String(line)))
	return "\n".join(translated)

static func _feedback_line(source: String) -> String:
	if FEEDBACK_EN.has(source):
		return String(FEEDBACK_EN[source])
	for axis in AXES:
		var korean := String(AXES[axis][0]) + "의 게이지가 안정된다. 손바닥보다 치아에 압력이 먼저 닿는다."
		if source == korean:
			return axis_name(axis, "en") + " gauge stabilizes. The pressure reaches my teeth before my palm."
	return source
