extends Control

const SCRIPT := preload("res://scripts/systems/ep01_script.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const PROLOGUE := preload("res://scenes/prologue/prologue.tscn")
var _reset_owner_generation := 0
var _reset_coordinator: ResetCoordinator
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _ready() -> void:
	_reset_coordinator = ResetCoordinator.new(GameState, SaveManager)
	call_deferred("run")

func run() -> void:
	for mode in ["P3", "P4", "EP01_SLEEP", "EP01_MORNING"]:
		var id: String = "NB_PR_" + mode + "_OPTIONS"
		for version in range(1, SCRIPT.notebook_version(id) + 1):
			var row := CONTENT.definition(id, version)
			check(not row.is_empty(), "known choice definition exists: " + id)
			if row.is_empty(): continue
			var segments := {}
			for segment in row.visible_segment_ids: segments[segment] = {}
			var options := CONTENT.descriptor(id, version, segments)
			for segment in row.visible_segment_ids:
				if segment in ["header", "prompt"]: continue
				var selected := CONTENT.choice_for_options("NB_PR_" + mode + "_SELECT_" + String(segment).to_upper(), options, segment)
				check(not selected.is_empty(), "compatible selected version exists: " + id + ":" + segment)
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await old_choice("author", 0)
		await old_choice("locked", 1)
	for failure in failures: printerr(failure)
	print("LEGACY_CHOICE_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func old_choice(choice: String, index: int) -> void:
	var locale := "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	var slot := "__test_sheet_legacy_choice_" + choice + "_" + locale.replace("-", "_")
	SaveManager.delete_test_slot(slot)
	GameState.reset_for_test()
	var view := PROLOGUE.instantiate()
	view.configure_session(slot, "P1_ENTRY", false)
	add_child(view)
	await get_tree().process_frame
	view._dismiss_dialogue_for_test()
	view._progress.P1_complete = true
	view._mark_intro("P3")
	view._enter_room("M1_LIBRARY_OUTER")
	view._dismiss_dialogue_for_test()
	await get_tree().process_frame
	view._progress.p3_journal_seen = true
	view._progress.p3_journal_choice = "pending"
	view._save_progress()
	var old: Dictionary = CONTENT.definition("NB_PR_P3_OPTIONS", 1).locales[locale]
	var data := {}
	for id in ["author", "locked", "silent"]: data[id] = {"label": old[id]}
	var bindings: Dictionary = SCRIPT.source().notebook_versions
	var current: int = bindings.NB_PR_P3_OPTIONS
	bindings.NB_PR_P3_OPTIONS = 1
	view._show_dialogue_choice_set("p3_journal", old.header, "주인공", old.prompt, "EDGAR", ["author", "locked", "silent"], data)
	check(view._choice_history_recorded, "version-one options were recorded: " + choice)
	var cursor := preload("res://scripts/systems/notebook_presentation.gd").read(GameState.get_snapshot())
	check(cursor.get("kind") == "choice" and cursor.get("lines", [{}])[0].get("notebook_content", {}).get("content_version") == 1, "fixture saves an actual version-one choice cursor")
	bindings.NB_PR_P3_OPTIONS = current
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(GameState, SaveManager).load_and_install(slot).get("ok", false), "legacy prompt reload: " + choice)
	view = PROLOGUE.instantiate()
	view.configure_session(slot, "P1_ENTRY", false)
	add_child(view)
	await get_tree().process_frame
	print("LEGACY_RESTORE ", choice, " mode=", view._dialogue_choice_mode, " label=", view._dialogue_choice_buttons[index].get_meta("choice_label", ""), " status=", view._status_label.text)
	check(view._dialogue_choice_active and view._dialogue_choice_buttons[index].get_meta("choice_label", "") == old[choice], "restored prompt preserves old visible label: " + choice)
	view._on_dialogue_choice_pressed(index)
	check(view._dialogue_active, "old visible choice enters its response: " + choice)
	var id := "NB_PR_P3_SELECT_" + choice.to_upper()
	var answers: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == id)
	check(answers.size() == 1, "old choice records one selected answer: " + choice)
	if answers.size() == 1:
		check(answers[0].observation.content_version == 1 and answers[0].observation.segments[0].captured_text == old[choice], "selected answer belongs to the observed old version: " + choice)
	check(SCRIPT.notebook_version("NB_PR_P3_OPTIONS") == current, "test does not downgrade current bindings")
	view.queue_free()
	await get_tree().process_frame
	SaveManager.delete_test_slot(slot)
