extends "notebook_reset_ui_audit.gd"

const P6_CASES := ["control", "view_queue", "view_free", "view_detach", "view_reenter", "view_reparent", "host_queue", "host_free", "host_detach", "host_reenter", "coordinator_replace", "slot_replace"]
const BOOT_CASES := ["control", "host_queue", "host_free", "host_detach", "host_reenter", "host_reparent", "coordinator_replace", "epoch_replace"]
const SENTINEL := "RETIRED_RESET_MUST_NOT_CHANGE_NEW_UI"

class HeldReset extends "res://scripts/autoload/save_manager.gd":
    var held := false
    var begins := 0
    func begin_history_write(game: Node, slot: String, point: String, recording: Dictionary, revision: int, id: String, guard: Callable = Callable()) -> Dictionary:
        var result := super.begin_history_write(game, slot, point, recording, revision, id, guard)
        if result.ok and recording.kind == "reset":
            begins += 1
            if not held:
                held = true
                set_process(false)
        return result

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var baseline := "--reset-owner-baseline" in OS.get_cmdline_user_args()
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        if baseline:
            await _p6_owner("fade", "control", locale)
            await _p6_owner("fade", "view_reenter", locale)
            await _p6_owner("write", "view_reenter", locale)
            await _p6_owner("write", "host_reenter", locale)
            await _boot_owner("normal", "write", "host_reenter", locale)
            await _boot_owner("normal", "complete", "host_reenter", locale)
        else:
            for boundary in ["fade", "write", "reveal"]:
                for scenario in P6_CASES: await _p6_owner(boundary, scenario, locale)
            for reset_type in ["normal", "broken"]:
                for boundary in ["write", "complete"]:
                    for scenario in BOOT_CASES: await _boot_owner(reset_type, boundary, scenario, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":12 if baseline else 136,
        "scope":"HEADLESS actual P6 controls, fade/write/reveal and bootstrap write/completion owner lifetime; no OS input or cross-process acceptance"}
    print("RESET_OWNER_AUDIT: ", JSON.stringify(result))
    print("RESET_OWNER_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _retire(host: Node, view: Node, scenario: String) -> void:
    match scenario:
        "view_queue": view.queue_free()
        "view_free": view.free()
        "view_detach": host.remove_child(view)
        "view_reenter":
            host.remove_child(view)
            host.add_child(view)
        "view_reparent": view.reparent(self)
        "host_queue": host.queue_free()
        "host_free": host.free()
        "host_detach": remove_child(host)
        "host_reenter":
            remove_child(host)
            add_child(host)
        "host_reparent": host.reparent(get_tree().root)
        "coordinator_replace": host._reset_coordinator = ResetCoordinator.new(GameState, SaveManager)
        "slot_replace": view._slot_id = "__test_retired_reset_slot"
        "epoch_replace":
            var state := GameState.get_snapshot()
            GameState.reset_for_test()
            _expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_RESET_OWNER_REPLACE").ok, "external epoch replacement fixture")
    if is_instance_valid(view) and not view.is_queued_for_deletion():
        view._status_label.text = SENTINEL
        view._fade.visible = true
        view._fade.color = Color(0.2, 0.3, 0.4, 0.5)
    if is_instance_valid(host) and not host.is_queued_for_deletion(): host._start_screen._status_label.text = SENTINEL

func _terminal(coordinator: RefCounted, manager: Node) -> void:
    var started := Time.get_ticks_msec()
    while coordinator._async_running and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
    _expect(not coordinator._async_running, "retired coordinator reaches terminal state")
    if is_instance_valid(manager):
        while not manager._notebook_job.is_empty() and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
        _expect(manager._notebook_job.is_empty(), "retired worker releases job")

func _dispose(host: Node, view: Node, manager: Node) -> void:
    if is_instance_valid(view):
        if not view._prologue_async_request.is_empty(): await _natural_settle(view)
        view.free()
    if is_instance_valid(host):
        if is_instance_valid(host._prologue):
            var current = host._prologue
            var started := Time.get_ticks_msec()
            while not current._history_async_request.is_empty() and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
        host.free()
    if is_instance_valid(manager): manager.free()
    await get_tree().process_frame
    await _wait_storage()
    SaveManager.delete_test_slot(SLOT)

func _p6_owner(boundary: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    await _wait_storage()
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
    var manager := HeldReset.new()
    add_child(manager)
    var coordinator := ResetCoordinator.new(GameState, manager)
    host._reset_coordinator = coordinator
    view._hotspot_layer.get_node("BED").pressed.emit()
    await _natural_settle(view)
    var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
    _expect(buttons.size() == 2, "actual P6 confirmation")
    buttons[0].pressed.emit()
    await _natural_settle(view)
    view._dialogue_next.pressed.emit()
    await _natural_settle(view)
    view._dialogue_next.pressed.emit()
    var started := Time.get_ticks_msec()
    while not view._reset_transition_pending and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
    _expect(view._reset_transition_pending, "actual P6 callback reaches fade")
    var reveal: Tween
    if boundary != "fade":
        while not manager.held and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
        _expect(manager.held, "P6 write held before promotion")
        await _prepared(manager)
        if boundary == "reveal":
            manager.set_process(true)
            while view._reset_transition_pending and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
            var tweens := get_tree().get_processed_tweens()
            _expect(view._fade.visible and not tweens.is_empty(), "actual reset reaches reveal")
            if not tweens.is_empty():
                reveal = tweens.back()
                reveal.set_speed_scale(0.02)
            await _natural_settle(view)
            await _wait_storage()
    var durable := GameState.get_snapshot()
    var paths: Dictionary = manager._slot_paths(SLOT)
    var main := FileAccess.get_file_as_bytes(paths.main)
    var backup := FileAccess.get_file_as_bytes(paths.backup)
    var prior_begins := manager.begins
    _retire(host, view, scenario)
    manager.set_process(true)
    if reveal != null and reveal.is_valid(): reveal.set_speed_scale(1.0)
    started = Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < 4000:
        await get_tree().process_frame
        if not coordinator._async_running and (not is_instance_valid(view) or (not view._reset_transition_pending and (scenario != "control" or not view._fade.visible))): break
    await _terminal(coordinator, manager)
    for tick in range(4): await get_tree().process_frame
    if scenario == "control":
        _expect(GameState.get_value("loop_state.day_index") == 1 and GameState.get_value("reset_state.phase") == "idle", "P6 live owner completes exactly one reset")
        _expect(not view._reset_transition_pending and not view._fade.visible and not view._modal_active, "P6 live reveal unlocks")
        await _natural_settle(view)
        await _wait_storage()
    else:
        _expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), durable), "P6 retired owner never changes durable state")
        _expect(FileAccess.get_file_as_bytes(paths.main) == main and FileAccess.get_file_as_bytes(paths.backup) == backup, "P6 retired owner preserves main/backup")
        _expect(manager.begins == prior_begins, "P6 retired owner starts no next worker")
        if is_instance_valid(view) and not view.is_queued_for_deletion():
            _expect(not view._reset_transition_pending and not view._modal_active and view._status_label.text == SENTINEL, "P6 retired callback does not lock or contaminate new UI")
            _expect(view._fade.visible and view._fade.color == Color(0.2, 0.3, 0.4, 0.5), "P6 old tween cannot overwrite replacement fade")
    cases.append({"kind":"p6", "reset_type":"normal", "boundary":boundary, "scenario":scenario, "locale":locale, "passed":errors.size() == first,
        "day_before":durable.loop_state.day_index, "day_after":GameState.get_value("loop_state.day_index"), "phase_before":durable.reset_state.phase, "phase_after":GameState.get_value("reset_state.phase")})
    await _dispose(host, view, manager)

