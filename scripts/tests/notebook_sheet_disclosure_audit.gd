extends Control

const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const DIAGNOSTICS := preload("res://scripts/systems/ep02_diagnostic_state.gd")
const TIMEOUT_MS := 120000
const SLOT_PREFIX := "__test_nb_sheet_disclosure_"
const OWNERS := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
const LEGACY_CATALOG_SHA256 := "42d31ad557c795401bdb0fc5a46785c331e0cee1ec7a5cc38077894c7265db41"
const LEGACY_BODY_SHA256 := {
    "NB_MIRROR_NOTE_C5_INFO": {
        "ko-KR": "04fe4d768dad72892b55e551355264c05f71efb9c366caeba1cfe9fb36a9faa1",
        "en-US": "c53df11c55b292d9dfc294d53f1becdcf02e194bdac522c57cdc9510a699a9fd"},
    "NB_MIRROR_NOTE_J3_MEMORY": {
        "ko-KR": "65f9b2e49ea407f5c1cb90ff839811d97a29986ef07ca819704924a1194ef2eb",
        "en-US": "d2aaba318ff784577e3bab1aa87fe795a93fd736dec4036fda69277acf34521f"}}
const CHANNEL_MARKERS := [
    "수직 잠금선", "대각 닦임", "이중 맥박", "꽃잎", "이중 액자",
    "vertical lock line", "diagonal wipe", "double pulse", "petal halo", "double frame",
    "다섯 출처", "five sources"]
const MEMORY_MARKERS := [
    "문은 네가 고르는 곳에", "더 큰 손", "내 손보다 큰 손", "연필이 종이 가루",
    "the door goes where you choose", "a larger hand", "pencil pushes paper dust"]

var checks := 0
var errors: Array = []
var cases: Array = []
var view: BlackMirrorController
var slot := ""
var case_id := "catalog"
var seen_tokens: Dictionary = {}
var save_events := 0
var serial := 0
var running := false
var finished := false
var run_started := 0
var case_started := 0
var case_error_start := 0
var case_check_start := 0
var old_locale := ""
var old_flavor: Variant


func _ready() -> void:
    call_deferred("_run")


func _process(_delta: float) -> void:
    # Also produces a failure report if an unexpected engine error abandons a coroutine.
    if running and not finished and Time.get_ticks_msec() - run_started > 1200000:
        _expect(false, "run watchdog expired", {"slot": slot})
        _report()


func _run() -> void:
    running = true
    run_started = Time.get_ticks_msec()
    old_locale = TranslationServer.get_locale()
    old_flavor = ProjectSettings.get_setting("ggb/build_flavor", "demo")
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    SaveManager.save_completed.connect(_saved)
    SaveManager.save_failed.connect(_save_failed)
    if not _expect(OS.is_debug_build(), "test-slot cleanup requires a debug build"):
        _report()
        return
    if not _expect(CONTENT.diagnostics().get("ok", false), "common catalogs validate", CONTENT.diagnostics()):
        _report()
        return
    _check_legacy_catalog()
    for locale in ["ko-KR", "en-US"]:
        TranslationServer.set_locale(locale)
        await _c5_case("minimal", false)
        await _c5_case("all_channels", false)
        await _c5_case("all_channels_historical_v1", true)
        await _j3_case("skip", false)
        await _j3_case("read", false)
        await _j3_case("read_historical_v1", true)
    case_id = "catalog_after_cases"
    _check_legacy_catalog()
    _expect(cases.size() == 12, "all twelve cases completed", {"actual": cases.size()})
    _report()


