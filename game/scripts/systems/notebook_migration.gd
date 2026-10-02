extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const FACTS := preload("res://scripts/systems/dialogue_observed_facts.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const WAKE_TEXTS := preload("res://scripts/ui/reality_wake_texts.gd")


static func adapt_verified(source: Dictionary, digest: String, promote_legacy: bool = true) -> Dictionary:
	var state := StateSnapshotValidator.new().normalize(source)
	var checked := StateSnapshotValidator.new().validate(state)
	if not checked.ok: return checked
	var history: Dictionary = state.meta_progress.dialogue_history
	if history.has("schema_version") or not promote_legacy:
		return {"ok": true, "snapshot": state, "migrated": false}
	var migrated := ARCHIVE.migrate_verified_legacy(history, digest)
	if not migrated.ok: return migrated
	# Extract only explicit legacy evidence, before any future normal-record pruning.
	var facts: Dictionary = state.meta_progress.knowledge_entries.get(FACTS.KNOWLEDGE_KEY, {}).duplicate(true)
	for object_id in FACTS.BODY_IDS:
		if object_id not in state.ending_run.get("required_interactions_seen", []): continue
		var known: Array = [WAKE.BODY[object_id][2], WAKE_TEXTS.body(object_id, "en")[2]]
		for entry in history.entries:
			if entry.get("line_id") == "CH1_HISTORY_TRANSCRIPT" and entry.get("variables", {}).get("text") in known:
				facts[FACTS.body_repeat_id(object_id)] = true
				break
	if not facts.is_empty(): state.meta_progress.knowledge_entries[FACTS.KNOWLEDGE_KEY] = facts
	state.meta_progress.dialogue_history = migrated.archive
	checked = StateSnapshotValidator.new().validate(state)
	return {"ok": true, "snapshot": state, "migrated": true} if checked.ok else checked
