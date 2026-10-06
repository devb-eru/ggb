extends RefCounted

const VERSION := 1
const SCOPE := preload("res://scripts/systems/notebook_view_store.gd")
var root := "user://profile/presentation_views"


func paths(scope: Dictionary) -> Dictionary:
	if not SCOPE._valid_scope(scope): return {}
	var path := root.path_join(JSON.stringify(scope, "", true).sha256_text())
	return {"main": path + ".json", "backup": path + ".bak.json", "temporary": path + ".tmp.json"}


func load_view(scope: Dictionary, identity: String) -> Dictionary:
	var files := paths(scope)
	if files.is_empty(): return {"view": {}, "writable": false}
	var primary := _read(files.main, scope)
	var backup := _read(files.backup, scope)
	# Never adopt an uncommitted temporary file, but protect its newer format.
	var temporary := _read(files.temporary, scope)
	for row in [primary, backup, temporary]:
		if row.get("future", false): return {"view": {}, "writable": false}
	for row in [primary, backup]:
		if row.get("ok", false):
			return {"view": row.payload.view if row.payload.identity == identity else {}, "writable": true}
	return {"view": {}, "writable": true}


func save_view(scope: Dictionary, identity: String, view: Dictionary) -> bool:
	var files := paths(scope)
	if files.is_empty() or not _identity(identity) or not valid_view(view): return false
	var primary := _read(files.main, scope)
	var backup := _read(files.backup, scope)
	var temporary := _read(files.temporary, scope)
	for row in [primary, backup, temporary]:
		if row.get("future", false): return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK: return false
	var payload := JSON.stringify({"scope": scope, "identity": identity, "view": view}, "", true, true)
	var file := FileAccess.open(files.temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": VERSION, "payload": payload, "checksum": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	var verified := _read(files.temporary, scope)
	if error != OK or not verified.get("ok", false) or verified.encoded != payload: return false
	if primary.get("ok", false):
		if FileAccess.file_exists(files.backup) and DirAccess.remove_absolute(files.backup) != OK: return false
		if DirAccess.copy_absolute(files.main, files.backup) != OK: return false
	if FileAccess.file_exists(files.main) and DirAccess.remove_absolute(files.main) != OK: return false
	if DirAccess.rename_absolute(files.temporary, files.main) != OK:
		if primary.get("ok", false): DirAccess.copy_absolute(files.backup, files.main)
		return false
	return true


func _read(path: String, scope: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() > 65536:
		file.close()
		return {}
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	if parsed != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary: return {}
	if SCOPE._integer(value.get("version")) and value.version > VERSION: return {"future": true}
	if not SCOPE._keys(value, ["version", "payload", "checksum"]) or not SCOPE._integer(value.version) or value.version != VERSION or not value.payload is String or not value.checksum is String: return {}
	if value.payload.sha256_text() != value.checksum: return {}
	if parser.parse(value.payload) != OK: return {}
	var payload: Variant = parser.data
	if not payload is Dictionary or not SCOPE._keys(payload, ["scope", "identity", "view"]): return {}
	if payload.scope != scope or not _identity(payload.identity) or not valid_view(payload.view): return {}
	return {"ok": true, "payload": payload, "encoded": value.payload}


static func _identity(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number()


static func valid_view(value: Variant) -> bool:
	if not value is Dictionary or not SCOPE._keys(value, ["focus", "scrolls", "layout"]): return false
	if not value.focus is String or value.focus.length() > 160 or not value.scrolls is Dictionary or value.scrolls.size() > 32: return false
	if not value.layout is Array or value.layout.size() != 4 or not value.layout[0] is String: return false
	for number in value.layout.slice(1):
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(number) or number <= 0: return false
	for key in value.scrolls:
		var row: Variant = value.scrolls[key]
		if not key is String or key.length() > 160 or not row is Dictionary or not SCOPE._keys(row, ["offset", "fraction"]): return false
		if not SCOPE._integer(row.offset) or row.offset < 0 or row.offset > 10000000 or not SCOPE._fraction(row.fraction): return false
	return true
