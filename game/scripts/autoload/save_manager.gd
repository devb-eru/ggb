extends Node

signal save_completed(slot_id: StringName, save_point_id: StringName)
signal save_failed(slot_id: StringName, error_ids: PackedStringArray)
signal load_recovered(slot_id: StringName, source: StringName)

const SCHEMA_VERSION := 1
const DESIGN_REVISION := "v0.4-state-r12"
const GAME_VERSION := "0.0.0-dev"
const BUILD_ID := "local-dev"
const BUILD_FLAVOR := "demo"
const CONTENT_REVISION := "unlocked"
const SOURCE_APP_ID := "local"
const SAVE_ROOT := "user://saves"


func save_snapshot(
	slot_id: String,
	save_point_id: String,
	snapshot: Dictionary,
	revision: int,
	transaction_id: String
) -> Dictionary:
	if not _is_safe_slot_id(slot_id):
		return _save_failure(slot_id, &"ERR_SAVE_SLOT_ID")
	var slot_dir := "%s/%s" % [SAVE_ROOT, slot_id]
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot_dir))
	if make_dir_error != OK:
		return _save_failure(slot_id, &"ERR_SAVE_CREATE_DIRECTORY")

	var paths := _slot_paths(slot_id)
	var now := int(Time.get_unix_time_from_system())
	var header := {
		"schema_version": SCHEMA_VERSION,
		"design_revision": DESIGN_REVISION,
		"game_version": GAME_VERSION,
		"build_id": BUILD_ID,
		"build_flavor": BUILD_FLAVOR,
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
	return {"ok": true, "path": paths["main"], "checksum": payload["save_header"]["checksum"]}


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


func delete_test_slot(slot_id: String) -> void:
	if not OS.is_debug_build() or not slot_id.begins_with("__test_"):
		return
	var paths := _slot_paths(slot_id)
	_remove_if_exists(paths["main"])
	_remove_if_exists(paths["backup"])
	_remove_if_exists(paths["temporary"])
	var absolute_dir := ProjectSettings.globalize_path("%s/%s" % [SAVE_ROOT, slot_id])
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
	var root := "%s/%s" % [SAVE_ROOT, slot_id]
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
