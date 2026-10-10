extends "notebook_history_async_audit.gd"

const RESET_PHASES := ["sleep_confirmed", "player_committed", "memory_committed", "physical_reset_complete", "morning_loaded", "route_selected", "complete", "idle"]
var phase_events: Array = []
var completed_events := 0
var async_result: Dictionary = {}
var async_done := false

class PhaseFault extends "res://scripts/autoload/save_manager.gd":
    var target := ""
    var mode := "reject"
    var injected := 0
    func _commit_prepared(paths: Dictionary, main: Dictionary, backup: Dictionary) -> Dictionary:
        var checked := _validate_save_text(FileAccess.get_file_as_string(paths.temporary), paths.temporary)
        var hit: bool = checked.ok and checked.snapshot.reset_state.phase == target and injected == 0
        if hit and mode == "reject":
            injected += 1
            return _load_failure(&"TEST_RESET_PROMOTION")
        var result := super._commit_prepared(paths, main, backup)
        if hit and mode == "ack" and result.ok:
            injected += 1
            return _load_failure(&"TEST_RESET_ACK_LOST")
        return result

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for reset_type in ["normal", "broken"]:
            for phase in RESET_PHASES: await _phase_case(reset_type, phase, locale)
            for mode in ["reject", "ack"]:
                for phase in RESET_PHASES: await _fault_case(reset_type, phase, mode, locale)
            for scenario in ["guard", "revision", "epoch", "cancel", "root", "source", "busy", "payload"]: await _stale_case(reset_type, scenario, locale)
            for scenario in ["between_epoch", "between_revision"]: await _between_case(reset_type, scenario, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":136,
        "scope":"HEADLESS reset coordinator, actual worker/disk and phase-stop reload; no OS input, cross-process recovery or latency budget acceptance"}
    print("RESET_ASYNC_AUDIT: ", JSON.stringify(result))
    print("RESET_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _reset_seed(reset_type: String) -> Dictionary:
    var state := GameState.make_default_snapshot()
    state.meta_progress.journal_stage = 2
    state.meta_progress.knowledge_entries = {"KN_RESET_KEEP":"verified"}
    state.meta_progress.servants.edgar.bond = 2
    state.meta_progress.servants.mara2.residual_memory = ["reset_kept"]
    state.loop_state.inventory = ["OBJ_TEST_TEMP_KEY"]
    state.loop_state.physical_changes = {"OBJ_TEST_DRAWER":"open"}
    state.loop_state.event_local_states = {"TEST_EVENT":{"step":2}}
    state.loop_state.shortcut_context = {"source":"test"}
    if reset_type == "broken":
        state.fracture_state.camouflage_filter = "disabled"
        state.fracture_state.world_phase = "S2"
    _seed(state)
    var line := _line()
    _expect(WRITER.record(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", line.speaker, line.text, TranslationServer.get_locale(), "PROLOGUE", [], _recording(line).context).ok, "seed actual authored archive")
    return GameState.get_snapshot()

func _listen(coordinator: ResetCoordinator) -> void:
    phase_events = []
    completed_events = 0
    coordinator.reset_phase_committed.connect(func(transaction: StringName, phase: StringName, revision: int) -> void:
        var disk := SaveManager.load_slot(SLOT)
        _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "phase signal follows exact durable install")
        _expect(String(GameState.get_value("reset_state.phase")) == String(phase) and GameState.revision == revision, "phase signal coordinates")
        phase_events.append({"phase":String(phase), "transaction":String(transaction), "revision":revision}))
    coordinator.reset_completed.connect(func(_transaction: StringName, _type: StringName, _revision: int) -> void: completed_events += 1)

func _request(coordinator: ResetCoordinator, reset_type: String, stop: String = "", guard: Callable = Callable()) -> Dictionary:
    if reset_type == "broken": return await coordinator.request_broken_reset_async(SLOT, stop, guard)
    return await coordinator.request_normal_reset_async(SLOT, stop, guard)

func _final(before: Dictionary, reset_type: String) -> void:
    var after := GameState.get_snapshot()
    _expect(after.reset_state.phase == "idle" and not after.reset_state.last_completed_transaction_id.is_empty(), "reset ends in idle with receipt")
    _expect(after.loop_state.day_index == before.loop_state.day_index + 1, "physical reset advances one day exactly once")
    _expect(after.loop_state.inventory.is_empty() and after.loop_state.physical_changes.is_empty() and after.loop_state.event_local_states.is_empty() and after.loop_state.shortcut_context.is_empty(), "all physical state resets")
    _expect(StateSnapshotValidator.same_persisted_value(after.meta_progress, before.meta_progress), "archive notes memory relation exact across reset")
    _expect(after.fracture_state.broken_reset_triggered == (reset_type == "broken"), "reset type preserved")
    _expect(after.fracture_state.world_phase == ("S3" if reset_type == "broken" else "S0"), "fracture phase preserved")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, after), "final disk exact")

