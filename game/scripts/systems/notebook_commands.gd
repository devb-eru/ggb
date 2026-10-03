extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func scope(game: Node, saves: Node, slot: String) -> String:
	var archive: Dictionary = game.get_value(&"meta_progress.dialogue_history", {})
	var scope_namespace := "development" if slot.begins_with("__dev_") else String(saves.get_build_flavor())
	var run_id := String(saves.inspect_slot(slot).get("run_id", ""))
	return "%s:%s:%s:%s:%s:%d" % [scope_namespace, slot, run_id, archive.get("source_origin_id", ""), archive.get("branch_id", ""), game.load_epoch]


static func set_reference(game: Node, saves: Node, slot: String, collection: String, reference: Dictionary, enabled: bool, expected_scope: String, expected_revision: int, command_id: String) -> Dictionary:
	if expected_scope != scope(game, saves, slot): return _error("NB_COMMAND_SCOPE")
	if expected_revision != game.revision: return _error("NB_COMMAND_STALE_REVISION")
	if command_id.length() != 32 or not command_id.is_valid_hex_number(): return _error("NB_COMMAND_ID")
	var summary: Dictionary = saves.inspect_slot(slot)
	if not summary.get("available", false): return _error("NB_COMMAND_SLOT_UNAVAILABLE")
	var state: Dictionary = game.get_snapshot()
	var archive: Dictionary = state.meta_progress.dialogue_history
	var changed := ARCHIVE.set_reference(archive, collection, reference, enabled, int(archive.revision))
	if enabled and changed.get("error_id") == "NB_REFERENCE_UNAVAILABLE":
		var note := ARCHIVE.LEGACY_NOTES.find(state.meta_progress.knowledge_entries, archive.source_origin_id, reference)
		if not note.is_empty(): changed = ARCHIVE.capture_legacy_note_reference(archive, collection, note, int(archive.revision))
	if not changed.ok: return changed
	if not changed.changed: return {"ok": true, "changed": false}
	state.meta_progress.dialogue_history = changed.archive
	var transaction := StringName("NOTEBOOK_META_" + command_id)
	var installed := StateWriter.new(game).install_snapshot(state, expected_revision, transaction)
	if not installed.ok: return installed
	var point := String(summary.save_point_id)
	var saved: Dictionary = saves.save_snapshot(slot, point, game.get_snapshot(), game.revision, String(transaction))
	if not saved.get("ok", false):
		if saves.has_method("confirm_snapshot_commit"):
			var confirmed: Dictionary = saves.confirm_snapshot_commit(slot, String(transaction))
			if confirmed.get("ok", false) and StateSnapshotValidator.same_persisted_value(state, confirmed.snapshot):
				return {"ok": true, "changed": true, "recovered_acknowledgement": true}
		game.rollback_failed_persistence(installed.previous_snapshot, int(installed.revision), transaction, &"ERR_NOTEBOOK_METADATA_SAVE")
		return saved
	return {"ok": true, "changed": true}


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id, "error_ids": [id]}
