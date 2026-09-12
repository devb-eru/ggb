extends RefCounted

const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const SLOT := "__test_chapter_one"
var errors := PackedStringArray()

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": PackedStringArray(["ERR_TEST_DISK_UNAVAILABLE"])}


func run(tree: SceneTree) -> Dictionary:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var initial := GameState.get_snapshot()
	initial["meta_progress"]["knowledge_entries"]["PROLOGUE_COMPLETE"] = true
	initial["meta_progress"]["knowledge_entries"]["prologue_notebook_entries"] = ["주방의 규칙적인 진동"]
	initial["loop_state"]["day_index"] = 1
	_expect(StateWriter.new(GameState).install_snapshot(initial, GameState.revision, &"CH1_SEED").get("ok", false), "chapter seed")
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().get("ok", false), "chapter initialization")
	var before_failed_save := GameState.get_snapshot()
	var rejected_save := RejectingSave.new()
	var failing_session := SESSION.new(GameState, rejected_save, SLOT)
	_expect(not failing_session.act("mark", "sentence").get("ok", false), "save error rejects event")
	_expect(GameState.get_snapshot() == before_failed_save, "save error rolls back live state")
	rejected_save.free()
	_expect(session.stage() == "A1", "first morning routes to A1")
	_expect(not session.act("move", "M1_LIBRARY_INNER").get("ok", false), "no early inner library bypass")
	_expect(session.act("mark", "house_glyph").get("ok", false), "A1 mark")
	_expect(not session.act("confirm_mark").get("ok", false), "mark needs physical reset")
	_expect(not session.act("mark", "sentence").get("ok", false), "cannot replace mark before verification")
	_expect(session.act("routine").get("ok", false), "routine shortcut")
	_expect(session.sleep().get("ok", false), "normal sleep")
	_expect(session.stage() == "A2", "next morning routes to A2")
	_expect(not session.local_state()["routine_done"], "routine physical state resets")
	_expect(session.act("confirm_mark").get("ok", false), "A2 confirm")
	_expect(not session.act("move", "M1_SERVANT_COMMON").get("ok", false), "rooms cannot teleport across hall")
	_travel(session, "M1_SERVANT_COMMON")
	session.act("read_schedule", "edgar")
	_expect(not session.act("schedule_window", "after_tea_before_bell").get("ok", false), "two independent schedule documents required")
	session.act("read_schedule", "luca")
	_expect(not session.act("schedule_window", "morning").get("ok", false), "wrong schedule is local retry")
	_expect(session.act("schedule_window", "after_tea_before_bell").get("ok", false), "B1 valid window")
	session.act("routine")
	_travel(session, "M1_LIBRARY_OUTER")
	_expect(session.act("move", "M1_LIBRARY_INNER").get("ok", false), "B2 entry")
	session.act("inspect_inner", "alcove")
	session.act("inspect_inner", "index")
	session.act("inspect_inner", "index")
	_expect(int(session.local_state()["attention"]) == 1, "repeat object does not farm attention")
	session.act("inspect_inner", "drawer")
	_expect(session.local_state()["edgar_state"] == "entering", "deterministic Edgar entry")
	var before_visit := GameState.get_snapshot()
	session.act("edgar_hide")
	_expect(session.local_state()["edgar_state"] == "hidden", "hide branch")
	session.act("edgar_leave")
	_expect(session.local_state()["edgar_state"] == "absent", "hidden branch rejoins investigation")
	StateWriter.new(GameState).install_snapshot(before_visit, GameState.revision, &"CH1_REPLAY_VISIT")
	session.act("edgar_talk")
	_expect(session.local_state()["edgar_state"] == "absent", "caught branch rejoins without failure")
	_expect("B2_CAUGHT" in GameState.get_value(&"meta_progress.servants.edgar.residual_memory", []), "direct encounter persists in servant memory")
	session.act("inspect_inner", "desk")
	session.act("j1_piece", 2)
	_expect(not session.act("j1_restore").get("ok", false), "J1 partial cannot restore")
	session.act("j1_clear")
	for index in range(3):
		session.act("j1_piece", index)
		session.act("j1_flip", index)
	_expect(session.act("j1_restore").get("ok", false), "J1 restored")
	_expect(int(GameState.get_value(&"meta_progress.journal_stage")) == 1, "journal stage one")
	session.act("inspect_inner", "link")
	for room in SESSION.CLOCK_ROOMS:
		_travel(session, room)
		session.act("rub_clock")
	_expect(session.local_state()["rubbed"].size() == 4, "four physical rubbings")
	_expect((GameState.get_value(&"loop_state.inventory") as Array).size() == 4, "physical rubbings are registered inventory")
	_expect(not CLOCK.inspect_layout(session.local_state()["board"])["ok"], "initial board is unsolved")
	session.act("board_check")
	_expect(not session.known("clock_network_layout_solved"), "wrong board remains local")
	_solve_board(session)
	_expect(session.act("board_check").get("ok", false), "board check commit")
	_expect(session.known("clock_network_layout_solved"), "B3-A solved")
	for role in CLOCK.ROLES:
		session.act("role", [role, CLOCK.SOLUTION[role]])
	var before_phase: String = session.local_state()["phase"]
	session.act("test_clock")
	_expect(session.local_state()["phase"] == before_phase and not session.local_state()["clock_locked"], "weak test does not set phase or break pin")
	_expect(not session.act("activate_clock", false).get("ok", false), "actual run requires confirmation")
	session.act("activate_clock", true)
	_expect(session.stage() == "BF", "wrong phase physically locks the clock")
	_expect(not session.act("phase", "+1").get("ok", false), "cannot repair locked clock in same day")
	var failure := GameState.get_value(&"meta_progress.failure_knowledge.B3_B", {}) as Dictionary
	_expect(failure.get("category", "") == "phase_simultaneous", "precise failure category")
	_expect(failure.get("verified_roles", {}).size() == 4, "preserve tested roles")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload after hard failure")
	_expect(session.stage() == "BF", "reload cannot evade failure")
	_travel(session, "M2_BEDROOM")
	_expect(session.sleep().get("ok", false), "sleep after hard failure")
	_expect(session.local_state()["rubbed"].is_empty() and not session.local_state()["clock_locked"], "rubbings and broken pin reset")
	_expect((GameState.get_value(&"loop_state.inventory") as Array).is_empty(), "physical inventory cleared on sleep")
	_expect(GameState.get_value(&"loop_state.location_id") == "M2_BEDROOM", "always return to same bedroom")
	_expect(int(GameState.get_value(&"meta_progress.journal_stage")) == 1, "J1 survives reset")
	_expect("B2_CAUGHT" in GameState.get_value(&"meta_progress.servants.edgar.residual_memory", []), "Edgar memory survives reset")
	_expect(session.act("shortcut").get("ok", false), "BSHORT rebuilds physical materials from knowledge")
	_expect(session.local_state()["rubbed"].size() == 4, "shortcut reacquires four rubbings")
	session.act("phase", "+1")
	session.act("activate_clock", true)
	_expect(session.stage() == "B4", "correct phase leads to recording, not auto J2")
	session.act("record_wave")
	_expect(GameState.get_value(&"meta_progress.failure_knowledge.B3_B.status") == "resolved", "success resolves active failure")
	_travel(session, "M1_NORTH_ARCHIVE_HALL")
	session.act("move", "M1_LIBRARY_INNER")
	_expect(not session.act("restore_j2").get("ok", false), "misaligned wave is local retry")
	for index in range(3):
		session.act("wave_rotate")
	_expect(session.act("restore_j2").get("ok", false), "wave alignment restores J2")
	_expect(session.stage() == "J2_COMPLETE", "chapter one ends at J2")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload chapter complete")
	_expect(session.stage() == "J2_COMPLETE", "chapter completion persists")
	_expect(not session.act("restore_j2").get("ok", false), "completed journal cannot be overwritten")
	_validate_clock_truth_table()
	await _validate_view(tree, session)
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	return {"ok": errors.is_empty(), "errors": errors}


