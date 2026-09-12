extends RefCounted

const SESSION := preload("res://scripts/systems/basement_session.gd")
const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const SLOT := "__test_basement_session"
var errors := PackedStringArray()
var game: Node
var saves: Node
var root: Window
var tree: SceneTree

class UnavailableEndingMeta extends RefCounted:
	func commit_completed(_state: Dictionary) -> Dictionary:
		return {"ok":false,"error":"injected_write_failure"}

class PendingEndingSession extends BasementSession:
	func stage() -> String:
		return "ENDING_BODY_PENDING"

func _validate_basement_hints(expected_stage: String) -> void:
	var view := VIEW.new()
	view.configure_session(SLOT, expected_stage)
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view.session.stage() == expected_stage, "basement hint stage: " + expected_stage)
	var before: Dictionary = game.get_snapshot()
	view._open_notebook()
	var button := view._modal_body.get_node_or_null("ClockHintsButton") as Button
	_expect(button != null, "basement thought action: " + expected_stage)
	if button != null:
		button.pressed.emit()
		for level in range(5):
			(view._modal_body.get_child(4) as Button).pressed.emit()
			var provider = preload("res://scripts/ui/core_hint_texts.gd") if expected_stage.begins_with("F0_") else preload("res://scripts/ui/basement_hint_texts.gd")
			var expected: String = provider.text(expected_stage, level, TranslationServer.get_locale())
			_expect(not expected.is_empty(), "requested hint has content")
			_expect(view._dialogue_label.text == expected, "basement requested hint: " + expected_stage)
			view._dialogue_next.pressed.emit()
		view._close_modal()
	var after: Dictionary = game.get_snapshot()
	_expect(after.meta_progress.dialogue_history.entries.size() == before.meta_progress.dialogue_history.entries.size() + 5, "basement hints persist only shown lines")
	after.meta_progress.dialogue_history = before.meta_progress.dialogue_history.duplicate(true)
	_expect(after == before, "basement hints preserve axes rings locks and relationships")
	view.queue_free()
	await tree.process_frame


func run(scene_tree: SceneTree) -> Dictionary:
	tree = scene_tree
	root = tree.root
	game = root.get_node("GameState")
	saves = root.get_node("SaveManager")
	game.reset_for_test()
	saves.delete_test_slot(SLOT)
	var state: Dictionary = game.get_snapshot()
	state["meta_progress"]["journal_stage"] = 3
	state["meta_progress"]["knowledge_entries"] = {"PROLOGUE_COMPLETE": true, "j3_restored_day": 3, "j2_restored_day": 2, "C5_MIRROR_TRACING": true, "KN_B1_LIBRARY_WINDOW": true, "self_authored_mark": {"day": 1}}
	state["loop_state"]["day_index"] = 3
	state["loop_state"]["location_id"] = "M2_BEDROOM"
	StateWriter.new(game).install_snapshot(state, game.revision, &"BASEMENT_SEED")
	var session := SESSION.new(game, saves, SLOT)
	_expect(session.initialize().get("ok", false), "initialize")
	_expect(session.stage() == "D_SLEEP", "J3 requires next morning")
	session.act("routine")
	_expect(session.sleep().get("ok", false), "J3 sleep")
	_expect(session.stage() == "D0", "D0 next morning")
	_expect(not session.act("move", "M1_BASEMENT_ENTRY").get("ok", false), "no basement entry before diagram")
	session.act("routine")
	_move(session, ["M1_CENTRAL_HALL", "M1_LIBRARY_OUTER", "M1_LIBRARY_INNER"])
	for point in ["greenhouse", "bedroom", "great_clock"]: session.act("d_drawer_point", point)
	_expect("MANSION_FLOORPLAN" in game.get_value("loop_state.inventory"), "physical floorplan acquired")
	await _validate_basement_hints("D0_A")
	session.act("d_overlay")
	_expect(not session.known("basement_overlay_solved"), "wrong overlay stays local")
	session.act("d_flip")
	for index in range(3): session.act("d_rotate")
	session.act("d_anchor", "great_clock")
	session.act("d_overlay")
	_expect(session.stage() == "D1", "D0-A unlocks pressure puzzle")
	await _validate_basement_hints("D1")
	_move(session, ["M1_LIBRARY_OUTER", "M1_CENTRAL_HALL", "M1_GREAT_CLOCK", "M1_BASEMENT_ENTRY", "B1_BASEMENT_STAIR", "B1_AXIS_CHAMBER"])
	_expect(not session.act("move", "B1_STORAGE").get("ok", false), "locked storage cannot be bypassed")
	session.act("d_axis_depth", ["line", 2])
	session.act("d_axis_push", {"value": "line", "confirmed": true})
	var axis_view_state: Dictionary = game.get_snapshot()
	session.act("d_axis_depth", ["branch", 3])
	session.act("d_axis_push", {"value": "branch", "confirmed": true})
	_expect(session.stage() == "DF", "wrong depth causes DF")
	await _validate_basement_hints("DF")
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "load failure")
	_expect(session.stage() == "DF", "load cannot repair pressure pins")
	_move(session, ["B1_BASEMENT_STAIR", "M1_BASEMENT_ENTRY", "M1_GREAT_CLOCK", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	_expect(not session.can_use_basement_shortcut(), "locked axes require sleep before preparation")
	session.sleep()
	_expect(session.can_use_basement_shortcut(), "unresolved axes failure allows preparation after sleep")
	_expect(session.basement_local()["axes"]["pushed"].is_empty(), "sleep resets physical axes")
	_expect("MANSION_FLOORPLAN" not in game.get_value("loop_state.inventory"), "sleep returns floorplan to drawer")
	_expect(session.known("basement_overlay_solved"), "verified overlay remains")
	session.act("d_shortcut")
	_expect(session.basement_local()["axes"]["depths"]["line"] == 2 and session.basement_local()["axes"]["pushed"].is_empty(), "shortcut preselects only verified depth, no irreversible push")
	for pair in [["line", 2], ["branch", 1], ["ring", 3]]:
		session.act("d_axis_depth", pair)
		session.act("d_axis_push", {"value": pair[0], "confirmed": true})
	session.act("d_axis_central", {"value": "counterclockwise", "confirmed": true})
	_expect(not session.basement_local()["axes"]["locked"], "reverse warning permits cancellation")
	session.act("d_axis_central", {"value": "clockwise", "confirmed": true})
	_expect(session.known("basement_access_fast_path"), "D2 grants access shortcut only after success")
	_expect(game.get_value("meta_progress.failure_knowledge.D1.status") == "resolved", "D2 resolves failure")
	_move(session, ["B1_BASEMENT_STAIR", "M1_BASEMENT_ENTRY", "M1_GREAT_CLOCK", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	var opened_storage: Dictionary = game.get_snapshot()
	_expect(not session.can_use_basement_shortcut() and not session.can_use_basement_shortcut(true), "already open storage offers neither preparation nor reopening")
	_expect(not session.act("d_shortcut").get("ok", false) and not session.act("d_fastpath").get("ok", false), "session rejects redundant storage shortcuts")
	_expect(game.get_snapshot() == opened_storage, "redundant storage shortcuts preserve state")
	_expect(session.sleep().get("ok", false), "sleep resets opened physical storage")
	_expect(not session.can_use_basement_shortcut() and session.can_use_basement_shortcut(true), "verified access replaces resolved failure preparation after reset")
	_expect(session.act("d_fastpath").get("ok", false) and session.basement_local()["axes"]["open"], "successful access shortcut reopens storage after reset")
	_move(session, ["B1_STORAGE"])
	_expect(not session.act("move", "B1_CLOCKWORK_HEART").get("ok", false), "storage survey before heart entry")
	session.act("d_storage", "cable")
	session.act("d_storage", "drawing")
	_move(session, ["B1_CLOCKWORK_HEART"])
	await _validate_basement_hints("D4")
	for handle in ["A", "B", "C", "C"]: session.act("d_heart", {"action": "turn", "value": handle})
	session.act("d_heart", {"action": "fix"})
	for index in range(12): session.act("d_heart", {"action": "wind"})
	session.act("d_heart", {"action": "stabilize"})
	_expect(game.get_value("fracture_state.camouflage_filter") == "active", "XII does not release filter")
	session.act("d_heart", {"action": "inspect_auxiliary"})
	_expect(not session.act("d_heart", {"action": "pull_auxiliary", "confirmed": false}).get("ok", false), "auxiliary is cancelable")
	session.act("d_heart", {"action": "pull_auxiliary", "confirmed": true})
	_expect(session.stage() == "D5" and not game.get_value("fracture_state.broken_reset_triggered"), "filter release precedes first broken sleep")
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "load at D4 boundary")
	var stinger := VIEW.new()
	stinger.configure_session(SLOT, "D5")
	root.add_child(stinger)
	await tree.process_frame
	stinger.set_process(false)
	stinger._demo_stinger_seconds = 0.0
	stinger._open_menu()
	_expect(stinger._modal_active, "Stinger menu remains available")
	stinger._tick_demo_stinger(70.0)
	_expect(stinger._demo_stinger_seconds == 0.0 and session.stage() == "D5", "Menu pauses stinger before completion boundary")
	stinger._close_modal()
	_expect(not stinger._hotspot_layer.has_node("D5_CONFIRM"), "Demo stinger has no confirmation gate")
	var stinger_before: Dictionary = game.get_snapshot()
	for attempt in [["move", "B1_STORAGE"], ["routine", null], ["d_storage", "cable"]]:
		_expect(not session.act(attempt[0], attempt[1]).get("ok", false), "Stinger rejects world action: " + attempt[0])
	_expect(game.get_snapshot() == stinger_before, "Rejected stinger actions preserve state")
	stinger._tick_demo_stinger(59.0)
	_expect(session.stage() == "D5", "Stinger cannot finish before sixty active seconds")
	var before_completion: Dictionary = game.get_snapshot()
	stinger.session.slot_id = "../invalid_slot"
	stinger._tick_demo_stinger(1.0)
	_expect(stinger._demo_stinger_save_failed and session.stage() == "D5", "Failed completion stays in D5")
	_expect(game.get_snapshot() == before_completion, "Failed stinger save rolls back completion")
	_expect(stinger._hotspot_layer.has_node("D5_SAVE_RETRY") and not stinger._hotspot_layer.has_node("RETURN_TITLE"), "Failure exposes retry instead of completed screen")
	var failed_revision: int = game.revision
	stinger._tick_demo_stinger(30.0)
	_expect(game.revision == failed_revision, "Failed stinger does not loop automatic save attempts")
	stinger.session.slot_id = SLOT
	stinger._hotspot_layer.get_node("D5_SAVE_RETRY").pressed.emit()
	_expect(stinger._hotspot_layer.has_node("RETURN_TITLE"), "Stinger completion displays demo end screen")
	stinger.queue_free()
	await tree.process_frame
	_expect(session.stage() == "DEMO_END", "demo boundary remains distinct from full-game continuation")
	_expect(not session.sleep().get("ok", false), "demo cannot silently enter full chapter")
	var loaded: Dictionary = saves.load_slot(SLOT)
	_expect(loaded.get("ok", false), "D5 boundary stored")
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "D5 boundary loads")
	_expect(session.stage() == "DEMO_END", "D5 boundary persists")
	await _validate_ui(session, axis_view_state)
	await _validate_full_transition()
	saves.delete_test_slot(SLOT)
	game.reset_for_test()
	return {"ok": errors.is_empty(), "errors": errors}


func _validate_full_transition() -> void:
	var demo: Dictionary = saves.load_slot(SLOT)
	var setting := "ggb/build_flavor"
	var previous: Variant = ProjectSettings.get_setting(setting, null)
	ProjectSettings.set_setting(setting, "full")
	_expect(saves.get_build_flavor() == "full", "full edition selected")
	_expect(saves.get_save_root() != "user://saves", "full edition preserves demo directory")
	saves.delete_test_slot(SLOT)
	_expect(not saves.load_slot(SLOT).get("ok", false), "full edition cannot implicitly load demo slot")
	_expect(not LoadCoordinator.new(game, saves).validate_header(demo["header"]).get("ok", false), "demo header requires explicit import, not ordinary load")
	var demo_path: String = "user://saves/" + SLOT + "/progress.json"
	var demo_bytes := FileAccess.get_file_as_bytes(demo_path)
	_expect(saves.inspect_demo_import(SLOT).get("ok",false), "Explicit import validates completed demo")
	var imported: Dictionary = saves.import_demo_to_new_slot(SLOT)
	_expect(imported.get("ok",false), "Demo import creates fresh full slot")
	if imported.get("ok",false):
		var imported_id: String = imported["slot_id"]
		_expect(LoadCoordinator.new(game,saves).load_and_install(imported_id).get("ok",false), "Imported full slot loads normally")
		var imported_session := SESSION.new(game,saves,imported_id)
		_expect(imported_session.stage() == "D6", "Imported demo resumes at D6")
		_expect(game.get_snapshot()["meta_progress"]["servants"] == StateSnapshotValidator.new().normalize(demo["snapshot"])["meta_progress"]["servants"], "Import preserves servant history")
		_expect(FileAccess.get_file_as_bytes(demo_path) == demo_bytes, "Demo source remains byte-identical")
		saves.delete_test_slot(imported_id)
	_expect(not saves.inspect_demo_import("../slot_01").get("ok",false), "Import rejects unsafe slot path")
	var import_screen: StartScreen = load("res://scenes/ui/start_screen.tscn").instantiate()
	root.add_child(import_screen)
	await tree.process_frame
	_expect(import_screen._import_button.visible, "Full title exposes import action")
	import_screen._import_button.pressed.emit()
	# Use the real completed fixture without touching any product save slot.
	import_screen._import_sources.assign([SLOT])
	import_screen._import_choices.clear()
	import_screen._import_choices.add_item("테스트 데모")
	import_screen._import_confirm.disabled = false
	var requested: Array[String] = []
	import_screen.load_game_requested.connect(func(id: String): requested.append(id))
	var bootstrap := tree.current_scene
	import_screen.load_game_requested.connect(bootstrap._on_load_game_requested)
	import_screen._import_confirm.pressed.emit()
	await tree.process_frame
	_expect(requested.size() == 1, "Import confirmation emits exactly one load request")
	_expect(not import_screen._import_controls.visible, "Successful import closes confirmation")
	if requested.size() == 1:
		var campaign := bootstrap.get_node_or_null("Basement")
		_expect(campaign != null, "Import load signal launches actual campaign scene")
		if campaign != null:
			_expect(campaign.session.stage() == "D6", "Imported campaign scene resumes D6")
			_expect(campaign._slot_id == requested[0], "Campaign uses imported slot, not demo source")
		_expect(not bootstrap.get_node("%StartScreen").visible, "Import launch hides product title")
		bootstrap._on_prologue_return_to_title()
		await tree.process_frame
		_expect(bootstrap.get_node("%StartScreen").visible, "Imported campaign returns to title")
		saves.delete_test_slot(requested[0])
	_expect(FileAccess.get_file_as_bytes(demo_path) == demo_bytes, "UI import preserves demo bytes")
	import_screen.queue_free()
	await tree.process_frame
	var state: Dictionary = StateSnapshotValidator.new().normalize(demo["snapshot"])
	state["loop_state"]["location_id"] = "M2_BEDROOM"
	_expect(StateWriter.new(game).install_snapshot(state, game.revision, &"FULL_TRANSITION_FIXTURE").get("ok", false), "full transition fixture installed")
	var session := SESSION.new(game, saves, SLOT)
	_expect(session.initialize().get("ok", false), "full D6 initialized")
	_expect(session.stage() == "D6", "full D5 continues to D6")
	_expect(saves.load_slot(SLOT)["header"]["save_point_id"] == "SAVE_FRACTURE_CONFIRMED", "full pre-sleep boundary")
	var day := int(game.get_value("loop_state.day_index"))
	var sleep_result := session.sleep()
	_expect(sleep_result.get("ok", false), "first broken sleep succeeds: " + str(sleep_result))
	_expect(session.stage() == "E1_ENTRY", "broken sleep enters E1")
	_expect(game.get_value("fracture_state.broken_reset_triggered") and game.get_value("fracture_state.camouflage_filter") == "broken", "broken state installed")
	_expect(int(game.get_value("loop_state.day_index")) == day + 1, "first broken sleep advances once")
	_expect(game.get_value("loop_state.location_id") == "M2_BEDROOM", "broken morning uses same bedroom")
	_expect(saves.load_slot(SLOT)["header"]["save_point_id"] == "SAVE_BROKEN_RESET_COMPLETE", "E1 save is not mislabeled as pre-sleep")
	var loaded := LoadCoordinator.new(game, saves).load_and_install(SLOT)
	_expect(loaded.get("ok", false) and loaded.get("resume_event_id") == "E1", "E1 load resolves E1 registry boundary")
	var view := VIEW.new()
	view.configure_session(SLOT, "E1_ENTRY")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._hotspot_layer.get_node_or_null("E1_bed") != null and view._hotspot_layer.get_node_or_null("E1_call_cord") != null, "E1 investigation UI connected")
	var history_count: int = game.get_value("meta_progress.dialogue_history.entries", []).size()
	view._hotspot_layer.get_node("E1_bed").pressed.emit()
	_expect(view._dialogue_active, "E1 click presents sensory response")
	var shown_text: String = view._dialogue_label.text
	var viewed_entries: Array = game.get_value("meta_progress.dialogue_history.entries", [])
	_expect(viewed_entries.size() == history_count + 1 and viewed_entries.back()["variables"]["text"] == shown_text, "E1 actual investigation records displayed sentence")
	view._dismiss_dialogue_for_test()
	var before_history: Dictionary = game.get_snapshot()
	view._open_menu()
	(view._modal_body.get_child(4) as Button).pressed.emit()
	_expect((view._modal_body.get_child(2).get_child(0) as Label).text.contains(shown_text), "E1 history available through menu")
	(view._modal_body.get_child(3) as Button).pressed.emit()
	_expect(game.get_snapshot() == before_history, "E1 history viewer is read only")
	for choice_method in ["_show_mara1_choice", "_show_iris_choice", "_show_luca_choice", "_show_edgar_choice", "_show_mara2_choice"]:
		var before_choice: Dictionary = game.get_snapshot()
		var option_count: int = before_choice["meta_progress"]["dialogue_history"]["entries"].size()
		view.call(choice_method)
		var displayed: Array = game.get_value("meta_progress.dialogue_history.entries", [])
		_expect(displayed.size() == option_count + 1, "relationship choice display recorded: " + choice_method)
		_expect(String(displayed.back()["variables"]["text"]).contains((view._modal_body.get_child(4) as Button).text), "relationship transcript includes actual option: " + choice_method)
		(view._modal_body.get_child(3) as Button).pressed.emit()
		_expect(game.get_value("meta_progress.dialogue_history.entries", []).size() == option_count + 1, "relationship deferral is not recorded as selected answer")
		_expect(game.get_snapshot()["meta_progress"]["servants"] == before_choice["meta_progress"]["servants"], "relationship deferral preserves bonds and completion")
	var choice_probe := {"calls": 0}
	view._show_recorded_choice("Choice test", "Shown only", [{"label": "Cancel", "action": view._close_modal}, {"label": "Chosen answer", "action": func(): choice_probe["calls"] += 1; view._close_modal()}])
	var selected_button := view._modal_body.get_child(4) as Button
	selected_button.pressed.emit()
	var selected_history: Array = game.get_value("meta_progress.dialogue_history.entries", [])
	_expect(choice_probe["calls"] == 1 and selected_history.back()["variables"]["text"] == "Chosen answer", "recorded choice invokes original action after storing selection")
	selected_button.pressed.emit()
	_expect(choice_probe["calls"] == 1, "closed choice cannot fire stale callback")
	var original_session: ChapterOneSession = view.session
	var before_unavailable: Dictionary = game.get_snapshot()
	view.session = PendingEndingSession.new(game, saves, SLOT)
	view._clear_hotspots()
	view._build_fracture_intro()
	_expect(not view._history_enabled(), "unsupported ending screen cannot write dialogue history")
	_expect(view._hotspot_layer.has_node("ENDING_UNAVAILABLE_TITLE") and not view._objective_label.text.contains("구현 중"), "unsupported ending offers accurate recovery navigation")
	var title_probe := {"called": false}
	view.return_to_title_requested.connect(func(): title_probe["called"] = true)
	(view._hotspot_layer.get_node("ENDING_UNAVAILABLE_TITLE") as Button).pressed.emit()
	_expect(title_probe["called"] and game.get_snapshot() == before_unavailable, "unsupported ending title action preserves gameplay state")
	view.session = original_session
	view._render_room()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://e1_morning.png")
	view.queue_free()
	await tree.process_frame
	_expect(not session.act("move", "M1_CENTRAL_HALL").get("ok", false), "E1 exit requires investigation")
	session.act("e1_inspect", "bed")
	session.act("e1_inspect", "bed")
	_expect(game.get_value("meta_progress.knowledge_entries.E1_objects_seen").size() == 1, "E1 repeats do not inflate unique count")
	session.act("e1_inspect", "window")
	_expect(not session.known("E1_complete"), "E1 two objects insufficient")
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "E1 partial investigation loads")
	session.act("e1_inspect", "mirror")
	_expect(session.known("E1_complete") and not session.known("E1_all_objects_seen"), "three objects unlock without fourth")
	_expect(session.act("move", "M1_CENTRAL_HALL").get("ok", false), "E1 exit unlocks")
	_expect(not session.act("move", "M1_PARLOR").get("ok", false), "E2 handoff cannot bypass gathering")
	session.act("move", "M2_BEDROOM")
	session.act("e1_inspect", "call_cord")
	_expect(session.known("E1_all_objects_seen"), "fourth optional inspection works after exit")
	_expect(not session.act("d_fastpath").get("ok", false), "broken morning rejects old basement replay")
	var e1_state: Dictionary = game.get_snapshot()
	var bond := int(game.get_value("meta_progress.servants.luca.bond"))
	for choice in ["withdraw", "hold"]:
		_expect(StateWriter.new(game).install_snapshot(e1_state, game.revision, StringName("LUCA_FIXTURE_" + choice)).get("ok", false), "Luca branch fixture")
		session.act("move", "M1_CENTRAL_HALL")
		_expect(session.stage() == "LUCA_GUIDE", "Luca prelude delays E2")
		session.act("move", "M1_KITCHEN")
		session.act("e2_luca", "ask")
		_expect(not session.known("LUCA_S2_complete"), "sensory question is not an outcome")
		_expect(session.act("e2_luca", choice).get("ok", false), "Luca choice " + choice)
		_expect(session.stage() == "E2_INTRO", "both choices rejoin E2")
		var expected := mini(5, bond + 1) if choice == "hold" else bond
		_expect(int(game.get_value("meta_progress.servants.luca.bond")) == expected, "Luca choice relationship delta")
		session.act("e2_luca", "hold")
		_expect(int(game.get_value("meta_progress.servants.luca.bond")) == expected, "Luca cannot farm repeat bond")
		_expect(not session.act("e2_finish").get("ok", false), "report precedes completion")
		session.act("e2_report")
		if choice == "hold":
			view = VIEW.new()
			view.configure_session(SLOT, "E2_INTRO")
			root.add_child(view)
			await tree.process_frame
			view._dismiss_dialogue_for_test()
			_expect(view._hotspot_layer.get_node_or_null("E2_Q_2") != null, "E2 question UI available")
			view._hotspot_layer.get_node("E2_Q_2").pressed.emit()
			_expect(view._dialogue_active, "E2 question click presents response")
			view._dismiss_dialogue_for_test()
			if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://e2_questions.png")
			view.queue_free()
			await tree.process_frame
			for question in ["memory", "house", "body", "memory"]: session.act("e2_question", question)
			_expect(game.get_value("meta_progress.knowledge_entries.E2_questions_seen").size() == 3, "questions arbitrary order unique history")
		_expect(session.act("e2_finish").get("ok", false), "E2 can finish with all or no optional questions")
		_expect(session.stage() == "E_HUB" and session.known("relationship_hub_open"), "E2 opens hub")
		_expect(not session.known("mara2_archive_index_known"), "anonymous index does not grant identity")
		_expect(int(game.get_value("meta_progress.servants.luca.bond")) == expected, "E2 does not change relationship")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "E2 completion loads")
		_expect(session.stage() == "E_HUB", "E2 completion persists")
	await _validate_mara1(session)
	await _validate_iris(session)
	await _validate_luca(session)
	await _validate_edgar(session)
	await _validate_mara2(session)
	await _validate_j4(session)
	session.act("move", "M2_BEDROOM")
	state = game.get_snapshot()
	state["loop_state"]["physical_changes"]["test_repair"] = true
	StateWriter.new(game).install_snapshot(state, game.revision, &"FULL_REPAIR_FIXTURE")
	_expect(session.sleep().get("ok", false), "post-broken rest succeeds")
	_expect(int(game.get_value("loop_state.day_index")) == day + 1 and game.get_value("loop_state.physical_changes.test_repair") == true, "post-broken rest does not repeat physical reset")
	saves.delete_test_slot(SLOT)
	ProjectSettings.set_setting(setting, previous)
	_expect(saves.load_slot(SLOT).get("snapshot", {}) == demo["snapshot"], "full test leaves original demo save intact")


