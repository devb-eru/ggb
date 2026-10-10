extends "notebook_prologue_async_audit.gd"

const MODES := ["p3_journal", "p4_father", "P1_EXIT", "P6_SLEEP"]
const SCENARIOS := ["success", "options_fail", "selected_fail", "ack", "options_replace", "selected_replace", "selected_locale", "selected_context"]

class RejectOptions extends "res://scripts/autoload/save_manager.gd":
    func _promote_temporary(paths: Dictionary) -> Error:
        var prepared := _read_and_validate(paths.temporary)
        if prepared.ok and preload("res://scripts/systems/notebook_presentation.gd").read(prepared.snapshot).get("phase") == "choosing": return ERR_CANT_CREATE
        return super._promote_temporary(paths)

class RejectSelection extends "res://scripts/autoload/save_manager.gd":
    func _promote_temporary(paths: Dictionary) -> Error:
        var prepared := _read_and_validate(paths.temporary)
        if prepared.ok and preload("res://scripts/systems/notebook_presentation.gd").read(prepared.snapshot).get("phase") == "selection_pending": return ERR_CANT_CREATE
        return super._promote_temporary(paths)

class ObservedView extends "res://scripts/prologue/prologue_controller.gd":
    var selection_actions: Array = []
    var defer_selected_action := false
    func _run_prologue_action(action: Callable) -> void:
        var cursor := preload("res://scripts/systems/notebook_presentation.gd").read(GameState.get_snapshot())
        if cursor.get("phase") == "selection_pending":
            var disk := SaveManager.load_slot(_slot_id)
            selection_actions.append({"method":String(action.get_method()), "selected":cursor.choice.last_selected,
                "durable":disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot())})
            if defer_selected_action: return
        super._run_prologue_action(action)

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in ["basic", "window", "combined", "stale_note", "malformed"]: await _candidate_case(scenario, locale)
        for scenario in ["success", "promotion", "ack", "replace", "locale", "service", "progress_changed", "pending_note_changed", "handoff", "after_action", "after_action_failure"]: await _prologue_ui(scenario, locale)
        for mode in MODES:
            for scenario in SCENARIOS: await _choice_case(mode, scenario, locale)
            for answer in _answers(mode): await _choice_case(mode, "answer_" + answer, locale)
            for phase in ["choosing", "selection_pending"]: await _restore_choice(mode, phase, locale)
        for fixture in FIXTURES.IDS: await _prologue_large(fixture, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":140, "timings":timings,
        "scope":"HEADLESS actual choice/modal callbacks, durable ordering and recreated controllers; not OS input, separate-process async restart or p95"}
    print("PROLOGUE_CHOICE_ASYNC_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_CHOICE_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _answers(mode: String) -> Array:
    if mode == "p3_journal": return ["author", "locked", "silent"]
    if mode == "p4_father": return ["father_tea", "mansion_age", "luca_tenure"]
    return ["confirm", "cancel"]

func _choice_seed(mode: String) -> Dictionary:
    var state := _fixture_state()
    var progress: Dictionary = state.loop_state.event_local_states.PROLOGUE
    progress.intros_seen = ["P1", "P3", "P4", "P6"]
    if mode == "p3_journal":
        progress.current_room = "M1_LIBRARY_OUTER"
        progress.p3_journal_seen = true
        progress.p3_journal_choice = "pending"
    if mode == "p4_father":
        progress.current_room = "M1_KITCHEN"
        progress.tea_step = 6
        progress.p4_memory_anchor_seen = true
        progress.p4_phase = "question"
    if mode == "P6_SLEEP":
        progress.P4_complete = true
        progress.time_block = "evening_free"
    state.loop_state.location_id = progress.current_room
    return state

func _make_choice_view() -> Node:
    var view := ObservedView.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    return view

func _show_choice(view: Node, mode: String) -> void:
    if mode == "p3_journal": view._show_p3_journal_choices()
    elif mode == "p4_father": view._show_p4_father_choices()
    elif mode == "P1_EXIT": view._leave_bedroom_morning()
    else: view._on_sleep_bed()

func _buttons(view: Node, mode: String) -> Array:
    if mode.begins_with("p"): return view._dialogue_choice_buttons
    return view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)

