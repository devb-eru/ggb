extends RefCounted

const SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const SLOT := "__test_black_mirror"
var errors := PackedStringArray()

func run(tree: SceneTree) -> Dictionary:
	GameState.reset_for_test()
	SaveManager.delete_test_slot(SLOT)
	var seed := GameState.get_snapshot()
	seed["meta_progress"]["journal_stage"] = 2
	seed["meta_progress"]["notebook_persistence_confirmed"] = true
	seed["meta_progress"]["knowledge_entries"] = {"PROLOGUE_COMPLETE": true, "j2_restored_day": 3, "KN_B1_LIBRARY_WINDOW": true, "b4_waveform_acquired": true, "self_authored_mark": {"day": 1}, "MEM_FATHER_TEA_HAND_FRAGMENT": "sensory_fragment"}
	seed["loop_state"]["day_index"] = 3
	seed["loop_state"]["location_id"] = "M2_BEDROOM"
	StateWriter.new(GameState).install_snapshot(seed, GameState.revision, &"MIRROR_SEED")
	var session := SESSION.new(GameState, SaveManager, SLOT)
	_expect(session.initialize().get("ok", false), "initialize after J2")
	_expect(session.stage() == "C_SLEEP", "C0 requires next morning")
	_expect(not session.act("c_observe").get("ok", false), "cannot skip J2 sleep")
	session.act("routine")
	_expect(session.sleep().get("ok", false), "J2 sleep")
	_expect(session.stage() == "C0", "next morning opens C0")
	_expect(not session.act("move", "M1_MIRROR_GALLERY").get("ok", false), "mirror is not directly off bedroom")
	_travel(session, "M1_MIRROR_GALLERY")
	session.act("c_observe")
	session.act("c_hypothesis")
	_travel(session, "M1_TOOL_ROOM")
	_expect(session.act("c_read_cleaning").get("ok", false), "C2 object source independent of servant presence")
	_travel(session, "M1_KITCHEN")
	_expect(not session.act("c_prepare").get("ok", false), "both documents required")
	session.act("c_read_chemicals")
	session.act("c_prepare")
	_expect(not session.act("c_pour", "active").get("ok", false), "unsafe dry-bottle active input rejected")
	_expect(session.mirror_local()["mixture"]["active"] == 0, "rejected input has no side effect")
	session.act("c_pour", "water")
	session.act("c_test")
	_expect(not session.mirror_local()["cleaner_ready"], "wrong mixture cannot create cleaner")
	session.act("c_discard")
	_make_cleaner(session)
	_expect("NEUTRAL_CLEANER" in GameState.get_value(&"loop_state.inventory"), "cleaner is physical inventory")
	_travel(session, "M1_GREAT_CLOCK")
	_expect(session.act("c_bell").get("ok", false), "repeat thirteenth bell using verified settings")
	_travel(session, "M1_MIRROR_GALLERY")
	session.act("c_dry")
	_expect(not session.mirror_local()["locked"], "dry failure is reversible")
	_expect(not session.act("c_wet", false).get("ok", false), "wet trace requires confirmation")
	session.act("c_wet", true)
	_expect(session.stage() == "CF", "bad anchor hardens coating")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "load hard failure")
	_expect(session.stage() == "CF" and not session.act("c_rotate").get("ok", false), "loading cannot repair failed mirror")
	_travel(session, "M2_BEDROOM")
	session.act("routine")
	session.sleep()
	_expect(session.mirror_local()["mixture"]["water"] == 0 and not session.mirror_local()["cleaner_ready"], "physical solution resets")
	_expect(session.known("c3_formula_verified"), "verified formula survives sleep")
	_expect(session.act("c_shortcut").get("ok", false), "CSHORT reacquires materials")
	_expect(not session.mirror_local()["cleaner_ready"], "CSHORT does not auto manufacture cleaner")
	_make_cleaner(session)
	_travel(session, "M1_GREAT_CLOCK")
	session.act("c_bell")
	_travel(session, "M1_MIRROR_GALLERY")
	session.act("c_rotate")
	session.act("c_anchor")
	for part in RULES.PATH: session.act("c_segment", part)
	session.act("c_dry")
	_expect(session.mirror_local()["dry_passed"], "correct dry trace passes")
	_expect(session.act("c_verify_plan").get("ok", false), "explicitly verify observed plan")
	var ready := GameState.get_snapshot()
	var alert := ready.duplicate(true)
	alert["meta_progress"]["servants"]["edgar"]["alert"] = 5
	StateWriter.new(GameState).install_snapshot(alert, GameState.revision, &"MIRROR_ALERT")
	session.act("c_wet", true)
	_expect(GameState.get_value(&"meta_progress.failure_knowledge.C4.category") == "tool_confiscated", "unhandled alert can confiscate tool")
	StateWriter.new(GameState).install_snapshot(alert, GameState.revision, &"MIRROR_ALERT_REPLAY")
	session.act("c_handle_patrol", "wait")
	session.act("c_wet", true)
	_expect(session.known("mirror_tracing_acquired"), "patrol handling preserves correct path at high alert")
	_expect(GameState.get_value(&"fracture_state.world_phase") == "S2", "diagnostic exposure advances visual state")
	_travel(session, "M2_BEDROOM")
	session.act("routine")
	session.sleep()
	_expect(not session.mirror_local()["surface_open"], "sleep resets physical mirror coating")
	_expect((GameState.get_value(&"meta_progress.knowledge_entries.c5_raw_capture", {}) as Dictionary).size() == 5, "uninterpreted capture survives sleep")
	_expect("C0_WARNING_GIVEN" in GameState.get_value(&"meta_progress.servants.edgar.residual_memory"), "Edgar remembers his warning after reset")
	_travel(session, "M1_MIRROR_GALLERY")
	_expect(not session.act("c_record").get("ok", false), "C5_INFO requires five channels")
	for owner in SESSION.CHANNELS: session.act("c_scan", owner)
	_expect(session.act("c_record").get("ok", false), "record five non-color signatures")
	_expect(session.known("color_room_entry_inspectable"), "C5_INFO opens external panel only")
	_expect(GameState.get_value(&"meta_progress.failure_knowledge.C4.status") == "resolved", "recording resolves failure record")
	_travel(session, "M1_LIBRARY_INNER")
	session.act("routine")
	session.act("j3_overlay")
	session.act("j3_piece", 2)
	_expect(not session.act("j3_restore").get("ok", false), "wrong J3 order is reversible")
	session.act("j3_clear")
	for index in range(4): session.act("j3_piece", index)
	_expect(session.act("j3_restore").get("ok", false), "restore J3")
	_expect(session.stage() == "J3_COMPLETE", "C chapter reaches J3")
	_expect(GameState.get_value(&"meta_progress.knowledge_entries.MEM_FATHER_DRAWN_DOOR_FRAGMENT") == "episodic_fragment", "tea memory leads to drawn-door fragment without solution")
	_validate_unique_solutions()
	await _validate_view(tree, session, ready)
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	return {"ok": errors.is_empty(), "errors": errors}


