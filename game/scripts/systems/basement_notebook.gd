extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PUBLIC_LABELS := preload("res://scripts/systems/notebook_puzzle_labels.gd")
const FIXED := {
	"FLOORPLAN": "이중 바닥에서 평면도를 꺼내 거울 회로 투명지와 일지 좌표를 함께 펼쳤다. 자료는 모였지만 방향은 아직 검증하지 않았다.",
	"SHORTCUT": "일과를 마치고 평면도를 다시 꺼냈다. 검증한 깊이만 미리 맞췄다. 축을 미는 것은 직접 결정한다.",
	"FASTPATH": "기록한 순서로 물리 장치를 다시 작동했다. 지하창고 문이 열린다.",
	"ACCESS": "세 축과 중앙 반 바퀴로 지하창고 접근 경로를 검증했다.",
	"FAILURE_SUFFIX": "당일 입력 잠김. 잠든 뒤 도면과 검증한 깊이는 남는다.",
	"D4": "XII 뒤 보조 입력을 실행했다. 위장 필터 해제. 정상 안정화만으로는 닿지 않는 공간이었다.",
	"DOOR": "반복 구조의 중심에 태엽 심장실 문이 드러난다.",
}
const STORAGE := {
	"barrel": "빈 와인통 안쪽에 같은 나사 간격이 반복된다.",
	"cable": "케이블 릴의 선이 선반 뒤로 모인다. 먼지 아래 방향이 하나로 이어진다.",
	"filter": "장식 테두리와 닮은 부품. 안쪽에는 위장 필터라는 표식이 있다.",
	"drawing": "찢어진 낙서 조각의 중심과 선반의 빈자리가 겹친다.",
}
const RESOLVED := "지하창고 문을 여는 절차를 검증했다. 먼저 잠겼던 압력핀과 당시의 실패 기록은 지우지 않는다."


static func paragraphs(id: String) -> Array:
	if not ROLLOUT.enabled() or id.is_empty(): return []
	var content_id := "NB_BASEMENT_" + id
	var version := PUBLIC_LABELS.version(content_id)
	var row := CONTENT.definition(content_id, version)
	var result: Array = []
	for segment in row.get("visible_segment_ids", ["line_01"]):
		result.append({"content_id": content_id, "content_version": version, "variant_id": "feedback", "segments": {segment: {}}})
	return result


static func write(state: Dictionary, id: String, source: String, context: Dictionary, locale: String) -> Dictionary:
	var content_id := "NB_BASEMENT_NOTE_" + id
	return EVENT_NOTES.write(state, content_id, source, context, locale, PUBLIC_LABELS.version(content_id))
