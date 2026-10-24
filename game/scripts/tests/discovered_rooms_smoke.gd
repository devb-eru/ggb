extends RefCounted
const VISITS := preload("res://scripts/systems/discovered_rooms.gd")
const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const SLOT := "__test_discovered_rooms"
var errors: Array[String] = []

class RejectSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok":false, "error_id":"TEST_MAP_DISK_FAILURE"}

func run() -> Dictionary:
	GameState.reset_for_test()
	SaveManager.delete_test_slot(SLOT)
	var state := GameState.get_snapshot()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.loop_state.day_index = 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"MAP_SEED").ok, "seed")
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().ok, "initialize")
	_expect(session.act("mark", "sentence").ok, "mark")
	_expect(session.act("move", "M1_CENTRAL_HALL").ok, "move to hall")
	_expect(session.act("move", "M1_PARLOR").ok, "silent move to parlor")
	_expect(session.act("move", "M1_CENTRAL_HALL").ok, "return to hall")
	var before := GameState.get_snapshot()
	var rejected := RejectSave.new()
	session._save = rejected
	_expect(not session.act("move", "M1_SERVANT_COMMON").ok, "disk failure rejects movement")
	_expect(GameState.get_snapshot() == before, "failed save rolls back visit and movement together")
	_expect(not VISITS.known(GameState.get_snapshot()).has("M1_SERVANT_COMMON"), "failed visit stays undiscovered")
	session._save = SaveManager
	rejected.free()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload actual save")
	_expect(VISITS.known(GameState.get_snapshot()).has("M1_PARLOR"), "silent visit survives reload without displayed dialogue")
	session = SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.act("move", "M2_BEDROOM").ok, "return to bedroom")
	_expect(session.act("routine").ok, "routine")
	_expect(session.sleep().ok, "actual normal reset")
	_expect(VISITS.known(GameState.get_snapshot()).has("M1_PARLOR"), "visited room survives day reset")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload after reset")
	_expect(VISITS.known(GameState.get_snapshot()).has("M1_PARLOR"), "reset visit survives disk reload")
	var frozen := GameState.get_snapshot()
	_expect(not session.act("move", "H0_CORE_CHAMBER").ok, "undisclosed destination rejected")
	_expect(GameState.get_snapshot() == frozen, "rejected target cannot discover a room")
	var malformed := frozen.duplicate(true)
	malformed.meta_progress.knowledge_entries[VISITS.KEY] = ["M2_BEDROOM", "M2_BEDROOM"]
	_expect(not StateSnapshotValidator.new().validate(malformed).ok, "duplicate visited IDs rejected")
	# Pure prologue candidates cover the synchronous and asynchronous save paths.
	var previous := GameState.make_default_snapshot()
	var request := {"progress":{}, "pending_notes":{}, "scope":{}, "recording":{}, "window":{}, "inventory":[], "surfaces":[], "room":"M1_PARLOR", "locale":"ko-KR", "complete":false, "already_complete":false, "cursor_enabled":false, "complete_cursor":false}
	var original := previous.duplicate(true)
	var prepared := preload("res://scripts/systems/prologue_save_candidate.gd").prepare(previous, request)
	_expect(prepared.ok and VISITS.known(prepared.snapshot).has("M1_PARLOR"), "prologue candidate records visit")
	_expect(previous == original, "prologue preparation leaves source immutable")
	SaveManager.delete_test_slot(SLOT)
	print("DISCOVERED_ROOMS_SMOKE: ", "PASS" if errors.is_empty() else errors)
	return {"ok":errors.is_empty(), "errors":errors}

func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)
