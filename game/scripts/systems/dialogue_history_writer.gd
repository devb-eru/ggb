extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func record(game: Node, saves: Node, slot: String, point: String, speaker: String, text: String, locale: String, chapter_id: String = "LEGACY", observed_fact_ids: Variant = [], context: Dictionary = {}) -> Dictionary:
	if text.is_empty():
		return {"ok": true}
	var state: Dictionary = game.get_snapshot()
	var facts := preload("res://scripts/systems/dialogue_observed_facts.gd").capture(state, observed_fact_ids)
	if not facts.ok:
		return facts
	var history: Dictionary = state["meta_progress"]["dialogue_history"]
	var payload := {
		"chapter_id": chapter_id, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM",
		"variables": {"speaker": speaker, "text": text}, "viewed_locale": locale,
	}
	var entry_uid := ""
	if history.has("schema_version"):
		var frozen := context.duplicate(true)
		if not frozen.has("presentation_token"): frozen.presentation_token = ARCHIVE.new_uid()
		var appended: Dictionary
		if frozen.has("notebook_content"):
			var observed := preload("res://scripts/systems/notebook_content.gd").observe(frozen.notebook_content, frozen, speaker, text, locale)
			if not observed.ok: return observed
			appended = ARCHIVE.append_observation(history, observed.observation, int(history.revision))
		else:
			appended = ARCHIVE.append_unmapped(history, payload, frozen, int(history.revision))
		if not appended.ok: return appended
		if not appended.changed: return {"ok": true, "entry_uid": appended.entry_uid}
		state.meta_progress.dialogue_history = appended.archive
		entry_uid = appended.entry_uid
	else:
		payload.sequence = int(history.next_sequence)
		history.entries.append(payload)
		history.next_sequence = int(history.next_sequence) + 1
	var transaction := StringName("HISTORY_R%06d" % (game.revision + 1))
	var installed: Dictionary = StateWriter.new(game).install_snapshot(state, game.revision, transaction)
	if not installed.get("ok", false):
		return installed
	var saved: Dictionary = saves.save_snapshot(slot, point, game.get_snapshot(), game.revision, String(transaction))
	if not saved.get("ok", false):
		if saves.has_method("confirm_snapshot_commit"):
			var confirmed: Dictionary = saves.confirm_snapshot_commit(slot, String(transaction))
			if confirmed.get("ok", false) and StateSnapshotValidator.same_persisted_value(state, confirmed.snapshot):
				return {"ok": true, "entry_uid": entry_uid, "recovered_acknowledgement": true}
		game.rollback_failed_persistence(installed["previous_snapshot"], int(installed["revision"]), transaction, &"ERR_DIALOGUE_HISTORY_SAVE")
	else:
		saved["entry_uid"] = entry_uid
	return saved