func _press(view: Node, mode: String, answer: String) -> void:
    var buttons := _buttons(view, mode)
    var order: Array = _answers(mode)
    buttons[order.find(answer)].pressed.emit()

func _options_token(view: Node, mode: String) -> String:
    return view._choice_history_context.presentation_token if mode.begins_with("p") else view._prologue_confirmation.context.presentation_token

func _selected_token(view: Node, mode: String, answer: String) -> String:
    var tokens: Dictionary = view._choice_selected_tokens if mode.begins_with("p") else view._prologue_confirmation.tokens
    return tokens.get(answer, "")

func _token_count(token: String) -> int:
    return GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("presentation_token") == token).size()

func _pending_controls(view: Node, mode: String) -> void:
    _expect(not view._prologue_async_request.is_empty() and not view._notebook_open_block_reason().is_empty(), "choice/modal pending and notebook barrier " + mode)
    for button in _buttons(view, mode): _expect(button.disabled, "pending disables actual option control " + mode)

func _replace_context(view: Node, mode: String) -> void:
    if mode.begins_with("p"): view._choice_history_context.presentation_token = ARCHIVE.new_uid()
    else: view._prologue_confirmation.context.presentation_token = ARCHIVE.new_uid()

func _choice_case(mode: String, scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    _seed(_choice_seed(mode))
    var view = _make_choice_view()
    var manager: Node = SaveManager
    if scenario == "options_fail": manager = RejectOptions.new()
    elif scenario == "selected_fail": manager = RejectSelection.new()
    elif scenario == "ack": manager = LostAcknowledgement.new()
    if manager != SaveManager: add_child(manager)
    view._prologue_surface_saves = manager
    view._queue_notebook_observation("NOTE_P_DUTIES")
    _show_choice(view, mode)
    var options_token := _options_token(view, mode)
    var before_options := GameState.get_snapshot()
    var revision: int = GameState.revision
    _pending_controls(view, mode)
    var answer: String = scenario.trim_prefix("answer_") if scenario.begins_with("answer_") else _answers(mode)[0]
    _press(view, mode, answer)
    _expect(view.selection_actions.is_empty() and GameState.revision == revision, "pending options cannot select " + mode)
    if scenario == "options_replace": _replace_context(view, mode)
    await _prologue_settle(view)
    if scenario in ["options_fail", "options_replace"]:
        _expect(view.selection_actions.is_empty() and StateSnapshotValidator.same_persisted_value(before_options, GameState.get_snapshot()), "rejected options preserve all live fields " + mode)
        _expect(not view._pending_notebook.is_empty() and _token_count(options_token) == 0, "rejected options retain pending note and never append " + mode)
        if scenario == "options_replace":
            await _finish_case(view, manager, mode, scenario, locale, initial_errors)
            return
        view._prologue_surface_saves = SaveManager
        _press(view, mode, answer)
        await _prologue_settle(view)
        _expect(view.selection_actions.is_empty(), "explicit options retry does not replay queued choice " + mode)
    _expect(view._pending_notebook.is_empty() and _token_count(options_token) == 1, "options and note durable exactly once " + mode)
    _expect(CURSOR.read(GameState.get_snapshot()).phase == "choosing", "options cursor is choosing " + mode)
    _press(view, mode, answer)
    var selected_token := _selected_token(view, mode, answer)
    var before_selected := GameState.get_snapshot()
    revision = GameState.revision
    _pending_controls(view, mode)
    _press(view, mode, answer)
    _expect(view.selection_actions.is_empty() and GameState.revision == revision, "pending selection cannot execute or duplicate " + mode)
    if scenario == "selected_replace":
        if mode.begins_with("p"): view._dialogue_choice_mode = "replaced"
        else: view._show_modal("Replacement", "Administrative screen", [])
    elif scenario == "selected_locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
    elif scenario == "selected_context": _replace_context(view, mode)
    await _prologue_settle(view)
    if scenario in ["selected_replace", "selected_locale", "selected_context", "selected_fail"]:
        _expect(view.selection_actions.is_empty() and StateSnapshotValidator.same_persisted_value(before_selected, GameState.get_snapshot()), "rejected selected result cannot act or install " + mode)
        _expect(_token_count(selected_token) == 0 and _token_count(options_token) == 1, "selection rejection preserves original options " + mode)
        if scenario != "selected_fail":
            await _finish_case(view, manager, mode, scenario, locale, initial_errors)
            return
        view._prologue_surface_saves = SaveManager
        _press(view, mode, answer)
        _expect(_selected_token(view, mode, answer) == selected_token, "selection retry reuses exact token " + mode)
        await _prologue_settle(view)
    _expect(view.selection_actions.size() == 1 and view.selection_actions[0].selected == answer and view.selection_actions[0].durable, "selected action follows durable snapshot once " + mode + ":" + answer)
    _expect(_token_count(options_token) == 1 and _token_count(selected_token) == 1, "options and selected text remain unique " + mode)
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "response/progress commit disk/live exact " + mode)
    if mode == "p3_journal" and answer != "silent": _expect(answer in view._progress.p3_journal_questions_asked, "actual journal answer applied")
    if mode == "p4_father": _expect(view._progress.p4_father_question == answer and view._dialogue_active, "actual father answer applied")
    if not mode.begins_with("p") and answer == "cancel": _expect(not view._modal_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "cancel is durable completed choice")
    await _finish_case(view, manager, mode, scenario, locale, initial_errors)

