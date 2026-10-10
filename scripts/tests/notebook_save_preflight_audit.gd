extends Node

const STORAGE := preload("res://scripts/autoload/save_manager.gd")
const FIXTURES := preload("res://scripts/tests/notebook_performance_fixture.gd")
const SLOT := "__test_save_source"
var errors: Array = []
var checks := 0
var measurements: Array = []

class Uncached extends "res://scripts/autoload/save_manager.gd":
    func _save_source_cache_allowed() -> bool:
        return false

class FailedPromotion extends "res://scripts/autoload/save_manager.gd":
    func _promote_temporary(_paths: Dictionary) -> Error:
        return ERR_CANT_CREATE

func _expect(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)

func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    _expect(file != null, "isolated fixture writable")
    if file == null: return
    file.store_string(text)
    file.flush()
    file.close()

func _ready() -> void:
    _safety()
    if errors.is_empty(): _measure()
    var result := {"ok":errors.is_empty(), "checks":checks, "errors":errors,
        "measurements":measurements, "scope":"HEADLESS sync save preflight, exploratory paired n=3"}
    print("SAVE_PREFLIGHT_AUDIT: ", JSON.stringify(result))
    print("SAVE_PREFLIGHT_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _safety() -> void:
    var manager := STORAGE.new()
    var original_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor", "demo")
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    manager.delete_test_slot(SLOT)
    var state := GameState.make_default_snapshot()
    _expect(manager._save_source_cache_allowed(), "standard v2 storage enables narrow preflight")
    _expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "CERT_01").ok, "seed primary")
    _expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 2, "CERT_02").ok, "seed backup")
    var paths := manager._slot_paths(SLOT)
    var main := FileAccess.get_file_as_string(paths.main)
    var backup := FileAccess.get_file_as_bytes(paths.backup)
    var proof := manager._read_save_source(paths.main)
    _expect(proof.ok and not proof.has("snapshot") and proof.header.transaction_id == "CERT_02", "same-byte preflight returns metadata only")
    _expect(manager._read_save_source(paths.backup).ok and not manager._read_save_source(paths.backup).has("snapshot"), "backup independently rehashes its certified bytes")
    proof.header.transaction_id = "caller mutation"
    _expect(manager._read_save_source(paths.main).header.transaction_id == "CERT_02", "proof header detached from caller")
    var full := manager._read_and_validate(paths.main)
    _expect(full.ok and full.has("snapshot") and StateSnapshotValidator.same_persisted_value(full.snapshot, state), "load still performs complete validation and returns exact snapshot")
    var tampered := main.replace("CERT_02", "CERT_99")
    _expect(tampered.length() == main.length() and tampered != main, "same-length corruption fixture")
    _write(paths.main, tampered)
    _expect(manager._read_save_source(paths.main).get("error_id") == "ERR_SAVE_CHECKSUM", "same-length tamper never trusts cached header/checksum")
    _expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 3, "CERT_03").ok, "corrupt primary can be replaced")
    _expect(FileAccess.get_file_as_bytes(paths.backup) == backup, "corrupt primary never replaces valid backup")
    full = manager._read_and_validate(paths.main)
    for defect in ["schema", "design", "cursor", "knowledge", "archive"]:
        var header: Dictionary = full.header.duplicate(true)
        var candidate: Dictionary = full.snapshot.duplicate(true)
        match defect:
            "schema": header.schema_version = 999
            "design": header.design_revision = "future-design"
            "cursor": candidate.loop_state.event_local_states.NOTEBOOK_PRESENTATION = {"schema_version":999}
            "knowledge": candidate.meta_progress.knowledge_entries.notebook_knowledge = {"schema_version":999}
            "archive": candidate.meta_progress.dialogue_history.schema_version = 999
        _write(paths.main, manager._encode_payload(header, candidate).text)
        var changed := FileAccess.get_file_as_bytes(paths.main)
        var rejected := manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "BLOCKED")
        _expect(not rejected.ok, defect + " external replacement blocks save despite warm certificate")
        _expect(FileAccess.get_file_as_bytes(paths.main) == changed and FileAccess.get_file_as_bytes(paths.backup) == backup, defect + " rejection preserves source and backup")
    _write(paths.main, main)
    var future_header: Dictionary = full.header.duplicate(true)
    future_header.schema_version = 999
    _write(paths.temporary, manager._encode_payload(future_header, full.snapshot).text)
    _expect(not manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "PENDING_FUTURE").ok, "pending temporary is always fully validated")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(paths.temporary))
    var cache_size: int = manager._save_source_cache.size()
    ProjectSettings.set_setting("ggb/build_flavor", "demo")
    _expect(manager._read_save_source(paths.main).has("snapshot"), "changed flavor cannot reuse proof")
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var root := manager.get_save_root()
    manager._storage_context = {"flavor":"full", "root":"user://different_root"}
    _expect(manager._read_save_source(paths.main).has("snapshot"), "changed root cannot reuse proof")
    manager._storage_context.clear()
    _expect(manager._save_source_cache.size() == cache_size, "policy misses do not retain full parsed trees")
    var custom := Uncached.new()
    _expect(not custom._save_source_cache_allowed() and custom._read_save_source(paths.main).has("snapshot"), "custom validator always keeps virtual full read path")
    custom.free()
    var failure := FailedPromotion.new()
    var saved_main := FileAccess.get_file_as_bytes(paths.main)
    _expect(not failure.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 5, "PROMOTION_FAIL").ok, "promotion failure never reports success")
    _expect(FileAccess.get_file_as_bytes(paths.main) == saved_main, "promotion failure restores prior certified main")
    failure.free()
    for index in range(manager.SAVE_SOURCE_CACHE_LIMIT + 3):
        _expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, index + 10, "BOUND_%02d" % index).ok, "bounded cache seed")
        _expect(manager._save_source_cache.size() <= manager.SAVE_SOURCE_CACHE_LIMIT, "bounded certificate count")
    for item in manager._save_source_cache.values():
        _expect(item.keys().size() == 3 and not item.has("snapshot") and not item.has("bytes"), "certificate retains no state or raw bytes")
        _expect(JSON.stringify(item).to_utf8_buffer().size() <= manager.SAVE_SOURCE_CACHE_ENTRY_BYTES, "certificate byte bound")
    var legacy := state.duplicate(true)
    legacy.meta_progress.dialogue_history = {"next_sequence":0, "entries":[]}
    var legacy_header: Dictionary = full.header.duplicate(true)
    legacy_header.schema_version = 1
    var legacy_text: String = manager._encode_payload(legacy_header, legacy).text
    _write(paths.main, legacy_text)
    _expect(manager._read_save_source(paths.main).has("snapshot"), "schema1 always fully validates")
    var legacy_loaded := manager._read_and_validate(paths.main)
    _expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 30, "LEGACY_PROMOTE").ok, "legacy source promoted normally")
    var preserved: String = paths.main.get_base_dir().path_join("pre_notebook_" + legacy_loaded.header.checksum + ".json")
    _expect(FileAccess.get_file_as_string(preserved) == legacy_text, "legacy migration backup exact bytes preserved")
    manager.delete_test_slot(SLOT)
    _expect(not manager._read_save_source(paths.main).ok, "deleted file cannot be revived by proof")
    _expect(manager._read_save_source(paths.main).get("error_id") == "ERR_SAVE_NOT_FOUND", "missing error contract preserved")
    ProjectSettings.set_setting("ggb/build_flavor", original_flavor)
    manager.free()