func _validate_mara1(session: BasementSession) -> void:
	var hub: Dictionary = game.get_snapshot()
	for outcome in ["original_attribution", "protected_identifiers"]:
		_expect(StateWriter.new(game).install_snapshot(hub, game.revision, StringName("MARA_FIXTURE_" + outcome)).get("ok", false), "Mara fixture")
		_move(session, ["M1_SERVICE_HALL", "M1_WIRING_ROOM"])
		_expect(not session.act("mara1_choose", outcome).get("ok", false), "cannot choose before evidence")
		_expect(not session.act("mara1_bridge").get("ok", false), "spanner before trace blocked locally")
		session.act("mara1_panel")
		var servant: Dictionary = game.get_value("meta_progress.servants.mara1")
		session.act("mara1_source", [0, "AUDIT"])
		_expect(game.get_value("meta_progress.servants.mara1") == servant, "wrong wiring no relationship penalty")
		for index in range(3): session.act("mara1_source", [index, ["MAINT", "CONSENT", "AUDIT"][index]])
		session.act("mara1_bridge")
		_move(session, ["M1_SERVICE_HALL", "M1_CENTRAL_HALL", "M2_BEDROOM"])
		session.sleep()
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Mara partial progress reload")
		_move(session, ["M1_CENTRAL_HALL", "M1_SERVICE_HALL", "M1_WIRING_ROOM"])
		_expect(game.get_value("loop_state.event_local_states.E3_1.bridge") == true, "Mara bridge survives exit rest load")
		for id in ["command", "failure", "consent"]: session.act("mara1_log", id)
		_expect(not session.act("mara1_restore").get("ok", false), "wrong chronology local retry")
		session.act("mara1_clear")
		for id in ["consent", "failure", "command"]: session.act("mara1_log", id)
		session.act("mara1_restore")
		session.act("mara1_confess")
		var view := VIEW.new()
		view.configure_session(SLOT, "E3_1")
		root.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		view._hotspot_layer.get_node("MARA_CHOICE").pressed.emit()
		await tree.process_frame
		_expect((root.gui_get_focus_owner() as Button).text == "아직 결정하지 않는다", "relationship choice defaults to defer")
		if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://mara1_choice.png")
		view._modal_body.get_child(4 if outcome == "original_attribution" else 5).pressed.emit()
		view._dismiss_dialogue_for_test()
		view.queue_free()
		await tree.process_frame
		_expect(session.known("E3_1_complete") and session.known("REC_MARA1"), "Mara completion and record atomic")
		var after: Dictionary = game.get_value("meta_progress.servants.mara1")
		_expect(after["core_event_complete"] and after["researcher_record_acquired"], "Mara servant flags")
		_expect(int(after["bond"]) == clampi(int(servant["bond"]) + (2 if outcome == "original_attribution" else 1), 0, 5), "Mara bond outcome")
		_expect(int(after["alert"]) == clampi(int(servant["alert"]) + (1 if outcome == "original_attribution" else -1), 0, 5), "Mara alert outcome")
		session.act("mara1_choose", outcome)
		_expect(game.get_value("meta_progress.servants.mara1") == after, "Mara outcome not farmable")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Mara completion loads")
		_expect(game.get_value("meta_progress.event_history.E3_1.outcome_id") == outcome, "Mara outcome survives load")
		_move(session, ["M1_SERVICE_HALL", "M1_CENTRAL_HALL"])


