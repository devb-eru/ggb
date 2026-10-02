extends SceneTree

const OUTPUT := "res://data/notebook/modals_v1.json"
const REL := preload("res://scripts/ui/relationship_display_texts.gd")
const FIELD := preload("res://scripts/ui/field_notebook_texts.gd")
const ENDING := preload("res://scripts/ui/ending_decision_texts.gd")
const MIRROR := preload("res://scripts/ui/black_mirror_display_texts.gd")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var contents := {}


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for spec in [
		["MARA1", "E3_1", "기록을 어떻게 남길까", "두 방식 모두 사건과 명령자·수행자의 책임을 보존한다.", ["아직 결정하지 않는다", "책임자와 원문을 그대로 남긴다", "피해자 식별 정보만 보호한다"]],
		["IRIS", "E3_2", "지금의 온실", "두 방식 모두 외부값과 책임 기록을 보존한다. 현재 보이는 계절 연출을 유지할지 정한다.", ["아직 결정하지 않는다", "불완전한 외부값과 책임 로그를 그대로 남긴다", "외부값은 보존하고 현재 온실 연출은 유지한다"]],
		["LUCA", "E3_3", "확인할 순서", "두 선택 모두 같은 위험 기록을 읽는다. 지금 생존한다는 사실이 기상 안전을 보장하지는 않는다.", ["아직 결정하지 않는다", "위험 수치를 먼저 전부 읽는다", "장치를 안정시킨 뒤 기록을 함께 읽는다"]],
		["EDGAR", "E3_4", "책임의 기록", "두 선택 모두 현재 선택권은 주인공에게 반환된다. 용서 여부나 엔딩을 결정하는 선택이 아니다.", ["기록을 다시 읽는다", "당신이 한 결정도 공식 기록에 남겨요.", "기록보다 먼저, 내 권한을 내게 직접 돌려줘요."]],
		["MARA2", "E3_5", "기록의 보존", "둘 다 원본과 감정 주석을 보존한다. 병합은 완전 회복의 약속이 아니며, 분리는 포기가 아니다.", ["설명을 다시 생각한다", "감정 주석을 원본에 다시 합친다.", "원본과 주석을 분리해 서로 참조하게 한다."]],
	]:
		var texts := {}
		for locale in ["ko-KR", "en-US"]:
			texts[locale] = [REL.text(spec[2], locale), REL.text(spec[3], locale)]
			for label in spec[4]: texts[locale].append(REL.text(label, locale))
		_add(spec[0], spec[1], texts, ["cancel", "confirm", "confirm"], 0)
	for decision in ENDING.DECISION.CONFIRMATIONS:
		var texts := {}
		for locale in ["ko-KR", "en-US"]:
			if ENDING.confirmation(decision, locale).is_empty():
				push_error("Missing ending confirmation: " + decision)
				quit(1)
				return
			texts[locale] = [ENDING.text("confirm_title", locale), ENDING.confirmation(decision, locale) + "\n\n" + ENDING.text("confirm_notice", locale), ENDING.text("confirm_cancel", locale), ENDING.text("confirm_commit", locale)]
		_add("EDC_" + String(decision).to_upper(), "EDC", texts, ["cancel", "confirm"], 0)
	var summary := {}
	for locale in ["ko-KR", "en-US"]:
		summary[locale] = [ENDING.text("summary_title", locale), ENDING.summary("wake", locale) + "\n\n" + ENDING.summary("stay", locale), ENDING.text("return", locale)]
	_add("EDC_SUMMARY", "EDC", summary, ["ui"], -1)
	_field_pages()
	_route()
	for spec in [
		["CH1_SLEEP", "MORNING_ROUTE", "CH1_SLEEP_TITLE", "CH1_SLEEP_RULE", ["P6_CANCEL", "P6_SLEEP"], ["cancel", "confirm"], 0],
		["CLOCK_ACTIVATE", "B3_B", "CH1_CLOCK_CONFIRM", "CH1_CLOCK_WARNING", ["CH1_CLOCK_RETEST", "CH1_CLOCK_COMMIT", "CH1_CLOCK_EDIT"], ["confirm", "confirm", "cancel"], 2],
		["CH1_MARK", "A1", "CH1_MARK_TITLE", "CH1_MARK_PROMPT", ["CH1_MARK_SENTENCE", "CH1_MARK_HOUSE_GLYPH", "CH1_MARK_INK_CORNER"], ["confirm", "confirm", "confirm"], -1],
		["CH1_SCHEDULE", "B1", "CH1_B1_TITLE", "CH1_B1_PROMPT", ["CH1_B1_MORNING", "CH1_B1_TEA", "CH1_B1_BELL"], ["confirm", "confirm", "confirm"], -1],
	]:
		var texts := {}
		for locale in ["ko-KR", "en-US"]:
			texts[locale] = [_source(spec[2], locale), _source(spec[3], locale)]
			for id in spec[4]: texts[locale].append(_source(id, locale))
		_add(spec[0], spec[1], texts, spec[5], spec[6])
	for spec in [
		["MIRROR_PATROL", "patrol_title", "patrol_body", ["patrol_wait", "patrol_question", "patrol_cloth"], ["confirm", "confirm", "confirm"], -1],
		["MIRROR_WET", "wet_title", "wet_body", ["wet_review", "wet_dry", "wet_execute"], ["cancel", "confirm", "confirm"], 0],
	]:
		var texts := {}
		for locale in ["ko-KR", "en-US"]:
			texts[locale] = [MIRROR.ui(spec[1], locale), MIRROR.ui(spec[2], locale)]
			for key in spec[3]: texts[locale].append(MIRROR.ui(key, locale))
		_add(spec[0], "C4", texts, spec[4], spec[5])
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_MODALS_SEED: ", contents.size())
	quit()


