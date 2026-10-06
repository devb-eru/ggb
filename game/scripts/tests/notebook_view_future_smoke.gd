extends RefCounted

const STORE := preload("res://scripts/systems/notebook_view_store.gd")
var checks := 0
var errors := PackedStringArray()

func run() -> Dictionary:
	var root := "user://__test_view_future_%d" % Time.get_ticks_usec()
	var store := STORE.new(root)
	var scope := {"profile": "local", "namespace": "test", "slot": "future", "run_id": "view", "source_origin_id": "origin", "branch_id": "branch"}
	var frontier := {"archive_revision": 0, "next_sequence": 0, "last_uid": "", "knowledge_revision": 0, "legacy_digest": ""}
	var state := STORE.empty_state()
	var paths: Dictionary = store.paths(scope)
	for target in ["main", "backup", "temporary"]:
		for primary in ["valid", "missing", "damaged"]:
			for path in paths.values():
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
			_expect(store.save_view(scope, frontier, state).ok, "seed " + target + "/" + primary)
			if primary == "missing": DirAccess.remove_absolute(paths.main)
			elif primary == "damaged": _write(paths.main, "damaged")
			_write(paths[target], JSON.stringify({"version": STORE.VERSION + 1}))
			var before := _bytes(paths)
			var loaded: Dictionary = store.load_view(scope, frontier)
			_expect(not loaded.writable and loaded.warning_id == "NB_VIEW_FUTURE" and loaded.state == state, "read-only default " + target + "/" + primary)
			var saved: Dictionary = store.save_view(scope, frontier, state)
			_expect(not saved.ok and saved.get("error_id") == "NB_VIEW_FUTURE", "reject write " + target + "/" + primary)
			_expect(_bytes(paths) == before, "preserve every candidate " + target + "/" + primary)
	for path in paths.values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	_expect(store.save_view(scope, frontier, state).ok, "current seed")
	var committed := FileAccess.get_file_as_bytes(paths.main)
	_write(paths.temporary, FileAccess.get_file_as_string(paths.main))
	_expect(store.load_view(scope, frontier).source == "primary", "current uncommitted temporary is not adopted")
	DirAccess.remove_absolute(paths.main)
	_expect(store.load_view(scope, frontier).source == "default", "temporary-only valid payload cannot become committed preferences")
	_expect(store.save_view(scope, frontier, state).ok and FileAccess.get_file_as_bytes(paths.main) == committed, "current temporary may be replaced by verified convenience state")
	for path in paths.values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(root)
	print("NOTEBOOK_VIEW_FUTURE_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}

func _bytes(paths: Dictionary) -> Dictionary:
	var result := {}
	for key in paths:
		if FileAccess.file_exists(paths[key]): result[key] = FileAccess.get_file_as_bytes(paths[key])
	return result

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "fixture write")
	if file != null:
		file.store_string(text)
		file.close()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_VIEW_FUTURE_FAIL: " + message)
