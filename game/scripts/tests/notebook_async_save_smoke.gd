extends RefCounted

const STORAGE := preload("res://scripts/autoload/save_manager.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")
const SLOT := "__test_notebook_async_save"
var errors := PackedStringArray()
var checks := 0


class PromotionFailure extends "res://scripts/autoload/save_manager.gd":
	func _promote_temporary(_paths: Dictionary) -> Error: return ERR_CANT_CREATE


class LostAcknowledgement extends "res://scripts/autoload/save_manager.gd":
	func _commit_prepared(paths: Dictionary, previous: Dictionary, backup: Dictionary) -> Dictionary:
		var saved := super._commit_prepared(paths, previous, backup)
		return _load_failure(&"TEST_LOST_ACK") if saved.ok else saved


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)


func run(tree: SceneTree) -> Dictionary:
	for scenario in ["success", "backup_recovery", "future_primary", "future_backup", "design_primary", "design_backup", "unchanged", "cancel", "revision", "reload", "disk", "future", "temporary", "guard", "namespace", "shutdown", "write_failure", "promotion_failure", "lost_ack"]:
		await _scenario(tree, scenario)
	await _large_candidate(tree)
	print("NOTEBOOK_ASYNC_SAVE_CHECKS: ", checks)
	return {"ok":errors.is_empty(), "errors":errors}


func _large_candidate(tree: SceneTree) -> void:
	var fixture := preload("res://scripts/tests/notebook_performance_fixture.gd").build("NB-PERF-L10000")
	_expect(fixture.ok, "build deterministic large asynchronous fixture")
	if not fixture.ok: return
	var state := GameState.make_default_snapshot()
	state.meta_progress.dialogue_history = fixture.archive
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_ASYNC_LARGE").ok, "install isolated large fixture")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, GameState.revision, "ASYNC_LARGE_SEED").ok, "persist isolated large fixture")
	var candidates: Array = fixture.archive.entries.filter(func(entry: Dictionary) -> bool: return entry.record_class == "legacy")
	var reference := ARCHIVE.make_reference(candidates[0], "legacy")
	var scope := COMMANDS.scope(GameState, SaveManager, SLOT)
	var manager := STORAGE.new()
	tree.root.add_child(manager)
	manager.set_process(false)
	var start := Time.get_ticks_usec()
	var id := ARCHIVE.new_uid()
	var result := manager.begin_notebook_reference(GameState, SLOT, "bookmarks", reference, true, scope, GameState.revision, id)
	var begin_ms := (Time.get_ticks_usec() - start) / 1000.0
	_expect(result.ok, "begin large candidate")
	if not result.ok:
		manager.free()
		return
	var frames := 0
	var last_frame := Time.get_ticks_usec()
	var max_frame_ms := 0.0
	while manager._notebook_job.thread.is_alive():
		await tree.process_frame
		var now := Time.get_ticks_usec()
		max_frame_ms = maxf(max_frame_ms, (now - last_frame) / 1000.0)
		last_frame = now
		frames += 1
		if now - start > 120000000:
			_expect(false, "large candidate exceeds watchdog")
			manager.free()
			return
	var dispatch_start := Time.get_ticks_usec()
	manager._process(0.0)
	var dispatch_ms := (Time.get_ticks_usec() - dispatch_start) / 1000.0
	result = manager.notebook_reference_result(id)
	_expect(result.ok and result.changed and frames > 0, "large candidate yields scene frames and commits")
	var loaded := SaveManager.load_slot(SLOT)
	_expect(loaded.ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), loaded.snapshot), "large archive and reference survive reload")
	print("NOTEBOOK_ASYNC_SAVE_MEASUREMENT: ", JSON.stringify({"fixture":fixture.manifest, "begin_ms":begin_ms, "dispatch_ms":dispatch_ms, "worker_frames":frames, "max_wait_frame_ms":max_frame_ms, "acceptance":"MEASUREMENT_ONLY_HEADLESS_SINGLE_SAMPLE"}))
	manager.free()
	SaveManager.delete_test_slot(SLOT)


