extends Node

signal save_completed(slot_id: StringName, save_point_id: StringName)
signal save_failed(slot_id: StringName, error_ids: PackedStringArray)
signal load_recovered(slot_id: StringName, source: StringName)

const SCHEMA_VERSION := 1
const DESIGN_REVISION := "v0.4-state-r12"
const GAME_VERSION := "0.0.0-dev"
const BUILD_ID := "local-dev"
const BUILD_FLAVOR := "demo"
const BUILD_FLAVOR_SETTING := "ggb/build_flavor"
const CONTENT_REVISION := "unlocked"
const SOURCE_APP_ID := "local"
const SAVE_ROOT := "user://saves"
const PRODUCT_SLOT_IDS := ["slot_01", "slot_02", "slot_03"]


func get_build_flavor() -> String:
	var flavor := String(ProjectSettings.get_setting(BUILD_FLAVOR_SETTING, BUILD_FLAVOR))
	return flavor if flavor in ["demo", "full"] else BUILD_FLAVOR


func get_save_root() -> String:
	return "user://saves_full" if get_build_flavor() == "full" else SAVE_ROOT


func get_source_app_id() -> String:
	return SOURCE_APP_ID


func list_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_id in PRODUCT_SLOT_IDS:
		summaries.append(inspect_slot(slot_id))
	return summaries


func inspect_slot(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return {"slot_id": slot_id, "available": false, "error_id": &"ERR_SAVE_SLOT_ID"}
	var paths := _slot_paths(slot_id)
	var result := _read_and_validate(paths["main"])
	var source := "main"
	if not bool(result.get("ok", false)) and result.get("error_id", &"") != &"ERR_SAVE_FUTURE_SCHEMA":
		var backup := _read_and_validate(paths["backup"])
		if bool(backup.get("ok", false)):
			result = backup
			source = "backup"
	if not bool(result.get("ok", false)):
		return {
			"slot_id": slot_id,
			"available": false,
			"incompatible": result.get("error_id", &"") == &"ERR_SAVE_FUTURE_SCHEMA",
			"error_id": result.get("error_id", &"ERR_SAVE_NOT_FOUND"),
		}
	var header: Dictionary = result["header"]
	var snapshot: Dictionary = result["snapshot"]
	var loop_state: Dictionary = snapshot.get("loop_state", {})
	var meta_progress: Dictionary = snapshot.get("meta_progress", {})
	return {
		"slot_id": slot_id,
		"available": true,
		"source": source,
		"updated_at_utc": int(header.get("updated_at_utc", 0)),
		"save_point_id": String(header.get("save_point_id", "")),
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
	var now := int(Time.get_unix_time_from_system())
	var previous := _read_and_validate(paths["main"])
	var run_id: String = previous.get("header", {}).get("run_id", "") if previous.get("ok", false) else ""
	if run_id.is_empty() or transaction_id.begins_with("NEW_GAME_"):
		run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var header := {
		"run_id": run_id,
		"schema_version": SCHEMA_VERSION,
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
	var payload := {"save_header": header, "state": _canonicalize(snapshot)}
	var unsigned_text := JSON.stringify(_canonicalize(payload), "\t", false)
	payload["save_header"]["checksum"] = _checksum_text(unsigned_text)
	var signed_text := JSON.stringify(_canonicalize(payload), "\t", false)

	var file := FileAccess.open(paths["temporary"], FileAccess.WRITE)
	if file == null:
		return _save_failure(slot_id, &"ERR_SAVE_TEMP_OPEN")
	file.store_string(signed_text)
	file.flush()
	file.close()

	var temp_validation := _read_and_validate(paths["temporary"])
	if not bool(temp_validation.get("ok", false)):
		_remove_if_exists(paths["temporary"])
		return _save_failure(slot_id, &"ERR_SAVE_TEMP_VERIFY")

	if FileAccess.file_exists(paths["main"]):
		_remove_if_exists(paths["backup"])
		var backup_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(paths["main"]),
			ProjectSettings.globalize_path(paths["backup"])
		)
		if backup_error != OK:
			_remove_if_exists(paths["temporary"])
			return _save_failure(slot_id, &"ERR_SAVE_BACKUP_COPY")
		_remove_if_exists(paths["main"])

	var promote_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(paths["temporary"]),
		ProjectSettings.globalize_path(paths["main"])
	)
	if promote_error != OK:
		if FileAccess.file_exists(paths["backup"]):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(paths["backup"]),
				ProjectSettings.globalize_path(paths["main"])
			)
		return _save_failure(slot_id, &"ERR_SAVE_PROMOTE")

	save_completed.emit(StringName(slot_id), StringName(save_point_id))
	var warnings := PackedStringArray()
	if not snapshot.get("meta_progress", {}).get("knowledge_entries", {}).get("F3_complete", false):
		warnings = _clear_previous_f3(slot_id)
	return {"ok": true, "path": paths["main"], "checksum": payload["save_header"]["checksum"], "warning_ids": warnings}


