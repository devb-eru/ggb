extends SceneTree

const OUTPUT := "res://data/notebook/mirror_v1.json"
const NOTES := preload("res://scripts/systems/mirror_notebook.gd")
const SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const DISPLAY := preload("res://scripts/ui/black_mirror_display_texts.gd")
const COMMON := preload("res://data/dialogue/prologue/prologue_text.tres")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
var contents := {}
var failed := false


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	_feedback("OBSERVE", "C0", NOTES.FIXED.OBSERVE, "EDGAR")
	_feedback("OBSERVE_WARNING", "C0", NOTES.FIXED.OBSERVE + "\n" + NOTES.FIXED.WARNING, "EDGAR")
	var events := {"HYPOTHESIS": "C1", "CLEANING": "C2", "CHEMICALS": "C2_1", "PREPARE": "C3", "DISCARD": "C3", "DISPERSE": "C3", "SETTLE": "C3", "BELL": "C4", "PATROL_WAIT": "C4", "PATROL_QUESTION": "C4", "PATROL_CLOTH": "C4", "PLAN": "C4", "RECORD": "C5_INFO", "OVERLAY": "J3"}
	for key in events:
		_feedback(key, events[key], NOTES.FIXED[key])
	_feedback("SHORTCUT", "CSHORT", NOTES.FIXED.PREPARE)
	for mix in [
		RULES.empty_mixture(),
		{"water": 6, "stabilizer": 1, "active": 1, "order": RULES.MATERIALS, "dispersed": true, "mixed": 1, "foamy": false},
		{"water": 5, "stabilizer": 1, "active": 2, "order": ["water", "active", "stabilizer"], "dispersed": true, "mixed": 1, "foamy": false},
		{"water": 5, "stabilizer": 1, "active": 2, "order": RULES.MATERIALS, "dispersed": true, "mixed": 0, "foamy": false},
		{"water": 5, "stabilizer": 1, "active": 2, "order": RULES.MATERIALS, "dispersed": true, "mixed": 1, "foamy": false},
	]:
		var result := RULES.test_mixture(mix)
		_feedback("MIXTURE_" + String(result.category).to_upper(), "C3", result.text)
	for spec in [[0, true, false, []], [90, false, true, []], [90, false, true, ["entry"]], [90, false, true, ["entry", "long_branch", "short_branch"]], [90, false, true, ["entry", "counterclockwise_ring"]], [90, false, true, RULES.PATH]]:
		var result := RULES.inspect_trace(spec[0], spec[1], spec[2], spec[3])
		var key := "SUCCESS" if result.ok else String(result.category).to_upper()
		_feedback("DRY_" + key, "C4", "마른 천 시험: " + result.text)
		_feedback("WET_" + key, "C4", result.text + ("\n" + NOTES.FIXED.RAW if result.ok else ""))
		if not result.ok: _failure(key, result.text)
	_feedback("WET_TOOL_CONFISCATED", "C4", NOTES.FIXED.CONFISCATED)
	_failure("TOOL_CONFISCATED", NOTES.FIXED.CONFISCATED)
	for owner in SESSION.CHANNELS:
		for mode in ["SURFACE", "COPY"]:
			_feedback("SCAN_" + mode + "_" + owner, "C5_INFO", ("진단면: " if mode == "SURFACE" else "수첩의 진단면 사본: ") + SESSION.CHANNELS[owner] + "\n" + NOTES.FIXED.SCAN_SUFFIX)
	var j3 := "\n\n".join(SESSION.J3_PARTS)
	_feedback("J3", "J3", j3)
	_feedback("J3_MEMORY", "J3", j3 + "\n" + NOTES.FIXED.MEMORY)
	_note("C0", "C0", "MIRROR_COATING", "observation", "observed", ["지연된 반사와 보존", "Delayed reflection and preservation"], NOTES.FIXED.C0_NOTE)
	contents.NB_MIRROR_NOTE_C0["1"].superseded_by_content_ids = ["NB_MIRROR_NOTE_C1"]
	_note("C1", "C1", "MIRROR_COATING", "hypothesis", "hypothesis", ["코팅이라는 가설", "The coating hypothesis"], NOTES.FIXED.HYPOTHESIS, ["MIRROR_COATING", "CH1_J2"])
	_note("CLEANING", "C2", "MIRROR_CLEANING_RECORD", "document", "observed", ["마라 1의 청소 기록", "Mara 1's cleaning record"], NOTES.FIXED.CLEANING)
	_note("CHEMICALS", "C2_1", "MIRROR_CHEMICAL_LABEL", "document", "observed", ["약품 라벨과 접힌 메모", "The chemical label and folded note"], NOTES.FIXED.CHEMICALS)
	_note("FORMULA", "C3", "MIRROR_FORMULA", "hypothesis", "verified", ["시험지로 검증한 세정제", "Cleaning solution verified by test strip"], NOTES.FIXED.FORMULA, ["MIRROR_CLEANING_RECORD", "MIRROR_CHEMICAL_LABEL"])
	_note("PLAN", "C4", "MIRROR_PLAN", "hypothesis", "verified", ["마른 시험으로 확인한 계획", "The dry-tested plan"], NOTES.FIXED.PLAN, ["MIRROR_COATING", "CH1_WAVEFORM"])
	contents.NB_MIRROR_NOTE_PLAN["1"].source_content_ids = ["NB_MODAL_MIRROR_ROUTE_OPTIONS"]
	_note("RAW", "C4", "MIRROR_TRACING", "observation", "observed", ["해석하지 않은 반사 원도", "The uninterpreted reflected tracing"], NOTES.FIXED.RAW, ["MIRROR_PLAN", "MIRROR_FORMULA"])
	_note("C5_INFO", "C5_INFO", "MIRROR_TRACING", "observation", "observed", ["대조한 회로와 다섯 출처", "The compared circuit and five sources"], NOTES.FIXED.RECORD + "\n" + "\n".join(SESSION.CHANNELS.values()), ["MIRROR_TRACING"])
	var scan_sources: Array = []
	for owner in SESSION.CHANNELS:
		for mode in ["SURFACE", "COPY"]: scan_sources.append("NB_MIRROR_SCAN_" + mode + "_" + owner)
	contents.NB_MIRROR_NOTE_C5_INFO["1"].source_content_ids = scan_sources
	_note("CF_RESOLVED", "C5_INFO", "MIRROR_FAILURE", "failure", "observed", ["거울 자료의 확보", "The mirror evidence is secured"], NOTES.FAILURE_RESOLVED, ["MIRROR_FAILURE", "MIRROR_TRACING"], "identified", "I recorded the mirror circuit and its five sources. The earlier records of hardened coating and confiscated tools remain.")
	_note("J3", "J3", "MIRROR_J3", "journal", "observed", ["일지 세 번째 페이지", "The third journal page"], j3, ["CH1_J2", "MIRROR_TRACING"], "unverified")
	_note("J3_MEMORY", "J3", "MIRROR_J3", "journal", "observed", ["세 번째 페이지와 문을 그리던 기억", "The third page and the memory of drawing a door"], j3 + "\n" + NOTES.FIXED.MEMORY, ["CH1_J2", "MIRROR_TRACING"], "unverified")
	if failed or contents.size() != 64:
		push_error("Incomplete mirror catalog: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_MIRROR_SEED: ", contents.size())
	quit()