func _seed() -> Dictionary:
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.make_default_snapshot()
	var legacy := {"next_sequence":1, "entries":[{"sequence":0, "line_id":"CH1_HISTORY_TRANSCRIPT", "speaker_id":"SYSTEM", "variables":{"text":"Saved source", "speaker":"Narrator"}}]}
	state.meta_progress.dialogue_history = ARCHIVE.migrate_verified_legacy(legacy, "async-fixture".sha256_text()).archive
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_ASYNC_FIXTURE").ok, "install asynchronous fixture")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, GameState.revision, "ASYNC_SEED").ok, "seed primary")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, GameState.revision, "ASYNC_BACKUP").ok, "seed backup")
	return ARCHIVE.make_reference(state.meta_progress.dialogue_history.entries[0], "legacy")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "open owned fault fixture")
	if file == null: return
	file.store_string(text)
	file.close()


func _scenario(tree: SceneTree, scenario: String) -> void:
	var reference := _seed()
	var manager: Node = PromotionFailure.new() if scenario == "promotion_failure" else (LostAcknowledgement.new() if scenario == "lost_ack" else STORAGE.new())
	tree.root.add_child(manager)
	manager.set_process(false)
	var paths: Dictionary = manager._slot_paths(SLOT)
	if scenario == "backup_recovery": _write(paths.main, "owned corrupt primary")
	if scenario in ["future_primary", "future_backup", "design_primary", "design_backup"]:
		var future_path: String = paths.main if scenario.ends_with("primary") else paths.backup
		var future: Dictionary = SaveManager._read_and_validate(future_path)
		if scenario.begins_with("design_"): future.header.design_revision = "unknown-design"
		else: future.header.schema_version = 999
		_write(future_path, SaveManager._encode_payload(future.header, future.snapshot).text)
	var primary := FileAccess.get_file_as_bytes(paths.main)
	var backup := FileAccess.get_file_as_bytes(paths.backup)
	var before := GameState.get_snapshot()
	var revision := GameState.revision
	var id := ARCHIVE.new_uid()
	var temporary: String = paths.main.get_base_dir().path_join("progress.notebook_" + id + ".tmp.json")
	if scenario == "write_failure":
		_expect(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary)) == OK, "block only owned candidate path")
	var guard := {"allowed":true}
	var original_scope := COMMANDS.scope(GameState, SaveManager, SLOT)
	var started: Dictionary = manager.begin_notebook_reference(GameState, SLOT, "bookmarks", reference, scenario != "unchanged", original_scope, revision, id, func() -> bool: return guard.allowed)
	_expect(started.ok and started.get("pending", false), "start background candidate: " + scenario)
	if not started.ok:
		manager.free()
		return
	_expect(GameState.get_snapshot() == before and GameState.revision == revision, "no optimistic live installation: " + scenario)
	_expect(FileAccess.get_file_as_bytes(paths.main) == primary and FileAccess.get_file_as_bytes(paths.backup) == backup, "begin leaves durable files intact: " + scenario)
	var second: Dictionary = manager.begin_notebook_reference(GameState, SLOT, "comparison", reference, true, "scope", revision, ARCHIVE.new_uid())
	_expect(not second.ok and second.error_id == &"NB_COMMAND_BUSY", "one candidate owner per service")
	var frames := 0
	var started_at := Time.get_ticks_msec()
	while manager._notebook_job.thread.is_alive():
		await tree.process_frame
		frames += 1
		if Time.get_ticks_msec() - started_at > 60000:
			_expect(false, "candidate preparation exceeds watchdog: " + scenario)
			manager.free()
			return
	if frames > 0: _expect(true, "scene frames continue during candidate preparation: " + scenario)
	_expect(GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == primary and FileAccess.get_file_as_bytes(paths.backup) == backup, "finished worker has not published game or files: " + scenario)
	if scenario == "shutdown":
		manager.free()
		_expect(not FileAccess.file_exists(temporary) and GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == primary and FileAccess.get_file_as_bytes(paths.backup) == backup, "service shutdown joins and discards without publishing")
		SaveManager.delete_test_slot(SLOT)
		return
	match scenario:
		"cancel": manager.cancel_notebook_reference(id)
		"revision", "reload":
			_expect(StateWriter.new(GameState).install_snapshot(before, GameState.revision, &"LOAD_ASYNC_CONFLICT" if scenario == "reload" else &"ASYNC_CONFLICT").ok, "a newer writer may proceed while candidate runs")
		"disk":
			_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", before, GameState.revision, "ASYNC_OTHER_WRITER").ok, "ordinary save may proceed before candidate promotion")
			primary = FileAccess.get_file_as_bytes(paths.main)
			backup = FileAccess.get_file_as_bytes(paths.backup)
		"future":
			var saved: Dictionary = SaveManager._read_and_validate(paths.main)
			saved.header.schema_version = 999
			_write(paths.main, SaveManager._encode_payload(saved.header, saved.snapshot).text)
			primary = FileAccess.get_file_as_bytes(paths.main)
		"temporary": _write(temporary, "changed candidate")
		"guard": guard.allowed = false
		"namespace": ProjectSettings.set_setting("ggb/build_flavor", "demo")
	manager._process(0.0)
	if scenario == "namespace": ProjectSettings.set_setting("ggb/build_flavor", "full")
	var result: Dictionary = manager.notebook_reference_result(id)
	_expect(not result.get("pending", false), "terminal result is observable: " + scenario)
	if scenario in ["success", "backup_recovery", "lost_ack"]:
		_expect(result.ok and result.changed, "verified candidate commits: " + scenario)
		_expect(GameState.revision == revision + 1 and GameState.get_snapshot().meta_progress.dialogue_history.bookmarks.size() == 1, "live state changes only at durable commit")
		var loaded: Dictionary = SaveManager.load_slot(SLOT)
		_expect(loaded.ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), loaded.snapshot), "committed reference and protection reload together")
		_expect(COMMANDS.scope(GameState, SaveManager, SLOT) == original_scope, "reference-only commit preserves run identity including backup recovery")
		if scenario == "lost_ack": _expect(result.recovered_acknowledgement, "lost promotion acknowledgement uses verified commit")
		if scenario == "backup_recovery": _expect(FileAccess.get_file_as_bytes(paths.backup) == backup, "corrupt primary never replaces validated backup")
	elif scenario == "unchanged":
		_expect(result.ok and not result.changed and GameState.revision == revision and GameState.get_snapshot() == before, "idempotent no-op leaves live state unchanged")
		_expect(FileAccess.get_file_as_bytes(paths.main) == primary and FileAccess.get_file_as_bytes(paths.backup) == backup, "idempotent no-op performs no disk promotion")
	else:
		_expect(not result.ok, "unsafe candidate rejected: " + scenario)
		if scenario.begins_with("design_"): _expect(result.get("error_id") == &"ERR_SAVE_DESIGN_REVISION", "unknown design worker preserves incompatibility error: " + scenario)
		_expect(GameState.get_snapshot() == before, "rejected candidate leaves current game intact: " + scenario)
		# Failed promotion restores the verified previous primary into both files.
		if scenario == "promotion_failure": backup = primary
		_expect(FileAccess.get_file_as_bytes(paths.main) == primary and FileAccess.get_file_as_bytes(paths.backup) == backup, "rejected candidate preserves current durable files: " + scenario)
	_expect(not FileAccess.file_exists(temporary), "owned temporary file removed: " + scenario)
	_expect(manager._notebook_job.is_empty(), "worker joined and ownership released: " + scenario)
	if scenario == "write_failure":
		_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)) == OK, "remove owned failure directory")
	manager.free()
	SaveManager.delete_test_slot(SLOT)
