extends "notebook_prologue_choice_async_audit.gd"

const SHEET_MODES := ["ep01_sleep", "ep01_morning"]


func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for mode in SHEET_MODES:
            for scenario in SCENARIOS: await _choice_case(mode, scenario, locale)
            for answer in _answers(mode): await _choice_case(mode, "answer_" + answer, locale)
            await _restore_choice(mode, "choosing", locale)
            for answer in _answers(mode): await _restore_choice(mode, "selection_pending", locale, answer)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":56, "timings":timings,
        "scope":"HEADLESS actual first-sleep/first-morning options, durable selection, retries, stale owners and recreated views; not a physical reset or OS playthrough"}
    print("SHEET_CHOICE_ASYNC_AUDIT: ", JSON.stringify(result))
    print("SHEET_CHOICE_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)


func _answers(mode: String) -> Array:
    return ["same", "date", "quiet"] if mode == "ep01_morning" else ["confirm", "cancel"]


func _choice_seed(mode: String) -> Dictionary:
    var state := _fixture_state()
    var progress: Dictionary = state.loop_state.event_local_states.PROLOGUE
    progress.P4_complete = true
    progress.current_room = "M2_BEDROOM"
    progress.time_block = "evening_free" if mode == "ep01_sleep" else "morning"
    progress.intros_seen = ["P1", "P3", "P4", "P6"]
    if mode == "ep01_morning":
        progress.P6_complete = true
        state.loop_state.day_index = 1
        state.meta_progress.knowledge_entries[CURSOR.FIRST_WAKE_REQUIRED] = true
    return state


func _show_choice(view: Node, mode: String) -> void:
    if mode == "ep01_sleep": view._ep01_show_sleep_choices()
    else: view._ep01_show_morning_choices()


func _finish_case(view: Node, manager: Node, mode: String, scenario: String, locale: String, initial_errors: int) -> void:
    if scenario in ["success", "options_fail", "selected_fail", "ack"] or scenario.begins_with("answer_"):
        var answer: String = scenario.trim_prefix("answer_") if scenario.begins_with("answer_") else _answers(mode)[0]
        if mode == "ep01_sleep":
            _expect(GameState.get_value("loop_state.day_index", -1) == 0 and not view._reset_transition_pending, "selecting a sleep option cannot itself perform the physical reset")
            _expect(bool(view._progress.P6_complete) == (answer == "confirm"), "sleep progress matches the actual selected answer")
            if answer == "confirm":
                _expect(view._dialogue_active and view._dialogue_lines[0].history_context.node_id == "EP01_SLEEP_FIRST_004", "confirm starts the authored transition before reset")
            else:
                _expect(not view._dialogue_active and not view._dialogue_choice_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "decline closes and durably completes the choice")
        else:
            var first: String = {"same":"EP01_RESET_FIRST_005", "date":"EP01_RESET_FIRST_008", "quiet":"EP01_RESET_FIRST_012"}[answer]
            _expect(view._dialogue_active and view._dialogue_lines[0].history_context.node_id == first, "morning answer starts its own authored response")
            _expect(GameState.get_value("loop_state.day_index", -1) == 1 and CURSOR.first_wake_pending(GameState.get_snapshot()), "morning choice neither repeats reset nor prematurely completes the unread handoff")
    await super._finish_case(view, manager, mode, scenario, locale, initial_errors)
