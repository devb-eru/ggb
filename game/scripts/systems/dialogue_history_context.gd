extends RefCounted

const CHAPTERS := ["PROLOGUE", "CHAPTER_1", "CHAPTER_2", "CHAPTER_3", "CHAPTER_4"]
const STAGES := {
	"CHAPTER_1": ["A1", "AS", "A2", "B1", "B2", "J1", "B3_A", "B3_B", "BF", "B4", "B5", "J2_COMPLETE"],
	"CHAPTER_2": ["C_SLEEP", "C0", "C1", "C2", "C3", "C_BELL", "C4", "CF", "C5_INFO", "J3", "J3_COMPLETE", "D_SLEEP", "D0", "D0_A", "D1", "DF", "D2", "D4"],
	"CHAPTER_3": ["D5", "D6", "DEMO_END", "E1_ENTRY", "LUCA_S2", "LUCA_GUIDE", "E2_INTRO", "E_HUB", "E3_1", "E3_2", "E3_3", "E3_4", "E3_5", "E3_4M", "J4", "E5", "E6"],
	"CHAPTER_4": ["F0_A", "F0_B", "F0_C", "F0_D", "F0_E", "F1", "F2", "F3", "EDC", "ENDING_SEQUENCE", "ENDING_BODY_PENDING", "REALITY_WAKE", "FIELD_NOTEBOOK", "REALITY_SURFACE", "STAY_CHARTER", "STAY_STORY", "ENDING_CREDITS", "POST_CREDITS"],
}


static func chapter_for_stage(node_id: String) -> String:
	for chapter in STAGES:
		if node_id in STAGES[chapter]:
			return chapter
	return "LEGACY"


static func normalize_chapter(value: Variant) -> String:
	return value if value is String and value in CHAPTERS else "LEGACY"


static func capture(node_id: String, location_id: String) -> Dictionary:
	return {"node_id": node_id, "location_id": location_id, "chapter_id": chapter_for_stage(node_id)}
