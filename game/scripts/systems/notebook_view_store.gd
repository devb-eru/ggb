extends RefCounted

# Convenience state only. No game snapshot, content, or durable reference is written here.
const VERSION := 3
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
const SCOPE_KEYS := ["profile", "namespace", "slot", "run_id", "source_origin_id", "branch_id"]
const VIEW_KEYS := ["filters", "anchor", "page", "selected", "scroll", "list_scroll", "list_anchor", "body", "pair", "pair_body", "comparing", "side", "detail", "back", "focus"]
var root_path: String


func _init(path: String = "user://profile/notebook_views") -> void:
	root_path = path


static func empty_state() -> Dictionary:
	return {"seen": [], "groups": [], "general": {}, "dialogue": {}}


static func persistent_scope(scope: Dictionary, profile: String = "local") -> Dictionary:
	var result := {"profile": profile}
	for field in SCOPE_KEYS:
		if field != "profile": result[field] = scope.get(field, "")
	return result


func paths(scope: Dictionary) -> Dictionary:
	if not _valid_scope(scope): return {}
	var key := JSON.stringify(scope, "", true).sha256_text()
	return {"main": root_path.path_join(key + ".json"), "backup": root_path.path_join(key + ".bak.json"), "temporary": root_path.path_join(key + ".tmp.json")}


func load_view(scope: Dictionary, frontier: Dictionary) -> Dictionary:
	if not _valid_scope(scope) or not _valid_frontier(frontier): return _default("NB_VIEW_SCOPE", false)
	var files := paths(scope)
	var primary := _read(files.main, scope)
	var backup := _read(files.backup, scope)
	for result in [primary, backup]:
		if result.get("error_id") == "NB_VIEW_FUTURE": return _default("NB_VIEW_FUTURE", false)
	for result in [primary, backup]:
		if not result.ok: continue
		if _past(result.payload.frontier, frontier): return _default("NB_VIEW_PAST_SNAPSHOT")
		return {"ok": true, "state": result.payload.state, "writable": true, "source": "primary" if result == primary else "backup", "warning_id": "" if result == primary else "NB_VIEW_RECOVERED"}
	return _default("" if primary.get("error_id") == "NB_VIEW_MISSING" and backup.get("error_id") == "NB_VIEW_MISSING" else "NB_VIEW_DAMAGED")


func save_view(scope: Dictionary, frontier: Dictionary, state: Dictionary) -> Dictionary:
	if not _valid_scope(scope) or not _valid_frontier(frontier) or not valid_state(state): return _error("NB_VIEW_PAYLOAD")
	var files := paths(scope)
	var primary := _read(files.main, scope)
	var backup := _read(files.backup, scope)
	for existing in [primary, backup]:
		if existing.get("error_id") == "NB_VIEW_FUTURE": return _error("NB_VIEW_FUTURE")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path)) != OK: return _error("NB_VIEW_DIRECTORY")
	var payload := {"scope": scope.duplicate(true), "frontier": frontier.duplicate(true), "state": state.duplicate(true)}
	var encoded := JSON.stringify(payload, "", true, true)
	var envelope := {"version": VERSION, "payload": encoded, "checksum": encoded.sha256_text()}
	var file := FileAccess.open(files.temporary, FileAccess.WRITE)
	if file == null: return _error("NB_VIEW_TEMP_OPEN")
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return _error("NB_VIEW_TEMP_WRITE")
	var checked := _read(files.temporary, scope)
	if not checked.ok: return _error("NB_VIEW_TEMP_VERIFY_" + String(checked.get("error_id", "UNKNOWN")))
	# Fractional UI positions can round during JSON parsing; verify the exact wire payload.
	if checked.encoded != encoded: return _error("NB_VIEW_TEMP_VALUE")
	# Never replace a good backup with a corrupt primary.
	if primary.ok:
		if FileAccess.file_exists(files.backup) and DirAccess.remove_absolute(files.backup) != OK: return _error("NB_VIEW_BACKUP")
		if DirAccess.copy_absolute(files.main, files.backup) != OK: return _error("NB_VIEW_BACKUP")
	if FileAccess.file_exists(files.main) and DirAccess.remove_absolute(files.main) != OK: return _error("NB_VIEW_REPLACE")
	if DirAccess.rename_absolute(files.temporary, files.main) != OK:
		if primary.ok: DirAccess.copy_absolute(files.backup, files.main)
		return _error("NB_VIEW_PROMOTE")
	return {"ok": true}