func _report() -> void:
    if finished: return
    finished = true
    var result := {"ok": errors.is_empty(), "checks": checks, "cases": cases, "errors": errors,
        "source_scope": {
            "baseline": "source/integration commit bound by caller receipt; not queried from git inside the game",
            "project": ProjectSettings.globalize_path("res://"),
            "harness": get_script().resource_path,
            "production": "actual BlackMirrorController/BlackMirrorSession, common event writer, NotebookQuery and LoadCoordinator",
            "fixtures": "isolated exposed C5 / unlocked J3; prior chapters, physical mirror opening and patrol timing are not replayed",
            "historical_v1": "event_note_commit fixtures only after actual corresponding channel/memory observations; never mutate catalogs",
            "storage": "__test_nb_sheet_disclosure_* only; real saves and same-process destroy/load/recreate",
            "waits": "controller history request + SaveManager worker + durable observation tokens + surface receipts; wall-clock deadlines, no fixed-frame save assumption",
            "async_history": "--ggb-dev-notebook-async" in OS.get_cmdline_user_args(),
            "not_covered": ["OS input", "cross-process restart", "full campaign", "EP01 first sleep/first morning"]}}
    print("NOTEBOOK_SHEET_DISCLOSURE_AUDIT: ", JSON.stringify(result))
    TranslationServer.set_locale(old_locale)
    ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
    get_tree().quit(0 if errors.is_empty() else 1)


func _expect(value: bool, label: String, evidence: Dictionary = {}) -> bool:
    checks += 1
    if not value: errors.append({"case": case_id, "check": label, "evidence": evidence.duplicate(true)})
    return value


func _saved(saved_slot: StringName, _point: StringName) -> void:
    if String(saved_slot) == slot: save_events += 1


func _save_failed(saved_slot: StringName, ids: PackedStringArray) -> void:
    if String(saved_slot) == slot: _expect(false, "production save failed", {"error_ids": Array(ids)})


func _check_legacy_catalog() -> void:
    var digest := HashingContext.new()
    digest.start(HashingContext.HASH_SHA256)
    digest.update(FileAccess.get_file_as_bytes("res://data/notebook/mirror_v1.json"))
    _expect(digest.finish().hex_encode() == LEGACY_CATALOG_SHA256, "mirror_v1.json remains byte-identical to baseline")
    for id in LEGACY_BODY_SHA256:
        var row := CONTENT.definition(id, 1)
        for locale in LEGACY_BODY_SHA256[id]:
            var body := String(row.get("locales", {}).get(locale, {}).get("body", ""))
            _expect(body.sha256_text() == LEGACY_BODY_SHA256[id][locale], "historical v1 body is unchanged", {"content_id": id, "locale": locale})


func _begin_case(name: String, journal: bool) -> bool:
    case_id = name + "/" + TranslationServer.get_locale()
    case_started = Time.get_ticks_msec()
    case_error_start = errors.size()
    case_check_start = checks
    seen_tokens = {}
    save_events = 0
    slot = SLOT_PREFIX + name + "_" + TranslationServer.get_locale().replace("-", "_")
    if not _expect(slot.begins_with(SLOT_PREFIX), "test-only slot guard"): return false
    SaveManager.delete_test_slot(slot)
    GameState.reset_for_test()
    var state: Dictionary = GameState.get_snapshot()
    state.meta_progress.dialogue_history = ARCHIVE.create()
    state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
    var known: Dictionary = state.meta_progress.knowledge_entries
    for key in ["PROLOGUE_COMPLETE", "c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record", "mirror_tracing_acquired"]:
        known[key] = true
    known.j2_restored_day = 1
    known.self_authored_mark = {"type": "sentence", "text": "disclosure audit mark", "day": 1}
    known.erase("MEM_FATHER_DRAWN_DOOR_FRAGMENT")
    known.erase("MEM_FATHER_TEA_HAND_FRAGMENT")
    known.erase("c5_inspections")
    known.erase("c5_info_complete")
    known.erase("C5_MIRROR_TRACING")
    for key in DIAGNOSTICS.FACTS.values(): known.erase(key)
    if journal:
        known.c5_info_complete = true
        known.C5_MIRROR_TRACING = true
        known.KN_B1_LIBRARY_WINDOW = true
        known.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
    state.meta_progress.notebook_persistence_confirmed = true
    state.meta_progress.journal_stage = 2
    state.meta_progress.event_history.erase("EP02_DIALOGUE_EFFECTS")
    state.loop_state.day_index = 2
    state.loop_state.time_block = "evening_free"
    state.loop_state.location_id = "M1_LIBRARY_INNER" if journal else "M1_MIRROR_GALLERY"
    state.loop_state.event_local_states = {
        "CHAPTER_ONE": {"edgar_state": "absent", "routine_done": true},
        "BLACK_MIRROR": {"surface_open": true, "channels_scanned": [], "diagnostics_scanned": []}}
    if not _install(state): return false
    return await _launch()


