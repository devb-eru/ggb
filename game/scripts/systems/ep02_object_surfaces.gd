extends RefCounted

const SCRIPT := preload("res://scripts/systems/ep01_script.gd")
const OBJECTS := {
	"M1_TOOL_ROOM": {"OBJ_CLEANING_LEDGER": "청소 장부", "OBJ_C3_MEASURE_BOTTLE": "눈금 시험병", "OBJ_TOOL_ROOM_DOOR": "도구실 손잡이", "OBJ_C2_TEST_CLOTHS": "시험 천", "OBJ_C2_SOFT_CLOTH": "부드러운 천", "OBJ_C2_DRY_BRUSH": "마른 솔", "OBJ_MARA1_WRENCH_RACK": "스패너 걸이", "OBJ_TOOL_RETURN": "도구 반납대"},
	"M1_KITCHEN": {"OBJ_CHEM_LABELS": "약품 라벨", "OBJ_NEUTRAL_TEST_STRIP": "시험지", "OBJ_CHEM_CABINET": "약품장", "OBJ_FOLDED_NOTE": "접힌 쪽지", "OBJ_C3_DISPOSAL_TRAY": "폐기 쟁반", "OBJ_C3_MIX_STATION": "혼합 병"},
	"M1_MIRROR_GALLERY": {"OBJ_MIRROR_BLACK": "검은 거울", "OBJ_MIRROR_DIAGNOSTIC": "진단문", "OBJ_NOTEBOOK": "회로 탁본"},
	"M1_COLOR_ROOM_ENTRY": {"OBJ_COLOR_SEPARATOR_PANEL": "외부 렌즈와 필터판"},
	"M1_LIBRARY_INNER": {"OBJ_JOURNAL": "일지의 세 번째 페이지"},
}

static func available(state: Dictionary) -> Dictionary:
	var room: String = state.loop_state.location_id
	var objects: Dictionary = OBJECTS.get(room, {}).duplicate()
	var known: Dictionary = state.meta_progress.knowledge_entries
	if room in ["M1_TOOL_ROOM", "M1_KITCHEN"] and not known.get("c1_cleaning_hypothesis", false):
		return {"OBJ_CHEM_CABINET": "약품장"} if room == "M1_KITCHEN" else {}
	if room == "M1_KITCHEN" and not state.loop_state.event_local_states.get("BLACK_MIRROR", {}).get("materials_ready", false): objects.erase("OBJ_C3_MIX_STATION")
	if room == "M1_MIRROR_GALLERY" and not known.get("mirror_tracing_acquired", false):
		objects.erase("OBJ_MIRROR_DIAGNOSTIC")
		objects.erase("OBJ_NOTEBOOK")
	if room == "M1_LIBRARY_INNER" and not known.get("c5_info_complete", false): return {}
	return objects

static func pages(state: Dictionary, object_id: String, before: Dictionary = {}) -> Array:
	if not available(state).has(object_id): return []
	var local: Dictionary = before if not before.is_empty() else state.loop_state.event_local_states.get("BLACK_MIRROR", {})
	var known: Dictionary = state.meta_progress.knowledge_entries
	var seen: bool = object_id in local.get("objects_seen", [])
	if object_id == "OBJ_CHEM_CABINET" and not local.get("materials_ready", false):
		var locked_pages: Array = ["EP02_OBJ_CHEM_LOCKED_PRE"]
		if state.meta_progress.failure_knowledge.get("C4", {}).get("status") == "active" and not local.get("locked", false): locked_pages.append("EP02_OBJ_CHEM_RESET")
		return locked_pages
	var ids: Array = []
	for row in SCRIPT.source("EP02").nodes:
		if row.object_id == object_id and row.location_id == state.loop_state.location_id and row.content_type == "DOCUMENT" and row.node_id.begins_with("EP02_") and row.next_type == "end":
			if row.node_id == "EP02_J3_DOC_008" and known.get("MEM_FATHER_TEA_HAND_FRAGMENT") != "sensory_fragment": continue
			ids.append(row.node_id)
	match object_id:
		"OBJ_C3_MIX_STATION": return preload("res://scripts/systems/ep02_puzzle_feedback.gd").mixture_pages(local)
		"OBJ_MIRROR_BLACK":
			var suffix := "C0_REPEAT" if seen else "C0_FIRST"
			if not known.get("c0_mirror_seen", false): suffix = "PRE"
			if local.get("locked", false): suffix = "CF"
			elif known.get("c5_info_complete", false): suffix = "C5_REPEAT"
			elif known.get("mirror_tracing_acquired", false): suffix = "C5"
			elif local.get("dry_passed", false): suffix = "C4_DRY_OK"
			elif local.get("cleaner_ready", false): suffix = "C4_COMMIT" if local.get("signal_ready", false) else "C3_READY"
			elif state.meta_progress.failure_knowledge.get("C4", {}).get("status") == "active": suffix = "RESET_AFTER_FAIL"
			elif known.get("c1_cleaning_hypothesis", false): suffix = "C1_DRY"
			ids.append("EP02_OBJ_MIRROR_" + suffix)
			if known.get("c0_mirror_seen", false) and not known.get("c1_cleaning_hypothesis", false): ids.append("EP02_OBJ_MIRROR_C1_DENY")
		"OBJ_CLEANING_LEDGER":
			if known.get("c2_cleaning_record", false): ids.append("EP02_OBJ_TOOL_LEDGER_REPEAT")
		"OBJ_TOOL_ROOM_DOOR": ids.append("EP02_OBJ_TOOL_DOOR_FIRST")
		"OBJ_C2_TEST_CLOTHS": ids.append("EP02_OBJ_TOOL_CLOTH_FIRST")
		"OBJ_C2_SOFT_CLOTH":
			ids.append("EP02_OBJ_TOOL_CLOTH_REPEAT" if seen else ("EP02_OBJ_TOOL_CLOTH_ACQUIRE" if local.get("materials_ready", false) else "EP02_OBJ_TOOL_CLOTH_FIRST"))
		"OBJ_C2_DRY_BRUSH": ids.append("EP02_OBJ_TOOL_BRUSH")
		"OBJ_MARA1_WRENCH_RACK": ids.append("EP02_OBJ_TOOL_WRENCH")
		"OBJ_TOOL_RETURN": ids.append("EP02_OBJ_TOOL_RETURN")
		"OBJ_CHEM_CABINET":
			ids.append("EP02_OBJ_CHEM_OPEN")
			ids.append_array(["EP02_OBJ_CHEM_WATER", "EP02_OBJ_CHEM_STABILIZER", "EP02_OBJ_CHEM_ACTIVE", "EP02_OBJ_CHEM_TEST"])
			if not local.get("cabinet_acquisition_seen", false): ids.append("EP02_OBJ_CHEM_ACQUIRE")
			ids.append("EP02_OBJ_CHEM_LATE" if known.get("c5_info_complete", false) else "EP02_OBJ_CHEM_HIGH_RISK")
		"OBJ_COLOR_SEPARATOR_PANEL":
			if not known.get("c5_info_complete", false): return ["EP02_OBJ_COLOR_PRE", "EP02_OBJ_COLOR_LOCKED"]
			ids.append("EP02_OBJ_COLOR_REPEAT" if seen else "EP02_OBJ_COLOR_POST")
			ids.append_array(["EP02_OBJ_COLOR_MARA2", "EP02_OBJ_COLOR_SOUND_ALT", "EP02_OBJ_COLOR_PATTERN_ALT", "EP02_OBJ_COLOR_LOCKED"])
	return ids
