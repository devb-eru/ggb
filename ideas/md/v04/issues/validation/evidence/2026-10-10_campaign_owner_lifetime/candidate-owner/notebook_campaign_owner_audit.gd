extends "notebook_campaign_sleep_ui_audit.gd"

const OWNER_SCENARIOS := ["control", "owner_queue", "owner_free", "owner_detach", "owner_reenter", "session_replace", "slot_replace", "service_free"]
const SENTINEL := "OWNER_REPLACEMENT_MUST_NOT_BE_OVERWRITTEN"

class HeldStorage extends "notebook_campaign_sleep_audit.gd".SleepStorage:
    var boundary := "first"
    var held := false
    func begin_history_write(game: Node, slot: String, point: String, recording: Dictionary, revision: int, id: String, guard: Callable = Callable()) -> Dictionary:
        var started := super.begin_history_write(game, slot, point, recording, revision, id, guard)
        if started.ok and not held and ((boundary == "first" and recording.kind == "reset") or (boundary == "wake" and recording.kind == "wake")):
            held = true
            set_process(false)
        return started

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var baseline := "--notebook-owner-baseline" in OS.get_cmdline_user_args()
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        if baseline:
            for scenario in ["control", "owner_reenter", "session_replace", "service_free"]:
                await _owner_case("chapter", "first", scenario, locale)
        else:
            for route in ROUTES:
                for boundary in (["wake"] if route == "rest" else ["first", "wake"]):
                    for scenario in OWNER_SCENARIOS: await _owner_case(route, boundary, scenario, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":8 if baseline else 176,
        "scope":"HEADLESS actual campaign/D6 callbacks, scene owner retirement/re-entry and exact durable reset/wake boundary; no OS input or cross-process acceptance"}
    print("CAMPAIGN_OWNER_AUDIT: ", JSON.stringify(result))
    print("CAMPAIGN_OWNER_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _owner_case(route: String, boundary: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    var before := _route_seed(route)
    var view = VIEWS[0 if route == "chapter" else (1 if route == "mirror" else 2)].new()
    view.configure_session(SLOT, "D6" if route in ["bedroom", "capsule"] else "")
    add_child(view)
    await get_tree().process_frame
    view.set_process(false)
    await _drain(view)
    view._close_modal()
    await _settle(view)
    var manager := HeldStorage.new()
    manager.boundary = boundary
    add_child(manager)
    view.session._save = manager
    var old_session = view.session
    if route in ["bedroom", "capsule"]:
        view._confirm_d6_rest(route)
        var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
        _expect(buttons.size() == 2, "actual D6 confirmation controls")
        if buttons.size() != 2:
            view.free()
            manager.free()
            return
        buttons[1].pressed.emit()
        await _settle(view)
        view.set_process(false)
        view._tick_d6_sleep_transition(6.0)
    else:
        view._sleep_now()
    var started := Time.get_ticks_msec()
    while not manager.held and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(manager.held and view._reset_transition_pending and not manager._notebook_job.is_empty(), "actual callback reaches selected worker boundary")
    await _prepared(manager)
    var last_durable := GameState.get_snapshot()
    var paths: Dictionary = manager._slot_paths(SLOT)
    var main := FileAccess.get_file_as_bytes(paths.main)
    var backup := FileAccess.get_file_as_bytes(paths.backup)
    var temporary: String = manager._notebook_job.paths.temporary
    var old_begins := manager.begins.size()
    if boundary == "wake":
        _expect(last_durable.reset_state.phase == "idle", "wake ownership captured after reset receipt")
        if route in ["bedroom", "capsule"]: _expect(not last_durable.meta_progress.knowledge_entries.get("E1_wake_seen", false), "E1 still undisclosed at wake boundary")
    match scenario:
        "owner_queue": view.queue_free()
        "owner_free": view.free()
        "owner_detach": remove_child(view)
        "owner_reenter":
            remove_child(view)
            add_child(view)
            view.set_process(false)
        "session_replace": view.session = _session(route, manager)
        "slot_replace":
            view._slot_id = "__test_owner_other"
            view.session.slot_id = "__test_owner_other"
        "service_free": manager.free()
    if is_instance_valid(view) and not view.is_queued_for_deletion(): view._status_label.text = SENTINEL
    if is_instance_valid(manager): manager.set_process(true)
    started = Time.get_ticks_msec()
    while old_session._sleep_async_running and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(not old_session._sleep_async_running, "retired callback session reaches terminal state")
    for tick in range(3): await get_tree().process_frame
    if scenario == "control":
        _expect(GameState.get_value("loop_state.day_index") == before.loop_state.day_index + (0 if route == "rest" else 1), "live owner completes one reset or rest")
        _expect(not view._reset_transition_pending and not view._modal_active, "live owner unlocks without a failure modal")
        await _drain(view)
        await _settle(view)
        _preserved(before, GameState.get_snapshot())
    else:
        _expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), last_durable), "retired callback never installs prepared reset/wake")
        _expect(FileAccess.get_file_as_bytes(paths.main) == main and FileAccess.get_file_as_bytes(paths.backup) == backup, "retired callback preserves main and backup bytes")
        if is_instance_valid(manager): _expect(manager.begins.size() == old_begins, "retired callback starts no following worker")
        if is_instance_valid(view) and not view.is_queued_for_deletion():
            _expect(not view._reset_transition_pending and not view._edgar_timer.paused, "retirement clears old pending ownership and timer pause")
            _expect(not view._modal_active and view._status_label.text == SENTINEL, "old callback cannot overwrite replacement UI or show retry")
    _expect(not FileAccess.file_exists(temporary), "retired or completed worker temporary cleaned")
    if is_instance_valid(view) and is_instance_valid(manager) and not view._history_async_request.is_empty(): await _settle(view)
    cases.append({"route":route, "boundary":boundary, "scenario":scenario, "locale":locale, "passed":errors.size() == first,
        "day_at_retirement":last_durable.loop_state.day_index, "phase_at_retirement":last_durable.reset_state.phase,
        "day_after":GameState.get_value("loop_state.day_index"), "phase_after":GameState.get_value("reset_state.phase")})
    if is_instance_valid(view): view.free()
    if is_instance_valid(manager): manager.free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
