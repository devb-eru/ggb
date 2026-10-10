extends "notebook_prologue_natural_async_audit.gd"

func _argument(name: String) -> String:
    for value in OS.get_cmdline_user_args():
        if value.begins_with(name + "="): return value.trim_prefix(name + "=")
    return ""

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var phase := _argument("--natural-phase")
    var mode := _argument("--natural-mode")
    var locale := _argument("--natural-locale")
    TranslationServer.set_locale(locale)
    _expect(phase in ["seed", "resume", "verify"] and mode in ["brush", "water"] and locale in ["ko_KR", "en_US"], "explicit process arguments")
    if phase == "seed":
        var state := _surface_seed(true)
        state.loop_state.event_local_states.PROLOGUE.window_states = [
            {"top_dust":mode == "brush","middle_stain":true,"bottom_wet":false,"dust_spread":false},
            {"top_dust":true,"middle_stain":true,"bottom_wet":false,"dust_spread":false},
            {"top_dust":true,"middle_stain":true,"bottom_wet":false,"dust_spread":false}]
        _seed(state)
    else:
        var loaded := SaveManager.load_slot(SLOT)
        _expect(loaded.ok, "independent process loads prior durable slot")
        if loaded.ok: _expect(StateWriter.new(GameState).install_snapshot(loaded.snapshot, GameState.revision, &"LOAD_NATURAL_RESUME").ok, "install only committed prior snapshot")
    var prior: Dictionary = GameState.get_snapshot()
    var prior_entries: Array = prior.meta_progress.dialogue_history.entries.duplicate(true)
    var revision: int = GameState.revision
    var view := NaturalView.new()
    view.configure_session(SLOT, "P1_ENTRY")
    add_child(view)
    await _natural_settle(view)
    if phase == "seed":
        await _natural_press(view, "WINDOW_0")
        await _natural_select(view, "COARSE_BRUSH" if mode == "brush" else "WATER")
        view._window_drop_targets["TOP" if mode == "brush" else "MIDDLE"].pressed.emit()
        await _natural_settle(view)
    else:
        _expect(GameState.revision == revision and StateSnapshotValidator.same_persisted_value(prior, GameState.get_snapshot()), "restoration is read-only across language change")
        _expect(view._inspection_active and view._inspected_window == 0, "same physical window restored")
        _expect(view._selected_item == ("COARSE_BRUSH" if mode == "brush" else ("WATER" if phase == "resume" else "SOFT_CLOTH")), "inventory selection restored")
        if mode == "brush":
            _expect(view._dialogue_active == (phase == "resume"), "observed or completed brush cursor restores correctly")
            if phase == "resume": await _natural_drain(view)
        elif phase == "resume":
            await _natural_select(view, "SOFT_CLOTH")
            view._window_drop_targets.BOTTOM.pressed.emit()
            await _natural_settle(view)
    var disk := SaveManager.load_slot(SLOT)
    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(disk.snapshot, GameState.get_snapshot()), "process durable disk/live exact")
    var saved_entries := []
    var physical := {}
    if disk.ok:
        saved_entries = disk.snapshot.meta_progress.dialogue_history.entries.duplicate(true)
        physical = disk.snapshot.loop_state.event_local_states.PROLOGUE.window_states[0].duplicate(true)
        if mode == "brush": _expect(physical.dust_spread and physical.top_dust, "brush physical change survives every process")
        else: _expect(not physical.middle_stain and physical.bottom_wet == (phase == "seed"), "water then drying survives every process")
        for entry in prior_entries:
            var matches: Array = saved_entries.filter(func(row: Dictionary) -> bool: return row.entry_uid == entry.entry_uid)
            _expect(matches.size() == 1 and StateSnapshotValidator.same_persisted_value(matches[0], entry), "old UID and original language remain exact")
        if phase == "verify": _expect(StateSnapshotValidator.same_persisted_value(prior, disk.snapshot), "final verification cannot rewrite slot")
    var result := {"ok":errors.is_empty(),"errors":errors,"checks":checks,"phase":phase,"mode":mode,"locale":locale,
        "prior_entries":prior_entries,"saved_entries":saved_entries,"physical":physical,"scope":"independent HEADLESS process restore and actual callbacks, not OS input"}
    print("PROLOGUE_NATURAL_PROCESS_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_NATURAL_PROCESS_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)
