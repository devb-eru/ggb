extends RefCounted

const SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const TEXTS := preload("res://scripts/ui/black_mirror_display_texts.gd")
const NOTEBOOK_WAIT := preload("res://scripts/tests/notebook_test_wait.gd")
const NOTEBOOK_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")
const SLOT := "__test_black_mirror"
var errors := PackedStringArray()

func run(tree: SceneTree) -> Dictionary:
	GameState.reset_for_test()
	_validate_c4_confirmation_versions()
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
	_expect(not session.can_prepare_mirror_shortcut(), "CSHORT cannot bypass failed coating before sleep")
	session.sleep()
	_expect(session.can_prepare_mirror_shortcut(), "CSHORT opens after sleep for unresolved failure")
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
	var after_capture_sleep := GameState.get_snapshot()
	_expect(not session.can_prepare_mirror_shortcut(), "CSHORT stays closed after durable tracing despite physical reset")
	_expect(not session.act("c_shortcut").get("ok", false), "session rejects obsolete CSHORT before channel interpretation")
	_expect(GameState.get_snapshot() == after_capture_sleep, "obsolete shortcut rejection preserves capture and position")
	var capture_view := VIEW.new()
	capture_view.configure_session(SLOT, "C5_INFO")
	tree.root.add_child(capture_view)
	await tree.process_frame
	capture_view._dismiss_dialogue_for_test()
	_expect(not capture_view._hotspot_layer.has_node("CSHORT"), "bedroom hides CSHORT after persistent mirror capture")
	capture_view.queue_free()
	await tree.process_frame
	_expect((GameState.get_value(&"meta_progress.knowledge_entries.c5_raw_capture", {}) as Dictionary).size() == 5, "uninterpreted capture survives sleep")
	_expect("C0_WARNING_GIVEN" in GameState.get_value(&"meta_progress.servants.edgar.residual_memory"), "Edgar remembers his warning after reset")
	_travel(session, "M1_MIRROR_GALLERY")
	_expect(not session.act("c_record").get("ok", false), "C5_INFO requires body and personality diagnostics")
	for owner in SESSION.CHANNELS: session.act("c_scan", owner)
	_expect(not session.act("c_record").get("ok", false), "optional owner signatures cannot replace required diagnostics")
	for diagnostic in ["BODY", "PERSONALITY"]: session.act("c_scan", diagnostic)
	_expect(session.act("c_record").get("ok", false), "record required diagnostics and optional non-color signatures")
	_expect(session.known("color_room_entry_inspectable"), "C5_INFO opens external panel only")
	_expect(GameState.get_value(&"meta_progress.failure_knowledge.C4.status") == "resolved", "recording resolves failure record")
	_travel(session, "M1_LIBRARY_INNER")
	session.act("routine")
	session.act("j3_overlay")
	for point in ["BED", "GREEN", "CLOCK"]: session.act("j3_point", point)
	session.act("j3_compare")
	session.act("j3_flip_page")
	session.act("j3_compare")
	session.act("j3_piece", 2)
	_expect(not session.act("j3_restore").get("ok", false), "wrong J3 order is reversible")
	session.act("j3_clear")
	for index in range(4): session.act("j3_piece", index)
	_expect(session.act("j3_restore").get("ok", false), "restore J3")
	_expect(session.stage() == "J3_COMPLETE", "C chapter reaches J3")
	_expect(not session.known("MEM_FATHER_DRAWN_DOOR_FRAGMENT"), "tea memory alone does not acquire an unread optional door memory")
	_validate_unique_solutions()
	await _validate_route_feedback(tree, ready)
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


