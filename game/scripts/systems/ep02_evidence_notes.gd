extends RefCounted


static func available(state: Dictionary) -> Array:
	var known: Dictionary = state.meta_progress.knowledge_entries
	var notes: Array = []
	var gates := {
		"c0_mirror_seen": "EP02_SYS_NOTE_C0",
		"c2_cleaning_record": "EP02_SYS_NOTE_C2",
		"c21_chemical_record": "EP02_SYS_NOTE_C21",
		"c3_formula_verified": "EP02_SYS_NOTE_C3",
		"KN_C4_OVERLAY": "EP02_SYS_NOTE_C4_OVERLAY",
	}
	for key in gates:
		if known.get(key, false): notes.append(gates[key])
	if known.has("mirror_verified_plan"): notes.append("EP02_SYS_NOTE_C4_ROUTE")
	if not state.meta_progress.failure_knowledge.get("C4", {}).is_empty(): notes.append("EP02_SYS_NOTE_CF")
	var diagnostics := ["KN_C5_EXTERNAL_BELOW_THRESHOLD", "KN_C5_SUBJECT_BODY_EXISTS", "KN_C5_WAKE_AUTHORITY_LOCKED", "KN_C5_PERSONALITY_CHANNEL_COUNT"]
	if diagnostics.all(func(key: String) -> bool: return known.get(key, false)):
		notes.append("EP02_SYS_NOTE_C5")
	if known.get("c5_info_complete", false): notes.append("EP02_SYS_NOTE_TRACE")
	if int(state.meta_progress.journal_stage) >= 3: notes.append("EP02_SYS_NOTE_J3")
	return notes
