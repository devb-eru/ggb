extends RefCounted


static func after(identity: String, state: Dictionary, profile: Dictionary) -> Array:
	var known: Dictionary = state.meta_progress.knowledge_entries
	var local: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
	var ids: Array = []
	var captions: Array = []
	match identity:
		"EP02_C0_001":
			if state.loop_state.location_id == "M1_MIRROR_GALLERY": captions.append("EP02_CAP_MIRROR_ENTER")
		"EP02_OBJ_CHEM_LOCKED_PRE":
			if state.loop_state.location_id == "M1_KITCHEN" and not local.get("materials_ready", false): captions.append("EP02_CAP_CHEM_LOCK")
		"EP02_C2_001", "EP02_C21_001":
			var coating: bool = known.get("c2_cleaning_record", false)
			var mixture: bool = known.get("c21_chemical_record", false)
			if coating and mixture: ids.append("EP02_SYS_UI_INFO_DONE")
			elif coating and identity == "EP02_C2_001": ids.append("EP02_SYS_UI_INFO_1")
			elif mixture and identity == "EP02_C21_001": ids.append("EP02_SYS_UI_INFO_2")
			if identity == "EP02_C2_001" and state.loop_state.location_id == "M1_TOOL_ROOM": captions.append("EP02_CAP_TOOL_AMB")
		"EP02_C3_MIX_001":
			if local.get("materials_ready", false): ids.append("EP02_SYS_UI_C3_LOCAL")
		"EP02_C3_SUCCESS_001":
			if local.get("cleaner_ready", false) and known.get("c3_formula_verified", false):
				ids.append_array(["EP02_C3_UI_ACQUIRE_LABEL", "EP02_C3_UI_FORMULA_LABEL", "EP02_SYS_SAVE_C3"])
		"EP02_C4_001":
			if not local.get("locked", false) and not known.get("mirror_tracing_acquired", false): ids.append("EP02_SYS_UI_C4_REVERSIBLE")
		"EP02_C4_COMMIT_001":
			if not local.get("locked", false) and not known.get("mirror_tracing_acquired", false): ids.append("EP02_SYS_UI_C4_IRREVERSIBLE")
		"EP02_CF_001":
			if local.get("locked", false) and state.meta_progress.failure_knowledge.get("C4", {}).get("status") == "active":
				ids.append_array(["EP02_C4_UI_FAIL_LOCK", "EP02_SYS_UI_CF_FREE", "EP02_SYS_SAVE_CF"])
				if local.get("witnesses", []).is_empty(): ids.append_array(["EP02_C4_UI_WITNESS_NONE", "EP02_REL_WITNESS_FAIL_NONE"])
		"EP02_C4_ACTUAL_001":
			if local.get("surface_open", false):
				ids.append("EP02_C4_UI_SUCCESS_UNLOCK")
				if local.get("witnesses", []).is_empty(): ids.append("EP02_REL_WITNESS_SUCCESS_NONE")
		"EP02_CSHORT_001":
			if state.loop_state.location_id == "M1_KITCHEN" and local.get("materials_ready", false): ids.append("EP02_SYS_UI_CSHORT")
		"EP02_CSHORT_MARA1_001", "EP02_CSHORT_LUCA_001":
			ids.append("EP02_REL_RELATION_LIMIT")
		"EP02_J3_001":
			if known.get("c5_info_complete", false):
				ids.append_array(["EP02_J3_UI_PAGE_OPEN", "EP02_SYS_UI_J3_LOCAL"])
				captions.append("EP02_CAP_J3_OPEN")
		"EP02_J3_MEMORY_001":
			if known.get("MEM_FATHER_TEA_HAND_FRAGMENT") == "sensory_fragment" and local.get("j3_reference_points", []).size() == 3:
				captions.append("EP02_CAP_PENCIL")
	return preload("res://scripts/systems/ep02_sensory_captions.gd").decorate(ids, captions, profile)


static func expand(ids: Array, state: Dictionary, profile: Dictionary) -> Array:
	var expanded: Array = []
	for identity in ids:
		if identity not in expanded: expanded.append(identity)
		for extra in after(identity, state, profile):
			if extra not in ids and extra not in expanded: expanded.append(extra)
	return expanded
