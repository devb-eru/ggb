extends RefCounted

const DOCUMENT := preload("res://scripts/systems/journal_four_notebook.gd")
const RULES := preload("res://scripts/systems/journal_four.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const PREFIX := "NB_J4_DISPLAY_"
const SCREEN := {
	"GUIDE": "획득하지 않은 기록은 빈 인덱스다.\n아버지 일지와 시스템 날짜만으로도 네 사건을 배열할 수 있다.",
	"MINIMUM": "에드가의 전체 관계 사건은 종료되었다.\n최소 접근 핀은 기록이나 관계 보상이 아니다.",
}
const MODAL_TITLE := "조사 종료 확인"
const MODAL_LABELS := ["계속 조사한다", "기록을 정리한다"]


static func paragraphs(key: String) -> Array:
	if not ROLLOUT.enabled() or key.is_empty(): return []
	var id := PREFIX + key
	var result: Array = []
	for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
		result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func read_paragraphs(document: Dictionary) -> Array:
	if not ROLLOUT.enabled() or document.is_empty(): return []
	var result: Array = []
	for segment in CONTENT.definition(DOCUMENT.ID, 1).visible_segment_ids:
		if not document.segments.has(segment): continue
		var key := "READ_" + String(segment).to_upper()
		if String(segment).ends_with("_original"):
			for line in String(document.segments[segment].original_text).split("\n", false):
				result.append(CONTENT.descriptor(PREFIX + key, 1, {"body": {"original_text": line}}))
		else:
			result.append_array(paragraphs(key))
	return result


static func order_key(pages: Array) -> String:
	return "SCREEN_ORDER_" + ("EMPTY" if pages.is_empty() else "_".join(pages).to_upper())


static func order_text(pages: Array) -> String:
	var names := PackedStringArray()
	for page in pages: names.append(String(RULES.PAGES[page]).split(" · ")[0])
	return "현재 배열: " + ("없음" if names.is_empty() else " → ".join(names))


static func confirmation(totals: Dictionary) -> Dictionary:
	var mask := 0
	for index in range(5):
		if RULES.EVENTS[index] in totals.incomplete_ids: mask |= 1 << index
	var segments := {"header": {}, "warning": {}, "counts": {"completed": totals.core_complete_ids.size(), "records": totals.researcher_record_count}, "remaining": {"owners": "mask_%02d" % mask}}
	if mask == 0: segments.no_time = {}
	else: segments.time = {"lower": totals.minutes_min, "upper": totals.minutes_max}
	if not totals.edgar_core_complete: segments.minimum = {}
	segments.option_0 = {}
	segments.option_1 = {}
	return CONTENT.descriptor(PREFIX + "CONFIRM_OPTIONS", 1, segments)


static func all_orders(prefix: Array = []) -> Array:
	var result: Array = [prefix.duplicate()]
	for page in RULES.ORDER:
		if page not in prefix: result.append_array(all_orders(prefix + [page]))
	return result


static func event_for(key: String) -> String:
	return "E3_4M" if key in ["MINIMUM", "SCREEN_MINIMUM"] else "J4"


static func nodes_for(key: String) -> Array:
	if key == "CONFIRM" or key.begins_with("CONFIRM_"): return ["E_HUB"]
	return ["E3_4M"] if event_for(key) == "E3_4M" else ["J4"]
