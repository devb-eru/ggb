extends Node

signal save_completed(slot_id: StringName, save_point_id: StringName)
signal save_failed(slot_id: StringName, error_ids: PackedStringArray)
signal load_recovered(slot_id: StringName, source: StringName)

const SCHEMA_VERSION := 2
const NOTEBOOK_MIGRATION := preload("res://scripts/systems/notebook_migration.gd")
const NOTEBOOK_ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const NOTEBOOK_ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const DESIGN_REVISION := "v0.4-state-r12"
const GAME_VERSION := "0.0.0-dev"
const BUILD_ID := "local-dev"
const BUILD_FLAVOR := "demo"
const BUILD_FLAVOR_SETTING := "ggb/build_flavor"
const CONTENT_REVISION := "unlocked"
const SOURCE_APP_ID := "local"
const SAVE_ROOT := "user://saves"
const PRODUCT_SLOT_IDS := ["slot_01", "slot_02", "slot_03"]
const SUMMARY_CACHE_LIMIT := 8
const SUMMARY_CACHE_ENTRY_BYTES := 4096
var _summary_cache := {}
var _storage_context := {}
var _notebook_job: Dictionary = {}
var _notebook_results := {}


func _enter_tree() -> void:
	# Runtime-only development override; exported games keep their build setting.
	if OS.has_feature("editor") and "--ggb-dev-full" in OS.get_cmdline_user_args():
		ProjectSettings.set_setting(BUILD_FLAVOR_SETTING, "full")
		print("GGB development full mode: user://saves_full (project setting unchanged on disk)")


func get_build_flavor() -> String:
	if not _storage_context.is_empty(): return _storage_context.flavor
	var flavor := String(ProjectSettings.get_setting(BUILD_FLAVOR_SETTING, BUILD_FLAVOR))
	return flavor if flavor in ["demo", "full"] else BUILD_FLAVOR


func get_save_root() -> String:
	if not _storage_context.is_empty(): return _storage_context.root
	return "user://saves_full" if get_build_flavor() == "full" else SAVE_ROOT


func get_source_app_id() -> String:
	return SOURCE_APP_ID


func begin_notebook_reference(game: Node, slot: String, collection: String, reference: Dictionary, enabled: bool, expected_scope: String, expected_revision: int, command_id: String, completion_guard: Callable = Callable()) -> Dictionary:
	if not _notebook_job.is_empty(): return _load_failure(&"NB_COMMAND_BUSY")
	if not _is_safe_slot_id(slot): return _load_failure(&"ERR_SAVE_SLOT_ID")
	if expected_revision != game.revision: return _load_failure(&"NB_COMMAND_STALE_REVISION")
	if command_id.length() != 32 or not command_id.is_valid_hex_number(): return _load_failure(&"NB_COMMAND_ID")
	var paths := _slot_paths(slot)
	paths.temporary = paths.main.get_base_dir().path_join("progress.notebook_" + command_id + ".tmp.json")
	var snapshot: Dictionary = game.get_snapshot()
	var request := {"id":command_id, "slot":slot, "collection":collection, "reference":reference.duplicate(true), "enabled":enabled,
		"scope":expected_scope, "revision":expected_revision, "load_epoch":int(game.load_epoch), "snapshot":snapshot,
		"paths":paths, "storage":{"flavor":get_build_flavor(), "root":get_save_root()}}
	var worker = load("res://scripts/systems/notebook_save_worker.gd").new()
	var thread := Thread.new()
	if thread.start(worker.prepare.bind(get_script(), request)) != OK: return _load_failure(&"NB_COMMAND_THREAD_START")
	_notebook_results.erase(command_id)
	_notebook_job = {"id":command_id, "slot":slot, "paths":paths, "game":weakref(game), "revision":expected_revision,
		"load_epoch":int(game.load_epoch), "flavor":get_build_flavor(), "root":get_save_root(), "thread":thread, "worker":worker, "cancelled":false,
		"guard":completion_guard, "guard_enabled":not completion_guard.is_null()}
	return {"ok":true, "pending":true, "id":command_id}


func notebook_reference_result(command_id: String) -> Dictionary:
	if _notebook_results.has(command_id):
		var result: Dictionary = _notebook_results[command_id]
		_notebook_results.erase(command_id)
		return result
	return {"ok":true, "pending":true} if _notebook_job.get("id") == command_id else _load_failure(&"NB_COMMAND_UNKNOWN")


func cancel_notebook_reference(command_id: String) -> void:
	if _notebook_job.get("id") == command_id: _notebook_job.cancelled = true


func _process(_delta: float) -> void:
	if _notebook_job.is_empty() or _notebook_job.thread.is_alive(): return
	var job := _notebook_job
	var result: Variant = job.thread.wait_to_finish()
	_notebook_job = {}
	var completed := _finish_notebook_reference(job, result)
	_remove_if_exists(job.paths.temporary)
	while _notebook_results.size() >= 8: _notebook_results.erase(_notebook_results.keys()[0])
	_notebook_results[job.id] = completed


