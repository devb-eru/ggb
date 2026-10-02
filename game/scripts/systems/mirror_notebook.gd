extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const FIXED := {
	"OBSERVE": "그 표면은 닦는 대상이 아닙니다. 보존 처리가 되어 있습니다.",
	"WARNING": "지난번 조사와 연결해서 생각하고 계십니까? 손에 드는 물건부터 확인하겠습니다.",
	"C0_NOTE": "거울이 호흡보다 조금 늦게 흐려진다. 에드가는 청소가 아니라 보존이라는 말을 썼다.",
	"HYPOTHESIS": "얼룩이 아니라 코팅일지도 모른다. 일지의 신호와 청소 기록, 약품 라벨을 비교해 보자.",
	"CLEANING": "청소 기록: 강한 용제는 코팅을 굳힌다. 중성 세정과 부드러운 천을 사용할 것.\n물의 양은 두 첨가제를 합친 양보다 2단위 많게 한다.\n마라 1의 추기: 물때랑 코팅을 헷갈리면 안 됨다. 제가 한 번 크게 배웠슴다.",
	"CHEMICALS": "라벨: 전체 8단위. 원액은 안정제의 두 배.\n마른 병에 활성 성분을 넣지 말 것. 물에 안정제가 퍼진 뒤 원액을 넣을 것.\n접힌 메모: 손이 떨릴 때도 읽을 수 있게... 큰 글씨로 다시 써 뒀어요.",
	"PREPARE": "빈 눈금병, 물, 안정제와 원액, 부드러운 천을 새로 준비했다. 공식은 남아 있어도 세정액은 직접 다시 만든다.",
	"DISCARD": "폐기 쟁반에 용액을 비우고 병을 헹군다. 같은 날 다시 계량할 수 있다.",
	"DISPERSE": "물 표면이 숨을 고르듯 내려앉는다. 안정제가 퍼졌다.",
	"SETTLE": "병을 내려놓고 기다리자 거품이 가라앉는다.",
	"FORMULA": "검증한 공식: 물 5, 안정제 1, 원액 2. 물 → 안정제 확산 → 원액, 천천히 혼합.",
	"BELL": "수첩에 검증한 시계망 설정을 다시 놓는다. 정상 종이 끝난 뒤 한 칸, 열세 번째 떨림이 벽을 지난다.",
	"PATROL_WAIT": "순찰이 지나갈 때까지 기다린다. 에드가의 발소리가 멀어진다.",
	"PATROL_QUESTION": "일지 문장에 관해 묻자 에드가가 복도 쪽에서 보존 원칙을 설명한다. 점검은 끝났다.",
	"PATROL_CLOTH": "일반 천을 앞에 두자 에드가가 그 천을 점검하고 나간다.",
	"PLAN": "마른 시험에서 확인한 계획을 수첩에 확정했다. 아직 코팅에는 손대지 않았다.",
	"CONFISCATED": "에드가가 젖은 천을 거둔다. 아직 점검을 마치지 않았다는 말만 남긴다.",
	"RAW": "검은 표면 아래 진단 패널과 냉각 장치 같은 긴 윤곽이 드러난다. 거울 속 호흡만 한 박자 늦다.\n드러난 원도를 우선 수첩에 옮겼다. 다섯 문양의 해석과 대조는 아직 남아 있다.",
	"FAILURE_SUFFIX": "오늘은 다시 닦을 수 없다. 잠든 뒤 기록으로 준비를 줄인다.",
	"SCAN_SUFFIX": "서로 다른 문양이 같은 면 아래에서 겹친다. 이것이 무엇인지는 아직 단정할 수 없다.",
	"RECORD": "직선·분기·고리의 반사 원도, 침실 창·온실 유리·대시계 기준점과 지하 좌표를 수첩에 고정했다.",
	"OVERLAY": "탁본을 그대로 놓으면 세 점이 동시에 맞지 않는다. 거울의 방향과 집의 방향을 아직 같은 것으로 믿을 수 없다.",
	"MEMORY": "짧은 연필이 종이 가루를 밀어 낸다. 더 큰 손이 외벽을 짚자 없던 문 윤곽이 생긴다. '문은 네가 고르는 곳에...' 기억은 거기서 끊긴다.",
}
const FAILURE_RESOLVED := "거울 회로와 다섯 출처를 기록했다. 코팅 경화와 도구 회수에 관한 이전 실패 기록은 남겨 둔다."


static func paragraphs(id: String) -> Array:
	if not ROLLOUT.enabled(): return []
	var content_id := "NB_MIRROR_" + id
	var row := CONTENT.definition(content_id, 1)
	var result: Array = []
	for segment in row.get("visible_segment_ids", ["line_01"]):
		result.append({"content_id": content_id, "content_version": 1, "variant_id": "feedback", "segments": {segment: {}}})
	return result


static func write(state: Dictionary, id: String, source: String, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, "NB_MIRROR_NOTE_" + id, source, context, locale)
