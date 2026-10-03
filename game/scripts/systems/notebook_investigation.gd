extends RefCounted

# Editorial relevance, never acquisition rules or a puzzle answer selector.
const TOPICS := {
	"P1": ["P1"], "P2": ["P2"], "P3": ["P3"], "P3B": ["P3B"],
	"P4": ["P4", "P4_IRIS_GREETING"], "P5": ["P5"], "P6": ["P6"], "PF": ["PF"],
	"A1": ["A1", "A2", "AS", "MARA2_S1"],
	"B1": ["B1", "B2", "J1"],
	"B3": ["B1", "J1", "B3", "B3_A", "B3_B", "BF", "BSHORT"],
	"B4": ["B4", "B5", "J1", "J2"],
	"C3": ["J2", "C0", "C1", "C2", "C2_1", "C3", "CSHORT"],
	"C4": ["B4", "J2", "C3", "C_BELL", "C4", "CF"],
	"C5": ["B4", "C4", "C5_INFO", "J3"],
	"D0": ["C5_INFO", "J3", "D0", "D0_A"],
	"D1": ["D0", "D0_A", "D1"], "D4": ["D2", "D4"],
	"D5": ["D4", "D5", "D6", "E1", "E2", "POST_BROKEN_REST"],
	"E3_1": ["E2", "E3_1"], "E3_2": ["E2", "E3_2"],
	"E3_3": ["P4", "LUCA_S2", "E2", "E3_3"], "E3_4": ["E2", "E3_4", "E3_4M", "EDGAR_S3"],
	"E3_5": ["P3B", "MARA2_S1", "E2", "E3_5", "MARA2_FU"],
	"J4": ["E2", "E3_1", "E3_2", "E3_3", "E3_4", "E3_5", "J4"],
	"E5": ["J4", "E5", "E6", "MARA2_FU"],
	"F0_A": ["C5_INFO", "J3", "D0", "D0_A", "F0_A"],
	"F0_B": ["F0_A", "F0_B", "D5", "D6"],
	"F0_C": ["B4", "C5_INFO", "D4", "F0_C"],
	"F0_D": ["J4", "E3_1", "E3_2", "E3_3", "E3_4", "E3_4M", "E3_5", "EDGAR_S3", "F0_D"],
	"F0_E": ["A1", "A2", "F0_E"],
	"F1": ["J4", "F0_E", "F1", "J5"],
	"F2": ["J4", "F1", "J5", "F2"],
	"F3": ["F0_E", "F1", "J5", "F2", "F3", "EDC"],
	"REALITY": ["EDR_ENTRY", "EDR_DISCONNECT", "EDR_WAKE_BODY", "EDR_BODY_CHECK", "EDR_FIELD_NOTEBOOK", "EDR_ARCHIVE_STATUS", "EDR_EXIT_PANEL", "EDR_FACILITY_FREE_LOOK", "EDR_FAREWELL", "EDR_AIRLOCK_CONFIRM", "EDR_SURFACE_THRESHOLD", "EDR_FINAL_FRAME"],
	"STAY": ["EDS_ENTRY", "EDS_STABILIZE", "EDS_MEMORY_CHARTER", "EDS_APPEARANCE_CONTROL", "EDS_AUTONOMY_CHARTER", "EDS_CENTRAL_HALL", "EDS_DINING_ROOM", "EDS_TABLE_OBJECTS", "EDS_FINAL_FRAME"],
}
const ALIASES := {
	"P4_IRIS_GREETING": "P4", "PG": "P1", "AS": "A1", "A2": "A1", "MARA2_S1": "A1",
	"B2": "B1", "J1": "B1", "B3_A": "B3", "B3_B": "B3", "BF": "B3", "BSHORT": "B3",
	"B5": "B4", "J2_COMPLETE": "B4", "C_SLEEP": "B4",
	"C0": "C3", "C1": "C3", "C2": "C3", "C2_1": "C3", "CSHORT": "C3",
	"C_BELL": "C4", "CF": "C4", "C5_INFO": "C5", "J3": "C5", "J3_COMPLETE": "C5",
	"D_SLEEP": "D0", "D0_A": "D0", "DF": "D1", "D2": "D4", "D6": "D5", "DEMO_END": "D5",
	"E1_ENTRY": "D5", "E1": "D5", "E2_INTRO": "D5", "E2": "D5", "E_HUB": "D5",
	"LUCA_S2": "E3_3", "LUCA_GUIDE": "E3_3", "E3_4M": "E3_4", "EDGAR_S3": "E3_4", "MARA2_FU": "E3_5", "E6": "E5",
	"J5": "F1", "EDC": "F3", "REALITY_WAKE": "REALITY", "FIELD_NOTEBOOK": "REALITY", "REALITY_SURFACE": "REALITY",
	"STAY_CHARTER": "STAY", "STAY_STORY": "STAY",
}


static func topic(node: String) -> String:
	var resolved: String = ALIASES.get(node, node)
	if TOPICS.has(resolved): return resolved
	# These are exact authored ending event IDs, not arbitrary prefix matches.
	for ending in ["REALITY", "STAY"]:
		if node in TOPICS[ending]: return ending
	return ""


static func includes(current_topic: String, entry: Dictionary) -> bool:
	if not TOPICS.has(current_topic) or entry.get("record_class") != "authored": return false
	var observed: Dictionary = entry.observation
	if observed.event_id in TOPICS[current_topic]: return true
	return observed.entry_kind == "hint_revealed" and String(observed.content_id).begins_with("NB_HINT_" + current_topic + "_")
