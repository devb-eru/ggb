extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const MIGRATION := preload("res://scripts/systems/notebook_migration.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const SLOT := "__test_notebook_migration"
var errors := PackedStringArray()

class F3PromotionFailure extends "res://scripts/autoload/save_manager.gd":
	var attempted := false
	func _promote_temporary(_paths: Dictionary) -> Error:
		attempted = true
		return ERR_CANT_CREATE


class ImportPromotionFailure extends "res://scripts/autoload/save_manager.gd":
	var target := ""
	var fail := true
	var foreign_file := false
	func _promote_temporary(paths: Dictionary) -> Error:
		target = paths.main.get_base_dir()
		if not fail: return super._promote_temporary(paths)
		if foreign_file:
			var file := FileAccess.open(target.path_join("keep.txt"), FileAccess.WRITE)
			file.store_string("foreign data")
			file.close()
		return ERR_CANT_CREATE


class ImportLostAcknowledgement extends "res://scripts/autoload/save_manager.gd":
	func save_snapshot(slot: String, point: String, snapshot: Dictionary, revision: int, transaction: String) -> Dictionary:
		var result := super.save_snapshot(slot, point, snapshot, revision, transaction)
		return _load_failure(&"TEST_IMPORT_ACK") if result.get("ok", false) else result


class SaveFault:
	extends Node
	var real: Node
	var lose_ack := false
	var inspections := 0
	func get_build_flavor() -> String: return real.get_build_flavor()
	func inspect_slot(slot: String) -> Dictionary:
		inspections += 1
		return real.inspect_slot(slot)
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if lose_ack: real.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_SAVE_RESPONSE"]}
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return real.confirm_snapshot_commit(slot, transaction)


func run() -> Dictionary:
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	GameState.reset_for_test()
	_validate_primary()
	_validate_failure_and_future()
	_validate_progress_future_temporary()
	_validate_unknown_design()
	_validate_backup()
	_validate_commands()
	_validate_retention_commit()
	_validate_f3()
	_validate_f3_uncommitted()
	_validate_f3_future_candidates()
	_validate_f3_backup_preservation()
	_validate_f3_failed_promotion()
	_validate_demo()
	_validate_demo_rejections()
	_validate_demo_target_failure()
	_validate_gallery_and_development()
	var safety: Dictionary = preload("res://scripts/tests/notebook_save_safety_smoke.gd").new().run()
	errors.append_array(safety.errors)
	SaveManager.delete_test_slot(SLOT)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors}


func _legacy(source: Dictionary = {}) -> Dictionary:
	var state: Dictionary = GameState.get_snapshot() if source.is_empty() else source.duplicate(true)
	state.meta_progress.dialogue_history = {"next_sequence": 8, "entries": [
		{"sequence": 4, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "Narrator", "text": "Preserved original"}, "viewed_locale": "en-US"},
		{"sequence": 7, "line_id": "OLD_UNKNOWN", "speaker_id": "SYSTEM", "chapter_id": "UNKNOWN_OLD", "extra": ["preserve"]},
	]}
	return state


func _write_source(path: String, state: Dictionary, schema: Variant = 1, point: String = "SAVE_NEW_GAME", run_id: String = "legacy-test-run", design: String = "") -> Dictionary:
	var header := {"schema_version": schema, "design_revision": SaveManager.DESIGN_REVISION, "checksum_algorithm": "sha256", "checksum": "", "build_flavor": SaveManager.get_build_flavor(), "content_boundary_id": point, "source_app_id": "local", "save_point_id": point, "slot_id": SLOT, "run_id": run_id, "state_revision": 8}
	if not design.is_empty(): header.design_revision = design
	var document: Dictionary = SaveManager._canonicalize({"save_header": header, "state": state})
	document.save_header.checksum = JSON.stringify(document, "\t", false).sha256_text()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t", false))
	file.close()
	return document


func _path(name: String = "progress.json") -> String:
	return SaveManager.get_save_root().path_join(SLOT).path_join(name)


func _validate_primary() -> void:
	SaveManager.delete_test_slot(SLOT)
	var source := _legacy()
	var document := _write_source(_path(), source)
	var original := FileAccess.get_file_as_bytes(_path())
	var preview: Dictionary = SaveManager._read_and_validate(_path())
	_expect(preview.get("ok", false) and FileAccess.get_file_as_bytes(_path()) == original, "verified preview is read only")
	if not preview.get("ok", false): return
	var expected: Dictionary = preview.snapshot.meta_progress.dialogue_history
	var loaded: Dictionary = SaveManager.load_slot(SLOT)
	_expect(loaded.get("ok", false), "legacy primary migrates through actual SaveManager")
	if not loaded.get("ok", false): return
	_expect(loaded.header.schema_version == 2 and loaded.snapshot.meta_progress.dialogue_history == expected, "migration commits exact deterministic archive")
	var backup := _path("pre_notebook_" + document.save_header.checksum + ".json")
	_expect(FileAccess.get_file_as_bytes(backup) == original, "pre-migration source is byte-identical and durable")
	_expect(loaded.snapshot.meta_progress.dialogue_history.entries[1].legacy_payload == source.meta_progress.dialogue_history.entries[1], "unknown fields and original chapter survive")
	var again: Dictionary = SaveManager.load_slot(SLOT)
	_expect(again.snapshot == loaded.snapshot, "second load neither re-migrates nor reissues UIDs")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "migrated state installs through load coordinator")
	_expect(GameState.get_snapshot() == loaded.snapshot, "installed state equals migrated state including numeric field types")
	var malformed: Dictionary = loaded.snapshot.duplicate(true)
	malformed.meta_progress.dialogue_history.comparison = 7
	_expect(not StateSnapshotValidator.new().validate(StateSnapshotValidator.new().normalize(malformed)).ok, "malformed collection rejected without script exception")
	malformed = loaded.snapshot.duplicate(true)
	malformed.meta_progress.dialogue_history.entries[0].sequence = 4.5
	_expect(not StateSnapshotValidator.new().validate(StateSnapshotValidator.new().normalize(malformed)).ok, "fractional sequence is never rounded into validity")


