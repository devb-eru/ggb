extends "notebook_prologue_async_audit.gd"

const SCENARIOS := ["success", "promotion", "ack", "request_changed", "active_changed", "generation", "scope", "locale", "service", "progress", "notes", "inventory", "window", "dialogue", "modal", "notebook", "stale_note", "unknown_content"]
const EXTRAS := ["repaint", "new_attempt", "p2_plain_tools", "pending_repaint", "queued_free"]

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in SCENARIOS: await _surface_case(scenario, locale)
        for scenario in EXTRAS: await _surface_extra(scenario, locale)
        for fixture in FIXTURES.IDS: await _surface_large(fixture, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases, "required_cases":54, "timings":timings,
        "scope":"HEADLESS actual prologue surface callbacks and atomic disk batch; not full prologue, physical input or p95"}
    print("PROLOGUE_SURFACE_ASYNC_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_SURFACE_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _surface_seed(parlor: bool = false) -> Dictionary:
    var state := _fixture_state()
    if parlor:
        state.loop_state.location_id = "M1_PARLOR"
        state.loop_state.event_local_states.PROLOGUE.current_room = "M1_PARLOR"
        state.loop_state.event_local_states.PROLOGUE.intros_seen = ["P2"]
    return state

func _pending_tokens(view: Node) -> Array:
    var tokens := []
    for id in view._prologue_surfaces.requests:
        var row: Dictionary = view._prologue_surfaces.requests[id]
        if not row.recorded and (id in view._prologue_surfaces.active or row.attempted): tokens.append(row.context.presentation_token)
    return tokens

func _surface_count(token: String) -> int:
    var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries
    return entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("presentation_token") == token).size()

func _settle_surface(view: Node) -> int:
    var frames := 1 if not view._prologue_async_request.is_empty() else 0
    await get_tree().process_frame
    frames += await _prologue_settle(view)
    frames += 1 if not view._prologue_async_request.is_empty() else 0
    await get_tree().process_frame
    frames += await _prologue_settle(view)
    return frames

func _surface_committed(view: Node, tokens: Array, label: String) -> void:
    _expect(view._prologue_async_request.is_empty() and not view._prologue_surfaces.has_pending() and not view._prologue_surfaces.retry_required, label + " clears only committed requests")
    for token in tokens: _expect(_surface_count(token) == 1, label + " exact surface token once")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), label + " disk/live exact")

