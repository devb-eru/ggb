extends SceneTree

const NOTES := preload("res://scripts/systems/journal_four_display_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const DISPLAY := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var contents := {}
var failed := false


func _initialize() -> void:
	var path := "res://data/notebook/journal_four_display_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for key in ["CONFIRM", "MINIMUM", "CLEAR", "ORDER"]:
		_fixed(key, NOTES.RULES.TEXT[key], true)
	_fixed("STATUS_ORDER", NOTES.RULES.TEXT.ORDER_MISMATCH, false)
	for page in NOTES.RULES.ORDER:
		_fixed("PAGE_" + String(page).to_upper(), NOTES.RULES.PAGES[page], true)
		_fixed("SCREEN_PAGE_" + String(page).to_upper(), NOTES.RULES.PAGES[page], false)
	for key in NOTES.SCREEN: _fixed("SCREEN_" + key, NOTES.SCREEN[key], false)
	for pages in NOTES.all_orders(): _fixed(NOTES.order_key(pages), NOTES.order_text(pages), false)
	var document := CONTENT.definition(NOTES.DOCUMENT.ID, 1)
	for segment in document.visible_segment_ids:
		var key := "READ_" + String(segment).to_upper()
		if segment in document.original_only_segments:
			var row := _base(key, "dialogue", "read")
			_subject(row)
			_segment(row, "body", "{original_text}", "{original_text}", {"original_text": "string"})
			row.original_only_segments = ["body"]
			contents[NOTES.PREFIX + key] = {"1": row}
		else:
			_paragraphs(key, document.locales["ko-KR"][segment], document.locales["en-US"][segment], "read")
	_confirmation()
	var segments := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not CONTENT._valid_row(row):
			failed = true
			push_error("Invalid J4 display row: " + id)
		segments += row.visible_segment_ids.size()
	if failed or contents.size() != 102:
		push_error("Invalid J4 display catalog: %d" % contents.size())
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_J4_DISPLAY_SEED: 102 IDs / %d segments" % segments)
	quit()


func _fixed(key: String, ko: String, spoken: bool) -> void:
	var en := DISPLAY.text(ko, "en-US")
	if ko == en:
		failed = true
		push_error("Missing J4 translation: " + key)
	if spoken:
		_paragraphs(key, ko, en, "feedback")
	else:
		var row := _base(key, "document_segment", "displayed")
		_segment(row, "body", ko, en)
		contents[NOTES.PREFIX + key] = {"1": row}


func _paragraphs(key: String, ko: String, en: String, variant: String) -> void:
	var row := _base(key, "dialogue", variant)
	_subject(row)
	var ko_parts := ko.split("\n", false)
	var en_parts := en.split("\n", false)
	if ko_parts.size() != en_parts.size():
		failed = true
		push_error("Unequal paragraph counts: " + key)
		return
	for index in range(ko_parts.size()): _segment(row, "line_%02d" % (index + 1), ko_parts[index], en_parts[index])
	contents[NOTES.PREFIX + key] = {"1": row}


func _confirmation() -> void:
	var row := _base("CONFIRM_OPTIONS", "options_presented", "shown")
	row.protection_reasons = ["choice_context"]
	row.choices = []
	row.cancel_index = 0
	for locale in row.locales: row.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	var owners := {"ko-KR": {}, "en-US": {}}
	for mask in range(32):
		var ko := PackedStringArray()
		var en := PackedStringArray()
		for index in range(5):
			if (mask & (1 << index)) != 0:
				ko.append(NOTES.RULES.NAMES[index])
				en.append(DISPLAY.J4_NAME_EN[NOTES.RULES.NAMES[index]])
		owners["ko-KR"]["mask_%02d" % mask] = "없음" if ko.is_empty() else ", ".join(ko)
		owners["en-US"]["mask_%02d" % mask] = "None" if en.is_empty() else ", ".join(en)
	row.enums = {"remaining_owners": owners}
	_segment(row, "header", NOTES.MODAL_TITLE, DISPLAY.text(NOTES.MODAL_TITLE, "en-US"))
	_segment(row, "warning", "남은 사용인 사건은 이후 완료할 수 없습니다. 메인 진행과 두 최종 선택지는 유지됩니다.", "Any remaining servant events will become unavailable. Main progression and both final choices remain open.")
	_segment(row, "counts", "완료: {completed} / 5 · 연구원 기록: {records} / 5", "Completed: {completed} / 5 · Researcher records: {records} / 5", {"completed": "int", "records": "int"})
	_segment(row, "remaining", "미완료: {owners}", "Incomplete: {owners}", {"owners": "enum:remaining_owners"})
	_segment(row, "no_time", "남은 예상 시간: 남은 선택 사건 없음", "Estimated time remaining: No optional events remain")
	_segment(row, "time", "남은 예상 시간: {lower}~{upper}분", "Estimated time remaining: {lower}-{upper} min", {"lower": "int", "upper": "int"})
	_segment(row, "minimum", "에드가 전체 사건은 최소 접근 절차로 대체됩니다. 최소 절차는 기록·관계·완료 수를 제공하지 않습니다.", "Edgar's full event will be replaced by the minimum-access procedure. It grants no record, relationship reward, or completion count.")
	for index in range(2):
		var ko: String = NOTES.MODAL_LABELS[index]
		var en := DISPLAY.text(ko, "en-US")
		_segment(row, "option_%d" % index, ko, en)
		var key := "CONFIRM_SELECT_%d" % index
		row.choices.append({"content_id": NOTES.PREFIX + key, "kind": "cancel" if index == 0 else "confirm"})
		var selected := _base(key, "choice_cancelled" if index == 0 else "choice_confirmed", "option_%d" % index)
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
		_segment(selected, "body", ko, en)
		contents[NOTES.PREFIX + key] = {"1": selected}
	contents[NOTES.PREFIX + "CONFIRM_OPTIONS"] = {"1": row}


func _base(key: String, kind: String, variant: String) -> Dictionary:
	return {"producer_id": "NP15", "source_file": "scripts/chapters/basement_controller.gd", "source_symbol": key,
		"event_id": NOTES.event_for(key), "node_ids": NOTES.nodes_for(key), "action_or_variant": variant, "speaker_id": "SYSTEM",
		"location_source": "captured_before_commit_or_actual_display", "entry_kind": kind, "disclosure_owner": "actual_display",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": ["clue_source"],
		"localization_keys": {}, "variables": {}, "locales": {"ko-KR": {"speaker": "장면", "title": "일지의 약속과 접근 권한", "summary": "확인한 일지와 접근 절차"}, "en-US": {"speaker": "Scene", "title": "The Journal's Promise and Access Authority", "summary": "The observed journal and access procedure"}}}


func _subject(row: Dictionary) -> void:
	row.speaker_id = "SUBJECT"
	for locale in row.locales: row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale)


func _segment(row: Dictionary, id: String, ko: String, en: String, variables: Dictionary = {}) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = variables
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