func _finish_case(view: Node, manager: Node, mode: String, scenario: String, locale: String, initial_errors: int) -> void:
    TranslationServer.set_locale(locale)
    cases.append({"kind":"choice", "mode":mode, "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    SaveManager.delete_test_slot(SLOT)

func _restore_choice(mode: String, phase: String, locale: String) -> void:
    var initial_errors := errors.size()
    _seed(_choice_seed(mode))
    var view = _make_choice_view()
    _show_choice(view, mode)
    await _prologue_settle(view)
    var options_token := _options_token(view, mode)
    var answer: String = _answers(mode)[0]
    var selected_token := ""
    if phase == "selection_pending":
        view.defer_selected_action = true
        _press(view, mode, answer)
        selected_token = _selected_token(view, mode, answer)
        await _prologue_settle(view)
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and CURSOR.read(disk.snapshot).phase == phase, "recreate boundary has real durable choice " + mode)
    var frozen := disk.snapshot.duplicate(true)
    view.queue_free()
    await get_tree().process_frame
    _expect(StateWriter.new(GameState).install_snapshot(frozen, GameState.revision, &"LOAD_CHOICE_RESTORE").ok, "recreated controller load")
    var restored = _make_choice_view()
    await _prologue_settle(restored)
    _expect(restored.selection_actions.is_empty() and restored._prologue_async_request.is_empty(), "restore does not execute pending selection " + mode)
    _expect(_token_count(options_token) == 1 and StateSnapshotValidator.same_persisted_value(frozen, GameState.get_snapshot()), "restore is read-only and preserves options " + mode)
    _press(restored, mode, answer)
    if phase == "selection_pending": _expect(_selected_token(restored, mode, answer) == selected_token, "restored pending answer reuses durable token " + mode)
    await _prologue_settle(restored)
    _expect(restored.selection_actions.size() == 1 and restored.selection_actions[0].durable, "explicit restored action runs once after durability " + mode)
    _expect(_token_count(options_token) == 1, "restore never re-appends options " + mode)
    if phase == "selection_pending": _expect(_token_count(selected_token) == 1, "restore never re-appends selected token " + mode)
    cases.append({"kind":"restore", "mode":mode, "phase":phase, "locale":locale, "passed":initial_errors == errors.size()})
    restored.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
