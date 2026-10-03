extends SceneTree

const NOTES := preload("res://scripts/systems/final_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const FATHER := preload("res://scripts/systems/father_final_record.gd")
const CONFRONTATION := preload("res://scripts/systems/researcher_confrontation.gd")
const INSPECTION := preload("res://scripts/systems/final_inspection.gd")
const DECISION := preload("res://scripts/systems/ending_decision.gd")
const DISPLAY := preload("res://scripts/ui/core_story_texts.gd")
const ENDING := preload("res://scripts/ui/ending_decision_texts.gd")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
const PROLOGUE := preload("res://data/dialogue/prologue/prologue_text.tres")
var failed := false
var contents := {}


func _initialize() -> void:
	var path := "res://data/notebook/final_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for pair in [["enter", null], ["inspect", null], ["authenticate", "sentence"], ["page", null], ["write", "subject"]]:
		_result(FATHER.apply(_state(), pair[0], pair[1]))
	for index in range(8):
		_result(FATHER.apply(_state(), "play", index))
		for prefix in ["play", "replay"]:
			_add("F1_TITLE_%s_%d" % [prefix.to_upper(), index], DISPLAY.UI[prefix][0] + FATHER.TITLES[index], DISPLAY.UI[prefix][1] + DISPLAY.FATHER_TITLES_EN[index], "document_segment")
	var written := FATHER.apply(_state(), "write", "subject")
	var original: String = written.state.meta_progress.knowledge_entries.chapter_notebook.J5
	_add("J5_RECORD", original, DISPLAY.feedback(original, "en-US"), "document_segment")
	var row: Dictionary = contents[NOTES.PREFIX + "J5_RECORD"]["1"]
	row.disclosure_owner = "event_note_commit"
	row.knowledge = {"knowledge_id":"J5", "category":"document", "epistemic_state":"observed", "provenance_state":"identified", "lifetime":"persistent"}
	row.source_knowledge_ids = ["J1", "J2", "J3", "J4", "F0_CURRENT_AUTHOR"]
	row.source_content_ids = [NOTES.PREFIX + "F1_INSPECT", NOTES.PREFIX + "F1_AUTHENTICATE", NOTES.PREFIX + "J5_PAGE"]
	for index in range(8): row.source_content_ids.append(NOTES.PREFIX + "F1_PLAY_%d" % index)
	row.protection_reasons = ["knowledge"]
	for locale in row.locales: row.locales[locale].speaker = "수첩" if locale == "ko-KR" else "Notebook"
	for mode in ["public", "direct_private", "indirect", "denied", "withheld", "inferred_only"]:
		var state := _state()
		state.meta_progress.journal_stage = 5
		state.meta_progress.knowledge_entries.F2_complete = false
		state.loop_state.event_local_states.F2 = {}
		var iris: Dictionary = state.meta_progress.servants.iris
		iris.core_event_complete = mode != "inferred_only"
		iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		iris.alert = 4 if mode == "denied" else 0
		if mode == "public":
			for servant in state.meta_progress.servants.values(): servant.core_event_complete = true
		_result(CONFRONTATION.apply(state, "enter", null))
	for fact in CONFRONTATION.FACTS:
		_add("F2_FACT_" + String(fact).trim_prefix("KN_F2_"), CONFRONTATION.FACTS[fact], DISPLAY.FACTS_EN[fact])
	for action in ["recap", "finish"]:
		var state := _state()
		state.meta_progress.journal_stage = 5
		state.meta_progress.knowledge_entries.F2_complete = false
		_result(CONFRONTATION.apply(state, action, null))
	_choices()
	for pair in [["enter", null], ["inspect", "wake"], ["inspect", "stay"], ["open", null], ["cancel", null]]:
		_result(INSPECTION.apply(_state(), pair[0], pair[1]))
	for intent in ["reality", "stay", "undecided"]:
		var state := _state()
		state.meta_progress.knowledge_entries.f0_provisional_intent = intent
		_result(INSPECTION.apply(state, "inspect", "notebook"))
	for last in ["wake", "stay"]:
		var state := _state()
		state.loop_state.event_local_states.F3.last_device = last
		_result(INSPECTION.apply(state, "summary", null))
	for relation in DECISION.MONOLOGUES:
		_add("EDC_" + String(relation).to_upper(), DECISION.MONOLOGUES[relation], ENDING.feedback(DECISION.MONOLOGUES[relation], "en-US"))
	for label in ["notice", "reality", "stay"]:
		_add("EDC_SCREEN_" + label.to_upper(), ENDING.LABELS[label][0], ENDING.LABELS[label][1], "document_segment")
	var count := 0
	for id in contents:
		var spec: Dictionary = contents[id]["1"]
		if not CONTENT._valid_row(spec):
			failed = true
			push_error("Invalid final row: " + id)
		for segment in spec.visible_segment_ids:
			if RegEx.create_from_string("[가-힣]").search(spec.locales["en-US"][segment]) != null:
				failed = true
				push_error("Untranslated final row: " + id + ":" + segment)
		count += spec.visible_segment_ids.size()
	if failed:
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1, "contents":contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_FINAL_SEED: %d IDs / %d segments" % [contents.size(), count])
	quit()


func _state() -> Dictionary:
	var servants := {}
	for owner in ["edgar", "mara1", "iris", "luca", "mara2"]:
		servants[owner] = {"core_event_complete":false, "bond":0, "alert":0}
	return {"meta_progress":{"journal_stage":4, "event_history":{}, "servants":servants,
		"knowledge_entries":{"F0_E_complete":true, "subject_authority_restored":true, "self_authored_mark":{"type":"sentence"}, "father_final_record_played":true, "F2_complete":true}},
		"loop_state":{"location_id":"H0_CORE_RECORDS", "event_local_states":{
			"F1":{"entered":true, "authenticated":true, "next":8, "j5_read":true},
			"F2":{"entered":true, "facts":CONFRONTATION.FACTS.keys(), "recapped":true},
			"F3":{"entered":true, "seen":["wake", "stay", "notebook"], "summary_seen":true}}},
		"fracture_state":{}, "ending_run":{"final_decision":"unset"}}


func _result(result: Dictionary) -> void:
	if not result.ok or result.notebook_keys.size() != 1:
		failed = true
		push_error("Invalid final seed result: " + str(result))
		return
	_add(result.notebook_keys[0], result.text, ENDING.feedback(DISPLAY.feedback(result.text, "en-US"), "en-US"))


func _add(key: String, ko: String, en: String, kind: String = "dialogue") -> void:
	var row := _base(key, kind)
	var left := ko.split("\n", false) if kind == "dialogue" else PackedStringArray([ko])
	var right := en.split("\n", false) if kind == "dialogue" else PackedStringArray([en])
	if left.size() != right.size():
		failed = true
		push_error("Final paragraph mismatch: " + key)
		return
	for index in range(left.size()):
		_segment(row, "line_%02d" % (index + 1) if kind == "dialogue" else "body", left[index], right[index])
	contents[NOTES.PREFIX + key] = {"1":row}


func _choices() -> void:
	var options := _base("F2_OPTIONS", "options_presented")
	options.protection_reasons = ["choice_context"]
	for locale in options.locales: options.locales[locale].speaker = _common("HISTORY_OPTIONS", locale)
	for index in range(NOTES.QUESTIONS.size()):
		var question: String = NOTES.QUESTIONS[index]
		var ko: String = CONFRONTATION.QUESTIONS[question]
		var en: String = DISPLAY.QUESTIONS_EN[question]
		_segment(options, "option_%d" % index, ko, en)
		var key := "F2_SELECT_%d" % index
		_add(key, ko, en, "choice_confirmed")
		var selected: Dictionary = contents[NOTES.PREFIX + key]["1"]
		selected.protection_reasons = ["choice"]
		for locale in selected.locales: selected.locales[locale].speaker = _common("HISTORY_SELECTED", locale)
	contents[NOTES.PREFIX + "F2_OPTIONS"] = {"1":options}


func _base(key: String, kind: String) -> Dictionary:
	var event: String = key.split("_")[0]
	var node: String = "F1" if event == "J5" else event
	var row := {"producer_id":"NP17", "source_file":"scripts/chapters/basement_controller.gd", "source_symbol":key,
		"event_id":event, "node_ids":[node], "action_or_variant":key, "speaker_id":"SUBJECT" if kind == "dialogue" else "SYSTEM",
		"location_source":"captured_before_commit_or_actual_display", "entry_kind":kind, "disclosure_owner":"actual_display",
		"mapping_status":"AUTHORED_ID", "owner":"planning/engineering", "visible_segment_ids":[], "variables":{}, "localization_keys":{},
		"protection_reasons":["clue_source"], "locales":{"ko-KR":{"speaker":"", "title":"마지막 기록과 확인", "summary":"당시에 공개된 원문과 응답"},
		"en-US":{"speaker":"", "title":"Final Records and Review", "summary":"The original text and responses disclosed at that time"}}}
	if key == "F3_CANCEL": row.node_ids = ["F3", "EDC"]
	if key.begins_with("EDC_") and not key.begins_with("EDC_SCREEN_"): row.protection_reasons = ["choice"]
	for locale in row.locales:
		row.locales[locale].speaker = _common("UI_SPEAKER_SUBJECT", locale) if kind == "dialogue" else "장면" if locale == "ko-KR" else "Scene"
	return row


func _segment(row: Dictionary, id: String, ko: String, en: String) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = ko
	row.locales["en-US"][id] = en


func _common(id: String, locale: String) -> String:
	for resource in [PROLOGUE, CH1, SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
