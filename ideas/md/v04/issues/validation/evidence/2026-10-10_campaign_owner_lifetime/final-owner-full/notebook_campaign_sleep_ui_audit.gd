extends "notebook_campaign_sleep_audit.gd"

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for route in ROUTES:
            for fault in ["success", "wake_reject"]: await _ui_case(route, fault, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":24,
        "scope":"HEADLESS actual controller callbacks and D6 confirmation/transition/retry controls; no OS input, cross-process recovery, latency or full playthrough acceptance"}
    print("CAMPAIGN_SLEEP_UI_AUDIT: ", JSON.stringify(result))
    print("CAMPAIGN_SLEEP_UI_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _settle(view) -> void:
    var started := Time.get_ticks_msec()
    while (not view._history_async_request.is_empty() or not SaveManager._notebook_job.is_empty()) and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(view._history_async_request.is_empty() and SaveManager._notebook_job.is_empty(), "UI history writer settles")

func _drain(view) -> void:
    for index in range(100):
        await _settle(view)
        if not view._dialogue_active: return
        view._advance_dialogue()
    _expect(false, "finite authored dialogue drains")

func _ui_case(route: String, fault: String, locale: String) -> void:
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
    var manager := SleepStorage.new()
    manager.fault = fault
    add_child(manager)
    view.session._save = manager
    _expect(view._async_history_enabled(), "actual campaign controller enables requested development async gate")
    if route in ["bedroom", "capsule"]:
        view._confirm_d6_rest(route)
        var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
        _expect(buttons.size() == 2, "actual D6 recorded rest confirmation has two controls")
        if buttons.size() != 2:
            view.queue_free()
            manager.queue_free()
            await get_tree().process_frame
            return
        buttons[1].pressed.emit()
        await _settle(view)
        view.set_process(false)
        _expect(view._d6_sleep_transition_active, "D6 confirmation starts actual transition")
        view._tick_d6_sleep_transition(6.0)
    else:
        view._sleep_now()
    var started := Time.get_ticks_msec()
    while not view._reset_transition_pending and Time.get_ticks_msec() - started < 10000: await get_tree().process_frame
    _expect(view._reset_transition_pending and not manager._notebook_job.is_empty(), "actual sleep callback starts worker and pending UI")
    var current_room: String = view._current_room
    var count := manager.begins.size()
    view._sleep_now()
    view._open_menu()
    view._return_to_title()
    view._enter_room("M1_CENTRAL_HALL")
    _expect(view._current_room == current_room and not view._modal_active and manager.begins.size() == count, "pending sleep blocks room/menu/title/duplicate callback")
    _expect(view._edgar_timer.paused and not view._notebook_open_block_reason().is_empty(), "pending sleep pauses Edgar and blocks notebook")
    started = Time.get_ticks_msec()
    while view._reset_transition_pending and Time.get_ticks_msec() - started < 120000: await get_tree().process_frame
    _expect(not view._reset_transition_pending, "actual sleep finishes pending boundary")
    if fault == "wake_reject":
        _expect(view._modal_active and not view.session._sleep_wake_pending.is_empty(), "wake failure presents explicit administrative retry")
        if route in ["bedroom", "capsule"]:
            _expect(not view.session.known("E1_wake_seen") and view._d6_sleep_transition_failed, "D6 failed wake cannot reveal E1")
        var revision: int = GameState.revision
        for tick in range(3): await get_tree().process_frame
        _expect(GameState.revision == revision, "actual failed UI never auto retries")
        var retries: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
        _expect(retries.size() == 1, "one explicit wake retry control")
        if retries.size() == 1: retries[0].pressed.emit()
        started = Time.get_ticks_msec()
        while view._reset_transition_pending and Time.get_ticks_msec() - started < 120000: await get_tree().process_frame
    await _settle(view)
    _expect(not view._reset_transition_pending and not view._modal_active and view.session._sleep_wake_pending.is_empty(), "actual retry completes and unlocks UI")
    _expect(not view._edgar_timer.paused, "completed sleep restores Edgar timer")
    _expect(GameState.get_value("loop_state.day_index") == before.loop_state.day_index + (0 if route == "rest" else 1), "actual UI retry never advances day twice")
    _expect(manager.begins.count("reset") == (0 if route == "rest" else 8) and manager.begins.count("wake") == (2 if fault == "wake_reject" else 1), "actual controller uses separate eight-phase and wake saves")
    _preserved(before, GameState.get_snapshot())
    cases.append({"kind":"ui", "route":route, "fault":fault, "locale":locale, "passed":errors.size() == first, "worker_kinds":manager.begins})
    await _drain(view)
    await _settle(view)
    view.queue_free()
    manager.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