func _exit_tree() -> void:
	if _notebook_job.is_empty(): return
	_notebook_job.thread.wait_to_finish()
	_remove_if_exists(_notebook_job.paths.temporary)
	_notebook_job = {}


func _finish_notebook_reference(job: Dictionary, result: Variant) -> Dictionary:
	if job.cancelled: return _load_failure(&"NB_COMMAND_CANCELLED")
	if job.guard_enabled and (not job.guard.is_valid() or not job.guard.call()): return _load_failure(&"NB_COMMAND_SCOPE")
	var game = job.game.get_ref()
	if not is_instance_valid(game) or game.revision != job.revision or int(game.load_epoch) != job.load_epoch:
		return _load_failure(&"NB_COMMAND_STALE_REVISION")
	if get_build_flavor() != job.flavor or get_save_root() != job.root: return _load_failure(&"NB_COMMAND_SCOPE")
	if not result is Dictionary: return _load_failure(&"NB_COMMAND_PREPARE")
	if not result.get("ok", false): return result
	var worker = job.worker
	for kind in ["main", "backup"]:
		var current: Dictionary = worker.read_source(job.paths[kind])
		if not current.ok or current.stamp != result.source_stamps[kind]: return _load_failure(&"NB_COMMAND_SOURCE_CHANGED")
	if not result.changed: return {"ok":true, "changed":false}
	var temporary: Dictionary = worker.read_source(job.paths.temporary)
	if not temporary.ok or temporary.stamp != result.temporary_stamp: return _load_failure(&"ERR_SAVE_TEMP_VERIFY")
	for source in result.sources.values():
		var preserved := _preserve_legacy_source(source)
		if not preserved.ok: return preserved
	var promoted := _commit_prepared(job.paths, result.sources.main, result.sources.backup)
	if not promoted.ok:
		var confirmed := confirm_snapshot_commit(job.slot, result.transaction)
		if not confirmed.get("ok", false) or not StateSnapshotValidator.same_persisted_value(result.snapshot, confirmed.snapshot): return promoted
	# No await between the final revision check, promotion and the live installation.
	var revision: int = game.commit_validated_snapshot(result.snapshot, job.revision, StringName(result.transaction), PackedStringArray(["meta_progress"]))
	if revision < 0: return _load_failure(&"NB_COMMAND_INSTALL")
	_cache_summary(_summary_key(job.paths.main), result.temporary_stamp, result.summary)
	if not result.snapshot.meta_progress.knowledge_entries.get("F3_complete", false): _clear_previous_f3(job.slot)
	save_completed.emit(StringName(job.slot), StringName(result.point))
	return {"ok":true, "changed":true, "recovered_acknowledgement":not promoted.ok}


func list_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_id in PRODUCT_SLOT_IDS:
		summaries.append(inspect_slot(slot_id))
	return summaries


