extends "notebook_prologue_choice_async_audit.gd"

func _argument(key: String) -> String:
    for value in OS.get_cmdline_user_args():
        if value.begins_with(key + "="): return value.substr(key.length() + 1)
    return ""

func _ready() -> void:
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var phase := _argument("--choice-phase")
    var mode := _argument("--choice-mode")
    var locale := _argument("--choice-locale")
    var saving := _argument("--choice-saving")
    _expect(phase in ["seed", "resume", "verify_response"] and mode in MODES and locale in ["ko_KR", "en_US"], "explicit native process parameters")
    TranslationServer.set_locale(locale)
    var observed := {}
    if errors.is_empty():
        if phase == "seed":
            _seed(_choice_seed(mode))
            var view = _make_choice_view()
            _expect(view._prologue_async_enabled() == (saving == "async"), "explicit save-mode gate")
            _show_choice(view, mode)
            await _prologue_settle(view)
            view.defer_selected_action = true
            _press(view, mode, _answers(mode)[0])
            await _prologue_settle(view)
            var disk := SaveManager.load_slot(SLOT)
            _expect(disk.ok and CURSOR.read(disk.snapshot).phase == "selection_pending", "seed stops after real durable pending choice")
            _expect(view.selection_actions.size() == 1 and view.selection_actions[0].durable, "seed interruption is after durable callback boundary")
            observed = _summary(disk.snapshot)
            view.queue_free()
            await get_tree().process_frame
        else:
            var loaded := SaveManager.load_slot(SLOT)
            _expect(loaded.ok, "previous native process save exists")
            if loaded.ok:
                var frozen: Dictionary = loaded.snapshot.duplicate(true)
                var cursor := CURSOR.read(frozen)
                _expect(StateWriter.new(GameState).install_snapshot(frozen, GameState.revision, &"LOAD_CHOICE_PROCESS").ok, "actual disk load into new process")
                var view = _make_choice_view()
                _expect(view._prologue_async_enabled() == (saving == "async"), "resume save-mode gate")
                await _prologue_settle(view)
                _expect(view.selection_actions.is_empty() and StateSnapshotValidator.same_persisted_value(frozen, GameState.get_snapshot()), "new process restore is read-only, never selects")
                if phase == "resume":
                    _expect(cursor.kind == "choice" and cursor.phase == "selection_pending" and cursor.choice.mode == mode, "resume exact selected-pending mode")
                    var localized := CURSOR.localized_choice(cursor, locale)
                    var prompt: String = view._dialogue_label.text if mode.begins_with("p") else view._prologue_confirmation.choice.prompt
                    _expect(prompt == localized.prompt, "new process prompt uses current locale")
                    var answer: String = _answers(mode)[0]
                    var token: String = cursor.choice.tokens[answer]
                    _expect(_selected_token(view, mode, answer) == token, "explicit process retry reuses original selected token")
                    var old_selected: Dictionary = frozen.meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("presentation_token") == token)[0]
                    _press(view, mode, answer)
                    await _prologue_settle(view)
                    _expect(view.selection_actions.size() == 1 and view.selection_actions[0].durable and _token_count(token) == 1, "explicit action is durable and singular across processes")
                    var final := GameState.get_snapshot()
                    var entries: Array = final.meta_progress.dialogue_history.entries
                    var same_intent := entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == old_selected.observation.content_id and entry.get("observation", {}).get("event_occurrence_id") == old_selected.observation.event_occurrence_id)
                    _expect(same_intent.size() == 1 and same_intent[0].entry_uid == old_selected.entry_uid and same_intent[0].observation.presentation_token == token, "explicit retry cannot replace or duplicate the selected intent")
                    for previous in frozen.meta_progress.dialogue_history.entries:
                        var matching := entries.filter(func(entry: Dictionary) -> bool: return entry.entry_uid == previous.entry_uid)
                        _expect(matching.size() == 1 and matching[0] == previous, "resume preserves exact previous record UID and body")
                    var disk := SaveManager.load_slot(SLOT)
                    _expect(disk.ok and StateSnapshotValidator.same_persisted_value(final, disk.snapshot), "resume disk/live exact")
                    observed = _summary(final)
                    if not errors.is_empty() and mode.begins_with("p"):
                        var context: Dictionary = view._choice_history_context.duplicate(true)
                        context.presentation_token = token
                        context.notebook_content = CONTENT.descriptor("NB_PR_" + String(context.node_id) + "_SELECT_" + answer.to_upper(), 1, {"body":{}})
                        var recording := {"speaker":view._dialogue_ui_text("HISTORY_SELECTED"), "text":String(_buttons(view, mode)[0].get_meta("choice_label")), "context":context, "presentation":view._prologue_choice_spec()}
                        var prepared := CANDIDATE.prepare(GameState.get_snapshot(), view._prologue_candidate_request(recording))
                        observed.diagnostic_error = prepared.get("error_id", prepared.get("error_ids", []))
                else:
                    _expect(cursor.kind == "dialogue" and cursor.phase == "reading" and view._dialogue_active, "third process restores response instead of replaying selection")
                    _expect(view._dialogue_label.text == CURSOR.localized_lines(cursor, locale)[cursor.index].text, "third process response is current-language text")
                    observed = _summary(GameState.get_snapshot())
                view.queue_free()
                await get_tree().process_frame
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors, "phase":phase, "mode":mode, "locale":locale, "saving":saving,
        "observed":observed, "scope":"native HEADLESS disk/process boundary; current locale restore, no physical input or full prologue completion"}
    print("PROLOGUE_CHOICE_PROCESS_AUDIT: ", JSON.stringify(result))
    print("PROLOGUE_CHOICE_PROCESS_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _summary(state: Dictionary) -> Dictionary:
    var cursor := CURSOR.read(state)
    var entries: Array = state.meta_progress.dialogue_history.entries
    return {"cursor_phase":cursor.phase, "cursor_kind":cursor.kind, "cursor_token":cursor.lines[0].presentation_token,
        "entry_uids":entries.map(func(entry: Dictionary) -> String: return entry.entry_uid),
        "snapshot_sha256":JSON.stringify(JSON.parse_string(JSON.stringify(state))).sha256_text()}
