extends "notebook_campaign_sleep_ui_audit.gd"

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for route in ["chapter", "mirror", "basement", "bedroom"]:
            for location in ["M1_BEDROOM", "M2_BEDROOM"]:
                for replay in [false, true]:
                    for mode in ["sync", "async"]:
                        await _location_case(route, location, replay, mode, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":64,
        "scope":"HEADLESS detached-candidate initialization, actual displayed observations and disk reload; not Windows physical input or process termination"}
    print("WAKE_LOCATION_AUDIT: ", JSON.stringify(result))
    print("WAKE_LOCATION_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _location_case(route: String, location: String, replay: bool, mode: String, locale: String) -> void:
    var first := errors.size()
    var state := _route_seed(route)
    state.loop_state.location_id = location
    state.loop_state.event_local_states.erase("NOTEBOOK_PRESENTATION")
    state.loop_state.event_local_states.CHAPTER_ONE.erase("last_feedback")
    if route == "bedroom":
        state.fracture_state.broken_reset_triggered = true
        state.fracture_state.camouflage_filter = "broken"
        state.fracture_state.world_phase = "S3"
        state.meta_progress.knowledge_entries.erase("E1_wake_seen")
    _seed(state)
    var client = _session(route, SaveManager)
    var original := {}
    if replay:
        state = GameState.get_snapshot()
        if route == "bedroom": state.meta_progress.knowledge_entries.E1_wake_seen = true
        var text: String = preload("res://scripts/systems/fracture_notebook.gd").TEXT.E1_WAKE if route == "bedroom" else preload("res://scripts/systems/chapter_one_notebook.gd").FIXED.WAKE
        var descriptors: Array = preload("res://scripts/systems/fracture_notebook.gd").paragraphs(["E1_WAKE"]) if route == "bedroom" else preload("res://scripts/systems/chapter_one_notebook.gd").paragraphs("WAKE")
        var context := {"node_id":"E1_ENTRY" if route == "bedroom" else client.stage(), "chapter_id":"CHAPTER_3" if route == "bedroom" else client.history_chapter_id(), "location_id":location}
        _expect(client._commit_feedback(state, text, "주인공", "", context, descriptors).ok, "save genuine earlier feedback with its original location")
        var display := _line("NB_FRACTURE_E1_WAKE" if route == "bedroom" else "NB_CH1_WAKE", context.node_id)
        display.history_context = context
        var record := _recording(display)
        _expect(WRITER.record(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", display.speaker, display.text, locale, context.chapter_id, [], record.context).ok, "earlier authored observation durable")
        original = GameState.get_snapshot()
        var row: Dictionary = original.meta_progress.dialogue_history.entries.back()
        var archive: Dictionary = original.meta_progress.dialogue_history
        for collection in ["bookmarks", "comparison"]:
            var pinned := ARCHIVE.set_reference(archive, collection, ARCHIVE.make_reference(row, row.observation.segments[0].segment_id), true, archive.revision)
            _expect(pinned.ok, "protect earlier waking original")
            if pinned.ok: archive = pinned.archive
        original.meta_progress.dialogue_history = archive
        _expect(StateWriter.new(GameState).install_snapshot(original, GameState.revision, &"LOAD_OLD_WAKE_PINS").ok, "install old waking references")
        _expect(SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", original, GameState.revision, "OLD_WAKE_ORIGINAL").ok, "old waking references durable")
    var before := GameState.get_snapshot()
    var candidate_context: Dictionary = client.history_context(before)
    _expect(candidate_context.location_id == location, "explicit candidate context does not alter historical input")
    var result: Dictionary
    if mode == "async":
        client._sleep_wake_pending = {"epoch":int(GameState.load_epoch), "revision":GameState.revision, "transaction":before.reset_state.last_completed_transaction_id, "rest":false}
        result = await client._persist_wake_async(Callable())
    else:
        result = client.initialize()
    _expect(result.ok, "initialization accepts canonical or legacy alias")
    var after := GameState.get_snapshot()
    _expect(after.loop_state.location_id == "M2_BEDROOM", "new live position canonical after initialization")
    var expected_location := location if replay else "M2_BEDROOM"
    _expect(result.get("history_context", {}).get("location_id") == expected_location, "new context canonical; earlier context unchanged")
    _expect(result.get("history_context", {}).get("node_id") == (before.loop_state.event_local_states.CHAPTER_ONE.last_feedback.history_context.node_id if replay else client.stage()), "node follows candidate stage for fresh source only")
    _expect(result.get("history_context", {}).get("chapter_id") == preload("res://scripts/systems/dialogue_history_context.gd").chapter_for_stage(result.history_context.node_id), "chapter matches genuine source node")
    if route == "bedroom" and not replay:
        var notes: Array = after.meta_progress.dialogue_history.entries.filter(func(row: Dictionary) -> bool: return row.get("observation", {}).get("content_id") == "NB_FRACTURE_NOTE_E1_WAKE")
        _expect(notes.size() == 1 and notes[0].observation.location_id == "M2_BEDROOM" and notes[0].observation.node_id == "E1_ENTRY", "new E1 acquired note carries normalized candidate context")
    var view = VIEWS[0 if route == "chapter" else (1 if route == "mirror" else 2)].new()
    view.configure_session(SLOT, "")
    add_child(view)
    await _settle(view)
    var displayed := GameState.get_snapshot()
    var cursor := CURSOR.read(displayed)
    _expect(not cursor.get("lines", []).is_empty(), "actual controller has waking presentation")
    for line in cursor.get("lines", []):
        _expect(line.get("history_context", {}).get("location_id") == expected_location, "displayed line keeps expected genuine location")
    var prior_uids: Array = before.meta_progress.dialogue_history.entries.map(func(row: Dictionary) -> String: return row.entry_uid)
    var observed := 0
    for row in displayed.meta_progress.dialogue_history.entries:
        if row.entry_uid in prior_uids or not row.has("observation"): continue
        if row.observation.content_id not in ["NB_CH1_WAKE", "NB_FRACTURE_E1_WAKE"]: continue
        observed += 1
        _expect(row.observation.location_id == expected_location, "actual observed feedback uses expected genuine location")
    _expect(observed > 0, "test reaches actual disclosure rather than only session result")
    _preserved(before, displayed)
    var old_feedback: Dictionary = before.loop_state.event_local_states.CHAPTER_ONE.get("last_feedback", {})
    if replay:
        _expect(StateSnapshotValidator.same_persisted_value(old_feedback, displayed.loop_state.event_local_states.CHAPTER_ONE.last_feedback), "existing last_feedback and its stamp unchanged")
    view.free()
    await get_tree().process_frame
    var loaded := SaveManager.load_slot(SLOT)
    _expect(loaded.ok and StateSnapshotValidator.same_persisted_value(loaded.snapshot, displayed), "disk round trip matches every persisted field")
    _expect(StateWriter.new(GameState).install_snapshot(loaded.snapshot, GameState.revision, &"LOAD_WAKE_LOCATION").ok, "reload saved observation snapshot")
    var reopened = VIEWS[0 if route == "chapter" else (1 if route == "mirror" else 2)].new()
    reopened.configure_session(SLOT, "")
    add_child(reopened)
    await _settle(reopened)
    var reopened_state := GameState.get_snapshot()
    _preserved(displayed, reopened_state)
    _expect(StateSnapshotValidator.same_persisted_value(displayed.meta_progress.dialogue_history, reopened_state.meta_progress.dialogue_history), "reopen cannot add duplicate observation or rewrite old UID/context")
    _expect(StateSnapshotValidator.same_persisted_value(CURSOR.read(displayed), CURSOR.read(reopened_state)), "reopen preserves exact cursor with original history context")
    cases.append({"route":route, "location":location, "replay":replay, "mode":mode, "locale":locale, "passed":errors.size() == first, "expected_context_location":expected_location, "observed":observed})
    reopened.free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