func inspect_slot(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return {"slot_id": slot_id, "available": false, "error_id": &"ERR_SAVE_SLOT_ID"}
	var paths := _slot_paths(slot_id)
	var result := _inspect_file(paths["main"])
	var source := "main"
	if not bool(result.get("ok", false)) and not _is_incompatible(result):
		var backup := _inspect_file(paths["backup"])
		if bool(backup.get("ok", false)) or _is_incompatible(backup):
			result = backup
			source = "backup"
	if not bool(result.get("ok", false)):
		return {
			"slot_id": slot_id,
			"available": false,
			"incompatible": _is_incompatible(result),
			"error_id": result.get("error_id", &"ERR_SAVE_NOT_FOUND"),
		}
	result.erase("ok")
	result["slot_id"] = slot_id
	result["available"] = true
	result["source"] = source
	return result


func _inspect_file(path: String) -> Dictionary:
	var key := _summary_key(path)
	if not FileAccess.file_exists(path):
		_summary_cache.erase(key)
		return _load_failure(&"ERR_SAVE_NOT_FOUND")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_summary_cache.erase(key)
		return _load_failure(&"ERR_SAVE_OPEN")
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		_summary_cache.erase(key)
		return _load_failure(&"ERR_SAVE_OPEN")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	var fingerprint := digest.finish().hex_encode()
	# Read the actual bytes every time; timestamps and the saved checksum are not cache identities.
	var cached: Dictionary = _summary_cache.get(key, {})
	_summary_cache.erase(key)
	if cached.get("fingerprint") == fingerprint:
		_summary_cache[key] = cached
		return cached.summary.duplicate(true)
	var validated := _validate_save_text(bytes.get_string_from_utf8(), path)
	if not validated.get("ok", false): return validated
	var summary := _summary_from_validated(validated)
	_cache_summary(key, fingerprint, summary)
	return summary


func _summary_key(path: String) -> String:
	return "%s:%s" % [ProjectSettings.globalize_path(path), NOTEBOOK_ROLLOUT.enabled()]


func _cache_summary(key: String, fingerprint: String, summary: Dictionary) -> void:
	# Retain only small display metadata, never the snapshot or source bytes.
	_summary_cache.erase(key)
	if JSON.stringify(summary).to_utf8_buffer().size() <= SUMMARY_CACHE_ENTRY_BYTES:
		while _summary_cache.size() >= SUMMARY_CACHE_LIMIT:
			_summary_cache.erase(_summary_cache.keys()[0])
		_summary_cache[key] = {"fingerprint":fingerprint, "summary":summary.duplicate(true)}


func _summary_from_validated(validated: Dictionary) -> Dictionary:
	var header: Dictionary = validated["header"]
	var snapshot: Dictionary = validated["snapshot"]
	var loop_state: Dictionary = snapshot.get("loop_state", {})
	var meta_progress: Dictionary = snapshot.get("meta_progress", {})
	return {
		"ok": true,
		"updated_at_utc": int(header.get("updated_at_utc", 0)),
		"save_point_id": String(header.get("save_point_id", "")),
		"run_id": String(header.get("run_id", "")),
		"day_index": int(loop_state.get("day_index", 0)),
		"location_id": String(loop_state.get("location_id", "")),
		"journal_stage": int(meta_progress.get("journal_stage", 0)),
	}


func find_latest_slot_id() -> String:
	var latest_slot_id := ""
	var latest_timestamp := -1
	for summary in list_slot_summaries():
		if not bool(summary.get("available", false)):
			continue
		var timestamp := int(summary.get("updated_at_utc", 0))
		if timestamp > latest_timestamp:
			latest_timestamp = timestamp
			latest_slot_id = String(summary["slot_id"])
	return latest_slot_id


func save_snapshot(
	slot_id: String,
	save_point_id: String,
	snapshot: Dictionary,
	revision: int,
	transaction_id: String
) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return _save_failure(slot_id, &"ERR_SAVE_SLOT_ID")
	var slot_dir := "%s/%s" % [get_save_root(), slot_id]
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot_dir))
	if make_dir_error != OK:
		return _save_failure(slot_id, &"ERR_SAVE_CREATE_DIRECTORY")

	var paths := _slot_paths(slot_id)
	var previous := _read_and_validate(paths["main"])
	if _is_incompatible(previous): return _save_failure(slot_id, previous.error_id)
	var previous_backup := _read_and_validate(paths.backup)
	if _is_incompatible(previous_backup): return _save_failure(slot_id, previous_backup.error_id)
	var pending := _read_and_validate(paths.temporary)
	if _is_incompatible(pending): return _save_failure(slot_id, pending.error_id)
	var promote_legacy := NOTEBOOK_ROLLOUT.enabled()
	var meta: Variant = snapshot.get("meta_progress")
	var history: Variant = meta.get("dialogue_history") if meta is Dictionary else null
	var migration_digest := ""
	if promote_legacy and history is Dictionary and not history.has("schema_version"):
		migration_digest = JSON.stringify(_canonicalize(snapshot)).sha256_text()
	var prepared := NOTEBOOK_MIGRATION.adapt_verified(snapshot, migration_digest, promote_legacy)
	if not prepared.get("ok", false): return _save_failure(slot_id, &"ERR_SAVE_SNAPSHOT_INVALID")
	snapshot = prepared.snapshot
	var write_schema := SCHEMA_VERSION if snapshot.meta_progress.dialogue_history.has("schema_version") else 1
	if write_schema == SCHEMA_VERSION:
		for source in [previous, previous_backup]:
			var preserved := _preserve_legacy_source(source)
			if not preserved.ok: return _save_failure(slot_id, preserved.error_id)
	var run_id: String = previous.get("header", {}).get("run_id", "") if previous.get("ok", false) else ""
	if run_id.is_empty() or transaction_id.begins_with("NEW_GAME_"):
		run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var header := _make_save_header(slot_id, save_point_id, revision, transaction_id, run_id, write_schema)
	var encoded := _encode_payload(header, snapshot)

	var file := FileAccess.open(paths["temporary"], FileAccess.WRITE)
	if file == null:
		return _save_failure(slot_id, &"ERR_SAVE_TEMP_OPEN")
	file.store_string(encoded.text)
	file.flush()
	file.close()

	var temp_validation := _read_and_validate(paths["temporary"], true)
	if not bool(temp_validation.get("ok", false)):
		_remove_if_exists(paths["temporary"])
		return _save_failure(slot_id, &"ERR_SAVE_TEMP_VERIFY")
	var temporary_key := _summary_key(paths.temporary)
	var verified_summary: Dictionary = _summary_cache.get(temporary_key, {}).duplicate(true)
	_summary_cache.erase(temporary_key)
	var promoted := _commit_prepared(paths, previous, previous_backup)
	if not promoted.ok: return _save_failure(slot_id, promoted.error_id)
	if not verified_summary.is_empty():
		_cache_summary(_summary_key(paths.main), verified_summary.fingerprint, verified_summary.summary)

	save_completed.emit(StringName(slot_id), StringName(save_point_id))
	var warnings := PackedStringArray()
	if not snapshot.get("meta_progress", {}).get("knowledge_entries", {}).get("F3_complete", false):
		warnings = _clear_previous_f3(slot_id)
	return {"ok": true, "path": paths["main"], "checksum": encoded.checksum, "warning_ids": warnings}


