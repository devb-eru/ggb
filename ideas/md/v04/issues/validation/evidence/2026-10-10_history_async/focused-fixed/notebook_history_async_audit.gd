extends Node

const STORAGE := preload("res://scripts/autoload/save_manager.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const FIXTURES := preload("res://scripts/tests/notebook_performance_fixture.gd")
const VIEWS := [preload("res://scripts/chapters/chapter_one_controller.gd"), preload("res://scripts/chapters/black_mirror_controller.gd"), preload("res://scripts/chapters/basement_controller.gd")]
const SLOT := "__test_history_async"
var errors: Array = []
var checks := 0
var cases: Array = []
var timings: Array = []
var _guard_open := true
var _last_wait_frame_ms := 0.0

class FailedPromotion extends "res://scripts/autoload/save_manager.gd":
    func _promote_temporary(_paths: Dictionary) -> Error: return ERR_CANT_CREATE

class LostAcknowledgement extends "res://scripts/autoload/save_manager.gd":
    func _commit_prepared(paths: Dictionary, main: Dictionary, backup: Dictionary) -> Dictionary:
        var result := super._commit_prepared(paths, main, backup)
        return _load_failure(&"TEST_LOST_ACK") if result.ok else result

func _expect(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)

func _guard() -> bool: return _guard_open

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in ["success", "cancel", "revision", "reload", "root", "guard", "disk", "backup", "pending", "temporary", "future", "missing_id", "promotion", "ack", "busy", "unchanged", "input_mutation"]:
            await _scenario(scenario, locale)
        for index in range(3):
            for scenario in ["success", "promotion", "replace", "locale", "storage"]:
                await _ui(index, scenario, locale)
        for id in FIXTURES.IDS: await _large(id, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":72, "timings":timings,
        "scope":"HEADLESS actual Control callbacks and disk saves; not physical Windows input or p95"}
    print("HISTORY_ASYNC_AUDIT: ", JSON.stringify(result))
    print("HISTORY_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _line(id: String = "NB_PR_DUTY_1", node: String = "P1") -> Dictionary:
    var row := CONTENT.definition(id, 1)
    var segments := {}
    for segment in row.visible_segment_ids: segments[segment] = {}
    var descriptor := CONTENT.descriptor(id, 1, segments)
    var display := CONTENT.presentation(descriptor, TranslationServer.get_locale())
    _expect(display.ok, "authored source display")
    return {"speaker":display.speaker, "text":display.text, "notebook_content":descriptor,
        "history_context":{"node_id":node, "chapter_id":"PROLOGUE" if node == "P1" else ("CHAPTER_1" if node == "A1" else "CHAPTER_2"), "location_id":"M2_BEDROOM"}, "presentation_token":ARCHIVE.new_uid()}

func _recording(line: Dictionary) -> Dictionary:
    var context: Dictionary = line.history_context.duplicate(true)
    context.notebook_content = line.notebook_content
    context.presentation_token = line.presentation_token
    context.event_occurrence_id = ARCHIVE.new_uid()
    context.conversation_session_id = ARCHIVE.new_uid()
    return {"kind":"dialogue", "speaker":line.speaker, "text":line.text, "locale":TranslationServer.get_locale(), "chapter":context.chapter_id, "facts":[], "context":context}

func _seed(state: Dictionary = {}) -> Dictionary:
    SaveManager.delete_test_slot(SLOT)
    GameState.reset_for_test()
    if state.is_empty(): state = GameState.make_default_snapshot()
    _expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_HISTORY_SEED").ok, "seed live state")
    for index in range(2): _expect(SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", state, GameState.revision, "HISTORY_SEED_%d" % index).ok, "seed disk and backup")
    return GameState.get_snapshot()

func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    _expect(file != null, "isolated fault file writable")
    if file == null: return
    file.store_string(text)
    file.close()

func _prepared(manager: Node) -> int:
    var start := Time.get_ticks_msec()
    var frames := 0
    var previous := Time.get_ticks_usec()
    _last_wait_frame_ms = 0.0
    while not manager._notebook_job.is_empty() and manager._notebook_job.thread.is_alive():
        if Time.get_ticks_msec() - start > 60000:
            _expect(false, "worker preparation deadline")
            break
        frames += 1
        await get_tree().process_frame
        var now := Time.get_ticks_usec()
        _last_wait_frame_ms = maxf(_last_wait_frame_ms, (now - previous) / 1000.0)
        previous = now
    return frames

func _scenario(scenario: String, locale: String) -> void:
    var begin_errors := errors.size()
    var before := _seed()
    var manager: Node = FailedPromotion.new() if scenario == "promotion" else (LostAcknowledgement.new() if scenario == "ack" else STORAGE.new())
    add_child(manager)
    manager.set_process(false)
    var paths: Dictionary = manager._slot_paths(SLOT)
    var recording := _recording(_line())
    var expected_recording := recording.duplicate(true)
    if scenario == "missing_id": recording.context.erase("notebook_content")
    if scenario == "future":
        var full: Dictionary = manager._read_and_validate(paths.main)
        full.header.schema_version = 999
        _write(paths.main, manager._encode_payload(full.header, full.snapshot).text)
    var original_main := FileAccess.get_file_as_bytes(paths.main)
    var original_backup := FileAccess.get_file_as_bytes(paths.backup)
    var revision: int = GameState.revision
    _guard_open = true
    var id := ARCHIVE.new_uid()
    var started: Dictionary = manager.begin_history_write(GameState, SLOT, "SAVE_CAMPAIGN_PROGRESS", recording, revision, id, _guard)
    _expect(started.ok and started.pending, scenario + " starts pending")
    _expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before) and GameState.revision == revision, scenario + " no tentative live installation")
    if scenario == "input_mutation":
        recording.text = "caller mutation"
        recording.context.notebook_content = {}
    if scenario == "busy":
        _expect(manager.begin_history_write(GameState, SLOT, "SAVE_CAMPAIGN_PROGRESS", recording, revision, ARCHIVE.new_uid()).get("error_id") == "NB_COMMAND_BUSY", "history requests serialize")
        _expect(manager.begin_notebook_reference(GameState, SLOT, "bookmarks", {}, true, "", revision, ARCHIVE.new_uid()).get("error_id") == "NB_COMMAND_BUSY", "reference requests share ownership")
        _expect(not manager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", before, revision, "RACING_SYNC").ok, "same-slot synchronous write refuses pending history")
    var frames := await _prepared(manager)
    match scenario:
        "cancel": manager.cancel_notebook_reference(id)
        "guard": _guard_open = false
        "revision", "reload":
            _expect(StateWriter.new(GameState).install_snapshot(before, GameState.revision, &"LOAD_OTHER" if scenario == "reload" else &"OTHER_REVISION").ok, "external state replacement")
        "root": manager._storage_context = {"flavor":"full", "root":"user://other_root"}
        "disk": _write(paths.main, FileAccess.get_file_as_string(paths.main) + " ")
        "backup": _write(paths.backup, FileAccess.get_file_as_string(paths.backup) + " ")
        "pending": _write(paths.temporary, "external ordinary temporary")
        "temporary": _write(manager._notebook_job.paths.temporary, "corrupt prepared candidate")
    var live_before_dispatch := GameState.get_snapshot()
    var live_revision: int = GameState.revision
    manager._process(0.0)
    var result: Dictionary = manager.notebook_reference_result(id)
    var success := scenario in ["success", "busy", "unchanged", "ack", "input_mutation"]
    _expect(result.get("ok", false) == success, scenario + " exact commit outcome")
    _expect(not result.get("pending", false), scenario + " terminal result")
    if success:
        _expect(frames > 0 and GameState.revision == revision + 1, "scene frames progress and exactly one durable installation")
        var disk := SaveManager._read_and_validate(paths.main)
        _expect(disk.ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), disk.snapshot), "disk and live state exact")
        _expect(disk.header.state_revision == GameState.revision, "persisted revision matches installation")
        _expect(result.get("recovered_acknowledgement", false) == (scenario == "ack"), "ACK recovery is explicit")
        var committed: Array = disk.snapshot.meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.entry_uid == result.entry_uid)
        _expect(committed.size() == 1 and committed[0].observation.segments[0].captured_text == expected_recording.text, "exact original observation preserved")
        if scenario == "unchanged":
            var main := FileAccess.get_file_as_bytes(paths.main)
            var expected := GameState.get_snapshot()
            var repeated := ARCHIVE.new_uid()
            _expect(manager.begin_history_write(GameState, SLOT, "SAVE_CAMPAIGN_PROGRESS", recording, GameState.revision, repeated).ok, "duplicate starts")
            await _prepared(manager)
            manager._process(0.0)
            var no_op: Dictionary = manager.notebook_reference_result(repeated)
            _expect(no_op.ok and not no_op.changed and no_op.entry_uid == result.entry_uid, "duplicate token remains idempotent")
            _expect(FileAccess.get_file_as_bytes(paths.main) == main and StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "duplicate changes neither disk nor live state")
    else:
        _expect(StateSnapshotValidator.same_persisted_value(live_before_dispatch, GameState.get_snapshot()) and GameState.revision == live_revision, scenario + " rejects without tentative state or rollback bump")
        if scenario not in ["disk", "backup"]: _expect(FileAccess.get_file_as_bytes(paths.main) == original_main, scenario + " primary preserved")
        if scenario not in ["backup", "promotion"]: _expect(FileAccess.get_file_as_bytes(paths.backup) == original_backup, scenario + " backup preserved")
    _expect(not FileAccess.file_exists(paths.main.get_base_dir().path_join("progress.history_" + id + ".tmp.json")), "unique temporary cleaned")
    cases.append({"kind":"api", "scenario":scenario, "locale":locale, "passed":errors.size() == begin_errors})
    manager.free()
    SaveManager.delete_test_slot(SLOT)