func _validate_iris(session: BasementSession) -> void:
	var hub: Dictionary = game.get_snapshot()
	var rules = BasementSession.IRIS_RELATIONSHIP
	for scenario in [[0, 0, "external_truth", "indirect"], [2, 5, "external_truth", "direct_private"], [0, 4, "shelter_projection", "denied"], [0, 0, "shelter_projection", "withheld"]]:
		var fixture := hub.duplicate(true)
		fixture["meta_progress"]["servants"]["iris"]["bond"] = scenario[0]
		fixture["meta_progress"]["servants"]["iris"]["alert"] = scenario[1]
		_expect(StateWriter.new(game).install_snapshot(fixture, game.revision, StringName("IRIS_FIXTURE_" + scenario[3])).get("ok", false), "Iris fixture installed")
		_move(session, ["M1_GREENHOUSE", "H0_CLIMATE_CONTROL"])
		_expect(not session.act("iris_choose", scenario[2]).get("ok", false), "Iris choice cannot precede evidence")
		session.act("iris_panel")
		var before: Dictionary = game.get_value("meta_progress.servants.iris")
		session.act("iris_source", ["temperature", 0, "EXTERNAL"])
		_expect(game.get_value("meta_progress.servants.iris") == before, "Iris error does not increase hostility")
		for gauge in rules.CHANNELS:
			for index in range(3): session.act("iris_source", [gauge, index, rules.CHANNELS[gauge][index]])
		_expect(session.known("iris_sensor_sources_separated"), "all three gauges separated")
		_move(session, ["M1_GREENHOUSE", "M1_CENTRAL_HALL", "M2_BEDROOM"])
		session.sleep()
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Iris partial save load")
		_move(session, ["M1_CENTRAL_HALL", "M1_GREENHOUSE", "H0_CLIMATE_CONTROL"])
		_expect(rules.progress(game.get_snapshot())["channels"].size() == 9, "Iris sensors survive exit rest and load")
		for id in ["command", "warning", "loss", "audit", "conversion"]: session.act("iris_log", id)
		_expect(not session.act("iris_restore").get("ok", false), "Iris false approval chronology rejected")
		session.act("iris_clear")
		for id in rules.ORDER: session.act("iris_log", id)
		session.act("iris_restore")
		_expect(not session.act("iris_audit", "warning_is_consent").get("ok", false), "warning is not consent")
		session.act("iris_audit", "credential_owner_not_executor")
		session.act("iris_confront")
		var result: Dictionary
		if scenario[3] == "direct_private":
			var view := VIEW.new()
			view.configure_session(SLOT, "E3_2")
			root.add_child(view)
			await tree.process_frame
			view._dismiss_dialogue_for_test()
			view._hotspot_layer.get_node("IRIS_CHOICE").pressed.emit()
			await tree.process_frame
			_expect((root.gui_get_focus_owner() as Button).text == "아직 결정하지 않는다", "Iris choice defaults to defer")
			if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://iris_choice.png")
			view._modal_body.get_child(4).pressed.emit()
			_expect(view._dialogue_active, "Iris choice renders conditional confession")
			view._dismiss_dialogue_for_test()
			view.queue_free()
			await tree.process_frame
			result = {"ok": session.known("E3_2_complete")}
		else:
			result = session.act("iris_choose", scenario[2])
		_expect(result.get("ok", false), "Iris outcome accepted " + scenario[3])
		var iris: Dictionary = game.get_value("meta_progress.servants.iris")
		_expect(rules.confession(iris["bond"], iris["alert"]) == scenario[3], "Iris prospective relationship confession")
		_expect(session.known("REC_IRIS") and session.known("iris_power_diversion_known") and iris["core_event_complete"] and iris["researcher_record_acquired"], "both Iris choices preserve record and knowledge")
		_expect(not game.get_value("meta_progress.knowledge_entries").has("iris_confession_state"), "Iris confession remains derived not global stored state")
		session.act("iris_choose", scenario[2])
		_expect(game.get_value("meta_progress.servants.iris") == iris, "Iris outcome cannot repeat rewards")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Iris outcome save load")
		_expect(game.get_value("meta_progress.event_history.E3_2.outcome_id") == scenario[2], "Iris outcome persists")
		_move(session, ["M1_GREENHOUSE", "M1_CENTRAL_HALL"])


func _validate_luca(session: BasementSession) -> void:
	var hub: Dictionary = game.get_snapshot()
	var rules = BasementSession.LUCA_RELATIONSHIP
	var record := ""
	for outcome in ["full_disclosure", "stabilize_first"]:
		_expect(StateWriter.new(game).install_snapshot(hub, game.revision, StringName("LUCA_CORE_" + outcome)).get("ok", false), "Luca core fixture")
		_move(session, ["M1_KITCHEN", "H0_LIFE_SUPPORT"])
		_expect(not session.act("luca_choose", outcome).get("ok", false), "Luca choice requires evidence")
		session.act("luca_panel")
		session.act("luca_pipe", "decoration")
		session.act("luca_pipe", "main")
		_expect(not session.act("luca_match").get("ok", false), "decorative pipe cannot be used")
		session.act("luca_pipe", "decoration")
		session.act("luca_pipe", "aux")
		session.act("luca_match")
		var before: Dictionary = game.get_value("meta_progress.servants.luca")
		session.act("luca_slot", [0, "aux_1"])
		session.act("luca_preview")
		session.act("luca_run")
		_expect(rules.progress(game.get_snapshot())["pressure"] == 0 and not rules.progress(game.get_snapshot())["stable"], "wrong phase vents pressure without progress")
		_expect(game.get_value("meta_progress.servants.luca") == before, "wrong pressure has no relationship penalty")
		for index in range(4): session.act("luca_slot", [index, rules.PHASES[index]])
		session.act("luca_run")
		_expect(session.known("luca_pressure_phase_stable"), "correct pressure confirmed")
		_move(session, ["M1_KITCHEN", "M1_CENTRAL_HALL", "M2_BEDROOM"])
		session.sleep()
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Luca partial save load")
		_move(session, ["M1_CENTRAL_HALL", "M1_KITCHEN", "H0_LIFE_SUPPORT"])
		_expect(rules.progress(game.get_snapshot())["stable"], "Luca pressure checkpoint survives rest and exit")
		for id in rules.LOGS: session.act("luca_log", id)
		session.act("luca_confess")
		var view := VIEW.new()
		view.configure_session(SLOT, "E3_3")
		root.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		view._hotspot_layer.get_node("LUCA_CHOICE").pressed.emit()
		await tree.process_frame
		_expect((root.gui_get_focus_owner() as Button).text == "아직 결정하지 않는다", "Luca choice defaults to defer")
		if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://luca_choice.png")
		view._modal_body.get_child(4 if outcome == "full_disclosure" else 5).pressed.emit()
		view._dismiss_dialogue_for_test()
		view.queue_free()
		await tree.process_frame
		_expect(session.known("REC_LUCA") and session.known("wake_criteria_missing") and session.known("protagonist_body_preserved"), "Luca record and core knowledge")
		var after: Dictionary = game.get_value("meta_progress.servants.luca")
		_expect(after["core_event_complete"] and after["researcher_record_acquired"], "Luca servant completion")
		_expect(int(after["bond"]) == clampi(int(before["bond"]) + (2 if outcome == "full_disclosure" else 1), 0, 5), "Luca bond")
		_expect(int(after["alert"]) == clampi(int(before["alert"]) + (1 if outcome == "full_disclosure" else -1), 0, 5), "Luca alert")
		var current := String(game.get_value("meta_progress.knowledge_entries.chapter_notebook.REC_LUCA"))
		if record.is_empty(): record = current
		else: _expect(record == current, "both outcomes provide identical facts")
		session.act("luca_choose", outcome)
		_expect(game.get_value("meta_progress.servants.luca") == after, "Luca cannot repeat rewards")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Luca completion loads")
		_expect(game.get_value("meta_progress.event_history.E3_3.outcome_id") == outcome, "Luca outcome preserved")
		_move(session, ["M1_KITCHEN", "M1_CENTRAL_HALL"])


func _validate_edgar(session: BasementSession) -> void:
	var hub: Dictionary = game.get_snapshot()
	var rules = BasementSession.EDGAR_RELATIONSHIP
	var record := ""
	for outcome in ["responsibility_recorded", "authority_returned"]:
		_expect(StateWriter.new(game).install_snapshot(hub, game.revision, StringName("EDGAR_FIXTURE_" + outcome)).get("ok", false), "Edgar fixture")
		_move(session, ["M1_GREAT_CLOCK", "H0_CLOCK_MACHINE"])
		_expect(not session.act("edgar_choose", outcome).get("ok", false), "Edgar choice cannot skip evidence")
		for id in ["vacancy", "protocol", "extension", "consent"]: session.act("edgar_log", id)
		_expect(not session.act("edgar_audit").get("ok", false), "Edgar chronology wrong local retry")
		session.act("edgar_clear")
		for id in rules.ORDER: session.act("edgar_log", id)
		session.act("edgar_audit")
		var before: Dictionary = game.get_value("meta_progress.servants.edgar")
		session.act("edgar_owner", ["PROTECTION", "SYSTEM"])
		session.act("edgar_owner", ["CHOICE", "CUSTODIAN"])
		session.act("edgar_validate")
		var partial: Dictionary = rules.progress(game.get_snapshot())
		_expect(partial["owners"].get("PROTECTION") == "SYSTEM" and not partial["owners"].has("CHOICE"), "Edgar only wrong cards return")
		_expect(game.get_value("meta_progress.servants.edgar") == before, "Edgar wrong layout no relationship change")
		_move(session, ["M1_GREAT_CLOCK", "M1_CENTRAL_HALL", "M2_BEDROOM"])
		session.sleep()
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Edgar partial save load")
		_move(session, ["M1_CENTRAL_HALL", "M1_GREAT_CLOCK", "H0_CLOCK_MACHINE"])
		_expect(rules.progress(game.get_snapshot())["owners"].get("PROTECTION") == "SYSTEM", "Edgar correct card survives exit rest load")
		for function in rules.OWNERS: session.act("edgar_owner", [function, rules.OWNERS[function]])
		session.act("edgar_validate")
		_expect(session.known("edgar_authority_layout_validated"), "Edgar current layout validated")
		session.act("edgar_confess")
		var view := VIEW.new()
		view.configure_session(SLOT, "E3_4")
		root.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		view._hotspot_layer.get_node("EDGAR_CHOICE").pressed.emit()
		await tree.process_frame
		_expect((root.gui_get_focus_owner() as Button).text == "기록을 다시 읽는다", "Edgar choice default reread")
		if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://edgar_choice.png")
		view._modal_body.get_child(4 if outcome == "responsibility_recorded" else 5).pressed.emit()
		view._dismiss_dialogue_for_test()
		view.queue_free()
		await tree.process_frame
		_expect(session.known("REC_EDGAR") and session.known("subject_role_identified") and session.known("edgar_detention_decision_known"), "both Edgar outcomes return subject role and truth")
		var after: Dictionary = game.get_value("meta_progress.servants.edgar")
		_expect(after["core_event_complete"] and after["researcher_record_acquired"], "Edgar completion flags")
		_expect(int(after["bond"]) == clampi(int(before["bond"]) + (1 if outcome == "responsibility_recorded" else 2), 0, 5), "Edgar bond")
		_expect(int(after["alert"]) == clampi(int(before["alert"]) + (-1 if outcome == "responsibility_recorded" else 1), 0, 5), "Edgar alert")
		var current := String(game.get_value("meta_progress.knowledge_entries.chapter_notebook.REC_EDGAR"))
		if record.is_empty(): record = current
		else: _expect(record == current, "Edgar truth equal between choices")
		session.act("edgar_choose", outcome)
		_expect(game.get_value("meta_progress.servants.edgar") == after, "Edgar repeated reward refused")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Edgar completion loads")
		_expect(game.get_value("meta_progress.event_history.E3_4.outcome_id") == outcome, "Edgar outcome persisted")
		_move(session, ["M1_GREAT_CLOCK", "M1_CENTRAL_HALL"])