func _install(state: Dictionary) -> bool:
    serial += 1
    var installed := StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("SHEET_DISCLOSURE_FIXTURE_%d" % serial))
    return _expect(installed.get("ok", false), "fixture installs through real validator", installed)


func _launch() -> bool:
    view = VIEW.new()
    view.configure_session(slot, "MORNING_ROUTE")
    add_child(view)
    if not _expect(view.session != null and view.session.get_script() == preload("res://scripts/systems/black_mirror_session.gd"), "actual production session and controller"):
        return false
    view._edgar_timer.stop()
    return await _settle("controller ready")


func _io_idle() -> bool:
    return SaveManager._notebook_job.is_empty() and (not is_instance_valid(view) or view._history_async_request.is_empty())


func _settle(label: String, allow_modal: bool = false) -> bool:
    var deadline := Time.get_ticks_msec() + TIMEOUT_MS
    while Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
        if not is_instance_valid(view): return _expect(false, label + ": controller disappeared")
        view._edgar_timer.stop()
        if not _io_idle(): continue
        if view._dialogue_active:
            if not view._record_current_history_line():
                if not _io_idle(): continue
                return _expect(false, label + ": displayed line failed to persist", _status())
            var line: Dictionary = view._dialogue_lines[view._dialogue_index]
            var token := String(line.get("presentation_token", ""))
            if not _expect(_has_token(token), label + ": displayed occurrence has durable observation", {"token": token}): return false
            seen_tokens[token] = String(line.get("notebook_content", {}).get("content_id", ""))
            view._advance_dialogue()
            continue
        if view._modal_active:
            if not _expect(allow_modal and not view._recorded_modal_request.is_empty(), label + ": expected recorded modal only", _status()): return false
            var request: Dictionary = view._recorded_modal_request
            if not _expect(bool(request.get("recorded", false)) and _has_token(String(request.history_context.presentation_token)), label + ": options actually displayed and recorded"): return false
            return true
        if not view._notebook_surface_allowed():
            if not _io_idle(): continue
            return _expect(false, label + ": visible surface failed to persist", _status())
        if view._notebook_surfaces.has_pending(): continue
        return true
    return _expect(false, label + ": deadline expired", _status())


func _status() -> Dictionary:
    if not is_instance_valid(view): return {"view": "freed"}
    return {"status": view._status_label.text, "dialogue": view._dialogue_active,
        "modal": view._modal_active, "stage": view.session.stage(), "worker_busy": not _io_idle()}


func _act(action: String, value: Variant = null) -> bool:
    if not await _settle("before " + action): return false
    view._do(action, value)
    return await _settle(action)


func _press(index: int) -> bool:
    if not await _settle("before modal selection", true): return false
    if not _expect(view._modal_active, "recorded choice is open"): return false
    var request: Dictionary = view._recorded_modal_request
    if not _expect(index in range(request.get("actions", []).size()), "actual choice index exists", {"index": index}): return false
    view._recorded_choice_pressed(request, index)
    return await _settle("after modal selection")


func _archive() -> Dictionary:
    return GameState.get_snapshot().meta_progress.dialogue_history


func _ledger() -> Dictionary:
    return GameState.get_snapshot().meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create())


