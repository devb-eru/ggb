extends RefCounted

const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const CHAPTER_ONE := preload("res://scripts/systems/chapter_one_session.gd")
const BLACK_MIRROR := preload("res://scripts/systems/black_mirror_session.gd")
const BASEMENT := preload("res://scripts/systems/basement_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const MIRROR := preload("res://data/puzzles/puzzle_black_mirror.tres")
const ENDING_META := preload("res://scripts/systems/ending_meta_store.gd")

const SLOT := "__test_full_campaign"
const BUILD_FLAVOR_SETTING := "ggb/build_flavor"
const TIER_ORDER := ["LOW", "MID", "HIGH", "ALL"]
const TIER_RELATIONSHIPS := {
	"LOW": [],
	"MID": ["mara1", "luca"],
	"HIGH": ["mara1", "iris", "luca", "edgar"],
	"ALL": ["mara1", "iris", "luca", "edgar", "mara2"],
}

var errors := PackedStringArray()
var game: Node
var saves: Node
var tree: SceneTree
var _test_slots: Array[String] = [SLOT]
var _replay_slots: Array[String] = []
var _meta_roots: Array[String] = []


func run(scene_tree: SceneTree) -> Dictionary:
	tree = scene_tree
	game = tree.root.get_node("GameState")
	saves = tree.root.get_node("SaveManager")
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en_US")
	var previous_flavor: Variant = ProjectSettings.get_setting(BUILD_FLAVOR_SETTING, null)
	ProjectSettings.set_setting(BUILD_FLAVOR_SETTING, "full")
	saves.delete_test_slot(SLOT)
	game.reset_for_test()

	if await _run_prologue():
		if _run_chapter_one():
			if _run_black_mirror():
				if _run_basement_to_relationship_hub():
					_run_relationship_tiers()

	_cleanup()
	ProjectSettings.set_setting(BUILD_FLAVOR_SETTING, previous_flavor)
	TranslationServer.set_locale(previous_locale)
	return {"ok": errors.is_empty(), "errors": errors}


func _run_prologue() -> bool:
	var bootstrap := tree.current_scene
	if not _expect(bootstrap != null and bootstrap.has_method("request_sleep_transition"), "bootstrap exposes the production sleep transition"):
		return false
	var prologue = PROLOGUE_SCENE.instantiate()
	prologue.configure_session(SLOT, "P1_ENTRY", false)
	bootstrap.add_child(prologue)
	await tree.process_frame
	prologue._dismiss_dialogue_for_test()
	prologue._inspect_bedroom("bed")
	prologue._dismiss_dialogue_for_test()
	prologue._inspect_bedroom("notebook")
	prologue._dismiss_dialogue_for_test()
	prologue._leave_bedroom_morning()
	prologue._dismiss_dialogue_for_test()
	if not _expect(bool(prologue._progress.get("P1_complete", false)), "P1 completes through bedroom interactions"):
		prologue.queue_free()
		return false

	var prologue_errors: PackedStringArray = prologue.run_smoke_scenario()
	for message in prologue_errors:
		errors.append("prologue route: " + message)
	if not prologue_errors.is_empty():
		prologue.queue_free()
		return false
	prologue._enter_room("M2_BEDROOM")
	prologue._dismiss_dialogue_for_test()
	prologue._begin_first_sleep()
	while prologue._dialogue_active:
		prologue._advance_dialogue()
	await tree.create_timer(2.8).timeout
	var prologue_ok := (
		_expect(int(game.get_value("loop_state.day_index", -1)) == 1, "first sleep advances the campaign to day one")
		and _expect(game.get_value("meta_progress.knowledge_entries.PROLOGUE_COMPLETE", false), "prologue completion survives normal reset")
		and _expect(game.get_value("meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT", "") == "sensory_fragment", "P4 father tea memory anchor persists")
		and _expect(game.get_value("meta_progress.knowledge_entries.CLR_00_SIGNATURES", false), "P3B signature lesson persists")
	)
	prologue.queue_free()
	await tree.process_frame
	return prologue_ok and _reload(SLOT, "prologue boundary reload")


func _run_chapter_one() -> bool:
	var session := CHAPTER_ONE.new(game, saves, SLOT)
	if not _step(session.initialize(), "chapter one initializes after the prologue"):
		return false
	if not _expect(session.stage() == "A1", "continuous route enters A1"):
		return false
	if not _step(session.act("mark", "house_glyph"), "A1 writes a persistent house glyph"):
		return false
	if not _step(session.act("routine"), "A1 routine shortcut") or not _step(session.sleep(), "A1 normal reset"):
		return false
	if not _step(session.act("confirm_mark"), "A2 confirms the mark survived"):
		return false
	_travel_chapter_one(session, "M1_SERVANT_COMMON")
	if not _step(session.act("read_schedule", "edgar"), "B1 reads Edgar schedule"):
		return false
	if not _step(session.act("read_schedule", "luca"), "B1 reads Luca schedule"):
		return false
	if not _step(session.act("schedule_window", "after_tea_before_bell"), "B1 derives the library window"):
		return false
	_step(session.act("routine"), "B1 completes the shortened routine")
	_travel_chapter_one(session, "M1_LIBRARY_OUTER")
	if not _step(session.act("move", "M1_LIBRARY_INNER"), "B2 enters the inner library"):
		return false
	_step(session.act("inspect_inner", "desk"), "B2 inspects the restoration desk")
	for index in range(3):
		_step(session.act("j1_piece", index), "J1 places fragment %d" % index)
		_step(session.act("j1_flip", index), "J1 flips fragment %d" % index)
	if not _step(session.act("j1_restore"), "J1 restores the first journal page"):
		return false
	_step(session.act("inspect_inner", "link"), "B3 reveals the clock-network link")
	for room in CHAPTER_ONE.CLOCK_ROOMS:
		_travel_chapter_one(session, room)
		if not _step(session.act("rub_clock"), "B3 records clock clue in " + room):
			return false
	_solve_clock_board(session)
	if not _step(session.act("board_check"), "B3 verifies the clock layout"):
		return false
	for role in CLOCK.ROLES:
		_step(session.act("role", [role, CLOCK.SOLUTION[role]]), "B3 assigns " + role)
	if not _step(session.act("activate_clock", true), "B3 commits the intended first phase failure"):
		return false
	if not _expect(session.stage() == "BF", "clock failure locks the current physical attempt"):
		return false
	_travel_chapter_one(session, "M2_BEDROOM")
	if not _step(session.sleep(), "B3 failure is recovered by normal reset"):
		return false
	if not _step(session.act("shortcut"), "B-stage persistent information rebuilds the attempt"):
		return false
	_step(session.act("phase", "+1"), "B3 applies the delayed phase")
	if not _step(session.act("activate_clock", true), "B3 succeeds after the information shortcut"):
		return false
	_travel_chapter_one(session, "M1_GREAT_CLOCK")
	if not _step(session.act("record_wave"), "B4 records the thirteenth-bell waveform"):
		return false
	_travel_chapter_one(session, "M1_NORTH_ARCHIVE_HALL")
	if not _step(session.act("move", "M1_LIBRARY_INNER"), "B5 re-enters the inner library"):
		return false
	for index in range(3):
		_step(session.act("wave_rotate"), "J2 rotates the waveform overlay")
	if not _step(session.act("restore_j2"), "J2 restores the second journal page"):
		return false
	return _expect(session.stage() == "J2_COMPLETE", "chapter one reaches J2_COMPLETE") and _reload(SLOT, "J2 campaign reload")


func _run_black_mirror() -> bool:
	var session := BLACK_MIRROR.new(game, saves, SLOT)
	if not _step(session.initialize(), "black mirror chapter initializes from J2"):
		return false
	if not _expect(session.stage() == "C_SLEEP", "J2 requires the next morning"):
		return false
	_travel_black_mirror(session, "M2_BEDROOM")
	_step(session.act("routine"), "C route completes the shortened routine")
	if not _step(session.sleep(), "J2 normal reset"):
		return false
	_travel_black_mirror(session, "M1_MIRROR_GALLERY")
	_step(session.act("c_observe"), "C0 observes the forbidden mirror")
	_step(session.act("c_hypothesis"), "C0 records the cleaning hypothesis")
	_travel_black_mirror(session, "M1_TOOL_ROOM")
	_step(session.act("c_read_cleaning"), "C2 reads Mara 1 cleaning records")
	_travel_black_mirror(session, "M1_KITCHEN")
	_step(session.act("c_read_chemicals"), "C2-1 reads Luca chemical records")
	_step(session.act("c_prepare"), "C3 prepares the mixing station")
	_make_cleaner(session)
	_travel_black_mirror(session, "M1_GREAT_CLOCK")
	_step(session.act("c_bell"), "C4 repeats the thirteenth bell")
	_travel_black_mirror(session, "M1_MIRROR_GALLERY")
	_step(session.act("c_dry"), "C4 dry trace records an invalid plan")
	if not _step(session.act("c_wet", true), "C4 commits the intended coating failure"):
		return false
	if not _expect(session.stage() == "CF", "mirror coating failure requires reset"):
		return false
	_travel_black_mirror(session, "M2_BEDROOM")
	_step(session.act("routine"), "C failure route completes routine")
	if not _step(session.sleep(), "C4 hard failure normal reset"):
		return false
	if not _step(session.act("c_shortcut"), "C-stage persistent information reacquires materials"):
		return false
	_make_cleaner(session)
	_travel_black_mirror(session, "M1_GREAT_CLOCK")
	_step(session.act("c_bell"), "C4 shortcut repeats the bell")
	_travel_black_mirror(session, "M1_MIRROR_GALLERY")
	_step(session.act("c_rotate"), "C4 rotates the dry overlay")
	_step(session.act("c_anchor"), "C4 anchors the waveform")
	for part in MIRROR.PATH:
		_step(session.act("c_segment", part), "C4 traces segment " + str(part))
	_step(session.act("c_dry"), "C4 verifies the dry path")
	_step(session.act("c_verify_plan"), "C4 confirms the observed plan")
	if not _step(session.act("c_wet", true), "C4 acquires the diagnostic tracing"):
		return false
	_travel_black_mirror(session, "M2_BEDROOM")
	_step(session.act("routine"), "C5 route completes routine before reset")
	if not _step(session.sleep(), "C5 tracing survives a normal reset"):
		return false
	_travel_black_mirror(session, "M1_MIRROR_GALLERY")
	for owner in BLACK_MIRROR.CHANNELS:
		_step(session.act("c_scan", owner), "C5 scans " + owner)
	if not _step(session.act("c_record"), "C5 records all five signature channels"):
		return false
	_travel_black_mirror(session, "M1_LIBRARY_INNER")
	_step(session.act("routine"), "J3 opens the restoration workbench")
	_step(session.act("j3_overlay"), "J3 lays down the circuit overlay")
	for index in range(4):
		_step(session.act("j3_piece", index), "J3 places fragment %d" % index)
	if not _step(session.act("j3_restore"), "J3 restores the third journal page"):
		return false
	return _expect(session.stage() == "J3_COMPLETE", "black mirror chapter reaches J3_COMPLETE") and _reload(SLOT, "J3 campaign reload")


func _run_basement_to_relationship_hub() -> bool:
	var session := BASEMENT.new(game, saves, SLOT)
	if not _step(session.initialize(), "basement campaign initializes from J3"):
		return false
	_move_basement(session, ["M1_LIBRARY_OUTER", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	_step(session.act("routine"), "D route completes the shortened routine")
	if not _step(session.sleep(), "J3 normal reset"):
		return false
	_step(session.act("routine"), "D0 completes the morning routine")
	_move_basement(session, ["M1_CENTRAL_HALL", "M1_LIBRARY_OUTER", "M1_LIBRARY_INNER"])
	for point in ["greenhouse", "bedroom", "great_clock"]:
		_step(session.act("d_drawer_point", point), "D0 reads floor-plan point " + point)
	_step(session.act("d_flip"), "D0 flips the floor plan")
	for index in range(3):
		_step(session.act("d_rotate"), "D0 rotates the floor plan")
	_step(session.act("d_anchor", "great_clock"), "D0 anchors the great clock")
	if not _step(session.act("d_overlay"), "D0 solves the basement overlay"):
		return false
	_move_basement(session, ["M1_LIBRARY_OUTER", "M1_CENTRAL_HALL", "M1_GREAT_CLOCK", "M1_BASEMENT_ENTRY", "B1_BASEMENT_STAIR", "B1_AXIS_CHAMBER"])
	_step(session.act("d_axis_depth", ["line", 2]), "D1 sets line depth")
	_step(session.act("d_axis_push", {"value": "line", "confirmed": true}), "D1 pushes line axis")
	_step(session.act("d_axis_depth", ["branch", 3]), "D1 sets an incorrect branch depth")
	if not _step(session.act("d_axis_push", {"value": "branch", "confirmed": true}), "D1 commits the intended axis failure"):
		return false
	if not _expect(session.stage() == "DF", "axis failure locks the current physical attempt"):
		return false
	_move_basement(session, ["B1_BASEMENT_STAIR", "M1_BASEMENT_ENTRY", "M1_GREAT_CLOCK", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	if not _step(session.sleep(), "D1 hard failure normal reset"):
		return false
	if not _step(session.act("d_shortcut"), "D-stage persistent information prepares verified depth"):
		return false
	for pair in [["line", 2], ["branch", 1], ["ring", 3]]:
		_step(session.act("d_axis_depth", pair), "D1 sets verified depth for " + pair[0])
		_step(session.act("d_axis_push", {"value": pair[0], "confirmed": true}), "D1 pushes " + pair[0])
	if not _step(session.act("d_axis_central", {"value": "clockwise", "confirmed": true}), "D2 opens the storage route"):
		return false
	_move_basement(session, ["B1_STORAGE"])
	_step(session.act("d_storage", "cable"), "D2 inspects the cable")
	_step(session.act("d_storage", "drawing"), "D2 inspects the drawing")
	_move_basement(session, ["B1_CLOCKWORK_HEART"])
	for handle in ["A", "B", "C", "C"]:
		_step(session.act("d_heart", {"action": "turn", "value": handle}), "D4 turns handle " + handle)
	_step(session.act("d_heart", {"action": "fix"}), "D4 fixes the selected handle")
	for index in range(12):
		_step(session.act("d_heart", {"action": "wind"}), "D4 winds the heart %d" % (index + 1))
	_step(session.act("d_heart", {"action": "stabilize"}), "D4 stabilizes the heart")
	_step(session.act("d_heart", {"action": "inspect_auxiliary"}), "D4 finds the auxiliary input")
	if not _step(session.act("d_heart", {"action": "pull_auxiliary", "confirmed": true}), "D4 disables the camouflage filter"):
		return false
	if not _step(session.act("d_fracture"), "D5 acknowledges the world fracture"):
		return false
	if not _reload(SLOT, "D5 campaign reload"):
		return false
	session.initialize()
	_step(session.act("d6_move", "H0_SERVICE_SPINE"), "D6 enters the service spine")
	for object_id in ["wall", "sign", "notebook"]:
		_step(session.act("d6_inspect", object_id), "D6 inspects " + object_id)
	if not _step(session.act("d6_rest", "capsule"), "D6 selects the emergency capsule"):
		return false
	if not _step(session.sleep(), "D6 performs the one broken reset"):
		return false
	if not _expect(session.stage() == "E1_ENTRY", "broken reset opens the different morning"):
		return false
	for object_id in ["bed", "window", "mirror"]:
		_step(session.act("e1_inspect", object_id), "E1 inspects " + object_id)
	_step(session.act("move", "M1_CENTRAL_HALL"), "E1 leaves the bedroom")
	_step(session.act("move", "M1_KITCHEN"), "Luca guides the protagonist to the kitchen")
	_step(session.act("e2_luca", "withdraw"), "Luca prelude resolves without relationship reward")
	_step(session.act("e2_report"), "E2 hears the reset-failure report")
	if not _step(session.act("e2_finish"), "E2 opens the optional relationship hub"):
		return false
	return _expect(
		_completed_servants(session.snapshot()) == 0 and session.stage() == "E_HUB",
		"continuous campaign reaches E_HUB with every relationship event still optional"
	)


func _run_relationship_tiers() -> void:
	var hub_snapshot: Dictionary = game.get_snapshot()
	var hub_header: Dictionary = saves.inspect_slot(SLOT)
	var save_point := String(hub_header.get("save_point_id", "SAVE_BROKEN_RESET_COMPLETE"))
	for tier in TIER_ORDER:
		if tier == "LOW":
			continue
		var slot_id := _tier_slot(tier)
		saves.delete_test_slot(slot_id)
		_test_slots.append(slot_id)
		if not _step(
			saves.save_snapshot(slot_id, save_point, hub_snapshot, game.revision, "RELATIONSHIP_TIER_BRANCH_" + tier),
			"%s route branches from the authentic E_HUB save" % tier
		):
			return

	for tier in TIER_ORDER:
		var slot_id := _tier_slot(tier)
		if not _reload(slot_id, "%s E_HUB branch reload" % tier):
			continue
		var session := BASEMENT.new(game, saves, slot_id)
		if not _step(session.initialize(), "%s route initializes at E_HUB" % tier):
			continue
		if not _expect(session.stage() == "E_HUB", "%s route starts from the same relationship hub" % tier):
			continue
		var route_ok := true
		for owner in TIER_RELATIONSHIPS[tier]:
			if not _solve_relationship(session, owner, tier):
				route_ok = false
				break
		var expected_count: int = TIER_RELATIONSHIPS[tier].size()
		if not _expect(_completed_servants(session.snapshot()) == expected_count, "%s route completes exactly %d relationship events" % [tier, expected_count]):
			route_ok = false
		if route_ok and _run_tier_to_decision(session, slot_id, tier, expected_count):
			_run_both_endings(slot_id, tier, expected_count)


func _tier_slot(tier: String) -> String:
	return SLOT if tier == "LOW" else SLOT + "_" + tier.to_lower()


func _solve_relationship(session, owner: String, tier: String) -> bool:
	var errors_before := errors.size()
	match owner:
		"mara1":
			_move_basement(session, ["M1_SERVICE_HALL", "M1_WIRING_ROOM"])
			_step(session.act("mara1_panel"), tier + " opens Mara 1's wiring panel")
			for index in range(3):
				_step(session.act("mara1_source", [index, ["MAINT", "CONSENT", "AUDIT"][index]]), tier + " traces Mara 1 source %d" % index)
			_step(session.act("mara1_bridge"), tier + " bridges Mara 1's verified wiring")
			for record_id in ["consent", "failure", "command"]:
				_step(session.act("mara1_log", record_id), tier + " orders Mara 1 record " + record_id)
			_step(session.act("mara1_restore"), tier + " restores Mara 1's deleted record")
			_step(session.act("mara1_confess"), tier + " hears Mara 1's account")
			_step(session.act("mara1_choose", "original_attribution"), tier + " returns Mara 1's attribution")
			_move_basement(session, ["M1_SERVICE_HALL", "M1_CENTRAL_HALL"])
		"iris":
			_move_basement(session, ["M1_GREENHOUSE", "H0_CLIMATE_CONTROL"])
			_step(session.act("iris_panel"), tier + " opens Iris's climate panel")
			for gauge in BASEMENT.IRIS_RELATIONSHIP.CHANNELS:
				for index in range(3):
					_step(session.act("iris_source", [gauge, index, BASEMENT.IRIS_RELATIONSHIP.CHANNELS[gauge][index]]), tier + " separates Iris channel %s/%d" % [gauge, index])
			for record_id in BASEMENT.IRIS_RELATIONSHIP.ORDER:
				_step(session.act("iris_log", record_id), tier + " orders Iris record " + record_id)
			_step(session.act("iris_restore"), tier + " restores Iris's audit chronology")
			_step(session.act("iris_audit", "credential_owner_not_executor"), tier + " distinguishes Iris's credential from execution")
			_step(session.act("iris_confront"), tier + " confronts Iris with the audit")
			_step(session.act("iris_choose", "external_truth"), tier + " preserves Iris's external record")
			_move_basement(session, ["M1_GREENHOUSE", "M1_CENTRAL_HALL"])
		"luca":
			_move_basement(session, ["M1_KITCHEN", "H0_LIFE_SUPPORT"])
			_step(session.act("luca_panel"), tier + " opens Luca's life-support panel")
			_step(session.act("luca_pipe", "main"), tier + " selects Luca's main pipe")
			_step(session.act("luca_pipe", "aux"), tier + " selects Luca's auxiliary pipe")
			_step(session.act("luca_match"), tier + " matches Luca's two live pipes")
			for index in range(4):
				_step(session.act("luca_slot", [index, BASEMENT.LUCA_RELATIONSHIP.PHASES[index]]), tier + " places Luca phase %d" % index)
			_step(session.act("luca_run"), tier + " stabilizes Luca's pressure cycle")
			for record_id in BASEMENT.LUCA_RELATIONSHIP.LOGS:
				_step(session.act("luca_log", record_id), tier + " reads Luca record " + record_id)
			_step(session.act("luca_confess"), tier + " hears Luca's account")
			_step(session.act("luca_choose", "full_disclosure"), tier + " requests Luca's full disclosure")
			_move_basement(session, ["M1_KITCHEN", "M1_CENTRAL_HALL"])
		"edgar":
			_move_basement(session, ["M1_GREAT_CLOCK", "H0_CLOCK_MACHINE"])
			for record_id in BASEMENT.EDGAR_RELATIONSHIP.ORDER:
				_step(session.act("edgar_log", record_id), tier + " orders Edgar record " + record_id)
			_step(session.act("edgar_audit"), tier + " validates Edgar's chronology")
			for function in BASEMENT.EDGAR_RELATIONSHIP.OWNERS:
				_step(session.act("edgar_owner", [function, BASEMENT.EDGAR_RELATIONSHIP.OWNERS[function]]), tier + " assigns Edgar authority " + function)
			_step(session.act("edgar_validate"), tier + " validates Edgar's authority layout")
			_step(session.act("edgar_confess"), tier + " hears Edgar's account")
			_step(session.act("edgar_choose", "authority_returned"), tier + " returns authority through Edgar's record")
			_move_basement(session, ["M1_GREAT_CLOCK", "M1_CENTRAL_HALL"])
		"mara2":
			_move_basement(session, ["M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY", "H0_COLOR_SEPARATION"])
			for portrait in BASEMENT.MARA2_RELATIONSHIP.PORTRAITS:
				for source_owner in BASEMENT.MARA2_RELATIONSHIP.OWNERS:
					_step(session.act("mara2_source", [portrait, source_owner, source_owner]), tier + " separates Mara 2 source %s/%s" % [portrait, source_owner])
			for portrait in BASEMENT.MARA2_RELATIONSHIP.ORDER:
				_step(session.act("mara2_portrait", portrait), tier + " orders Mara 2 portrait " + portrait)
			for portrait in BASEMENT.MARA2_RELATIONSHIP.PORTRAITS:
				for kind in ["start", "outline"]:
					_step(session.act("mara2_align", [portrait, kind, BASEMENT.MARA2_RELATIONSHIP.PORTRAITS[portrait][kind]]), tier + " aligns Mara 2 %s/%s" % [portrait, kind])
			_step(session.act("mara2_overlay"), tier + " overlays Mara 2's degraded portraits")
			_move_basement(session, ["H0_PERSONALITY_ARCHIVE"])
			for backup_owner in BASEMENT.MARA2_RELATIONSHIP.BACKUPS:
				_step(session.act("mara2_backup", backup_owner), tier + " verifies Mara 2 backup " + backup_owner)
			for index in BASEMENT.MARA2_RELATIONSHIP.GAPS:
				_step(session.act("mara2_cell", [index, BASEMENT.MARA2_RELATIONSHIP.CHECKSUM[index]]), tier + " restores Mara 2 checksum cell %d" % index)
			_step(session.act("mara2_checksum"), tier + " validates Mara 2's original checksum")
			_step(session.act("mara2_confess"), tier + " hears Mara 2's account")
			_step(session.act("mara2_choose", "separated"), tier + " preserves Mara 2's separated identity")
			_move_basement(session, ["H0_COLOR_SEPARATION", "M1_COLOR_ROOM_ENTRY", "M1_NORTH_ARCHIVE_HALL", "M1_CENTRAL_HALL"])
		_:
			_expect(false, "unknown relationship route owner " + owner)
	if errors.size() != errors_before:
		return false
	return _expect(
		bool(game.get_value("meta_progress.servants.%s.core_event_complete" % owner, false)),
		"%s route commits %s as a completed relationship event" % [tier, owner]
	)


func _run_tier_to_decision(session, slot_id: String, tier: String, expected_count: int) -> bool:
	if not _step(session.act("j4_confirm", true), "J4 closes the optional relationship hub"):
		return false
	for page in BASEMENT.JOURNAL_FOUR.ORDER:
		_step(session.act("j4_page", page), "J4 places " + page)
	_step(session.act("j4_order"), "J4 verifies chronological order")
	if not _step(session.act("j4_read"), "J4 restores the base journal variant"):
		return false
	var expected_j4 := "J4_FULL" if expected_count == 5 else ("J4_EXPANDED" if expected_count >= 2 else "J4_BASE")
	if not _expect(game.get_value("meta_progress.knowledge_entries.j4_variant", "") == expected_j4, "%s route selects %s" % [tier, expected_j4]):
		return false
	if not bool(game.get_value("meta_progress.servants.edgar.core_event_complete", false)):
		if not _step(session.act("j4_minimum"), "%s route receives minimum core access without relationship reward" % tier):
			return false
	if not _reload(slot_id, "%s J4 reload" % tier):
		return false
	session.initialize()
	_step(session.act("e5_enter"), "E5 begins the last normal evening")
	_step(session.act("e5_sit"), "E5 takes the subject seat")
	var question: String = {"LOW":"wish", "MID":"leave", "HIGH":"stay", "ALL":"wish"}[tier]
	_step(session.act("e5_question", question), "%s E5 asks one optional question" % tier)
	if not _step(session.act("e5_finish", true), "%s E5 commits its relationship settlement" % tier):
		return false
	if not _expect(game.get_value("meta_progress.event_history.E5.variant_id", "") == tier, "%s route records the matching E5 variant" % tier):
		return false
	if bool(game.get_value("meta_progress.servants.mara2.core_event_complete", false)):
		_step(session.act("e6_move", "M1_NORTH_ARCHIVE_HALL"), tier + " visits Mara 2's optional name follow-up")
		_step(session.act("e6_mara2", "write"), tier + " records Mara 2's chosen name")
	_step(session.act("e6_move", "H0_CLOCK_MACHINE"), "E6 approaches Edgar's core access")
	if bool(game.get_value("meta_progress.servants.edgar.core_event_complete", false)):
		_step(session.act("e6_edgar", "ask"), tier + " asks Edgar to open the core path")
	else:
		_step(session.act("e6_open"), tier + " opens the core path without relationship rewards")
	if not _step(session.act("e6_enter", true), "E6 enters the F0 meta-puzzle"):
		return false
	if not _reload(slot_id, "%s F0 entry reload" % tier):
		return false
	session.initialize()
	if not _solve_core_meta_puzzle(session):
		return false
	if not _run_final_records(session, slot_id):
		return false
	if not _expect(session.stage() == "EDC", "%s continuous campaign reaches the final decision" % tier):
		return false
	return _expect(_completed_servants(session.snapshot()) == expected_count, "%s route preserves its relationship count at EDC" % tier)


func _solve_core_meta_puzzle(session) -> bool:
	var room_rules = BASEMENT.CORE_ROOMS
	for slot in range(4):
		var local: Dictionary = room_rules.progress(session.snapshot())
		var source: int = local["tiles"].find(room_rules.ROOMS[slot])
		_step(session.act("f0a_select", slot), "F0-A selects target slot %d" % slot)
		_step(session.act("f0a_select", source), "F0-A swaps source tile %d" % source)
		for turn in range((slot + 1) % 4):
			_step(session.act("f0a_rotate", slot), "F0-A rotates slot %d" % slot)
	if not _step(session.act("f0a_signal"), "F0-A closes the room feedback loop"):
		return false
	for room in BASEMENT.CORE_SAMPLES.ROOMS:
		_step(session.act("f0b_inspect", [room, 0]), "F0-B inspects maintenance sample " + room)
		if not _step(session.act("f0b_send", room), "F0-B verifies channel " + room):
			return false
	for layer in ["B4", "C5", "D4"]:
		_step(session.act("f0c", {"action": "anchor", "layer": layer, "value": 0}), "F0-C anchors " + layer)
	for index in range(2):
		_step(session.act("f0c", {"action": "rotate", "layer": "B4"}), "F0-C rotates B4")
	_step(session.act("f0c", {"action": "flip", "layer": "C5"}), "F0-C flips C5")
	for index in range(3):
		_step(session.act("f0c", {"action": "rotate", "layer": "C5"}), "F0-C rotates C5")
	if not _step(session.act("f0c", {"action": "verify"}), "F0-C verifies the overlay"):
		return false
	for point in ["PATH", "SPLIT", "AUTH"]:
		_step(session.act("f0c", {"action": "inspect", "value": point}), "F0-C inspects " + point)
	for index in range(BASEMENT.CORE_ROLES.RECORDS.size()):
		_step(session.act("f0d_select", BASEMENT.CORE_ROLES.RECORDS[index]), "F0-D selects record %d" % index)
		_step(session.act("f0d_place", index), "F0-D places record %d" % index)
	if not _step(session.act("f0d_verify"), "F0-D verifies all record roles"):
		return false
	var mark: Dictionary = game.get_value("meta_progress.knowledge_entries.self_authored_mark", {})
	var mark_type := String(mark.get("type", ""))
	if not _expect(mark_type in BASEMENT.CORE_SELF.MARKS, "F0-E receives the actual A1 mark type"):
		return false
	for piece in BASEMENT.CORE_SELF.MARKS[mark_type]:
		_step(session.act("f0e_piece", piece), "F0-E reconstructs mark piece " + str(piece))
	_step(session.act("f0e_past"), "F0-E authenticates the past mark")
	_step(session.act("f0e_author", "subject"), "F0-E restores SUBJECT authority")
	if not _step(session.act("f0e_intent", "undecided"), "F0-E records a non-binding undecided intent"):
		return false
	return _expect(session.stage() == "F1" and session.snapshot()["ending_run"]["final_decision"] == "unset", "F0-E reaches F1 without choosing an ending")


func _run_final_records(session, slot_id: String) -> bool:
	_step(session.act("f1_enter"), "F1 enters the original-record chamber")
	_step(session.act("f1_inspect"), "F1 inspects the playback device")
	var mark_type := String(game.get_value("meta_progress.knowledge_entries.self_authored_mark.type", ""))
	_step(session.act("f1_authenticate", mark_type), "F1 authenticates with the A1 mark")
	for index in range(8):
		if not _step(session.act("f1_play", index), "F1 plays segment %d" % index):
			return false
		if index == 3 and not _reload(slot_id, "F1 partial playback reload"):
			return false
	_step(session.act("f1_page"), "F1 reads the fifth-page source")
	if not _step(session.act("f1_write", "subject"), "J5 writes the fifth journal page as SUBJECT"):
		return false
	_step(session.act("f2_enter"), "F2 begins the researcher confrontation")
	_step(session.act("f2_recap"), "F2 assembles the six mandatory facts")
	if not _step(session.act("f2_finish"), "F2 completes without relationship gates"):
		return false
	_step(session.act("f3_enter"), "F3 enters final inspection and locks sleep")
	for object_id in ["wake", "stay", "notebook"]:
		_step(session.act("f3_inspect", object_id), "F3 inspects " + object_id)
	_step(session.act("f3_summary"), "F3 compares both procedures")
	if not _step(session.act("f3_open"), "F3 opens the balanced final decision"):
		return false
	return _reload(slot_id, "F3 decision boundary reload")


func _run_both_endings(slot_id: String, tier: String, expected_count: int) -> void:
	var clone: Dictionary = saves.create_f3_reselect_slot(slot_id)
	if not _step(clone, "%s F3 creates an independent ending reselect slot" % tier):
		return
	var replay_slot := String(clone.get("slot_id", ""))
	if not _expect(not replay_slot.is_empty() and replay_slot != slot_id, "%s F3 reselect slot is distinct from its campaign slot" % tier):
		return
	_replay_slots.append(replay_slot)
	_run_ending(slot_id, "reality", tier, expected_count)
	if not _reload(replay_slot, "%s F3 replay slot reload" % tier):
		return
	var replay := BASEMENT.new(game, saves, replay_slot)
	if not _step(replay.initialize(), "%s replay session initializes at EDC" % tier):
		return
	_expect(replay.snapshot()["ending_run"].get("reselect_used", false), "%s replay slot records reselect provenance" % tier)
	_run_ending(replay_slot, "stay", tier, expected_count)


func _run_ending(slot_id: String, branch: String, tier: String, expected_count: int) -> void:
	var session := BASEMENT.new(game, saves, slot_id)
	var route_label := "%s %s" % [tier, branch]
	if not _step(session.initialize(), route_label + " ending initializes"):
		return
	if not _expect(session.stage() == "EDC", route_label + " ending starts from the same decision boundary"):
		return
	var meta_root := "user://__test_full_campaign_meta_%s_%s_%s" % [tier.to_lower(), branch, Time.get_ticks_usec()]
	_meta_roots.append(meta_root)
	session.ending_meta_store = ENDING_META.new(meta_root)
	if not _step(session.act("edc_commit", branch), route_label + " EDC commits the branch"):
		return
	if expected_count == 5:
		if not _expect(session.snapshot()["ending_run"]["current_node_id"] == "ED_ALL_CEREMONY", route_label + " enters the ALL identity ceremony"):
			return
		for owner in BASEMENT.ENDING_ENTRY.OWNERS:
			if not _step(session.act("ending_identity", owner), route_label + " authenticates " + owner):
				return
		if not _step(session.act("ending_authority"), route_label + " confirms SUBJECT authority"):
			return
		if not _step(session.act("ending_sign"), route_label + " signs the ALL ceremony"):
			return
		if not _expect(session.snapshot()["ending_run"].get("all_ceremony_seen", false), route_label + " records the completed ALL ceremony"):
			return
	else:
		var expected_entry := "EDR_ENTRY" if branch == "reality" else "EDS_ENTRY"
		if not _expect(session.snapshot()["ending_run"]["current_node_id"] == expected_entry, route_label + " skips the ALL-only ceremony"):
			return
	for index in range(2):
		var current := String(session.snapshot()["ending_run"]["current_node_id"])
		if not _step(session.act("ending_continue", current), route_label + " ending acknowledges " + current):
			return
	if branch == "reality":
		_run_reality_ending(session, slot_id, tier, expected_count)
	else:
		_run_stay_ending(session, slot_id, tier, expected_count)


func _run_reality_ending(session, slot_id: String, tier: String, expected_count: int) -> void:
	for owner in BASEMENT.REALITY_WAKE.OWNERS:
		if not _step(session.act("reality_farewell", owner), "reality reads " + owner + " handoff"):
			return
	for node in ["EDR_DISCONNECT", "EDR_WAKE_BODY"]:
		if not _step(session.act("reality_continue", node), "reality acknowledges " + node):
			return
	for object_id in ["OBJ_REALITY_HAND", "OBJ_REALITY_BREATH_MONITOR"]:
		_step(session.act("reality_body", object_id), "reality checks " + object_id)
	if not _step(session.act("reality_body_finish"), "reality completes the body check"):
		return
	for page in BASEMENT.FIELD_NOTEBOOK.REQUIRED:
		_step(session.act("field_read", page), "reality reads " + page)
	if not _step(session.act("field_finish"), "reality closes the required field notebook pages"):
		return
	for status_id in BASEMENT.FIELD_NOTEBOOK.EXIT:
		_step(session.act("field_inspect", status_id), "reality checks " + status_id)
	if not _step(session.act("field_unlock"), "reality unlocks the facility exit"):
		return
	_step(session.act("surface_airlock"), "reality approaches the airlock")
	_step(session.act("surface_enter"), "reality enters the surface threshold")
	if not _step(session.act("surface_outside"), "reality steps into the final exterior frame"):
		return
	_step(session.act("surface_look", "center"), "reality keeps a neutral final gaze")
	for index in range(8):
		if not _step(session.act("surface_tick"), "reality final frame second %d" % (index + 1)):
			return
	_finish_credits(session, slot_id, "reality", tier, expected_count)


func _run_stay_ending(session, slot_id: String, tier: String, expected_count: int) -> void:
	for index in range(3):
		_step(session.act("stay_memory", index), "stay confirms memory principle %d" % index)
	_step(session.act("stay_memory_finish"), "stay preserves all three truth principles")
	_step(session.act("stay_appearance", "contextual"), "stay selects contextual appearance")
	_step(session.act("stay_appearance_finish"), "stay confirms the reversible appearance rule")
	for owner in BASEMENT.STAY_CHARTER.OWNERS:
		_step(session.act("stay_propose", owner), "stay returns autonomy to " + owner)
	if not _step(session.act("stay_autonomy_finish"), "stay completes the five-person autonomy charter"):
		return
	_step(session.act("story_dine"), "stay enters the dining room")
	_step(session.act("story_sit"), "stay chooses the final table")
	_step(session.act("story_write", 0), "stay writes the first notebook sentence")
	_step(session.act("story_write", 1), "stay writes the second notebook sentence")
	_step(session.act("story_final"), "stay enters the final frame")
	_step(session.act("story_tick"), "stay final frame first beat")
	_step(session.act("story_tick"), "stay final frame second beat")
	if not _step(session.act("story_finish"), "stay reaches the credits boundary"):
		return
	_finish_credits(session, slot_id, "stay", tier, expected_count)


func _finish_credits(session, slot_id: String, branch: String, tier: String, expected_count: int) -> void:
	if not _step(session.act("credits_start"), branch + " credits start"):
		return
	_step(session.act("credits_next", 0), branch + " credits page two")
	_step(session.act("credits_next", 1), branch + " credits page three")
	if not _step(session.act("credits_finish"), branch + " credits finish"):
		return
	_expect(session.stage() == "POST_CREDITS", branch + " reaches POST_CREDITS")
	_expect(saves.inspect_slot(slot_id).get("save_point_id", "") == "SAVE_ENDING_COMPLETE", branch + " ending completion is stored on disk")
	_reload(slot_id, branch + " completed-ending reload")
	_expect(game.get_value("ending_run.final_decision", "") == branch, branch + " decision survives completed-ending reload")
	_expect(_completed_servants(game.get_snapshot()) == expected_count, "%s %s ending preserves %d completed relationships" % [tier, branch, expected_count])
	_expect(game.get_value("meta_progress.event_history.E5.variant_id", "") == tier, "%s %s ending preserves its E5 relationship tier" % [tier, branch])


func _make_cleaner(session) -> void:
	for index in range(5):
		_step(session.act("c_pour", "water"), "C3 pours water %d" % (index + 1))
	_step(session.act("c_pour", "stabilizer"), "C3 adds stabilizer")
	_step(session.act("c_disperse"), "C3 disperses stabilizer")
	for index in range(2):
		_step(session.act("c_pour", "active"), "C3 adds active material %d" % (index + 1))
	_step(session.act("c_mix"), "C3 mixes the cleaner")
	_step(session.act("c_test"), "C3 verifies the 5:1:2 cleaner")


func _solve_clock_board(session) -> void:
	for index in range(4):
		var board: Dictionary = session.local_state()["board"]
		var wanted: String = CLOCK.SOLUTION[CLOCK.ROLES[index]]
		var other: int = board["pieces"].find(wanted)
		if other != index:
			_step(session.act("board_swap", [index, other]), "B3 swaps clock rubbing %d" % index)
		for turn in range(4):
			if int(session.local_state()["board"]["rotations"][index]) != 0:
				_step(session.act("board_rotate", index), "B3 rotates clock rubbing %d" % index)
	if not session.local_state()["board"]["library_back"]:
		_step(session.act("board_flip"), "B3 flips the library rubbing")


func _travel_chapter_one(session, target: String) -> void:
	var room := String(game.get_value("loop_state.location_id"))
	if room == target:
		return
	if room == "M1_LIBRARY_INNER":
		_step(session.act("move", "M1_LIBRARY_OUTER"), "chapter one leaves inner library")
	if game.get_value("loop_state.location_id") != "M1_CENTRAL_HALL":
		_step(session.act("move", "M1_CENTRAL_HALL"), "chapter one returns to central hall")
	_step(session.act("move", target), "chapter one travels to " + target)


func _travel_black_mirror(session, target: String) -> void:
	var parents := {
		"M1_MIRROR_GALLERY": "M1_PARLOR",
		"M1_TOOL_ROOM": "M1_SERVANT_COMMON",
		"M1_KITCHEN": "M1_SERVANT_COMMON",
		"M1_COLOR_ROOM_ENTRY": "M1_NORTH_ARCHIVE_HALL",
		"M1_LIBRARY_INNER": "M1_LIBRARY_OUTER",
	}
	var room := String(game.get_value("loop_state.location_id"))
	if room == target:
		return
	if parents.has(room):
		_step(session.act("move", parents[room]), "mirror route leaves " + room)
	if game.get_value("loop_state.location_id") != "M1_CENTRAL_HALL":
		_step(session.act("move", "M1_CENTRAL_HALL"), "mirror route returns to central hall")
	if parents.has(target):
		_step(session.act("move", parents[target]), "mirror route approaches " + target)
	if target == "M1_LIBRARY_INNER":
		_step(session.act("routine"), "mirror route opens the inner library window")
	_step(session.act("move", target), "mirror route travels to " + target)


func _move_basement(session, path: Array) -> void:
	for room in path:
		_step(session.act("move", room), "basement route moves to " + str(room))


func _reload(slot_id: String, label: String) -> bool:
	return _step(LoadCoordinator.new(game, saves).load_and_install(slot_id), label)


func _completed_servants(state: Dictionary) -> int:
	var count := 0
	for servant in state["meta_progress"]["servants"].values():
		if servant["core_event_complete"]:
			count += 1
	return count


func _step(result: Dictionary, label: String) -> bool:
	return _expect(bool(result.get("ok", false)), label + ("" if result.get("ok", false) else ": " + str(result.get("text", result.get("error_ids", result)))))


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		errors.append(message)
	return condition


func _cleanup() -> void:
	for slot_id in _test_slots:
		saves.delete_test_slot(slot_id)
	for replay_slot in _replay_slots:
		saves.delete_test_slot(replay_slot)
	for path in _meta_roots:
		_remove_tree(path)
	game.reset_for_test()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