func _validate_route_feedback(tree: SceneTree, ready: Dictionary) -> void:
	var before := GameState.get_snapshot()
	var old_locale := TranslationServer.get_locale()
	var paths := [[], ["entry"], ["entry", "long_branch", "short_branch", "clockwise_ring"], ["entry", "short_branch", "long_branch", "counterclockwise_ring"], RULES.PATH, ["long_branch"]]
	for path in paths:
		TranslationServer.set_locale("en" if path.is_empty() else "ko")
		var state := ready.duplicate(true)
		state.loop_state.event_local_states.BLACK_MIRROR.path = path.duplicate()
		state.loop_state.event_local_states.BLACK_MIRROR.dry_passed = false
		StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"MIRROR_ROUTE_TEST")
		var view := VIEW.new()
		view.configure_session(SLOT, "C4")
		tree.root.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		if path == RULES.PATH:
			view._apply_reading_text_scale(2.0)
		view._do("c_dry")
		for frame in range(4):
			await tree.process_frame
		_expect(view._modal_active, "dry test automatically opens signal feedback")
		var diagram = view._modal_body.get_node_or_null("MirrorRouteFeedback")
		_expect(diagram != null, "dry test contains the route diagram")
		if diagram != null:
			var expected: Dictionary = RULES.inspect_trace(90, false, true, path)
			_expect(diagram.verdict == expected, "visual feedback uses authoritative puzzle verdict")
			_expect(diagram.segments == path, "visual feedback preserves submitted path")
			_expect(diagram.steps.size() == maxi(1, mini(path.size(), expected.verified_prefix.size() + 1)), "trace stops at first mismatch without showing unchosen solution")
			_expect(bool(view._mirror().mirror_local().dry_passed) == bool(expected.ok), "dry result is committed before animation")
			_expect(not view._mirror().mirror_local().locked and view._mirror().mirror_local().cleaner_ready, "visual dry failure leaves materials and coating intact")
			diagram.configure(view._mirror().mirror_local(), "standard")
			diagram._process(0.4)
			_expect(not diagram.finished and is_equal_approx(diagram.elapsed, 0.4), "light progresses through route over time")
			if path == RULES.PATH and "--mirror-route-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var moving_image := view.get_viewport().get_texture().get_image()
				_expect(moving_image.save_png("user://mirror-route-moving.png") == OK, "moving particle screenshot saved")
			diagram._process(20.0)
			_expect(diagram.finished and not diagram.is_processing(), "animation ends without an infinite particle loop")
			if "--mirror-route-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var capture := "user://mirror-route-%d.png" % paths.find(path)
				var image := view.get_viewport().get_texture().get_image()
				_expect(image.save_png(capture) == OK, "route feedback screenshot saved")
				print("MIRROR_ROUTE_CAPTURE: " + ProjectSettings.globalize_path(capture))
			var loop_before: Dictionary = GameState.get_snapshot().loop_state.duplicate(true)
			(view._modal_body.get_child(5) as Button).pressed.emit()
			_expect(GameState.get_snapshot().loop_state == loop_before, "replay is visual only")
			for mode in ["reduced", "static"]:
				diagram.configure(view._mirror().mirror_local(), mode)
				_expect(diagram.finished and not diagram.is_processing() and diagram.verdict == expected, "motion alternative preserves result and trail: " + mode)
			await tree.process_frame
			_expect(diagram.get_global_rect().end.y <= view._modal_panel.get_global_rect().end.y, "diagram fits feedback panel")
			_expect((view._modal_body.get_child(5) as Button).get_global_rect().end.y <= view._modal_panel.get_global_rect().end.y, "replay remains within panel at requested text scale")
			_expect(view._modal_panel.get_global_rect().end.y <= view.get_viewport_rect().end.y, "feedback panel remains inside visible viewport")
			(view._modal_body.get_child(4) as Button).grab_focus()
			await _support_key(KEY_ENTER, tree)
			_expect(not view._modal_active, "keyboard closes feedback without waiting")
			var no_signal := GameState.get_snapshot()
			no_signal.loop_state.event_local_states.BLACK_MIRROR.signal_ready = false
			StateWriter.new(GameState).install_snapshot(no_signal, GameState.revision, &"MIRROR_NO_SIGNAL")
			var before_reject := GameState.get_snapshot()
			view._do("c_dry")
			_expect(not view._modal_active and GameState.get_snapshot() == before_reject, "missing bell signal cannot produce visual success or alter progress")
		view.queue_free()
		await tree.process_frame
	var visual = VIEW.ROUTE_FEEDBACK.new()
	var local: Dictionary = ready.loop_state.event_local_states.BLACK_MIRROR.duplicate(true)
	for rotation in [0, 90, 180, 270]:
		for flipped in [true, false]:
			for anchored in [true, false]:
				local.merge({"rotation": rotation, "flipped": flipped, "anchored": anchored}, true)
				visual.configure(local, "static")
				_expect(visual.verdict == RULES.inspect_trace(rotation, flipped, anchored, local.path), "transform failure uses the same predicate as gameplay")
				if visual.verdict.category == "anchor_missing":
					_expect(visual.steps.size() == 1 and visual.steps[0][0].is_equal_approx(visual._overlay_point(visual.ENTRY)), "misaligned signal stops before entering mirror grooves")
	visual.free()
	TranslationServer.set_locale(old_locale)
	StateWriter.new(GameState).install_snapshot(before, GameState.revision, &"MIRROR_ROUTE_RESTORE")


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