func _has_token(token: String) -> bool:
    if token.is_empty(): return false
    for entry in _archive().entries:
        if entry.get("observation", entry.get("snapshot_context", {})).get("presentation_token") == token: return true
    return false


func _has_content(id: String) -> bool:
    return _archive().entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == id)


func _latest(id: String) -> Dictionary:
    var rows: Array = _ledger().revisions
    for index in range(rows.size() - 1, -1, -1):
        if rows[index].metadata.knowledge_id == id: return rows[index]
    return {}


func _check_disk(label: String) -> bool:
    if not _expect(_io_idle(), label + ": no in-flight persistence"): return false
    var loaded: Dictionary = SaveManager.load_slot(slot)
    if not _expect(loaded.get("ok", false), label + ": actual disk load succeeds", {"error_ids": loaded.get("error_ids", [])}): return false
    return _expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), loaded.snapshot), label + ": durable snapshot equals live snapshot")


func _reload() -> bool:
    if not await _settle("before reload"): return false
    if not _check_disk("before reload"): return false
    var frozen := _freeze()
    view.queue_free()
    while is_instance_valid(view): await get_tree().process_frame
    view = null
    var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(slot)
    if not _expect(loaded.get("ok", false), "real LoadCoordinator installs saved slot", loaded): return false
    _preserved(frozen, "after disk install")
    if not await _launch(): return false
    _preserved(frozen, "after controller recreation")
    return _check_disk("after controller recreation")


func _freeze() -> Dictionary:
    var entries := {}
    for entry in _archive().entries:
        var immutable: Dictionary = entry.duplicate(true)
        # References may legitimately add protection; observation payloads must never change.
        immutable.erase("protection_reasons")
        entries[entry.entry_uid] = immutable
    return {"entries": entries, "revisions": _ledger().revisions.duplicate(true)}


func _preserved(frozen: Dictionary, label: String) -> void:
    var current := _freeze()
    for uid in frozen.entries:
        _expect(current.entries.has(uid) and StateSnapshotValidator.same_persisted_value(frozen.entries[uid], current.entries.get(uid, {})), label + ": acquired observation unchanged", {"uid": uid})
    var by_revision := {}
    for revision in current.revisions: by_revision[revision.revision_uid] = revision
    for revision in frozen.revisions:
        _expect(StateSnapshotValidator.same_persisted_value(revision, by_revision.get(revision.revision_uid, {})), label + ": prior revision and source refs unchanged", {"revision_uid": revision.revision_uid})


func _notebook_rows(locale: String) -> Array:
    var before: Dictionary = GameState.get_snapshot()
    var archive: Dictionary = before.meta_progress.dialogue_history
    var query := QUERY.new()
    var scope := {"namespace": SaveManager.get_build_flavor(), "slot": slot,
        "run_id": String(SaveManager.inspect_slot(slot).get("run_id", "")),
        "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": int(GameState.load_epoch)}
    var opened := query.open(archive, _ledger(), scope, locale, before.meta_progress.knowledge_entries, view.session.stage())
    if not _expect(opened.get("ok", false), "real notebook query opens", opened): return []
    var rows: Array = []
    for tab in QUERY.TABS:
        var page_index := 0
        while true:
            var page := query.page({"tab": tab, "include_previous": true, "include_refuted": true}, page_index, query.cache_key())
            if not _expect(page.get("ok", false) and int(page.get("error_count", -1)) == 0, "notebook page has no hidden rendering errors", {"tab": tab, "page": page_index}): break
            for item in page.items:
                var detail := query.detail(item.key, query.cache_key())
                if not _expect(detail.get("ok", false), "actual notebook detail renders", {"key": item.key}): continue
                rows.append({"locale": locale, "kind": item.kind, "reference": item.reference,
                    "text": detail.text, "title": detail.title, "previous": detail.previous})
            page_index += 1
            if page_index >= int(page.pages): break
    query.close()
    _expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "notebook query is read-only")
    return rows