func _make_save_header(slot_id: String, save_point_id: String, revision: int, transaction_id: String, run_id: String, write_schema: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"run_id": run_id,
		"schema_version": write_schema,
		"design_revision": DESIGN_REVISION,
		"game_version": GAME_VERSION,
		"build_id": BUILD_ID,
		"build_flavor": get_build_flavor(),
		"content_revision": CONTENT_REVISION,
		"content_boundary_id": save_point_id,
		"source_app_id": SOURCE_APP_ID,
		"engine_version": "%d.%d" % [
			int(Engine.get_version_info().get("major", 0)),
			int(Engine.get_version_info().get("minor", 0)),
		],
		"slot_id": slot_id,
		"save_point_id": save_point_id,
		"transaction_id": transaction_id,
		"state_revision": revision,
		"created_at_utc": now,
		"updated_at_utc": now,
		"checksum_algorithm": "sha256",
		"checksum": "",
	}


func _commit_prepared(paths: Dictionary, previous: Dictionary, previous_backup: Dictionary) -> Dictionary:
	if FileAccess.file_exists(paths["main"]):
		# Only a validated primary may replace the last recovery copy.
		if previous.get("ok", false):
			_remove_if_exists(paths["backup"])
			var backup_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(paths["main"]),
				ProjectSettings.globalize_path(paths["backup"])
			)
			if backup_error != OK:
				_remove_if_exists(paths["temporary"])
				return _load_failure(&"ERR_SAVE_BACKUP_COPY")
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(paths["main"])) != OK:
			_remove_if_exists(paths["temporary"])
			return _load_failure(&"ERR_SAVE_REPLACE")

	var promote_error := _promote_temporary(paths)
	if promote_error != OK:
		if (previous.get("ok", false) or previous_backup.get("ok", false)) and FileAccess.file_exists(paths["backup"]):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(paths["backup"]),
				ProjectSettings.globalize_path(paths["main"])
			)
		return _load_failure(&"ERR_SAVE_PROMOTE")
	return {"ok":true}


func _promote_temporary(paths: Dictionary) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(paths.temporary), ProjectSettings.globalize_path(paths.main))


func _encode_payload(header: Dictionary, snapshot: Dictionary) -> Dictionary:
	var payload: Dictionary = _canonicalize({"save_header":header, "state":snapshot})
	payload.save_header.checksum = ""
	var unsigned_text := JSON.stringify(payload, "\t", false)
	var header_prefix := _save_header_prefix(payload.save_header)
	var checksum := _checksum_text(unsigned_text)
	# Replacing this existing value preserves the already canonical key order.
	payload.save_header.checksum = checksum
	var signed_text: String
	if unsigned_text.begins_with(header_prefix):
		signed_text = _save_header_prefix(payload.save_header) + unsigned_text.substr(header_prefix.length())
	else:
		# Preserve the original encoder if the engine's JSON layout changes.
		signed_text = JSON.stringify(payload, "\t", false)
	return {"text":signed_text, "checksum":checksum}


func _save_header_prefix(header: Dictionary) -> String:
	return "{\n\t\"save_header\": " + JSON.stringify(header, "\t", false).replace("\n", "\n\t")


func load_slot(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return {"ok": false, "error_ids": PackedStringArray(["ERR_SAVE_SLOT_ID"])}
	var paths := _slot_paths(slot_id)
	var primary := _read_and_validate(paths["main"], true)
	if bool(primary.get("ok", false)):
		primary = _promote_legacy(slot_id, primary)
		if not primary.get("ok", false): return primary
		primary["source"] = "main"
		return primary
	if _is_incompatible(primary):
		return primary

	var backup := _read_and_validate(paths["backup"])
	if _is_incompatible(backup): return backup
	if bool(backup.get("ok", false)):
		# Recovery will write a new branch; guard its destination before changing main.
		var pending := _read_and_validate(paths.temporary)
		if _is_incompatible(pending): return pending
		if NOTEBOOK_ROLLOUT.enabled():
			var preserved := _preserve_legacy_source(backup)
			if not preserved.ok: return preserved
		_remove_if_exists(paths["main"])
		var recovery_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(paths["backup"]),
			ProjectSettings.globalize_path(paths["main"])
		)
		if recovery_error != OK:
			return _load_failure(&"ERR_SAVE_RECOVERY_COPY")
		backup = _read_and_validate(paths.main, true)
		backup = _promote_legacy(slot_id, backup)
		if not backup.get("ok", false): return _failed_backup_recovery(paths, backup)
		if backup.snapshot.meta_progress.dialogue_history.has("schema_version"):
			var before_fork: Dictionary = backup.snapshot.duplicate(true)
			backup.snapshot.meta_progress.dialogue_history = NOTEBOOK_ROLLOUT.fork_history(backup.snapshot.meta_progress.dialogue_history)
			preload("res://scripts/systems/notebook_presentation.gd").carry(backup.snapshot, before_fork)
			var branch_saved := save_snapshot(slot_id, String(backup.header.save_point_id), backup.snapshot, int(backup.header.state_revision), "BACKUP_RECOVERY_BRANCH")
			if not branch_saved.ok: return _failed_backup_recovery(paths, branch_saved)
			backup = _read_and_validate(paths.main)
		backup["source"] = "backup"
		load_recovered.emit(StringName(slot_id), &"backup")
		return backup
	return primary


