extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
# Explicit producer IDs, never a reverse lookup of old saved text.
const FIXED := {
	"WAKE": "같은 아침이다. 방의 흔적과 수첩을 비교해 본다.",
	"MOVE": "문턱을 넘는다.",
	"MARK": "표식을 남겼다. 아직 내일의 내가 읽기 전이라 증거는 완성되지 않았다.",
	"CONFIRM_MARK": "내가 쓴 표식이다. 수첩은 방과 다른 시간 위에 놓여 있다.",
	"ROUTINE": "젖은 천이 어제와 같은 호를 그린다. 책등 세 권과 다섯 이름표를 정리하고, 물이 끓는 동안 모래시계를 뒤집는다. 익숙한 일과가 끝났다.",
	"LAYOUT_SOLVED": "대응접실 → 외부 서고 → 서쪽 대시계. 침실은 단절. 네 조각의 배치를 검증했다.",
}


static func paragraphs(id: String, variables: Dictionary = {}) -> Array:
	if not ROLLOUT.enabled(): return []
	var content_id := "NB_CH1_" + id
	var row := CONTENT.definition(content_id, 1)
	var result: Array = []
	# A missing explicit version must fail observation, not become an unmapped line.
	for segment in row.get("visible_segment_ids", ["line_01"]):
		result.append({"content_id": content_id, "content_version": 1, "variant_id": "feedback", "segments": {segment: variables.duplicate(true)}})
	return result


static func layout(checked: Dictionary, reveal_faults: bool) -> Array:
	if not ROLLOUT.enabled(): return []
	if checked.ok: return paragraphs("LAYOUT_SOLVED")
	var result := paragraphs("LAYOUT_COUNT", {"matched": int(checked.matched)})
	if reveal_faults:
		for fault in checked.faults:
			var variables := {"position": int(fault.position)} if fault.kind in ["piece", "rotation"] else {}
			result.append_array(paragraphs("LAYOUT_" + String(fault.kind).to_upper(), variables))
	return result