func _no_document_leaks(markers: Array, label: String) -> void:
    for locale in ["ko-KR", "en-US"]:
        var leaks: Array = []
        for row in _notebook_rows(locale):
            if row.kind not in ["document_segment", "legacy_note"]: continue
            var text := String(row.text).to_lower()
            for marker in markers:
                if text.contains(String(marker).to_lower()):
                    leaks.append({"reference": row.reference, "marker": marker, "text": row.text})
                    break
        _expect(leaks.is_empty(), label + ": notebook material excludes undisclosed body", {"locale": locale, "leaks": leaks})
    var legacy: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries.get("chapter_notebook", {})
    for key in legacy:
        var text := String(legacy[key]).to_lower()
        for marker in markers:
            if text.contains(String(marker).to_lower()):
                _expect(false, label + ": legacy notebook body also excludes undisclosed material", {"key": key, "marker": marker, "text": text})
                break


func _historical_note(id: String) -> bool:
    # The caller first obtains real matching observations, then models an old saved event note.
    var state: Dictionary = GameState.get_snapshot()
    var row := CONTENT.definition(id, 1)
    if not _expect(not row.is_empty(), "historical v1 definition still distributed", {"id": id}): return false
    var written := NOTES.write(state, id, row.locales["ko-KR"].body, view.session.history_context(), TranslationServer.get_locale(), 1)
    if not _expect(written.get("ok", false), "historical note uses common validated event writer", written): return false
    if not _install(state): return false
    serial += 1
    var saved: Dictionary = SaveManager.save_snapshot(slot, view.session._save_point(state), state, GameState.revision, "SHEET_DISCLOSURE_OLD_%d" % serial)
    if not _expect(saved.get("ok", false), "historical fixture persisted", saved): return false
    return await _reload()


func _check_historical_render(id: String) -> void:
    var matches: Array = _archive().entries.filter(func(entry: Dictionary) -> bool:
        var observed: Dictionary = entry.get("observation", {})
        return observed.get("content_id") == id and int(observed.get("content_version", 0)) == 1)
    _expect(matches.size() == 1, "one legitimate historical v1 observation survives", {"content_id": id, "count": matches.size()})
    for entry in matches:
        for locale in ["ko-KR", "en-US"]:
            var rendered := CONTENT.render_entry(entry, locale)
            if not _expect(rendered.get("ok", false), "historical original renders by pinned version", rendered): continue
            var parts: Array = rendered.entry.segments
            if not _expect(parts.size() == 1, "historical v1 has one complete body", {"content_id": id}): continue
            _expect(String(parts[0].text).sha256_text() == LEGACY_BODY_SHA256[id][locale], "historical original cannot be replaced by safer new summary", {"content_id": id, "locale": locale})
            var found := false
            for row in _notebook_rows(locale):
                if row.reference.uid == entry.entry_uid:
                    found = String(row.text).contains(String(parts[0].text))
                    break
            _expect(found, "historical original remains accessible in notebook", {"content_id": id, "locale": locale})