func _failed_backup_recovery(paths: Dictionary, failure: Dictionary) -> Dictionary:
	# Keep the next load on the recovery path until a distinct branch is durable.
	var main := _read_and_validate(paths.main)
	var backup := _read_and_validate(paths.backup)
	if main.get("ok", false) and backup.get("ok", false) and main.snapshot == backup.snapshot:
		_remove_if_exists(paths.main)
	return failure


func inspect_demo_import(slot_id: String) -> Dictionary:
	if get_build_flavor() != "full" or not _is_safe_slot_id(slot_id): return _load_failure(&"ERR_IMPORT_CONTEXT")
	var loaded := _read_and_validate(SAVE_ROOT.path_join(slot_id).path_join("progress.json"))
	if not loaded.get("ok", false): return loaded
	var header: Dictionary = loaded["header"]
	if header.get("slot_id") != slot_id or header.get("build_flavor") != "demo" or header.get("source_app_id") != SOURCE_APP_ID:
		return _load_failure(&"ERR_IMPORT_SOURCE")
	if header.get("save_point_id") != "SAVE_D5_COMPLETE" or header.get("content_boundary_id") != "SAVE_D5_COMPLETE":
		return _load_failure(&"ERR_IMPORT_BOUNDARY")
	var validator := StateSnapshotValidator.new()
	var state := validator.normalize(loaded["snapshot"])
	if not validator.validate(state).get("ok", false): return _load_failure(&"ERR_IMPORT_STATE")
	if not state["meta_progress"]["knowledge_entries"].get("d5_complete", false) or state["fracture_state"].get("broken_reset_triggered", false) or state["ending_run"]["final_decision"] != "unset":
		return _load_failure(&"ERR_IMPORT_PROGRESS")
	loaded["snapshot"] = state
	return loaded


func import_demo_to_new_slot(source_slot_id: String) -> Dictionary:
	var source := inspect_demo_import(source_slot_id)
	if not source.get("ok", false): return source
	var target := ""
	if OS.is_debug_build() and source_slot_id.begins_with("__test_"):
		target = "__test_import_" + Crypto.new().generate_random_bytes(16).hex_encode()
	else:
		for id in PRODUCT_SLOT_IDS:
			if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(get_save_root().path_join(id))):
				target = id
				break
	if target.is_empty() or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(get_save_root().path_join(target))): return _load_failure(&"ERR_IMPORT_NO_EMPTY_SLOT")
	var state: Dictionary = source["snapshot"].duplicate(true)
	state.meta_progress.dialogue_history = NOTEBOOK_ROLLOUT.fork_history(state.meta_progress.dialogue_history)
	state["meta_progress"]["knowledge_entries"]["demo_import_source"] = {"slot_id":source_slot_id,"checksum":source["header"]["checksum"]}
	var root := ProjectSettings.globalize_path(get_save_root())
	if DirAccess.make_dir_recursive_absolute(root) != OK: return _load_failure(&"ERR_SAVE_CREATE_DIRECTORY")
	# Reserve an absent directory so failure cleanup never owns an existing slot.
	if DirAccess.make_dir_absolute(root.path_join(target)) != OK: return _load_failure(&"ERR_IMPORT_NO_EMPTY_SLOT")
	var transaction := "DEMO_IMPORT_" + Crypto.new().generate_random_bytes(16).hex_encode()
	var result := save_snapshot(target, "SAVE_FRACTURE_CONFIRMED", state, int(source["header"]["state_revision"]), transaction)
	if not result.get("ok", false):
		var committed := confirm_snapshot_commit(target, transaction)
		if committed.get("ok", false) and StateSnapshotValidator.same_persisted_value(committed.snapshot, state):
			result = {"ok":true, "recovered_acknowledgement":true}
		elif not _discard_failed_import(target, transaction):
			result["warning_ids"] = PackedStringArray(["WARN_IMPORT_CLEANUP"])
			result["incomplete_slot_id"] = target
	if result.get("ok", false): result["slot_id"] = target
	return result


func _discard_failed_import(slot_id: String, transaction: String) -> bool:
	var paths := _slot_paths(slot_id)
	if FileAccess.file_exists(paths.main) or FileAccess.file_exists(paths.backup): return false
	var pending := _read_and_validate(paths.temporary)
	if _is_incompatible(pending): return false
	if pending.get("ok", false) and (pending.header.get("transaction_id") != transaction or pending.header.get("slot_id") != slot_id): return false
	if FileAccess.file_exists(paths.temporary):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(paths.temporary)) != OK: return false
	# Non-recursive removal preserves unexpected files and directories.
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(paths.main.get_base_dir())) == OK


