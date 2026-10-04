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


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)


func run() -> Dictionary:
	_test_encoding()
	_test_corrupt_main()
	for main_kind in ["valid", "corrupt", "absent"]:
		_test_failed_promotion(main_kind)
	_test_legacy_digest()
	SaveManager.delete_test_slot(SLOT)
	print("NOTEBOOK_SAVE_SAFETY_CHECKS: ", checks)
	return {"ok":errors.is_empty(), "errors":errors}


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