func _await_notebook_ready(view: Node) -> bool:
	if not view._notebook_is_open():
		var legacy: bool = view._modal_active and view._modal_layer.is_visible_in_tree()
		_expect(legacy, "legacy notebook is visible before inspection")
		return legacy
	var host = view._notebook_host
	var ready: bool = await NOTEBOOK_WAIT.ready(view.get_tree(), host)
	ready = ready and is_instance_valid(host.panel) and host.panel.is_visible_in_tree() and host._refresh_job.is_empty()
	_expect(ready, "notebook model and visible panel are ready before inspection")
	return ready


func _history_text(view: Node) -> String:
	if view._notebook_is_open():
		if not await _await_notebook_ready(view): return ""
		var panel = view._notebook_host.panel
		_expect(panel._filters.tab == "dialogue", "mirror menu opens unified dialogue tab")
		var key: String = view._notebook_host.model.latest_dialogue_key()
		var opened: bool = not key.is_empty() and panel.show_detail(key)
		_expect(opened, "latest public mirror dialogue opens in actual notebook")
		if not opened: return ""
		var parts := PackedStringArray()
		for label in panel._detail.find_children("*", "RichTextLabel", true, false): parts.append(label.get_parsed_text())
		for label in panel._detail.find_children("*", "Label", true, false): parts.append(label.text)
		return "\n".join(parts)
	var transcript := view._modal_body.find_child("HistoryTranscript", true, false) as Label
	_expect(transcript != null, "legacy mirror history has a transcript")
	return transcript.text if transcript != null else ""


func _close_history(view: Node) -> bool:
	if view._notebook_is_open():
		var host = view._notebook_host
		host.request_close()
		var closed: bool = await NOTEBOOK_WAIT.closed(view.get_tree(), host)
		_expect(closed and not view._notebook_is_open(), "mirror history close completes")
		if not closed or view._notebook_is_open(): return false
		_expect(view._modal_active, "mirror history returns to its calling menu")
		if not view._modal_active: return false
	else:
		var close := view._modal_body.get_node_or_null("HistoryClose") as Button
		_expect(close != null, "legacy mirror history exposes close action")
		if close == null: return false
		close.pressed.emit()
	return await _close_support(view)


func _notebook_tool(view: Node, id: String) -> Button:
	var surface: Node = view._notebook_host.panel if view._notebook_is_open() else view._modal_body
	var button := surface.find_child(id, true, false) as Button
	var usable := button != null and button.is_visible_in_tree() and not button.disabled
	_expect(usable, "mirror notebook exposes actual tool: " + id)
	return button if usable else null


func _activate_notebook_tool(view: Node, button: Button, marker: String) -> bool:
	if button == null: return false
	var host = view._notebook_host if view._notebook_is_open() else null
	button.pressed.emit()
	if is_instance_valid(host):
		var closed: bool = await NOTEBOOK_WAIT.closed(view.get_tree(), host)
		_expect(closed, "notebook closes before dispatching its tool")
		if not closed: return false
	var deadline := Time.get_ticks_msec() + 15000
	while view._notebook_is_open() or not view._modal_active or not view._modal_layer.is_visible_in_tree() or (view._modal_body.get_child_count() < 5 if marker.is_empty() else view._modal_body.find_child(marker, true, false) == null):
		if Time.get_ticks_msec() >= deadline:
			_expect(false, "notebook tool did not present its actual controls: " + marker)
			return false
		await view.get_tree().process_frame
	return true


