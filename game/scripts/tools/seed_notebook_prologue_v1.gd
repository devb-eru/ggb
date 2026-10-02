extends SceneTree

const OUTPUT := "res://data/notebook/prologue_v1.json"
const CATALOGS := [preload("res://data/dialogue/prologue/prologue_text.tres"), preload("res://data/dialogue/system/foundation_text_catalog.tres"), preload("res://data/dialogue/chapter_one/chapter_one_text.tres")]
const GROUPS := [
	["P1", "_show_p1_intro", "SYSTEM", ["P1_WAKE_LIGHT", "P1_WAKE_KNOCK"]],
	["P1", "_show_p1_intro", "EDGAR", ["P1_WAKE_EDGAR", "P1_WAKE_TASKS"]],
	["P1", "_inspect_bedroom", "SUBJECT", ["P1_INSPECT_BED", "P1_INSPECT_WINDOW", "P1_INSPECT_PHOTO", "P1_INSPECT_NOTEBOOK"]],
	["P1", "_complete_p1", "SYSTEM", ["P1_HALL_VIEW"]],
	["P1", "_complete_p1", "EDGAR", ["P1_HALL_EDGAR"]],
	["P2", "_build_parlor", "SUBJECT", ["P2_CLOCK_OBSERVATION"]],
	["P2", "_build_parlor", "MARA1", ["P2_TOOL_INTRO", "P2_TOOL_GUIDE"]],
	["P2", "_apply_window_tool", "MARA1", ["P2_TOOL_SPANNER_LINE", "P2_TOOL_BRUSH_LINE", "P2_TOOL_BIRD_LINE"]],
	["P2", "_apply_window_tool", "SYSTEM", ["P2_TOOL_BIRD"]],
	["P2", "_complete_p2", "MARA1", ["P2_TOOL_COMPLETE_LINE"]],
	["P3", "_build_library", "EDGAR", ["P3_INTRO", "P3_RESTRICTED"]],
	["P3", "_on_shelf_pressed", "SYSTEM", ["P3_DISCOVER"]],
	["P3", "_on_shelf_pressed/_resume_p3_journal_choice", "EDGAR", ["P3_LEDGER"]],
	["P3", "_answer_p3_journal_choice", "EDGAR", ["P3_A_AUTHOR", "P3_A_LOCKED"]],
	["P3", "_resume_p3_journal_choice", "SYSTEM", ["P3_RESUME"]],
	["P3", "_finish_p3_book_placement", "EDGAR", ["P3_COMPLETE"]],
	["P3", "_inspect_inner_door", "SUBJECT", ["P3_DOOR"]],
	["P3B", "_build_archive", "MARA2", ["P3B_INTRO", "P3B_HINT"]],
	["P3B", "_on_portrait_pressed", "MARA2", ["P3B_WRONG", "P3B_COMPLETE", "P3B_NAME"]],
	["P3B", "_on_portrait_pressed", "SYSTEM", ["P3B_PATTERNS"]],
	["P4", "_build_kitchen", "LUCA", ["P4_LINK_INTRO", "P4_LINK_GUIDE"]],
	["P4", "_resume_p4_life_support_foreshadow", "SYSTEM", ["P4_MEMORY_PULSE", "P4_MEMORY_EARS", "P4_MEMORY_REPLY"]],
	["P4", "_resume_p4_memory_anchor", "SYSTEM", ["P4_MEMORY_GROOVE", "P4_MEMORY_SCRAPE", "P4_MEMORY_HAND", "P4_MEMORY_ABSENCE", "P4_MEMORY_PAUSE"]],
	["P4", "_resume_p4_memory_anchor", "SUBJECT", ["P4_MEMORY_WHY"]],
	["P4", "_resume_p4_memory_anchor", "LUCA", ["P4_MEMORY_HABIT"]],
	["P4", "_turn_p4_cup_handle", "SUBJECT", ["P4_MEMORY_ALREADY"]],
	["P4", "_turn_p4_cup_handle", "SYSTEM", ["P4_MEMORY_TURN", "P4_MEMORY_RETURN"]],
	["P4", "_present_p4_question_answer", "LUCA", ["P4_A_FATHER_TEA", "P4_A_MANSION_AGE", "P4_A_LUCA_TENURE", "P4_SERVE"]],
	["P4", "_present_p4_question_answer", "SYSTEM", ["P4_TENURE_PAUSE"]],
	["P4_IRIS_GREETING", "_show_p4_iris_greeting", "IRIS", ["P4_LINK_IRIS_HELLO", "P4_LINK_IRIS_INVITE"]],
	["P5", "_build_greenhouse", "IRIS", ["P5_HELLO", "P5_OUTSIDE"]],
	["P5", "_observe_weather", "SUBJECT", ["P5_CORRIDOR", "P5_GLASS", "P5_THRESHOLD"]],
	["P5", "_complete_p5", "SUBJECT", ["P5_QUESTION"]],
	["P5", "_complete_p5", "IRIS", ["P5_ANSWER"]],
	["P6", "_build_bedroom", "EDGAR", ["P6_NIGHT_EDGAR_DONE", "P6_NIGHT_EDGAR_REST"]],
	["P6", "_begin_first_sleep", "SYSTEM", ["P6_DARK", "P6_SOUND"]],
	["R1", "_show_after_reset", "SYSTEM", ["R1_WAKE", "R1_NOTES"]],
	["R1", "_show_after_reset", "SUBJECT", ["R1_SAME"]],
	["PF", "_build_hall/_evening_ambient", "SUBJECT", ["PF_LIGHT", "PF_PAGES"]],
]
const TITLES := {"P1": ["아침 인사", "Morning greetings"], "PG": ["남은 일과", "Remaining duties"], "P2": ["창가에서", "At the windows"], "P3": ["외부 서고에서", "In the outer library"], "P3B": ["초상화 곁에서", "Beside the portraits"], "P4": ["차를 준비하며", "Preparing tea"], "P4_IRIS_GREETING": ["이리스의 인사", "Iris's greeting"], "P5": ["온실 앞에서", "Outside the greenhouse"], "P6": ["잠들기 전에", "Before sleep"], "R1": ["다시 온 아침", "Morning again"], "PF": ["저녁 조사", "Evening observations"]}
const PROTECTED := ["P1_INSPECT_NOTEBOOK", "P1_INSPECT_PHOTO", "P2_CLOCK_OBSERVATION", "P2_TOOL_BIRD", "P3_DISCOVER", "P3_LEDGER", "P3_A_AUTHOR", "P3_A_LOCKED", "P3B_PATTERNS", "P3B_NAME", "P4_MEMORY_PULSE", "P4_MEMORY_EARS", "P4_MEMORY_REPLY", "P4_MEMORY_GROOVE", "P4_MEMORY_SCRAPE", "P4_MEMORY_HAND", "P4_MEMORY_ABSENCE", "P4_MEMORY_WHY", "P4_MEMORY_PAUSE", "P4_MEMORY_HABIT", "P4_MEMORY_TURN", "P4_MEMORY_RETURN", "P4_A_FATHER_TEA", "P4_A_MANSION_AGE", "P4_A_LUCA_TENURE", "P4_TENURE_PAUSE", "P5_CORRIDOR", "P5_GLASS", "P5_THRESHOLD", "P5_QUESTION", "P5_ANSWER", "P6_SOUND", "R1_SAME", "R1_NOTES", "PF_LIGHT", "PF_PAGES"]
var contents := {}


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-source-project="):
			var project := argument.trim_prefix("--verify-source-project=")
			for catalog in CATALOGS:
				var external := ResourceLoader.load(project.path_join(catalog.resource_path.trim_prefix("res://")), "", ResourceLoader.CACHE_MODE_IGNORE)
				if external == null or external.localized_text != catalog.localized_text:
					push_error("Source text differs: " + catalog.resource_path)
					quit(1)
					return
	for group in GROUPS:
		for text_id in group[3]:
			var row := _base(group[0], group[1], group[2], "NP01", "dialogue", "spoken")
			row.source_text_id = text_id
			row.text_source = _source(text_id)
			if text_id in PROTECTED: row.protection_reasons = ["clue_source"]
			_body(row, text_id)
			contents["NB_PR_" + text_id] = {"1": row}
	for mask in range(1, 8):
		var row := _base("PG", "_report_tasks", "EDGAR", "NP01", "dialogue", "spoken")
		row.source_text_id = "UI_DUTY_REMAINING"
		row.text_source = _source(row.source_text_id)
		_body(row, row.source_text_id)
		for locale in row.locales:
			var labels := PackedStringArray()
			for index in range(3):
				if mask & (1 << index): labels.append(_text(["UI_DUTY_PARLOR", "UI_DUTY_LIBRARY", "UI_DUTY_ARCHIVE"][index], locale))
			row.locales[locale].body = row.locales[locale].body.replace("{tasks}", ", ".join(labels))
		contents["NB_PR_DUTY_%d" % mask] = {"1": row}
	var night := _base("P6", "_inspect_bedroom", "SUBJECT", "NP01", "dialogue", "spoken")
	night.source_text_id = "P1_INSPECT_WINDOW"
	night.text_source = _source(night.source_text_id)
	_body(night, night.source_text_id)
	contents["NB_PR_P6_INSPECT_WINDOW"] = {"1": night}
	for event in ["P3", "P4"]:
		var choices: Array = ["author", "locked", "silent"] if event == "P3" else ["father_tea", "mansion_age", "luca_tenure"]
		var row := _base(event, "_show_dialogue_choice_set/_record_choice_history", "SYSTEM", "NP02", "options_presented", "shown")
		row.protection_reasons = ["choice_context"]
		row.visible_segment_ids = ["header", "prompt"] + choices
		row.localization_keys = {"header": event + "_HEADER", "prompt": event + "_PROMPT"}
		row.variables = {"header": {}, "prompt": {}}
		for choice in choices:
			row.localization_keys[choice] = event + "_Q_" + choice.to_upper()
			row.variables[choice] = {}
		for locale in row.locales:
			row.locales[locale].speaker = _text("HISTORY_OPTIONS", locale)
			for segment in row.visible_segment_ids: row.locales[locale][segment] = _text(row.localization_keys[segment], locale)
		contents["NB_PR_" + event + "_OPTIONS"] = {"1": row}
		for choice in choices:
			var chosen := _base(event, "_on_dialogue_choice_pressed", "SUBJECT", "NP02", "choice_confirmed", "selected_" + choice)
			chosen.protection_reasons = ["choice"]
			_body(chosen, event + "_Q_" + choice.to_upper())
			for locale in chosen.locales: chosen.locales[locale].speaker = _text("HISTORY_SELECTED", locale)
			contents["NB_PR_" + event + "_SELECT_" + choice.to_upper()] = {"1": chosen}
	for spec in [["P1", "P1_EXIT", "_leave_bedroom_morning", "P1_EXIT_TITLE", "P1_EXIT_CONFIRM", "P1_EXIT_START", "P1_EXIT_STAY"], ["P6", "P6_SLEEP", "_on_sleep_bed", "P6_TITLE", "P6_BODY", "P6_SLEEP", "P6_CANCEL"]]:
		var row := _base(spec[0], spec[2], "SYSTEM", "NP02", "options_presented", "shown")
		row.protection_reasons = ["choice_context"]
		row.visible_segment_ids = ["header", "prompt", "confirm", "cancel"]
		for index in range(4):
			var segment: String = row.visible_segment_ids[index]
			row.localization_keys[segment] = spec[index + 3]
			row.variables[segment] = {}
			for locale in row.locales: row.locales[locale][segment] = _text(spec[index + 3], locale)
		for locale in row.locales: row.locales[locale].speaker = _text("HISTORY_OPTIONS", locale)
		contents["NB_PR_" + spec[1] + "_OPTIONS"] = {"1": row}
		for choice in ["confirm", "cancel"]:
			var kind := "choice_confirmed" if choice == "confirm" else "choice_cancelled"
			var selected := _base(spec[0], spec[2] + "/_prologue_confirmation_pressed", "SUBJECT", "NP02", kind, choice)
			selected.protection_reasons = ["choice"]
			_body(selected, spec[5] if choice == "confirm" else spec[6])
			for locale in selected.locales: selected.locales[locale].speaker = _text("HISTORY_SELECTED", locale)
			contents["NB_PR_" + spec[1] + "_" + choice.to_upper()] = {"1": selected}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_PROLOGUE_SEED: ", contents.size())
	quit()