func _phase_case(reset_type: String, phase: String, locale: String) -> void:
    var first := errors.size()
    var before := _reset_seed(reset_type)
    var coordinator := ResetCoordinator.new(GameState, SaveManager)
    _listen(coordinator)
    var stopped := await _request(coordinator, reset_type, phase)
    _expect(stopped.ok and stopped.phase == phase, "async reset stops at requested phase")
    _expect(phase_events.size() == RESET_PHASES.find(phase) + 1, "all and only durable phases signalled")
    _expect(completed_events == (1 if phase == "idle" else 0), "no early completion")
    var saved := GameState.get_snapshot()
    GameState.reset_for_test()
    var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
    _expect(loaded.ok and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "phase reload exact")
    if phase != "idle":
        _expect(loaded.resume_event_id == "SYS_RESET", "unfinished reset routes to coordinator")
        coordinator = ResetCoordinator.new(GameState, SaveManager)
        _listen(coordinator)
        var resumed := await coordinator.resume_pending_reset_async(SLOT)
        _expect(resumed.ok and resumed.completed, "saved phase resumes to completion")
        _expect(phase_events.size() == 7 - RESET_PHASES.find(phase) and completed_events == 1, "resume never repeats committed phase")
    _final(before, reset_type)
    cases.append({"kind":"phase", "reset_type":reset_type, "phase":phase, "locale":locale, "passed":errors.size() == first})
    SaveManager.delete_test_slot(SLOT)

func _between_case(reset_type: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    var before := _reset_seed(reset_type)
    var coordinator := ResetCoordinator.new(GameState, SaveManager)
    _listen(coordinator)
    coordinator.reset_phase_committed.connect(func(_transaction: StringName, phase: StringName, _revision: int) -> void:
        if String(phase) != "sleep_confirmed": return
        if scenario == "between_epoch": GameState.load_epoch += 1
        else: _expect(StateWriter.new(GameState).commit_atomic([{ "state_path":"meta_progress.servants.edgar.bond", "operation":"increment", "value":1}], GameState.revision, &"RESET_BETWEEN_STALE").ok, "explicit mutation between phases"))
    var result := await _request(coordinator, reset_type)
    _expect(not result.ok and phase_events.size() == 1 and completed_events == 0, "context change between phases must stop reset")
    _expect(GameState.get_value("reset_state.phase") == "sleep_confirmed" and GameState.get_value("loop_state.day_index") == 0, "between-phase invalidation cannot clear physical state")
    if not result.ok:
        _expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "explicit recovery reloads last durable phase")
        var retry := await ResetCoordinator.new(GameState, SaveManager).resume_pending_reset_async(SLOT)
        _expect(retry.ok and retry.completed, "fresh coordinator resumes invalidated transaction explicitly")
        _final(before, reset_type)
    cases.append({"kind":"between", "reset_type":reset_type, "scenario":scenario, "locale":locale, "passed":errors.size() == first})
    SaveManager.delete_test_slot(SLOT)

