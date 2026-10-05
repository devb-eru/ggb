extends RefCounted

const SLOT := "__test_notebook_save_safety"
var errors := PackedStringArray()
var checks := 0


class PromotionFailure:
	extends "res://scripts/autoload/save_manager.gd"
	var verified_temp := false
	func _promote_temporary(paths: Dictionary) -> Error:
		verified_temp = _read_and_validate(paths.temporary).get("ok", false)
		return ERR_CANT_CREATE


class SummaryProbe:
	extends "res://scripts/autoload/save_manager.gd"
	var validations := 0
	func _validate_save_text(text: String, path: String) -> Dictionary:
		validations += 1
		return super._validate_save_text(text, path)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)


func run() -> Dictionary:
	_test_encoding()
	_test_corrupt_main()
	for main_kind in ["valid", "corrupt", "absent"]:
		_test_failed_promotion(main_kind)
	_test_legacy_digest()
	_test_summary_cache()
	_test_summary_cache_bounds()
	SaveManager.delete_test_slot(SLOT)
	print("NOTEBOOK_SAVE_SAFETY_CHECKS: ", checks)
	return {"ok":errors.is_empty(), "errors":errors}


func _write_test_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "open isolated summary fixture")
	if file == null: return
	file.store_string(text)
	file.close()


func _test_summary_cache() -> void:
	SaveManager.delete_test_slot(SLOT)
	var manager := SummaryProbe.new()
	var state := GameState.make_default_snapshot()
	_expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "SUMMARY_01").ok, "summary fixture primary")
	_expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 2, "SUMMARY_02").ok, "summary fixture backup")
	var paths: Dictionary = manager._slot_paths(SLOT)
	var original := FileAccess.get_file_as_string(paths.main)
	var backup := FileAccess.get_file_as_bytes(paths.backup)
	manager.validations = 0
	var first: Dictionary = manager.inspect_slot(SLOT)
	_expect(first.available and first.source == "main" and manager.validations == 1, "first summary fully validates")
	var expected: Dictionary = first.duplicate(true)
	first.run_id = "caller mutation"
	first.save_point_id = "caller mutation"
	_expect(manager.inspect_slot(SLOT) == expected and manager.validations == 1, "unchanged bytes reuse only isolated summary metadata")
	_expect(manager._read_and_validate(paths.main).ok and manager.validations == 2, "full state reads never trust display cache")
	manager.validations = 0
	_expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 3, "SUMMARY_03").ok, "save after warm summary")
	_expect(manager.validations >= 3, "durable write still independently validates primary, backup and temporary")
	_expect(manager.inspect_slot(SLOT).available, "new committed bytes replace cached summary")
	original = FileAccess.get_file_as_string(paths.main)
	backup = FileAccess.get_file_as_bytes(paths.backup)
	var tampered := original.replace("SUMMARY_03", "SUMMARY_04")
	_expect(tampered != original and tampered.to_utf8_buffer().size() == original.to_utf8_buffer().size(), "same-length tamper fixture")
	_write_test_text(paths.main, tampered)
	var before := manager.validations
	var fallback: Dictionary = manager.inspect_slot(SLOT)
	_expect(fallback.available and fallback.source == "backup" and manager.validations == before + 2, "changed bytes with old checksum invalidate cache and verify backup")
	before = manager.validations
	_expect(manager.inspect_slot(SLOT).source == "backup" and manager.validations == before + 1, "invalid primary is retried; only unchanged valid backup is cached")
	_expect(FileAccess.get_file_as_string(paths.main) == tampered and FileAccess.get_file_as_bytes(paths.backup) == backup, "inspection never repairs or rewrites either file")
	_write_test_text(paths.main, original)
	var valid: Dictionary = manager._read_and_validate(paths.main)
	var changed_header: Dictionary = valid.header.duplicate(true)
	changed_header.run_id = "replacement-run"
	changed_header.save_point_id = "SAVE_BROKEN_RESET_COMPLETE"
	_write_test_text(paths.main, manager._encode_payload(changed_header, valid.snapshot).text)
	var replacement: Dictionary = manager.inspect_slot(SLOT)
	_expect(replacement.run_id == "replacement-run" and replacement.save_point_id == "SAVE_BROKEN_RESET_COMPLETE", "valid external replacement does not retain previous run or save point")
	changed_header.schema_version = 999
	var future: String = manager._encode_payload(changed_header, valid.snapshot).text
	_write_test_text(paths.main, future)
	var rejected: Dictionary = manager.inspect_slot(SLOT)
	_expect(not rejected.available and rejected.incompatible and rejected.error_id == &"ERR_SAVE_FUTURE_SCHEMA", "future primary cannot fall through warm valid backup")
	_expect(not manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "BLOCK_FUTURE").ok, "summary cache cannot authorize overwrite of future data")
	_expect(FileAccess.get_file_as_string(paths.main) == future and FileAccess.get_file_as_bytes(paths.backup) == backup, "future main and backup remain unchanged")
	_write_test_text(paths.main, "corrupt")
	_write_test_text(paths.backup, future)
	rejected = manager.inspect_slot(SLOT)
	_expect(not rejected.available and rejected.incompatible, "future backup supersedes formerly cached valid backup")
	_write_test_text(paths.main, original)
	_expect(manager.inspect_slot(SLOT).available, "valid primary can be inspected without trusting future backup")
	_expect(not manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "BLOCK_FUTURE_BACKUP").ok, "save still validates future backup even when primary summary is warm")
	_expect(FileAccess.get_file_as_string(paths.main) == original and FileAccess.get_file_as_string(paths.backup) == future, "future backup failure preserves both files")
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(paths.main)) == OK, "remove isolated primary")
	_expect(not manager._inspect_file(paths.main).ok, "missing file cannot use cached summary")
	before = manager.validations
	_write_test_text(paths.main, original)
	_expect(manager._inspect_file(paths.main).ok and manager.validations == before + 1, "recreated file validates after missing-file eviction")
	manager.free()
	SaveManager.delete_test_slot(SLOT)