func _travel(session: ChapterOneSession, target: String) -> void:
	var room := String(GameState.get_value(&"loop_state.location_id"))
	if room == target:
		return
	if room == "M1_LIBRARY_INNER":
		_expect(session.act("move", "M1_LIBRARY_OUTER").get("ok", false), "leave inner through outer library")
	if GameState.get_value(&"loop_state.location_id") != "M1_CENTRAL_HALL":
		_expect(session.act("move", "M1_CENTRAL_HALL").get("ok", false), "travel through central hall")
	_expect(session.act("move", target).get("ok", false), "travel destination " + target)


func _solve_board(session: ChapterOneSession) -> void:
	for index in range(4):
		var board := session.local_state()["board"] as Dictionary
		var wanted: String = CLOCK.SOLUTION[CLOCK.ROLES[index]]
		var other := (board["pieces"] as Array).find(wanted)
		if other != index:
			session.act("board_swap", [index, other])
		for turn in range(4):
			if int(session.local_state()["board"]["rotations"][index]) != 0:
				session.act("board_rotate", index)
	if not session.local_state()["board"]["library_back"]:
		session.act("board_flip")


func _validate_clock_truth_table() -> void:
	var solutions := 0
	for a in CLOCK.CLOCKS:
		for b in CLOCK.CLOCKS:
			for c in CLOCK.CLOCKS:
				for d in CLOCK.CLOCKS:
					for phase in CLOCK.PHASES:
						var roles := {"reference": a, "relay": b, "output": c, "excluded": d}
						if CLOCK.activate(roles, phase)["ok"]:
							solutions += 1
	_expect(solutions == 1, "24-3 clock solution must be unique across all role/phase inputs")


