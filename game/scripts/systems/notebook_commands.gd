extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func scope(game: Node, saves: Node, slot: String) -> String:
	return _scope_from_summary(game, saves, slot, saves.inspect_slot(slot))


static func scope_namespace(game: Node, saves: Node, slot: String) -> String:
	var source := String(game.get_value("meta_progress.knowledge_entries.reselect_source_slot_id", ""))
	return namespace_for(slot, saves.get_build_flavor(), source)


static func namespace_for(slot: String, flavor: String, source: String) -> String:
	if slot.begins_with("__dev_") or (OS.is_debug_build() and source.begins_with("__dev_checkpoint")):
		return "development"
	return flavor


static func _scope_from_summary(game: Node, saves: Node, slot: String, summary: Dictionary) -> String:
	var archive: Dictionary = game.get_value(&"meta_progress.dialogue_history", {})
	var namespace_id := scope_namespace(game, saves, slot)
	var run_id := String(summary.get("run_id", ""))
	return "%s:%s:%s:%s:%s:%d" % [namespace_id, slot, run_id, archive.get("source_origin_id", ""), archive.get("branch_id", ""), game.load_epoch]


static func set_reference(game: Node, saves: Node, slot: String, collection: String, reference: Dictionary, enabled: bool, expected_scope: String, expected_revision: int, command_id: String) -> Dictionary:
	var summary: Dictionary = saves.inspect_slot(slot)
	if expected_scope != _scope_from_summary(game, saves, slot, summary): return _error("NB_COMMAND_SCOPE")
	if expected_revision != game.revision: return _error("NB_COMMAND_STALE_REVISION")
	if command_id.length() != 32 or not command_id.is_valid_hex_number(): return _error("NB_COMMAND_ID")
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
