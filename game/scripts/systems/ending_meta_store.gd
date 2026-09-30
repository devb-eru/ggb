class_name EndingMetaStore
extends RefCounted

const KEYS := ["reality_seen", "stay_seen", "any_ending_seen", "gallery_unlocked", "chapter_select_unlocked", "reality_all_seen", "stay_all_seen"]
const FILES := ["ending_meta.json", "ending_meta.bak.json", "ending_meta.tmp.json"]
var root_path: String

func _init(path: String = "user://profile") -> void:
	root_path = path

func load_profile() -> Dictionary:
	var meta: Dictionary = {}
	for key in KEYS: meta[key] = false
	var recovered := false
	for name in FILES:
		var path := root_path.path_join(name)
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: return {"ok":false,"error":"profile_read"}
		var parser := JSON.new()
		var parse_error := parser.parse(file.get_as_text())
		var parsed: Variant = parser.data if parse_error == OK else null
		file.close()
		if parsed is Dictionary and typeof(parsed.get("ending_meta_profile_version")) in [TYPE_INT, TYPE_FLOAT] and parsed["ending_meta_profile_version"] > 1:
			return {"ok":false,"error":"future_profile"}
		if not _valid(parsed):
			recovered = true
			continue
		for key in KEYS: meta[key] = meta[key] or parsed["ending_meta"].get(key, false)
	return {"ok":true,"profile":{"ending_meta_profile_version":1,"ending_meta":meta},"recovered":recovered}

func commit_completed(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("ending_run", {})
	var branch: String = run.get("branch_id", "")
	if not run.get("branch_committed", false) or branch not in ["reality", "stay"]:
		return {"ok":false,"error":"ending_incomplete"}
	var frame := "EDR_FINAL_FRAME" if branch == "reality" else "EDS_FINAL_FRAME"
	if frame not in run.get("completed_nodes", []): return {"ok":false,"error":"ending_incomplete"}
	var loaded := load_profile()
	if not loaded["ok"]: return loaded
	var document: Dictionary = loaded["profile"]
	var meta: Dictionary = document["ending_meta"]
	meta[branch + "_seen"] = true
	for key in ["any_ending_seen", "gallery_unlocked", "chapter_select_unlocked"]: meta[key] = true
	if run.get("all_ceremony_seen", false): meta[branch + "_all_seen"] = true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path)) != OK:
		return {"ok":false,"error":"profile_directory"}
	# Each valid copy contributes monotonically; an interrupted promotion never removes seen flags.
	for name in ["ending_meta.tmp.json", "ending_meta.bak.json", "ending_meta.json"]:
		var file := FileAccess.open(root_path.path_join(name), FileAccess.WRITE)
		if file == null: return {"ok":false,"error":"profile_write"}
		file.store_string(JSON.stringify(document, "\t"))
		file.flush()
		var error := file.get_error()
		file.close()
		if error != OK: return {"ok":false,"error":"profile_flush"}
		var verify := FileAccess.open(root_path.path_join(name), FileAccess.READ)
		if verify == null: return {"ok":false,"error":"profile_verify"}
		var parsed: Variant = JSON.parse_string(verify.get_as_text())
		verify.close()
		if not _valid(parsed) or parsed["ending_meta"] != meta: return {"ok":false,"error":"profile_verify"}
	return {"ok":true,"profile":document}

func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("ending_meta_profile_version") != 1: return false
	var meta: Variant = value.get("ending_meta")
	if not meta is Dictionary: return false
	for key in KEYS:
		if key.ends_with("_all_seen") and not meta.has(key): continue
		if not meta.get(key) is bool: return false
	var any_seen: bool = meta["reality_seen"] or meta["stay_seen"]
	if meta["any_ending_seen"] != any_seen or meta["gallery_unlocked"] != any_seen or meta["chapter_select_unlocked"] != any_seen: return false
	for branch in ["reality", "stay"]:
		if meta.get(branch + "_all_seen", false) and not meta[branch + "_seen"]: return false
	return true