func _settle(view: Node) -> void:
    var start := Time.get_ticks_msec()
    while is_instance_valid(view) and not view._history_async_request.is_empty():
        if Time.get_ticks_msec() - start > 60000:
            _expect(false, "UI pending deadline")
            break
        await get_tree().process_frame

func _ui(index: int, scenario: String, locale: String) -> void:
    var begin_errors := errors.size()
    var fixture := CHECKPOINTS.new().snapshot_for(["A1", "C0", "D0"][index])
    _expect(fixture.ok, "UI checkpoint")
    fixture.snapshot.meta_progress.dialogue_history = ARCHIVE.create()
    fixture.snapshot.meta_progress.knowledge_entries.erase("notebook_knowledge")
    fixture.snapshot.loop_state.event_local_states.erase(CURSOR.KEY)
    _seed(fixture.snapshot)
    var view = VIEWS[index].new()
    view.configure_session(SLOT, "MORNING_ROUTE")
    add_child(view)
    await _settle(view)
    view._dismiss_dialogue_for_test()
    var manager: Node = FailedPromotion.new() if scenario == "promotion" else SaveManager
    if manager != SaveManager: add_child(manager)
    view.session._save = manager
    var line := _line(["NB_CH1_MARK", "NB_MIRROR_OBSERVE", "NB_BASEMENT_FLOORPLAN"][index], ["A1", "C0", "D0"][index])
    var second := line.duplicate(true)
    second.presentation_token = ARCHIVE.new_uid()
    var before := GameState.get_snapshot()
    var revision: int = GameState.revision
    view._show_dialogue([line, second])
    _expect(view._async_history_enabled() and not view._history_async_request.is_empty(), "real shared controller starts asynchronous writer")
    _expect(view._dialogue_next.disabled and not view._notebook_open_block_reason().is_empty(), "pending next button and notebook guarded")
    view._dialogue_next.pressed.emit()
    view._advance_dialogue()
    _expect(view._dialogue_index == 0 and GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "pending callbacks cannot advance or install")
    if scenario == "replace": view._dialogue_lines[0].presentation_token = ARCHIVE.new_uid()
    if scenario == "locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
    if scenario == "storage": view.session._save = STORAGE.new()
    await _settle(view)
    if scenario == "success":
        _expect(view._history_recorded_index == 0 and not view._dialogue_next.disabled, "success permits explicit continuation")
        view._dialogue_next.pressed.emit()
        _expect(view._dialogue_index == 1 and not view._history_async_request.is_empty(), "next line has its own pending boundary")
        await _settle(view)
        var state := GameState.get_snapshot()
        var count: int = state.meta_progress.dialogue_history.entries.size()
        view._dialogue_next.pressed.emit()
        _expect(view._dialogue_active and not view._history_async_request.is_empty(), "final continuation waits for cursor durability")
        await _settle(view)
        _expect(not view._dialogue_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "durable completed cursor closes the dialogue")
        _expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.size() >= count, "completion does not rewrite displayed observations")
        var disk := SaveManager.load_slot(SLOT)
        _expect(disk.ok and CURSOR.read(disk.snapshot).phase == "completed", "completed cursor survives actual reload")
    else:
        _expect(view._history_recorded_index == -1 and view._dialogue_active and not view._dialogue_next.disabled, "rejected outcome keeps current line retryable")
        _expect(GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "rejection preserves live state")
        if scenario == "promotion":
            view.session._save = SaveManager
            view._dialogue_next.pressed.emit()
            await _settle(view)
            _expect(view._history_recorded_index == 0 and view._dialogue_index == 0, "retry records without advancing the displayed line")
            _expect(view._status_label.text != view._dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"), "successful retry clears failure notice")
    if scenario == "storage": view.session._save.free()
    TranslationServer.set_locale(locale)
    cases.append({"kind":"ui", "family":index, "scenario":scenario, "locale":locale, "passed":errors.size() == begin_errors})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    SaveManager.delete_test_slot(SLOT)

func _large(id: String, locale: String) -> void:
    var begin_errors := errors.size()
    var fixture := FIXTURES.build(id)
    _expect(fixture.ok, "fixed large fixture")
    var state := GameState.make_default_snapshot()
    state.meta_progress.dialogue_history = fixture.archive
    state.meta_progress.knowledge_entries.notebook_knowledge = fixture.ledger
    _seed(state)
    var manager := STORAGE.new()
    add_child(manager)
    manager.set_process(false)
    var command := ARCHIVE.new_uid()
    var start := Time.get_ticks_usec()
    _expect(manager.begin_history_write(GameState, SLOT, "SAVE_CAMPAIGN_PROGRESS", _recording(_line()), GameState.revision, command).ok, "large record begins")
    var begin_ms := (Time.get_ticks_usec() - start) / 1000.0
    var frames := await _prepared(manager)
    var dispatch := Time.get_ticks_usec()
    manager._process(0.0)
    var dispatch_ms := (Time.get_ticks_usec() - dispatch) / 1000.0
    var result := manager.notebook_reference_result(command)
    var durable_ms := (Time.get_ticks_usec() - start) / 1000.0
    _expect(result.ok and result.changed and frames > 0, "large writer yields frames and commits")
    var loaded := SaveManager.load_slot(SLOT)
    _expect(loaded.ok and StateSnapshotValidator.same_persisted_value(loaded.snapshot, GameState.get_snapshot()), "large live/disk snapshot exact")
    timings.append({"fixture":id, "locale":locale, "begin_ms":begin_ms, "dispatch_ms":dispatch_ms,
        "total_ms":durable_ms, "worker_frames":frames, "max_wait_frame_ms":_last_wait_frame_ms, "scope":"HEADLESS n=1 durable return; excludes post-commit load"})
    cases.append({"kind":"large", "fixture":id, "locale":locale, "passed":errors.size() == begin_errors})
    manager.free()
    SaveManager.delete_test_slot(SLOT)
