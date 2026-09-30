extends RefCounted


static func record(game: Node, saves: Node, slot: String, point: String, speaker: String, text: String, locale: String) -> Dictionary:
	if text.is_empty():
		return {"ok": true}
	var state: Dictionary = game.get_snapshot()
	var history: Dictionary = state["meta_progress"]["dialogue_history"]
	var sequence := int(history["next_sequence"])
	history["entries"].append({
		"sequence": sequence, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM",
		"variables": {"speaker": speaker, "text": text}, "viewed_locale": locale,
	})
	history["next_sequence"] = sequence + 1
	var transaction := StringName("HISTORY_R%06d" % (game.revision + 1))
	var installed: Dictionary = StateWriter.new(game).install_snapshot(state, game.revision, transaction)
	if not installed.get("ok", false):
		return installed
	var saved: Dictionary = saves.save_snapshot(slot, point, game.get_snapshot(), game.revision, String(transaction))
	if not saved.get("ok", false):
		game.rollback_failed_persistence(installed["previous_snapshot"], int(installed["revision"]), transaction, &"ERR_DIALOGUE_HISTORY_SAVE")
	return saved
