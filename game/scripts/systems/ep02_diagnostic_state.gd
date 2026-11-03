extends RefCounted

const FACTS := {"BODY": "KN_C5_SUBJECT_BODY_EXISTS", "PERSONALITY": "KN_C5_PERSONALITY_CHANNEL_COUNT", "EXTERNAL": "KN_C5_EXTERNAL_BELOW_THRESHOLD", "WAKE": "KN_C5_WAKE_AUTHORITY_LOCKED", "MASK": "KN_C5_WORLD_MASK_DEGRADED"}


static func seen(state: Dictionary, key: String) -> bool:
	var local: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
	if key in local.get("diagnostics_scanned", []) or key in local.get("channels_scanned", []) or (key == "SUBJECT" and local.get("subject_scanned", false)): return true
	var known: Dictionary = state.meta_progress.knowledge_entries
	var stored: Variant = known.get("c5_inspections", [])
	if stored is Array and key in stored: return true
	if FACTS.has(key) and known.get(FACTS[key], false) == true: return true
	var ids := ["NB_EP02_C5_HOT_%s_FIRST" % key, "NB_EP02_C5_HOT_%s_REPEAT" % key, "NB_EP02_C5_CH_%s_FIRST" % key, "NB_EP02_C5_CH_%s_REPEAT" % key, "NB_MIRROR_SCAN_SURFACE_" + key, "NB_MIRROR_SCAN_COPY_" + key]
	if key == "SUBJECT": ids.append("NB_EP02_C5_HOT_SUBJECT_CHANNEL")
	for entry in state.meta_progress.dialogue_history.get("entries", []):
		if entry.get("record_class") == "authored" and entry.get("observation", {}).get("content_id") in ids: return true
	return false


static func remember(state: Dictionary, key: String) -> void:
	var stored: Variant = state.meta_progress.knowledge_entries.get("c5_inspections", [])
	var inspections: Array = stored.duplicate() if stored is Array else []
	if key not in inspections: inspections.append(key)
	state.meta_progress.knowledge_entries["c5_inspections"] = inspections


static func required_count(state: Dictionary) -> int:
	return int(seen(state, "BODY")) + int(seen(state, "PERSONALITY"))