func _validate_j4(session: BasementSession) -> void:
	var hub := session.snapshot()
	var rules = SESSION.JOURNAL_FOUR
	for mask in range(32):
		var fixture := hub.duplicate(true)
		var count := 0
		for index in range(5):
			var complete := (mask & (1 << index)) != 0
			var servant: Dictionary = fixture["meta_progress"]["servants"][rules.OWNERS[index]]
			servant["core_event_complete"] = complete
			servant["researcher_record_acquired"] = complete
			fixture["meta_progress"]["knowledge_entries"][rules.EVENTS[index] + "_complete"] = complete
			if complete: count += 1
		_expect(StateWriter.new(game).install_snapshot(fixture, game.revision, &"J4_FIXTURE").get("ok", false), "J4 fixture")
		_expect(not session.act("j4_confirm", false).get("ok", false) and session.snapshot() == fixture, "J4 cancellation preserves state")
		_expect(session.act("j4_confirm", true).get("ok", false), "J4 confirm mask %d" % mask)
		_expect(session.stage() == "J4", "J4 opens without record gate")
		_expect(not session.act("move", "M1_KITCHEN").get("ok", false), "J4 closes relation hub")
		_expect(not session.act("j4_read").get("ok", false), "J4 requires page assembly")
		session.act("j4_page", "activation")
		_expect(not session.act("j4_order").get("ok", false), "J4 wrong order is locally retryable")
		session.act("j4_clear")
		for page in rules.ORDER: _expect(session.act("j4_page", page).get("ok", false), "J4 page")
		_expect(session.act("j4_order").get("ok", false), "J4 chronological order")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "J4 partial load")
		_expect(session.act("j4_read").get("ok", false), "J4 restoration")
		var expected := "J4_FULL" if count == 5 else ("J4_EXPANDED" if count >= 2 else "J4_BASE")
		_expect(game.get_value("meta_progress.knowledge_entries.j4_variant") == expected, "J4 record tier")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "J4 completed load")
		var servants_before: Dictionary = session.snapshot()["meta_progress"]["servants"].duplicate(true)
		if (mask & 8) == 0:
			_expect(session.stage() == "E3_4M", "unfinished Edgar routes to minimum")
			_expect(session.act("j4_minimum").get("ok", false), "zero reward minimum procedure")
			_expect(not session.act("j4_minimum").get("ok", false), "minimum cannot duplicate")
		_expect(session.snapshot()["meta_progress"]["servants"] == servants_before, "minimum does not award relationships")
		_expect(session.stage() == "E5", "all masks reach next evening")
		var before_evening: Dictionary = session.snapshot()["meta_progress"]["servants"].duplicate(true)
		_expect(session.act("e5_enter").get("ok", false), "E5 enter for every mask")
		if mask == 0: await _validate_e5_ui(session)
		_expect(not session.act("e5_finish", true).get("ok", false), "E5 cannot skip dialogue")
		_expect(session.act("e5_sit").get("ok", false), "E5 subject seat")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "E5 partial reload")
		_expect(session.act("e5_question", ["wish", "leave", "stay"][mask % 3]).get("ok", false), "E5 question")
		_expect(not session.act("e5_question", "wish").get("ok", false), "E5 question once")
		_expect(not session.act("e5_finish", false).get("ok", false), "E5 cancel remains free")
		_expect(session.act("e5_inspect", "hall").get("ok", false), "E5 free hall inspection")
		_expect(session.act("e5_inspect", "dining").get("ok", false), "E5 return dining")
		_expect(session.act("e5_finish", true).get("ok", false), "E5 commit")
		var expected_tier := "ALL" if count == 5 else ("HIGH" if count == 4 else ("MID" if count >= 2 else "LOW"))
		_expect(game.get_value("meta_progress.event_history.E5.variant_id") == expected_tier, "E5 settlement tier")
		_expect(session.snapshot()["meta_progress"]["servants"] == before_evening, "E5 does not change relationship values")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "E5 completed reload")
		_expect(session.stage() == "E6", "E5 reaches followup boundary")
		var e5_history: Dictionary = session.snapshot()["meta_progress"]["event_history"]["E5"].duplicate(true)
		if (mask & 16) != 0 and mask % 2 == 1:
			session.act("e6_move", "M1_NORTH_ARCHIVE_HALL")
			var choice: String = ["write", "call", "joke"][mask % 3]
			var bond := int(game.get_value("meta_progress.servants.mara2.bond"))
			_expect(session.act("e6_mara2", choice).get("ok", false), "Mara2 followup")
			_expect(int(game.get_value("meta_progress.servants.mara2.bond")) == clampi(bond + (0 if choice == "joke" else 1), 0, 5), "Mara2 followup delta")
			_expect(not session.act("e6_mara2", choice).get("ok", false), "Mara2 no duplicate reward")
		session.act("e6_move", "H0_CLOCK_MACHINE")
		if mask % 2 == 0:
			_expect(session.act("e6_open").get("ok", false), "skip all followups opens door")
		else:
			var choice: String = ["ask", "order", "wait"][mask % 3]
			var bond := int(game.get_value("meta_progress.servants.edgar.bond"))
			_expect(session.act("e6_edgar", choice).get("ok", false), "Edgar followup")
			_expect(int(game.get_value("meta_progress.servants.edgar.bond")) == clampi(bond + (1 if choice == "ask" else 0), 0, 5), "Edgar followup delta")
			_expect(not session.act("e6_edgar", choice).get("ok", false), "Edgar no duplicate reward")
		_expect(not session.act("e6_enter", false).get("ok", false), "E6 entry can be deferred")
		if mask == 0: await _validate_e6_ui(session)
		_expect(session.act("e6_enter", true).get("ok", false), "E6 all masks enter F0")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "F0 entry reload")
		_expect(session.initialize().get("ok", false) and session.stage() == "F0_A", "F0 resume stays on core path")
		if mask == 0: await _validate_f0a(session)
		_expect(not session.act("e6_move", "M1_CENTRAL_HALL").get("ok", false), "no F0 backtracking")
		_expect(session.snapshot()["meta_progress"]["event_history"]["E5"] == e5_history, "followups preserve E5 snapshot")
	_expect(StateWriter.new(game).install_snapshot(hub, game.revision, &"J4_RESTORE").get("ok", false), "restore relation hub after J4 tests")
	var view := VIEW.new()
	view.configure_session(SLOT, "J4")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view._show_j4_confirmation()
	_expect(not view._objective_label.text.contains("구현 중"), "relation hub contains player-facing objective rather than development status")
	var j4_before_cancel := session.snapshot()
	var expected_hub := hub.duplicate(true)
	expected_hub["meta_progress"]["dialogue_history"] = j4_before_cancel["meta_progress"]["dialogue_history"].duplicate(true)
	_expect(j4_before_cancel == expected_hub, "J4 opening only appends displayed dialogue history")
	var confirm := view._modal_body.get_child(4) as Button
	_expect(confirm.disabled, "J4 confirmation input grace")
	await tree.create_timer(0.6).timeout
	_expect(not confirm.disabled, "J4 confirmation becomes available")
	view._close_modal()
	_expect(session.snapshot() == j4_before_cancel, "J4 modal cancel changes nothing")
	view.queue_free()
	await tree.process_frame


func _validate_f0a(session: BasementSession) -> void:
	await _validate_basement_hints("F0_A")
	var rules = SESSION.CORE_ROOMS
	var solutions := 0
	for a in range(4):
		for b in range(4):
			for c in range(4):
				for d in range(4):
					if [a,b,c,d].count(a) != 1 or [a,b,c,d].count(b) != 1 or [a,b,c,d].count(c) != 1: continue
					for rotation in range(256):
						var local := {"tiles": [rules.ROOMS[a],rules.ROOMS[b],rules.ROOMS[c],rules.ROOMS[d]], "directions": [rotation%4,(rotation/4)%4,(rotation/16)%4,(rotation/64)%4]}
						if rules.evaluate(local)["ok"]: solutions += 1
	_expect(solutions == 1, "F0-A has one solution among 6144 configurations")
	var before := session.snapshot()
	_expect(session.act("f0a_signal").get("ok", false) and not session.known("f0_room_feedback_loop_solved"), "F0-A wrong wiring remains retryable")
	for slot in range(4):
		var local: Dictionary = rules.progress(session.snapshot())
		var source: int = local["tiles"].find(rules.ROOMS[slot])
		session.act("f0a_select", slot)
		session.act("f0a_select", source)
		for turn in range((slot+1)%4): session.act("f0a_rotate", slot)
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "F0-A partial reload")
	var view := VIEW.new()
	view.configure_session(SLOT, "F0_A")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._hotspot_layer.has_node("F0A_SIGNAL"), "F0-A signal button")
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f0a_network.png")
	view._hotspot_layer.get_node("F0A_SIGNAL").pressed.emit()
	view._dismiss_dialogue_for_test()
	_expect(session.stage() == "F0_B", "F0-A solved moves to next stage")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false) and session.stage() == "F0_B", "F0-A completion reload")
	_expect(session.snapshot()["meta_progress"]["servants"] == before["meta_progress"]["servants"], "F0-A no relationship gate or reward")
	await _validate_f0b(session)


func _validate_f0b(session: BasementSession) -> void:
	await _validate_basement_hints("F0_B")
	var rules = SESSION.CORE_SAMPLES
	var seed := session.snapshot()
	for mask in range(16):
		var state := seed.duplicate(true)
		var expected := 0
		for index in range(4):
			var room: String = rules.ROOMS[index]
			var sample := (mask >> index) & 1
			if sample == 0: expected += 1
			state = rules.apply(state, "inspect", [room, sample])["state"]
			state = rules.apply(state, "send", room)["state"]
		_expect(rules.progress(state)["verified"].size() == expected, "F0-B all 16 combinations")
		_expect(bool(state["meta_progress"]["knowledge_entries"].get("f0_system_samples_verified", false)) == (mask == 0), "F0-B only four maintenance samples complete")
	_expect(not session.act("f0b_send", "kitchen").get("ok", false), "F0-B inspect before send")
	for attempt in range(3):
		session.act("f0b_inspect", ["kitchen", 1])
		session.act("f0b_send", "kitchen")
	_expect(rules.progress(session.snapshot())["hint_seen"], "F0-B third error hint")
	for room in ["bedroom", "library", "kitchen"]:
		session.act("f0b_inspect", [room, 0])
		_expect(session.act("f0b_send", room).get("ok", false), "F0-B verify channels in any order")
		_expect(not session.act("f0b_send", room).get("ok", false), "F0-B verified channel cannot duplicate")
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "F0-B partial load")
	var view := VIEW.new()
	view.configure_session(SLOT, "F0_B")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f0b_samples.png")
	view._hotspot_layer.get_node("F0B_greenhouse_0").pressed.emit()
	view._dismiss_dialogue_for_test()
	view._render_room()
	view._hotspot_layer.get_node("F0B_SEND_greenhouse").pressed.emit()
	view._dismiss_dialogue_for_test()
	_expect(session.stage() == "F0_C", "F0-B access denied advances to missing port investigation")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false) and session.stage() == "F0_C", "F0-B completed reload")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"], "F0-B no relationship changes")
	await _validate_basement_hints("F0_C")
	for layer in ["B4","C5","D4"]: session.act("f0c", {"action":"anchor","layer":layer,"value":0})
	for i in range(2): session.act("f0c", {"action":"rotate","layer":"B4"})
	session.act("f0c", {"action":"flip","layer":"C5"})
	for i in range(3): session.act("f0c", {"action":"rotate","layer":"C5"})
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "F0-C partial reload")
	view = VIEW.new()
	view.configure_session(SLOT, "F0_C")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f0c_overlay.png")
	view._hotspot_layer.get_node("F0C_VERIFY").pressed.emit()
	view._dismiss_dialogue_for_test()
	for point in ["PATH","SPLIT","AUTH"]:
		view._render_room()
		view._hotspot_layer.get_node("F0C_"+point).pressed.emit()
		view._dismiss_dialogue_for_test()
	_expect(session.stage() == "F0_D", "F0-C UI investigation completes")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false) and session.stage() == "F0_D", "F0-C completed reload")
	await _validate_f0d(session)


func _validate_f0d(session: BasementSession) -> void:
	await _validate_basement_hints("F0_D")
	var rules = SESSION.CORE_ROLES
	var seed := session.snapshot()
	_expect(not session.act("f0d_verify").get("ok",false), "F0-D rejects empty slots")
	for index in range(5):
		session.act("f0d_select",rules.RECORDS[index])
		session.act("f0d_place",index if index == 0 else (index%4)+1)
	for failure in range(3): session.act("f0d_verify")
	_expect(session.act("f0d_lock",0).get("ok",false), "F0-D verified slot lock")
	session.act("f0d_select","father")
	_expect(not session.act("f0d_place",1).get("ok",false), "F0-D cannot move locked card")
	for index in range(1,5):
		session.act("f0d_select",rules.RECORDS[index])
		session.act("f0d_place",index)
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "F0-D partial reload")
	var view := VIEW.new()
	view.configure_session(SLOT,"F0_D")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f0d_roles.png")
	view._hotspot_layer.get_node("F0D_VERIFY").pressed.emit()
	view._dismiss_dialogue_for_test()
	_expect(session.stage()=="F0_E", "F0-D roles solved")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false) and session.stage()=="F0_E", "F0-D completed reload")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"], "F0-D anonymous route no relationship changes")
	await _validate_f0e(session)


func _validate_f0e(session: BasementSession) -> void:
	await _validate_basement_hints("F0_E")
	var seed := session.snapshot()
	var rules = SESSION.CORE_SELF
	for type in rules.MARKS:
		for intent in ["reality","stay","undecided"]:
			var fixture := seed.duplicate(true)
			fixture["meta_progress"]["knowledge_entries"]["self_authored_mark"] = {"type":type,"day":1,"text":"A1 test mark"}
			_expect(StateWriter.new(game).install_snapshot(fixture,game.revision,&"F0E_FIXTURE").get("ok",false),"F0-E fixture")
			_expect(not session.act("f0e_intent",intent).get("ok",false),"F0-E cannot skip authentication")
			_expect(not session.act("f0e_past").get("ok",false),"F0-E wrong order retry")
			for piece in rules.MARKS[type]: session.act("f0e_piece",piece)
			_expect(session.act("f0e_past").get("ok",false),"F0-E past mark verified")
			for external in ["father","system","servant"]:
				_expect(not session.act("f0e_author",external).get("ok",false),"F0-E external author rejected")
			_expect(session.act("f0e_author","subject").get("ok",false),"F0-E direct author")
			_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"F0-E partial reload")
			if type == "sentence" and intent == "reality":
				var view := VIEW.new()
				view.configure_session(SLOT,"F0_E")
				root.add_child(view)
				await tree.process_frame
				view._dismiss_dialogue_for_test()
				_expect(view._hotspot_layer.has_node("F0E_INTENT_stay") and view._hotspot_layer.has_node("F0E_INTENT_undecided"),"all intent buttons available")
				if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://f0e_intent.png")
				view.queue_free()
				await tree.process_frame
			_expect(session.act("f0e_intent",intent).get("ok",false),"F0-E all intents succeed")
			_expect(session.stage()=="F1", "F0-E common merge")
			_expect(session.snapshot()["ending_run"]==seed["ending_run"],"F0-E final decision unchanged")
			_expect(session.snapshot()["meta_progress"]["servants"]==seed["meta_progress"]["servants"],"F0-E relationship unchanged")
			_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"F0-E completion reload")
	await _validate_f1(session)


