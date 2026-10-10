extends "notebook_prologue_natural_async_audit.gd"

const MAIN := preload("res://scenes/main/main.tscn")
const FAULT := preload("notebook_reset_async_audit.gd")
const UI_SCENARIOS := ["success", "reject_initial", "reject_physical", "ack_physical", "locale", "cancel"]

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in UI_SCENARIOS: await _sleep_ui(scenario, locale)
        for reset_type in ["normal", "broken"]: await _boot_ui(reset_type, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":16,
        "scope":"HEADLESS actual P6 bed/confirmation/dialogue/retry controls and real bootstrap; no physical OS input or full playthrough"}
    print("RESET_UI_AUDIT: ", JSON.stringify(result))
    print("RESET_UI_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _sleep_ui(scenario: String, locale: String) -> void:
    var first := errors.size()
    var state := _fixture_state()
    var progress: Dictionary = state.loop_state.event_local_states.PROLOGUE
    for flag in ["P1_complete", "P2_complete", "P3_complete", "P3B_complete", "P4_complete"]: progress[flag] = true
    progress.intros_seen = ["P6"]
    progress.time_block = "night"
    _seed(state)
    var host = MAIN.instantiate()
    add_child(host)
    var view = PROLOGUE.new()
    view.configure_session(SLOT, "P6_ENTRY")
    host.add_child(view)
    await _natural_settle(view)
    var manager: Node = SaveManager
    if scenario in ["reject_initial", "reject_physical", "ack_physical"]:
        manager = FAULT.PhaseFault.new()
        manager.target = "sleep_confirmed" if scenario == "reject_initial" else "physical_reset_complete"
        manager.mode = "ack" if scenario == "ack_physical" else "reject"
        add_child(manager)
    host._reset_coordinator = ResetCoordinator.new(GameState, manager)
    var phase_signals := []
    host._reset_coordinator.reset_phase_committed.connect(func(_transaction: StringName, phase: StringName, _revision: int) -> void: phase_signals.append(String(phase)))
    view._hotspot_layer.get_node("BED").pressed.emit()
    await _natural_settle(view)
    _expect(view._modal_active and view._prologue_confirmation.recorded, "actual sleep confirmation durable")
    var buttons := view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
    _expect(buttons.size() == 2, "sleep confirmation controls exist")
    buttons[0].pressed.emit()
    await _natural_settle(view)
    _expect(view._dialogue_active and view._dialogue_lines.size() == 2, "sleep begins with actual two-line P6 presentation")
    view._dialogue_next.pressed.emit()
    await _natural_settle(view)
    var before := GameState.get_snapshot()
    var prior_entries: Array = before.meta_progress.dialogue_history.entries.duplicate(true)
    view._dialogue_next.pressed.emit()
    var started := Time.get_ticks_msec()
    while manager._notebook_job.is_empty() and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
    _expect(view._reset_transition_pending and host._reset_async_pending and not manager._notebook_job.is_empty(), "actual reset enters worker boundary")
    _expect(GameState.get_value("reset_state.phase") == "idle", "first pending phase is not exposed before durability")
    var room: String = view._current_room
    view._perform_normal_reset()
    view._open_menu()
    view._return_to_title()
    view._enter_room("M1_CENTRAL_HALL")
    _expect(view._current_room == room and not view._modal_active and not view._notebook_open_block_reason().is_empty(), "pending reset blocks room/menu/title/notebook")
    _expect(not host.request_sleep_transition(SLOT).ok, "synchronous bootstrap reset cannot overlap worker")
    if scenario == "locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
    if scenario == "cancel": manager.cancel_notebook_reference(manager._notebook_job.id)
    started = Time.get_ticks_msec()
    while view._reset_transition_pending and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(not view._reset_transition_pending and not host._reset_async_pending, "actual reset reaches terminal or explicit failure")
    if scenario in ["reject_initial", "reject_physical", "locale", "cancel"]:
        _expect(view._modal_active and phase_signals.size() == (3 if scenario == "reject_physical" else 0), "failure shows explicit retry after only durable phases")
        var revision: int = GameState.revision
        for tick in range(3): await get_tree().process_frame
        _expect(GameState.revision == revision, "failed UI never automatically restarts reset")
        if scenario == "locale": TranslationServer.set_locale(locale)
        var retry_buttons := view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
        _expect(retry_buttons.size() == 1, "failed reset has explicit retry control")
        retry_buttons[0].pressed.emit()
        started = Time.get_ticks_msec()
        while view._reset_transition_pending and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
        _expect(not view._reset_transition_pending and not view._modal_active, "actual retry completes pending phases")
    await _natural_settle(view)
    _expect(GameState.get_value("reset_state.phase") == "idle" and GameState.get_value("loop_state.day_index") == 1, "actual P6 resets exactly once")
    _expect(phase_signals == ["sleep_confirmed", "player_committed", "memory_committed", "physical_reset_complete", "morning_loaded", "route_selected", "complete", "idle"], "UI retry never duplicates durable phase")
    _expect(view._dialogue_active and view._dialogue_lines[0].id == "R1_WAKE", "reset opens same-morning R1 presentation")
    var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries
    for entry in prior_entries:
        var rows := entries.filter(func(row: Dictionary) -> bool: return row.entry_uid == entry.entry_uid)
        _expect(rows.size() == 1 and StateSnapshotValidator.same_persisted_value(rows[0], entry), "P6 archive UID and original preserved through actual reset")
    _expect(GameState.get_value("meta_progress.knowledge_entries.PROLOGUE_COMPLETE", false), "actual permanent prologue completion survives")
    cases.append({"kind":"sleep_ui", "scenario":scenario, "locale":locale, "passed":errors.size() == first})
    host.queue_free()
    if manager != SaveManager: manager.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _boot_ui(reset_type: String, locale: String) -> void:
    var first := errors.size()
    var state := GameState.make_default_snapshot()
    state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
    if reset_type == "broken":
        state.meta_progress.journal_stage = 3
        state.fracture_state.camouflage_filter = "disabled"
        state.fracture_state.world_phase = "S2"
    _seed(state)
    var coordinator := ResetCoordinator.new(GameState, SaveManager)
    var stopped: Dictionary
    if reset_type == "broken": stopped = await coordinator.request_broken_reset_async(SLOT, "memory_committed")
    else: stopped = await coordinator.request_normal_reset_async(SLOT, "memory_committed")
    _expect(stopped.ok and stopped.phase == "memory_committed", "boot fixture has real durable pending reset")
    GameState.reset_for_test()
    _expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "pending boot slot installed")
    var host = MAIN.instantiate()
    add_child(host)
    host._launch_prologue(SLOT, "SYS_RESET")
    _expect(host._reset_async_pending and not SaveManager._notebook_job.is_empty() and not is_instance_valid(host._prologue), "bootstrap resumes reset before launching campaign")
    var revision: int = GameState.revision
    host._on_new_game_requested("slot_01")
    host._on_load_game_requested("slot_02")
    host._developer_jump("PR01")
    _expect(GameState.revision == revision and host._reset_async_pending, "bootstrap rejects competing start/load/jump during reset")
    var started := Time.get_ticks_msec()
    while host._reset_async_pending and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(not host._reset_async_pending and is_instance_valid(host._prologue), "campaign launches only after durable reset")
    _expect(GameState.get_value("reset_state.phase") == "idle" and GameState.get_value("loop_state.day_index") == 1, "boot reset completes once")
    _expect(GameState.get_value("fracture_state.broken_reset_triggered") == (reset_type == "broken"), "boot keeps reset route type")
    cases.append({"kind":"boot_ui", "reset_type":reset_type, "locale":locale, "passed":errors.size() == first})
    if is_instance_valid(host._prologue): await _natural_settle(host._prologue)
    host.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
