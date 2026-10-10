extends "notebook_history_async_audit.gd"

const SESSIONS := [preload("res://scripts/systems/chapter_one_session.gd"), preload("res://scripts/systems/black_mirror_session.gd"), preload("res://scripts/systems/basement_session.gd")]
const ROUTES := ["chapter", "mirror", "basement", "bedroom", "capsule", "rest"]
const FAULTS := ["success", "wake_reject", "wake_ack", "reset_reject"]
var done := false
var outcome: Dictionary = {}

class SleepStorage extends "res://scripts/autoload/save_manager.gd":
    var fault := "success"
    var injected := 0
    var begins: Array = []
    var pending_snapshots: Array = []
    func begin_history_write(game: Node, slot: String, point: String, recording: Dictionary, revision: int, id: String, guard: Callable = Callable()) -> Dictionary:
        var started := super.begin_history_write(game, slot, point, recording, revision, id, guard)
        if started.ok:
            begins.append(recording.kind)
            if recording.kind == "wake": pending_snapshots.append(game.get_snapshot())
        return started
    func _commit_prepared(paths: Dictionary, main: Dictionary, backup: Dictionary) -> Dictionary:
        var checked := _validate_save_text(FileAccess.get_file_as_string(paths.temporary), paths.temporary)
        var wake: bool = checked.ok and String(checked.header.transaction_id).begins_with("WAKE_")
        var hit: bool = injected == 0 and ((wake and fault in ["wake_reject", "wake_ack"]) or (fault == "reset_reject" and checked.ok and checked.snapshot.reset_state.phase == "physical_reset_complete"))
        if hit and fault != "wake_ack":
            injected += 1
            return _load_failure(&"TEST_SLEEP_PROMOTION")
        var result := super._commit_prepared(paths, main, backup)
        if hit and result.ok:
            injected += 1
            return _load_failure(&"TEST_SLEEP_ACK")
        return result

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for route in ROUTES:
            for fault in FAULTS:
                if route == "rest" and fault == "reset_reject": continue
                await _sleep_case(route, fault, locale)
        for scenario in ["guard", "cancel", "epoch", "revision", "busy", "payload"]:
            await _scope_case(scenario, locale)
        for field in ["family", "transaction", "relation", "knowledge", "entry", "reference", "ledger", "prune", "shape"]: _payload_case(field, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":76,
        "scope":"HEADLESS real session initialization chain, reset worker and wake worker/disk; not physical OS input, cross-process recovery, controller or performance acceptance"}
    print("CAMPAIGN_SLEEP_AUDIT: ", JSON.stringify(result))
    print("CAMPAIGN_SLEEP_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _route_seed(route: String) -> Dictionary:
    var id: String = {"chapter":"AS", "mirror":"C_SLEEP", "basement":"D_SLEEP", "bedroom":"D6", "capsule":"D6", "rest":"E1_ENTRY"}[route]
    var built := CHECKPOINTS.new().snapshot_for(id)
    _expect(built.ok, "checkpoint adapts for " + route)
    var state: Dictionary = built.snapshot
    state.loop_state.location_id = "H0_SERVICE_SPINE" if route == "capsule" else "M2_BEDROOM"
    var local: Dictionary = state.loop_state.event_local_states.get("CHAPTER_ONE", {})
    local.routine_done = true
    state.loop_state.event_local_states.CHAPTER_ONE = local
    if route == "capsule": state.loop_state.event_local_states.D6 = {"fracture_rest_route":"emergency_capsule"}
    if route == "rest":
        state.meta_progress.knowledge_entries.E1_wake_seen = true
        var notes := preload("res://scripts/systems/fracture_notebook.gd")
        var written := notes.write(state, "E1_WAKE", notes.NOTES.E1_WAKE, {"node_id":"E1_ENTRY", "chapter_id":"CHAPTER_3", "location_id":"M2_BEDROOM"}, TranslationServer.get_locale())
        _expect(written.ok, "rest fixture retains an actually observed E1 knowledge revision")
    var archive: Dictionary = state.meta_progress.dialogue_history
    if not archive.entries.is_empty():
        var entry: Dictionary = archive.entries[0]
        var reference := ARCHIVE.make_reference(entry, "legacy" if entry.record_class in ["legacy", "unmapped"] else entry.observation.segments[0].segment_id)
        for collection in ["bookmarks", "comparison"]:
            var pinned := ARCHIVE.set_reference(archive, collection, reference, true, archive.revision)
            _expect(pinned.ok, "seed protected reference " + collection)
            if pinned.ok: archive = pinned.archive
        state.meta_progress.dialogue_history = archive
    _seed(state)
    if route == "rest":
        var line := _line("NB_PR_P1_INSPECT_BED", "P1")
        _expect(WRITER.record(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", line.speaker, line.text, TranslationServer.get_locale(), "PROLOGUE", [], _recording(line).context).ok, "rest fixture retains an unprotected past prologue observation")
    return GameState.get_snapshot()

func _session(route: String, manager: Node):
    return SESSIONS[0 if route == "chapter" else (1 if route == "mirror" else 2)].new(GameState, manager, SLOT)

func _launch(session) -> void:
    outcome = await session.sleep_async(_guard)
    done = true

func _wait_done() -> void:
    var started := Time.get_ticks_msec()
    while not done and Time.get_ticks_msec() - started < 120000: await get_tree().process_frame
    _expect(done, "sleep reaches a terminal result")

func _preserved(before: Dictionary, after: Dictionary) -> void:
    _expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.servants, after.meta_progress.servants), "all relationships and residual memories preserved")
    var old: Dictionary = before.meta_progress.dialogue_history
    var next: Dictionary = after.meta_progress.dialogue_history
    for key in ["source_origin_id", "branch_id", "bookmarks", "comparison"]:
        _expect(StateSnapshotValidator.same_persisted_value(old.get(key), next.get(key)), "archive identity and references retained: " + key)
    for entry in old.entries:
        var rows: Array = next.entries.filter(func(row: Dictionary) -> bool: return row.entry_uid == entry.entry_uid)
        _expect(rows.size() == 1 and StateSnapshotValidator.same_persisted_value(entry, rows[0]), "existing archive entry exact: " + entry.entry_uid)

func _sleep_case(route: String, fault: String, locale: String) -> void:
    var first := errors.size()
    var before := _route_seed(route)
    var manager := SleepStorage.new()
    manager.fault = fault
    add_child(manager)
    var session = _session(route, manager)
    _guard_open = true
    var result: Dictionary = await session.sleep_async(_guard)
    if fault in ["wake_reject", "reset_reject"]:
        _expect(not result.ok and manager.injected == 1, "selected promotion failure is explicit")
        var failed := GameState.get_snapshot()
        var disk := manager.load_slot(SLOT)
        _expect(disk.ok and StateSnapshotValidator.same_persisted_value(failed, disk.snapshot), "failure preserves exact last durable snapshot")
        if fault == "wake_reject":
            _expect(not session._sleep_wake_pending.is_empty() and failed.reset_state.phase == "idle", "wake retry retains completed reset receipt")
            if route in ["bedroom", "capsule"]:
                _expect(not failed.meta_progress.knowledge_entries.get("E1_wake_seen", false), "failed wake does not reveal E1 or write its observation")
            _expect(not session.sleep().ok, "synchronous sleep cannot overlap pending wake retry")
        var revision: int = GameState.revision
        for tick in range(3): await get_tree().process_frame
        _expect(GameState.revision == revision, "failure does not implicitly retry")
        result = await session.sleep_async(_guard)
    _expect(result.ok and session._sleep_wake_pending.is_empty() and not session._sleep_async_running, "explicit sleep completes all durable boundaries")
    var after := GameState.get_snapshot()
    _expect(after.loop_state.day_index == before.loop_state.day_index + (0 if route == "rest" else 1), "retry advances exactly one physical day or no day for rest")
    _expect(manager.begins.count("reset") == (0 if route == "rest" else (9 if fault == "reset_reject" else 8)), "committed reset phases never repeat")
    _expect(manager.begins.count("wake") == (2 if fault == "wake_reject" else 1), "wake worker count matches explicit retry only")
    _expect(manager.pending_snapshots.size() > 0, "wake persists through actual detached worker")
    for pending in manager.pending_snapshots:
        _expect(pending.loop_state.day_index == after.loop_state.day_index, "wake candidate capture cannot advance another day")
        if route in ["bedroom", "capsule"]:
            _expect(not pending.meta_progress.knowledge_entries.get("E1_wake_seen", false), "draft initialization never installs E1 prematurely")
    _preserved(before, after)
    var disk := manager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(after, disk.snapshot), "final disk and live state exact")
    if route in ["bedroom", "capsule"]:
        _expect(after.meta_progress.knowledge_entries.get("E1_wake_seen", false) and after.fracture_state.broken_reset_triggered and result.stage == "E1_ENTRY", "broken sleep wakes into E1 after durability")
    if route == "rest":
        _expect(StateSnapshotValidator.same_persisted_value(after.reset_state, before.reset_state), "post-fracture rest does not reset world")
    cases.append({"kind":"session", "route":route, "fault":fault, "locale":locale, "passed":errors.size() == first, "worker_kinds":manager.begins})
    manager.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _payload_case(field: String, locale: String) -> void:
    var first := errors.size()
    var before := _route_seed("rest")
    var worker := preload("res://scripts/systems/notebook_save_worker.gd").new()
    var payload := {"family":"basement_session", "snapshot":before.duplicate(true), "reset_transaction_id":before.reset_state.last_completed_transaction_id}
    _expect(worker._prepare_wake(before, payload).ok, "unchanged wake candidate validates")
    match field:
        "family": payload.family = "unrecognized_session"
        "transaction": payload.reset_transaction_id = "unrelated-reset"
        "relation": payload.snapshot.meta_progress.servants.edgar.bond += 1
        "knowledge": payload.snapshot.meta_progress.knowledge_entries.F0_E_complete = true
        "shape": payload.snapshot.meta_progress.knowledge_entries = []
        "entry": payload.snapshot.meta_progress.dialogue_history.entries[0].entry_uid = ARCHIVE.new_uid()
        "reference": payload.snapshot.meta_progress.dialogue_history.bookmarks = []
        "ledger":
            var metadata: Dictionary = payload.snapshot.meta_progress.knowledge_entries.notebook_knowledge.revisions[0].metadata
            metadata.provenance_state = "unverified" if metadata.provenance_state == "authenticated" else "authenticated"
        "prune":
            var rows: Array = payload.snapshot.meta_progress.dialogue_history.entries
            var found := -1
            for index in range(rows.size()):
                if rows[index].record_class == "authored" and ARCHIVE._reasons(payload.snapshot.meta_progress.dialogue_history, rows[index]).is_empty():
                    found = index
                    break
            _expect(found >= 0, "prune mutation has an actual unprotected entry below quota")
            if found >= 0: rows.remove_at(found)
    _expect(not worker._prepare_wake(before, payload).ok, "wake scope rejects " + field)
    _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "payload rejection leaves live state exact")
    cases.append({"kind":"payload", "field":field, "locale":locale, "passed":errors.size() == first})
    SaveManager.delete_test_slot(SLOT)