func _test_summary_cache_bounds() -> void:
	SaveManager.delete_test_slot(SLOT)
	var manager := SummaryProbe.new()
	var state := GameState.make_default_snapshot()
	_expect(manager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "BOUNDS").ok, "bounded cache fixture")
	var paths: Dictionary = manager._slot_paths(SLOT)
	var original := FileAccess.get_file_as_string(paths.main)
	var test_paths: Array[String] = []
	for index in range(manager.SUMMARY_CACHE_LIMIT + 2):
		var path: String = paths.main.get_base_dir().path_join("summary_probe_%d.json" % index)
		test_paths.append(path)
		_write_test_text(path, original)
		_expect(manager._inspect_file(path).ok, "separate path receives verified summary")
		_expect(manager._summary_cache.size() <= manager.SUMMARY_CACHE_LIMIT, "cache bounded across slots and namespaces")
	var before := manager.validations
	_expect(manager._inspect_file(test_paths[0]).ok and manager.validations == before + 1, "least recently used summary is revalidated after eviction")
	for cached in manager._summary_cache.values():
		_expect(cached.keys().size() == 2 and cached.has("fingerprint") and cached.has("summary"), "cache stores no full snapshot or source buffer")
		_expect(JSON.stringify(cached.summary).to_utf8_buffer().size() <= manager.SUMMARY_CACHE_ENTRY_BYTES, "metadata entry has an explicit byte limit")
	var valid: Dictionary = manager._read_and_validate(paths.main)
	var huge: Dictionary = valid.header.duplicate(true)
	huge.run_id = "x".repeat(manager.SUMMARY_CACHE_ENTRY_BYTES + 1)
	_write_test_text(paths.main, manager._encode_payload(huge, valid.snapshot).text)
	before = manager.validations
	_expect(manager.inspect_slot(SLOT).available and manager.inspect_slot(SLOT).available, "oversized metadata remains readable")
	_expect(manager.validations == before + 2, "oversized summary is not retained")
	for path in test_paths:
		_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "remove owned summary fixture")
	manager.free()
	SaveManager.delete_test_slot(SLOT)


func _test_corrupt_main() -> void:
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.make_default_snapshot()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "SAFETY_SEED").ok, "seed valid primary")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 2, "SAFETY_BACKUP").ok, "seed valid backup")
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var backup := FileAccess.get_file_as_bytes(paths.backup)
	var file := FileAccess.open(paths.main, FileAccess.WRITE)
	file.store_string("corrupt primary")
	file.close()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 3, "SAFETY_REPAIR").ok, "new verified save replaces corrupt main")
	_expect(FileAccess.get_file_as_bytes(paths.backup) == backup, "corrupt main never replaces the last valid backup")
	_expect(SaveManager._read_and_validate(paths.backup).ok, "backup remains independently loadable")