func capture_f3_reselect(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id): return _load_failure(&"ERR_SAVE_SLOT_ID")
	var paths := _slot_paths(slot_id)
	var source := _read_and_validate(paths["main"])
	if not _valid_f3_copy(source, slot_id): return _load_failure(&"ERR_RESELECT_SOURCE")
	var target := "%s/%s/f3_reselect.json" % [get_save_root(), slot_id]
	var previous: Dictionary = {}
	# Check every destination before the first copy can overwrite newer data.
	for suffix in ["", ".tmp", ".bak"]:
		var existing := _read_and_validate(target + suffix)
		if _is_incompatible(existing): return existing
		if suffix.is_empty(): previous = existing
	var temporary := target + ".tmp"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(paths["main"]), ProjectSettings.globalize_path(temporary)) != OK:
		return _load_failure(&"ERR_RESELECT_COPY")
	if not _valid_f3_copy(_read_and_validate(temporary), slot_id): return _load_failure(&"ERR_RESELECT_VERIFY")
	if FileAccess.file_exists(target):
		if _valid_f3_copy(previous, slot_id) and previous.header.get("run_id", "") == source.header.get("run_id", ""):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(target + ".bak")) != OK:
				return _load_failure(&"ERR_RESELECT_BACKUP")
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK: return _load_failure(&"ERR_RESELECT_REPLACE")
	if _promote_temporary({"main":target, "temporary":temporary}) != OK:
		return _load_failure(&"ERR_RESELECT_PROMOTE")
	return {"ok":true,"path":target}


func load_f3_reselect(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id): return _load_failure(&"ERR_SAVE_SLOT_ID")
	# A stale sidecar is never enough: the current primary must belong to a run that reached F3.
	var current := _read_and_validate(_slot_paths(slot_id)["main"])
	if not current.get("ok", false): return current
	if current["header"].get("slot_id") != slot_id or current["header"].get("build_flavor") != get_build_flavor():
		return _load_failure(&"ERR_RESELECT_SOURCE")
	if not current["snapshot"].get("meta_progress", {}).get("knowledge_entries", {}).get("F3_complete", false):
		return _load_failure(&"ERR_RESELECT_CURRENT_RUN")
	var path := "%s/%s/f3_reselect.json" % [get_save_root(), slot_id]
	# A verified temporary candidate is not a committed reselect checkpoint.
	for suffix in ["", ".bak"]:
		var result := _read_and_validate(path + suffix)
		if _is_incompatible(result): return result
		if _valid_f3_copy(result, slot_id):
			var run_id: String = current["header"].get("run_id", "")
			if not run_id.is_empty() and result["header"].get("run_id", "") == run_id: return result
	return _load_failure(&"ERR_RESELECT_UNAVAILABLE")


func _clear_previous_f3(slot_id: String) -> PackedStringArray:
	var warnings := PackedStringArray()
	var path := "%s/%s/f3_reselect.json" % [get_save_root(), slot_id]
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := _read_and_validate(path + suffix)
		if _is_incompatible(candidate):
			return PackedStringArray(["WARN_RESELECT_DESIGN_PRESERVED" if candidate.error_id == &"ERR_SAVE_DESIGN_REVISION" else "WARN_RESELECT_FUTURE_PRESERVED"])
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) != OK:
			warnings.append("WARN_RESELECT_CLEANUP")
	return warnings


func create_f3_reselect_slot(source_slot_id: String) -> Dictionary:
	var loaded := load_f3_reselect(source_slot_id)
	if not loaded.get("ok", false): return loaded
	var snapshot: Dictionary = loaded["snapshot"].duplicate(true)
	snapshot.meta_progress.dialogue_history = NOTEBOOK_ROLLOUT.fork_history(snapshot.meta_progress.dialogue_history)
	snapshot["ending_run"]["reselect_used"] = true
	snapshot["meta_progress"]["knowledge_entries"]["reselect_source_slot_id"] = source_slot_id
	snapshot["meta_progress"]["knowledge_entries"]["reselect_source_run_id"] = loaded["header"].get("run_id", "")
	var prefix := "__test_reselect_" if source_slot_id.begins_with("__test_") else "reselect_"
	var target := prefix + Crypto.new().generate_random_bytes(16).hex_encode()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(get_save_root().path_join(target))):
		return _load_failure(&"ERR_RESELECT_COLLISION")
	var result := save_snapshot(target, "SAVE_F3_COMPLETE", snapshot, int(loaded["header"]["state_revision"]), "RESELECT_COPY")
	if result.get("ok", false):
		result["slot_id"] = target
		result["source_slot_id"] = source_slot_id
	return result


func list_reselect_slots(source_slot_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not _is_safe_slot_id(source_slot_id): return found
	var source := _read_and_validate(_slot_paths(source_slot_id)["main"])
	if not source.get("ok", false): return found
	var run_id: String = source["header"].get("run_id", "")
	if run_id.is_empty(): return found
	for name in DirAccess.get_directories_at(get_save_root()):
		if not name.begins_with("reselect_") and not name.begins_with("__test_reselect_"): continue
		var saved := _read_and_validate(_slot_paths(name)["main"])
		if not saved.get("ok", false): continue
		if saved["header"].get("build_flavor") != get_build_flavor(): continue
		var knowledge: Dictionary = saved["snapshot"].get("meta_progress", {}).get("knowledge_entries", {})
		if knowledge.get("reselect_source_slot_id") != source_slot_id or knowledge.get("reselect_source_run_id") != run_id: continue
		var summary := inspect_slot(name)
		if summary.get("available", false): found.append(summary)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["updated_at_utc"] > b["updated_at_utc"])
	return found


