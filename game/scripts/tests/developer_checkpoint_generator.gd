extends "res://scripts/tests/full_campaign_smoke.gd"

const OUTPUT := "res://data/development/checkpoints.json"
const ROOMS := {
	"B1":"M1_SERVANT_COMMON", "B2":"M1_LIBRARY_OUTER", "J1":"M1_LIBRARY_INNER",
	"B3_A":"M1_GREAT_CLOCK", "B3_B":"M1_GREAT_CLOCK", "B4":"M1_GREAT_CLOCK", "B5":"M1_LIBRARY_INNER",
	"C0":"M1_MIRROR_GALLERY", "C1":"M1_MIRROR_GALLERY", "C3":"M1_KITCHEN", "C_BELL":"M1_GREAT_CLOCK", "C4":"M1_MIRROR_GALLERY",
	"J3":"M1_LIBRARY_INNER", "D0":"M1_LIBRARY_INNER", "D1":"B1_AXIS_CHAMBER", "D2":"B1_STORAGE", "D4":"B1_CLOCKWORK_HEART",
	"E3_1":"M1_WIRING_ROOM", "E3_2":"H0_CLIMATE_CONTROL", "E3_3":"H0_LIFE_SUPPORT", "E3_4":"H0_CLOCK_MACHINE", "E3_5":"H0_COLOR_SEPARATION",
}
var checkpoints: Dictionary = {}
var capturing := false


func generate(scene_tree: SceneTree) -> Dictionary:
	if not OS.is_debug_build(): return {"ok":false}
	tree = scene_tree
	game = tree.root.get_node("GameState")
	saves = tree.root.get_node("SaveManager")
	_capture("P1", game.make_default_snapshot(), "프롤로그 시작")
	game.state_committed.connect(_prologue_commit)
	capturing = true
	var result := await run(scene_tree)
	capturing = false
	game.state_committed.disconnect(_prologue_commit)
	if not result.ok: return result
	for required in ["P1", "P2", "P3", "P3B", "P4", "P4_MEMORY", "P5", "P6", "A1", "B3_A", "C4", "D4", "D5", "E_HUB", "E3_1", "E3_2", "E3_3", "E3_4", "E3_5", "F0_A", "F0_E", "F1", "F2", "EDC", "EDR_FIELD_NOTEBOOK"]:
		if not checkpoints.has(required): errors.append("Checkpoint not reached: " + required)
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null: return {"ok":false,"errors":["Cannot write " + OUTPUT]}
	file.store_string(JSON.stringify({"version":1,"design_revision":game.DESIGN_REVISION,"checkpoints":checkpoints}, "\t"))
	file.close()
	print("DEVELOPER_CHECKPOINTS_GENERATED: %d" % checkpoints.size())
	return {"ok":true,"count":checkpoints.size()}


func _prologue_commit(_transaction: StringName, _revision: int, _paths: PackedStringArray) -> void:
	if not capturing: return
	var state: Dictionary = game.get_snapshot()
	if state.meta_progress.knowledge_entries.get("PROLOGUE_COMPLETE", false): return
	var progress: Dictionary = state.loop_state.event_local_states.get("PROLOGUE", {})
	var room := String(state.loop_state.location_id)
	for id in ["P2", "P3", "P3B", "P4", "P5", "P6"]:
		var target: String = {"P2":"M1_PARLOR","P3":"M1_LIBRARY_OUTER","P3B":"M1_NORTH_ARCHIVE_HALL","P4":"M1_KITCHEN","P5":"M1_GREENHOUSE_VESTIBULE","P6":"M2_BEDROOM"}[id]
		if room == target and progress.get("P1_complete", false) and not progress.get(id + "_complete", false):
			if id == "P6" and not progress.get("P4_complete", false): continue
			_capture(id, state, "프롤로그 " + id)
	if room == "M1_KITCHEN" and progress.get("p4_memory_anchor_seen", false) and not progress.get("P4_complete", false):
		_capture("P4_MEMORY", state, "차 준비 뒤 기억 닻과 질문")


func _step(result: Dictionary, label: String) -> bool:
	var ok := super._step(result, label)
	if not ok or not capturing: return ok
	var state: Dictionary = game.get_snapshot()
	if not state.meta_progress.knowledge_entries.get("PROLOGUE_COMPLETE", false): return ok
	var journal := int(state.meta_progress.journal_stage)
	var session = BASEMENT.new(game, saves, SLOT) if journal >= 3 else (BLACK_MIRROR.new(game, saves, SLOT) if journal >= 2 else CHAPTER_ONE.new(game, saves, SLOT))
	var stage: String = session.stage()
	if stage in ["J2_COMPLETE", "J3_COMPLETE", "POST_CREDITS"]: return ok
	if not state.ending_run.get("branch_committed", false) and (not ROOMS.has(stage) or ROOMS[stage] == state.loop_state.location_id):
		_capture(stage, state, label)
	if state.ending_run.get("branch_committed", false):
		_capture(String(state.ending_run.current_node_id), state, label)
	if stage == "EDC":
		var tier := String(state.meta_progress.event_history.get("E5", {}).get("variant_id", "LOW"))
		_capture("EDC_" + tier, state, label)
	return ok


func _capture(id: String, state: Dictionary, label: String) -> void:
	if checkpoints.has(id): return
	var captured := state.duplicate(true)
	if captured.loop_state.location_id == "M1_BEDROOM": captured.loop_state.location_id = "M2_BEDROOM"
	checkpoints[id] = {"id":id,"source_step":label,"snapshot":captured}
