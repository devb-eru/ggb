extends "notebook_prologue_surface_async_audit.gd"

const NATURAL_SCENARIOS := ["brush", "spanner", "cloth", "water", "bird", "promotion", "ack"]
const ROUTES := ["p2_complete", "room_intro", "p3_books", "p3_drop", "p3b_labels", "p4_father", "p4_tenure", "p5_weather"]
const STALE_ACTIONS := ["locale", "scope", "generation", "progress", "notes", "inventory", "window", "service", "active"]
const STALE_RETRIES := ["locale", "scope", "generation", "progress", "notes", "inventory", "window", "requests"]

class NaturalView extends "res://scripts/prologue/prologue_controller.gd":
    var tool_actions := 0
    func _apply_window_tool(item_id: String, zone_id: String) -> void:
        if _prologue_dispatch_active: tool_actions += 1
        super._apply_window_tool(item_id, zone_id)

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var windows_only := "--natural-window-only" in OS.get_cmdline_user_args()
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in NATURAL_SCENARIOS: await _natural_window(scenario, locale)
        if not windows_only:
            for route in ROUTES: await _natural_route(route, locale)
            for scenario in STALE_ACTIONS: await _natural_stale(scenario, locale, false)
            for scenario in STALE_RETRIES: await _natural_stale(scenario, locale, true)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases,
        "required_cases":14 if windows_only else 64, "scope":"HEADLESS actual inventory/hotspot/window/choice signals; fixed event boundaries, not full campaign, OS input or performance acceptance"}
    print("PROLOGUE_NATURAL_ASYNC_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_NATURAL_ASYNC_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _natural_settle(view: Node) -> void:
    var start := Time.get_ticks_msec()
    var idle_frames := 0
    while idle_frames < 3:
        await get_tree().process_frame
        idle_frames = idle_frames + 1 if view._prologue_async_request.is_empty() else 0
        if Time.get_ticks_msec() - start > 60000:
            _expect(false, "natural pending deadline")
            return

func _natural_select(view: Node, item_id: String) -> void:
    var found := false
    for slot in view._inventory_slots:
        if String(slot.get_meta("item_id", "")) == item_id:
            found = true
            slot.pressed.emit()
            break
    _expect(found, "actual inventory slot exists " + item_id)
    await _natural_settle(view)
    _expect(view._selected_item == item_id, "actual selection committed " + item_id)

func _natural_window(scenario: String, locale: String) -> void:
    var initial_errors := errors.size()
    var state := _surface_seed(true)
    var windows := []
    for index in range(3): windows.append({"top_dust":true, "middle_stain":true, "bottom_wet":false, "dust_spread":false})
    if scenario in ["water", "promotion", "ack"]: windows[0].top_dust = false
    state.loop_state.event_local_states.PROLOGUE.window_states = windows
    _seed(state)
    var view := NaturalView.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    await _natural_settle(view)
    var window_index := 2 if scenario == "bird" else 0
    var hotspot = view._hotspot_layer.get_node("WINDOW_%d" % window_index)
    hotspot.pressed.emit()
    await _natural_settle(view)
    _expect(view._inspection_active and view._inspected_window == window_index, "actual window opens")
    var item_id := "SOFT_CLOTH"
    if scenario == "brush": item_id = "COARSE_BRUSH"
    elif scenario == "spanner": item_id = "SPANNER"
    elif scenario in ["water", "promotion", "ack"]: item_id = "WATER"
    await _natural_select(view, item_id)
    var manager: Node = SaveManager
    if scenario == "promotion": manager = FailedPromotion.new()
    elif scenario == "ack": manager = LostAcknowledgement.new()
    if manager != SaveManager: add_child(manager)
    view._prologue_surface_saves = manager
    view._queue_notebook_observation("NOTE_P_DUTIES")
    var before: Dictionary = GameState.get_snapshot()
    var revision: int = GameState.revision
    var zone := "MIDDLE" if item_id == "WATER" else "TOP"
    view._window_drop_targets[zone].pressed.emit()
    _expect(not view._prologue_async_request.is_empty(), "actual tool starts one pending candidate")
    _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()) and GameState.revision == revision, "pending does not install physical state or knowledge")
    var local_state: Dictionary = view._progress.window_states[window_index].duplicate(true)
    var display_token := ""
    if view._dialogue_active: display_token = view._dialogue_lines[view._dialogue_index].presentation_token
    var worker_kind: String = view._prologue_async_request.get("kind", "")
    view._window_drop_targets[zone].pressed.emit()
    _expect(view.tool_actions == 1, "pending repeated input cannot reapply tool")
    await _natural_settle(view)
    if scenario == "promotion":
        _expect(worker_kind == "action", "plain tool uses action candidate")
        _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "failed promotion leaves live state exact")
        var failed_disk := SaveManager.load_slot(SLOT)
        _expect(failed_disk.ok and StateSnapshotValidator.same_persisted_value(before, failed_disk.snapshot), "failed promotion leaves durable main exact")
        _expect(view._progress.window_states[window_index] == local_state and not view._pending_notebook.is_empty(), "failed action keeps local draft and pending note")
        _expect(view._prologue_surfaces.retry_required and is_instance_valid(view._prologue_surface_retry) and view._prologue_surface_retry.visible, "failed action exposes retry")
        await _natural_settle(view)
        _expect(GameState.revision == revision and view.tool_actions == 1, "failure never retries implicitly")
        view._prologue_surface_saves = SaveManager
        view._prologue_surface_retry.pressed.emit()
        _expect(not view._prologue_async_request.is_empty(), "actual retry starts same detached candidate")
        await _natural_settle(view)
        _expect(view.tool_actions == 1, "retry does not replay physical action")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "committed disk/live exact")
    if disk.ok:
        var saved: Dictionary = disk.snapshot.loop_state.event_local_states.PROLOGUE
        _expect(saved.window_states[window_index] == local_state, "physical state and presentation committed together")
        _expect(view._pending_notebook.is_empty(), "knowledge cleared only after durability")
        if scenario == "brush":
            _expect(saved.window_states[0].dust_spread and saved.p2_brush_hint_seen, "brush spread and hint retained")
        elif scenario == "spanner": _expect(saved.p2_spanner_hint_seen, "spanner hint retained")
        elif scenario in ["water", "promotion", "ack"]:
            _expect(not saved.window_states[0].middle_stain and saved.window_states[0].bottom_wet, "water transforms glass without rollback")
        else: _expect(not saved.window_states[window_index].top_dust, "cloth removes top dust")
        if scenario == "bird": _expect(saved.bird_observed, "bird observation and physical dust change share commit")
        if not display_token.is_empty():
            var entries: Array = disk.snapshot.meta_progress.dialogue_history.entries
            _expect(entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("presentation_token") == display_token).size() == 1, "special line recorded once with physical state")
            var cursor := CURSOR.read(disk.snapshot)
            _expect(cursor.get("phase") == "reading" and CURSOR.observed(cursor, disk.snapshot), "special line has durable reading cursor and matching observation")
    cases.append({"scenario":scenario, "locale":locale, "worker_kind":worker_kind, "tool_actions":view.tool_actions,
        "physical_expected":local_state, "display_token":display_token, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    SaveManager.delete_test_slot(SLOT)

func _natural_drain(view: Node) -> void:
    for index in range(64):
        await _natural_settle(view)
        if not view._dialogue_active: return
        if view._prologue_history_index != view._dialogue_index:
            _expect(false, "dialogue did not durably record before advance")
            return
        view._dialogue_next.pressed.emit()
    _expect(false, "natural dialogue deadline")

func _natural_press(view: Node, id: String) -> void:
    var button = view._hotspot_layer.get_node_or_null(id)
    _expect(button != null, "actual hotspot exists " + id)
    if button == null: return
    button.pressed.emit()
    await _natural_settle(view)

func _natural_answer(view: Node, id: String) -> void:
    var found := false
    for button in view._dialogue_choice_buttons:
        if String(button.get_meta("choice_id", "")) == id:
            found = true
            button.pressed.emit()
            break
    _expect(found, "actual answer exists " + id)
    await _natural_settle(view)

func _natural_route(route: String, locale: String) -> void:
    var initial_errors := errors.size()
    var state := _fixture_state()
    var progress: Dictionary = state.loop_state.event_local_states.PROLOGUE
    progress.intros_seen = ["P1", "P2", "P3", "P3B", "P4", "P5", "P6"]
    var room := "M1_CENTRAL_HALL"
    if route == "room_intro": progress.intros_seen.erase("P2")
    elif route == "p2_complete":
        room = "M1_PARLOR"
        progress.window_states = [
            {"top_dust":false,"middle_stain":false,"bottom_wet":false,"dust_spread":false},
            {"top_dust":false,"middle_stain":false,"bottom_wet":false,"dust_spread":false},
            {"top_dust":true,"middle_stain":true,"bottom_wet":false,"dust_spread":false}]
    elif route.begins_with("p3_"): room = "M1_LIBRARY_OUTER"
    elif route == "p3b_labels": room = "M1_NORTH_ARCHIVE_HALL"
    elif route.begins_with("p4_"):
        room = "M1_KITCHEN"
        for key in ["P2_complete", "P3_complete", "P3B_complete"]: progress[key] = true
    elif route == "p5_weather":
        room = "M1_GREENHOUSE_VESTIBULE"
        progress.P4_complete = true
        progress.time_block = "evening_free"
    progress.current_room = room
    state.loop_state.location_id = room
    _seed(state)
    var view := NaturalView.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    await _natural_settle(view)
    if route == "room_intro":
        await _natural_press(view, "PARLOR")
        _expect(view._dialogue_active and view._current_room == "M1_PARLOR", "room action produces P2 intro")
        await _natural_drain(view)
        _expect("MARA1" in view._progress.introduced, "intro commits character introduction")
    elif route == "p2_complete":
        await _natural_press(view, "WINDOW_2")
        await _natural_select(view, "SOFT_CLOTH")
        view._window_drop_targets.TOP.pressed.emit()
        await _natural_drain(view)
        view._window_drop_targets.MIDDLE.pressed.emit()
        await _natural_drain(view)
        _expect(view._progress.P2_complete and view._current_room == "M1_CENTRAL_HALL", "P2 completion returns to hall after durable dialogue")
    elif route.begins_with("p3_"):
        for pair in [["BOOK_MECHANICAL","SHELF_CLOCK"],["BOOK_FLORA","SHELF_FLOWER"],["BOOK_LEDGER","SHELF_CUP"]]:
            if route == "p3_drop":
                var target = view._hotspot_layer.get_node(pair[1])
                target.inventory_item_dropped.emit(pair[0], pair[1])
                await _natural_settle(view)
            else:
                await _natural_select(view, pair[0])
                await _natural_press(view, pair[1])
            await _natural_drain(view)
            if pair[0] == "BOOK_MECHANICAL":
                _expect(view._dialogue_choice_active, "natural discovery reaches journal choice")
                await _natural_answer(view, "author")
                await _natural_drain(view)
                _expect(view._dialogue_choice_active, "answer returns to journal choice")
                await _natural_answer(view, "silent")
                await _natural_drain(view)
        _expect(view._progress.P3_complete and view._progress.p3_placed.size() == 3 and view._current_room == "M1_CENTRAL_HALL", "P3 physical placement and answer complete")
        _expect("author" in view._progress.p3_journal_questions_asked and view._progress.p3_journal_choice == "silent", "P3 answers survive subsequent placement")
    elif route == "p3b_labels":
        for index in range(5):
            await _natural_select(view, "LABEL_" + view.P3B_OWNERS[index])
            await _natural_press(view, "PORTRAIT_%d" % index)
            await _natural_drain(view)
        _expect(view._progress.P3B_complete and view._progress.p3b_placed.size() == 5 and view._current_room == "M1_CENTRAL_HALL", "five labels and signature note complete")
    elif route.begins_with("p4_"):
        for index in range(6):
            await _natural_select(view, view.TEA_STEP_ITEMS[index])
            await _natural_press(view, "TEA_%d" % index)
            await _natural_drain(view)
            _expect(view._progress.tea_step == index + 1, "actual tea step advances once")
            if index == 4: await _natural_press(view, "P4_RECORD_PULSE")
        _expect(view._progress.p4_phase == "memory_anchor_ready", "tea reaches memory anchor before question")
        await _natural_press(view, "P4_CUP_HANDLE")
        await _natural_drain(view)
        await _natural_press(view, "P4_ASK_LUCA")
        var answer := "father_tea" if route == "p4_father" else "luca_tenure"
        await _natural_answer(view, answer)
        await _natural_drain(view)
        _expect(view._progress.P4_complete and view._progress.iris_greeting_seen and view._current_room == "M1_CENTRAL_HALL", "P4 question and Iris greeting finish")
        _expect(view._progress.p4_handle_return_used and view._progress.p4_life_support_recorded and view._progress.p4_father_question == answer, "P4 anchors and selected answer preserved")
    else:
        for id in ["CORRIDOR_WINDOW", "GREENHOUSE_GLASS", "THRESHOLD"]:
            await _natural_press(view, id)
            await _natural_drain(view)
        await _natural_press(view, "RECORD")
        await _natural_drain(view)
        _expect(view._progress.P5_complete and view._current_room == "M1_CENTRAL_HALL", "P5 observation then explicit record completes")
    await _natural_settle(view)
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "route disk/live exact")
    if disk.ok:
        _expect(disk.snapshot.loop_state.event_local_states.PROLOGUE == view._progress, "route local/durable physical progress exact")
        var tokens := {}
        for entry in disk.snapshot.meta_progress.dialogue_history.entries:
            var token: String = entry.get("observation", {}).get("presentation_token", "")
            _expect(not token.is_empty() and not tokens.has(token), "route has unique actual observation token")
            tokens[token] = true
    cases.append({"kind":"route", "scenario":route, "locale":locale, "room":view._current_room, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    SaveManager.delete_test_slot(SLOT)

func _natural_stale(scenario: String, locale: String, retry: bool) -> void:
    var initial_errors := errors.size()
    var state := _surface_seed(true)
    state.loop_state.event_local_states.PROLOGUE.window_states = [
        {"top_dust":false,"middle_stain":true,"bottom_wet":false,"dust_spread":false},
        {"top_dust":true,"middle_stain":true,"bottom_wet":false,"dust_spread":false},
        {"top_dust":true,"middle_stain":true,"bottom_wet":false,"dust_spread":false}]
    _seed(state)
    var view := NaturalView.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    await _natural_settle(view)
    await _natural_press(view, "WINDOW_0")
    await _natural_select(view, "WATER")
    var manager: Node = null
    if retry:
        manager = FailedPromotion.new()
        add_child(manager)
        view._prologue_surface_saves = manager
    view._queue_notebook_observation("NOTE_P_DUTIES")
    var before: Dictionary = GameState.get_snapshot()
    var revision: int = GameState.revision
    view._window_drop_targets.MIDDLE.pressed.emit()
    _expect(view._prologue_async_request.get("kind") == "action", "stale fixture has pending actual action")
    if retry:
        await _natural_settle(view)
        _expect(view._prologue_surfaces.retry_required, "retry fixture has genuine failed save")
        view._prologue_surface_saves = SaveManager
    var substitute: Node = null
    match scenario:
        "locale": TranslationServer.set_locale("en_US" if locale == "ko_KR" else "ko_KR")
        "scope": view._slot_id += "_other"
        "generation": view._prologue_surfaces.generation += 1
        "progress": view._progress.bird_observed = true
        "notes": view._pending_notebook.clear()
        "inventory": view._inventory_slots[0].set_inventory_item("SPANNER", "spanner")
        "window": view._inspected_window = 1
        "active": view._prologue_surfaces.active.pop_back()
        "requests": view._prologue_surfaces.requests[view._prologue_surfaces.active[0]].text += "changed"
        "service":
            substitute = STORAGE.new()
            add_child(substitute)
            view._prologue_surface_saves = substitute
    if retry: view._prologue_surface_retry.pressed.emit()
    await _natural_settle(view)
    _expect(GameState.revision == revision and StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "changed action/retry context cannot install")
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(before, disk.snapshot), "changed action/retry context cannot persist")
    _expect(view.tool_actions == 1, "stale action never replays physical mutation")
    TranslationServer.set_locale(locale)
    view._slot_id = SLOT
    cases.append({"kind":"stale_retry" if retry else "stale_action", "scenario":scenario, "locale":locale, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != null: manager.free()
    if substitute != null: substitute.free()
    SaveManager.delete_test_slot(SLOT)