func _boot_owner(reset_type: String, boundary: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    await _wait_storage()
    var state := GameState.make_default_snapshot()
    state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
    if reset_type == "broken":
        state.meta_progress.journal_stage = 3
        state.fracture_state.camouflage_filter = "disabled"
        state.fracture_state.world_phase = "S2"
    _seed(state)
    var initial := ResetCoordinator.new(GameState, SaveManager)
    var pending: Dictionary = await initial.request_broken_reset_async(SLOT, "memory_committed") if reset_type == "broken" else await initial.request_normal_reset_async(SLOT, "memory_committed")
    _expect(pending.ok, "real boot durable pending reset")
    var host = MAIN.instantiate()
    add_child(host)
    var manager := HeldReset.new()
    add_child(manager)
    var coordinator := ResetCoordinator.new(GameState, manager)
    host._reset_coordinator = coordinator
    var captured := {}
    if boundary == "complete":
        coordinator.reset_completed.connect(func(_transaction: StringName, _type: StringName, _revision: int) -> void:
            captured.snapshot = GameState.get_snapshot()
            var paths: Dictionary = manager._slot_paths(SLOT)
            captured.main = FileAccess.get_file_as_bytes(paths.main)
            captured.backup = FileAccess.get_file_as_bytes(paths.backup)
            _retire(host, null, scenario))
    host._launch_prologue(SLOT, "SYS_RESET")
    var started := Time.get_ticks_msec()
    while not manager.held and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
    _expect(manager.held and host._reset_async_pending and not is_instance_valid(host._prologue), "actual bootstrap holds before launch")
    await _prepared(manager)
    var paths: Dictionary = manager._slot_paths(SLOT)
    var durable := GameState.get_snapshot()
    var main := FileAccess.get_file_as_bytes(paths.main)
    var backup := FileAccess.get_file_as_bytes(paths.backup)
    if boundary == "write": _retire(host, null, scenario)
    manager.set_process(true)
    await _terminal(coordinator, manager)
    for tick in range(5): await get_tree().process_frame
    if boundary == "complete":
        _expect(not captured.is_empty(), "real completed signal observed")
        if not captured.is_empty():
            durable = captured.snapshot
            main = captured.main
            backup = captured.backup
    if scenario == "control":
        _expect(is_instance_valid(host._prologue) and not host._reset_async_pending, "live bootstrap launches after durability")
        _expect(GameState.get_value("loop_state.day_index") == 1 and GameState.get_value("reset_state.phase") == "idle", "boot completes exactly one reset")
    else:
        _expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), durable), "retired bootstrap cannot replace durable state")
        _expect(FileAccess.get_file_as_bytes(paths.main) == main and FileAccess.get_file_as_bytes(paths.backup) == backup, "retired bootstrap preserves main/backup")
        if is_instance_valid(host) and not host.is_queued_for_deletion():
            _expect(not host._reset_async_pending and not is_instance_valid(host._prologue), "retired bootstrap unlocks without campaign launch")
            _expect(host._start_screen._status_label.text == SENTINEL, "old boot cannot show error on replacement UI")
    cases.append({"kind":"boot", "reset_type":reset_type, "boundary":boundary, "scenario":scenario, "locale":locale, "passed":errors.size() == first,
        "day_before":durable.loop_state.day_index, "day_after":GameState.get_value("loop_state.day_index"), "phase_before":durable.reset_state.phase, "phase_after":GameState.get_value("reset_state.phase")})
    await _dispose(host, null, manager)