func _make_cleaner(session: BlackMirrorSession) -> void:
	for index in range(5): session.act("c_pour", "water")
	session.act("c_pour", "stabilizer")
	session.act("c_disperse")
	for index in range(2): session.act("c_pour", "active")
	session.act("c_mix")
	session.act("c_test")
	_expect(session.mirror_local()["cleaner_ready"], "5:1:2 in safe order creates cleaner")


func _travel(session: BlackMirrorSession, target: String) -> void:
	var parents := {"M1_MIRROR_GALLERY": "M1_PARLOR", "M1_TOOL_ROOM": "M1_SERVANT_COMMON", "M1_KITCHEN": "M1_SERVANT_COMMON", "M1_COLOR_ROOM_ENTRY": "M1_NORTH_ARCHIVE_HALL", "M1_LIBRARY_INNER": "M1_LIBRARY_OUTER"}
	var room := String(GameState.get_value(&"loop_state.location_id"))
	if room == target: return
	if parents.has(room):
		_expect(session.act("move", parents[room]).get("ok", false), "leave child room " + room)
	if GameState.get_value(&"loop_state.location_id") != "M1_CENTRAL_HALL":
		_expect(session.act("move", "M1_CENTRAL_HALL").get("ok", false), "through hall")
	if parents.has(target):
		_expect(session.act("move", parents[target]).get("ok", false), "approach parent of " + target)
	if target == "M1_LIBRARY_INNER": session.act("routine")
	_expect(session.act("move", target).get("ok", false), "destination " + target)


func _validate_unique_solutions() -> void:
	var mixtures := 0
	for water in range(9):
		for stabilizer in range(9):
			for active in range(9):
				var mix := RULES.empty_mixture()
				mix.merge({"water": water, "stabilizer": stabilizer, "active": active, "order": RULES.MATERIALS, "dispersed": true, "mixed": 1}, true)
				if RULES.test_mixture(mix)["ok"]: mixtures += 1
	_expect(mixtures == 1, "unique measured mixture")
	var traces := 0
	for a in RULES.SEGMENTS:
		for b in RULES.SEGMENTS:
			for c in RULES.SEGMENTS:
				for d in RULES.SEGMENTS:
					for rotation in [0, 90, 180, 270]:
						for flipped in [true, false]:
							for anchored in [true, false]:
								if RULES.inspect_trace(rotation, flipped, anchored, [a, b, c, d])["ok"]: traces += 1
	_expect(traces == 1, "unique 24-3 mirror transform and trace")


