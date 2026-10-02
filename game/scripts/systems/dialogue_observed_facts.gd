extends RefCounted

const KNOWLEDGE_KEY := "dialogue_observed_facts"
const BODY_IDS := ["OBJ_REALITY_HAND", "OBJ_REALITY_BREATH_MONITOR", "OBJ_REALITY_RESTRAINT"]


static func valid_facts(value: Variant) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not id is String or not id.begins_with("BODY_REPEAT:") or id.trim_prefix("BODY_REPEAT:") not in BODY_IDS: return false
		if typeof(value[id]) != TYPE_BOOL or not value[id]: return false
	return true


static func body_repeat_id(object_id: String) -> String:
	return "BODY_REPEAT:" + object_id if object_id in BODY_IDS else ""


static func capture(state: Dictionary, ids: Variant) -> Dictionary:
	if not ids is Array: return {"ok": false, "error_ids": ["ERR_DIALOGUE_FACTS_TYPE"]}
	var run: Dictionary = state.get("ending_run", {})
	for id in ids:
		if not id is String or not id.begins_with("BODY_REPEAT:") or id.trim_prefix("BODY_REPEAT:") not in BODY_IDS:
			return {"ok": false, "error_ids": ["ERR_DIALOGUE_FACT_ID"]}
		if run.get("branch_id") != "reality" or run.get("current_node_id") != "EDR_BODY_CHECK" or id.trim_prefix("BODY_REPEAT:") not in run.get("required_interactions_seen", []):
			return {"ok": false, "error_ids": ["ERR_DIALOGUE_FACT_CONTEXT"]}
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	var facts: Variant = knowledge.get(KNOWLEDGE_KEY, {})
	if not valid_facts(facts): return {"ok": false, "error_ids": ["ERR_DIALOGUE_FACTS_TYPE"]}
	if not ids.is_empty():
		facts = facts.duplicate(true)
		for id in ids: facts[id] = true
		knowledge[KNOWLEDGE_KEY] = facts
	return {"ok": true}


static func has_body_repeat(state: Dictionary, object_id: String) -> bool:
	var facts: Variant = state.get("meta_progress", {}).get("knowledge_entries", {}).get(KNOWLEDGE_KEY, {})
	return object_id in BODY_IDS and facts is Dictionary and facts.get(body_repeat_id(object_id)) == true
