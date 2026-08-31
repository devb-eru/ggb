class_name AccessibilityProfileStore
extends RefCounted

const PROFILE_VERSION := 1
const DEFAULT_ROOT := "user://profile"

var _root_path: String


func _init(root_path: String = DEFAULT_ROOT) -> void:
	_root_path = root_path


func default_profile() -> Dictionary:
	return {
		"accessibility_profile_version": PROFILE_VERSION,
		"first_run_complete": false,
		"text_scale": 1.0,
		"signature_mode": "color_pattern_label",
		"motion_mode": "standard",
		"captions_enabled": true,
	}


func load_profile() -> Dictionary:
	var primary := _read_profile(_path("accessibility.json"))
	if bool(primary.get("ok", false)):
		return primary
	var backup := _read_profile(_path("accessibility.bak.json"))
	if bool(backup.get("ok", false)):
		backup["source"] = "backup"
		return backup
	return {
		"ok": true,
		"source": "default",
		"profile": default_profile(),
		"warning_ids": primary.get("error_ids", PackedStringArray()),
	}


func save_profile(profile_value: Dictionary) -> Dictionary:
	var validation := validate_profile(profile_value)
	if not bool(validation.get("ok", false)):
		return validation
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root_path))
	if make_dir_error != OK:
		return _failure(&"ERR_ACCESSIBILITY_DIRECTORY")
	var temporary_path := _path("accessibility.tmp.json")
	var primary_path := _path("accessibility.json")
	var backup_path := _path("accessibility.bak.json")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure(&"ERR_ACCESSIBILITY_TEMP_OPEN")
	file.store_string(JSON.stringify(profile_value, "\t", false))
	file.flush()
	file.close()
	var verify := _read_profile(temporary_path)
	if not bool(verify.get("ok", false)):
		_remove(temporary_path)
		return _failure(&"ERR_ACCESSIBILITY_TEMP_VERIFY")
	if FileAccess.file_exists(primary_path):
		_remove(backup_path)
		var backup_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(primary_path),
			ProjectSettings.globalize_path(backup_path)
		)
		if backup_error != OK:
			_remove(temporary_path)
			return _failure(&"ERR_ACCESSIBILITY_BACKUP")
		_remove(primary_path)
	var promote_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(primary_path)
	)
	if promote_error != OK:
		return _failure(&"ERR_ACCESSIBILITY_PROMOTE")
	return {"ok": true, "profile": profile_value.duplicate(true)}


func validate_profile(profile_value: Variant) -> Dictionary:
	var errors := PackedStringArray()
	if not profile_value is Dictionary:
		return _failure(&"ERR_ACCESSIBILITY_TYPE")
	var profile: Dictionary = profile_value
	var required := [
		"accessibility_profile_version",
		"first_run_complete",
		"text_scale",
		"signature_mode",
		"motion_mode",
		"captions_enabled",
	]
	for field in required:
		if not profile.has(field):
			errors.append("ERR_ACCESSIBILITY_FIELD")
	if int(profile.get("accessibility_profile_version", -1)) != PROFILE_VERSION:
		errors.append("ERR_ACCESSIBILITY_VERSION")
	if typeof(profile.get("first_run_complete")) != TYPE_BOOL or typeof(profile.get("captions_enabled")) != TYPE_BOOL:
		errors.append("ERR_ACCESSIBILITY_BOOL")
	var text_scale := float(profile.get("text_scale", 0.0))
	if text_scale not in [1.0, 1.25, 1.5, 2.0]:
		errors.append("ERR_ACCESSIBILITY_TEXT_SCALE")
	if String(profile.get("signature_mode", "")) not in ["color_pattern_label", "pattern_label", "label_only"]:
		errors.append("ERR_ACCESSIBILITY_SIGNATURE")
	if String(profile.get("motion_mode", "")) not in ["standard", "reduced", "static"]:
		errors.append("ERR_ACCESSIBILITY_MOTION")
	return {"ok": errors.is_empty(), "error_ids": errors}


func delete_test_profile() -> void:
	if not OS.is_debug_build() or "__test_" not in _root_path:
		return
	for file_name in ["accessibility.json", "accessibility.bak.json", "accessibility.tmp.json"]:
		_remove(_path(file_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_root_path))


func _read_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure(&"ERR_ACCESSIBILITY_NOT_FOUND")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(&"ERR_ACCESSIBILITY_OPEN")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var validation := validate_profile(parsed)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true, "source": "primary", "profile": parsed}


func _path(file_name: String) -> String:
	return "%s/%s" % [_root_path, file_name]


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _failure(error_id: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_id": error_id,
		"error_ids": PackedStringArray([String(error_id)]),
	}