func _validate_f1(session: BasementSession) -> void:
	var seed := session.snapshot()
	_expect(not session.act("f1_play",7).get("ok",false),"F1 cannot auto skip")
	session.act("f1_enter")
	session.act("f1_inspect")
	_expect(not session.known("father_final_record_played"),"F1 investigation does not play")
	session.act("f1_authenticate",seed["meta_progress"]["knowledge_entries"]["self_authored_mark"]["type"])
	for index in range(8):
		_expect(session.act("f1_play",index).get("ok",false),"F1 segment")
		if index == 3:
			_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"F1 partial reload")
			session.initialize()
			_expect(session.snapshot()["loop_state"]["location_id"]=="H0_CORE_RECORDS","F1 location retained")
	_expect(session.known("KN_F1_RELEASE_HARDWARE_LOST"),"F1 no release hardware fact")
	_expect(not session.act("f1_write","subject").get("ok",false),"J5 must read page")
	session.act("f1_page")
	_expect(not session.act("f1_write","father").get("ok",false),"J5 external author rejected")
	var view := VIEW.new()
	view.configure_session(SLOT,"F1")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f1_records.png")
	view._hotspot_layer.get_node("J5_WRITE").pressed.emit()
	view._dismiss_dialogue_for_test()
	view.queue_free()
	await tree.process_frame
	_expect(session.stage()=="F2" and int(session.snapshot()["meta_progress"]["journal_stage"])==5,"J5 completes")
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"J5 completed reload")
	_expect(session.snapshot()["ending_run"]==seed["ending_run"],"F1 J5 do not decide ending")
	await _validate_f2(session)


func _validate_f2(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.CONFRONTATION
	for mask in range(32):
		var state := seed.duplicate(true)
		var index := 0
		for owner in state["meta_progress"]["servants"]:
			state["meta_progress"]["servants"][owner]["core_event_complete"] = (mask & (1<<index)) != 0
			index += 1
		state = rules.apply(state,"enter",null)["state"]
		if mask % 2 == 1:
			for question in rules.QUESTIONS: state = rules.apply(state,"question",question)["state"]
		state = rules.apply(state,"recap",null)["state"]
		_expect(rules.progress(state)["facts"].size()==6,"F2 all relationship masks receive mandatory facts")
		_expect(rules.apply(state,"finish",null)["ok"],"F2 all masks may finish")
	_expect(not session.act("f2_finish").get("ok",false),"F2 cannot bypass recap")
	session.act("f2_enter")
	session.act("f2_question","release")
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"F2 partial reload")
	var view := VIEW.new()
	view.configure_session(SLOT,"F2")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f2_questions.png")
	view._hotspot_layer.get_node("F2_RECAP").pressed.emit()
	view._dismiss_dialogue_for_test()
	view._render_room()
	view._hotspot_layer.get_node("F2_FINISH").pressed.emit()
	view._dismiss_dialogue_for_test()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false) and session.stage()=="F3","F2 completed reload")
	_expect(session.snapshot()["ending_run"]==seed["ending_run"] and session.snapshot()["meta_progress"]["servants"]==seed["meta_progress"]["servants"],"F2 ending and relationships unchanged")
	await _validate_f3(session)


func _validate_f3(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.FINAL_INSPECTION
	for order in [["wake","stay","notebook"],["stay","wake","notebook"],["notebook","wake","stay"],["notebook","stay","wake"],["wake","notebook","stay"],["stay","notebook","wake"]]:
		var state: Dictionary = rules.apply(seed,"enter",null)["state"]
		for object in order: state = rules.apply(state,"inspect",object)["state"]
		var result: Dictionary = rules.apply(state,"summary",null)
		_expect(result["ok"],"F3 any investigation order")
		_expect(result["state"]["ending_run"]==seed["ending_run"],"F3 cannot choose ending")
	_expect(session.act("f3_enter").get("ok",false),"F3 enter commits sleep lock")
	_expect(not session.sleep().get("ok",false),"F3 sleep lock")
	_expect(not session.act("f3_open").get("ok",false),"F3 cannot skip inspection")
	for object in ["wake","stay","notebook"]: session.act("f3_inspect",object)
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"F3 partial reload")
	var view := VIEW.new()
	view.configure_session(SLOT,"F3")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://f3_inspection.png")
	view._hotspot_layer.get_node("F3_SUMMARY").pressed.emit()
	view._dismiss_dialogue_for_test()
	view._render_room()
	view._hotspot_layer.get_node("F3_OPEN").pressed.emit()
	view._dismiss_dialogue_for_test()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false) and session.stage()=="EDC","F3 completed reload")
	var original_path: String = saves.get_save_root().path_join(SLOT).path_join("progress.json")
	var original_bytes := FileAccess.get_file_as_bytes(original_path)
	var f3_copy: Dictionary = saves.load_f3_reselect(SLOT)
	_expect(f3_copy.get("ok",false),"F3 independent snapshot captured")
	var clone: Dictionary = saves.create_f3_reselect_slot(SLOT)
	_expect(clone.get("ok",false),"F3 copy creates unique replay slot")
	if clone.get("ok",false):
		var replay_id: String = clone["slot_id"]
		_expect(replay_id != SLOT and replay_id not in saves.PRODUCT_SLOT_IDS,"Replay slot cannot overwrite product slot")
		_expect(LoadCoordinator.new(game,saves).load_and_install(replay_id).get("ok",false),"F3 replay copy loads through regular validator")
		_expect(game.get_snapshot()["ending_run"]["reselect_used"] and game.get_snapshot()["ending_run"]["final_decision"] == "unset","Replay starts before decision")
		var normalized_f3 := StateSnapshotValidator.new().normalize(f3_copy["snapshot"])
		_expect(game.get_snapshot()["meta_progress"]["servants"] == normalized_f3["meta_progress"]["servants"],"Replay preserves F3 relationships")
		_expect(FileAccess.get_file_as_bytes(original_path) == original_bytes,"Replay leaves original bytes intact")
		saves.delete_test_slot(replay_id)
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Restore source after replay test")
	session.act("f3_cancel")
	_expect(session.stage()=="F3" and session.snapshot()["ending_run"]==seed["ending_run"],"EDC cancel returns to inspection without decision")
	await _validate_edc(session)


func _validate_edc(session: BasementSession) -> void:
	_expect(not session.act("edc_commit", "reality").get("ok", false), "EDC cannot commit from closed inspection")
	_expect(session.act("f3_open").get("ok", false), "EDC reopens")
	var seed := session.snapshot()
	var rules = SESSION.ENDING_DECISION
	var validator := StateSnapshotValidator.new()
	_expect(seed["loop_state"]["location_id"] == "H0_CORE_CHAMBER", "EDC canonical core chamber")
	_expect(not rules.commit(seed, "invalid").get("ok", false), "EDC unknown decision rejected")
	var unlocked := seed.duplicate(true)
	unlocked["fracture_state"]["final_sleep_lock"] = false
	_expect(not rules.commit(unlocked, "reality").get("ok", false), "EDC requires final sleep lock")
	for intent in ["reality", "stay", "undecided"]:
		for decision in ["reality", "stay"]:
			for completed in [false, true]:
				var source := seed.duplicate(true)
				source["meta_progress"]["knowledge_entries"]["f0_provisional_intent"] = intent
				for servant in source["meta_progress"]["servants"].values(): servant["core_event_complete"] = completed
				var before := source.duplicate(true)
				var result: Dictionary = rules.commit(source, decision)
				_expect(result.get("ok", false) and source == before, "EDC pure commit does not mutate source")
				if not result.get("ok", false): continue
				var state: Dictionary = result["state"]
				var ending: Dictionary = state["ending_run"]
				_expect(validator.validate(state).get("ok", false), "EDC branch schema valid")
				_expect(ending["final_choice_relation"] == ("formed" if intent == "undecided" else ("reaffirmed" if intent == decision else "revised")), "EDC all six intent comparisons")
				_expect(ending["current_node_id"] == ("ED_ALL_CEREMONY" if completed else ("EDR_ENTRY" if decision == "reality" else "EDS_ENTRY")), "EDC ceremony only after all five completed")
				_expect(state["meta_progress"]["servants"] == before["meta_progress"]["servants"] and state["meta_progress"]["knowledge_entries"] == before["meta_progress"]["knowledge_entries"], "EDC no relationship or provisional writes")
				for field in ["final_choice_relation", "branch_committed", "branch_id", "current_node_id"]:
					var partial := state.duplicate(true)
					partial["ending_run"].erase(field)
					_expect(not validator.validate(partial).get("ok", false), "EDC partial field bundle rejected")
				_expect(not rules.commit(state, decision).get("ok", false), "EDC cannot recommit")
	for guard in ["F3_complete", "subject_authority_restored"]:
		var invalid := seed.duplicate(true)
		invalid["meta_progress"]["knowledge_entries"][guard] = false
		_expect(not rules.commit(invalid, "reality").get("ok", false), "EDC guard " + guard)
	var view := VIEW.new()
	view.configure_session(SLOT, "EDC")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view._restore_world_focus()
	_expect(root.gui_get_focus_owner() == view._hotspot_layer.get_node("EDC_SUBJECT"), "EDC neutral default focus")
	_expect(view._hotspot_layer.get_node("EDC_REALITY").size == view._hotspot_layer.get_node("EDC_STAY").size, "EDC equal choice area")
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://edc_choices.png")
	view._hotspot_layer.get_node("EDC_STAY").pressed.emit()
	await tree.process_frame
	_expect(view._modal_active and session.snapshot()["ending_run"]["final_decision"] == "unset", "EDC preview does not commit")
	view._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	view._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tree.process_frame
	_expect(not view._modal_active and root.gui_get_focus_owner() == view._hotspot_layer.get_node("EDC_SUBJECT"), "EDC focus return discards confirmation and stays neutral")
	view._hotspot_layer.get_node("EDC_STAY").pressed.emit()
	await tree.process_frame
	view._modal_body.get_child(3).pressed.emit()
	view._dismiss_dialogue_for_test()
	_expect(session.stage() == "F3", "EDC confirmation cancel returns F3")
	view.queue_free()
	await tree.process_frame
	_expect(session.act("f3_open").get("ok", false), "EDC reopen after preview cancel")
	var open_seed := session.snapshot()
	var valid_slot := session.slot_id
	session.slot_id = "../invalid_slot"
	_expect(not session.act("edc_commit", "stay").get("ok", false), "EDC save failure is reported")
	_expect(session.snapshot() == open_seed, "EDC failed persistence rolls back all fields")
	session.slot_id = valid_slot
	for decision in ["reality", "stay"]:
		_expect(StateWriter.new(game).install_snapshot(open_seed, game.revision, &"EDC_TEST_SEED").get("ok", false), "EDC restore test seed")
		var confirm_view := VIEW.new()
		confirm_view.configure_session(SLOT, "EDC")
		root.add_child(confirm_view)
		await tree.process_frame
		confirm_view._dismiss_dialogue_for_test()
		var before_summary: Dictionary = session.snapshot()
		confirm_view._edc_summary()
		var summary_history: Array = game.get_value("meta_progress.dialogue_history.entries", [])
		_expect(summary_history.size() == before_summary["meta_progress"]["dialogue_history"]["entries"].size() + 1, "EDC summary is recorded when shown")
		for procedure in ["wake", "stay"]:
			_expect(summary_history.back()["variables"]["text"].contains(SESSION.FINAL_INSPECTION.SUMMARIES[procedure]), "EDC history preserves both procedure summaries")
		confirm_view._modal_body.get_child(3).pressed.emit()
		var after_summary: Dictionary = session.snapshot()
		after_summary["meta_progress"]["dialogue_history"] = before_summary["meta_progress"]["dialogue_history"].duplicate(true)
		_expect(after_summary == before_summary, "Reading balanced summary does not change choice or progression")
		var history_before_confirmation: int = game.get_value("meta_progress.dialogue_history.entries", []).size()
		confirm_view._confirm_ending(decision)
		await tree.process_frame
		var preview_history: Array = game.get_value("meta_progress.dialogue_history.entries", [])
		_expect(preview_history.size() == history_before_confirmation + 1 and preview_history.back()["variables"]["text"].contains(rules.CONFIRMATIONS[decision]), "EDC records displayed confirmation for " + decision)
		_expect(session.snapshot()["ending_run"]["final_decision"] == "unset", "Recording EDC preview does not commit branch")
		confirm_view._modal_body.get_child(4).pressed.emit()
		var committed_history: Array = game.get_value("meta_progress.dialogue_history.entries", [])
		_expect(committed_history[history_before_confirmation + 1]["variables"]["text"] == "내 선택으로 확정한다", "EDC records confirmation click separately")
		confirm_view._dismiss_dialogue_for_test()
		confirm_view.queue_free()
		await tree.process_frame
		_expect(session.snapshot()["ending_run"]["final_decision"] == decision, "EDC confirmation UI commits " + decision)
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "EDC branch reload")
		_expect(session.stage() == "ENDING_SEQUENCE" and session.snapshot()["ending_run"]["branch_id"] == decision, "EDC resume committed branch")
		_expect(not session.act("f3_cancel").get("ok", false) and not session.act("edc_commit", decision).get("ok", false), "EDC no return after commit")
		await _validate_ending_entry(session)


