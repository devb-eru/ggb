extends "notebook_history_async_audit.gd"

const GAME := preload("res://scripts/autoload/game_state.gd")
const SCENARIOS := ["control", "epoch", "revision", "game_free", "game_queue", "service_queue", "service_detach", "guard"]
var done := false
var outcome: Dictionary = {}
var callbacks := 0

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for reset_type in ["normal", "broken"]:
            for scenario in SCENARIOS: await _completion_case(reset_type, scenario, locale)
        for scenario in ["queued_begin", "queued_pending", "detached_pending", "game_queued_pending"]:
            await _service_case(scenario, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":40,
        "scope":"HEADLESS final reset callback and real worker/service lifetime; not OS input, cross-process or performance acceptance"}
    print("RESET_LIFETIME_AUDIT: ", JSON.stringify(result))
    print("RESET_LIFETIME_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _local_seed(reset_type: String) -> Dictionary:
    var before := _seed()
    var game := GAME.new()
    add_child(game)
    if reset_type == "broken":
        before.fracture_state.camouflage_filter = "disabled"
        before.fracture_state.world_phase = "S2"
    before.meta_progress.servants.mara2.residual_memory = ["lifetime_original"]
    before.loop_state.inventory = ["OBJ_TEST_TEMP_KEY"]
    _expect(StateWriter.new(game).install_snapshot(before, game.revision, &"LOAD_LIFETIME_SEED").ok, "local seed installs")
    for index in range(2):
        _expect(SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", before, game.revision, "LIFETIME_SEED_%d" % index).ok, "local seed disk")
    var manager := STORAGE.new()
    add_child(manager)
    return {"game":game, "manager":manager, "snapshot":before}

func _launch(coordinator: ResetCoordinator, reset_type: String) -> void:
    outcome = await coordinator.request_broken_reset_async(SLOT, "", _guard) if reset_type == "broken" else await coordinator.request_normal_reset_async(SLOT, "", _guard)
    done = true

func _wait() -> void:
    var started := Time.get_ticks_msec()
    while not done and Time.get_ticks_msec() - started < 15000: await get_tree().process_frame
    _expect(done, "lifetime call returns a terminal result")

func _completion_case(reset_type: String, scenario: String, locale: String) -> void:
    var first := errors.size()
    var seed := _local_seed(reset_type)
    var game: Node = seed.game
    var manager: Node = seed.manager
    var coordinator := ResetCoordinator.new(game, manager)
    callbacks = 0
    _guard_open = true
    coordinator.reset_completed.connect(func(_id: StringName, _type: StringName, _revision: int) -> void:
        callbacks += 1
        match scenario:
            "epoch": game.load_epoch += 1
            "revision":
                _expect(StateWriter.new(game).commit_atomic([{"state_path":"meta_progress.servants.edgar.bond", "operation":"increment", "value":1}], game.revision, &"LIFETIME_EXTERNAL").ok, "completed callback changes revision")
            "game_free": game.free()
            "game_queue": game.queue_free()
            "service_queue": manager.queue_free()
            "service_detach": remove_child(manager)
            "guard": _guard_open = false)
    done = false
    outcome = {}
    _launch(coordinator, reset_type)
    await _wait()
    _expect(callbacks == 1, "completion notification exactly once")
    _expect(outcome.get("ok", false) == (scenario == "control"), "invalidated final callback rejects continuation: " + scenario)
    if scenario != "control" and done:
        _expect("NB_COMMAND_SCOPE" in outcome.get("error_ids", []), "invalidated callback has scope error")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and disk.snapshot.reset_state.phase == "idle", "already completed phase remains durable")
    if disk.ok:
        _expect(disk.snapshot.loop_state.day_index == seed.snapshot.loop_state.day_index + 1, "physical reset happens exactly once")
        _expect(not String(disk.snapshot.reset_state.last_completed_transaction_id).is_empty(), "completion receipt retained")
        _expect(StateSnapshotValidator.same_persisted_value(disk.snapshot.meta_progress, seed.snapshot.meta_progress), "permanent data unchanged by callback")
        var receipt: String = disk.snapshot.reset_state.last_completed_transaction_id
        var fresh := GAME.new()
        add_child(fresh)
        _expect(LoadCoordinator.new(fresh, SaveManager).load_and_install(SLOT).ok, "fresh owner loads durable result")
        var recovered := await ResetCoordinator.new(fresh, SaveManager).resume_pending_reset_async(SLOT)
        _expect(not recovered.ok and "ERR_RESET_NOT_PENDING" in recovered.get("error_ids", []), "idle receipt cannot replay pending reset")
        _expect(fresh.get_value("reset_state.last_completed_transaction_id") == receipt and fresh.get_value("loop_state.day_index") == disk.snapshot.loop_state.day_index, "rejected resume preserves exact receipt and day")
        fresh.free()
    if is_instance_valid(game) and not game.is_queued_for_deletion(): game.free()
    if is_instance_valid(manager) and not manager.is_queued_for_deletion(): manager.free()
    await get_tree().process_frame
    _guard_open = true
    cases.append({"kind":"completed", "reset_type":reset_type, "scenario":scenario, "locale":locale, "passed":errors.size() == first, "returned":done, "result":outcome})
    SaveManager.delete_test_slot(SLOT)

func _service_case(scenario: String, locale: String) -> void:
    var first := errors.size()
    var seed := _local_seed("normal")
    var game: Node = seed.game
    var manager: Node = seed.manager
    manager.set_process(false)
    var paths: Dictionary = manager._slot_paths(SLOT)
    var main := FileAccess.get_file_as_bytes(paths.main)
    var backup := FileAccess.get_file_as_bytes(paths.backup)
    var revision: int = game.revision
    var recording := {"kind":"reset", "payload":{"operation":"begin", "reset_type":"normal", "transaction_id":"RESET_LIFETIME_PENDING"}}
    var id := ARCHIVE.new_uid()
    if scenario == "queued_begin": manager.queue_free()
    var begun: Dictionary = manager.begin_history_write(game, SLOT, "SAVE_P6_COMPLETE", recording, revision, id)
    if scenario == "queued_begin":
        _expect(not begun.ok and begun.get("error_id") == "NB_COMMAND_SERVICE_UNAVAILABLE", "queued service refuses new work")
    else:
        _expect(begun.ok and begun.pending, "lifetime worker starts")
        await _prepared(manager)
        match scenario:
            "queued_pending": manager.queue_free()
            "detached_pending": remove_child(manager)
            "game_queued_pending": game.queue_free()
        manager._process(0.0)
        var terminal: Dictionary = manager.notebook_reference_result(id)
        _expect(not terminal.ok and not terminal.get("pending", false), "removed or queued owner cannot promote prepared work")
    _expect(FileAccess.get_file_as_bytes(paths.main) == main and FileAccess.get_file_as_bytes(paths.backup) == backup, "lifetime rejection preserves main and backup bytes")
    _expect(game.revision == revision and StateSnapshotValidator.same_persisted_value(game.get_snapshot(), seed.snapshot), "lifetime rejection installs no candidate")
    if is_instance_valid(manager) and not manager.is_queued_for_deletion(): manager.free()
    if is_instance_valid(game) and not game.is_queued_for_deletion(): game.free()
    await get_tree().process_frame
    _expect(not FileAccess.file_exists(paths.main.get_base_dir().path_join("progress.history_" + id + ".tmp.json")), "prepared private temporary cleaned on exit")
    cases.append({"kind":"service", "scenario":scenario, "locale":locale, "passed":errors.size() == first})
    SaveManager.delete_test_slot(SLOT)