func _source(id: String, locale: String) -> String:
	for source in [CH1, PROLOGUE, SYSTEM]:
		if source.localized_text[locale].has(id): return source.localized_text[locale][id]
	push_error("Missing modal source: " + id)
	return ""


func _add(key: String, event: String, texts: Dictionary, kinds: Array, cancel_index: int) -> Dictionary:
	var row := _base(event, "options_presented", "shown", key)
	row.choices = []
	row.cancel_index = cancel_index
	row.default_segments = ["header", "body"]
	_segment(row, key, "header", [texts["ko-KR"][0], texts["en-US"][0]])
	_segment(row, key, "body", [texts["ko-KR"][1], texts["en-US"][1]])
	for index in range(kinds.size()):
		var id := "option_%d" % index
		row.default_segments.append(id)
		_segment(row, key, id, [texts["ko-KR"][index + 2], texts["en-US"][index + 2]])
		var choice_id := "NB_MODAL_%s_SELECT_%d" % [key, index]
		row.choices.append({"content_id": choice_id if kinds[index] != "ui" else "", "kind": kinds[index]})
		if kinds[index] == "ui": continue
		var selected := _base(event, "choice_cancelled" if kinds[index] == "cancel" else "choice_confirmed", id, key)
		_segment(selected, key + "_SELECT", "body", [texts["ko-KR"][index + 2], texts["en-US"][index + 2]])
		for locale in selected.locales: selected.locales[locale].speaker = _source("HISTORY_SELECTED", locale)
		contents[choice_id] = {"1": selected}
	contents["NB_MODAL_" + key + "_OPTIONS"] = {"1": row}
	return row


func _base(event: String, kind: String, variant: String, key: String) -> Dictionary:
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	return {"producer_id": "NP05", "source_file": "scripts/chapters/chapter_one_controller.gd", "source_symbol": "_show_recorded_choice:" + key,
		"event_id": event, "node_ids": nodes, "action_or_variant": variant, "speaker_id": "SYSTEM" if kind == "options_presented" else "SUBJECT",
		"location_source": "history_context:captured_before_modal", "entry_kind": kind, "disclosure_owner": "actual_display_or_choice_press",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": ["choice_context" if kind == "options_presented" else "choice"],
		"variables": {}, "localization_keys": {}, "locales": {
			"ko-KR": {"title": "당시 열린 선택과 자료", "summary": "실제로 표시한 선택창", "speaker": _source("HISTORY_OPTIONS", "ko-KR")},
			"en-US": {"title": "Choices and material shown then", "summary": "The modal actually displayed", "speaker": _source("HISTORY_OPTIONS", "en-US")},
		}}


