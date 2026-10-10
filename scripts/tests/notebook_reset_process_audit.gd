extends "notebook_reset_ui_audit.gd"

const SLEEP_FIXTURE := preload("notebook_campaign_sleep_audit.gd")
const PHASES := ["sleep_confirmed", "player_committed", "memory_committed", "physical_reset_complete", "morning_loaded", "route_selected", "complete", "idle"]
var phase := ""
var route := ""
var point := ""
var cut := ""
var case_dir := ""
var legacy_kind := ""

class CutStorage extends "res://scripts/autoload/save_manager.gd":
    var armed := false
    var point := ""
    var cut := ""
    var directory := ""
    var prior: Dictionary
    var failures: Array

    func _commit_prepared(paths: Dictionary, main: Dictionary, backup: Dictionary) -> Dictionary:
        var candidate := _validate_save_text(FileAccess.get_file_as_string(paths.temporary), paths.temporary)
        var hit: bool = armed and candidate.ok and ((point == "wake" and String(candidate.header.transaction_id).begins_with("WAKE_")) or (point != "wake" and candidate.snapshot.reset_state.phase == point))
        if hit and cut == "prepared": _freeze(paths, candidate)
        var result := super._commit_prepared(paths, main, backup)
        if hit and result.ok and cut == "promoted": _freeze(paths, candidate)
        return result

    func _freeze(paths: Dictionary, candidate: Dictionary) -> void:
        var disk := _read_and_validate(paths.main)
        var record := {"ok":disk.ok and failures.is_empty(), "errors":failures, "baseline":prior, "snapshot":disk.get("snapshot", {}),
            "candidate":candidate.snapshot, "phase":point, "cut":cut, "pid":OS.get_process_id(),
            "main_sha256":FileAccess.get_sha256(paths.main), "backup_sha256":FileAccess.get_sha256(paths.backup),
            "prepared_sha256":FileAccess.get_sha256(paths.temporary) if FileAccess.file_exists(paths.temporary) else ""}
        var file := FileAccess.open(directory.path_join("cut.json"), FileAccess.WRITE)
        if file == null: push_error("isolated cut receipt unavailable"); return
        file.store_string(JSON.stringify(record))
        file.close()
        print("RESET_PROCESS_CUT: ", JSON.stringify({"ok":record.ok, "pid":record.pid, "phase":point, "cut":cut}))
        # Freeze this exact real promotion boundary; the parent kills only this child.
        while true: OS.delay_msec(10)