func _valid_f3_copy(result: Dictionary, slot_id: String) -> bool:
	if not result.get("ok", false): return false
	var header: Dictionary = result["header"]
	var snapshot: Dictionary = result["snapshot"]
	if header.get("slot_id") != slot_id or header.get("save_point_id") != "SAVE_F3_COMPLETE" or header.get("build_flavor") != get_build_flavor(): return false
	var validator := StateSnapshotValidator.new()
	if not validator.validate(validator.normalize(snapshot)).get("ok", false): return false
	var run: Dictionary = snapshot["ending_run"]
	return snapshot["meta_progress"]["knowledge_entries"].get("F3_complete", false) and snapshot["fracture_state"].get("final_sleep_lock", false) and run.get("final_decision") == "unset" and not run.get("branch_committed", false)


func delete_test_slot(slot_id: String) -> void:
	if not OS.is_debug_build() or not slot_id.begins_with("__test_"):
		return
	var paths := _slot_paths(slot_id)
	_remove_if_exists(paths["main"])
	for suffix in ["", ".tmp", ".bak"]:
		_remove_if_exists("%s/%s/f3_reselect.json%s" % [get_save_root(), slot_id, suffix])
	_remove_if_exists(paths["backup"])
	_remove_if_exists(paths["temporary"])
	var absolute_dir := ProjectSettings.globalize_path("%s/%s" % [get_save_root(), slot_id])
	if not DirAccess.dir_exists_absolute(absolute_dir): return
	for filename in DirAccess.get_files_at(absolute_dir):
		if filename.begins_with("pre_notebook_") and filename.ends_with(".json"):
			_remove_if_exists(absolute_dir.path_join(filename))
	DirAccess.remove_absolute(absolute_dir)


func _read_and_validate(path: String, capture_summary: bool = false) -> Dictionary:
	if capture_summary: _summary_cache.erase(_summary_key(path))
	if not FileAccess.file_exists(path):
		return _load_failure(&"ERR_SAVE_NOT_FOUND")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _load_failure(&"ERR_SAVE_OPEN")
	var raw_text := file.get_as_text()
	file.close()
	var validated := _validate_save_text(raw_text, path)
	if capture_summary and validated.get("ok", false):
		# Bind metadata to the exact text that was validated, not the planned write.
		_cache_summary(_summary_key(path), raw_text.sha256_text(), _summary_from_validated(validated))
	return validated