func _c5_case(mode: String, historical: bool) -> void:
    if not await _begin_case("c5_" + mode, false):
        await _end_case({"setup_failed": true})
        return
    var all_channels := mode != "minimal"
    var observed_channels := {}
    _expect(DIAGNOSTICS.required_count(GameState.get_snapshot()) == 0, "raw fixture has no fabricated diagnostic inspections")
    for key in ["BODY", "PERSONALITY"]:
        if not await _act("c_scan", key):
            await _end_case({"setup_failed": true})
            return
        _expect(DIAGNOSTICS.seen(GameState.get_snapshot(), key), "actual diagnostic persisted", {"diagnostic": key})
        _expect(_has_content("NB_EP02_C5_HOT_%s_FIRST" % key), "diagnostic has its actual authored observation", {"diagnostic": key})
    if all_channels:
        for owner in OWNERS:
            var before: Dictionary = seen_tokens.duplicate()
            if not await _act("c_scan", owner):
                await _end_case({"setup_failed": true})
                return
            var refs: Array = []
            for entry in _archive().entries:
                var observed: Dictionary = entry.get("observation", {})
                var token := String(observed.get("presentation_token", ""))
                var channel_ids := ["NB_EP02_C5_CH_%s_FIRST" % owner, "NB_EP02_C5_CH_%s_REPEAT" % owner,
                    "NB_EP02_C5_HOT_%s_CHANNEL" % owner, "NB_MIRROR_SCAN_SURFACE_" + owner, "NB_MIRROR_SCAN_COPY_" + owner]
                if seen_tokens.has(token) and not before.has(token) and observed.get("content_id") in channel_ids:
                    for segment in observed.get("segments", []): refs.append(ARCHIVE.make_reference(entry, segment.segment_id))
            observed_channels[owner] = refs
            _expect(DIAGNOSTICS.seen(GameState.get_snapshot(), owner) and not refs.is_empty(), "owner channel was really displayed and acquired", {"owner": owner})
    else:
        _expect(view._mirror().mirror_local().channels_scanned.is_empty(), "minimal path never inspects owner channels")
        for owner in OWNERS:
            _expect(not DIAGNOSTICS.seen(GameState.get_snapshot(), owner), "uninspected owner has no observation", {"owner": owner})
    if historical and not await _historical_note("NB_MIRROR_NOTE_C5_INFO"):
        await _end_case({"setup_failed": true})
        return
    var acquired := _freeze()
    view._confirm_sheet_trace()
    if not await _press(1):
        await _end_case({"setup_failed": true})
        return
    _expect(view.session.known("c5_info_complete") and view.session.known("C5_MIRROR_TRACING"), "explicit trace consent commits real KB ownership")
    _expect(not _latest("MIRROR_TRACING").is_empty(), "real tracing knowledge card exists")
    _c5_inspections(all_channels, "after trace commit")
    _preserved(acquired, "C5 commit")
    _channel_label_sources()
    if all_channels: _channel_sources(observed_channels)
    if historical: _check_historical_render("NB_MIRROR_NOTE_C5_INFO")
    if await _reload():
        _expect(view.session.known("c5_info_complete"), "trace KB ownership survives reload")
        _c5_inspections(all_channels, "after trace reload")
        _channel_label_sources()
        if all_channels: _channel_sources(observed_channels)
        if historical: _check_historical_render("NB_MIRROR_NOTE_C5_INFO")
    await _end_case({"observed_channels": observed_channels.keys(), "historical_v1": historical,
        "tracing_revision": _latest("MIRROR_TRACING"),
        "kb_c5_complete": GameState.get_snapshot().meta_progress.knowledge_entries.get("c5_info_complete", false)})


func _channel_label_sources() -> void:
    var tracing := _latest("MIRROR_TRACING")
    var linked := {}
    for reference in tracing.get("source_refs", []): linked[ARCHIVE.reference_identity(reference)] = true
    for owner in OWNERS:
        var matched := false
        for entry in _archive().entries:
            if entry.get("record_class") != "authored": continue
            var observed: Dictionary = entry.observation
            if observed.content_id not in ["NB_PUZZLE_C_CHANNEL_%s_UNCHECKED" % owner, "NB_PUZZLE_C_CHANNEL_%s_CHECKED" % owner]: continue
            for segment in observed.segments:
                if linked.has(ARCHIVE.reference_identity(ARCHIVE.make_reference(entry, segment.segment_id))): matched = true
        _expect(matched, "tracing cites the channel label actually displayed, without granting an inspection", {"owner": owner})
    var resolved := ARCHIVE.resolve(_archive(), tracing.get("observation_ref", {}))
    if _expect(resolved.get("ok", false), "recorded circuit source resolves"):
        _expect(preload("res://scripts/systems/notebook_visuals.gd").supports(resolved.entry, "body"), "recorded circuit retains its read-only visual viewer")
        for locale in ["ko-KR", "en-US"]:
            var row := CONTENT.definition(String(resolved.entry.observation.content_id), int(resolved.entry.observation.content_version))
            _expect(row.locales[locale].body.sha256_text() == LEGACY_BODY_SHA256.NB_MIRROR_NOTE_C5_INFO[locale], "visible circuit/channel wording remains unchanged", {"locale": locale})