func _read(path: String, scope: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path): return _error("NB_VIEW_MISSING")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _error("NB_VIEW_OPEN")
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	if parsed != OK: return _error("NB_VIEW_FORMAT")
	var envelope: Variant = parser.data
	if not envelope is Dictionary: return _error("NB_VIEW_FORMAT")
	if _integer(envelope.get("version")) and envelope.version > VERSION: return _error("NB_VIEW_FUTURE")
	if not _keys(envelope, ["version", "payload", "checksum"]) or not _integer(envelope.version) or int(envelope.version) not in [1, 2, VERSION]: return _error("NB_VIEW_FORMAT")
	if not envelope.payload is String or not envelope.checksum is String or envelope.payload.sha256_text() != envelope.checksum: return _error("NB_VIEW_CHECKSUM")
	if parser.parse(envelope.payload) != OK: return _error("NB_VIEW_PAYLOAD")
	var payload: Variant = parser.data
	if not payload is Dictionary or not _keys(payload, ["scope", "frontier", "state"]): return _error("NB_VIEW_PAYLOAD")
	if not _valid_scope(payload.scope) or payload.scope != scope or not _valid_frontier(payload.frontier) or not valid_state(payload.state): return _error("NB_VIEW_PAYLOAD")
	return {"ok": true, "payload": payload, "encoded": envelope.payload}


static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["seen", "groups", "general", "dialogue"]): return false
	for field in ["seen", "groups"]:
		if not value[field] is Array: return false
		var unique := {}
		for item in value[field]:
			if not item is String or item.is_empty() or unique.has(item): return false
			unique[item] = true
	if not _valid_view(value.general) or not _valid_view(value.dialogue): return false
	return value.dialogue.is_empty() or value.dialogue.filters.get("tab") == "dialogue"


static func _valid_view(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not (_keys(value, VIEW_KEYS) or _keys(value, VIEW_KEYS + ["visuals"])) or not value.filters is Dictionary: return false
	if value.has("visuals"):
		if not value.visuals is Dictionary or value.visuals.size() > 64: return false
		for key in value.visuals:
			if not key is String or key.is_empty() or not VISUALS.valid_view(value.visuals[key]): return false
	if not QUERY.valid_filters(value.filters): return false
	if not _anchor(value.anchor) or not _anchor(value.list_anchor): return false
	for field in ["selected"]:
		if not value[field] is String: return false
	for field in ["page", "scroll", "list_scroll", "side"]:
		if not _integer(value[field]) or value[field] < 0: return false
	if value.side > 1: return false
	for field in ["comparing", "detail"]:
		if not value[field] is bool: return false
	if not value.pair is Array or value.pair.size() != 2 or not value.pair_body is Array or value.pair_body.size() != 2: return false
	for side in range(2):
		if not value.pair[side] is String or not _body(value.pair_body[side]): return false
	if not _body(value.body) or not _focus(value.focus) or not value.back is Array or value.back.size() > 32: return false
	for step in value.back:
		if not step is Dictionary or not _keys(step, ["key", "scroll", "body", "focus"]) or not step.key is String or not _integer(step.scroll) or step.scroll < 0 or not _body(step.body) or not _focus(step.focus): return false
	return true


static func _anchor(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not _keys(value, ["key", "sort", "fraction"]) or not value.key is String or not value.sort is Array or value.sort.size() != 3 or not _fraction(value.fraction): return false
	for item in value.sort:
		if not _integer(item): return false
	return true


static func _body(value: Variant) -> bool:
	return value is Dictionary and _keys(value, ["paragraph", "fraction"]) and _integer(value.paragraph) and value.paragraph >= -1 and _fraction(value.fraction)


static func _focus(value: Variant) -> bool:
	return value is Dictionary and _keys(value, ["control", "key"]) and value.control is String and value.key is String


static func _valid_scope(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, SCOPE_KEYS): return false
	for field in SCOPE_KEYS:
		if not value[field] is String or value[field].is_empty(): return false
	return true


static func _valid_frontier(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["archive_revision", "next_sequence", "last_uid", "knowledge_revision", "legacy_digest"]): return false
	for field in ["archive_revision", "next_sequence", "knowledge_revision"]:
		if not _integer(value[field]) or value[field] < 0: return false
	return value.last_uid is String and value.legacy_digest is String


static func _past(saved: Dictionary, current: Dictionary) -> bool:
	for field in ["archive_revision", "next_sequence", "knowledge_revision"]:
		if current[field] < saved[field]: return true
	if current.next_sequence == saved.next_sequence and current.last_uid != saved.last_uid: return true
	return current.archive_revision == saved.archive_revision and current.knowledge_revision == saved.knowledge_revision and current.legacy_digest != saved.legacy_digest


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0)


static func _fraction(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value) and value >= 0 and value <= 1


static func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


static func _default(warning: String = "", writable: bool = true) -> Dictionary:
	return {"ok": true, "state": empty_state(), "writable": writable, "source": "default", "warning_id": warning}


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id}