func _validate_ending_entry(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.ENDING_ENTRY
	var wrong_branch := seed.duplicate(true)
	wrong_branch["ending_run"]["current_node_id"] = "EDS_ENTRY" if seed["ending_run"]["branch_id"] == "reality" else "EDR_ENTRY"
	_expect(not rules.apply(wrong_branch, "continue", wrong_branch["ending_run"]["current_node_id"]).get("ok", false), "Ending rejects opposite branch node")
	for ceremony in [false, true]:
		var state := seed.duplicate(true)
		var ending: Dictionary = state["ending_run"]
		ending.erase("completed_nodes")
		ending.erase("all_ceremony_seen")
		ending["current_node_id"] = "ED_ALL_CEREMONY" if ceremony else ("EDR_ENTRY" if ending["branch_id"] == "reality" else "EDS_ENTRY")
		state["loop_state"]["event_local_states"].erase("ED_ALL_CEREMONY")
		for servant in state["meta_progress"]["servants"].values(): servant["core_event_complete"] = ceremony
		_expect(StateWriter.new(game).install_snapshot(state, game.revision, &"ENDING_ENTRY_TEST").get("ok", false), "Ending seed installed")
		var before_servants: Dictionary = state["meta_progress"]["servants"].duplicate(true)
		if ceremony:
			_expect(not session.act("ending_sign").get("ok", false), "Ceremony cannot skip identities")
			for owner in rules.OWNERS:
				_expect(session.act("ending_identity", owner).get("ok", false), "Ceremony identity saved")
				_expect(not session.act("ending_identity", owner).get("ok", false), "Ceremony duplicate identity rejected")
				_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "Ceremony partial identity reload")
			_expect(session.act("ending_authority").get("ok", false), "Ceremony authority")
			var view := VIEW.new()
			view.configure_session(SLOT,"ENDING_SEQUENCE")
			root.add_child(view)
			await tree.process_frame
			view._dismiss_dialogue_for_test()
			_expect(view._hotspot_layer.has_node("ENDING_SIGNATURE") and view._hotspot_layer.has_node("ENDING_AUTO_SIGN"), "Ceremony trace and accessible alternative")
			if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://ending_signature.png")
			if seed["ending_run"]["branch_id"] == "reality":
				var signature = view._hotspot_layer.get_node("ENDING_SIGNATURE")
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				press.position = Vector2(50,50)
				signature._gui_input(press)
				var motion := InputEventMouseMotion.new()
				motion.position = Vector2(100,50)
				signature._gui_input(motion)
				press.pressed = false
				signature._gui_input(press)
			else:
				view._hotspot_layer.get_node("ENDING_AUTO_SIGN").pressed.emit()
			while view._dialogue_active: view._advance_dialogue()
			view.queue_free()
			await tree.process_frame
			_expect(session.snapshot()["ending_run"].get("all_ceremony_seen", false), "Ceremony signature saved")
		var entry: String = session.snapshot()["ending_run"]["current_node_id"]
		_expect(session.act("ending_continue", entry).get("ok", false), "Ending entry advances")
		var status: String = session.snapshot()["ending_run"]["current_node_id"]
		_expect(not session.act("ending_continue", entry).get("ok", false), "Ending stale acknowledgement rejected")
		_expect(session.act("ending_continue", status).get("ok", false), "Ending status applies")
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "Ending node reload")
		_expect(session.stage() == ("REALITY_WAKE" if seed["ending_run"]["branch_id"] == "reality" else "STAY_CHARTER"), "Ending next body boundary")
		var final_state := session.snapshot()
		_expect(final_state["ending_run"]["final_decision"] == seed["ending_run"]["final_decision"] and final_state["meta_progress"]["servants"] == before_servants, "Ending entry preserves choice and relationships")
		var channels: Dictionary = final_state["meta_progress"]["knowledge_entries"]["ending_resident_channels"]
		_expect(channels.size() == 5, "All five channels preserved even LOW")
		for mode in channels.values(): _expect(mode == ("low_power" if final_state["ending_run"]["branch_id"] == "reality" else "active"), "Ending resident mode")
		if final_state["ending_run"]["branch_id"] == "stay":
			_expect(final_state["fracture_state"]["world_phase"] == "S5", "Stay stabilizes S5 without reset")
			await _validate_stay_charter(session)
		else: await _validate_reality_wake(session)


func _validate_stay_charter(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.STAY_CHARTER
	var unset_mode := seed.duplicate(true)
	unset_mode["ending_run"]["ending_appearance_mode"] = "unset"
	_expect(StateSnapshotValidator.new().validate(unset_mode).get("ok",false),"Unset appearance remains loadable")
	unset_mode["ending_run"]["ending_appearance_mode"] = "invalid"
	_expect(not StateSnapshotValidator.new().validate(unset_mode).get("ok",false),"Invalid appearance rejected")
	_expect(not session.act("stay_memory_finish").get("ok",false),"Stay requires three memory principles")
	_expect(not session.act("stay_appearance","layered").get("ok",false),"Stay cannot skip memory")
	var view := VIEW.new()
	view.configure_session(SLOT,"STAY_CHARTER")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for index in range(3):
		view._hotspot_layer.get_node("STAY_MEMORY_%d"%index).pressed.emit()
		while view._dialogue_active: view._advance_dialogue()
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Stay memory partial reload")
		_expect(session.act("stay_memory",index).get("ok",false) and rules.progress(session.snapshot())["principles"].size() == index+1,"Reloaded principles remain deduplicated")
	view._hotspot_layer.get_node("STAY_MEMORY_FINISH").pressed.emit()
	view._restore_world_focus()
	_expect(root.gui_get_focus_owner() == view._hotspot_layer.get_node("STAY_MODE_NEUTRAL"),"Stay appearance neutral focus")
	_expect(not session.act("stay_appearance_finish").get("ok",false),"Stay requires explicit appearance choice")
	view._hotspot_layer.get_node("STAY_LAYERED").pressed.emit()
	view._hotspot_layer.get_node("STAY_CONTEXTUAL").pressed.emit()
	view._hotspot_layer.get_node("STAY_INSPECT_FRAME").pressed.emit()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://stay_appearance.png")
	view._hotspot_layer.get_node("STAY_APPEARANCE_FINISH").pressed.emit()
	_expect(not session.act("stay_autonomy_finish").get("ok",false),"Stay autonomy includes all five even LOW")
	for owner in rules.OWNERS:
		view._hotspot_layer.get_node("STAY_ROLE_"+owner).pressed.emit()
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Stay autonomy partial reload")
	view._hotspot_layer.get_node("STAY_AUTONOMY_FINISH").pressed.emit()
	view.queue_free()
	await tree.process_frame
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDS_CENTRAL_HALL","Stay charters reach central hall")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"],"Stay autonomy does not grant relationship rewards")
	_expect(session.snapshot()["fracture_state"] == seed["fracture_state"],"Appearance never restores physical reset or erases fracture")
	_expect(session.act("stay_appearance","layered").get("ok",false),"Appearance remains reversible after charters")
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Stay final appearance reload")
	_expect(session.snapshot()["ending_run"]["ending_appearance_mode"] == "layered" and session.snapshot()["ending_run"]["final_decision"] == "stay","Appearance persistence and choice invariance")
	_expect(not session.sleep().get("ok",false),"No actual sleep in ending")
	await _validate_stay_story(session)


func _validate_stay_story(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.STAY_STORY
	for mask in range(32):
		var state := seed.duplicate(true)
		var index := 0
		for owner in rules.OWNERS:
			state["meta_progress"]["servants"][owner]["core_event_complete"] = bool(mask & (1 << index))
			index += 1
		var seating: String = rules.seating(state)
		for name in rules.OWNERS.values(): _expect(name in seating,"Stay all seating combinations retain five names")
	var table_seed: Dictionary = rules.apply(seed,"dine",null)["state"]
	table_seed = rules.apply(table_seed,"sit",null)["state"]
	for order in [[0,1],[1,0]]:
		var state := table_seed.duplicate(true)
		for index in order: state = rules.apply(state,"write",index)["state"]
		_expect(rules.progress(state)["written"] == [0,1],"Stay written sentence order canonical")
		_expect(rules.apply(state,"final",null).get("ok",false),"Stay optional table objects not gates")
	var view := VIEW.new()
	view.configure_session(SLOT,"STAY_STORY")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for id in rules.HALL:
		view._hotspot_layer.get_node("STORY_HALL_"+id).pressed.emit()
		if id == "cord":
			_expect(view._modal_active,"Stay shared channel selection")
			view._modal_body.get_child(4).pressed.emit()
		else:
			while view._dialogue_active: view._advance_dialogue()
	view._hotspot_layer.get_node("STORY_DINE").pressed.emit()
	view._hotspot_layer.get_node("STORY_SIT").pressed.emit()
	while view._dialogue_active: view._advance_dialogue()
	_expect(not session.act("story_final").get("ok",false),"Stay requires manual notebook writing")
	for owner in rules.TABLE:
		view._hotspot_layer.get_node("STORY_TABLE_"+owner).pressed.emit()
		while view._dialogue_active: view._advance_dialogue()
	view._hotspot_layer.get_node("STORY_TEA_HOT").pressed.emit()
	view._hotspot_layer.get_node("STORY_WRITE_1").pressed.emit()
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Stay partial writing reload")
	_expect(session.act("story_write",1).get("ok",false) and rules.progress(session.snapshot())["written"] == [1],"Reloaded sentence remains deduplicated")
	view._render_room()
	view._hotspot_layer.get_node("STORY_WRITE_0").pressed.emit()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://stay_table.png")
	view._hotspot_layer.get_node("STORY_FINAL").pressed.emit()
	view.set_process(false)
	_expect(not session.act("story_finish").get("ok",false),"Stay opening pose precedes chosen positions")
	for index in range(2): _expect(session.act("story_tick").get("ok",false),"Stay final pose time")
	view._render_room()
	session.ending_meta_store = preload("res://scripts/systems/ending_meta_store.gd").new("user://__test_auto_meta_stay_%s" % Time.get_ticks_usec())
	view.session.ending_meta_store = session.ending_meta_store
	view._hotspot_layer.get_node("STORY_FINISH").pressed.emit()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Stay final frame reload")
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "CREDITS_STAY","Stay reaches credits boundary")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"] and session.snapshot()["ending_run"]["final_decision"] == "stay","Stay story preserves choice and relationships")
	await _validate_credits(session)


func _validate_reality_wake(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.REALITY_WAKE
	for owner in rules.OWNERS:
		for outcome in rules.OVERLAYS[owner]:
			var source := seed.duplicate(true)
			source["meta_progress"]["servants"][owner]["core_event_complete"] = true
			source["meta_progress"]["servants"][owner]["researcher_record_acquired"] = true
			source["meta_progress"]["event_history"][rules.EVENTS[owner]] = {"outcome_id":outcome,"lifecycle":"completed"}
			var before := source.duplicate(true)
			var response: Dictionary = rules.farewell(source,owner)
			_expect(not response["warning"] and source == before, "Farewell outcome overlay is read-only")
	var view := VIEW.new()
	view.configure_session(SLOT,"REALITY_WAKE")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for owner in rules.OWNERS:
		var before_index: int = rules.index(session.snapshot())
		view._hotspot_layer.get_node("REALITY_FAREWELL").pressed.emit()
		_expect(rules.index(session.snapshot()) == before_index, "Farewell not saved before acknowledgement")
		while view._dialogue_active: view._advance_dialogue()
		_expect(rules.index(session.snapshot()) == before_index + 1, "Farewell acknowledged once")
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "Farewell partial reload")
		view._render_room()
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDR_DISCONNECT", "All five farewell records remain present")
	view._hotspot_layer.get_node("REALITY_DISCONNECT").pressed.emit()
	while view._dialogue_active: view._advance_dialogue()
	await tree.create_timer(1.3).timeout
	_expect(session.snapshot()["loop_state"]["location_id"] == "R0_CRYO_CHAMBER", "Disconnect enters physical cryo chamber")
	_expect(session.snapshot()["fracture_state"]["world_phase"] == "R0", "Reality world phase")
	view._open_notebook()
	_expect(not view._modal_active, "Reality cannot open simulation notebook")
	view._hotspot_layer.get_node("REALITY_WAKE").pressed.emit()
	while view._dialogue_active: view._advance_dialogue()
	_expect(not session.act("reality_body_finish").get("ok",false), "Body check requires two distinct objects")
	var body_seed := session.snapshot()
	var keys: Array = rules.BODY.keys()
	for pair in [[keys[0],keys[1]],[keys[0],keys[2]],[keys[1],keys[2]]]:
		var state := body_seed.duplicate(true)
		for object in pair: state = rules.apply(state,"body",object)["state"]
		_expect(rules.apply(state,"body_finish",null).get("ok",false), "Any two physical observations qualify")
	for object in [keys[0],keys[0],keys[1]]:
		view._hotspot_layer.get_node(object).pressed.emit()
		while view._dialogue_active: view._advance_dialogue()
	_expect(session.snapshot()["ending_run"]["required_interactions_seen"].size() == 2, "Repeated physical observation is deduplicated")
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://reality_body_check.png")
	view._hotspot_layer.get_node("REALITY_BODY_FINISH").pressed.emit()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "Reality body completed reload")
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDR_FIELD_NOTEBOOK", "Reality reaches physical notebook")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"] and session.snapshot()["ending_run"]["final_decision"] == "reality", "Wake has no relation reward or ending reversal")
	await _validate_field_notebook(session)