func _segment(row: Dictionary, key: String, id: String, texts: Array, variables: Dictionary = {}) -> void:
	row.visible_segment_ids.append(id)
	row.localization_keys[id] = "NB_MODAL_" + key + "_" + id
	row.variables[id] = variables
	row.locales["ko-KR"][id] = texts[0]
	row.locales["en-US"][id] = texts[1]


func _field_pages() -> void:
	var pages: Array = FIELD.RULES.PAGES.keys()
	for page in pages:
		for expanded in [false, true]:
			var key: String = "FIELD_" + page + ("_FULL" if expanded else "_SUMMARY")
			var next: String = pages[(pages.find(page) + 1) % pages.size()]
			var texts := {}
			for locale in ["ko-KR", "en-US"]:
				var source: Dictionary = FIELD.PAGES if locale.begins_with("en") else FIELD.RULES.PAGES
				texts[locale] = [FIELD.title(page, locale), source[page][2 if expanded else 1], FIELD.text("close", locale), FIELD.text("summary" if expanded else "expand", locale), FIELD.text("next", locale) + FIELD.title(next, locale)]
			var row := _add(key, "EDR_FIELD_NOTEBOOK", texts, ["confirm", "confirm", "confirm"], -1)
			var tail: Array = row.visible_segment_ids.slice(2)
			row.visible_segment_ids = row.visible_segment_ids.slice(0, 2)
			if expanded and page in FIELD.RULES.OWNERS:
				var owner: String = FIELD.RULES.OWNERS[page]
				for outcome in FIELD.OVERLAYS[owner]:
					_segment(row, key, "addendum_" + outcome, ["인계 부기: " + FIELD.RULES.WAKE.OVERLAYS[owner][outcome], "Handoff addendum: " + FIELD.OVERLAYS[owner][outcome]])
			if expanded and page == "SUBJECT_HANDOFF_PAGE":
				_segment(row, key, "sources_none", ["인계 출처: 별도 연구원 원문 인계 없음. 기본 운용 자료는 유지.", "Handoff sources: No separate original researcher records handed over. Basic operating information is retained."])
				_segment(row, key, "sources_present", ["인계 출처: {records}", "Handoff sources: {records}"], {"records": "string"})
			row.visible_segment_ids.append_array(tail)


func _route() -> void:
	var texts := {}
	for locale in ["ko-KR", "en-US"]:
		texts[locale] = [MIRROR.ui("route_title", locale), "Unused", MIRROR.ui("overlay_back", locale), MIRROR.ui("route_replay", locale)]
	var row := _add("MIRROR_ROUTE", "C4", texts, ["ui", "ui"], -1)
	row.visible_segment_ids = ["header"]
	row.locales["ko-KR"].erase("body")
	row.locales["en-US"].erase("body")
	row.variables.erase("body")
	row.localization_keys.erase("body")
	var cases := [[0, true, false, []], [90, false, true, []], [90, false, true, ["entry"]], [90, false, true, ["entry", "long_branch", "short_branch"]], [90, false, true, ["entry", "counterclockwise_ring"]], [90, false, true, RULES.PATH]]
	for sample in cases:
		var trace := RULES.inspect_trace(sample[0], sample[1], sample[2], sample[3])
		var text := "마른 천 시험: " + String(trace.text)
		_segment(row, "MIRROR_ROUTE", "result_" + ("success" if trace.ok else String(trace.category)), [text, MIRROR.feedback(text, "en-US")])
	_segment(row, "MIRROR_ROUTE", "route_header", ["\n선택한 순서:", "\nSelected order:"])
	_segment(row, "MIRROR_ROUTE", "route_empty", [MIRROR.ui("route_empty", "ko-KR"), MIRROR.ui("route_empty", "en-US")])
	for index in range(4):
		for segment in MIRROR.SEGMENTS:
			_segment(row, "MIRROR_ROUTE", "route_%d_%s" % [index + 1, segment], ["%d. %s" % [index + 1, MIRROR.segment_name(segment, "ko-KR")], "%d. %s" % [index + 1, MIRROR.segment_name(segment, "en-US")]])
	_segment(row, "MIRROR_ROUTE", "legend", ["\n" + MIRROR.ui("route_legend", "ko-KR"), "\n" + MIRROR.ui("route_legend", "en-US")])
	row.visible_segment_ids.append_array(["option_0", "option_1"])
	row.default_segments = ["header", "route_header", "legend", "option_0", "option_1"]