func _support_key(keycode: Key, scene_tree: SceneTree, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)
	await scene_tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await scene_tree.process_frame


func _validate_view(tree: SceneTree, session: BlackMirrorSession, ready: Dictionary) -> void:
	var completed := GameState.get_snapshot()
	StateWriter.new(GameState).install_snapshot(ready, GameState.revision, &"MIRROR_UI")
	var view := VIEW.new()
	view.configure_session(SLOT, "C4")
	tree.root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	var before_history := GameState.get_snapshot()
	var history_count: int = before_history["meta_progress"]["dialogue_history"]["entries"].size()
	view._show_dialogue([{"speaker": "주인공", "text": "Mirror history shown"}, {"speaker": "주인공", "text": "Mirror history unseen"}])
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"].size() == history_count + 1, "mirror records only presented line")
	view._dismiss_dialogue_for_test()
	var recorded := GameState.get_snapshot()
	_expect(recorded["loop_state"] == before_history["loop_state"] and recorded["ending_run"] == before_history["ending_run"], "history recording preserves mirror puzzle and ending state")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "mirror history reload")
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"] == recorded["meta_progress"]["dialogue_history"], "mirror history survives reload")
	var before_history_menu := GameState.get_snapshot()
	view._open_menu()
	(view._modal_body.get_child(4) as Button).pressed.emit()
	var history_body := (view._modal_body.get_child(2).get_child(0) as Label).text
	_expect(history_body.contains("Mirror history shown") and not history_body.contains("Mirror history unseen"), "mirror menu opens viewed history only")
	(view._modal_body.get_child(3) as Button).pressed.emit()
	_expect(GameState.get_snapshot() == before_history_menu, "mirror history menu is read only")
	var hint_base := GameState.get_snapshot()
	for hint_stage in ["C3", "C4"]:
		var hint_state := hint_base.duplicate(true)
		var old_scale: float = view._reading_text_scale
		if hint_stage == "C3":
			view._apply_reading_text_scale(2.0)
			hint_state.loop_state.event_local_states.BLACK_MIRROR.cleaner_ready = false
			hint_state.loop_state.inventory.erase("NEUTRAL_CLEANER")
		_expect(StateWriter.new(GameState).install_snapshot(hint_state, GameState.revision, StringName("MIRROR_HINT_" + hint_stage)).get("ok", false), "hint fixture installed")
		_expect(view.session.stage() == hint_stage, "context selects current puzzle hint track")
		if hint_stage == "C3":
			var table := preload("res://scripts/ui/cleaner_quantity_table.gd")
			_expect(table.candidates(false, false).size() == 45, "all nonnegative total-eight candidates")
			_expect(table.candidates(true, false).size() == 3, "ratio filter alone leaves three candidates")
			_expect(table.candidates(false, true).size() == 4, "water filter alone leaves four candidates")
			_expect(table.candidates(true, true) == [{"water": 5, "stabilizer": 1, "active": 2}], "combined constraints yield original mixture")
			view._open_notebook()
			_expect(view._modal_body.get_node("ClockHintsButton").get_theme_font_size("font_size") == 42, "notebook hint button follows text scale")
			_expect(view._modal_body.get_node("CleanerQuantityTable").get_theme_font_size("font_size") == 42, "notebook calculation button follows text scale")
			await tree.process_frame
			await tree.process_frame
			_expect(view._modal_panel.get_global_rect().end.y <= view.get_global_rect().end.y, "large text notebook remains vertically within view")
			if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				tree.root.get_texture().get_image().save_png("user://cleaner_notebook_200.png")
			(view._modal_body.get_node("CleanerQuantityTable") as Button).pressed.emit()
			var quantity_body := view._modal_body.get_child(2).get_child(0) as Label
			_expect(quantity_body.text.contains("45"), "quantity table initially shows unfiltered candidates")
			var ratio := view._modal_body.get_node("QuantityRatio") as CheckButton
			var difference := view._modal_body.get_node("QuantityWaterDifference") as CheckButton
			_expect(ratio.get_theme_font_size("font_size") == 42, "quantity filters respect 200 percent text")
			await tree.process_frame
			await tree.process_frame
			ratio.grab_focus()
			await _support_key(KEY_SPACE, tree)
			_expect(ratio.button_pressed, "Space toggles focused quantity filter through input pipeline")
			await _support_key(KEY_TAB, tree)
			_expect(tree.root.gui_get_focus_owner() == difference, "Tab advances to next filter")
			await _support_key(KEY_TAB, tree)
			_expect(tree.root.gui_get_focus_owner() == view._modal_body.get_child(2), "last filter wraps to support scroll instead of world")
			await _support_key(KEY_TAB, tree, true)
			_expect(tree.root.gui_get_focus_owner() == difference, "Shift Tab wraps backward within support")
			ratio.button_pressed = true
			difference.button_pressed = true
			_expect(quantity_body.text.contains("W 5   |   S 1   |   A 2") and not quantity_body.text.contains("W 8"), "actual filter controls narrow table")
			if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await tree.process_frame
				await RenderingServer.frame_post_draw
				tree.root.get_texture().get_image().save_png("user://cleaner_quantity_table.png")
			ratio.button_pressed = false
			difference.button_pressed = false
			_expect(quantity_body.text.contains("45"), "clearing filters restores candidates")
			var quantity_scroll := view._modal_body.get_child(2) as ScrollContainer
			quantity_scroll.grab_focus()
			await tree.process_frame
			await _support_key(KEY_PAGEDOWN, tree)
			_expect(quantity_scroll.scroll_vertical > 0, "Page Down reaches candidate rows at large text")
			view._close_modal()
			view._apply_reading_text_scale(old_scale)
			_expect(GameState.get_snapshot() == hint_state, "quantity table never pours or changes state")
		view._open_notebook()
		var hints := view._modal_body.get_node_or_null("ClockHintsButton") as Button
		_expect(hints != null, "mirror notebook exposes shared thought action")
		if hints != null:
			hints.pressed.emit()
			for level in range(5):
				(view._modal_body.get_child(4) as Button).pressed.emit()
				var expected: String = preload("res://scripts/ui/mirror_hint_texts.gd").text(hint_stage, level, TranslationServer.get_locale())
				_expect(view._dialogue_active and view._dialogue_label.text == expected, "mirror hint text shown only on request")
				view._dialogue_next.pressed.emit()
			view._close_modal()
		var hint_result := GameState.get_snapshot()
		_expect(hint_result.meta_progress.dialogue_history.entries.size() == hint_state.meta_progress.dialogue_history.entries.size() + 5, "five requested mirror hints persisted")
		hint_result.meta_progress.dialogue_history = hint_state.meta_progress.dialogue_history.duplicate(true)
		_expect(hint_result == hint_state, "hints preserve mixture trace inventory lock and relations")
	_expect(preload("res://scripts/ui/mirror_hint_texts.gd").text("CF", 4, "en-US").contains("sleep"), "locked mirror support preserves sleep requirement")
	StateWriter.new(GameState).install_snapshot(hint_base, GameState.revision, &"MIRROR_HINT_RESTORE")
	view._hotspot_layer.get_node("TRACE_COMPARE").pressed.emit()
	await tree.process_frame
	_expect(view._modal_active, "waveform comparison diagram opens")
	var diagram := view._modal_body.get_child(3)
	_expect(diagram._overlay_point(Vector2(1, -0.55)).is_equal_approx(Vector2(1, -0.55)), "displayed transform matches accepted puzzle transform")
	if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://black_mirror_overlay.png")
	view._close_modal()
	if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://black_mirror_trace.png")
		var kitchen := ready.duplicate(true)
		kitchen["loop_state"]["location_id"] = "M1_KITCHEN"
		StateWriter.new(GameState).install_snapshot(kitchen, GameState.revision, &"MIRROR_CAPTURE_KITCHEN")
		view._render_room()
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://black_mirror_mixture.png")
		StateWriter.new(GameState).install_snapshot(ready, GameState.revision, &"MIRROR_CAPTURE_RESTORE")
		view._render_room()
		print("BLACK_MIRROR_CAPTURE: " + ProjectSettings.globalize_path("user://black_mirror_trace.png"))
	view._hotspot_layer.get_node("C_WET").pressed.emit()
	await tree.process_frame
	_expect(view._modal_active, "wet trace confirmation visible")
	_expect((tree.root.gui_get_focus_owner() as Button).text == "계획을 다시 확인한다", "default focus is reversible choice")
	view._close_modal()
	view.queue_free()
	await tree.process_frame
	StateWriter.new(GameState).install_snapshot(completed, GameState.revision, &"MIRROR_UI_RESTORE")
	session.initialize()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload J3")
	var bootstrap := tree.current_scene
	bootstrap._on_load_game_requested(SLOT)
	await tree.process_frame
	_expect(bootstrap.get_node_or_null("Basement") != null, "bootstrap routes J3 completion to basement")
	bootstrap._on_prologue_return_to_title()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