func _base(event: String, callsite: String, speaker: String, producer: String, kind: String, variant: String) -> Dictionary:
	var localized := {}
	for index in range(2):
		var locale: String = ["ko-KR", "en-US"][index]
		localized[locale] = {"title": TITLES[event][index], "summary": "당시 확인한 말과 감각" if index == 0 else "Words and impressions observed then", "speaker": _text("UI_SPEAKER_" + ("LUKA" if speaker == "LUCA" else speaker), locale)}
	return {"producer_id": producer, "source_file": "scripts/prologue/prologue_controller.gd", "source_symbol": callsite, "event_id": event, "node_ids": [event], "action_or_variant": variant, "speaker_id": speaker, "location_source": "_current_room:captured_before_display", "entry_kind": kind, "disclosure_owner": "actual_display_or_choice_press", "visible_segment_ids": ["body"], "knowledge_ref": "", "protection_reasons": [], "mapping_status": "AUTHORED_ID", "owner": "development/content", "localization_keys": {}, "variables": {}, "locales": localized}


func _body(row: Dictionary, text_id: String) -> void:
	row.localization_keys = {"body": text_id}
	row.variables = {"body": {}}
	for locale in row.locales: row.locales[locale].body = _text(text_id, locale)


func _source(id: String) -> String:
	for catalog in CATALOGS:
		if catalog.localized_text["ko-KR"].has(id): return catalog.resource_path
	push_error("Missing source ID " + id)
	return ""


func _text(id: String, locale: String) -> String:
	for catalog in CATALOGS:
		if catalog.localized_text[locale].has(id): return catalog.localized_text[locale][id]
	push_error("Missing text " + id)
	return ""
