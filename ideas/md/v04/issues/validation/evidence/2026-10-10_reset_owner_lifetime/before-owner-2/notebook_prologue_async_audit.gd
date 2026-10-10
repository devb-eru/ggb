extends "notebook_history_async_audit.gd"

const PROLOGUE := preload("res://scripts/prologue/prologue_controller.gd")
const CANDIDATE := preload("res://scripts/systems/prologue_save_candidate.gd")
var handoffs := 0

class RejectCompleted extends "res://scripts/autoload/save_manager.gd":
    func _promote_temporary(paths: Dictionary) -> Error:
        var prepared := _read_and_validate(paths.temporary)
        if prepared.ok and CURSOR.read(prepared.snapshot).get("phase") == "completed": return ERR_CANT_CREATE
        return super._promote_temporary(paths)

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in ["basic", "window", "combined", "stale_note", "malformed", "choice"]: await _candidate_case(scenario, locale)
        for scenario in ["success", "promotion", "ack", "replace", "locale", "service", "progress_changed", "pending_note_changed", "handoff", "after_action", "after_action_failure"]: await _prologue_ui(scenario, locale)
        for fixture in FIXTURES.IDS: await _prologue_large(fixture, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":42, "timings":timings,
        "scope":"HEADLESS prologue atomic candidate, actual Control callbacks and durable saves; not OS input or p95"}
    print("PROLOGUE_ASYNC_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _fixture_state() -> Dictionary:
    var state := GameState.make_default_snapshot()
    state.loop_state.event_local_states.PROLOGUE = {"P1_complete":true, "current_room":"M2_BEDROOM", "time_block":"morning", "notebook_entries":[], "introduced":[]}
    return state

func _make_view() -> Node:
    var view = PROLOGUE.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    return view

func _prologue_settle(view: Node) -> int:
    var start := Time.get_ticks_msec()
    var frames := 0
    while is_instance_valid(view) and not view._prologue_async_request.is_empty():
        if Time.get_ticks_msec() - start > 60000:
            _expect(false, "prologue pending timed out")
            break
        await get_tree().process_frame
        frames += 1
    return frames

func _candidate_case(scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    _seed(_fixture_state())
    var view = _make_view()
    view._queue_notebook_observation("NOTE_P_DUTIES")
    var request: Dictionary = view._prologue_candidate_request()
    if scenario == "window": request.window = {"schema_version":1, "window":1, "selected_item":"SOFT_CLOTH"}
    if scenario == "combined":
        request.progress.p3_journal_seen = true
        request.progress.P3B_complete = true
        request.progress.p4_life_support_seen = true
        request.progress.p4_memory_anchor_seen = true
        request.progress.bird_observed = true
        request.progress.P5_complete = true
        request.progress.introduced = ["EDGAR"]
        request.inventory = ["SOFT_CLOTH"]
        var surface := _recording(_line())
        request.surfaces = [{"speaker":surface.speaker, "text":surface.text, "locale":locale, "context":surface.context}]
    if scenario == "stale_note": request.scope.slot = "different_slot"
    if scenario == "malformed": request.erase("progress")
    if scenario == "choice":
        view._show_p3_journal_choices()
        request = view._prologue_candidate_request({"speaker":view._dialogue_ui_text("HISTORY_OPTIONS"), "text":view._dialogue_label.text,
            "context":{}, "presentation":view._prologue_choice_spec()})
        var line: Dictionary = request.recording.presentation.line
        request.recording.context = line.history_context.duplicate(true)
        request.recording.context.notebook_content = line.notebook_content
        request.recording.text = line.text
        request.recording.speaker = line.speaker
    var original := GameState.get_snapshot()
    var frozen := request.duplicate(true)
    var prepared := CANDIDATE.prepare(original, request)
    if scenario in ["stale_note", "malformed"]:
        _expect(not prepared.ok and prepared.error_id == ("NB_NOTE_STALE_SCOPE" if scenario == "stale_note" else "NB_PROLOGUE_REQUEST"), "candidate exact rejection")
    else:
        _expect(prepared.ok, "candidate accepts detached composite")
        if prepared.ok:
            _expect(StateSnapshotValidator.new().validate(prepared.snapshot).ok, "candidate validates complete snapshot")
            _expect(prepared.snapshot.loop_state.event_local_states.PROLOGUE == request.progress, "candidate contains exact progress")
            if scenario == "window": _expect(prepared.snapshot.loop_state.event_local_states[CURSOR.WINDOW_KEY] == request.window, "window context preserved")
            if scenario == "combined":
                var knowledge: Dictionary = prepared.snapshot.meta_progress.knowledge_entries
                for marker in ["NOTE_JOURNAL", "CLR_00_SIGNATURES", "OBS_KITCHEN_REGULAR_PULSE", "MEM_FATHER_TEA_HAND_FRAGMENT", "OBS_REPEATING_BIRD", "OBS_WEATHER_CONTRADICTION", "INTRO_EDGAR"]:
                    _expect(knowledge.has(marker), "exact composite marker " + marker)
                _expect(prepared.snapshot.loop_state.inventory == ["SOFT_CLOTH"], "inventory belongs to same candidate")
            if scenario == "choice": _expect(CURSOR.read(prepared.snapshot).kind == "choice", "synchronous choice candidate still supported")
    _expect(StateSnapshotValidator.same_persisted_value(original, GameState.get_snapshot()) and request == frozen, "candidate preserves caller and live state")
    cases.append({"kind":"candidate", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _handoff(_slot: String) -> void: handoffs += 1

func _prologue_ui(scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    var seed := _fixture_state()
    if scenario == "handoff":
        seed.loop_state.day_index = 1
        seed.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
        seed.meta_progress.knowledge_entries.prologue_notebook_entries = ["already saved before reset"]
        seed.meta_progress.knowledge_entries.notebook_knowledge = preload("res://scripts/systems/notebook_knowledge.gd").create()
    _seed(seed)
    var view = _make_view()
    if scenario == "handoff":
        await _prologue_settle(view)
        view._dismiss_dialogue_for_test()
    var manager: Node = SaveManager
    if scenario == "promotion": manager = FailedPromotion.new()
    elif scenario == "ack": manager = LostAcknowledgement.new()
    elif scenario == "after_action_failure": manager = RejectCompleted.new()
    if manager != SaveManager: add_child(manager)
    view._prologue_surface_saves = manager
    if scenario != "handoff": view._queue_notebook_observation("NOTE_P_DUTIES")
    var line := _line()
    if scenario == "handoff": line = view._prologue_line("R1_NOTES", "SYSTEM")
    var after := Callable()
    if scenario == "handoff":
        after = view._finish_prologue_handoff
        view.campaign_requested.connect(_handoff)
    if scenario in ["after_action", "after_action_failure"]: after = view._return_to_hall_after_dialogue
    var before := GameState.get_snapshot()
    var revision: int = GameState.revision
    var previous_handoffs := handoffs
    view._show_dialogue([line], after)
    var displayed_token: String = view._dialogue_lines[0].presentation_token
    _expect(view._prologue_async_enabled() and not view._prologue_async_request.is_empty(), "real prologue starts pending composite")
    _expect(view._dialogue_next.disabled and not view._notebook_open_block_reason().is_empty(), "prologue next/notebook guard")
    view._dialogue_next.pressed.emit()
    view._advance_dialogue()
    _expect(view._dialogue_index == 0 and GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "pending cannot advance or partially install")
    if scenario == "replace": view._dialogue_lines[0].presentation_token = ARCHIVE.new_uid()
    if scenario == "locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
    if scenario == "service": view._prologue_surface_saves = STORAGE.new()
    if scenario == "progress_changed": view._progress.bird_observed = true
    if scenario == "pending_note_changed": view._pending_notebook.clear()
    var frames := await _prologue_settle(view)
    if scenario in ["success", "ack", "handoff", "after_action", "after_action_failure"]:
        _expect(frames > 0 and view._prologue_history_index == 0 and not view._dialogue_next.disabled, "composite commits before continuation")
        _expect(view._pending_notebook.is_empty(), "pending notes cleared only after commit")
        var disk := SaveManager.load_slot(SLOT)
        _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "atomic prologue disk/live state")
        _expect(disk.snapshot.meta_progress.knowledge_entries.has("notebook_knowledge"), "acquired note is durable with displayed line")
        if scenario == "handoff":
            _expect(disk.snapshot.loop_state.event_local_states.PROLOGUE == before.loop_state.event_local_states.PROLOGUE and disk.snapshot.meta_progress.knowledge_entries == before.meta_progress.knowledge_entries, "departing physical defaults cannot overwrite reset knowledge/progress")
        var previous_entries: Array = disk.snapshot.meta_progress.dialogue_history.entries.duplicate(true)
        view._dialogue_next.pressed.emit()
        _expect(view._dialogue_active and not view._prologue_async_request.is_empty(), "completion remains pending before durable cursor")
        _expect(handoffs == previous_handoffs, "handoff not dispatched before completion")
        await _prologue_settle(view)
        disk = SaveManager.load_slot(SLOT)
        if scenario == "after_action_failure":
            _expect(view._dialogue_active and CURSOR.read(disk.snapshot).phase == "finish_pending", "after-action failure restores durable pending presentation")
            view._prologue_surface_saves = SaveManager
            view._dialogue_next.pressed.emit()
            await _prologue_settle(view)
            disk = SaveManager.load_slot(SLOT)
        _expect(not view._dialogue_active and CURSOR.read(disk.snapshot).phase == "completed", "completed cursor is durable")
        var entries: Array = disk.snapshot.meta_progress.dialogue_history.entries
        for entry in previous_entries:
            var preserved: Array = entries.filter(func(value: Dictionary) -> bool: return value.entry_uid == entry.entry_uid)
            _expect(preserved.size() == 1 and StateSnapshotValidator.same_persisted_value(preserved[0], entry), "completion preserves observed UID and original content")
        _expect(entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("presentation_token") == displayed_token).size() == 1, "completion never duplicates displayed line token")
        var previous_uids: Array = previous_entries.map(func(entry: Dictionary) -> String: return entry.entry_uid)
        for entry in entries:
            if entry.entry_uid not in previous_uids:
                _expect(entry.record_class == "authored" and String(entry.observation.content_id).begins_with("NB_PROLOGUE_SURFACE_"), "only actually displayed object surfaces may follow completion")
        _expect(handoffs == previous_handoffs + (1 if scenario == "handoff" else 0), "handoff exactly once after durability")
        if scenario in ["after_action", "after_action_failure"]: _expect(disk.snapshot.loop_state.location_id == "M1_CENTRAL_HALL", "after-action progress and completion saved atomically")
    else:
        _expect(GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "rejection leaves all live fields unchanged")
        _expect(view._prologue_history_index == -1 and view._dialogue_active and not view._dialogue_next.disabled, "failed composite remains retryable")
        if scenario == "promotion":
            _expect(not view._pending_notebook.is_empty(), "failed save retains uncommitted note")
            view._prologue_surface_saves = SaveManager
            view._dialogue_next.pressed.emit()
            await _prologue_settle(view)
            _expect(view._prologue_history_index == 0 and view._dialogue_index == 0 and view._pending_notebook.is_empty(), "retry records composite without advancing")
    if scenario == "service": view._prologue_surface_saves.free()
    TranslationServer.set_locale(locale)
    cases.append({"kind":"ui", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    SaveManager.delete_test_slot(SLOT)

func _prologue_large(id: String, locale: String) -> void:
    var initial_errors := errors.size()
    var fixture := FIXTURES.build(id)
    _expect(fixture.ok, "large fixed fixture")
    var state := _fixture_state()
    state.meta_progress.dialogue_history = fixture.archive
    state.meta_progress.knowledge_entries.notebook_knowledge = fixture.ledger
    _seed(state)
    var view = _make_view()
    view._queue_notebook_observation("NOTE_P_DUTIES")
    var start := Time.get_ticks_usec()
    view._show_dialogue([_line()])
    var begin_ms := float(Time.get_ticks_usec() - start) / 1000.0
    var frames := await _prologue_settle(view)
    var total_ms := float(Time.get_ticks_usec() - start) / 1000.0
    _expect(view._prologue_history_index == 0 and frames > 0, "large composite commits while frames progress")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "large composite disk/live exact")
    timings.append({"fixture":id, "locale":locale, "begin_ms":begin_ms, "total_ms":total_ms, "worker_frames":frames, "scope":"HEADLESS n=1 composite durable return; excludes reload"})
    cases.append({"kind":"large", "fixture":id, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