func _validate_field_notebook(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.FIELD_NOTEBOOK
	_expect(not session.act("field_finish").get("ok",false),"Field notebook required pages")
	var view := VIEW.new()
	view.configure_session(SLOT,"FIELD_NOTEBOOK")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	var before_failed_read: Dictionary = session.snapshot()
	var original_slot: String = view.session.slot_id
	view.session.slot_id = "../invalid_slot"
	view._open_field_page("FIELD_NOTEBOOK_PREFACE", false)
	var retry_button := view._modal_body.get_child(3) as Button
	retry_button.pressed.emit()
	_expect(session.snapshot() == before_failed_read and view._modal_active, "Failed reading transcript save preserves state and keeps page open")
	view.session.slot_id = original_slot
	retry_button.pressed.emit()
	_expect(not view._modal_active, "Reading can retry successfully after persistence is restored")
	view._dismiss_dialogue_for_test()
	for page in rules.PAGES:
		var before_page: Dictionary = session.snapshot()
		var summary_text: String = rules.page_text(before_page, page, false)
		view._open_field_page(page,false)
		_expect(view._modal_active,"Field page summary opens")
		var summaries: Array = game.get_value("meta_progress.dialogue_history.entries", [])
		_expect(summaries.size() == before_page["meta_progress"]["dialogue_history"]["entries"].size() + 1, "Opening notebook summary records one visible panel")
		_expect(summaries.back()["variables"]["text"] == rules.PAGES[page][0] + "\n" + summary_text + "\n읽기 확인 후 닫기\n펼쳐 읽기\n" + (view._modal_body.get_child(5) as Button).text, "Summary history contains displayed text and navigation only")
		var after_page: Dictionary = session.snapshot()
		after_page["meta_progress"]["dialogue_history"] = before_page["meta_progress"]["dialogue_history"].duplicate(true)
		_expect(after_page == before_page, "Opening a page does not mark expanded or confirmed reading")
		var stale_read := view._modal_body.get_child(3) as Button
		view._open_field_page(page,true)
		var expanded_state: Dictionary = session.snapshot()
		var expanded_entries: Array = expanded_state["meta_progress"]["dialogue_history"]["entries"]
		_expect(expanded_entries.size() == summaries.size() + 1 and expanded_entries.back()["variables"]["text"].contains(rules.page_text(before_page, page, true)), "Only opened expanded page is appended")
		stale_read.pressed.emit()
		_expect(session.snapshot() == expanded_state and view._modal_active, "Replaced summary callback cannot confirm stale reading")
		await tree.process_frame
		if page == "SUBJECT_HANDOFF_PAGE" and "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://field_notebook_page.png")
		view._modal_body.get_child(3).pressed.emit()
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Field page reload")
		_expect(game.get_value("meta_progress.dialogue_history.entries", []).has(expanded_entries.back()), "Expanded reading transcript survives reload")
	view._render_room()
	view._hotspot_layer.get_node("FIELD_FINISH").pressed.emit()
	_expect(session.snapshot()["loop_state"]["location_id"] == "R0_FACILITY_EXIT","Field notebook leads to physical exit")
	_expect(not session.act("field_unlock").get("ok",false),"Exit cannot skip three status checks")
	for id in rules.EXIT:
		view._hotspot_layer.get_node(id).pressed.emit()
		while view._dialogue_active: view._advance_dialogue()
	view._hotspot_layer.get_node("FIELD_UNLOCK").pressed.emit()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Exit unlock reload")
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDR_FACILITY_FREE_LOOK","Exit reaches free investigation")
	_expect(session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"],"Reading does not change relationships")
	var minimal := seed.duplicate(true)
	for id in rules.REQUIRED: minimal = rules.apply(minimal,"read",id)["state"]
	_expect(rules.apply(minimal,"finish",null).get("ok",false),"Optional pages are not gates")
	await _validate_surface(session)


func _validate_surface(session: BasementSession) -> void:
	var seed := session.snapshot()
	var rules = SESSION.REALITY_SURFACE
	var skip := seed.duplicate(true)
	for action in ["airlock","enter","outside"]:
		var result: Dictionary = rules.apply(skip,action,null)
		_expect(result.get("ok",false),"Surface optional investigations never gate")
		skip = result["state"]
	_expect(rules.local(skip)["seen"].is_empty(),"Unobserved signal stays unobserved")
	var invalid := skip.duplicate(true)
	invalid["ending_run"]["current_node_id"] = "EDR_SURFACE_THRESHOLD"
	invalid["ending_run"]["completed_nodes"].erase("EDR_BODY_CHECK")
	_expect(not rules.apply(invalid,"outside",null).get("ok",false),"Final frame requires body/notebook/exit completion")
	var view := VIEW.new()
	view.configure_session(SLOT,"REALITY_SURFACE")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for location in ["R0_CRYO_CHAMBER","R0_FACILITY_EXIT"]:
		_expect(session.act("surface_move",location).get("ok",false),"Surface internal movement")
		view._render_room()
		for id in rules.OBJECTS:
			if rules.OBJECTS[id][0] != location: continue
			view._hotspot_layer.get_node("SURFACE_OBJ_"+id).pressed.emit()
			while view._dialogue_active: view._advance_dialogue()
	view._hotspot_layer.get_node("SURFACE_AIRLOCK").pressed.emit()
	view._hotspot_layer.get_node("SURFACE_CANCEL").pressed.emit()
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDR_FACILITY_FREE_LOOK","Airlock cancel returns to investigation")
	view._hotspot_layer.get_node("SURFACE_AIRLOCK").pressed.emit()
	view._hotspot_layer.get_node("SURFACE_ENTER").pressed.emit()
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Surface arrival reload")
	view._render_room()
	view._hotspot_layer.get_node("SURFACE_OBJ_signal").pressed.emit()
	while view._dialogue_active: view._advance_dialogue()
	view._hotspot_layer.get_node("SURFACE_OUTSIDE").pressed.emit()
	view.set_process(false)
	view._hotspot_layer.get_node("SURFACE_LOOK_left").pressed.emit()
	view.set_process(false)
	view._open_notebook()
	_expect(view._modal_active,"Physical notebook remains readable on surface")
	var elapsed: int = rules.local(session.snapshot())["elapsed"]
	view._on_surface_tick()
	_expect(rules.local(session.snapshot())["elapsed"] == elapsed,"Final frame pauses during notebook")
	view._close_modal()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://reality_final_frame.png")
	for index in range(7): _expect(session.act("surface_tick").get("ok",false),"Final frame advances active second")
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "EDR_FINAL_FRAME","Final frame remains until eight seconds")
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Final frame partial reload")
	session.ending_meta_store = preload("res://scripts/systems/ending_meta_store.gd").new("user://__test_auto_meta_reality_%s" % Time.get_ticks_usec())
	_expect(session.act("surface_tick").get("ok",false),"Final eighth second")
	_expect(session.snapshot()["ending_run"]["current_node_id"] == "CREDITS_REALITY","Reality final frame reaches credits boundary")
	_expect(rules.local(session.snapshot())["look"] == "left","No automatic signal zoom")
	_expect(session.snapshot()["ending_run"]["final_decision"] == "reality" and session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"],"Last gaze does not change ending or relationships")
	view.queue_free()
	await tree.process_frame
	await _validate_credits(session)


func _validate_credits(session: BasementSession) -> void:
	var seed := session.snapshot()
	var profile: Dictionary = session.ending_meta_store.load_profile()
	var gallery = preload("res://scripts/systems/ending_gallery_store.gd").new(session.ending_meta_store.root_path.path_join("ending_gallery"))
	var archived: Dictionary = gallery.capture(seed)
	_expect(archived.get("ok",false), "Completed ending gallery archive")
	_expect(gallery.capture(seed).get("id") == archived.get("id"), "Gallery capture is idempotent")
	var unseen := seed.duplicate(true)
	unseen["ending_run"]["completed_nodes"].erase("EDR_FINAL_FRAME")
	unseen["ending_run"]["completed_nodes"].erase("EDS_FINAL_FRAME")
	_expect(not gallery.capture(unseen).get("ok",false), "Gallery rejects unseen ending")
	_expect(not gallery.read_entry("../progress").get("ok",false), "Gallery rejects path traversal")
	_expect(gallery.read_entry(archived.get("id","")).get("state",{}).get("meta_progress",{}) == seed["meta_progress"], "Gallery retains actual relationship and record state")
	_expect(profile.get("ok",false) and profile["profile"]["ending_meta"][seed["ending_run"]["branch_id"] + "_seen"],"Final frame automatically commits seen before credits")
	var real_store = session.ending_meta_store
	session.ending_meta_store = UnavailableEndingMeta.new()
	_expect(session._commit(seed.duplicate(true),"").get("ok",false),"Meta failure preserves successful final frame save")
	_expect(not session.act("credits_start").get("ok",false),"Meta failure blocks credits start")
	_expect(not session.snapshot()["ending_run"].get("credits_started",false),"Failed meta does not start credits")
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Final frame reload after meta failure")
	session.ending_meta_store = real_store
	_expect(session.ensure_ending_meta().get("ok",false),"Meta retry after reload succeeds")
	_expect(not session.act("credits_finish").get("ok",false),"Credits cannot finish before pages")
	var invalid := seed.duplicate(true)
	invalid["ending_run"]["completed_nodes"].erase("EDR_FINAL_FRAME")
	invalid["ending_run"]["completed_nodes"].erase("EDS_FINAL_FRAME")
	_expect(not SESSION.ENDING_CREDITS.apply(invalid,"start",null).get("ok",false),"Credits require final frame")
	var view := VIEW.new()
	view.configure_session(SLOT,"ENDING_CREDITS")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view._hotspot_layer.get_node("CREDITS_START").pressed.emit()
	_expect(not session.act("credits_start").get("ok",false),"Credits cannot restart accidentally")
	for index in range(2):
		view._hotspot_layer.get_node("CREDITS_NEXT").pressed.emit()
		_expect(not session.act("credits_next",index).get("ok",false),"Credits stale page acknowledgement rejected")
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false),"Credits page reload")
		view._render_room()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://ending_credits.png")
	view._hotspot_layer.get_node("CREDITS_FINISH").pressed.emit()
	_expect(session.stage() == "POST_CREDITS" and view._hotspot_layer.has_node("CREDITS_TITLE"),"Credits finish reaches real title action")
	var source_path: String = saves.get_save_root().path_join(SLOT).path_join("progress.json")
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	var before_gallery := session.snapshot()
	_expect(not view._history_enabled(), "post credits does not record new dialogue")
	view._open_menu()
	var history_button := view._modal_body.get_child(4) as Button
	_expect(history_button.text == view._dialogue_ui_text("CH1_HISTORY_TITLE"), "post credits offers existing dialogue history")
	history_button.pressed.emit()
	_expect(view._modal_active and (view._modal_body.get_child(0) as Label).text == view._dialogue_ui_text("CH1_HISTORY_TITLE"), "post credits opens transcript")
	(view._modal_body.get_child(3) as Button).pressed.emit()
	_expect(session.snapshot() == before_gallery and FileAccess.get_file_as_bytes(source_path) == source_bytes, "post credits history preserves state and save bytes")
	var pages = preload("res://scripts/systems/ending_gallery_pages.gd")
	_expect(not pages.build(before_gallery).is_empty(), "Gallery contains completed final frame")
	var uninspected := before_gallery.duplicate(true)
	uninspected["ending_run"]["all_ceremony_seen"] = false
	for entry_node in SESSION.ENDING_ENTRY.TEXT: uninspected["ending_run"]["completed_nodes"].erase(entry_node)
	uninspected["loop_state"]["event_local_states"]["EDR_FAREWELL"] = {"index":0}
	uninspected["ending_run"]["required_interactions_seen"] = []
	uninspected["loop_state"]["event_local_states"]["FIELD_NOTEBOOK"] = {"pages":[]}
	uninspected["loop_state"]["event_local_states"]["STAY_CHARTER"] = {"principles":[],"proposed":[]}
	uninspected["loop_state"]["event_local_states"]["REALITY_SURFACE"] = {"seen":[],"look":"center","elapsed":8}
	uninspected["loop_state"]["event_local_states"]["STAY_STORY"] = {"hall":[],"table":[],"written":[],"elapsed":2}
	_expect(pages.build(uninspected).size() == 1, "Gallery hides uninspected optional objects and lines")
	var all_record := uninspected.duplicate(true)
	for owner in SESSION.ENDING_ENTRY.OWNERS: all_record["meta_progress"]["servants"][owner]["core_event_complete"] = true
	var baseline_count: int = pages.build(all_record).size()
	_expect(baseline_count == 1, "All relationships alone do not reveal ceremony")
	all_record["ending_run"]["all_ceremony_seen"] = true
	all_record["ending_run"]["completed_nodes"].erase("ED_ALL_CEREMONY")
	_expect(pages.build(all_record).size() == baseline_count, "Seen flag without completed ceremony remains hidden")
	all_record["ending_run"]["completed_nodes"].append("ED_ALL_CEREMONY")
	all_record["loop_state"]["event_local_states"]["ED_ALL_CEREMONY"] = {"identity_index":5,"authority_seen":true}
	_expect(pages.build(all_record).size() == baseline_count + 6, "Completed ALL ceremony exposes five identities and authority")
	if before_gallery["ending_run"]["branch_id"] == "stay":
		var charter_state := uninspected.duplicate(true)
		charter_state["loop_state"]["event_local_states"]["STAY_CHARTER"] = {"principles":[1.0],"proposed":["luca"]}
		_expect(pages.build(charter_state).size() == 3, "Gallery replays only acknowledged charter principle and owner")
		charter_state["ending_run"]["ending_appearance_mode"] = "layered"
		_expect(pages.build(charter_state).size() == 3, "Unconfirmed appearance is not a gallery page")
		charter_state["ending_run"]["required_interactions_seen"] = ["OBJ_STAY_APPEARANCE_CONTROL"]
		_expect(pages.build(charter_state).size() == 4, "Confirmed appearance adds one gallery page")
	if before_gallery["ending_run"]["branch_id"] == "reality":
		var partial := uninspected.duplicate(true)
		partial["loop_state"]["event_local_states"]["EDR_FAREWELL"] = {"index":1}
		var partial_pages: Array[Dictionary] = pages.build(partial)
		_expect(partial_pages.size() > 1, "Gallery replays acknowledged farewell")
		for page in partial_pages:
			_expect(not str(page["title"]).begins_with("작별 · 이리스"), "Gallery cannot reveal unacknowledged Iris farewell")
		partial["ending_run"]["required_interactions_seen"] = ["OBJ_REALITY_HAND"]
		var body_pages: Array[Dictionary] = pages.build(partial)
		_expect(body_pages.size() == partial_pages.size() + 1, "Gallery replays only inspected body object")
		partial["loop_state"]["event_local_states"]["FIELD_NOTEBOOK"] = {"pages":["FIELD_NOTEBOOK_PREFACE"]}
		var notebook_pages: Array[Dictionary] = pages.build(partial)
		_expect(notebook_pages.size() == body_pages.size() + 1, "Gallery shows only acknowledged notebook page")
		for page in notebook_pages:
			if str(page["title"]).begins_with("현장 수첩"):
				_expect(page["text"] == SESSION.FIELD_NOTEBOOK.PAGES["FIELD_NOTEBOOK_PREFACE"][1], "Gallery does not infer expanded notebook reading")
		partial["ending_run"]["required_interactions_seen"].append("EXIT_STATUS_AIR")
		_expect(pages.build(partial).size() == notebook_pages.size() + 1, "Gallery shows only inspected exit check")
		var expanded_result: Dictionary = SESSION.FIELD_NOTEBOOK.apply(before_gallery,"read",{"page":"FIELD_NOTEBOOK_PREFACE","expanded":true})
		_expect(expanded_result.get("ok",false), "Expanded notebook acknowledgement accepted")
		if expanded_result.get("ok",false):
			var expanded_state: Dictionary = expanded_result["state"]
			var repeated: Dictionary = SESSION.FIELD_NOTEBOOK.apply(expanded_state,"read",{"page":"FIELD_NOTEBOOK_PREFACE","expanded":true})
			_expect(repeated["state"]["loop_state"]["event_local_states"]["FIELD_NOTEBOOK"]["expanded_pages"].count("FIELD_NOTEBOOK_PREFACE") == 1, "Expanded notebook history deduplicated")
			var found_expanded := false
			for page in pages.build(expanded_state):
				if page["title"] == "현장 수첩 · " + SESSION.FIELD_NOTEBOOK.PAGES["FIELD_NOTEBOOK_PREFACE"][0]:
					found_expanded = page["text"] == SESSION.FIELD_NOTEBOOK.page_text(expanded_state,"FIELD_NOTEBOOK_PREFACE",true)
			_expect(found_expanded, "Gallery uses explicitly acknowledged expanded text")
		_expect(not SESSION.FIELD_NOTEBOOK.apply(before_gallery,"read",{"page":"FIELD_NOTEBOOK_PREFACE","expanded":"true"}).get("ok",false), "Notebook rejects malformed expanded flag")
	view._hotspot_layer.get_node("CREDITS_GALLERY").pressed.emit()
	_expect(view._modal_active, "Gallery opens read-only menu")
	var archived_entries: Array[Dictionary] = preload("res://scripts/systems/ending_gallery_store.gd").new().list_entries()
	_expect(not archived_entries.is_empty(), "Gallery has archived entries")
	if not archived_entries.is_empty():
		view._gallery_page(archived_entries[0]["id"],0)
		_expect(view._modal_active, "Gallery renders archived text page")
	view._close_modal()
	_expect(session.snapshot() == before_gallery and FileAccess.get_file_as_bytes(source_path) == source_bytes, "Gallery never installs or saves gameplay state")
	view._hotspot_layer.get_node("CREDITS_RESELECT").pressed.emit()
	_expect(view._modal_active, "Post credits opens reselect menu")
	view._close_modal()
	_expect(FileAccess.get_file_as_bytes(source_path) == source_bytes, "Reselect menu cancel preserves source")
	_expect(saves.load_f3_reselect(SLOT).get("ok", false), "Completed source retains a valid F3 copy for UI test")
	if saves.load_f3_reselect(SLOT).get("ok", false):
		view._confirm_reselect()
		_expect(view._modal_active, "Reselect requires confirmation")
		view._create_reselect()
		var replay_id: String = view._slot_id
		_expect(replay_id != SLOT and view.session.snapshot()["ending_run"]["reselect_used"], "Reselect UI switches to separate slot")
		_expect(view.session.act("f3_cancel").get("ok", false), "Replay can return to F3 inspection")
		_expect(FileAccess.get_file_as_bytes(source_path) == source_bytes, "Replay action does not write source")
		var listed := false
		for entry in saves.list_reselect_slots(SLOT):
			if entry["slot_id"] == replay_id: listed = true
		_expect(listed, "Replay remains discoverable from original ending")
		_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false), "Restore original after replay UI")
		saves.delete_test_slot(replay_id)
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(game,saves).load_and_install(SLOT).get("ok",false) and session.stage() == "POST_CREDITS","Credits completion reload")
	_expect(saves.inspect_slot(SLOT).get("save_point_id","") == "SAVE_ENDING_COMPLETE","Credits final save point")
	_expect(session.snapshot()["ending_run"]["final_decision"] == seed["ending_run"]["final_decision"] and session.snapshot()["meta_progress"]["servants"] == seed["meta_progress"]["servants"],"Credits preserve choice and relationships")
	var meta_path: String = real_store.root_path
	if "__test_auto_meta_" in meta_path:
		var gallery_path := meta_path.path_join("ending_gallery")
		for name in DirAccess.get_files_at(gallery_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(gallery_path.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gallery_path))
		for name in real_store.FILES: DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path))


