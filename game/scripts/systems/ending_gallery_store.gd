class_name EndingGalleryStore
extends RefCounted

var root_path: String

func _init(path: String = "user://profile/ending_gallery") -> void:
	root_path = path

func capture(source: Dictionary) -> Dictionary:
	var state := StateSnapshotValidator.new().normalize(source)
	if not _completed(state): return {"ok":false,"error":"gallery_incomplete"}
	# Credits presentation is not a different ending variant.
	var run: Dictionary = state["ending_run"]
	for key in ["credits_started", "credits_completed"]: run.erase(key)
	run["current_node_id"] = "EDR_FINAL_FRAME" if run["branch_id"] == "reality" else "EDS_FINAL_FRAME"
	for node in ["CREDITS_REALITY", "CREDITS_STAY"]: run["completed_nodes"].erase(node)
	state["loop_state"]["event_local_states"].erase("ENDING_CREDITS")
	var payload := JSON.stringify(state, "\t", true)
	var id := payload.sha256_text()
	var path := root_path.path_join(id + ".json")
	if FileAccess.file_exists(path): return read_entry(id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path)) != OK: return {"ok":false,"error":"gallery_directory"}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"gallery_write"}
	file.store_string(JSON.stringify({"gallery_version":1,"payload":payload,"checksum":id}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return {"ok":false,"error":"gallery_flush"}
	var verified := _read_path(path + ".tmp", id)
	if not verified.get("ok", false): return verified
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK: return {"ok":false,"error":"gallery_promote"}
	return verified

func read_entry(id: String) -> Dictionary:
	if id.length() != 64 or not id.is_valid_hex_number(): return {"ok":false,"error":"gallery_id"}
	return _read_path(root_path.path_join(id + ".json"), id)

func list_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)): return entries
	for name in DirAccess.get_files_at(root_path):
		if not name.ends_with(".json"): continue
		var entry := read_entry(name.trim_suffix(".json"))
		if entry.get("ok", false): entries.append(entry)
	return entries

func _read_path(path: String, id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false,"error":"gallery_read"}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return {"ok":false,"error":"gallery_document"}
	var document: Dictionary = parser.data
	if document.get("gallery_version") != 1: return {"ok":false,"error":"gallery_version"}
	var payload: Variant = document.get("payload")
	if not payload is String or document.get("checksum") != id or payload.sha256_text() != id: return {"ok":false,"error":"gallery_checksum"}
	if parser.parse(payload) != OK or not parser.data is Dictionary: return {"ok":false,"error":"gallery_state"}
	var state := StateSnapshotValidator.new().normalize(parser.data)
	if not _completed(state): return {"ok":false,"error":"gallery_incomplete"}
	return {"ok":true,"id":id,"state":state,"branch":state["ending_run"]["branch_id"],"all_seen":state["ending_run"].get("all_ceremony_seen",false)}

func _completed(state: Dictionary) -> bool:
	if not StateSnapshotValidator.new().validate(state).get("ok", false): return false
	var run: Dictionary = state["ending_run"]
	var branch: String = run.get("branch_id", "")
	if not run.get("branch_committed", false) or branch not in ["reality", "stay"]: return false
	return ("EDR_FINAL_FRAME" if branch == "reality" else "EDS_FINAL_FRAME") in run.get("completed_nodes", [])