func _validate_save_text(raw_text: String, path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		return _load_failure(&"ERR_SAVE_INVALID_JSON")
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return _load_failure(&"ERR_SAVE_INVALID_JSON")
	var payload: Dictionary = parsed
	if not payload.has("save_header") or not payload["save_header"] is Dictionary:
		return _load_failure(&"ERR_SAVE_HEADER_MISSING")
	if not payload.has("state") or not payload["state"] is Dictionary:
		return _load_failure(&"ERR_SAVE_STATE_MISSING")
	var schema_value: Variant = payload["save_header"].get("schema_version")
	if not (schema_value is int or schema_value is float) or not is_finite(float(schema_value)) or float(schema_value) != floor(float(schema_value)):
		return _load_failure(&"ERR_SAVE_SCHEMA_UNSUPPORTED")
	var schema_version := int(schema_value)
	if schema_version > SCHEMA_VERSION:
		return _load_failure(&"ERR_SAVE_FUTURE_SCHEMA")
	if schema_version not in [1, SCHEMA_VERSION]:
		return _load_failure(&"ERR_SAVE_SCHEMA_UNSUPPORTED")
	if String(payload["save_header"].get("design_revision", "")) != DESIGN_REVISION:
		return _load_failure(&"ERR_SAVE_DESIGN_REVISION")
	if String(payload["save_header"].get("checksum_algorithm", "")) != "sha256":
		return _load_failure(&"ERR_SAVE_CHECKSUM_ALGORITHM")
	var stored_checksum := String(payload["save_header"].get("checksum", ""))
	var signed_token := "\"checksum\": \"%s\"" % stored_checksum
	var unsigned_token := "\"checksum\": \"\""
	if stored_checksum.is_empty() or signed_token not in raw_text:
		return _load_failure(&"ERR_SAVE_CHECKSUM")
	var unsigned_text := raw_text.replace(signed_token, unsigned_token)
	if stored_checksum != _checksum_text(unsigned_text):
		return _load_failure(&"ERR_SAVE_CHECKSUM")
	if schema_version == SCHEMA_VERSION:
		if not payload.state.get("meta_progress") is Dictionary or not payload.state.meta_progress.get("dialogue_history") is Dictionary:
			return _load_failure(&"ERR_SAVE_NOTEBOOK_SCHEMA")
		var notebook_version: Variant = payload.state.meta_progress.dialogue_history.get("schema_version")
		if not (notebook_version is int or notebook_version is float):
			return _load_failure(&"ERR_SAVE_NOTEBOOK_SCHEMA")
		if notebook_version > NOTEBOOK_ARCHIVE.VERSION:
			return _load_failure(&"ERR_SAVE_FUTURE_SCHEMA")
		if notebook_version != NOTEBOOK_ARCHIVE.VERSION:
			return _load_failure(&"ERR_SAVE_NOTEBOOK_SCHEMA")
	var meta: Variant = payload.state.get("meta_progress")
	var cursor: Dictionary = preload("res://scripts/systems/notebook_presentation.gd").read(payload.state)
	if cursor is Dictionary:
		var version: Variant = cursor.get("schema_version")
		if (version is int or version is float) and is_finite(float(version)) and float(version) == floor(float(version)) and version > preload("res://scripts/systems/notebook_presentation.gd").VERSION:
			return _load_failure(&"ERR_SAVE_FUTURE_SCHEMA")
	if meta is Dictionary and meta.get("knowledge_entries") is Dictionary:
		var ledger: Variant = meta.knowledge_entries.get("notebook_knowledge")
		if ledger is Dictionary:
			var version: Variant = ledger.get("schema_version")
			if (version is int or version is float) and is_finite(float(version)) and float(version) == floor(float(version)) and version > 1:
				return _load_failure(&"ERR_SAVE_FUTURE_SCHEMA")
	var adapted := NOTEBOOK_MIGRATION.adapt_verified(payload.state, stored_checksum, NOTEBOOK_ROLLOUT.enabled())
	if not adapted.get("ok", false): return _load_failure(&"ERR_SAVE_NOTEBOOK_MIGRATION")
	return {
		"ok": true,
		"header": payload["save_header"],
		"snapshot": adapted.snapshot,
		"source_path": path,
		"source_schema_version": schema_version,
	}


func _preserve_legacy_source(source: Dictionary) -> Dictionary:
	if _is_incompatible(source): return source
	if not source.get("ok", false) or source.get("source_schema_version") != 1: return {"ok": true}
	var path: String = source.source_path
	var checksum: String = source.header.checksum
	var target := path.get_base_dir().path_join("pre_notebook_" + checksum + ".json")
	if FileAccess.file_exists(target):
		return {"ok": true} if FileAccess.get_file_as_bytes(target) == FileAccess.get_file_as_bytes(path) else _load_failure(&"ERR_SAVE_MIGRATION_BACKUP_COLLISION")
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(target)) != OK:
		return _load_failure(&"ERR_SAVE_MIGRATION_BACKUP")
	if FileAccess.get_file_as_bytes(target) != FileAccess.get_file_as_bytes(path): return _load_failure(&"ERR_SAVE_MIGRATION_BACKUP_VERIFY")
	return {"ok": true}


func confirm_snapshot_commit(slot_id: String, transaction_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id): return _load_failure(&"ERR_SAVE_SLOT_ID")
	var saved := _read_and_validate(_slot_paths(slot_id).main)
	if not saved.get("ok", false): return saved
	if saved.header.get("transaction_id") != transaction_id: return _load_failure(&"ERR_SAVE_TRANSACTION_UNCONFIRMED")
	return saved


func _promote_legacy(slot_id: String, loaded: Dictionary) -> Dictionary:
	if not NOTEBOOK_ROLLOUT.enabled(): return loaded
	if not loaded.get("ok", false) or loaded.get("source_schema_version") != 1: return loaded
	var saved := save_snapshot(slot_id, String(loaded.header.save_point_id), loaded.snapshot, int(loaded.header.state_revision), "NOTEBOOK_MIGRATION")
	if not saved.ok: return saved
	return _read_and_validate(_slot_paths(slot_id).main)


func _checksum_text(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var normalized := {}
		var keys: Array = dictionary_value.keys()
		keys.sort()
		for key in keys:
			normalized[String(key)] = _canonicalize(dictionary_value[key])
		return normalized
	if value is Array:
		var array_value: Array = value
		var normalized_array := []
		for item in array_value:
			normalized_array.append(_canonicalize(item))
		return normalized_array
	if value is StringName:
		return String(value)
	return value


func _slot_paths(slot_id: String) -> Dictionary:
	var root := "%s/%s" % [get_save_root(), slot_id]
	return {
		"main": "%s/progress.json" % root,
		"backup": "%s/progress.bak.json" % root,
		"temporary": "%s/progress.tmp.json" % root,
	}


func _is_safe_slot_id(slot_id: String) -> bool:
	return slot_id.is_valid_filename() and not slot_id.is_empty() and "/" not in slot_id and "\\" not in slot_id


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _save_failure(slot_id: String, error_id: StringName) -> Dictionary:
	var errors := PackedStringArray([String(error_id)])
	save_failed.emit(StringName(slot_id), errors)
	return {"ok": false, "error_ids": errors, "error_id": error_id}


func _is_incompatible(result: Dictionary) -> bool:
	return result.get("error_id") in [&"ERR_SAVE_FUTURE_SCHEMA", &"ERR_SAVE_DESIGN_REVISION"]


func _load_failure(error_id: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_ids": PackedStringArray([String(error_id)]),
		"error_id": error_id,
	}