func _validate_e6_ui(session: BasementSession) -> void:
	var before := session.snapshot()
	var view := VIEW.new()
	view.configure_session(SLOT, "E6")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._hotspot_layer.has_node("E6_ENTER"), "E6 entry button visible")
	var after_intro := session.snapshot()
	before["meta_progress"]["dialogue_history"] = after_intro["meta_progress"]["dialogue_history"].duplicate(true)
	_expect(after_intro == before, "E6 opening only appends displayed dialogue history")
	view._hotspot_layer.get_node("E6_ENTER").pressed.emit()
	await tree.process_frame
	var focus := root.gui_get_focus_owner() as Button
	_expect(focus != null and focus.text == "아직 조사한다", "E6 confirmation defaults to stay")
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://e6_confirmation.png")
	view._close_modal()
	view.queue_free()
	await tree.process_frame
	_expect(session.snapshot() == before, "E6 UI cancellation unchanged")


func _validate_e5_ui(session: BasementSession) -> void:
	var before := session.snapshot()
	var view := VIEW.new()
	view.configure_session(SLOT, "E5")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._hotspot_layer.has_node("E5_SIT"), "E5 seat button visible")
	view._hotspot_layer.get_node("E5_SIT").pressed.emit()
	view._dismiss_dialogue_for_test()
	view._render_room()
	_expect(view._hotspot_layer.has_node("E5_QUESTION_stay"), "all E5 questions accessible")
	view._hotspot_layer.get_node("E5_QUESTION_stay").pressed.emit()
	view._dismiss_dialogue_for_test()
	view._render_room()
	view._hotspot_layer.get_node("E5_FINISH").pressed.emit()
	await tree.process_frame
	var focus := root.gui_get_focus_owner() as Button
	_expect(focus != null and focus.text == "아직 준비되지 않았다", "E5 confirmation defaults to defer")
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://e5_confirmation.png")
	view._close_modal()
	view.queue_free()
	await tree.process_frame
	_expect(StateWriter.new(game).install_snapshot(before, game.revision, &"E5_UI_RESTORE").get("ok", false), "E5 UI fixture restore")


func _validate_mara2(session: BasementSession) -> void:
	var hub: Dictionary = game.get_snapshot()
	var rules = BasementSession.MARA2_RELATIONSHIP
	var record := ""
	for outcome in ["merged", "separated"]:
		_expect(StateWriter.new(game).install_snapshot(hub, game.revision, StringName("MARA2_FIXTURE_" + outcome)).get("ok", false), "Mara2 fixture")
		_move(session, ["M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY", "H0_COLOR_SEPARATION"])
		_expect(not session.act("move", "H0_PERSONALITY_ARCHIVE").get("ok", false), "archive needs common gaps")
		_expect(not session.act("mara2_source", ["A", "MARA2", "EDGAR"]).get("ok", false), "mixed owner source rejected")
		for portrait in rules.PORTRAITS:
			for owner in rules.OWNERS: session.act("mara2_source", [portrait, owner, owner])
		for portrait in ["A", "B", "C"]: session.act("mara2_portrait", portrait)
		_expect(not session.act("mara2_overlay").get("ok", false), "wrong degradation chronology rejected")
		session.act("mara2_clear")
		for portrait in rules.ORDER: session.act("mara2_portrait", portrait)
		_expect(not session.act("mara2_overlay").get("ok", false), "wave alignment required")
		for portrait in rules.PORTRAITS:
			for kind in ["start", "outline"]: session.act("mara2_align", [portrait, kind, rules.PORTRAITS[portrait][kind]])
		session.act("mara2_overlay")
		_move(session, ["H0_PERSONALITY_ARCHIVE"])
		for owner in rules.BACKUPS: session.act("mara2_backup", owner)
		for index in rules.GAPS: session.act("mara2_cell", [index, "선"])
		session.act("mara2_checksum")
		_expect(not session.known("E3_5_puzzle_solved"), "wrong checksum not completed")
		for index in rules.GAPS: session.act("mara2_cell", [index, rules.CHECKSUM[index]])
		session.act("mara2_checksum")
		_expect(session.known("E3_5_puzzle_solved") and not session.known("REC_MARA2"), "technical checkpoint is not relationship completion")
		_move(session, ["H0_COLOR_SEPARATION", "M1_COLOR_ROOM_ENTRY", "M1_NORTH_ARCHIVE_HALL", "M1_CENTRAL_HALL", "M2_BEDROOM"])
		session.sleep()
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Mara2 checkpoint reload")
		_move(session, ["M1_CENTRAL_HALL", "M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY", "H0_COLOR_SEPARATION", "H0_PERSONALITY_ARCHIVE"])
		_expect(rules.progress(game.get_snapshot())["solved"], "Mara2 puzzle survives exit rest load")
		session.act("mara2_confess")
		var before: Dictionary = game.get_value("meta_progress.servants.mara2")
		var view := VIEW.new()
		view.configure_session(SLOT, "E3_5")
		root.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		view._hotspot_layer.get_node("MARA2_CHOICE").pressed.emit()
		await tree.process_frame
		_expect((root.gui_get_focus_owner() as Button).text == "설명을 다시 생각한다", "Mara2 choice defaults to defer")
		if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://mara2_choice.png")
		view._modal_body.get_child(4 if outcome == "merged" else 5).pressed.emit()
		view._dismiss_dialogue_for_test()
		view.queue_free()
		await tree.process_frame
		_expect(session.known("REC_MARA2") and session.known("mara2_self_sacrifice_known") and session.known("mara2_archive_index_known"), "Mara2 record and identity after choice")
		var after: Dictionary = game.get_value("meta_progress.servants.mara2")
		_expect(after["core_event_complete"] and after["researcher_record_acquired"], "Mara2 completion flags")
		_expect(int(after["bond"]) == clampi(int(before["bond"]) + (2 if outcome == "merged" else 1), 0, 5), "Mara2 bond")
		_expect(int(after["alert"]) == clampi(int(before["alert"]) + (1 if outcome == "merged" else -1), 0, 5), "Mara2 alert")
		var current := String(game.get_value("meta_progress.knowledge_entries.chapter_notebook.REC_MARA2"))
		if record.is_empty(): record = current
		else: _expect(record == current, "both archive choices preserve identical facts")
		session.act("mara2_choose", outcome)
		_expect(game.get_value("meta_progress.servants.mara2") == after, "Mara2 cannot repeat relationship rewards")
		_expect(LoadCoordinator.new(game, saves).load_and_install(SLOT).get("ok", false), "Mara2 completion loads")
		_expect(game.get_value("meta_progress.event_history.E3_5.outcome_id") == outcome, "archive resolution persisted in outcome")
		_move(session, ["H0_COLOR_SEPARATION", "M1_COLOR_ROOM_ENTRY", "M1_NORTH_ARCHIVE_HALL", "M1_CENTRAL_HALL"])

func _validate_ui(session: BasementSession, axis_state: Dictionary) -> void:
	var completed: Dictionary = game.get_snapshot()
	StateWriter.new(game).install_snapshot(axis_state, game.revision, &"BASEMENT_UI_FIXTURE")
	var view := VIEW.new()
	view.configure_session(SLOT, "D1")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view._hotspot_layer.get_node("PUSH_branch").pressed.emit()
	await tree.process_frame
	_expect(view._modal_active, "axis irreversible confirmation appears")
	var focused := root.gui_get_focus_owner() as Button
	_expect(focused != null and focused.text == "수첩 도면을 본다", "axis confirmation defaults to notebook")
	view._close_modal()
	if "--capture-basement-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://basement_axes.png")
		print("BASEMENT_CAPTURE: " + ProjectSettings.globalize_path("user://basement_axes.png"))
	view.queue_free()
	await tree.process_frame
	StateWriter.new(game).install_snapshot(completed, game.revision, &"BASEMENT_UI_RESTORE")
	session.initialize()
	view = VIEW.new()
	view.configure_session(SLOT, "DEMO_END_SCREEN")
	root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._hotspot_layer.get_node_or_null("RETURN_TITLE") != null, "demo boundary presents title exit")
	_expect(view._hotspot_layer.get_node_or_null("SLEEP") == null, "demo boundary has no full-game sleep action")
	view.queue_free()
	await tree.process_frame


func _move(session: BasementSession, path: Array) -> void:
	for room in path: _expect(session.act("move", room).get("ok", false), "move " + room)

func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