func _close_support(view: Node) -> bool:
	view._close_modal()
	var deadline := Time.get_ticks_msec() + 15000
	while view._notebook_is_open() or view._modal_active:
		if Time.get_ticks_msec() >= deadline:
			_expect(false, "mirror support close did not complete")
			return false
		await view.get_tree().process_frame
	return true


func _same_support_gameplay(view: Node, before: Dictionary, after: Dictionary) -> bool:
	if view._presentation_enabled():
		return NOTEBOOK_ASSERTIONS.same_gameplay(before, after, "utility")
	return before == after


func _await_dialogue_recorded(view: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while view._dialogue_active and (not view._history_async_request.is_empty() or view._history_recorded_index != view._dialogue_index):
		if Time.get_ticks_msec() >= deadline or (view._history_async_request.is_empty() and view._history_recorded_index != view._dialogue_index):
			_expect(false, "displayed mirror dialogue was not committed: " + String(view._status_label.text))
			return false
		await view.get_tree().process_frame
	_expect(view._dialogue_active, "mirror dialogue remains visible after its record commits")
	return view._dialogue_active


func _await_hint_menu(view: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while view._dialogue_active or not view._modal_active or not view._modal_layer.is_visible_in_tree():
		if Time.get_ticks_msec() >= deadline:
			_expect(false, "requested hint did not finish and return to support menu")
			return false
		await view.get_tree().process_frame
	return true


func _validate_c4_confirmation_versions() -> void:
	var content := preload("res://scripts/systems/notebook_content.gd")
	var ids := ["NB_EP02_C4_COMMIT_001", "NB_EP02_C4_COMMIT_CH01", "NB_EP02_C4_COMMIT_CH02", "NB_EP02_C4_COMMIT_CH03", "NB_EP02_CHOICE_C4_COMMIT", "NB_EP02_CHOICE_C4_COMMIT_SELECT_0", "NB_EP02_CHOICE_C4_COMMIT_SELECT_1", "NB_EP02_CHOICE_C4_COMMIT_SELECT_2"]
	for id in ids:
		var original := content.definition(id, 1)
		var current := content.definition(id, 2)
		_expect(not original.is_empty() and not current.is_empty(), "C4 confirmation preserves original and translated semantic versions: " + id)
		if original.is_empty() or current.is_empty(): continue
		var unchanged := current.duplicate(true)
		unchanged.locales["en-US"] = original.locales["en-US"].duplicate(true)
		_expect(StateSnapshotValidator.same_persisted_value(original, unchanged), "C4 translation leaves Korean, provenance and behavior unchanged: " + id)
	for version in [1, 2]:
		var options := content.descriptor("NB_EP02_CHOICE_C4_COMMIT", version, {"option_0": {}, "option_1": {}, "option_2": {}})
		for index in range(3):
			var selected := content.choice_for_options("NB_EP02_CHOICE_C4_COMMIT_SELECT_%d" % index, options, "option_%d" % index)
			_expect(selected.get("content_version") == version, "C4 selection preserves the version of the options actually displayed")


func _await_wet_choice(view: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if view._dialogue_active:
			if not await _await_dialogue_recorded(view): return false
			view._dialogue_next.pressed.emit()
		elif view._modal_active and view._recorded_modal_request.get("recorded", false):
			await view.get_tree().process_frame
			return true
		await view.get_tree().process_frame
	_expect(false, "authored C4 warning finishes before its durable confirmation choices")
	return false


func _validate_view(tree: SceneTree, session: BlackMirrorSession, ready: Dictionary) -> void:
	var completed := GameState.get_snapshot()
	StateWriter.new(GameState).install_snapshot(ready, GameState.revision, &"MIRROR_UI")
	var view := VIEW.new()
	view.configure_session(SLOT, "C4")
	tree.root.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	_expect(view._notebook_surface_allowed(), "displayed mirror board commits before the history baseline")
	var before_history := GameState.get_snapshot()
	var history_count: int = before_history["meta_progress"]["dialogue_history"]["entries"].size()
	var history_lines: Array = [{"speaker": "주인공", "text": "Mirror history shown"}, {"speaker": "주인공", "text": "Mirror history unseen"}]
	if view._unified_notebook_enabled():
		var sheet := preload("res://scripts/systems/ep01_script.gd")
		history_lines = [sheet.line("EP02_C4_001", before_history, TranslationServer.get_locale()), sheet.line("EP02_C4_002", before_history, TranslationServer.get_locale())]
		_expect(history_lines.all(func(line: Dictionary) -> bool: return not line.is_empty() and not line.get("notebook_content", {}).is_empty()), "v2 history fixture uses registered EP02 authored lines and contexts")
		if history_lines.any(func(line: Dictionary) -> bool: return line.is_empty()):
			view.queue_free()
			await tree.process_frame
			return
	var shown_text: String = history_lines[0].text
	var unseen_text: String = history_lines[1].text
	view._show_dialogue(history_lines)
	if not await _await_dialogue_recorded(view):
		view.queue_free()
		await tree.process_frame
		return
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"]["entries"].size() == history_count + 1, "mirror records only presented line")
	if view._unified_notebook_enabled():
		var added: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.slice(history_count)
		_expect(added.size() == 1 and added[0].get("record_class") == "authored" and added[0].get("observation", {}).get("content_id") == history_lines[0].notebook_content.content_id, "strict v2 history commits the displayed authored row, not a text fallback")
		_expect(not added.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == history_lines[1].notebook_content.content_id), "unshown authored mirror row is not archived")
	view._dismiss_dialogue_for_test()
	var recorded := GameState.get_snapshot()
	var recorded_loop: Dictionary = recorded.loop_state.duplicate(true)
	var before_loop: Dictionary = before_history.loop_state.duplicate(true)
	if view._presentation_enabled():
		var presentation := preload("res://scripts/systems/notebook_presentation.gd")
		var cursor := presentation.read(recorded)
		_expect(presentation.matches(cursor, recorded) and cursor.get("kind") == "dialogue" and cursor.get("phase") == "reading" and cursor.get("index") == 0, "history preserves the actual first-line reading cursor")
		recorded_loop.event_local_states.erase(presentation.KEY)
		before_loop.event_local_states.erase(presentation.KEY)
	_expect(recorded_loop == before_loop and recorded["ending_run"] == before_history["ending_run"], "history recording preserves mirror puzzle and ending state")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "mirror history reload")
	_expect(GameState.get_snapshot()["meta_progress"]["dialogue_history"] == recorded["meta_progress"]["dialogue_history"], "mirror history survives reload")
	var before_history_menu := GameState.get_snapshot()
	view._open_menu()
	(view._modal_body.get_child(4) as Button).pressed.emit()
	var history_body := await _history_text(view)
	_expect(history_body.contains(shown_text) and not history_body.contains(unseen_text), "mirror menu opens viewed history only")
	if not await _close_history(view):
		view.queue_free()
		await tree.process_frame
		return
	_expect(GameState.get_snapshot() == before_history_menu, "mirror history menu is read only")
	var hint_base := GameState.get_snapshot()
	for hint_stage in ["C3", "C4"]:
		var hint_count := 5 if hint_stage == "C3" else 4
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
			if not await _await_notebook_ready(view):
				view.queue_free()
				await tree.process_frame
				return
			var unified: bool = view._notebook_is_open()
			var notebook_panel: Control = view._notebook_host.panel if unified else view._modal_panel
			var hint_tool := _notebook_tool(view, "ClockHintsButton")
			var quantity_tool := _notebook_tool(view, "CleanerQuantityTable")
			var tool_font_size := 36 if unified else 42
			_expect(hint_tool != null and hint_tool.get_theme_font_size("font_size") == tool_font_size, "notebook hint button follows text scale")
			_expect(quantity_tool != null and quantity_tool.get_theme_font_size("font_size") == tool_font_size, "notebook calculation button follows text scale")
			await tree.process_frame
			await tree.process_frame
			_expect(notebook_panel.get_global_rect().position.y >= view.get_viewport_rect().position.y and notebook_panel.get_global_rect().end.y <= view.get_viewport_rect().end.y, "large text notebook remains vertically within view")
			if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				tree.root.get_texture().get_image().save_png("user://cleaner_notebook_200.png")
			if not await _activate_notebook_tool(view, quantity_tool, "QuantityRatio"):
				view.queue_free()
				await tree.process_frame
				return
			var quantity_body := view._modal_body.get_child(2).get_child(0) as Label
			_expect(quantity_body.text.contains("45"), "quantity table initially shows unfiltered candidates")
			_expect(view._modal_body.get_child(0).get_theme_font_size("font_size") == 68, "common modal title scales to 200 percent")
			_expect(view._modal_body.get_child(3).get_theme_font_size("font_size") == 42, "common modal action scales to 200 percent")
			var ratio := view._modal_body.get_node("QuantityRatio") as CheckButton
			var difference := view._modal_body.get_node("QuantityWaterDifference") as CheckButton
			var review := view._modal_body.get_node_or_null("QuantitySourceCards") as Button
			_expect(review != null, "quantity table exposes actual observation-card review action")
			_expect(ratio.get_theme_font_size("font_size") == 42, "quantity filters respect 200 percent text")
			await tree.process_frame
			await tree.process_frame
			ratio.grab_focus()
			await _support_key(KEY_SPACE, tree)
			_expect(ratio.button_pressed, "Space toggles focused quantity filter through input pipeline")
			await _support_key(KEY_TAB, tree)
			_expect(tree.root.gui_get_focus_owner() == difference, "Tab advances to next filter")
			await _support_key(KEY_TAB, tree)
			_expect(tree.root.gui_get_focus_owner() == review, "last filter advances to observation-card review instead of world")
			await _support_key(KEY_TAB, tree)
			_expect(tree.root.gui_get_focus_owner() == view._modal_body.get_child(2), "last support action wraps to support scroll instead of world")
			await _support_key(KEY_TAB, tree, true)
			_expect(tree.root.gui_get_focus_owner() == review, "Shift Tab wraps backward to last support action")
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
			var original_page_keys := InputMap.action_get_events("ui_page_down")
			InputMap.action_erase_events("ui_page_down")
			var remapped_page := InputEventKey.new()
			remapped_page.keycode = KEY_F8
			InputMap.action_add_event("ui_page_down", remapped_page)
			quantity_scroll.scroll_vertical = 0
			difference.grab_focus()
			await _support_key(KEY_F8, tree)
			_expect(quantity_scroll.scroll_vertical > 0, "remapped page action scrolls from a non-scroll control")
			InputMap.action_erase_events("ui_page_down")
			for original_key in original_page_keys:
				InputMap.action_add_event("ui_page_down", original_key)
			if not await _close_support(view):
				view.queue_free()
				await tree.process_frame
				return
			_expect(_same_support_gameplay(view, hint_state, GameState.get_snapshot()), "quantity table never pours or changes state")
			view._apply_reading_text_scale(old_scale)
			view._show_modal("확인", "기본 배율 복귀", [{"label": "닫기", "action": view._close_modal}])
			_expect(view._modal_panel.position == Vector2(510, 190), "normal text restores normal modal placement")
			if not await _close_support(view):
				view.queue_free()
				await tree.process_frame
				return
		view._open_notebook()
		if not await _await_notebook_ready(view):
			view.queue_free()
			await tree.process_frame
			return
		var hints := _notebook_tool(view, "ClockHintsButton")
		_expect(hints != null, "mirror notebook exposes shared thought action")
		if hints != null:
			if not await _activate_notebook_tool(view, hints, ""):
				view.queue_free()
				await tree.process_frame
				return
			for level in range(hint_count):
				var request: Button = (view._modal_body.get_child(4) as Button) if view._modal_body.get_child_count() > 4 else null
				var requestable := request != null and request.is_visible_in_tree() and not request.disabled
				_expect(requestable, "mirror hint level remains explicitly requestable: %s H%d" % [hint_stage, level + 1])
				if not requestable: break
				request.pressed.emit()
				var content := preload("res://scripts/systems/notebook_content.gd")
				var published := content.presentation(content.hint_descriptor(hint_stage, level), TranslationServer.get_locale())
				_expect(published.get("ok", false) and not String(published.get("text", "")).is_empty(), "mirror hint has a registered current presentation")
				var expected: String = published.get("text", "")
				_expect(view._dialogue_active and view._dialogue_label.text == expected, "mirror hint text shown only on request")
				if not await _await_dialogue_recorded(view): break
				view._dialogue_next.pressed.emit()
				if not await _await_hint_menu(view): break
			_expect(view._modal_body.get_child_count() == 4, "completed hint track offers close without an extra hint")
			if not await _close_support(view):
				view.queue_free()
				await tree.process_frame
				return
		var hint_result := GameState.get_snapshot()
		_expect(hint_result.meta_progress.dialogue_history.entries.size() == hint_state.meta_progress.dialogue_history.entries.size() + hint_count, "every explicitly requested mirror hint persisted")
		var old_entries: Array = hint_state.meta_progress.dialogue_history.entries
		var new_entries: Array = hint_result.meta_progress.dialogue_history.entries
		_expect(StateSnapshotValidator.same_persisted_value(old_entries, new_entries.slice(0, old_entries.size())), "requesting hints preserves every earlier archive entry")
		if view._unified_notebook_enabled():
			var content := preload("res://scripts/systems/notebook_content.gd")
			for level in range(hint_count):
				var index := old_entries.size() + level
				var descriptor := content.hint_descriptor(hint_stage, level)
				_expect(index < new_entries.size() and new_entries[index].get("record_class") == "authored" and new_entries[index].get("observation", {}).get("content_id") == descriptor.get("content_id") and new_entries[index].get("observation", {}).get("content_version") == descriptor.get("content_version"), "requested mirror hint archives its exact current authored identity: %s H%d" % [hint_stage, level + 1])
			if hint_stage == "C4":
				_expect(not content.definition("NB_HINT_C4_H5", 1).is_empty(), "historical C4 H5 definition remains available")
				_expect(not new_entries.slice(old_entries.size()).any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_HINT_C4_H5"), "current four-step C4 support never invents a new H5 observation")
		hint_result.meta_progress.dialogue_history = hint_state.meta_progress.dialogue_history.duplicate(true)
		_expect(_same_support_gameplay(view, hint_state, hint_result), "hints preserve mixture trace inventory lock and relations")
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
	if not await _await_wet_choice(view):
		view.queue_free()
		await tree.process_frame
		return
	_expect(view._modal_active, "wet trace confirmation visible")
	var focus := tree.root.gui_get_focus_owner() as Button
	_expect(focus != null and focus.text == preload("res://scripts/systems/ep01_script.gd").text("EP02_C4_COMMIT_CH02", TranslationServer.get_locale()), "default focus is reversible plan review, never wet execution")
	view._close_modal()
	await _validate_english_display(tree, view, ready)
	view.queue_free()
	await tree.process_frame
	StateWriter.new(GameState).install_snapshot(completed, GameState.revision, &"MIRROR_UI_RESTORE")
	session.initialize()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).get("ok", false), "reload J3")
	var bootstrap := tree.current_scene
	var owns_bootstrap := not bootstrap.has_method("_on_load_game_requested")
	if owns_bootstrap:
		bootstrap = load("res://scenes/main/main.tscn").instantiate()
		tree.root.add_child(bootstrap)
		await tree.process_frame
	bootstrap._on_load_game_requested(SLOT)
	await tree.process_frame
	_expect(bootstrap.get_node_or_null("Basement") != null, "bootstrap routes J3 completion to basement")
	bootstrap._on_prologue_return_to_title()
	await tree.process_frame
	if owns_bootstrap:
		bootstrap.queue_free()
		await tree.process_frame