func _scope_case(scenario: String, locale: String) -> void:
    var first := errors.size()
    var before := _route_seed("rest")
    var manager := SleepStorage.new()
    add_child(manager)
    manager.set_process(false)
    var session = _session("rest", manager)
    _guard_open = true
    done = false
    outcome = {}
    _launch(session)
    _expect(not done and manager._notebook_job.get("write_kind") == "wake", "rest starts pending wake before any installation")
    _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "pending wake live state exact")
    var job := manager._notebook_job
    match scenario:
        "guard": _guard_open = false
        "cancel": manager.cancel_notebook_reference(job.id)
        "epoch": GameState.load_epoch += 1
        "revision": _expect(StateWriter.new(GameState).commit_atomic([{ "state_path":"meta_progress.servants.edgar.bond", "operation":"increment", "value":1}], GameState.revision, &"WAKE_STALE").ok, "external revision mutation")
        "busy":
            _expect(not (await session.sleep_async(_guard)).ok and not session.sleep().ok, "both duplicate sleep APIs blocked")
        "payload":
            var malformed := manager.begin_history_write(GameState, SLOT, "SAVE_CAMPAIGN_PROGRESS", {"kind":"wake", "payload":[]}, GameState.revision, ARCHIVE.new_uid())
            _expect(not malformed.ok, "malformed overlap cannot disturb valid request")
    var expected := GameState.get_snapshot()
    manager.set_process(true)
    await _wait_done()
    if scenario in ["busy", "payload"]:
        _expect(outcome.ok and session._sleep_wake_pending.is_empty(), "unrelated invalid overlap preserves valid wake")
    else:
        _expect(not outcome.ok and not session._sleep_wake_pending.is_empty(), "stale or cancelled wake cannot install")
        _expect(StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "stale wake does not overwrite newer live state")
        if scenario in ["guard", "cancel"]:
            _guard_open = true
            _expect((await session.sleep_async(_guard)).ok, "guard cancellation supports explicit wake-only retry")
        else:
            _expect(not (await session.sleep_async(_guard)).ok, "old session cannot retry after epoch/revision replacement")
    cases.append({"kind":"scope", "scenario":scenario, "locale":locale, "passed":errors.size() == first})
    _guard_open = true
    manager.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