func _channel_sources(observed_channels: Dictionary) -> void:
    var tracing := _latest("MIRROR_TRACING")
    var linked := {}
    for reference in tracing.get("source_refs", []):
        linked[ARCHIVE.reference_identity(reference)] = true
        _expect(ARCHIVE.resolve(_archive(), reference).get("ok", false), "tracing source refers only to a real disclosed segment", {"reference": reference})
    for owner in observed_channels:
        var found := false
        for reference in observed_channels[owner]:
            if linked.has(ARCHIVE.reference_identity(reference)): found = true
            var resolved := ARCHIVE.resolve(_archive(), reference)
            _expect(resolved.get("ok", false), "individual channel original remains accessible", {"owner": owner, "reference": reference})
        _expect(found, "base tracing links an actually inspected individual channel (not merged prose)", {"owner": owner})
    for locale in ["ko-KR", "en-US"]:
        var bodies := {}
        for row in _notebook_rows(locale): bodies[QUERY.reference_key(row.reference)] = row.text
        for owner in observed_channels:
            for reference in observed_channels[owner]:
                var resolved := ARCHIVE.resolve(_archive(), reference)
                if not resolved.get("ok", false): continue
                var rendered := CONTENT.render_segment(resolved.entry, reference.segment_id, locale)
                if not _expect(rendered.get("ok", false), "inspected channel original renders in both languages", {"owner": owner, "locale": locale}): continue
                var text := String(rendered.entry.segments[0].text)
                _expect(not text.is_empty() and String(bodies.get(QUERY.reference_key(reference), "")).contains(text), "notebook detail retains the individual channel body", {"owner": owner, "locale": locale, "reference": reference})


func _c5_inspections(all_channels: bool, label: String) -> void:
    var state: Dictionary = GameState.get_snapshot()
    for key in ["BODY", "PERSONALITY"]:
        _expect(DIAGNOSTICS.seen(state, key), label + ": mandatory inspection retained", {"diagnostic": key})
    for owner in OWNERS:
        _expect(DIAGNOSTICS.seen(state, owner) == all_channels, label + ": owner inspection matches actual actions", {"owner": owner})


func _j3_case(mode: String, historical: bool) -> void:
    if not await _begin_case("j3_" + mode, true):
        await _end_case({"setup_failed": true})
        return
    var read_memory := mode != "skip"
    if not await _act("j3_overlay"):
        await _end_case({"setup_failed": true})
        return
    for point in ["BED", "GREEN", "CLOCK"]:
        if not await _act("j3_point", point):
            await _end_case({"setup_failed": true})
            return
    _expect(view._j3_memory_available() and not view._j3_memory_seen(), "real three-point investigation offers unread optional memory")
    view._open_j3_memory()
    if not await _press(1 if read_memory else 0):
        await _end_case({"setup_failed": true})
        return
    _memory_state(read_memory, "after explicit memory choice")
    if not await _reload():
        await _end_case({"setup_failed": true})
        return
    _memory_state(read_memory, "after pre-restoration reload")
    if historical and not await _historical_note("NB_MIRROR_NOTE_J3_MEMORY"):
        await _end_case({"setup_failed": true})
        return
    var acquired := _freeze()
    for action in ["j3_compare", "j3_flip_page", "j3_compare"]:
        if not await _act(action):
            await _end_case({"setup_failed": true})
            return
    for part in range(4):
        if not await _act("j3_piece", part):
            await _end_case({"setup_failed": true})
            return
    _expect(view._mirror().mirror_local().j3_order == [0, 1, 2, 3], "actual puzzle actions assemble the third page")
    view._confirm_sheet_j3_restore()
    if not await _press(1):
        await _end_case({"setup_failed": true})
        return
    _expect(int(GameState.get_snapshot().meta_progress.journal_stage) == 3 and not _latest("MIRROR_J3").is_empty(), "explicit restoration commits actual journal and its notebook card")
    _memory_state(read_memory, "after restoration")
    _preserved(acquired, "J3 restoration")
    if historical: _check_historical_render("NB_MIRROR_NOTE_J3_MEMORY")
    if await _reload():
        _memory_state(read_memory, "after restoration reload")
        if historical: _check_historical_render("NB_MIRROR_NOTE_J3_MEMORY")
    await _end_case({"memory_requested": read_memory, "historical_v1": historical,
        "door_fragment": GameState.get_snapshot().meta_progress.knowledge_entries.get("MEM_FATHER_DRAWN_DOOR_FRAGMENT", ""),
        "journal_revision": _latest("MIRROR_J3")})


