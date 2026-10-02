extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const TEXT := {
	"D5_COMPLETE": "시계는 잠깐 정상적으로 움직인다. 벽지의 무늬가 벗겨지며 배선과 진단 문자가 드러난다. 사용인의 윤곽에서 서로 다른 서명이 조금씩 어긋난다.",
	"E1_WAKE": "종도 새소리도 없다. 냉각 팬이 느려진다. 이불은 어제와 같은 무게인데, 그 아래 금속 고정구가 손목을 따라 떨린다. 커튼 사이 아침빛은 그림자를 만들지 않는다.\n수첩에 흑연 글씨가 남아 있다. '같은 아침이어야 한다.' 마지막 획이 떨린다.",
	"E1_REPEAT_BED": "천은 부드럽다. 그 아래가 무엇인지는 이제 안다.",
	"E1_UNLOCK": "침실 문 걸쇠가 풀린다. 잠들었는데도, 돌아오지 않았다.",
	"E1_ALL": "달라진 것이 네 개가 아니었다. 달라지지 않은 척하는 방법이 네 군데에서 끝난 것이다.",
	"LUCA_ASK": "괜찮아요... 아직은요. 이 소리가 빨라지면, 제가 먼저 말할게요. 그건... 꼭 말할게요.",
	"LUCA_HOLD": "따뜻한 쪽이 어느 쪽인지 헷갈렸어요... 같이 돌아가요.",
	"LUCA_WITHDRAW": "괜찮아요... 천천히 오세요. 같이 돌아가요.",
	"E2_REPORT": "보고드리겠습니다. 정상 리셋 복구가 불가능합니다.\n마라 1의 웃음이 두 번 재생되고 멎는다. 루카는 손목과 진단 신호를 번갈아 본다. 이리스의 미소 아래 플라스틱 날개가 닫힌다.\n마라 2가 겹친 이름표를 붙든다. '너무 오래 쓴 표지야! 이제 안쪽 기능실이 보이는 거지.'",
	"E2_FINISH": "위장 필터는 돌아오지 않습니다. 외부 신체의 생존 신호는 있으나 기상의 안전을 보장하지 못합니다. 저희 기억은 물리 리셋 대상이 아니었습니다.\n각 장치를 조사할지, 바로 기록 결산으로 갈지는 귀하가 결정합니다. 더는 그 선택을 잠그지 않겠습니다.",
	"MOVE_KITCHEN": "이중 맥박 표식을 따라 사용인 통로를 지나 주방으로 간다.",
	"MOVE_CORRIDOR": "조용한 복도를 지나간다.",
	"D6_MOVE": "익숙한 복도의 외피 아래로 휴식 경로가 이어진다.",
	"D6_REST": "조금 눈을 감는다. 이번에는 무엇이 돌아올지 알 수 없다.",
	"POST_REST": "잠깐 쉬어도 균열과 수리한 곳은 돌아가지 않는다.",
}
const NOTES := {
	"E1_WAKE": "같은 아침이어야 한다.",
	"E1_DIFFERENT": "잠들었지만 세계는 복구되지 않았다.",
	"E2_REPORT": "위장 필터는 복구되지 않는다. 바깥 신체의 생존 신호는 유지되지만 기상 안전은 미확정이다. 사용인의 기억은 물리 리셋에서 제외되어 있었다.",
	"INDEX_KNOWN": "ARCHIVE / MARA2",
	"INDEX_ANONYMOUS": "ARCHIVE / 소유자 미확인 · 겹친 액자 · 이중 윤곽",
}
const INSPECTIONS := {
	"wall": "벗겨진 벽지 뒤 금속 격자는 기억하는 방보다 좁다. 손끝에는 종이와 금속의 경계가 동시에 닿는다.",
	"sign": "서비스 척추 표지의 다섯 기능실 방향과 SUBJECT 방향이 갈라져 있다. 아직 기능실로 들어갈 수는 없다.",
	"trace": "몸은 없는데 문양만 일정한 간격으로 지나간다. 잠금선, 닦임 자국, 이중 맥박, 꽃잎, 겹친 액자. 알아보는 것은 색만이 아니다.",
	"capsule": "비상 캡슐 표면에 침실 침대와 같은 직물 무늬가 투사된다. 가까이서는 천의 결 아래 매끄러운 곡면이 느껴진다.",
	"notebook": "수첩의 낙서 저택을 펼쳐 배선과 겹쳐 본다. 복도 끝에서 꺾인 선이 같다. 내가 그린 선을 누군가 이곳의 길로 만들었다. 종이를 접어도 벽의 선은 사라지지 않는다.",
}


static func paragraphs(ids: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for id in ids:
		var content_id := "NB_FRACTURE_" + String(id)
		var row := CONTENT.definition(content_id, 1)
		for segment in row.get("visible_segment_ids", ["line_01"]):
			result.append({"content_id": content_id, "content_version": 1, "variant_id": "feedback", "segments": {segment: {}}})
	return result


static func displayed(id: String) -> Dictionary:
	return {"content_id": "NB_FRACTURE_" + id, "content_version": 1, "variant_id": "feedback", "segments": {"body": {}}}


static func write(state: Dictionary, id: String, source: String, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, "NB_FRACTURE_NOTE_" + id, source, context, locale)
