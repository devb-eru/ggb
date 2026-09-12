extends RefCounted

const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const SLOT := "__test_chapter_one"
var errors := PackedStringArray()

class RejectingSave extends Node:
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok": false, "error_ids": PackedStringArray(["ERR_TEST_DISK_UNAVAILABLE"])}

class RejectThirdSave extends Node:
	var calls := 0
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		calls += 1
		if calls == 3:
			return {"ok": false, "error_ids": PackedStringArray(["ERR_TEST_CHOICE_COMMIT"])}
		return delegate.save_snapshot(slot, point, state, revision, transaction)


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
	_expect(not failing_session.record_viewed_line("Edgar", "A viewed line", "en-US").get("ok", false), "history persistence failure reported")
	_expect(GameState.get_snapshot() == before_failed_save, "history persistence failure rolls back live state")
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
	var edgar_document := session.act("read_schedule", "edgar")
	_expect(edgar_document.get("text_id", "") == "CH1_B1_TEXT_EDGAR", "schedule document carries display translation ID")
	_expect(edgar_document.get("text", "") == SESSION.DOCUMENTS["edgar"], "original document retained independently of display language")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload translated document save")
	var resumed_document := session.initialize()
	_expect(resumed_document.get("text_id", "") == "CH1_B1_TEXT_EDGAR", "reload retains document translation ID")
	_expect(resumed_document.get("text", "") == SESSION.DOCUMENTS["edgar"], "reload retains original document text")
	_expect(not session.act("schedule_window", "after_tea_before_bell").get("ok", false), "two independent schedule documents required")
	session.act("read_schedule", "luca")
	_expect(not session.act("schedule_window", "morning").get("ok", false), "wrong schedule is local retry")
	_expect(session.act("schedule_window", "after_tea_before_bell").get("ok", false), "B1 valid window")
	session.act("routine")
	_travel(session, "M1_LIBRARY_OUTER")
	_expect(session.act("move", "M1_LIBRARY_INNER").get("ok", false), "B2 entry")
	_expect(session.act("inspect_inner", "alcove").get("text_id", "") == "CH1_INNER_ALCOVE", "alcove observation has translation ID")
	_expect(session.act("inspect_inner", "index").get("text_id", "") == "CH1_INNER_INDEX", "quiet index observation has no premature footsteps")
	session.act("inspect_inner", "index")
	_expect(int(session.local_state()["attention"]) == 1, "repeat object does not farm attention")
	var drawer_visit := session.act("inspect_inner", "drawer")
	_expect(drawer_visit.get("text_id", "") == "CH1_INNER_DRAWER_VISIT", "drawer combines observation and deterministic visit translation")
	_expect(drawer_visit.get("text", "").contains("문밖에서 발소리"), "visit retains original footsteps source")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "observation with visit reload")
	_expect(session.initialize().get("text_id", "") == "CH1_INNER_DRAWER_VISIT", "reload preserves composite observation ID")
	_expect(session.local_state()["edgar_state"] == "entering", "deterministic Edgar entry")
	var before_visit := GameState.get_snapshot()
	_expect(session.act("edgar_hide").get("text_id", "") == "CH1_B2_HIDDEN", "hide narration has translation ID")
	_expect(session.local_state()["edgar_state"] == "hidden", "hide branch")
	_expect(session.act("edgar_leave").get("text_id", "") == "CH1_B2_LEFT", "departure narration has translation ID")
	_expect(session.local_state()["edgar_state"] == "absent", "hidden branch rejoins investigation")
	StateWriter.new(GameState).install_snapshot(before_visit, GameState.revision, &"CH1_REPLAY_VISIT")
	_expect(session.act("edgar_talk").get("text_id", "") == "CH1_B2_NORMAL", "normal Edgar dialogue translation")
	_expect(session.local_state()["edgar_state"] == "absent", "caught branch rejoins without failure")
	_expect("B2_CAUGHT" in GameState.get_value(&"meta_progress.servants.edgar.residual_memory", []), "direct encounter persists in servant memory")
	var after_normal_visit := GameState.get_snapshot()
	var alert_visit := before_visit.duplicate(true)
	alert_visit["meta_progress"]["servants"]["edgar"]["alert"] = 4
	_expect(StateWriter.new(GameState).install_snapshot(alert_visit, GameState.revision, &"CH1_ALERT_VISIT").get("ok", false), "high alert visit fixture")
	var alert_reply := session.act("edgar_talk")
	_expect(alert_reply.get("ok", false) and alert_reply.get("text_id", "") == "CH1_B2_ALERT", "high alert chooses suspicion dialogue without failure")
	_expect(session.local_state()["edgar_state"] == "absent", "high alert conversation also rejoins investigation")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload suspicion dialogue save")
	_expect(session.initialize().get("text_id", "") == "CH1_B2_ALERT", "reload retains high alert dialogue translation ID")
	_expect(StateWriter.new(GameState).install_snapshot(after_normal_visit, GameState.revision, &"CH1_ALERT_RESTORE").get("ok", false), "restore normal encounter state")
	session.act("inspect_inner", "desk")
	session.act("j1_piece", 2)
	_expect(session.act("j1_restore").get("text_id", "") == "CH1_J1_WRONG_ORDER", "J1 partial reports localized retry without damage")
	session.act("j1_clear")
	for index in range(3):
		session.act("j1_piece", index)
		session.act("j1_flip", index)
	var restored_j1 := session.act("j1_restore")
	_expect(restored_j1.get("ok", false) and restored_j1.get("text_id", "") == "CH1_J1_RESTORED", "J1 restored with display translation ID")
	_expect(restored_j1.get("text", "") == "\n\n".join(SESSION.J1_FRAGMENTS), "J1 original source preserved")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "J1 restored save reload")
	_expect(session.initialize().get("text_id", "") == "CH1_J1_RESTORED", "J1 restored translation ID survives reload")
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
	var saved_locale := TranslationServer.get_locale()
	var before_translation := GameState.get_snapshot()
	TranslationServer.set_locale("en_US")
	view._clear_hotspots()
	var j1_ui := session.local_state().duplicate(true)
	j1_ui["inspected"] = ["desk"]
	j1_ui["j1_order"] = [0, 1, 2]
	view._build_inner(j1_ui, 0)
	_expect(view._hotspot_layer.get_node("INNER_alcove").text.contains("Hiding place"), "English inner library exposes hiding affordance")
	_expect(view._hotspot_layer.get_node("INNER_link").text.contains("latch behind the portrait"), "English shortcut hotspot description")
	for id in ["DESK", "INDEX", "DRAWER", "ALCOVE", "GAP", "LINK", "LINK_OPEN"]:
		var base_id: String = "CH1_INNER_" + id
		var original: String = view._dialogue_texts.get_text(base_id, "ko-KR")
		var translated: String = view._dialogue_ui_text(base_id)
		_expect(not translated.is_empty() and translated != original and translated != base_id, "English observation available: " + id)
		_expect(view._dialogue_ui_text(base_id + "_VISIT") == translated + "\nFootsteps stop outside the door. The latch turns.", "English observation preserves both content and footsteps: " + id)
	_expect(view._hotspot_layer.get_node("J1_PIECE_0").text.contains("If you remember yesterday"), "English J1 opening clue")
	_expect(view._hotspot_layer.get_node("J1_PIECE_1").text.contains("passing a tremor to the next room"), "English J1 preserves relay clue")
	_expect(view._hotspot_layer.get_node("J1_PIECE_2").text.contains("one space beyond"), "English J1 preserves thirteenth sound clue")
	_expect(view._hotspot_layer.get_node("J1_FLIP_0").text == "Turn over", "English J1 flip control retains fragment ID")
	_expect(view._localized_notebook_entry("\n\n".join(SESSION.J1_FRAGMENTS)).contains("It is not the time that is wrong"), "Legacy J1 notebook translated only for display")
	for index in range(3):
		_expect(view._dialogue_texts.get_text("CH1_J1_FRAGMENT_%d" % index, "ko-KR") == SESSION.J1_FRAGMENTS[index], "Korean J1 fragments match canonical source")
	_expect(GameState.get_snapshot() == before_translation, "J1 translated presentation preserves saved state")
	view._update_objective()
	_expect(view._objective_label.text.contains("black mirror"), "English chapter boundary objective")
	view._clear_hotspots()
	view._build_loop_bedroom(session.local_state())
	_expect((view._hotspot_layer.get_node("SLEEP") as Button).text == "Bed · Go to sleep", "English bedroom sleep control")
	_expect((view._hotspot_layer.get_node("AS_ROUTINE") as Button).text.begins_with("Finish the routine"), "English bedroom routine control")
	view._open_mark_choices()
	_expect((view._modal_body.get_child(0) as Label).text == "A mark for myself", "English mark selection title")
	view._close_modal()
	view._confirm_sleep()
	_expect((view._modal_body.get_child(0) as Label).text == "Go to sleep", "English sleep confirmation title")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_translation, "language rendering and cancelled modals preserve gameplay state")
	view._open_schedule_board()
	_expect((view._modal_body.get_child(0) as Label).text == "When the inner archive is empty", "English schedule inference title")
	view._close_modal()
	view._feedback({"ok": true, "text": SESSION.DOCUMENTS["edgar"], "text_id": "CH1_B1_TEXT_EDGAR"})
	_expect(view._dialogue_label.text.contains("Work ledger"), "schedule feedback renders translated document")
	view._dismiss_dialogue_for_test()
	TranslationServer.set_locale(saved_locale)
	var history_before: int = GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"].size()
	view._show_dialogue([{"speaker": "주인공", "text": "Viewed history line"}, {"speaker": "주인공", "text": "Not yet viewed"}])
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"].size() == history_before + 1, "only presented sentence is recorded")
	view._present_dialogue_line()
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"].size() == history_before + 1, "redrawing same sentence does not duplicate history")
	view._dismiss_dialogue_for_test()
	var before_history_open := GameState.get_snapshot()
	view._open_dialogue_history()
	var history_body := (view._modal_body.get_child(2).get_child(0) as Label).text
	_expect(history_body.contains("Viewed history line") and not history_body.contains("Not yet viewed"), "history viewer excludes unshown sentence")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_history_open, "history viewing is read only")
	view._show_history_result({"ok": false, "entries": [{"text": "Readable history remains"}]})
	var partial_history := (view._modal_body.get_child(2).get_child(0) as Label).text
	_expect(partial_history.contains(view._dialogue_ui_text("CH1_HISTORY_READ_ERROR")) and partial_history.contains("Readable history remains"), "partial history failure shows warning and readable entries")
	view._close_modal()
	view._show_history_result({"ok": false, "entries": []})
	_expect((view._modal_body.get_child(2).get_child(0) as Label).text == view._dialogue_ui_text("CH1_HISTORY_READ_ERROR"), "unreadable history is not mislabeled as empty")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_history_open, "history error display preserves original records")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "history save reload")
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"] == before_history_open["meta_progress"]["dialogue_history"], "viewed history persists through reload")
	var good_save: Node = view.session._save
	var rejected_history_save := RejectingSave.new()
	view.session._save = rejected_history_save
	var before_retry := GameState.get_snapshot()
	view._show_dialogue([{"speaker": "주인공", "text": "Retry first line"}, {"speaker": "주인공", "text": "Retry second line"}])
	_expect(view._dialogue_index == 0 and GameState.get_snapshot() == before_retry, "failed display save leaves first sentence and state intact")
	view._dialogue_next.pressed.emit()
	_expect(view._dialogue_index == 0 and GameState.get_snapshot() == before_retry, "continue cannot skip a sentence whose history save failed")
	view.session._save = good_save
	rejected_history_save.free()
	view._dialogue_next.pressed.emit()
	_expect(view._dialogue_index == 1 and view._dialogue_label.text == "Retry second line", "recovered save advances by exactly one sentence")
	var retried_entries: Array = GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"]
	_expect(retried_entries.size() == before_retry["meta_progress"]["dialogue_history"]["entries"].size() + 2, "recovered save records both presented sentences once")
	view._dialogue_next.pressed.emit()
	_expect(not view._dialogue_active, "last sentence finish closes dialogue after successful recording")
	var before_menu := GameState.get_snapshot()
	var audio_store := AccessibilityProfileStore.new("user://__test_campaign_audio")
	audio_store.delete_test_profile()
	view._audio_profile_store = audio_store
	var pauses: Array[bool] = []
	var settings_updates: Array[Dictionary] = []
	view.menu_audio_pause_requested.connect(func(paused: bool): pauses.append(paused))
	view.audio_settings_changed.connect(func(settings: Dictionary): settings_updates.append(settings))
	view._open_menu()
	(view._modal_body.get_child(6) as Button).pressed.emit()
	_expect(view._audio_settings_panel.visible and view._modal_active and not view._modal_panel.visible, "campaign menu opens audio settings")
	view._audio_settings_panel.sliders.master.value = 23
	view._audio_settings_panel.apply.pressed.emit()
	_expect(is_equal_approx(audio_store.load_profile().profile.audio.master, 0.23), "campaign audio persists independently")
	_expect(settings_updates.size() == 1 and is_equal_approx(settings_updates[0].master, 0.23), "campaign audio signals runtime only after save")
	_expect(not view._audio_settings_panel.visible and view._modal_panel.visible and view._modal_active, "audio apply returns to pause menu")
	view._open_audio_settings()
	view._audio_settings_panel.sliders.master.value = 99
	view._audio_settings_panel.back.pressed.emit()
	view._close_modal()
	_expect(settings_updates.size() == 1 and not pauses.back(), "audio cancel does not apply and menu close resumes")
	_expect(GameState.get_snapshot() == before_menu, "campaign audio leaves progress and dialogue history unchanged")
	audio_store.delete_test_profile()
	view._open_menu()
	var history_button := view._modal_body.get_child(4) as Button
	_expect(history_button.text == view._dialogue_ui_text("CH1_HISTORY_TITLE"), "pause menu exposes history action")
	history_button.pressed.emit()
	_expect((view._modal_body.get_child(2).get_child(0) as Label).text.contains("Retry second line"), "actual menu action opens recorded transcript")
	(view._modal_body.get_child(3) as Button).pressed.emit()
	_expect(not view._modal_active and GameState.get_snapshot() == before_menu, "history close button preserves gameplay state")
	var before_choice_fixture := GameState.get_snapshot()
	var choice_fixture := before_choice_fixture.duplicate(true)
	choice_fixture["loop_state"]["event_local_states"]["CHAPTER_ONE"]["routine_done"] = false
	choice_fixture["loop_state"]["time_block"] = "morning"
	_expect(StateWriter.new(GameState).install_snapshot(choice_fixture, GameState.revision, &"CHOICE_SAVE_FIXTURE").get("ok", false), "choice save failure fixture")
	var staged_failure := RejectThirdSave.new()
	staged_failure.delegate = view.session._save
	view.session._save = staged_failure
	view._show_recorded_choice("Routine", "Attempt, not completion", [{"label": "Cancel", "action": view._close_modal}, {"label": "Attempt routine", "action": view._modal_act.bind("routine")}])
	(view._modal_body.get_child(4) as Button).pressed.emit()
	_expect(staged_failure.calls == 3, "choice records prompt and click before attempted gameplay save")
	var after_failed_choice := GameState.get_snapshot()
	_expect(not view.session.local_state()["routine_done"] and after_failed_choice["loop_state"]["time_block"] == "morning", "failed choice commit rolls back routine and time")
	var attempted_history: Array = after_failed_choice["meta_progress"]["dialogue_history"]["entries"]
	_expect(attempted_history.back()["variables"]["text"] == "Attempt routine", "failed gameplay commit retains actual click record")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "failed choice commit reload")
	_expect(not view.session.local_state()["routine_done"], "reload does not turn recorded click into completed action")
	view.session._save = staged_failure.delegate
	staged_failure.free()
	_expect(StateWriter.new(GameState).install_snapshot(before_choice_fixture, GameState.revision, &"CHOICE_SAVE_RESTORE").get("ok", false), "restore state after choice failure test")
	view._render_room()
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
	var hint_before := GameState.get_snapshot()
	view._open_notebook()
	var hint_button := view._modal_body.get_node_or_null("ClockHintsButton") as Button
	_expect(hint_button != null, "B3 notebook offers requested hints")
	if hint_button != null:
		hint_button.pressed.emit()
		for level in range(5):
			var read_hint := view._modal_body.get_child(4) as Button
			_expect(read_hint.text.contains("H%d" % (level + 1)), "hint progression requires explicit request")
			read_hint.pressed.emit()
			var expected_hint: String = preload("res://scripts/ui/clock_hint_texts.gd").text("B3_B", level, TranslationServer.get_locale())
			_expect(view._dialogue_label.text == expected_hint, "requested hint is shown in dialogue")
			view._dialogue_next.pressed.emit()
			_expect(view._modal_active and not view._dialogue_active, "hint returns to support menu without solving")
		_expect(view._modal_body.get_child_count() == 4, "final hint does not offer an out-of-range tier")
	view._close_modal()
	var hint_after := GameState.get_snapshot()
	_expect(hint_after.meta_progress.dialogue_history.entries.size() == hint_before.meta_progress.dialogue_history.entries.size() + 5, "only five requested hints enter durable history")
	hint_after.meta_progress.dialogue_history = hint_before.meta_progress.dialogue_history.duplicate(true)
	_expect(hint_after == hint_before, "hints do not change puzzle roles phase failure or relationships")
	var hint_texts := preload("res://scripts/ui/clock_hint_texts.gd")
	_expect(hint_texts.text("B3_A", 2, "en-US").contains("flipping"), "English transform hint")
	_expect(hint_texts.text("BF", 4, "en-US").contains("+1"), "failed loop retains direct support")
	_expect(hint_texts.text("F0", 0, "ko-KR").is_empty(), "clock hints do not leak into other puzzles")
	var before_support := GameState.get_snapshot()
	for attempts in [1, 2, 3, 4]:
		var support_state := before_support.duplicate(true)
		support_state.loop_state.event_local_states.CHAPTER_ONE.clock_locked = true
		var failure: Dictionary = support_state.meta_progress.failure_knowledge.get("B3_B", {}).duplicate(true)
		failure.merge({"source_event_id": "B3_B", "status": "active", "attempts": attempts}, true)
		support_state.meta_progress.failure_knowledge["B3_B"] = failure
		_expect(StateWriter.new(GameState).install_snapshot(support_state, GameState.revision, StringName("CLOCK_SUPPORT_%d" % attempts)).get("ok", false), "install failure support fixture")
		view._offer_clock_failure_support()
		if attempts == 1:
			_expect(not view._modal_active, "first failure does not auto-offer a strong hint")
		else:
			_expect(view._modal_active, "repeated failure offers optional support")
			var support_button := view._modal_body.get_child(4) as Button
			_expect(support_button.text.contains("H%d" % mini(attempts + 1, 5)), "support tier follows real failure count")
			_expect(not (view._modal_body.get_child(2).get_child(0) as Label).text.contains("+1"), "support offer does not reveal phase answer")
			(view._modal_body.get_child(3) as Button).pressed.emit()
		_expect(GameState.get_snapshot() == support_state, "declining support preserves lock failures and state")
	StateWriter.new(GameState).install_snapshot(before_support, GameState.revision, &"CLOCK_SUPPORT_RESTORE")
	var actual_retry := before_support.duplicate(true)
	actual_retry.loop_state.time_block = "evening_free"
	actual_retry.loop_state.event_local_states.CHAPTER_ONE.clock_locked = false
	actual_retry.loop_state.event_local_states.CHAPTER_ONE.roles = {}
	var previous_failure: Dictionary = actual_retry.meta_progress.failure_knowledge.get("B3_B", {}).duplicate(true)
	previous_failure.merge({"source_event_id": "B3_B", "status": "active", "attempts": 1}, true)
	actual_retry.meta_progress.failure_knowledge["B3_B"] = previous_failure
	StateWriter.new(GameState).install_snapshot(actual_retry, GameState.revision, &"CLOCK_SUPPORT_ACTION")
	view._do("activate_clock", true)
	_expect(view._dialogue_active and not view._modal_active, "actual failed activation shows outcome before support")
	while view._dialogue_active:
		view._dialogue_next.pressed.emit()
	_expect(view._modal_active and view._modal_body.get_child(4).text.contains("H3"), "second actual failure chains optional H3 after outcome")
	view._close_modal()
	StateWriter.new(GameState).install_snapshot(before_support, GameState.revision, &"CLOCK_SUPPORT_ACTION_RESTORE")
	view._render_room()
	await tree.process_frame
	var role_button := view._hotspot_layer.get_node("ROLE_reference") as OptionButton
	role_button.grab_focus()
	view._set_status("Previous failed action")
	role_button.item_selected.emit(CLOCK.CLOCKS.find("parlor") + 1)
	await tree.process_frame
	_expect(session.local_state()["roles"].get("reference", "") == "parlor", "real role control persists player input")
	_expect(view._status_label.text.is_empty(), "successful puzzle action clears stale error feedback")
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