func _fault_case(reset_type: String, phase: String, mode: String, locale: String) -> void:
    var first := errors.size()
    var before := _reset_seed(reset_type)
    var manager := PhaseFault.new()
    manager.target = phase
    manager.mode = mode
    add_child(manager)
    var coordinator := ResetCoordinator.new(GameState, manager)
    _listen(coordinator)
    var result := await _request(coordinator, reset_type)
    _expect(manager.injected == 1, "target phase injected exactly once")
    if mode == "reject":
        var index := RESET_PHASES.find(phase)
        _expect(not result.ok and phase_events.size() == index and completed_events == 0, "rejected phase never signals or completes")
        _expect(GameState.get_value("reset_state.phase") == ("idle" if index == 0 else RESET_PHASES[index - 1]), "failure leaves last durable phase")
        var disk := SaveManager.load_slot(SLOT)
        _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "failure preserves last durable disk/live")
        var revision: int = GameState.revision
        for tick in range(3): await get_tree().process_frame
        _expect(GameState.revision == revision and manager.injected == 1, "no implicit retry")
        coordinator = ResetCoordinator.new(GameState, SaveManager)
        var retry: Dictionary
        if index == 0: retry = await _request(coordinator, reset_type)
        else: retry = await coordinator.resume_pending_reset_async(SLOT)
        _expect(retry.ok and retry.completed, "explicit retry resumes last durable phase")
    else:
        _expect(result.ok and result.completed and phase_events.size() == 8 and completed_events == 1, "ACK loss verified without repeating phase")
    _final(before, reset_type)
    cases.append({"kind":mode, "reset_type":reset_type, "phase":phase, "locale":locale, "passed":errors.size() == first})
    manager.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _run_to_stop(coordinator: ResetCoordinator, reset_type: String) -> void:
    async_result = await _request(coordinator, reset_type, "sleep_confirmed", _guard)
    async_done = true

func _stale_case(reset_type: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    var before := _reset_seed(reset_type)
    var revision: int = GameState.revision
    var coordinator := ResetCoordinator.new(GameState, SaveManager)
    _listen(coordinator)
    _guard_open = true
    async_done = false
    async_result = {}
    if scenario == "payload":
        var malformed := SaveManager.begin_history_write(GameState, SLOT, "SAVE_P6_COMPLETE", {"kind":"reset", "payload":[]}, revision, ARCHIVE.new_uid())
        _expect(not malformed.ok and malformed.error_id == "ERR_RESET_REQUEST" and SaveManager._notebook_job.is_empty(), "malformed reset request rejected before worker")
    _run_to_stop(coordinator, reset_type)
    _expect(not SaveManager._notebook_job.is_empty() and not async_done, "reset starts detached worker before durable install")
    _expect(GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "pending reset does not expose sleep phase")
    var job := SaveManager._notebook_job
    match scenario:
        "guard": _guard_open = false
        "revision": _expect(StateWriter.new(GameState).commit_atomic([{ "state_path":"meta_progress.servants.edgar.bond", "operation":"increment", "value":1}], GameState.revision, &"RESET_STALE").ok, "external revision mutation")
        "epoch": GameState.load_epoch += 1
        "cancel": SaveManager.cancel_notebook_reference(job.id)
        "root": SaveManager._storage_context = {"flavor":"full", "root":SaveManager.get_save_root() + "_other"}
        "source": _write(job.paths.main, FileAccess.get_file_as_string(job.paths.main) + " ")
        "busy":
            var rejected := await coordinator.request_normal_reset_async(SLOT)
            _expect(not rejected.ok and phase_events.is_empty(), "duplicate reset rejected while initial phase pending")
        "payload":
            var payload := {"operation":"advance", "phase":"idle"}
            var bad := ResetCoordinator.prepare_step(before, payload)
            _expect(not bad.ok and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "invalid phase candidate rejected without mutating source")
    var expected := GameState.get_snapshot()
    var started := Time.get_ticks_msec()
    while not async_done and Time.get_ticks_msec() - started < 60000: await get_tree().process_frame
    _expect(async_done, "pending reset deadline")
    SaveManager._storage_context = {}
    if scenario in ["busy", "payload"]:
        _expect(async_result.ok and phase_events.size() == 1, "unrelated rejected call cannot cancel valid worker")
    else:
        _expect(not async_result.ok and phase_events.is_empty() and completed_events == 0, "stale or cancelled reset never signals")
        _expect(StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "stale reset installs nothing")
    _guard_open = true
    cases.append({"kind":"stale", "reset_type":reset_type, "scenario":scenario, "locale":locale, "passed":errors.size() == first})
    SaveManager.delete_test_slot(SLOT)
