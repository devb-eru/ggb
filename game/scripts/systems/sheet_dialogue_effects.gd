extends RefCounted

const RECEIPTS := "EP02_DIALOGUE_EFFECTS"

static func apply(state: Dictionary, ids: Array) -> Dictionary:
	var history: Dictionary = state.meta_progress.event_history
	var receipts: Dictionary = history.get(RECEIPTS, {}).duplicate(true)
	var source := preload("res://scripts/systems/ep01_script.gd").source("EP02")
	for row in source.get("nodes", []):
		if row.node_id not in ids: continue
		for raw_key in String(row.knowledge_id).split(";", false):
			var key := raw_key.strip_edges()
			if key.begins_with("KN_") and not key.contains("*") and not state.meta_progress.knowledge_entries.has(key) and _verified_fact(state, key):
				state.meta_progress.knowledge_entries[key] = true
	for effect in source.get("effects", []):
		if effect.node_id not in ids or receipts.has(effect.effect_id): continue
		var path: String = effect.state_path
		if effect.effect_id == "EFF_EP02_0033":
			var mirror: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
			if not mirror.get("surface_open", false) and not state.meta_progress.knowledge_entries.get("mirror_tracing_acquired", false): continue
			if state.meta_progress.failure_knowledge.has("C4"): state.meta_progress.failure_knowledge.C4.status = "resolved"
			receipts[effect.effect_id] = true
			continue
		if path == "meta_progress.knowledge_entries" and effect.operation == "add":
			var entries: Variant = JSON.parse_string(effect.typed_value)
			if not entries is Dictionary: return {"ok": false, "error_id": "SHEET_EFFECT_KNOWLEDGE"}
			for key in entries:
				if key in ["KN_C2_*", "KN_C21_*"]: continue
				if key not in ["KN_C3_RATIO", "KN_C4_OVERLAY", "KN_C4_ROUTE", "KN_J3_MAP_REQUIRED"]: return {"ok": false, "error_id": "SHEET_EFFECT_KNOWLEDGE_KEY"}
				if _verified_fact(state, key): state.meta_progress.knowledge_entries[key] = true
			continue
		if path == "meta_progress.event_history" and effect.operation == "add":
			var entries: Variant = JSON.parse_string(effect.typed_value)
			if not entries is Dictionary: return {"ok": false, "error_id": "SHEET_EFFECT_HISTORY"}
			if effect.effect_id == "EFF_EP02_0045":
				var season := ""
				for index in range(4):
					if "EP02_IRIS_S2_CH%02d" % (index + 1) in ids: season = ["spring", "summer", "autumn", "winter"][index]
				if season.is_empty(): return {"ok": false, "error_id": "SHEET_EFFECT_SEASON_CHOICE"}
				state.meta_progress["iris_season_image"] = season
				entries[effect.node_id] = {"iris_season_image": season}
			elif effect.effect_id == "EFF_EP02_0038":
				state.meta_progress.knowledge_entries["mara2_archive_index_known"] = true
			elif effect.effect_id == "EFF_EP02_0046" and state.meta_progress.knowledge_entries.get("MEM_FATHER_TEA_HAND_FRAGMENT") == "sensory_fragment":
				state.meta_progress.knowledge_entries["MEM_FATHER_DRAWN_DOOR_FRAGMENT"] = "episodic_fragment"
			history.merge(entries, true)
			receipts[effect.effect_id] = true
			continue
		# Physical puzzle transitions remain owned by BlackMirrorSession.
		if not path.begins_with("meta_progress.servants."): continue
		var parts := path.split(".")
		if parts.size() != 4 or not state.meta_progress.servants.has(parts[2]):
			return {"ok": false, "error_id": "SHEET_EFFECT_PATH"}
		if effect.repeat_policy != "once": return {"ok": false, "error_id": "SHEET_EFFECT_REPEAT"}
		var servant: Dictionary = state.meta_progress.servants[parts[2]]
		if parts[3] in ["bond", "alert"] and effect.operation == "increment":
			if not String(effect.typed_value).is_valid_int(): return {"ok": false, "error_id": "SHEET_EFFECT_INTEGER"}
			servant[parts[3]] = clampi(int(servant[parts[3]]) + int(effect.typed_value), 0, 5)
		elif parts[3] == "residual_memory" and effect.operation == "add" and effect.value_type == "string":
			if effect.typed_value not in servant.residual_memory: servant.residual_memory.append(effect.typed_value)
		else:
			return {"ok": false, "error_id": "SHEET_EFFECT_OPERATION"}
		receipts[effect.effect_id] = true
	if not receipts.is_empty(): history[RECEIPTS] = receipts
	return {"ok": true}


static func _verified_fact(state: Dictionary, key: String) -> bool:
	var known: Dictionary = state.meta_progress.knowledge_entries
	var local: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
	match key:
		"KN_C3_RATIO": return known.get("c3_ratio_reviewed", false) or known.get("c3_formula_verified", false)
		"KN_C4_ROUTE": return local.get("dry_passed", false) or known.has("mirror_verified_plan")
		"KN_C4_OVERLAY":
			if known.has("mirror_verified_plan"): return true
			var verdict: Dictionary = preload("res://data/puzzles/puzzle_black_mirror.tres").inspect_trace(int(local.get("rotation", 0)), bool(local.get("flipped", false)), bool(local.get("anchored", false)), [])
			return verdict.category != "anchor_missing"
		"KN_J3_MAP_REQUIRED": return int(state.meta_progress.journal_stage) >= 3
	return true

static func event_seen(state: Dictionary, event_id: String) -> bool:
	var receipts: Dictionary = state.meta_progress.event_history.get(RECEIPTS, {})
	for effect in preload("res://scripts/systems/ep01_script.gd").source("EP02").get("effects", []):
		if effect.event_id == event_id and receipts.has(effect.effect_id): return true
	return false


static func j3_memory_seen(state: Dictionary) -> bool:
	if state.meta_progress.event_history.get(RECEIPTS, {}).get("EFF_EP02_0046", false): return true
	return state.meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("record_class") == "authored" and entry.get("observation", {}).get("content_id") == "NB_EP02_J3_MEMORY_003")