func _memory_state(expected: bool, label: String) -> void:
    var known: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries
    var receipt: bool = GameState.get_snapshot().meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0046", false)
    var observed := _has_content("NB_EP02_J3_MEMORY_003")
    _expect(receipt == expected and observed == expected, label + ": completion receipt and actual terminal observation agree with choice", {"receipt": receipt, "observed": observed})
    _expect(view._j3_memory_seen() == expected, label + ": production memory-seen predicate agrees")
    _expect((known.get("MEM_FATHER_DRAWN_DOOR_FRAGMENT", "") == "episodic_fragment") == expected, label + ": KB never invents or deletes the door fragment")
    if not expected:
        _expect(not _has_content("NB_MIRROR_NOTE_J3_MEMORY"), label + ": skipped memory has no legacy memory card")
        _no_document_leaks(MEMORY_MARKERS, label)
    else:
        var found := false
        for row in _notebook_rows(TranslationServer.get_locale()):
            for marker in MEMORY_MARKERS:
                if String(row.text).to_lower().contains(String(marker).to_lower()): found = true
        _expect(found, label + ": actually read memory original remains available in notebook")


func _end_case(evidence: Dictionary) -> void:
    var idle_deadline := Time.get_ticks_msec() + TIMEOUT_MS
    while not _io_idle() and Time.get_ticks_msec() < idle_deadline: await get_tree().process_frame
    var idle := _expect(_io_idle(), "case cleanup waits for actual write completion")
    var state := GameState.get_snapshot()
    var disk := SaveManager.load_slot(slot)
    _expect(disk.get("ok", false) and StateSnapshotValidator.same_persisted_value(state, disk.get("snapshot", {})), "case evidence matches the durable slot")
    var directory := "user://__test_nb_sheet_disclosure_evidence"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    var name := case_id.replace("/", "_") + ".json"
    var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
    if _expect(file != null, "case snapshot evidence is writable"):
        file.store_string(JSON.stringify({"case": case_id, "state": state, "durable_state": disk.get("snapshot", {})}))
        file.close()
        evidence["snapshot_file"] = name
    if is_instance_valid(view):
        view.queue_free()
        while is_instance_valid(view): await get_tree().process_frame
    view = null
    _expect(save_events > 0, "case observed real save-completed events", {"events": save_events})
    cases.append({"id": case_id, "ok": errors.size() == case_error_start,
        "checks": checks - case_check_start, "errors": errors.size() - case_error_start,
        "elapsed_ms": Time.get_ticks_msec() - case_started, "save_events": save_events,
        "actually_presented_tokens": seen_tokens.duplicate(true), "evidence": evidence})
    if idle and slot.begins_with(SLOT_PREFIX): SaveManager.delete_test_slot(slot)