func _surface_case(scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    _seed(_surface_seed(scenario == "window"))
    var view = _make_view()
    var manager: Node = SaveManager
    if scenario == "promotion": manager = FailedPromotion.new()
    elif scenario == "ack": manager = LostAcknowledgement.new()
    if manager != SaveManager: add_child(manager)
    view._prologue_surface_saves = manager
    view._queue_notebook_observation("NOTE_P_DUTIES")
    if scenario == "window":
        view._inspection_active = true
        view._inspected_window = 0
        view._inspection_scope = view._notebook_event_scope()
    var first_key: String = view._prologue_surfaces.active[0]
    var original_context: Dictionary = view._prologue_surfaces.requests[first_key].context.duplicate(true)
    if scenario == "unknown_content": view._prologue_surfaces.requests[first_key].context.notebook_content.content_id = "NB_NOT_REGISTERED"
    if scenario == "stale_note":
        for note in view._pending_notebook.values(): note.scope.slot = "different_slot"
    var before: Dictionary = GameState.get_snapshot()
    var tokens := _pending_tokens(view)
    var generation: int = view._prologue_surfaces.generation
    _expect(tokens.size() >= 4 and not view._flush_prologue_surfaces(generation), "visible batch starts as pending, never a false success")
    _expect(view._prologue_async_request.get("kind") == "surfaces", "ordinary surfaces use composite worker")
    _expect(view._interaction_blocked() and not view._notebook_open_block_reason().is_empty(), "pending blocks gameplay and notebook")
    view._enter_room("M1_CENTRAL_HALL")
    view._open_menu()
    _expect(view._current_room == before.loop_state.location_id and not view._modal_active, "pending cannot move or open menu")
    _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "pending cannot install partial state")
    var substitute: Node = null
    var notebook: Control = null
    match scenario:
        "request_changed": view._prologue_surfaces.requests[first_key].text += "changed"
        "active_changed": view._prologue_surfaces.active.pop_back()
        "generation": view._prologue_surfaces.generation += 1
        "scope": view._slot_id += "_other"
        "locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
        "service":
            substitute = STORAGE.new()
            add_child(substitute)
            view._prologue_surface_saves = substitute
        "progress": view._progress.bird_observed = true
        "notes": view._pending_notebook.clear()
        "inventory": view._inventory_slots[0].set_inventory_item("SOFT_CLOTH", "cloth")
        "window": view._inspected_window = 1
        "dialogue": view._dialogue_active = true
        "modal": view._modal_active = true
        "notebook":
            notebook = Control.new()
            add_child(notebook)
            view._notebook_host = notebook
    var frames := await _settle_surface(view)
    if scenario in ["success", "ack"]:
        _expect(frames > 0 and view._pending_notebook.is_empty(), "successful surface candidate durably acquires note")
        _surface_committed(view, tokens, "success")
        var revision: int = GameState.revision
        _expect(view._flush_prologue_surfaces(generation) and GameState.revision == revision, "already committed batch is read-only")
    else:
        _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "failed or stale batch installs nothing")
        for token in tokens: _expect(_surface_count(token) == 0, "failed or stale batch never partially records")
        if scenario in ["promotion", "stale_note", "unknown_content"]:
            _expect(view._prologue_surfaces.retry_required and is_instance_valid(view._prologue_surface_retry) and view._prologue_surface_retry.visible, "live save failure exposes explicit retry")
            _expect(not view._pending_notebook.is_empty(), "failure retains pending knowledge")
            _expect(not view._flush_prologue_surfaces(generation) and view._prologue_async_request.is_empty(), "failure never retries implicitly")
            view._prologue_surface_saves = SaveManager
            view._prologue_surfaces.requests[first_key].context = original_context
            for note in view._pending_notebook.values(): note.scope = view._notebook_event_scope().duplicate(true)
            view._prologue_surface_retry.pressed.emit()
            _expect(not view._prologue_async_request.is_empty(), "real retry button starts owned pending batch")
            await _settle_surface(view)
            _surface_committed(view, tokens, "retry")
    if notebook != null: view._notebook_host = null; notebook.free()
    TranslationServer.set_locale(locale)
    cases.append({"kind":"surface", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    if substitute != null: substitute.free()
    SaveManager.delete_test_slot(SLOT)

func _surface_extra(scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    _seed(_surface_seed(scenario == "p2_plain_tools"))
    var view = _make_view()
    var tokens := _pending_tokens(view)
    if scenario == "queued_free":
        var before: Dictionary = GameState.get_snapshot()
        view.queue_free()
        _expect(not view._flush_prologue_surfaces(view._prologue_surfaces.generation) and view._prologue_async_request.is_empty(), "departing view cannot start a queued batch")
        await get_tree().process_frame
        _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "departing deferred flush preserves live state")
        for token in tokens: _expect(_surface_count(token) == 0, "departing view never records an unseen continuation")
        cases.append({"kind":"extra", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
        SaveManager.delete_test_slot(SLOT)
        return
    if scenario == "repaint": view._rebuild_current_room_content()
    if scenario == "pending_repaint":
        var before: Dictionary = GameState.get_snapshot()
        view._flush_prologue_surfaces(view._prologue_surfaces.generation)
        view._rebuild_current_room_content()
        await _settle_surface(view)
        _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "old repaint result cannot install")
        _expect(not view._prologue_surfaces.requests.is_empty(), "repaint retains previously observed pending values")
        view._flush_prologue_surfaces(view._prologue_surfaces.generation)
    await _settle_surface(view)
    _surface_committed(view, tokens, scenario)
    if scenario == "new_attempt":
        view._surface_status("P1_LABEL_BED")
        var newer := _pending_tokens(view)
        _expect(newer.size() == 1 and newer[0] not in tokens, "explicit new attempt receives its own token")
        await _settle_surface(view)
        _surface_committed(view, newer, "new attempt")
        for token in tokens: _expect(_surface_count(token) == 1, "new attempt preserves prior observation")
    if scenario == "p2_plain_tools":
        view._hotspot_layer.get_node("WINDOW_0").pressed.emit()
        await _settle_surface(view)
        _expect(view._inspection_active and view._inspected_window == 0, "actual window hotspot opens after durable room surfaces")
        view._inventory_slots[0].pressed.emit()
        await _settle_surface(view)
        view._window_drop_targets.TOP.pressed.emit()
        await _settle_surface(view)
        _expect(not view._progress.window_states[0].top_dust and view._progress.window_states[0].middle_stain, "actual top tool is not rolled back by deferred feedback batch")
        view._inventory_slots[2].pressed.emit()
        await _settle_surface(view)
        view._window_drop_targets.MIDDLE.pressed.emit()
        await _settle_surface(view)
        _expect(not view._progress.window_states[0].middle_stain and view._progress.window_states[0].bottom_wet, "actual water result and feedback are retained")
        view._inventory_slots[0].pressed.emit()
        await _settle_surface(view)
        view._window_drop_targets.BOTTOM.pressed.emit()
        await _settle_surface(view)
        _expect(view._is_window_clean(view._progress.window_states[0]), "actual dry completion survives capture")
        _surface_committed(view, [], "actual tools")
    cases.append({"kind":"extra", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _surface_large(id: String, locale: String) -> void:
    var initial_errors := errors.size()
    var fixture := FIXTURES.build(id)
    _expect(fixture.ok, "large fixture exists")
    var seed := _surface_seed()
    seed.meta_progress.dialogue_history = fixture.archive
    seed.meta_progress.knowledge_entries.notebook_knowledge = fixture.ledger
    _seed(seed)
    var view = _make_view()
    view._queue_notebook_observation("NOTE_P_DUTIES")
    var before: Dictionary = GameState.get_snapshot()
    var tokens := _pending_tokens(view)
    var start := Time.get_ticks_usec()
    var allowed_tokens := tokens.duplicate()
    for note in view._pending_notebook.values(): allowed_tokens.append(note.observation.presentation_token)
    view._flush_prologue_surfaces(view._prologue_surfaces.generation)
    var begin_ms := float(Time.get_ticks_usec() - start) / 1000.0
    var frames := await _settle_surface(view)
    var total_ms := float(Time.get_ticks_usec() - start) / 1000.0
    _surface_committed(view, tokens, "large batch")
    _expect(frames > 0 and view._pending_notebook.is_empty(), "large batch commits while frames advance")
    var final: Dictionary = GameState.get_snapshot()
    var preserved := {}
    var original_uids := {}
    for row in before.meta_progress.dialogue_history.entries: original_uids[row.entry_uid] = true
    for row in final.meta_progress.dialogue_history.entries:
        if not preserved.has(row.entry_uid): preserved[row.entry_uid] = []
        preserved[row.entry_uid].append(row)
        if not original_uids.has(row.entry_uid): _expect(row.get("observation", {}).get("presentation_token") in allowed_tokens, "new records are exactly observed surfaces or acquired note")
    var removed := 0
    for previous in before.meta_progress.dialogue_history.entries:
        var matching: Array = preserved.get(previous.entry_uid, [])
        if id == "NB-PERF-P2001" and int(previous.sequence) == 0:
            _expect(previous.record_class == "authored" and previous.protection_reasons.is_empty() and matching.is_empty(), "only fixture's oldest surplus normal dialogue is pruned")
            removed += 1
            continue
        var expected: Dictionary = previous.duplicate(true)
        if id == "NB-PERF-P2001" and int(previous.sequence) in range(1, 10): expected.session_pruned = true
        _expect(matching.size() == 1 and StateSnapshotValidator.same_persisted_value(expected, matching[0]), "large batch preserves exact original and only approved session marker")
    _expect(removed == (1 if id == "NB-PERF-P2001" else 0), "independent permitted prune denominator")
    _expect(final.meta_progress.dialogue_history.next_sequence == before.meta_progress.dialogue_history.next_sequence + allowed_tokens.size(), "exact new-observation count, no hidden repeated append")
    for collection in ["bookmarks", "comparison"]:
        _expect(final.meta_progress.dialogue_history[collection] == before.meta_progress.dialogue_history[collection], "large batch preserves reference collection " + collection)
    timings.append({"fixture":id, "locale":locale, "begin_ms":begin_ms, "total_ms":total_ms, "worker_frames":frames, "scope":"HEADLESS n=1 ordinary surface batch; excludes setup/reload, not p95"})
    cases.append({"kind":"large", "fixture":id, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)