func _validate_view(tree: SceneTree, session: ChapterOneSession) -> void:
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._objective_label.text.contains("검은 거울"), "chapter boundary objective visible")
	view._open_notebook()
	_expect(view._modal_active, "chapter notebook opens")
	_expect(view._modal_body.get_child_count() == 4, "notebook reuses common scroll without stale modal children")
	var pages := (view._modal_body.get_child(2).get_child(0) as Label).text
	_expect(pages.contains("주방의 규칙적인 진동") and pages.contains("표식"), "chapter notebook displays both prologue and current records")
	view._close_modal()
	view._open_notebook()
	_expect(view._modal_body.get_child_count() == 4, "same-frame notebook reopen has no duplicate children")
	view._close_modal()
	view._apply_reading_text_scale(2.0)
	view._open_notebook()
	_expect(view._modal_body.get_child(2).get_child(0).get_theme_font_size("font_size") == 44, "Notebook respects 200 percent reading text scale")
	view._close_modal()
	view._render_room()
	await tree.process_frame
	var back := view._hotspot_layer.get_node("BACK") as Button
	back.grab_focus()
	view._render_room()
	await tree.process_frame
	_expect(tree.root.gui_get_focus_owner() == view._hotspot_layer.get_node("BACK"), "keyboard focus restored after room rebuild")
	var completed := GameState.get_snapshot()
	var board_state := completed.duplicate(true)
	board_state["meta_progress"]["journal_stage"] = 1
	board_state["meta_progress"]["knowledge_entries"]["b4_waveform_acquired"] = false
	board_state["loop_state"]["location_id"] = "M1_GREAT_CLOCK"
	var board_local: Dictionary = board_state["loop_state"]["event_local_states"]["CHAPTER_ONE"]
	board_local["signal_generated"] = false
	board_local["clock_locked"] = false
	board_local["roles"] = {}
	StateWriter.new(GameState).install_snapshot(board_state, GameState.revision, &"CH1_UI_FIXTURE")
	view._render_room()
	await tree.process_frame
	var role_button := view._hotspot_layer.get_node("ROLE_reference") as OptionButton
	role_button.grab_focus()
	role_button.item_selected.emit(CLOCK.CLOCKS.find("parlor") + 1)
	await tree.process_frame
	_expect(session.local_state()["roles"].get("reference", "") == "parlor", "real role control persists player input")
	_expect(tree.root.gui_get_focus_owner() == view._hotspot_layer.get_node("ROLE_reference"), "role selection preserves keyboard focus")
	if "--capture-chapter-one" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := tree.root.get_texture().get_image()
		capture.save_png("user://chapter_one_roles.png")
		print("CHAPTER_ONE_CAPTURE: " + ProjectSettings.globalize_path("user://chapter_one_roles.png"))
	StateWriter.new(GameState).install_snapshot(completed, GameState.revision, &"CH1_UI_RESTORE")
	_expect(session.initialize().get("ok", false), "restore authoritative completion save after UI test")
	view.queue_free()
	await tree.process_frame
	# The production bootstrap must route persisted post-prologue saves into the chapter.
	var bootstrap := tree.current_scene
	bootstrap._on_load_game_requested(SLOT)
	await tree.process_frame
	_expect(bootstrap.get_node_or_null("BlackMirror") != null, "J2 load routes to next chapter instead of prologue completion screen")
	bootstrap._on_prologue_return_to_title()
	await tree.process_frame
	_expect(session.stage() == "J2_COMPLETE", "return to title does not overwrite chapter state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