func _measure() -> void:
    for locale in ["ko_KR", "en_US"]:
        TranslationServer.set_locale(locale)
        for fixture_id in FIXTURES.IDS:
            var fixture := FIXTURES.build(fixture_id)
            _expect(fixture.ok, "fixed performance fixture")
            if not fixture.ok: continue
            var state := GameState.make_default_snapshot()
            state.meta_progress.dialogue_history = fixture.archive
            state.meta_progress.knowledge_entries.notebook_knowledge = fixture.ledger
            var managers := [Uncached.new(), STORAGE.new()]
            for index in range(2):
                var slot := SLOT + "_" + str(index)
                managers[index].delete_test_slot(slot)
                for seed in range(2):
                    _expect(managers[index].save_snapshot(slot, "SAVE_NEW_GAME", state, seed + 1, "PAIR_SEED_%d" % seed).ok, "pair seed durable")
            for repeat in range(3):
                for index in ([0, 1] if repeat % 2 == 0 else [1, 0]):
                    var slot := SLOT + "_" + str(index)
                    var before := JSON.stringify(state)
                    var start := Time.get_ticks_usec()
                    var saved: Dictionary = managers[index].save_snapshot(slot, "SAVE_NEW_GAME", state, repeat + 3, "PAIR_%d" % repeat)
                    var duration_ms := (Time.get_ticks_usec() - start) / 1000.0
                    _expect(saved.ok and JSON.stringify(state) == before, "pair durable success and caller immutable")
                    var loaded: Dictionary = managers[index]._read_and_validate(managers[index]._slot_paths(slot).main)
                    _expect(loaded.ok and StateSnapshotValidator.same_persisted_value(loaded.snapshot, state), "pair full disk snapshot exact")
                    measurements.append({"fixture":fixture_id, "locale":locale, "repeat":repeat,
                        "mode":"uncached" if index == 0 else "certificate", "total_ms":duration_ms, "ok":saved.ok,
                        "archive_sha256":JSON.stringify(fixture.archive).sha256_text(), "ledger_sha256":JSON.stringify(fixture.ledger).sha256_text()})
            for index in range(2):
                managers[index].delete_test_slot(SLOT + "_" + str(index))
                managers[index].free()
    _expect(measurements.size() == 48, "four fixtures two locales paired three repeats")
