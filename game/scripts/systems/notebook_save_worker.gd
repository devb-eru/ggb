extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func read_source(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		if DirAccess.dir_exists_absolute(path): return {"ok":false, "error_id":"ERR_SAVE_OPEN"}
		return {"ok":true, "stamp":"absent", "exists":false, "bytes":PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false, "error_id":"ERR_SAVE_OPEN"}
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	var error := file.get_error()
	file.close()
	if bytes.size() != length or error not in [OK, ERR_FILE_EOF]: return {"ok":false, "error_id":"ERR_SAVE_OPEN"}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return {"ok":true, "stamp":hash.finish().hex_encode(), "exists":true, "bytes":bytes}


func prepare(storage_script: Script, request: Dictionary) -> Dictionary:
	# This storage instance never joins the scene tree or receives live game/UI objects.
	var storage: Node = storage_script.new()
	storage._storage_context = request.storage.duplicate(true)
	var result := _prepare_with_storage(storage, request)
	storage.free()
	return result


func _prepare_with_storage(storage: Node, request: Dictionary) -> Dictionary:
	var paths: Dictionary = request.paths
	var sources := {}
	var stamps := {}
	for kind in ["main", "backup"]:
		var raw := read_source(paths[kind])
		if not raw.ok: return raw
		stamps[kind] = raw.stamp
		sources[kind] = storage._validate_save_text(raw.bytes.get_string_from_utf8(), paths[kind]) if raw.exists else {"ok":false, "error_id":"ERR_SAVE_NOT_FOUND"}
		if storage._is_incompatible(sources[kind]): return sources[kind]
	var source: Dictionary = sources.main if sources.main.ok else sources.backup
	if not source.ok: return {"ok":false, "error_id":"NB_COMMAND_SLOT_UNAVAILABLE"}
	var state: Dictionary = request.snapshot
	var archive: Dictionary = state.meta_progress.dialogue_history
	var storage_namespace := preload("res://scripts/systems/notebook_commands.gd").namespace_for(String(request.slot), String(request.storage.flavor), String(state.meta_progress.knowledge_entries.get("reselect_source_slot_id", "")))
	var scope := "%s:%s:%s:%s:%s:%d" % [storage_namespace, request.slot, source.header.get("run_id", ""), archive.get("source_origin_id", ""), archive.get("branch_id", ""), request.load_epoch]
	if scope != request.scope: return {"ok":false, "error_id":"NB_COMMAND_SCOPE"}
	var changed := ARCHIVE.set_reference(archive, request.collection, request.reference, request.enabled, int(archive.revision))
	if request.enabled and changed.get("error_id") == "NB_REFERENCE_UNAVAILABLE":
		var note := ARCHIVE.LEGACY_NOTES.find(state.meta_progress.knowledge_entries, archive.source_origin_id, request.reference)
		if not note.is_empty(): changed = ARCHIVE.capture_legacy_note_reference(archive, request.collection, note, int(archive.revision))
	if not changed.ok: return changed
	if not changed.changed: return {"ok":true, "changed":false, "source_stamps":stamps}
	state.meta_progress.dialogue_history = changed.archive
	var checked := StateSnapshotValidator.new().validate(state)
	if not checked.ok: return checked
	var point: String = source.header.get("save_point_id", "")
	var run_id: String = source.header.get("run_id", "")
	if run_id.is_empty(): run_id = ARCHIVE.new_uid()
	var transaction: String = "NOTEBOOK_META_" + request.id
	var header: Dictionary = storage._make_save_header(request.slot, point, request.revision + 1, transaction, run_id, storage.SCHEMA_VERSION)
	var encoded: Dictionary = storage._encode_payload(header, state)
	var file := FileAccess.open(paths.temporary, FileAccess.WRITE)
	if file == null: return {"ok":false, "error_id":"ERR_SAVE_TEMP_OPEN"}
	file.store_string(encoded.text)
	file.flush()
	file.close()
	var temp_source := read_source(paths.temporary)
	if not temp_source.ok: return temp_source
	var verified: Dictionary = storage._validate_save_text(temp_source.bytes.get_string_from_utf8(), paths.temporary)
	if not verified.ok or not StateSnapshotValidator.same_persisted_value(state, verified.snapshot):
		return {"ok":false, "error_id":"ERR_SAVE_TEMP_VERIFY"}
	for kind in sources: sources[kind].erase("snapshot")
	return {"ok":true, "changed":true, "snapshot":state, "sources":sources, "source_stamps":stamps,
		"temporary_stamp":temp_source.stamp, "summary":storage._summary_from_validated(verified),
		"point":point, "transaction":transaction, "checksum":encoded.checksum}


func prepare_history(storage_script: Script, request: Dictionary) -> Dictionary:
	var storage: Node = storage_script.new()
	storage._storage_context = request.storage.duplicate(true)
	var result := _prepare_history_with_storage(storage, request)
	storage.free()
	return result


func _prepare_history_with_storage(storage: Node, request: Dictionary) -> Dictionary:
	var state: Dictionary = request.snapshot
	var recording: Dictionary = request.recording
	var appended: Dictionary
	if recording.kind == "dialogue":
		appended = preload("res://scripts/systems/dialogue_history_writer.gd").append_to_snapshot(state,
			recording.speaker, recording.text, recording.locale, recording.chapter, recording.facts, recording.context)
	elif recording.kind == "prologue":
		var prepared := preload("res://scripts/systems/prologue_save_candidate.gd").prepare(state, recording.get("payload", {}))
		if not prepared.ok: return prepared
		state = prepared.snapshot
		appended = {"ok":true, "changed":true, "entry_uid":""}
	else:
		var cursor: Dictionary = recording.cursor
		var presentation := preload("res://scripts/systems/notebook_presentation.gd")
		if not presentation.matches(cursor, state) or not presentation.observed(cursor, state): return {"ok":false, "error_id":"NB_PRESENTATION_STALE"}
		presentation.install(state, cursor)
		appended = {"ok":true, "changed":true, "entry_uid":""}
	if not appended.ok: return appended
	var checked := StateSnapshotValidator.new().validate(state)
	if not checked.ok: return checked
	var paths: Dictionary = request.paths
	var sources := {}
	var stamps := {}
	for kind in ["main", "backup", "pending"]:
		var raw := read_source(paths[kind])
		if not raw.ok: return raw
		if raw.stamp != request.expected_stamps[kind]: return {"ok":false, "error_id":"NB_COMMAND_SOURCE_CHANGED"}
		stamps[kind] = raw.stamp
		var source: Dictionary = storage._validate_save_text(raw.bytes.get_string_from_utf8(), paths[kind]) if raw.exists else {"ok":false, "error_id":"ERR_SAVE_NOT_FOUND"}
		if storage._is_incompatible(source): return source
		if kind != "pending": sources[kind] = source
	if not appended.changed: return {"ok":true, "changed":false, "entry_uid":appended.entry_uid, "source_stamps":stamps}
	var run_id: String = sources.main.get("header", {}).get("run_id", "") if sources.main.ok else ""
	if run_id.is_empty(): run_id = ARCHIVE.new_uid()
	var schema: int = storage.SCHEMA_VERSION if state.meta_progress.dialogue_history.has("schema_version") else 1
	var header: Dictionary = storage._make_save_header(request.slot, request.point, request.revision + 1, request.transaction, run_id, schema)
	var encoded: Dictionary = storage._encode_payload(header, state)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(paths.main.get_base_dir())) != OK: return {"ok":false, "error_id":"ERR_SAVE_CREATE_DIRECTORY"}
	var file := FileAccess.open(paths.temporary, FileAccess.WRITE)
	if file == null: return {"ok":false, "error_id":"ERR_SAVE_TEMP_OPEN"}
	file.store_string(encoded.text)
	file.flush()
	file.close()
	var temporary := read_source(paths.temporary)
	if not temporary.ok: return temporary
	var verified: Dictionary = storage._validate_save_text(temporary.bytes.get_string_from_utf8(), paths.temporary)
	if not verified.ok or not StateSnapshotValidator.same_persisted_value(state, verified.snapshot): return {"ok":false, "error_id":"ERR_SAVE_TEMP_VERIFY"}
	for source in sources.values(): source.erase("snapshot")
	return {"ok":true, "changed":true, "snapshot":state, "entry_uid":appended.entry_uid, "sources":sources, "source_stamps":stamps,
		"temporary_stamp":temporary.stamp, "summary":storage._summary_from_validated(verified), "point":request.point,
		"transaction":request.transaction, "checksum":encoded.checksum}