func _test_encoding() -> void:
	var header := {"z_last":"끝", "checksum":"", "schema_version":2, "a_first":&"start"}
	var samples := [GameState.make_default_snapshot(),
		{"z": [{"b":&"name", "a":"한글\n\"checksum\": \"\""}, null, true, false, 7, 7.25], "a":{"2":"two", "1":"one"}},
		{"nested":{"text":"앞면 / back \\ tab\t", "array":[[], {}, ["x"]]}}]
	for state in samples:
		var before := JSON.stringify(state, "", true)
		var header_before := JSON.stringify(header, "", true)
		# Independent copy of the previous on-disk encoder, including key order.
		var old := {"save_header":header.duplicate(true), "state":SaveManager._canonicalize(state)}
		var unsigned := JSON.stringify(SaveManager._canonicalize(old), "\t", false)
		old.save_header.checksum = SaveManager._checksum_text(unsigned)
		var expected := JSON.stringify(SaveManager._canonicalize(old), "\t", false)
		var encoded: Dictionary = SaveManager._encode_payload(header, state)
		_expect(encoded.text.to_utf8_buffer() == expected.to_utf8_buffer(), "signed payload bytes match previous encoder")
		_expect(encoded.checksum == old.save_header.checksum, "checksum matches previous encoder")
		_expect(JSON.stringify(state, "", true) == before and JSON.stringify(header, "", true) == header_before, "encoder leaves source and header unchanged")


func _test_failed_promotion(main_kind: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.make_default_snapshot()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "FAIL_SEED").ok, "failure case seed primary")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 2, "FAIL_BACKUP").ok, "failure case seed backup")
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var recoverable := FileAccess.get_file_as_bytes(paths.main if main_kind == "valid" else paths.backup)
	if main_kind == "absent":
		_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(paths.main)) == OK, "remove test primary")
	elif main_kind == "corrupt":
		var file := FileAccess.open(paths.main, FileAccess.WRITE)
		file.store_string("corrupt primary")
		file.close()
	var fault := PromotionFailure.new()
	var signals := {"success":0, "failure":0}
	fault.save_completed.connect(func(_slot, _point): signals.success += 1)
	fault.save_failed.connect(func(_slot, _errors): signals.failure += 1)
	var saved: Dictionary = fault.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 3, "FAIL_PROMOTE")
	_expect(not saved.ok and saved.error_id == &"ERR_SAVE_PROMOTE", main_kind + ": promotion failure reported")
	_expect(fault.verified_temp, main_kind + ": fault occurs only after valid temporary write")
	_expect(signals.success == 0 and signals.failure == 1, main_kind + ": no premature success signal")
	_expect(FileAccess.get_file_as_bytes(paths.backup) == recoverable, main_kind + ": verified recovery bytes retained")
	_expect(FileAccess.get_file_as_bytes(paths.main) == recoverable, main_kind + ": failed promotion restores recovery bytes")
	_expect(SaveManager._read_and_validate(paths.main).ok and SaveManager._read_and_validate(paths.backup).ok, main_kind + ": both restored files validate")
	fault.free()
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 4, "FAIL_RETRY").ok, main_kind + ": next save can succeed")


func _test_legacy_digest() -> void:
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.make_default_snapshot()
	state.meta_progress.dialogue_history = {"next_sequence":1, "entries":[
		{"sequence":0, "line_id":"CH1_HISTORY_TRANSCRIPT", "speaker_id":"SYSTEM", "variables":{"speaker":"이전 화자", "text":"지워지지 않을 기록"}}]}
	var digest := JSON.stringify(SaveManager._canonicalize(state)).sha256_text()
	var expected: Dictionary = preload("res://scripts/systems/notebook_migration.gd").adapt_verified(state, digest, true)
	_expect(expected.ok, "legacy input remains migratable")
	var before := JSON.stringify(state, "", true)
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, 1, "LEGACY_DIGEST").ok, "legacy save promotes with original digest")
	var loaded: Dictionary = SaveManager._read_and_validate(SaveManager._slot_paths(SLOT).main)
	_expect(loaded.ok and StateSnapshotValidator.same_persisted_value(loaded.snapshot, expected.snapshot), "legacy digest and deterministic identities preserved")
	_expect(JSON.stringify(state, "", true) == before, "legacy input remains unchanged")