func _argument(name: String) -> String:
    for value in OS.get_cmdline_user_args():
        if value.begins_with(name + "="): return value.trim_prefix(name + "=")
    return ""

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    phase = _argument("--reset-process-phase")
    route = _argument("--reset-process-route")
    point = _argument("--reset-process-point")
    cut = _argument("--reset-process-cut")
    case_dir = _argument("--reset-process-dir")
    legacy_kind = _argument("--reset-process-legacy")
    var locale := _argument("--reset-process-locale")
    TranslationServer.set_locale(locale)
    _expect(phase in ["seed", "resume", "verify"] and route in ["p6", "chapter", "mirror", "basement", "bedroom", "capsule", "rest"] and point in PHASES + ["wake"] and cut in ["prepared", "promoted"] and locale in ["ko_KR", "en_US"], "explicit process coordinates")
    _expect(legacy_kind in ["", "new", "replay", "pending"] and (legacy_kind.is_empty() or (legacy_kind == "pending" and route in ["chapter", "bedroom"] and point in PHASES and cut == "promoted") or (route in ["chapter", "mirror", "basement", "bedroom"] and point == "wake" and cut == "promoted")), "explicit legacy alias fixture coordinates")
    if phase == "seed":
        if legacy_kind in ["", "pending"]: await _seed_cut()
        else: _seed_legacy()
    else: await _recover()
    var result := {"ok":errors.is_empty(), "errors":errors, "checks":checks, "phase":phase, "route":route, "point":point, "cut":cut, "locale":locale,
        "legacy_kind":legacy_kind, "scope":"fresh HEADLESS process and actual bootstrap/P6 controls; legacy fixtures are not interrupted reset workers; no Windows physical input"}
    print("RESET_PROCESS_AUDIT: ", JSON.stringify(result))
    print("RESET_PROCESS_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _seed_legacy() -> void:
    var fixture := SLEEP_FIXTURE.new()
    var state: Dictionary = fixture._route_seed(route)
    errors.append_array(fixture.errors)
    checks += fixture.checks
    state.loop_state.location_id = "M1_BEDROOM"
    state.loop_state.event_local_states.CHAPTER_ONE.erase("last_feedback")
    state.loop_state.event_local_states.erase("NOTEBOOK_PRESENTATION")
    if route == "bedroom":
        state.fracture_state.broken_reset_triggered = true
        state.fracture_state.camouflage_filter = "broken"
        state.fracture_state.world_phase = "S3"
        state.meta_progress.knowledge_entries.erase("E1_wake_seen")
    _seed(state)
    if legacy_kind == "replay":
        var client = fixture._session(route, SaveManager)
        if route == "bedroom": state.meta_progress.knowledge_entries.E1_wake_seen = true
        var context := {"node_id":"E1_ENTRY" if route == "bedroom" else client.stage(), "chapter_id":"CHAPTER_3" if route == "bedroom" else client.history_chapter_id(), "location_id":"M1_BEDROOM"}
        var text: String = preload("res://scripts/systems/fracture_notebook.gd").TEXT.E1_WAKE if route == "bedroom" else preload("res://scripts/systems/chapter_one_notebook.gd").FIXED.WAKE
        var descriptors: Array = preload("res://scripts/systems/fracture_notebook.gd").paragraphs(["E1_WAKE"]) if route == "bedroom" else preload("res://scripts/systems/chapter_one_notebook.gd").paragraphs("WAKE")
        _expect(client._commit_feedback(state, text, "주인공", "", context, descriptors).ok, "genuine legacy feedback saved")
        var line := _line("NB_FRACTURE_E1_WAKE" if route == "bedroom" else "NB_CH1_WAKE", context.node_id)
        line.history_context = context
        _expect(WRITER.record(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", line.speaker, line.text, TranslationServer.get_locale(), context.chapter_id, [], _recording(line).context).ok, "genuine earlier alias observation durable")
    fixture.free()
    var manager := CutStorage.new()
    manager.point = point
    manager.cut = cut
    manager.directory = case_dir
    manager.prior = GameState.get_snapshot()
    manager.failures = errors
    add_child(manager)
    var paths := SaveManager._slot_paths(SLOT)
    var disk := SaveManager._read_and_validate(paths.main)
    _expect(disk.ok, "legacy alias fixture validated before cold start")
    manager._freeze(paths, disk)

func _seed_cut() -> void:
    if route == "p6":
        var state := _fixture_state()
        var progress: Dictionary = state.loop_state.event_local_states.PROLOGUE
        for flag in ["P1_complete", "P2_complete", "P3_complete", "P3B_complete", "P4_complete"]: progress[flag] = true
        progress.intros_seen = ["P6"]
        progress.time_block = "night"
        state.meta_progress.servants.edgar.bond = 2
        state.meta_progress.servants.mara2.residual_memory = ["PROCESS_KEEP"]
        _seed(state)
    else:
        var fixture := SLEEP_FIXTURE.new()
        fixture._route_seed(route)
        errors.append_array(fixture.errors)
        checks += fixture.checks
        fixture.free()
    var shown := _line("NB_PR_DUTY_1", "PG")
    _expect(WRITER.record(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", shown.speaker, shown.text, TranslationServer.get_locale(), "PROLOGUE", [], _recording(shown).context).ok, "past authored original present before sleep")
    var state := GameState.get_snapshot()
    var archive: Dictionary = state.meta_progress.dialogue_history
    var entry: Dictionary = archive.entries.back()
    var reference := ARCHIVE.make_reference(entry, entry.observation.segments[0].segment_id)
    for collection in ["bookmarks", "comparison"]:
        var pinned := ARCHIVE.set_reference(archive, collection, reference, true, archive.revision)
        _expect(pinned.ok, "pin actual original before process cut")
        if pinned.ok: archive = pinned.archive
    state.meta_progress.dialogue_history = archive
    _expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_PROCESS_PINS").ok, "install valid fixture references")
    _expect(SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", state, GameState.revision, "PROCESS_BASELINE").ok, "fixture references durable")
    var manager := CutStorage.new()
    manager.point = point
    manager.cut = cut
    manager.directory = case_dir
    manager.prior = GameState.get_snapshot()
    manager.failures = errors
    add_child(manager)
    if route == "p6":
        var host = MAIN.instantiate()
        add_child(host)
        var view = PROLOGUE.new()
        view.configure_session(SLOT, "P6_ENTRY")
        host.add_child(view)
        await _natural_settle(view)
        host._reset_coordinator = ResetCoordinator.new(GameState, manager)
        view._hotspot_layer.get_node("BED").pressed.emit()
        await _natural_settle(view)
        var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
        _expect(buttons.size() == 2, "real P6 sleep confirmation")
        buttons[0].pressed.emit()
        await _natural_settle(view)
        view._dialogue_next.pressed.emit()
        await _natural_settle(view)
        manager.armed = true
        view._dialogue_next.pressed.emit()
        while true: await get_tree().process_frame
    else:
        manager.armed = true
        var fixture := SLEEP_FIXTURE.new()
        var client = fixture._session(route, manager)
        fixture.free()
        var outcome: Dictionary = await client.sleep_async()
        _expect(false, "expected real persistence cut not reached: " + JSON.stringify(outcome))

func _host_settle(host: Node) -> void:
    var started := Time.get_ticks_msec()
    while Time.get_ticks_msec() - started < 60000:
        await get_tree().process_frame
        var view = host._prologue
        if host._reset_async_pending or not is_instance_valid(view): continue
        if view._reset_transition_pending or not view._normal_reset_request.is_empty(): continue
        if not view._prologue_async_request.is_empty(): continue
        if view is ChapterOneController and not view._history_async_request.is_empty(): continue
        if not SaveManager._notebook_job.is_empty(): continue
        return
    _expect(false, "cold bootstrap and displayed records settle")

func _preserved(before: Dictionary, after: Dictionary) -> void:
    _expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.servants, after.meta_progress.servants), "all relationships/memories exact across process")
    var old: Dictionary = before.meta_progress.dialogue_history
    var next: Dictionary = after.meta_progress.dialogue_history
    for key in ["source_origin_id", "branch_id", "bookmarks", "comparison"]:
        _expect(StateSnapshotValidator.same_persisted_value(old.get(key), next.get(key)), "archive/ref identity exact: " + key)
    for entry in old.entries:
        var rows: Array = next.entries.filter(func(row: Dictionary) -> bool: return row.entry_uid == entry.entry_uid)
        _expect(rows.size() == 1 and StateSnapshotValidator.same_persisted_value(entry, rows[0]), "original immutable across process: " + entry.entry_uid)
    for key in before.meta_progress.knowledge_entries:
        if key == "chapter_notebook":
            var old_notes: Dictionary = before.meta_progress.knowledge_entries[key]
            var new_notes: Dictionary = after.meta_progress.knowledge_entries.get(key, {})
            for note in old_notes:
                _expect(StateSnapshotValidator.same_persisted_value(old_notes[note], new_notes.get(note)), "prior projected note exact: " + note)
            for note in new_notes:
                if note not in old_notes:
                    _expect(note == "NOTE_E1_WAKE" and route in ["bedroom", "capsule"] and new_notes[note] == preload("res://scripts/systems/fracture_notebook.gd").NOTES.E1_WAKE, "only actual E1 acquisition may extend projected notes")
        else:
            _expect(StateSnapshotValidator.same_persisted_value(before.meta_progress.knowledge_entries[key], after.meta_progress.knowledge_entries.get(key)), "prior knowledge exact: " + key)

func _recover() -> void:
    var evidence: Variant = JSON.parse_string(FileAccess.get_file_as_string(case_dir.path_join("cut.json")))
    _expect(evidence is Dictionary and evidence.ok, "actual terminated child receipt valid")
    if not evidence is Dictionary: return
    var prior := evidence.snapshot as Dictionary
    if phase == "verify": prior = JSON.parse_string(FileAccess.get_file_as_string(case_dir.path_join("resumed_snapshot.json")))
    var paths := SaveManager._slot_paths(SLOT)
    var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
    _expect(loaded.ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), prior), "fresh process installs exact last durable snapshot")
    if phase == "resume":
        _expect(FileAccess.get_sha256(paths.main) == evidence.main_sha256 and FileAccess.get_sha256(paths.backup) == evidence.backup_sha256, "load cannot rewrite main/backup before actual recovery")
    var events := []
    var host = MAIN.instantiate()
    add_child(host)
    host._reset_coordinator.reset_phase_committed.connect(func(_id: StringName, value: StringName, _revision: int) -> void: events.append(String(value)))
    host._on_load_game_requested(SLOT)
    await _host_settle(host)
    var view = host._prologue
    if phase == "resume" and route == "p6":
        _expect(is_instance_valid(view) and view.get_script() == PROLOGUE, "first P6 cold recovery must restore unobserved R1 instead of skipping into campaign")
        if is_instance_valid(view) and view.get_script() == PROLOGUE:
            _expect(view._dialogue_active and view._dialogue_lines[0].notebook_content.content_id == "NB_PR_R1_WAKE", "actual first waking presentation restored")
            view.campaign_requested.connect(func(_slot: String) -> void:
                var state := GameState.get_snapshot()
                var cursor := preload("res://scripts/systems/notebook_presentation.gd").read(state)
                _expect(cursor.get("phase") == "completed" and preload("res://scripts/systems/notebook_presentation.gd").matches(cursor, state), "first-wake completion marker and cursor anchor commit together")
                _expect(state.meta_progress.knowledge_entries.get("PROLOGUE_FIRST_WAKE_COMPLETED", false), "handoff follows durable first-wake completion")
            )
            for index in range(3):
                view._dialogue_next.pressed.emit()
                await _host_settle(host)
            var started := Time.get_ticks_msec()
            while is_instance_valid(host._prologue) and host._prologue.get_script() == PROLOGUE and Time.get_ticks_msec() - started < 60000:
                await get_tree().process_frame
            await _host_settle(host)
            _expect(is_instance_valid(host._prologue) and host._prologue is ChapterOneController, "completed R1 deferred handoff settles before cold re-open snapshot")
    var after := GameState.get_snapshot()
    _expect(after.loop_state.location_id == "M2_BEDROOM", "fresh wake installs canonical bedroom")
    if legacy_kind.is_empty() and (point == "wake" or PHASES.find(point) >= PHASES.find("physical_reset_complete")):
        _expect(evidence.candidate.loop_state.location_id == "M2_BEDROOM", "new physical/wake candidate already uses canonical bedroom")
    var feedback: Dictionary = after.loop_state.event_local_states.CHAPTER_ONE.last_feedback
    var uncommitted_rest: bool = legacy_kind.is_empty() and route == "rest" and point == "wake" and cut == "prepared"
    var expected_location := "LEGACY_UNKNOWN" if uncommitted_rest else ("M1_BEDROOM" if legacy_kind == "replay" else "M2_BEDROOM")
    _expect(feedback.history_context.location_id == expected_location, "new waking source canonical; old feedback source unchanged")
    var cursor := CURSOR.read(after)
    _expect(not cursor.get("lines", []).is_empty(), "wake presentation has actual displayed lines")
    for line in cursor.get("lines", []):
        _expect(line.get("history_context", {}).get("location_id") == expected_location, "wake presentation records genuine source bedroom")
    var old_uids: Array = evidence.baseline.meta_progress.dialogue_history.entries.map(func(row: Dictionary) -> String: return row.entry_uid)
    var wake_count := 0
    for entry in after.meta_progress.dialogue_history.entries:
        if entry.entry_uid in old_uids or not entry.has("observation"): continue
        var observation: Dictionary = entry.observation
        if observation.get("content_id") not in ["NB_CH1_WAKE", "NB_FRACTURE_E1_WAKE", "NB_FRACTURE_NOTE_E1_WAKE", "NB_FRACTURE_POST_REST"]: continue
        wake_count += 1
        _expect(observation.location_id == expected_location, "authored waking source uses genuine bedroom: " + observation.content_id)
    if uncommitted_rest:
        _expect(wake_count == 0, "uncommitted rest cannot fabricate an authored waking source")
        var origin: Dictionary = feedback.get("legacy_feedback_origin", {})
        _expect(StateSnapshotValidator.same_persisted_value(origin.get("feedback"), evidence.baseline.loop_state.event_local_states.CHAPTER_ONE.last_feedback), "uncommitted rest retains genuine prior legacy feedback instead of relabeling it")
    else:
        _expect(wake_count > 0, "actual authored wake observed rather than merely normalized live position")
    var expected_day: int = int(evidence.baseline.loop_state.day_index) + (0 if route == "rest" or legacy_kind in ["new", "replay"] else 1)
    _expect(after.loop_state.day_index == expected_day and after.reset_state.phase == "idle", "fresh process completes exactly one reset or unchanged post-fracture rest")
    _preserved(evidence.baseline, after)
    _preserved(prior, after)
    if route in ["bedroom", "capsule", "rest"]:
        _expect(after.fracture_state.broken_reset_triggered and after.meta_progress.knowledge_entries.get("E1_wake_seen", false), "broken route initializes E1 only from durable state")
    var expected_events: Array = []
    if prior.reset_state.phase != "idle": expected_events = PHASES.slice(PHASES.find(prior.reset_state.phase) + 1)
    _expect(events == expected_events, "committed reset phases never repeat in new process")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, after), "new process disk/live exact")
    if phase == "verify":
        _expect(StateSnapshotValidator.same_persisted_value(prior, after) and prior.reset_state.last_completed_transaction_id == after.reset_state.last_completed_transaction_id, "second cold load preserves completed snapshot and cannot repeat wake/reset")
    var file := FileAccess.open(case_dir.path_join("verified_snapshot.json" if phase == "verify" else "resumed_snapshot.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(after))
    file.close()
    var details := {"phase":phase, "route":route, "point":point, "cut":cut, "pid":OS.get_process_id(), "reset_events":events,
        "day_before":prior.loop_state.day_index, "day_after":after.loop_state.day_index, "phase_before":prior.reset_state.phase, "phase_after":after.reset_state.phase,
        "reset_receipt":after.reset_state.last_completed_transaction_id, "main_sha256":FileAccess.get_sha256(paths.main), "backup_sha256":FileAccess.get_sha256(paths.backup)}
    var output := FileAccess.open(case_dir.path_join(phase + "_details.json"), FileAccess.WRITE)
    output.store_string(JSON.stringify(details))
    output.close()
    host.free()
    await get_tree().process_frame