func _validate_failure_and_future() -> void:
	SaveManager.delete_test_slot(SLOT)
	var source := _legacy()
	var document := _write_source(_path(), source)
	var original := FileAccess.get_file_as_bytes(_path())
	var expected: Dictionary = SaveManager._read_and_validate(_path()).snapshot.meta_progress.dialogue_history
	var backup := _path("pre_notebook_" + document.save_header.checksum + ".json")
	var file := FileAccess.open(backup, FileAccess.WRITE)
	file.store_string("collision")
	file.close()
	_expect(not SaveManager.load_slot(SLOT).get("ok", false), "backup collision blocks migration")
	_expect(FileAccess.get_file_as_bytes(_path()) == original, "failed backup leaves original untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	var temporary := _path("progress.tmp.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary))
	_expect(not SaveManager.load_slot(SLOT).get("ok", false), "blocked temporary write fails safely")
	_expect(FileAccess.get_file_as_bytes(_path()) == original and FileAccess.get_file_as_bytes(backup) == original, "failed commit preserves both source and backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	var recovered: Dictionary = SaveManager.load_slot(SLOT)
	_expect(recovered.get("ok", false) and recovered.snapshot.meta_progress.dialogue_history == expected, "retry after write failure has identical UIDs")
	SaveManager.delete_test_slot(SLOT)
	_write_source(_path(), source)
	var corrupt := FileAccess.get_file_as_string(_path()).replace("Preserved original", "Tampered original")
	file = FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	_expect(SaveManager.load_slot(SLOT).get("error_id") == &"ERR_SAVE_CHECKSUM", "original checksum checked before adaptation")
	_expect(FileAccess.get_file_as_string(_path()) == corrupt, "checksum failure never rewrites source")
	for schema in [999, 1.5, "2"]:
		SaveManager.delete_test_slot(SLOT)
		_write_source(_path(), source, schema)
		original = FileAccess.get_file_as_bytes(_path())
		_expect(not SaveManager.load_slot(SLOT).get("ok", false), "unsupported envelope rejected: " + str(schema))
		if schema is int and schema == 999:
			_expect(not SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_FUTURE").ok, "future main cannot be overwritten")
		_expect(FileAccess.get_file_as_bytes(_path()) == original, "unsupported envelope preserved")
	SaveManager.delete_test_slot(SLOT)
	var future := GameState.get_snapshot()
	future.meta_progress.dialogue_history.schema_version = 999
	_write_source(_path(), future, 2)
	_write_source(_path("progress.bak.json"), source)
	original = FileAccess.get_file_as_bytes(_path())
	_expect(SaveManager.load_slot(SLOT).get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA", "future notebook never falls back to older backup")
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_FUTURE").ok, "future notebook cannot be overwritten")
	_expect(FileAccess.get_file_as_bytes(_path()) == original, "future notebook bytes preserved")
	SaveManager.delete_test_slot(SLOT)
	_write_source(_path(), source)
	_write_source(_path("progress.bak.json"), source, 999)
	original = FileAccess.get_file_as_bytes(_path("progress.bak.json"))
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_FUTURE_BACKUP").ok, "future backup cannot be overwritten even with valid main")
	_expect(FileAccess.get_file_as_bytes(_path("progress.bak.json")) == original, "future backup bytes preserved")
	SaveManager.delete_test_slot(SLOT)
	future = GameState.get_snapshot()
	future.meta_progress.knowledge_entries.notebook_knowledge = {"schema_version": 999}
	_write_source(_path(), future, 2)
	_write_source(_path("progress.bak.json"), source)
	original = FileAccess.get_file_as_bytes(_path())
	_expect(SaveManager.load_slot(SLOT).get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA", "future knowledge ledger cannot fall back to old backup")
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_FUTURE_LEDGER").ok, "future knowledge ledger cannot be overwritten")
	_expect(FileAccess.get_file_as_bytes(_path()) == original, "future ledger source bytes preserved")
	SaveManager.delete_test_slot(SLOT)
	_write_source(_path(), source)
	_write_source(_path("progress.bak.json"), future, 2)
	original = FileAccess.get_file_as_bytes(_path("progress.bak.json"))
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), GameState.revision, "TEST_FUTURE_LEDGER_BACKUP").ok, "future knowledge ledger backup cannot be replaced")
	_expect(FileAccess.get_file_as_bytes(_path("progress.bak.json")) == original, "future ledger backup bytes preserved")
	SaveManager.delete_test_slot(SLOT)


func _validate_progress_future_temporary() -> void:
	for entry in ["save", "migration", "recovery"]:
		for kind in ["envelope", "archive", "knowledge"]:
			SaveManager.delete_test_slot(SLOT)
			var state := _legacy()
			_write_source(_path(), state)
			_write_source(_path("progress.bak.json"), state)
			if entry == "recovery":
				var broken := FileAccess.open(_path(), FileAccess.WRITE)
				broken.store_string("corrupt")
				broken.close()
			var future := GameState.get_snapshot()
			if kind == "archive": future.meta_progress.dialogue_history.schema_version = 999
			if kind == "knowledge": future.meta_progress.knowledge_entries.notebook_knowledge = {"schema_version":999}
			_write_source(_path("progress.tmp.json"), future, 999 if kind == "envelope" else 2)
			var before := {}
			for name in ["progress.json", "progress.bak.json", "progress.tmp.json"]:
				before[name] = FileAccess.get_file_as_bytes(_path(name))
			var result: Dictionary
			if entry == "save":
				result = SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), 8, "TEST_FUTURE_TEMP")
			else:
				result = SaveManager.load_slot(SLOT)
			_expect(not result.ok and result.get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA", "future progress temporary blocks write: " + entry + "/" + kind)
			for name in before:
				_expect(FileAccess.get_file_as_bytes(_path(name)) == before[name], "future temporary preserves source bytes: " + entry + "/" + kind + "/" + name)
			var pending_bytes: PackedByteArray = before["progress.tmp.json"]
			var committed := GameState.get_snapshot()
			_write_source(_path(), committed, 2)
			var readable: Dictionary = SaveManager.load_slot(SLOT)
			_expect(readable.get("ok", false) and readable.snapshot == committed, "future temporary is not adopted during committed read: " + entry + "/" + kind)
			_expect(FileAccess.get_file_as_bytes(_path("progress.tmp.json")) == pending_bytes, "read leaves future temporary untouched: " + entry + "/" + kind)
	SaveManager.delete_test_slot(SLOT)


func _validate_unknown_design() -> void:
	for action in ["save", "load", "inspect"]:
		for name in ["progress.json", "progress.bak.json", "progress.tmp.json"]:
			SaveManager.delete_test_slot(SLOT)
			var state := _legacy()
			for candidate in ["progress.json", "progress.bak.json", "progress.tmp.json"]:
				_write_source(_path(candidate), state)
			_write_source(_path(name), state, 1, "SAVE_NEW_GAME", "legacy-test-run", "unknown-design")
			if name == "progress.bak.json" and action != "save":
				var file := FileAccess.open(_path(), FileAccess.WRITE)
				file.store_string("corrupt")
				file.close()
			var before := {}
			for candidate in ["progress.json", "progress.bak.json", "progress.tmp.json"]:
				before[candidate] = FileAccess.get_file_as_bytes(_path(candidate))
			var result: Dictionary
			match action:
				"save": result = SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", GameState.get_snapshot(), 8, "TEST_UNKNOWN_DESIGN")
				"load": result = SaveManager.load_slot(SLOT)
				"inspect": result = SaveManager.inspect_slot(SLOT)
			if action == "inspect" and name == "progress.tmp.json":
				_expect(result.get("available", false), "inspection reads committed main, not unknown tmp")
			else:
				_expect(result.get("error_id") == &"ERR_SAVE_DESIGN_REVISION", "unknown design rejected: " + action + "/" + name)
				if action == "inspect": _expect(result.get("incompatible", false), "unknown design has incompatible summary: " + name)
			for candidate in before:
				_expect(FileAccess.get_file_as_bytes(_path(candidate)) == before[candidate], "unknown design preserves bytes: " + action + "/" + name + "/" + candidate)
	for action in ["capture", "load", "cleanup"]:
		for suffix in ["", ".bak", ".tmp"]:
			SaveManager.delete_test_slot(SLOT)
			var source: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
			_write_source(_path(), source, 2, "SAVE_F3_COMPLETE")
			for candidate in ["", ".bak", ".tmp"]:
				_write_source(_path("f3_reselect.json" + candidate), source, 2, "SAVE_F3_COMPLETE")
			_write_source(_path("f3_reselect.json" + suffix), source, 2, "SAVE_F3_COMPLETE", "legacy-test-run", "unknown-design")
			if action == "load" and suffix == ".bak":
				var file := FileAccess.open(_path("f3_reselect.json"), FileAccess.WRITE)
				file.store_string("corrupt")
				file.close()
			var before := {}
			for name in ["progress.json", "f3_reselect.json", "f3_reselect.json.bak", "f3_reselect.json.tmp"]:
				before[name] = FileAccess.get_file_as_bytes(_path(name))
			if action == "cleanup":
				_expect(not SaveManager._clear_previous_f3(SLOT).is_empty(), "unknown F3 design reports preserved cleanup: " + suffix)
			else:
				var result: Dictionary = SaveManager.capture_f3_reselect(SLOT) if action == "capture" else SaveManager.load_f3_reselect(SLOT)
				if action == "load" and suffix == ".tmp":
					_expect(result.get("ok", false), "F3 committed read ignores unknown-design tmp")
				else:
					_expect(result.get("error_id") == &"ERR_SAVE_DESIGN_REVISION", "unknown F3 design rejected: " + action + suffix)
			for name in before:
				_expect(FileAccess.get_file_as_bytes(_path(name)) == before[name], "unknown F3 design preserves bytes: " + action + suffix + "/" + name)
	SaveManager.delete_test_slot(SLOT)


func _validate_backup() -> void:
	var source := _legacy()
	var document := _write_source(_path("progress.bak.json"), source)
	var original := FileAccess.get_file_as_bytes(_path("progress.bak.json"))
	var expected: Dictionary = SaveManager._read_and_validate(_path("progress.bak.json")).snapshot.meta_progress.dialogue_history
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	var temporary := _path("progress.tmp.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary))
	_expect(not SaveManager.load_slot(SLOT).get("ok", false), "backup promotion write failure is surfaced")
	_expect(FileAccess.get_file_as_bytes(_path("progress.bak.json")) == original, "failed recovery preserves valid original backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	var loaded: Dictionary = SaveManager.load_slot(SLOT)
	_expect(loaded.get("ok", false) and loaded.get("source") == "backup", "legacy backup recovery commits schema two")
	if loaded.get("ok", false):
		var history: Dictionary = loaded.snapshot.meta_progress.dialogue_history
		_expect(history.entries == expected.entries and history.branch_id != expected.branch_id, "backup recovery preserves observations but forks branch")
		_expect(FileAccess.get_file_as_bytes(_path("pre_notebook_" + document.save_header.checksum + ".json")) == original, "backup original preserved before promotion")
	SaveManager.delete_test_slot(SLOT)


func _validate_commands() -> void:
	_write_source(_path(), _legacy())
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "command fixture loads")
	var initial := GameState.get_snapshot()
	var reference := ARCHIVE.make_reference(initial.meta_progress.dialogue_history.entries[0], "legacy")
	var scope := COMMANDS.scope(GameState, SaveManager, SLOT)
	var result := COMMANDS.set_reference(GameState, SaveManager, SLOT, "bookmarks", reference, true, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(result.ok and result.changed, "bookmark command commits through real writer and save")
	var pinned := GameState.get_snapshot()
	var except_archive := pinned.duplicate(true)
	except_archive.meta_progress.dialogue_history = initial.meta_progress.dialogue_history
	_expect(except_archive == initial, "bookmark cannot change gameplay, relations, read completion, or ending state")
	_expect(SaveManager.load_slot(SLOT).snapshot == pinned, "committed reference and protection reload together")
	var repeat := COMMANDS.set_reference(GameState, SaveManager, SLOT, "bookmarks", reference, true, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(repeat.ok and not repeat.changed and GameState.get_snapshot() == pinned, "duplicate desired-state command is idempotent")
	var fault := SaveFault.new()
	fault.real = SaveManager
	result = COMMANDS.set_reference(GameState, fault, SLOT, "comparison", reference, true, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(fault.inspections == 1, "command uses one verified slot summary for both scope and save point")
	_expect(not result.ok and GameState.get_snapshot() == pinned and SaveManager.load_slot(SLOT).snapshot == pinned, "failed save rolls back only its candidate and keeps disk unchanged")
	fault.lose_ack = true
	result = COMMANDS.set_reference(GameState, fault, SLOT, "comparison", reference, true, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(result.ok and result.get("recovered_acknowledgement", false), "lost success response resolved against verified disk commit")
	_expect(SaveManager.load_slot(SLOT).snapshot == GameState.get_snapshot(), "lost acknowledgement never rolls back a committed pin")
	var presentation := {"presentation_token": ARCHIVE.new_uid()}
	var observed := WRITER.record(GameState, fault, SLOT, "SAVE_NEW_GAME", "Narrator", "Visible retry", "en-US", "PROLOGUE", [], presentation)
	_expect(observed.ok and observed.get("recovered_acknowledgement", false), "observed line also confirms lost success response")
	var observed_state := GameState.get_snapshot()
	var repeated := WRITER.record(GameState, SaveManager, SLOT, "SAVE_NEW_GAME", "Narrator", "Visible retry", "en-US", "PROLOGUE", [], presentation)
	_expect(repeated.ok and repeated.entry_uid == observed.entry_uid and GameState.get_snapshot() == observed_state, "same presentation retry returns existing UID without another append")
	_expect(SaveManager.load_slot(SLOT).snapshot == observed_state, "observed context reloads unchanged")
	fault.free()
	var old_revision := GameState.revision
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "same slot reload succeeds")
	var before := GameState.get_snapshot()
	_expect(not COMMANDS.set_reference(GameState, SaveManager, SLOT, "comparison", reference, false, scope, GameState.revision, ARCHIVE.new_uid()).ok, "old load epoch cannot modify newly loaded slot")
	scope = COMMANDS.scope(GameState, SaveManager, SLOT)
	_expect(not COMMANDS.set_reference(GameState, SaveManager, SLOT, "comparison", reference, false, scope, old_revision, ARCHIVE.new_uid()).ok, "stale game revision is not silently replaced")
	_expect(GameState.get_snapshot() == before, "rejected callbacks leave current state untouched")
	SaveManager.delete_test_slot(SLOT)


func _validate_retention_commit() -> void:
	var archive := preload("res://scripts/tests/notebook_retention_fixture.gd").create()
	var reference := ARCHIVE.make_reference(archive.entries[0], "body")
	var pinned := ARCHIVE.set_reference(archive, "bookmarks", reference, true, archive.revision)
	_expect(pinned.ok and pinned.pruned_uids.is_empty(), "pin prevents pruning before persistence test")
	if not pinned.ok: return
	var state := GameState.get_snapshot()
	state.meta_progress.dialogue_history = pinned.archive
	_write_source(_path(), state, 2)
	var loaded: Dictionary = LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
	_expect(loaded.ok, "retention save fixture installs")
	if not loaded.ok: return
	var before := GameState.get_snapshot()
	var disk := FileAccess.get_file_as_bytes(_path())
	var scope := COMMANDS.scope(GameState, SaveManager, SLOT)
	var fault := SaveFault.new()
	fault.real = SaveManager
	var failed := COMMANDS.set_reference(GameState, fault, SLOT, "bookmarks", reference, false, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(not failed.ok and GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(_path()) == disk, "failed pruning commit leaves both old entries and marker absence unchanged")
	fault.lose_ack = true
	var saved := COMMANDS.set_reference(GameState, fault, SLOT, "bookmarks", reference, false, scope, GameState.revision, ARCHIVE.new_uid())
	_expect(saved.ok and saved.get("recovered_acknowledgement", false), "durable pruning commit is recognized after lost acknowledgement")
	var after := GameState.get_snapshot()
	var retained: Dictionary = after.meta_progress.dialogue_history
	_expect(retained.entries.size() == 2003 and retained.entries[0].get(ARCHIVE.SESSION_PRUNED, false), "prune and session notice install together")
	_expect(SaveManager.load_slot(SLOT).snapshot == after, "session evidence survives real save normalization and reload")
	fault.free()
	SaveManager.delete_test_slot(SLOT)


func _validate_f3() -> void:
	var source := _legacy(CHECKPOINTS.new().snapshot_for("EDC").snapshot)
	_write_source(_path(), source, 1, "SAVE_F3_COMPLETE")
	_write_source(_path("f3_reselect.json"), source, 1, "SAVE_F3_COMPLETE")
	var original := FileAccess.get_file_as_bytes(_path("f3_reselect.json"))
	var main_bytes := FileAccess.get_file_as_bytes(_path())
	var preview: Dictionary = SaveManager.load_f3_reselect(SLOT)
	var copied: Dictionary = SaveManager.create_f3_reselect_slot(SLOT)
	_expect(preview.get("ok", false) and copied.get("ok", false), "legacy F3 copy adapts into a new slot")
	if copied.get("ok", false):
		var archive: Dictionary = SaveManager.load_slot(copied.slot_id).snapshot.meta_progress.dialogue_history
		_expect(archive.entries == preview.snapshot.meta_progress.dialogue_history.entries and archive.branch_id != preview.snapshot.meta_progress.dialogue_history.branch_id, "F3 copy retains UIDs and changes branch")
		SaveManager.delete_test_slot(copied.slot_id)
	_expect(FileAccess.get_file_as_bytes(_path("f3_reselect.json")) == original and FileAccess.get_file_as_bytes(_path()) == main_bytes, "F3 adaptation does not rewrite source run or sidecar")
	SaveManager.delete_test_slot(SLOT)


func _validate_f3_uncommitted() -> void:
	SaveManager.delete_test_slot(SLOT)
	var source := _legacy(CHECKPOINTS.new().snapshot_for("EDC").snapshot)
	_write_source(_path(), source, 1, "SAVE_F3_COMPLETE")
	var tentative := source.duplicate(true)
	tentative.meta_progress.dialogue_history.entries[0].variables.text = "Uncommitted F3 candidate"
	var temporary := _path("f3_reselect.json.tmp")
	_write_source(temporary, tentative, 1, "SAVE_F3_COMPLETE")
	var bytes := FileAccess.get_file_as_bytes(temporary)
	_expect(not SaveManager.load_f3_reselect(SLOT).ok, "uncommitted F3 temporary is not a recovery source")
	var copied: Dictionary = SaveManager.create_f3_reselect_slot(SLOT)
	_expect(not copied.ok, "uncommitted F3 temporary cannot create a playable branch")
	if copied.ok: SaveManager.delete_test_slot(copied.slot_id)
	_write_source(_path("f3_reselect.json.bak"), source, 1, "SAVE_F3_COMPLETE")
	var expected: Dictionary = SaveManager._read_and_validate(_path("f3_reselect.json.bak"))
	var loaded: Dictionary = SaveManager.load_f3_reselect(SLOT)
	_expect(loaded.ok and loaded.snapshot == expected.snapshot, "committed F3 backup wins over uncommitted temporary")
	_expect(FileAccess.get_file_as_bytes(temporary) == bytes, "reading never removes or rewrites tentative F3 bytes")
	SaveManager.delete_test_slot(SLOT)


func _validate_f3_future_candidates() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		for kind in ["envelope", "archive", "knowledge"]:
			SaveManager.delete_test_slot(SLOT)
			var source: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
			_write_source(_path(), source, 2, "SAVE_F3_COMPLETE")
			for candidate in ["", ".tmp", ".bak"]:
				_write_source(_path("f3_reselect.json" + candidate), source, 2, "SAVE_F3_COMPLETE")
			var future := source.duplicate(true)
			if kind == "archive": future.meta_progress.dialogue_history.schema_version = 999
			if kind == "knowledge": future.meta_progress.knowledge_entries.notebook_knowledge = {"schema_version":999}
			_write_source(_path("f3_reselect.json" + suffix), future, 999 if kind == "envelope" else 2, "SAVE_F3_COMPLETE")
			var before := {}
			for name in ["progress.json", "f3_reselect.json", "f3_reselect.json.tmp", "f3_reselect.json.bak"]:
				before[name] = FileAccess.get_file_as_bytes(_path(name))
			var result: Dictionary = SaveManager.capture_f3_reselect(SLOT)
			_expect(not result.ok and result.get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA", "F3 future candidate blocks capture: " + kind + suffix)
			for name in before:
				_expect(FileAccess.get_file_as_bytes(_path(name)) == before[name], "F3 future candidate preserves all files: " + kind + suffix + " / " + name)
	SaveManager.delete_test_slot(SLOT)


func _validate_f3_backup_preservation() -> void:
	for kind in ["corrupt", "non_f3", "foreign_run", "valid"]:
		SaveManager.delete_test_slot(SLOT)
		var source := _legacy(CHECKPOINTS.new().snapshot_for("EDC").snapshot)
		_write_source(_path(), source, 1, "SAVE_F3_COMPLETE")
		var old := source.duplicate(true)
		old.meta_progress.dialogue_history.entries[0].variables.text = "Last committed F3 backup"
		_write_source(_path("f3_reselect.json.bak"), old, 1, "SAVE_F3_COMPLETE")
		var backup := FileAccess.get_file_as_bytes(_path("f3_reselect.json.bak"))
		var target := _path("f3_reselect.json")
		if kind == "corrupt":
			var file := FileAccess.open(target, FileAccess.WRITE)
			file.store_string("corrupt F3 primary")
			file.close()
		else:
			_write_source(target, source, 1, "SAVE_NEW_GAME" if kind == "non_f3" else "SAVE_F3_COMPLETE", "other-run" if kind == "foreign_run" else "legacy-test-run")
		var previous := FileAccess.get_file_as_bytes(target)
		var captured: Dictionary = SaveManager.capture_f3_reselect(SLOT)
		_expect(captured.ok, "F3 capture replaces " + kind + " primary")
		_expect(FileAccess.get_file_as_bytes(_path("f3_reselect.json.bak")) == (previous if kind == "valid" else backup), "only a valid F3 primary replaces recovery bytes: " + kind)
		_expect(SaveManager.load_f3_reselect(SLOT).ok, "new committed F3 remains readable: " + kind)
	SaveManager.delete_test_slot(SLOT)


func _validate_f3_failed_promotion() -> void:
	for kind in ["corrupt", "non_f3", "foreign_run", "valid"]:
		SaveManager.delete_test_slot(SLOT)
		var source := _legacy(CHECKPOINTS.new().snapshot_for("EDC").snapshot)
		_write_source(_path(), source, 1, "SAVE_F3_COMPLETE")
		var old := source.duplicate(true)
		old.meta_progress.dialogue_history.entries[0].variables.text = "Recoverable committed backup"
		_write_source(_path("f3_reselect.json.bak"), old, 1, "SAVE_F3_COMPLETE")
		var target := _path("f3_reselect.json")
		if kind == "corrupt":
			var file := FileAccess.open(target, FileAccess.WRITE)
			file.store_string("corrupt F3 primary")
			file.close()
		else:
			_write_source(target, source, 1, "SAVE_NEW_GAME" if kind == "non_f3" else "SAVE_F3_COMPLETE", "other-run" if kind == "foreign_run" else "legacy-test-run")
		var recovery_path := target if kind == "valid" else target + ".bak"
		var expected: Dictionary = SaveManager._read_and_validate(recovery_path)
		var bytes := FileAccess.get_file_as_bytes(recovery_path)
		var primary := FileAccess.get_file_as_bytes(_path())
		var manager := F3PromotionFailure.new()
		var result := manager.capture_f3_reselect(SLOT)
		_expect(manager.attempted and not result.ok and result.error_id == &"ERR_RESELECT_PROMOTE", "F3 promotion fault reaches real capture: " + kind)
		_expect(FileAccess.get_file_as_bytes(target + ".bak") == bytes and FileAccess.get_file_as_bytes(_path()) == primary, "F3 promotion failure preserves recovery and gameplay bytes: " + kind)
		var loaded: Dictionary = SaveManager.load_f3_reselect(SLOT)
		_expect(loaded.ok and loaded.snapshot == expected.snapshot, "failed F3 promotion loads committed backup, not temporary: " + kind)
		manager.free()
	SaveManager.delete_test_slot(SLOT)


func _validate_demo() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	SaveManager.delete_test_slot(SLOT)
	var source := _legacy(CHECKPOINTS.new().snapshot_for("D6").snapshot)
	_write_source(_path(), source, 1, "SAVE_D5_COMPLETE")
	var source_path := _path()
	var original := FileAccess.get_file_as_bytes(source_path)
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var preview: Dictionary = SaveManager.inspect_demo_import(SLOT)
	var copied: Dictionary = SaveManager.import_demo_to_new_slot(SLOT)
	_expect(preview.get("ok", false) and copied.get("ok", false), "legacy demo imports through explicit full-game boundary")
	if copied.get("ok", false):
		var archive: Dictionary = SaveManager.load_slot(copied.slot_id).snapshot.meta_progress.dialogue_history
		_expect(archive.entries == preview.snapshot.meta_progress.dialogue_history.entries and archive.branch_id != preview.snapshot.meta_progress.dialogue_history.branch_id, "demo import retains UIDs and changes branch")
		var repeated: Dictionary = SaveManager.import_demo_to_new_slot(SLOT)
		_expect(repeated.get("ok", false) and repeated.get("slot_id") != copied.slot_id, "repeated explicit import uses a separate destination")
		if repeated.get("ok", false):
			var again: Dictionary = SaveManager.load_slot(repeated.slot_id).snapshot.meta_progress.dialogue_history
			_expect(again.entries == archive.entries and again.source_origin_id == archive.source_origin_id, "repeated import preserves original observation identities without duplicates")
			_expect(again.branch_id != archive.branch_id, "independent imports receive distinct branches")
			SaveManager.delete_test_slot(repeated.slot_id)
		SaveManager.delete_test_slot(copied.slot_id)
	_expect(FileAccess.get_file_as_bytes(source_path) == original, "demo source bytes remain unchanged")
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	SaveManager.delete_test_slot(SLOT)
	ProjectSettings.set_setting("ggb/build_flavor", "full")


func _validate_demo_rejections() -> void:
	var conditions := {
		"checksum": &"ERR_SAVE_CHECKSUM", "schema": &"ERR_SAVE_FUTURE_SCHEMA",
		"design": &"ERR_SAVE_DESIGN_REVISION", "slot": &"ERR_IMPORT_SOURCE",
		"flavor": &"ERR_IMPORT_SOURCE", "app": &"ERR_IMPORT_SOURCE",
		"point": &"ERR_IMPORT_BOUNDARY", "boundary": &"ERR_IMPORT_BOUNDARY",
		"progress": &"ERR_IMPORT_PROGRESS",
	}
	for kind in conditions:
		ProjectSettings.set_setting("ggb/build_flavor", "demo")
		SaveManager.delete_test_slot(SLOT)
		var source := _legacy(CHECKPOINTS.new().snapshot_for("D6").snapshot)
		var path := _path()
		var document := _write_source(path, source, 1, "SAVE_D5_COMPLETE")
		match kind:
			"schema": document.save_header.schema_version = 999
			"design": document.save_header.design_revision = "unknown-design"
			"slot": document.save_header.slot_id = "different-slot"
			"flavor": document.save_header.build_flavor = "full"
			"app": document.save_header.source_app_id = "different-app"
			"point": document.save_header.save_point_id = "SAVE_NEW_GAME"
			"boundary": document.save_header.content_boundary_id = "SAVE_NEW_GAME"
			"progress": document.state.meta_progress.knowledge_entries.d5_complete = false
		var text: String = SaveManager._encode_payload(document.save_header, document.state).text
		if kind == "checksum": text = text.replace("Preserved original", "Tampered original")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var original := FileAccess.get_file_as_bytes(path)
		ProjectSettings.set_setting("ggb/build_flavor", "full")
		var directories := DirAccess.get_directories_at(SaveManager.get_save_root())
		var live := GameState.get_snapshot()
		for attempt in range(2):
			var preview: Dictionary = SaveManager.inspect_demo_import(SLOT)
			var imported: Dictionary = SaveManager.import_demo_to_new_slot(SLOT)
			_expect(not preview.get("ok", false) and preview.get("error_id") == conditions[kind], "demo preview rejects source: " + kind + str(attempt))
			_expect(not imported.get("ok", false) and imported.get("error_id") == conditions[kind], "demo import rejects source: " + kind + str(attempt))
			_expect(FileAccess.get_file_as_bytes(path) == original, "rejected demo source remains byte-identical: " + kind)
			_expect(DirAccess.get_directories_at(SaveManager.get_save_root()) == directories, "rejected import allocates no destination slot: " + kind)
			_expect(GameState.get_snapshot() == live, "rejected import leaves live game unchanged: " + kind)
		ProjectSettings.set_setting("ggb/build_flavor", "demo")
		SaveManager.delete_test_slot(SLOT)
	ProjectSettings.set_setting("ggb/build_flavor", "full")


func _validate_demo_target_failure() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	SaveManager.delete_test_slot(SLOT)
	var source := _legacy(CHECKPOINTS.new().snapshot_for("D6").snapshot)
	_write_source(_path(), source, 1, "SAVE_D5_COMPLETE")
	var source_path := _path()
	var original := FileAccess.get_file_as_bytes(source_path)
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var manager := ImportPromotionFailure.new()
	var live := GameState.get_snapshot()
	for foreign in [false, true]:
		manager.foreign_file = foreign
		var result: Dictionary = manager.import_demo_to_new_slot(SLOT)
		_expect(not result.get("ok", false) and result.get("error_id") == &"ERR_SAVE_PROMOTE", "import promotion failure surfaced")
		_expect(not manager.target.is_empty(), "import failure reached real promotion boundary")
		if foreign:
			_expect(FileAccess.get_file_as_string(manager.target.path_join("keep.txt")) == "foreign data", "import rollback preserves unrelated files")
			_expect(result.get("incomplete_slot_id") == manager.target.get_file() and "WARN_IMPORT_CLEANUP" in result.get("warning_ids", []), "incomplete import cleanup is reported")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.target.path_join("keep.txt")))
		else:
			_expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(manager.target)), "failed import releases unused destination directory")
		_expect(not FileAccess.file_exists(manager.target.path_join("progress.tmp.json")), "failed import discards only its uncommitted candidate")
		_expect(FileAccess.get_file_as_bytes(source_path) == original and GameState.get_snapshot() == live, "import failure leaves source and live game unchanged")
		manager.delete_test_slot(manager.target.get_file())
	manager.fail = false
	var retry: Dictionary = manager.import_demo_to_new_slot(SLOT)
	_expect(retry.get("ok", false), "import succeeds after destination fault removed")
	if retry.get("ok", false):
		var loaded: Dictionary = manager.load_slot(retry.slot_id)
		_expect(loaded.get("ok", false) and loaded.snapshot.meta_progress.dialogue_history.entries.size() == source.meta_progress.dialogue_history.entries.size(), "retry installs exactly the original observation count")
		manager.delete_test_slot(retry.slot_id)
	_expect(FileAccess.get_file_as_bytes(source_path) == original and GameState.get_snapshot() == live, "successful retry never edits source or current game")
	manager.free()
	var lost := ImportLostAcknowledgement.new()
	var recovered: Dictionary = lost.import_demo_to_new_slot(SLOT)
	_expect(recovered.get("ok", false) and recovered.get("recovered_acknowledgement", false), "durable import survives lost success acknowledgement")
	if recovered.get("ok", false):
		_expect(lost.load_slot(recovered.slot_id).get("ok", false), "acknowledgement recovery keeps committed destination")
		lost.delete_test_slot(recovered.slot_id)
	_expect(FileAccess.get_file_as_bytes(source_path) == original and GameState.get_snapshot() == live, "acknowledgement recovery preserves demo source and live game")
	lost.free()
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	SaveManager.delete_test_slot(SLOT)
	ProjectSettings.set_setting("ggb/build_flavor", "full")


func _validate_gallery_and_development() -> void:
	var checkpoints := CHECKPOINTS.new()
	var first := checkpoints.snapshot_for("CREDITS_REALITY")
	_expect(first.ok and first.snapshot == checkpoints.snapshot_for("CREDITS_REALITY").snapshot, "developer fixture migration deterministic")
	var state := _legacy(first.snapshot)
	var gallery := EndingGalleryStore.new("user://__test_notebook_gallery")
	var captured := gallery.capture(state)
	_expect(captured.get("ok", false), "completed legacy gallery accepted")
	if not captured.get("ok", false): return
	var path: String = gallery.root_path.path_join(captured.id + ".json")
	var original := FileAccess.get_file_as_bytes(path)
	var before := GameState.get_snapshot()
	var read := gallery.read_entry(captured.id)
	_expect(read.ok and read.id == captured.id and read.state == captured.state, "gallery adapts consistently without changing hash identity")
	_expect(read.state.meta_progress.dialogue_history.entries[0].legacy_payload == state.meta_progress.dialogue_history.entries[0], "gallery keeps original observation")
	_expect(FileAccess.get_file_as_bytes(path) == original and GameState.get_snapshot() == before, "gallery read never rewrites immutable source or live state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gallery.root_path))


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
