extends Node

const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const STORE := preload("res://scripts/systems/ending_gallery_store.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
var errors: Array[String] = []
var cases: Array = []
var checks := 0
var serial := 0
var game: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	game = get_tree().root.get_node("GameState")
	_expect("--ggb-dev-notebook-v2" in OS.get_cmdline_user_args(), "explicit development rollout")
	_expect("--notebook-require-authored" in OS.get_cmdline_user_args(), "explicit strict writer")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for branch in ["REALITY", "STAY"]:
			var loaded := CHECKPOINTS.new().snapshot_for("CREDITS_" + branch)
			if not _expect(loaded.get("ok", false), "valid completed fixture " + branch): continue
			print("GALLERY_FUTURE_PHASE: ", locale, " ", branch)
			for version in [2, 999, "future", "1", true, false, null, [1], {"value": 1}, 1.5]:
				for candidate in ["main", "temporary"]:
					for action in ["read", "list", "capture"]:
						_case(loaded.snapshot, locale, branch, version, candidate, action)
			for checksum in [1, true, false, null, [1], {"value": 1}]:
				for action in ["read", "list", "capture"]:
					_case(loaded.snapshot, locale, branch, checksum, "main", action, "checksum")
			for kind in ["fresh", "current_temporary", "damaged_temporary"]:
				_control(loaded.snapshot, locale, branch, kind)
	_expect(cases.size() == 324, "independent 240 unsupported + 72 checksum + 12 current-format cases")
	var result := {
		"schema_version": 1, "suite_id": "gallery-future", "ok": errors.is_empty(),
		"engine_version": Engine.get_version_info().string,
		"harness_sha256": FileAccess.get_sha256(get_script().resource_path),
		"store_sha256": FileAccess.get_sha256("res://scripts/systems/ending_gallery_store.gd"),
		"checkpoint_sha256": FileAccess.get_sha256(CHECKPOINTS.DATA),
		"source_corpus": preload("res://scripts/tests/notebook_runtime_audit.gd").new()._source_corpus(),
		"required_cases": 324, "checks": checks, "cases": cases, "errors": errors,
		"not_covered": ["OS_power_loss", "concurrent_external_writer", "disk_full", "all_NP22_consumers", "all_producers", "actual_game_input"],
	}
	print("NOTEBOOK_GALLERY_FUTURE_AUDIT: " + JSON.stringify(result))
	print("NOTEBOOK_GALLERY_FUTURE_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
	get_tree().quit(0 if errors.is_empty() else 1)


func _prepared(source: Dictionary) -> Dictionary:
	serial += 1
	var store := STORE.new("user://__test_gallery_future_%d" % serial)
	var captured := store.capture(source)
	if not _expect(captured.get("ok", false), "prepare valid gallery capture"): return {}
	var path: String = store.root_path.path_join(captured.id + ".json")
	var bytes := FileAccess.get_file_as_bytes(path)
	var document: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "remove own seed capture only")
	_write(store.root_path.path_join("unrelated.txt"), "unrelated artifact; never replace")
	return {"store": store, "id": captured.id, "path": path, "document": document, "bytes": bytes}


func _case(source: Dictionary, locale: String, branch: String, version: Variant, candidate: String, action: String, field: String = "gallery_version") -> void:
	var prepared := _prepared(source)
	if prepared.is_empty(): return
	var store: EndingGalleryStore = prepared.store
	var document: Dictionary = prepared.document.duplicate(true)
	document[field] = version
	var target: String = prepared.path + (".tmp" if candidate == "temporary" else "")
	_write(target, JSON.stringify(document, "\t"))
	var before := _files(store.root_path)
	var state_before: Dictionary = game.get_snapshot()
	var source_before := source.duplicate(true)
	var key := "%s/%s/%s/%s/%s/%s" % [locale, branch, field, str(version), candidate, action]
	var start_errors := errors.size()
	var result: Dictionary = {}
	if action == "read":
		result = store.read_entry(prepared.id)
		_expect(not result.get("ok", false), "unsupported original not adopted " + key)
	elif action == "list":
		var listed := store.list_entries()
		result = {"ok": listed.is_empty(), "listed_count": listed.size()}
		_expect(listed.is_empty(), "unsupported/temporary capture not listed " + key)
	else:
		result = store.capture(source)
		_expect(not result.get("ok", false), "unsupported original blocks capture " + key)
	if action == "capture" or (action == "read" and candidate == "main"):
		_expect(result.get("error", "") == ("gallery_version" if field == "gallery_version" else "gallery_checksum"), "invalid header returns a typed error, not an aborted function " + key)
	var after := _files(store.root_path)
	_expect(before == after, "original names and bytes preserved " + key)
	_expect(game.get_snapshot() == state_before and source == source_before, "consumer does not mutate live/caller state " + key)
	cases.append({"key": key, "kind": "unsupported" if field == "gallery_version" else "checksum", "field": field, "version": version, "candidate": candidate, "action": action,
		"passed": errors.size() == start_errors, "result": result.get("error", ""), "before_files": before, "after_files": after})


func _control(source: Dictionary, locale: String, branch: String, kind: String) -> void:
	var prepared := _prepared(source)
	if prepared.is_empty(): return
	var store: EndingGalleryStore = prepared.store
	if kind == "current_temporary": _write(prepared.path + ".tmp", JSON.stringify(prepared.document, "\t"))
	elif kind == "damaged_temporary": _write(prepared.path + ".tmp", "{invalid interrupted current write")
	var before_state: Dictionary = game.get_snapshot()
	var original := source.duplicate(true)
	var key := "%s/%s/%s" % [locale, branch, kind]
	var start_errors := errors.size()
	_expect(not store.read_entry(prepared.id).get("ok", false) and store.list_entries().is_empty(), "uncommitted candidate is not a read source " + key)
	var captured := store.capture(source)
	_expect(captured.get("ok", false) and captured.get("id", "") == prepared.id, "current-format write remains available " + key)
	var before := _files(store.root_path)
	var reread := store.read_entry(prepared.id)
	var repeated := store.capture(source)
	_expect(reread.get("ok", false) and repeated.get("ok", false), "committed capture reads and repeats " + key)
	_expect(store.list_entries().size() == 1 and _files(store.root_path) == before, "repeat capture preserves exact committed bytes " + key)
	_expect(FileAccess.get_file_as_string(store.root_path.path_join("unrelated.txt")) == "unrelated artifact; never replace", "unrelated bytes preserved " + key)
	_expect(source == original and game.get_snapshot() == before_state, "current consumer caller/live state immutable " + key)
	_expect(not captured.get("state", {}).get("meta_progress", {}).get("dialogue_history", {}).get("entries", []).is_empty(), "capture retained observed source records " + key)
	_expect(ARCHIVE.validate(captured.state.meta_progress.dialogue_history).get("ok", false), "source archive retained without new observations " + key)
	_expect(captured.state.meta_progress.dialogue_history == source.meta_progress.dialogue_history, "captured source observations unchanged " + key)
	cases.append({"key": key, "kind": kind, "passed": errors.size() == start_errors, "files": before})


func _files(path: String) -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at(path): result[name] = FileAccess.get_sha256(path.path_join(name))
	return result


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "test fixture writable"): return
	file.store_string(text)
	file.flush()
	_expect(file.get_error() == OK, "test fixture write flushed")
	file.close()


func _expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		errors.append(message)
		print("GALLERY_FUTURE_ASSERT: ", message)
	return condition