func _base(id: String, event: String, kind: String, speaker: String, variant: String) -> Dictionary:
	var nodes: Array = []
	for stages in preload("res://scripts/systems/dialogue_history_context.gd").STAGES.values():
		for stage in stages:
			if stage not in nodes: nodes.append(stage)
	return {"producer_id": "NP07", "source_file": "scripts/systems/black_mirror_session.gd", "source_symbol": "act:" + id, "event_id": event,
		"node_ids": nodes, "action_or_variant": variant, "speaker_id": speaker, "location_source": "history_context:captured_before_commit",
		"entry_kind": kind, "disclosure_owner": "event_note_commit" if kind == "document_segment" else "actual_display_or_choice_press",
		"mapping_status": "AUTHORED_ID", "owner": "planning/engineering", "visible_segment_ids": [], "protection_reasons": ["knowledge" if kind == "document_segment" else "clue_source"],
		"localization_keys": {}, "variables": {}, "locales": {}}


func _feedback(id: String, event: String, ko: String, speaker: String = "SUBJECT") -> void:
	var row := _base(id, event, "dialogue", speaker, "feedback")
	var en := DISPLAY.feedback(ko, "en-US")
	var korean := ko.split("\n", false)
	var english := en.split("\n", false)
	if korean.size() != english.size() or en == ko:
		failed = true
		push_error("Missing mirror translation: " + id)
		return
	for locale in ["ko-KR", "en-US"]:
		if not COMMON.localized_text[locale].has("UI_SPEAKER_" + speaker):
			failed = true
			push_error("Missing mirror speaker source: " + speaker)
			return
		row.locales[locale] = {"title": "거울 조사: " + event if locale == "ko-KR" else "Mirror investigation: " + event,
			"summary": "그때 표시한 조사 결과" if locale == "ko-KR" else "The investigation result shown then", "speaker": COMMON.localized_text[locale]["UI_SPEAKER_" + speaker]}
	for index in range(korean.size()):
		var segment := "line_%02d" % (index + 1)
		row.visible_segment_ids.append(segment)
		row.variables[segment] = {}
		row.localization_keys[segment] = "NB_MIRROR_" + id + ":" + segment
		row.locales["ko-KR"][segment] = korean[index]
		row.locales["en-US"][segment] = english[index]
	contents["NB_MIRROR_" + id] = {"1": row}


func _note(id: String, event: String, knowledge_id: String, category: String, status: String, titles: Array, ko: String, sources: Array = [], provenance: String = "identified", english: String = "") -> void:
	var row := _base(id, event, "document_segment", "SUBJECT", "recorded")
	var en := DISPLAY.feedback(ko, "en-US") if english.is_empty() else english
	if en == ko:
		failed = true
		push_error("Missing mirror note translation: " + id)
	row.visible_segment_ids = ["body"]
	row.localization_keys = {"body": "NB_MIRROR_NOTE_" + id}
	row.variables = {"body": {}}
	row.locales = {"ko-KR": {"title": titles[0], "summary": titles[0], "speaker": "수첩", "body": ko}, "en-US": {"title": titles[1], "summary": titles[1], "speaker": "Notebook", "body": en}}
	row.knowledge = {"knowledge_id": knowledge_id, "category": category, "epistemic_state": status, "provenance_state": provenance, "lifetime": "persistent"}
	row.source_knowledge_ids = sources
	contents["NB_MIRROR_NOTE_" + id] = {"1": row}


func _failure(key: String, text: String) -> void:
	_note("CF_" + key, "C4", "MIRROR_FAILURE", "failure", "observed", ["거울의 당일 잠김", "The mirror is locked for the day"], text + "\n" + NOTES.FIXED.FAILURE_SUFFIX, ["MIRROR_FORMULA", "MIRROR_PLAN", "MIRROR_FAILURE"])
	contents["NB_MIRROR_NOTE_CF_" + key]["1"].new_attempt = true
