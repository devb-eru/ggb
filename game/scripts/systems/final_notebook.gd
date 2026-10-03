extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_FINAL_"
const QUESTIONS := ["consent", "awakening", "outside", "release", "wish"]


static func paragraphs(keys: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		var id: String = PREFIX + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: {}}))
	return result


static func write(state: Dictionary, keys: Array, context: Dictionary, locale: String) -> Dictionary:
	if "J5_WRITE" not in keys: return {"ok": true}
	# The event writes this document; merely playing F1 or opening J5 does not acquire it.
	var original: String = state.meta_progress.knowledge_entries.chapter_notebook.J5
	return EVENT_NOTES.write(state, PREFIX + "J5_RECORD", original, context, locale)
