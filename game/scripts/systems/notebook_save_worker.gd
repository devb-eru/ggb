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
	elif recording.kind == "reset":
		var prepared := ResetCoordinator.prepare_step(state, recording.get("payload", {}))
		if not prepared.ok: return prepared
		state = prepared.snapshot
		request.point = ResetCoordinator.save_point_for(prepared.reset_type, prepared.phase)
		request.transaction = "%s_%s_R%06d_%s" % [prepared.reset_transaction_id, prepared.phase.to_upper(), request.revision + 1, request.id]
		appended = {"ok":true, "changed":true, "entry_uid":""}
	elif recording.kind == "wake":
		var prepared := _prepare_wake(state, recording.get("payload", {}))
		if not prepared.ok: return prepared
		state = prepared.snapshot
		request.transaction = "WAKE_R%06d_%s" % [request.revision + 1, request.id]
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


func _prepare_wake(previous: Dictionary, payload: Dictionary) -> Dictionary:
	if payload.get("family") not in ["chapter_one_session", "black_mirror_session", "basement_session"] or not payload.get("snapshot") is Dictionary:
		return {"ok":false, "error_id":"NB_WAKE_REQUEST"}
	if previous.reset_state.phase != "idle" or payload.get("reset_transaction_id") != previous.reset_state.last_completed_transaction_id:
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	var candidate: Dictionary = payload.snapshot
	if not candidate.get("meta_progress") is Dictionary or not candidate.get("loop_state") is Dictionary \
		or not _unchanged_outside(previous, candidate, ["meta_progress", "loop_state"]) \
		or not _unchanged_outside(previous.meta_progress, candidate.meta_progress, ["knowledge_entries", "dialogue_history"]) \
		or not _unchanged_outside(previous.loop_state, candidate.loop_state, ["location_id", "inventory", "event_local_states"]):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	var checked := StateSnapshotValidator.new().validate(candidate)
	if not checked.ok: return checked
	var old_knowledge: Dictionary = previous.meta_progress.knowledge_entries
	var new_knowledge: Dictionary = candidate.meta_progress.knowledge_entries
	if not _unchanged_outside(old_knowledge, new_knowledge, ["j2_restored_day", "j3_restored_day", "E1_wake_seen", "D6_rest_route", "chapter_notebook", "notebook_knowledge"]) \
		or not _unchanged_outside(old_knowledge.get("chapter_notebook", {}), new_knowledge.get("chapter_notebook", {}), ["NOTE_E1_WAKE"]):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	for key in ["j2_restored_day", "j3_restored_day"]:
		if old_knowledge.has(key):
			if new_knowledge.get(key) != old_knowledge[key]: return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		elif new_knowledge.has(key) and new_knowledge[key] != previous.loop_state.day_index: return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	if new_knowledge.has("D6_rest_route") and (not old_knowledge.has("D6_rest_route") or new_knowledge.D6_rest_route != old_knowledge.D6_rest_route):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	if old_knowledge.has("D6_rest_route") and not new_knowledge.has("D6_rest_route") and payload.family != "basement_session":
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	var first_broken_wake: bool = payload.family == "basement_session" and previous.fracture_state.broken_reset_triggered and not old_knowledge.get("E1_wake_seen", false)
	if not first_broken_wake and (old_knowledge.get("E1_wake_seen") != new_knowledge.get("E1_wake_seen") \
		or old_knowledge.get("chapter_notebook", {}).get("NOTE_E1_WAKE") != new_knowledge.get("chapter_notebook", {}).get("NOTE_E1_WAKE")):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	if first_broken_wake and (new_knowledge.get("E1_wake_seen") != true \
		or new_knowledge.get("chapter_notebook", {}).get("NOTE_E1_WAKE") != preload("res://scripts/systems/fracture_notebook.gd").NOTES.E1_WAKE):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	var old: Dictionary = previous.meta_progress.dialogue_history
	var next: Dictionary = candidate.meta_progress.dialogue_history
	if old.has("schema_version"):
		if not _unchanged_outside(old, next, ["revision", "next_sequence", "entries", "source_links"]): return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		var old_ledger: Dictionary = old_knowledge.get("notebook_knowledge", preload("res://scripts/systems/notebook_knowledge.gd").create())
		var new_ledger: Dictionary = new_knowledge.get("notebook_knowledge", preload("res://scripts/systems/notebook_knowledge.gd").create())
		var revisions: Array = old_ledger.get("revisions", [])
		var new_revisions: Array = new_ledger.get("revisions", [])
		if not _unchanged_outside(old_ledger, new_ledger, ["revision", "revisions"]) or new_revisions.size() != revisions.size() + (1 if first_broken_wake else 0):
			return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		for index in range(revisions.size()):
			if not StateSnapshotValidator.same_persisted_value(revisions[index], new_revisions[index]): return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		if next.source_links.size() < old.source_links.size(): return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		for index in range(old.source_links.size()):
			if not StateSnapshotValidator.same_persisted_value(old.source_links[index], next.source_links[index]): return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		var rows := {}
		for entry in next.entries: rows[entry.entry_uid] = entry
		var originals := {}
		var eligible: Array = []
		for entry in old.entries:
			originals[entry.entry_uid] = true
			if entry.record_class == "authored" and ARCHIVE._reasons(next, entry).is_empty(): eligible.append(entry.entry_uid)
		var expected_pruned: Array = eligible.slice(0, maxi(eligible.size() - ARCHIVE.NORMAL_LIMIT, 0))
		var added := 0
		for entry in next.entries:
			if originals.has(entry.entry_uid): continue
			if not first_broken_wake or entry.record_class != "authored" or entry.observation.content_id != "NB_FRACTURE_NOTE_E1_WAKE": return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
			added += 1
		if added != (1 if first_broken_wake else 0): return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
		for entry in old.entries:
			if not rows.has(entry.entry_uid):
				if entry.entry_uid not in expected_pruned: return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
			elif entry.entry_uid in expected_pruned: return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
			elif not _unchanged_outside(entry, rows[entry.entry_uid], ["protection_reasons", "session_pruned"]):
				return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	elif not StateSnapshotValidator.same_persisted_value(old, next):
		return {"ok":false, "error_id":"NB_WAKE_SCOPE"}
	return {"ok":true, "snapshot":candidate}


func _unchanged_outside(previous: Dictionary, next: Dictionary, allowed: Array) -> bool:
	for key in previous:
		if key not in allowed and (not next.has(key) or not StateSnapshotValidator.same_persisted_value(previous[key], next[key])): return false
	for key in next:
		if key not in allowed and not previous.has(key): return false
	return true