func load_slot(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return {"ok": false, "error_ids": PackedStringArray(["ERR_SAVE_SLOT_ID"])}
	var paths := _slot_paths(slot_id)
	var primary := _read_and_validate(paths["main"])
	if bool(primary.get("ok", false)):
		primary["source"] = "main"
		return primary
	if primary.get("error_id", &"") == &"ERR_SAVE_FUTURE_SCHEMA":
		return primary

	var backup := _read_and_validate(paths["backup"])
	if bool(backup.get("ok", false)):
		_remove_if_exists(paths["main"])
		var recovery_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(paths["backup"]),
			ProjectSettings.globalize_path(paths["main"])
		)
		if recovery_error != OK:
			return _load_failure(&"ERR_SAVE_RECOVERY_COPY")
		backup["source"] = "backup"
		load_recovered.emit(StringName(slot_id), &"backup")
		return backup
	return primary


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
	state["meta_progress"]["knowledge_entries"]["demo_import_source"] = {"slot_id":source_slot_id,"checksum":source["header"]["checksum"]}
	var result := save_snapshot(target, "SAVE_FRACTURE_CONFIRMED", state, int(source["header"]["state_revision"]), "DEMO_IMPORT")
	if result.get("ok", false): result["slot_id"] = target
	return result


func capture_f3_reselect(slot_id: String) -> Dictionary:
	if not _is_safe_slot_id(slot_id): return _load_failure(&"ERR_SAVE_SLOT_ID")
	var paths := _slot_paths(slot_id)
	var source := _read_and_validate(paths["main"])
	if not _valid_f3_copy(source, slot_id): return _load_failure(&"ERR_RESELECT_SOURCE")
	var target := "%s/%s/f3_reselect.json" % [get_save_root(), slot_id]
	var existing := _read_and_validate(target)
	if existing.get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA": return existing
	var temporary := target + ".tmp"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(paths["main"]), ProjectSettings.globalize_path(temporary)) != OK:
		return _load_failure(&"ERR_RESELECT_COPY")
	if not _valid_f3_copy(_read_and_validate(temporary), slot_id): return _load_failure(&"ERR_RESELECT_VERIFY")
	if FileAccess.file_exists(target):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(target + ".bak")) != OK:
			return _load_failure(&"ERR_RESELECT_BACKUP")
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK: return _load_failure(&"ERR_RESELECT_REPLACE")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target)) != OK:
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
	for suffix in ["", ".tmp", ".bak"]:
		var result := _read_and_validate(path + suffix)
		if result.get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA": return result
		if _valid_f3_copy(result, slot_id):
			var run_id: String = current["header"].get("run_id", "")
			if not run_id.is_empty() and result["header"].get("run_id", "") == run_id: return result
	return _load_failure(&"ERR_RESELECT_UNAVAILABLE")


func _clear_previous_f3(slot_id: String) -> PackedStringArray:
	var warnings := PackedStringArray()
	var path := "%s/%s/f3_reselect.json" % [get_save_root(), slot_id]
	for suffix in ["", ".tmp", ".bak"]:
		if _read_and_validate(path + suffix).get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA":
			return PackedStringArray(["WARN_RESELECT_FUTURE_PRESERVED"])
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) != OK:
			warnings.append("WARN_RESELECT_CLEANUP")
	return warnings


func create_f3_reselect_slot(source_slot_id: String) -> Dictionary:
	var loaded := load_f3_reselect(source_slot_id)
	if not loaded.get("ok", false): return loaded
	var snapshot: Dictionary = loaded["snapshot"].duplicate(true)
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
	DirAccess.remove_absolute(absolute_dir)


func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _load_failure(&"ERR_SAVE_NOT_FOUND")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _load_failure(&"ERR_SAVE_OPEN")
	var raw_text := file.get_as_text()
	file.close()
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
	var schema_version := int(payload["save_header"].get("schema_version", -1))
	if schema_version > SCHEMA_VERSION:
		return _load_failure(&"ERR_SAVE_FUTURE_SCHEMA")
	if schema_version != SCHEMA_VERSION:
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
	return {
		"ok": true,
		"header": payload["save_header"],
		"snapshot": payload["state"],
	}


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


func _load_failure(error_id: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_ids": PackedStringArray([String(error_id)]),
		"error_id": error_id,
	}
