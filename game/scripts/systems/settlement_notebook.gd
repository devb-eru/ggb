extends RefCounted

const EVENING := preload("res://scripts/systems/last_evening.gd")
const APPROACH := preload("res://scripts/systems/core_approach.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_SETTLEMENT_"
const NAME_RECORD := "마라 2(가칭)"
const SCREEN := {
	"MARA2": "마라 2가 자신의 이름을 확인해 달라고 한다.\n기록하거나 불러 주거나 장난으로 답할 수 있다.",
	"OPTIONAL": "남은 후속 반응은 선택 사항이다.\n코어 문턱을 넘기 전까지 확인할 수 있다.",
}
const CHOICES := {
	"QUESTION": ["나한테 무엇을 바라고 있어요?", "내가 떠나면 여러분은 어떻게 돼요?", "내가 남으면 무엇이 달라져요?"],
	"MARA2": ["수첩에 마라 2(가칭)를 적는다", "이름을 다시 불러 준다", "장난으로 넘긴다"],
	"EDGAR": ["열어 주세요.", "명령이에요. 열어요.", "아무 말 없이 기다린다"],
}
const MODALS := {
	"E5_FINISH": {"title": "코어 접근 준비", "body": "저녁의 결산을 마칩니다. 남을지 떠날지는 코어에서 다시 확인합니다.", "labels": ["아직 준비되지 않았다", "준비를 마친다"]},
	"E6_ENTER": {"title": "코어 경로 진입", "body": "진입하면 이전 공간으로 돌아갈 수 없고, 미확인 후속 반응은 종료됩니다. 완료한 관계와 저녁의 결산은 유지됩니다. 현실·잔류 선택은 아직 하지 않습니다.", "labels": ["아직 조사한다", "문턱을 넘는다"]},
}


static func paragraphs(group: String, keys: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		if group == "E6" and key == "MOVE": continue
		var id: String = PREFIX + group + "_" + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func options(key: String) -> Dictionary:
	var id := PREFIX + key + "_OPTIONS"
	var segments := {}
	for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []): segments[segment] = {}
	return CONTENT.descriptor(id, 1, segments)


static func write_name(state: Dictionary, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "NAME_RECORD", NAME_RECORD, context, locale)


static func event_for(key: String) -> String:
	if key.begins_with("E5_") or key.begins_with("QUESTION_"): return "E5"
	if key.begins_with("E6_MARA2") or key.begins_with("MARA2_") or key == "NAME_RECORD" or key == "SCREEN_MARA2": return "MARA2_FU"
	if key.begins_with("E6_EDGAR") or key.begins_with("EDGAR_"): return "EDGAR_S3"
	return "E6"


static func node_for(key: String) -> String:
	return "E5" if event_for(key) == "E5" else "E6"


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in EVENING.TEXT: rows["E5_" + key] = _row(EVENING.TEXT[key])
	for owner in EVENING.OWNERS:
		rows["E5_INSERT_" + owner.to_upper()] = _row(EVENING.INSERTS[owner])
		rows["E5_DISTANCE_" + owner.to_upper()] = _row(EVENING.DISTANCE[owner])
	for outcome in EVENING.OVERLAYS: rows["E5_OVERLAY_" + outcome.to_upper()] = _row(EVENING.OVERLAYS[outcome])
	for key in EVENING.QUESTIONS: rows["E5_QUESTION_" + key.to_upper()] = _row(EVENING.feedback_text("QUESTION_" + key.to_upper()))
	for key in APPROACH.TEXT:
		if key != "MOVE": rows["E6_" + key] = _row(APPROACH.TEXT[key])
	for key in SCREEN: rows["SCREEN_" + key] = {"text": SCREEN[key], "kind": "document_segment", "variant": "displayed"}
	rows.NAME_RECORD = {"text": NAME_RECORD, "kind": "document_segment", "variant": "recorded"}
	return rows


static func _row(text: String) -> Dictionary:
	return {"text": text, "kind": "dialogue", "variant": "feedback"}