func _validate_english_display(tree: SceneTree, view: BlackMirrorController, ready: Dictionary) -> void:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en_US")
	StateWriter.new(GameState).install_snapshot(ready, GameState.revision, &"MIRROR_ENGLISH_UI")
	view._render_room()
	_expect(view._location_label.text.contains("Mirror Gallery"), "English mirror-gallery location header")
	_expect(view._objective_label.text.contains("overlay") and view._objective_label.text.contains("route"), "English C4 objective")
	_expect((view._hotspot_layer.get_node("TRACE_COMPARE") as Button).text.contains("mirror grooves"), "English trace comparison control")
	_expect((view._hotspot_layer.get_node("C_WET") as Button).text == "Apply with the wet cloth", "English irreversible action control")
	view._confirm_wet_trace()
	if not await _await_wet_choice(view):
		TranslationServer.set_locale(previous_locale)
		return
	var sheet := preload("res://scripts/systems/ep01_script.gd")
	_expect(sheet.text("EP02_C4_COMMIT_001", "en-US") == "Applying the solution makes this route irreversible for today.", "English irreversible warning is translated")
	var review_text := sheet.text("EP02_C4_COMMIT_CH02", "en-US")
	var confirmation_buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
	_expect(confirmation_buttons.size() == 3 and confirmation_buttons[1].text == review_text, "English confirmation presents the registered reversible plan-review choice")
	var focus := tree.root.gui_get_focus_owner() as Button
	_expect(focus != null and focus.text == review_text, "English confirmation defaults to reversible plan review")
	_expect(review_text == "Review the plan again.", "English plan-review confirmation is translated rather than copied Korean")
	_expect(view._recorded_modal_request.history_context.notebook_content.content_version == 2, "current C4 confirmation uses translated version without rewriting past v1")
	view._close_modal()
	view._feedback({"ok": false, "text": "거울 앞에서 일지의 가설을 확인한다."})
	_expect(view._status_label.text == "Review the journal's hypothesis in front of the mirror.", "English uncatalogued mirror rejection")
	for id in TEXTS.OBJECTIVES:
		_expect(TEXTS.objective(id, "en-US") != TEXTS.objective(id, "ko-KR"), "English mirror objective exists: " + id)
	for id in TEXTS.UI:
		_expect(TEXTS.ui(id, "en-US") != TEXTS.ui(id, "ko-KR"), "English mirror UI text exists: " + id)
	for id in TEXTS.MATERIALS:
		_expect(TEXTS.material_name(id, "en-US") != TEXTS.material_name(id, "ko-KR"), "English material name exists: " + id)
	for id in TEXTS.SEGMENTS:
		_expect(TEXTS.segment_name(id, "en-US") != TEXTS.segment_name(id, "ko-KR"), "English trace segment exists: " + id)
	for id in TEXTS.CHANNELS:
		_expect(TEXTS.channel(id, "en-US") != TEXTS.channel(id, "ko-KR"), "English channel signature exists: " + id)
	for source in TEXTS.FEEDBACK_EN:
		_expect(TEXTS.feedback(source, "en-US") != source, "English mirror feedback exists: " + source.left(14))
	for index in range(TEXTS.J3_PARTS.size()):
		_expect(TEXTS.j3_part(index, "en-US") != TEXTS.j3_part(index, "ko-KR"), "English J3 fragment exists: " + str(index))
	var dry_result := "마른 천 시험: " + String(RULES.inspect_trace(90, false, true, RULES.PATH)["text"])
	_expect(TEXTS.feedback(dry_result, "en-US").begins_with("Dry-cloth test:"), "English dry-run prefix composes with puzzle feedback")
	var channel_result := "수첩의 진단면 사본: " + String(SESSION.CHANNELS["MARA2"]) + "\n서로 다른 문양이 같은 면 아래에서 겹친다. 이것이 무엇인지는 아직 단정할 수 없다."
	var translated_channel := TEXTS.feedback(channel_result, "en-US")
	_expect(translated_channel.contains("Notebook diagnostic copy: Mara 2") and translated_channel.contains("Different glyphs overlap"), "English channel scan preserves source and interpretation")
	var before_notebook := GameState.get_snapshot()
	var j3_source := "\n\n".join(SESSION.J3_PARTS)
	_expect(view._localized_notebook_entry(j3_source).contains("heart of the house"), "English notebook renders restored J3 without rewriting source")
	_expect(GameState.get_snapshot() == before_notebook, "English mirror display leaves puzzle and save state unchanged")
	if "--capture-black-mirror" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://black_mirror_english.png")
	TranslationServer.set_locale(previous_locale)


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
