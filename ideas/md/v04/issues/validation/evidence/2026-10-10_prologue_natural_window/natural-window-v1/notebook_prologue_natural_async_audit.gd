extends "notebook_prologue_surface_async_audit.gd"

const NATURAL_SCENARIOS := ["brush", "spanner", "cloth", "water", "bird", "promotion", "ack"]

class NaturalView extends "res://scripts/prologue/prologue_controller.gd":
    var tool_actions := 0
    func _apply_window_tool(item_id: String, zone_id: String) -> void:
        if _prologue_dispatch_active: tool_actions += 1
        super._apply_window_tool(item_id, zone_id)

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for scenario in NATURAL_SCENARIOS: await _natural_window(scenario, locale)
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "cases":cases,
        "required_cases":14, "scope":"HEADLESS actual inventory/hotspot/window signals; isolated P2 boundaries, not full campaign, OS input or performance acceptance"}
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
            _expect(CURSOR.read(disk.snapshot).phase == "observed", "special line has durable observed cursor")
    cases.append({"scenario":scenario, "locale":locale, "worker_kind":worker_kind, "tool_actions":view.tool_actions,
        "physical_expected":local_state, "display_token":display_token, "passed":initial_errors == errors.size()})
    view.queue_free()
    await get_tree().process_frame
    if manager != SaveManager: manager.free()
    SaveManager.delete_test_slot(SLOT)
