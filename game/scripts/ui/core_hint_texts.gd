extends RefCounted

const HINTS := {
	"F0_A": [
		["방의 겉모습보다 무엇을 받아 무엇을 내보내는지 비교하자. P5·P4·침실·일지 기록을 같은 회로의 자료로 읽는다.", "Compare what each room receives and outputs, not its appearance. Read P5, P4, the bedroom, and the journal as evidence about one circuit."],
		["외부 대기는 북쪽으로 들어오고 중앙 코어의 관리 요청은 서쪽에 있다. 이 두 고정 포트에 맞는 방의 기능을 찾자.", "Outside air enters from the north; the core's management request is in the west. Match room functions to these two fixed ports."],
		["환경 제어는 생명 유지 공급으로, 그 공급은 몸의 신경 신호로 이어진다. 기록 내실의 연출 피드백이 온실로 돌아와야 회로가 닫힌다.", "Environmental control feeds life support, which sustains the body's neural signal. The library's presentation feedback must return to the greenhouse to close the circuit."],
		["북쪽은 온실, 서쪽은 기록 내실이다. 나머지 두 방을 놓을 때 다음 물리 포트로 이어지는 방향인지 약한 신호로 확인한다.", "Place the greenhouse north and the inner library west. As you place the remaining rooms, use the weak signal to check connections to the next physical port."],
		["북쪽 온실→동쪽 주방→남쪽 침실→서쪽 기록 내실→북쪽 온실로 연결한다. 각 화살표는 다음 방위 슬롯을 가리키며 내실의 중앙 요청 포트도 유지한다.", "Connect north greenhouse → east kitchen → south bedroom → west inner library → north greenhouse. Each arrow points to the next compass slot; preserve the library's central request port too."],
	],
	"F0_B": [
		["보기 좋은 장면을 만드는 기록과 몸·인격을 유지하는 기록은 다르다. 표본의 이름뿐 아니라 연결선이 어디에서 끝나는지 조사하자.", "Records that create a pleasing scene differ from records that sustain a body or personality. Inspect where each sample's connection ends, not just its name."],
		["장면을 멈추거나 하루가 반복되어도 남는 신호가 있는지 비교한다. 향·메뉴·역할 애니메이션과 실제 유지 장치의 출력을 구분하자.", "Compare which signals persist when a scene stops or a day repeats. Separate scent, menu, and role animation from actual maintenance output."],
		["온실 표본은 외부 흡입구에서 공급 장치로, 주방 표본은 침실 냉각 장치로 이어지는지 본다. 표본을 선택한 뒤 전송해 검증한다.", "Check whether the greenhouse sample reaches the supply equipment from the outside intake and whether the kitchen sample reaches bedroom cooling. Inspect a sample before sending it for verification."],
		["침실에서는 애니메이션을 멈춰도 이어지는 생체 신호가 필요하다. 기록 내실에서는 책등 배치가 아니라 이전 항목을 유지하는 인덱스를 찾는다.", "In the bedroom, you need the biological signal that persists when animation stops. In the library, look for the index retaining earlier entries, not the book-spine layout."],
		["외부 대기 수치·생명 유지 유체 흐름·현재 생체 신호·지속 기억 인덱스가 네 유지 표본이다. 네 채널이 맞아도 접근 거부는 남은 포트 문제일 수 있다. 관계 이벤트 수로 해결하는 조건이 아니다.", "The four maintenance samples are outside-air readings, life-support fluid flow, current biological signal, and persistent memory index. Access denial after verifying all four may concern a missing port, not the number of relationship events completed."],
	],
	"F0_C": [
		["B4는 완료 뒤 추가 입력, C5는 경로와 인증 고리, D4는 포트의 빈자리를 보여 준다. 세 장이 모두 같은 역할을 하는 자료는 아니다.", "B4 shows input after completion, C5 shows paths and authentication loops, and D4 shows a vacant port. The three layers serve different purposes."],
		["B4의 열두 번째 종 완료선, C5의 닫힌 고리 중심, D4의 중앙 심장 포트를 기준으로 삼는다. 투명도는 읽기 보조이지 정답 조건이 아니다.", "Anchor B4 at the twelfth-bell completion line, C5 at the closed-loop center, and D4 at the central heart port. Opacity helps reading; it is not a solution condition."],
		["D4는 움직이지 않는 기준판이다. B4는 반전 없이 회전하고, C5는 거울에서 얻은 회로라 좌우 반전과 회전을 함께 비교한다.", "D4 is the fixed reference. Rotate B4 without mirroring. Since C5 came from the mirror, compare horizontal mirroring together with rotation."],
		["B4는 180도 회전·반전 없음이다. C5는 좌우 반전 뒤 반시계 방향 90도로 맞춘다. 각 자료의 기준점을 원래 의미에 맞춰 고정해야 한다.", "Rotate B4 by 180 degrees without mirroring. Mirror C5 horizontally, then rotate it 90 degrees counterclockwise. Align each layer's anchor with its intended reference."],
		["D4는 고정, B4는 180도, C5는 좌우 반전+반시계90도다. 세 기준점을 맞춰 완전 중첩을 검증한 뒤 PATH 경로→SPLIT 분기→AUTH 인증 고리 순서로 조사한다. 그림을 겹친 것만으로 조사가 끝나지는 않는다.", "Keep D4 fixed, rotate B4 180 degrees, and mirror C5 plus rotate it 90 degrees counterclockwise. Verify the aligned anchors, then inspect PATH → SPLIT → AUTH. Aligning the image alone does not complete the investigation."],
	],
	"F0_D": [
		["기록을 만든 사람과 기록의 역할은 같지 않을 수 있다. 색은 출처를 구분하지만 슬롯의 정답은 기록이 한 일을 읽어 판단한다.", "A record's author and its role are not necessarily the same. Color identifies its source; assign the slot by what the record does."],
		["만든 자, 관리한 자, 계속 존재하는 자, 자동 실행, 결과를 겪는 주체를 구분하자. 호감이나 신뢰 순위를 매기는 판이 아니다.", "Distinguish creator, custodian, continuing resident, automatic execution, and the subject living with the consequences. This is not a ranking of affection or trust."],
		["아버지의 설계와 에드가의 접근 허가는 서로 다른 기능이다. 연구원 기록은 거주 인격의 지속을 말하고 D4 명령은 조건에 따라 실행된다.", "The father's design and Edgar's access permission have different functions. Researcher records concern continuing resident personalities; the D4 command executes under set conditions."],
		["주인공 수첩은 이 삶의 결과를 겪는 사람이 직접 남긴 기록이다. 사용인 기록이 부족해도 익명 인덱스로 기능은 확인할 수 있다.", "The protagonist's notebook is written by the person living with this life's consequences. Even without personal servant records, anonymous indices preserve the functional evidence."],
		["아버지 일지=CREATOR, 에드가 암구호=CUSTODIAN, 연구원 기록=RESIDENT, D4 명령=SYSTEM, 주인공 수첩=SUBJECT다. 빈칸이 있는 역할 이름은 기능 문장과 함께 읽는다.", "Father's journal: CREATOR. Edgar's passphrase: CUSTODIAN. Researcher records: RESIDENT. D4 command: SYSTEM. Protagonist's notebook: SUBJECT. Read incomplete role labels alongside their functional descriptions."],
	],
	"F0_E": [
		["과거 표시와 현재의 빈 줄은 다른 확인 절차다. 무엇을 선택하느냐보다 누가 지금 기록하는지 살펴보자.", "The old mark and the current blank line are separate checks. Look at who writes now, rather than which outcome they prefer."],
		["A1에서 직접 남겼던 표시를 수첩에서 확인한다. 문장·저택 문양·잉크 흔적 중 실제로 선택한 유형을 기준으로 조각 순서를 되짚는다.", "Check the mark you made in A1. Reconstruct the sequence for the type you actually chose: sentence, house glyph, or ink trace."],
		["과거 표시를 확인해도 현재 작성자 확인은 남는다. 아버지·시스템·사용인의 문장을 가져오는 것과 지금 직접 쓰는 것은 다르다.", "Verifying the old mark still leaves the current-author check. Importing the father's, system's, or servants' words is different from writing yourself now."],
		["현재의 주인공이 직접 쓰는 동작으로 작성자를 확인한다. 이 인증은 밖으로 나가겠다는 선언도, 저택에 남겠다는 약속도 아니다.", "Verify authorship by having the present protagonist write directly. This authentication neither declares departure nor promises to remain."],
		["과거 조각을 원래 표시 순서로 맞추고 현재 작성자를 주인공으로 확인한다. 이후 현실·잔류·미정 세 임시 의향은 모두 같은 진행으로 합류한다. 정답 의향은 없으며 최종 선택은 나중에 다시 한다.", "Restore the old pieces in their original order and verify the protagonist as the current author. Reality, staying, and undecided all lead to the same next stage. No provisional preference is the correct answer; the final choice comes later."],
	],
}

static func text(stage: String, level: int, locale: String) -> String:
	if not HINTS.has(stage) or level < 0 or level >= 5:
		return ""
	return HINTS[stage][level][1 if locale.begins_with("en") else 0]
