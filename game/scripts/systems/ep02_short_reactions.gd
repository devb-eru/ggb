extends RefCounted


static func edgar_warning(state: Dictionary) -> String:
	var alert := int(state.meta_progress.servants.edgar.alert)
	return "EP02_REL_EDGAR_C0_" + ("HIGH" if alert >= 4 else ("MID" if alert >= 2 else "LOW"))


static func available(state: Dictionary) -> Dictionary:
	var known: Dictionary = state.meta_progress.knowledge_entries
	var servants: Dictionary = state.meta_progress.servants
	var local: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
	var result := {}
	var effects := preload("res://scripts/systems/sheet_dialogue_effects.gd")
	match String(state.loop_state.location_id):
		"M1_MIRROR_GALLERY":
			if known.get("c2_cleaning_record", false):
				var id := "EP02_REL_MARA1_C2_REPEAT" if _read(state, "EP02_REL_MARA1_C2_FIRST") else "EP02_REL_MARA1_C2_FIRST"
				if local.get("materials_ready", false) and state.meta_progress.failure_knowledge.has("C4"):
					if int(servants.mara1.alert) >= 4: id = "EP02_REL_MARA1_CSHORT_ALERT"
					elif int(servants.mara1.bond) >= 4: id = "EP02_REL_MARA1_CSHORT_HIGH"
				result.MARA1 = id
			if "EDGAR" in local.get("witnesses", []) and local.get("intervention_handled", false): result.EDGAR = "EP02_REL_EDGAR_C4_REPEAT"
		"M1_KITCHEN":
			if known.get("c21_chemical_record", false):
				var id := "EP02_REL_LUCA_C21_HIGH" if int(servants.luca.bond) >= 4 and int(servants.luca.alert) < 4 else "EP02_REL_LUCA_C21_LOW"
				if local.get("materials_ready", false) and state.meta_progress.failure_knowledge.has("C4") and int(servants.luca.alert) >= 4: id = "EP02_REL_LUCA_CSHORT_ALERT"
				if local.get("mixture_test_failed", false): id = "EP02_REL_LUCA_C3_ERROR"
				result.LUCA = id
		"M1_COLOR_ROOM_ENTRY":
			var id := "EP02_REL_MARA2_PRE" if not known.get("c5_info_complete", false) else "EP02_REL_MARA2_POST"
			if known.get("mara2_archive_index_known", false): id = "EP02_REL_MARA2_INDEX"
			result.MARA2 = id
		"M1_GREENHOUSE":
			if known.get("c5_info_complete", false): result.IRIS = "EP02_REL_IRIS_POST" if effects.event_seen(state, "IRIS_S2") else "EP02_REL_IRIS_PRE"
	return result


static func _read(state: Dictionary, identity: String) -> bool:
	for entry in state.meta_progress.dialogue_history.get("entries", []):
		if entry.get("observation", {}).get("content_id") == "NB_" + identity: return true
	return false
