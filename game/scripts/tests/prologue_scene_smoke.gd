extends RefCounted

const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const CAPTURE_ARG := "--capture-prologue"
const CAPTURE_FILE := "user://prologue_dialogue_1280x720.png"
const CAPTURE_P2_ARG := "--capture-p2-window"
const CAPTURE_P2_FILE := "user://p2_window_drag_1280x720.png"
const CAPTURE_P3_ARG := "--capture-p3-journal-choice"
const CAPTURE_P3_FILE := "user://p3_journal_choice_1280x720.png"
const CAPTURE_P4_ARG := "--capture-p4-father-choice"
const CAPTURE_P4_FILE := "user://p4_father_choice_1280x720.png"
const RESET_TEST_SLOT := "__test_prologue_reset"


func _modal_tab(tree: SceneTree, backwards: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.shift_pressed = backwards
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame


func run(tree: SceneTree) -> Dictionary:
	var prologue = PROLOGUE_SCENE.instantiate()
	prologue.configure_session("__test_prologue", "P1_ENTRY", true)
	tree.root.add_child(prologue)
	await tree.process_frame
	await tree.process_frame
	if CAPTURE_P4_ARG in OS.get_cmdline_user_args():
		if "--capture-large-text" in OS.get_cmdline_user_args():
			prologue._apply_reading_text_scale(2.0)
		prologue._dismiss_dialogue_for_test()
		prologue._progress["P1_complete"] = true
		prologue._progress["P2_complete"] = true
		prologue._progress["P3_complete"] = true
		prologue._progress["P3B_complete"] = true
		prologue._enter_room("M1_KITCHEN")
		prologue._dismiss_dialogue_for_test()
		for index in range(prologue.TEA_STEPS.size()):
			prologue._on_tea_step(index)
			prologue._dismiss_dialogue_for_test()
		prologue._show_p4_father_choices()
		await _capture_view(tree, CAPTURE_P4_FILE, "P4_FATHER_CHOICE_CAPTURE")
	elif CAPTURE_P3_ARG in OS.get_cmdline_user_args():
		prologue._dismiss_dialogue_for_test()
		prologue._progress["P1_complete"] = true
		prologue._enter_room("M1_LIBRARY_OUTER")
		prologue._dismiss_dialogue_for_test()
		prologue._selected_item = "BOOK_MECHANICAL"
		prologue._on_shelf_pressed("SHELF_CLOCK")
		while prologue._dialogue_active:
			prologue._advance_dialogue()
		await _capture_view(tree, CAPTURE_P3_FILE, "P3_JOURNAL_CHOICE_CAPTURE")
	elif CAPTURE_P2_ARG in OS.get_cmdline_user_args():
		if "--capture-english" in OS.get_cmdline_user_args():
			TranslationServer.set_locale("en_US")
		if "--capture-large-text" in OS.get_cmdline_user_args():
			prologue._apply_reading_text_scale(2.0)
		prologue._dismiss_dialogue_for_test()
		prologue._progress["P1_complete"] = true
		prologue._enter_room("M1_PARLOR")
		prologue._dismiss_dialogue_for_test()
		prologue._on_window_pressed(0)
		await _capture_view(tree, CAPTURE_P2_FILE, "P2_WINDOW_CAPTURE")
		prologue._apply_reading_text_scale(1.0)
	elif CAPTURE_ARG in OS.get_cmdline_user_args():
		prologue._advance_dialogue()
		prologue._advance_dialogue()
		await _capture_view(tree, CAPTURE_FILE, "PROLOGUE_CAPTURE")
	var audio_requests: Array[StringName] = []
	var room_requests: Array[String] = []
	prologue.audio_cue_requested.connect(func(id: StringName): audio_requests.append(id))
	prologue.audio_room_requested.connect(func(id: String): room_requests.append(id))
	var errors: PackedStringArray = prologue.run_smoke_scenario()
	_expect(audio_requests.count(&"AUD_SIG_LUCA") == 1, "P4 pulse dispatches once during the tea sequence", errors)
	_expect("M1_KITCHEN" in room_requests, "kitchen entry requests ambience", errors)
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en_US")
	prologue._show_p1_intro()
	_expect(prologue._dialogue_lines.size() == 4, "English P1 preserves four opening lines", errors)
	_expect("Morning light" in prologue._dialogue_label.text, "P1 uses English runtime locale", errors)
	_expect(prologue._dialogue_next.text == "Continue", "English dialogue continue control", errors)
	prologue._advance_dialogue()
	_expect("Exactly three knocks" in prologue._dialogue_label.text, "English P1 preserves knock clue", errors)
	prologue._advance_dialogue()
	_expect("my lady" in prologue._dialogue_label.text, "English P1 keeps formal address", errors)
	_expect(prologue._speaker_label.text == "Edgar", "English speaker display", errors)
	_expect(prologue._dialogue_lines[2]["speaker"] == "에드가", "Localization preserves speaker identity", errors)
	prologue._advance_dialogue()
	_expect("northern archive corridor" in prologue._dialogue_label.text, "English P1 includes portrait task", errors)
	_expect(prologue._dialogue_next.text == "Finish", "English final dialogue control", errors)
	prologue._advance_dialogue()
	_expect(not prologue._dialogue_active, "English P1 completes normally", errors)
	_expect("Examine the light" in prologue._status_label.text, "English P1 completes with localized objective", errors)
	var before_sleep_prompt: Dictionary = prologue._progress.duplicate(true)
	prologue._on_sleep_bed()
	_expect(prologue._modal_body.get_child(3).text == "Go to sleep", "English sleep confirmation action", errors)
	_expect(prologue._modal_body.get_child(4).text == "Investigate a little longer", "English sleep cancellation action", errors)
	await tree.process_frame
	await tree.process_frame
	prologue._modal_body.get_child(4).grab_focus()
	await _modal_tab(tree)
	_expect(prologue.get_viewport().gui_get_focus_owner() == prologue._modal_body.get_child(2), "Sleep modal Tab wraps to reading area", errors)
	await _modal_tab(tree, true)
	_expect(prologue.get_viewport().gui_get_focus_owner() == prologue._modal_body.get_child(4), "Sleep modal Shift+Tab wraps to last action", errors)
	_expect(prologue._progress == before_sleep_prompt, "Modal keyboard navigation preserves progress", errors)
	prologue._modal_body.get_child(4).pressed.emit()
	_expect(not prologue._modal_active, "Sleep cancellation closes prompt", errors)
	_expect(prologue._progress == before_sleep_prompt, "Sleep cancellation preserves all progress", errors)
	prologue._progress["P5_complete"] = false
	prologue._progress["p5_observations"] = []
	prologue._enter_room("M1_GREENHOUSE_VESTIBULE")
	prologue._dismiss_dialogue_for_test()
	for index in range(9):
		var hotspot_id: String = ["CORRIDOR_WINDOW", "GREENHOUSE_GLASS", "THRESHOLD"][index % 3]
		prologue._hotspot_layer.get_node(hotspot_id).pressed.emit()
		var clue: String = ["railing is completely dry", "ceiling pipes", "Spring · clear"][index % 3]
		_expect(clue in prologue._dialogue_label.text, "English weather clue from hotspot", errors)
		prologue._dismiss_dialogue_for_test()
		var observations: Array = prologue._progress["p5_observations"]
		_expect(prologue._hotspot_layer.get_child_count() == (5 if observations.size() == 3 else 4), "Repeated weather observations do not stack hotspots", errors)
		_expect(prologue._hotspot_layer.has_node("RECORD") == (observations.size() == 3), "Weather record still requires all clues", errors)
	_expect(prologue._progress["p5_observations"].size() == 3, "Repeated weather observations remain unique", errors)
	prologue._complete_p5()
	_expect(prologue._hotspot_layer.get_child_count() == 4, "Completed weather removes record action without duplicating hotspots", errors)
	prologue._dismiss_dialogue_for_test()
	for choice_id in prologue.P4_FATHER_CHOICE_ORDER:
		prologue._progress["P4_complete"] = false
		prologue._progress["tea_step"] = prologue.TEA_STEPS.size()
		prologue._progress["p4_memory_anchor_seen"] = true
		prologue._progress["p4_father_question"] = ""
		prologue._show_p4_father_choices()
		_expect(prologue._dialogue_choice_buttons[0].get_meta("choice_label") == "Was this Father's favorite tea?", "English P4 choice label", errors)
		prologue._answer_p4_father_choice(choice_id)
		_expect(prologue._progress["p4_father_question"] == choice_id, "English P4 preserves chosen ID", errors)
		_expect(prologue._dialogue_label.text == prologue._localized_p4_choices()[choice_id]["response"], "English P4 answer rendered", errors)
		prologue._answer_p4_father_choice("mansion_age" if choice_id != "mansion_age" else "father_tea")
		_expect(prologue._progress["p4_father_question"] == choice_id, "English P4 rejects second selection", errors)
		if choice_id == "luca_tenure":
			_expect(prologue._dialogue_lines.size() == 3, "Tenure keeps topic-change beats", errors)
			_expect("same number" in prologue._dialogue_label.text, "English tenure keeps loop clue", errors)
		prologue._dismiss_dialogue_for_test()
	prologue._progress["P3_complete"] = false
	prologue._progress["p3_placed"] = {}
	prologue._progress["p3_journal_seen"] = true
	prologue._progress["p3_journal_choice"] = "silent"
	prologue._enter_room("M1_LIBRARY_OUTER")
	prologue._dismiss_dialogue_for_test()
	_expect(prologue._inventory_slots[0].text == "Mechanical drawings", "English book name", errors)
	_expect("Clock · vertical lines" in prologue._hotspot_layer.get_node("SHELF_CLOCK").text, "English shelf pattern clue", errors)
	prologue._on_shelf_item_dropped("BOOK_MECHANICAL", "SHELF_CLOCK")
	_expect(prologue._progress["p3_placed"]["SHELF_CLOCK"] == "BOOK_MECHANICAL", "Book ID survives localization", errors)
	_expect(prologue._hotspot_layer.get_node("SHELF_CLOCK").text == "Mechanical drawings\n[Shelved]", "English occupied shelf", errors)
	prologue._progress["P3B_complete"] = false
	prologue._progress["p3b_placed"] = {}
	prologue._enter_room("M1_NORTH_ARCHIVE_HALL")
	prologue._dismiss_dialogue_for_test()
	_expect(prologue._inventory_slots[0].text == "Edgar · LOCK", "English portrait nameplate", errors)
	_expect("Dragon horns" in prologue._hotspot_layer.get_node("PORTRAIT_0").text, "Non-color portrait clue in English", errors)
	prologue._on_portrait_item_dropped("LABEL_MARA1", "PORTRAIT_0")
	_expect("Check the appearance and function label" in prologue._dialogue_label.text, "English portrait mismatch guidance", errors)
	_expect(prologue._progress["p3b_placed"].is_empty(), "Wrong portrait does not assign owner", errors)
	prologue._dismiss_dialogue_for_test()
	for index in range(5):
		prologue._on_portrait_item_dropped("LABEL_" + prologue.P3B_OWNERS[index], "PORTRAIT_%d" % index)
	_expect(prologue._progress["P3B_complete"], "English five-portrait completion", errors)
	_expect("Vertical lines" in prologue._dialogue_label.text, "English pattern confirmation", errors)
	while prologue._dialogue_active:
		prologue._advance_dialogue()
	prologue._progress["p3_journal_questions_asked"] = []
	prologue._show_p3_journal_choices()
	_expect(prologue._dialogue_choice_buttons[0].get_meta("choice_label") == "Who wrote this ledger?", "English author choice", errors)
	prologue._answer_p3_journal_choice("author")
	_expect(prologue._dialogue_label.text == "These are the master's records.", "English author response", errors)
	prologue._advance_dialogue()
	prologue._answer_p3_journal_choice("locked")
	_expect(prologue._dialogue_label.text == "Damaged records are easily misread.", "English locked response", errors)
	prologue._advance_dialogue()
	prologue._answer_p3_journal_choice("author")
	_expect(prologue._progress["p3_journal_questions_asked"] == ["author", "locked"], "Repeated question does not duplicate history", errors)
	prologue._advance_dialogue()
	prologue._answer_p3_journal_choice("silent")
	_expect(prologue._progress["p3_journal_choice"] == "silent", "English silent choice preserves completion state", errors)
	prologue._dismiss_dialogue_for_test()
	prologue._progress["window_states"] = prologue._make_default_window_states()
	prologue._open_window_inspection(0)
	_expect("Window 1 close-up" in prologue._window_title.text, "English window title", errors)
	_expect(prologue._window_drop_targets["TOP"].text == "Top\nDust", "English dust area", errors)
	prologue._apply_window_tool("SOFT_CLOTH", "BOTTOM")
	_expect("Work from top to bottom" in prologue._window_feedback_label.text, "English wrong-order feedback", errors)
	prologue._apply_window_tool("COARSE_BRUSH", "TOP")
	_expect("spread the dust sideways" in prologue._window_feedback_label.text, "English brush feedback", errors)
	prologue._dismiss_dialogue_for_test()
	prologue._apply_window_tool("SPANNER", "TOP")
	_expect("cannot clean the window" in prologue._window_feedback_label.text, "English spanner feedback", errors)
	prologue._dismiss_dialogue_for_test()
	prologue._apply_window_tool("SOFT_CLOTH", "TOP")
	prologue._apply_window_tool("WATER", "MIDDLE")
	_expect("water loosened the stain" in prologue._window_feedback_label.text, "English water feedback", errors)
	prologue._apply_window_tool("SOFT_CLOTH", "BOTTOM")
	_expect(prologue._is_window_clean(prologue._progress["window_states"][0]), "English actions still clean window", errors)
	var window_state: Dictionary = prologue._progress["window_states"][0]
	window_state["dust_spread"] = true
	prologue._refresh_window_inspection()
	_expect("Dust spread sideways" in prologue._window_drop_targets["TOP"].text, "English spread state", errors)
	window_state["dust_spread"] = false
	window_state["top_dust"] = false
	window_state["middle_stain"] = false
	window_state["bottom_wet"] = true
	prologue._refresh_window_inspection()
	_expect("Moisture at the bottom" in prologue._window_title.text, "English remaining moisture stage", errors)
	_expect(prologue._window_drop_targets["BOTTOM"].text == "Bottom\nWet", "English wet area", errors)
	window_state["bottom_wet"] = false
	var clean_snapshot := window_state.duplicate(true)
	prologue._refresh_window_inspection()
	_expect("This window is clean" in prologue._window_hint_label.text, "English completed window hint", errors)
	_expect(window_state == clean_snapshot, "Translation does not mutate window state", errors)
	prologue._apply_reading_text_scale(2.0)
	await tree.process_frame
	_expect(prologue._window_title.get_theme_font_size("font_size") == 64, "Window title doubles text size", errors)
	_expect(prologue._window_drop_targets["TOP"].get_theme_font_size("font_size") == 44, "Window area doubles text size", errors)
	var items: Array = []
	for index in range(6):
		items.append({"id": "TEST_%d" % index, "label": "A long inventory item label for reading"})
	prologue._update_inventory(items)
	await tree.process_frame
	await tree.process_frame
	var inventory_scroll := prologue._inventory_slots[0].get_parent().get_parent() as ScrollContainer
	_expect(prologue._inventory_slots[0].get_theme_font_size("font_size") == 34, "Inventory doubles text size", errors)
	prologue._inventory_slots[5].grab_focus()
	await tree.process_frame
	await tree.process_frame
	_expect(inventory_scroll.scroll_vertical > 0, "Keyboard focus scrolls to lower inventory slot", errors)
	var payload: Dictionary = prologue._inventory_slots[5].get_drag_payload_for_test()
	_expect(payload.get("item_id") == "TEST_5", "Scrolled inventory retains drag identity", errors)
	_expect("Dragging:" in prologue._status_label.text, "Localized drag status", errors)
	_expect("activate the target" in prologue._inventory_slots[5].accessibility_description, "Localized inventory accessibility description", errors)
	prologue._update_inventory([])
	_expect(prologue._inventory_slots[0].text == "Empty", "English empty slot", errors)
	_expect(prologue._inventory_slots[0].disabled, "Empty slot remains disabled", errors)
	_expect(prologue._inventory_slots[0].get_drag_payload_for_test().is_empty(), "Empty slot cannot drag", errors)
	_expect(not prologue._window_drop_targets["TOP"].get_rect().intersects(prologue._window_drop_targets["MIDDLE"].get_rect()), "Large window targets do not overlap", errors)
	prologue._apply_reading_text_scale(1.0)
	prologue._close_window_inspection()
	prologue._progress["P4_complete"] = false
	prologue._progress["p1_inspections"] = []
	prologue._enter_room("M2_BEDROOM")
	_expect(prologue._hotspot_layer.get_node("BED").text == "Bed", "English bedroom hotspot label", errors)
	prologue._leave_bedroom_morning()
	_expect(prologue._modal_active, "English early departure retains confirmation", errors)
	_expect(prologue._modal_body.get_child(3).text == "Begin the day's duties", "English departure action", errors)
	prologue._modal_body.get_child(4).pressed.emit()
	_expect(not prologue._modal_active and prologue._current_room == "M2_BEDROOM", "Keep looking does not leave bedroom", errors)
	for pair in [["bed", "not a wrinkle"], ["window", "altitude"], ["photo", "Father and me"], ["notebook", "pencil impressions"]]:
		prologue._inspect_bedroom(pair[0])
		_expect(pair[1] in prologue._dialogue_label.text, "English inspection " + pair[0], errors)
		_expect(pair[0] in prologue._progress["p1_inspections"], "Inspection ID preserved " + pair[0], errors)
		prologue._advance_dialogue()
	prologue._leave_bedroom_morning()
	_expect(prologue._current_room == "M1_CENTRAL_HALL", "English inspected departure reaches hall", errors)
	_expect("three routes" in prologue._dialogue_label.text, "English hall transition", errors)
	prologue._advance_dialogue()
	_expect("leave the order to you" in prologue._dialogue_label.text, "English duty order explanation", errors)
	prologue._advance_dialogue()
	for mask in range(8):
		var flags := ["P2_complete", "P3_complete", "P3B_complete"]
		var count := 0
		for index in range(flags.size()):
			prologue._progress[flags[index]] = bool(mask & (1 << index))
			count += int(prologue._progress[flags[index]])
		prologue._progress["tea_step"] = 0
		prologue._enter_room("M1_CENTRAL_HALL")
		_expect(prologue._hotspot_layer.has_node("KITCHEN") == (count == 3), "Kitchen gate for completion mask %d" % mask, errors)
		if count < 3:
			_expect(prologue._objective_label.text == "Morning duties %d / 3 · choose any order" % count, "Localized count for mask %d" % mask, errors)
			prologue._report_tasks()
			var names := ["Parlor", "Outer library", "North corridor"]
			for index in range(flags.size()):
				_expect((names[index] in prologue._dialogue_label.text) == not prologue._progress[flags[index]], "Report lists only unfinished duty", errors)
			prologue._advance_dialogue()
		else:
			_expect(prologue._objective_label.text == "Prepare tea in the kitchen", "Tea objective after all duties", errors)
		_expect(prologue._hotspot_layer.get_node("PARLOR").text.ends_with("Complete" if prologue._progress["P2_complete"] else "Pending"), "Localized task state", errors)
	prologue._progress["tea_step"] = prologue.TEA_STEPS.size()
	prologue._update_objective()
	_expect("ask Luka one question" in prologue._objective_label.text, "Tea memory objective", errors)
	prologue._progress["P4_complete"] = true
	prologue._update_objective()
	_expect("greenhouse optional" in prologue._objective_label.text, "Evening remains optional", errors)
	var saved_notes: Array = prologue._progress["notebook_entries"].duplicate(true)
	var legacy_notes := ["주방의 규칙적인 진동", "Unknown legacy note"]
	prologue._progress["notebook_entries"] = legacy_notes.duplicate()
	prologue._open_notebook()
	var english_notes: String = prologue._modal_body.get_child(2).get_child(0).text
	_expect("The kitchen's rhythmic vibration" in english_notes, "Legacy note displays in English", errors)
	_expect("Unknown legacy note" in english_notes, "Unknown note preserved", errors)
	_expect(prologue._progress["notebook_entries"] == legacy_notes, "Reading does not rewrite saved notes", errors)
	prologue._close_modal()
	await tree.process_frame
	TranslationServer.set_locale("ko_KR")
	prologue._open_notebook()
	_expect("주방의 규칙적인 진동" in prologue._modal_body.get_child(2).get_child(0).text, "Same note returns to Korean", errors)
	prologue._close_modal()
	await tree.process_frame
	prologue._add_notebook("주방의 규칙적인 진동")
	_expect(prologue._progress["notebook_entries"].size() == 2, "Locale change does not duplicate acquisition", errors)
	prologue._progress["notebook_entries"] = saved_notes
	TranslationServer.set_locale("en_US")
	for pair in [["주인공", "Protagonist"], ["마라 1", "Mara 1"], ["마라 2", "Mara 2"], ["루카", "Luka"], ["이리스", "Iris"]]:
		_expect(prologue._localized_speaker(pair[0]) == pair[1], "English speaker " + pair[0], errors)
	_expect(prologue._localized_speaker("Unknown witness") == "Unknown witness", "Unknown speaker remains visible", errors)
	TranslationServer.set_locale("ko_KR")
	prologue._show_p1_intro()
	_expect(prologue._dialogue_next.text == "계속", "Korean continue preserved", errors)
	prologue._advance_dialogue()
	prologue._advance_dialogue()
	_expect(prologue._speaker_label.text == "에드가", "Korean speaker preserved", errors)
	prologue._advance_dialogue()
	_expect(prologue._dialogue_next.text == "마침", "Korean finish preserved", errors)
	prologue._advance_dialogue()
	TranslationServer.set_locale(original_locale)
	prologue._apply_reading_text_scale(2.0)
	_expect(prologue._dialogue_label.get_theme_font_size("font_size") == 48, "Dialogue applies 200 percent text size", errors)
	_expect(prologue._dialogue_choice_buttons[0].get_theme_font_size("font_size") == 46, "Choices apply 200 percent text size", errors)
	prologue._show_dialogue([{"speaker":"SYSTEM", "text":"긴 기록의 마지막 문장까지 읽을 수 있어야 한다.\n".repeat(40)}, {"speaker":"SYSTEM", "text":"다음 기록"}])
	await tree.process_frame
	await tree.process_frame
	_expect(prologue._dialogue_label.size.y > prologue._dialogue_scroll.size.y, "Long dialogue overflows into scrollable content", errors)
	var page := InputEventKey.new()
	page.keycode = KEY_PAGEDOWN
	page.pressed = true
	prologue._unhandled_input(page)
	_expect(prologue._dialogue_scroll.scroll_vertical > 0, "Page Down scrolls dialogue without advancing", errors)
	_expect(prologue._dialogue_index == 0, "Reading does not advance the sentence", errors)
	prologue._advance_dialogue()
	_expect(prologue._dialogue_scroll.scroll_vertical == 0, "Next dialogue resets scroll", errors)
	prologue._dismiss_dialogue_for_test()
	prologue._show_modal("긴 조사 기록", "기록의 끝도 확인할 수 있다.\n".repeat(80), [{"label":"닫기", "action":prologue._close_modal}])
	await tree.process_frame
	await tree.process_frame
	prologue._unhandled_input(page)
	var modal_scroll := prologue._modal_body.get_child(2) as ScrollContainer
	_expect(modal_scroll.get_child(0).get_theme_font_size("font_size") == 46, "Modal body applies 200 percent text size", errors)
	_expect(modal_scroll.scroll_vertical > 0 and prologue._modal_active, "Page Down reads long modal without closing", errors)
	page.keycode = KEY_PAGEUP
	prologue._unhandled_input(page)
	_expect(modal_scroll.scroll_vertical == 0, "Page Up returns modal to beginning", errors)
	prologue._close_modal()
	prologue.queue_free()
	await tree.process_frame
	await _validate_p4_resume_and_choices(tree, errors)
	await _validate_reset_integration(tree, errors)
	return {"ok": errors.is_empty(), "errors": errors}


func _capture_view(tree: SceneTree, path: String, marker: String) -> void:
	await tree.process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var save_error := image.save_png(path)
	if save_error == OK:
		print("%s: %s" % [marker, ProjectSettings.globalize_path(path)])


func _validate_p4_resume_and_choices(tree: SceneTree, errors: PackedStringArray) -> void:
	const SLOT := "__test_p4_resume"
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var scene = PROLOGUE_SCENE.instantiate()
	scene.configure_session(SLOT, "P1_ENTRY", false)
	tree.root.add_child(scene)
	await tree.process_frame
	scene._dismiss_dialogue_for_test()
	for event_id in ["P1_complete", "P2_complete", "P3_complete", "P3B_complete"]:
		scene._progress[event_id] = true
	scene._progress["intros_seen"] = ["P4"]
	scene._progress["tea_step"] = scene.TEA_STEPS.size()
	scene._progress["p4_phase"] = "memory_anchor"
	scene._progress["p4_memory_anchor_seen"] = true
	scene._current_room = "M1_KITCHEN"
	scene._progress["current_room"] = "M1_KITCHEN"
	_expect(scene._save_progress(), "P4 interrupted memory save failed", errors)
	scene.queue_free()
	await tree.process_frame
	GameState.reset_for_test()
	var load_result := LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
	_expect(bool(load_result.get("ok", false)), "P4 interrupted memory load failed", errors)
	scene = PROLOGUE_SCENE.instantiate()
	scene.configure_session(SLOT, "P1_ENTRY", false)
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	_expect(scene._dialogue_active and scene._dialogue_lines.size() == 7, "P4 memory sensory sequence was skipped after reload", errors)
	while scene._dialogue_active:
		scene._advance_dialogue()
	_expect(scene._progress["p4_phase"] == "memory_anchor_ready", "P4 memory completion was not persisted", errors)
	scene._on_tea_step(0)
	_expect(scene._progress["tea_step"] == scene.TEA_STEPS.size(), "P4 repeated tea input changed completed steps", errors)
	scene._test_mode = true
	for choice_id in scene.P4_FATHER_CHOICE_ORDER:
		scene._progress["P4_complete"] = false
		scene._progress["p4_father_question"] = ""
		scene._progress["p4_phase"] = "memory_anchor_ready"
		scene._progress["iris_greeting_seen"] = false
		scene._current_room = "M1_KITCHEN"
		scene._show_p4_father_choices()
		scene._answer_p4_father_choice(choice_id)
		_expect(scene._progress["p4_father_question"] == choice_id, "P4 choice failed: " + choice_id, errors)
		scene._dismiss_dialogue_for_test()
		scene._resume_p4_question_answer()
		_expect(scene._dialogue_active and scene._dialogue_lines[0]["text"] == scene.P4_FATHER_CHOICES[choice_id]["response"], "P4 answer resume failed: " + choice_id, errors)
		scene._answer_p4_father_choice("father_tea")
		_expect(scene._progress["p4_father_question"] == choice_id, "P4 second question replaced selection", errors)
		while scene._dialogue_active:
			scene._advance_dialogue()
		_expect(scene._progress["P4_complete"] and scene._progress["iris_greeting_seen"], "P4 choice did not reach evening: " + choice_id, errors)
	scene.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()


func _validate_reset_integration(tree: SceneTree, errors: PackedStringArray) -> void:
	SaveManager.delete_test_slot(RESET_TEST_SLOT)
	GameState.reset_for_test()
	var bootstrap := tree.current_scene
	_expect(bootstrap != null and bootstrap.has_method("request_sleep_transition"), "reset coordinator entry is unavailable", errors)
	if bootstrap == null or not bootstrap.has_method("request_sleep_transition"):
		return
	var prologue = PROLOGUE_SCENE.instantiate()
	prologue.configure_session(RESET_TEST_SLOT, "P1_ENTRY", false)
	bootstrap.add_child(prologue)
	await tree.process_frame
	await tree.process_frame
	prologue._dismiss_dialogue_for_test()
	var before_failed_sleep: Dictionary = prologue._progress.duplicate(true)
	var choice_start: int = GameState.get_value(&"meta_progress.dialogue_history.entries", []).size()
	prologue._show_dialogue_choice_set("p3_journal", "Journal", "주인공", "A shown question prompt", "", ["author"], {"author": {"label": "Shown author question"}, "locked": {"label": "Unshown option"}})
	var shown_choices: Array = GameState.get_value(&"meta_progress.dialogue_history.entries", [])
	_expect(shown_choices.size() == choice_start + 1 and shown_choices.back()["variables"]["text"].contains("Shown author question") and not shown_choices.back()["variables"]["text"].contains("Unshown option"), "Choice history includes only displayed options", errors)
	prologue._slot_id = "../invalid_choice_history"
	prologue._dialogue_choice_buttons[0].pressed.emit()
	_expect(prologue._dialogue_choice_active and GameState.get_value(&"meta_progress.dialogue_history.entries", []).size() == choice_start + 1, "Failed selected-option save keeps choices open", errors)
	prologue._slot_id = RESET_TEST_SLOT
	prologue._dialogue_choice_buttons[0].pressed.emit()
	var selected_choices: Array = GameState.get_value(&"meta_progress.dialogue_history.entries", [])
	_expect(selected_choices.size() == choice_start + 3 and selected_choices[choice_start + 1]["variables"]["text"] == "Shown author question", "Choice retry records selection once before displayed answer", errors)
	prologue._dismiss_dialogue_for_test()
	before_failed_sleep = prologue._progress.duplicate(true)
	var history_count: int = GameState.get_value(&"meta_progress.dialogue_history.entries", []).size()
	var before_point := String(SaveManager.inspect_slot(RESET_TEST_SLOT).get("save_point_id", ""))
	prologue._show_dialogue([{"speaker": "주인공", "text": "Prologue shown line"}, {"speaker": "주인공", "text": "Prologue unseen line"}])
	_expect(GameState.get_value(&"meta_progress.dialogue_history.entries", []).size() == history_count + 1, "Prologue only records displayed sentence", errors)
	_expect(SaveManager.inspect_slot(RESET_TEST_SLOT).get("save_point_id", "") == before_point, "Prologue history preserves existing save point", errors)
	prologue._dismiss_dialogue_for_test()
	var before_history_menu := GameState.get_snapshot()
	prologue._open_menu()
	(prologue._modal_body.get_child(4) as Button).pressed.emit()
	var history_body := (prologue._modal_body.get_child(2).get_child(0) as Label).text
	_expect(history_body.contains("Prologue shown line") and not history_body.contains("Prologue unseen line"), "Prologue menu displays viewed history only", errors)
	(prologue._modal_body.get_child(3) as Button).pressed.emit()
	_expect(GameState.get_snapshot() == before_history_menu, "Prologue history menu is read only", errors)
	prologue._slot_id = "../invalid_sleep_slot"
	var before_history_failure := GameState.get_snapshot()
	prologue._show_dialogue([{"speaker": "주인공", "text": "History retry first"}, {"speaker": "주인공", "text": "History retry second"}])
	_expect(GameState.get_snapshot() == before_history_failure, "Failed prologue history save rolls back state", errors)
	prologue._dialogue_next.pressed.emit()
	_expect(prologue._dialogue_index == 0 and GameState.get_snapshot() == before_history_failure, "Failed history retry cannot skip current prologue sentence", errors)
	prologue._slot_id = RESET_TEST_SLOT
	prologue._dialogue_next.pressed.emit()
	_expect(prologue._dialogue_index == 1, "Recovered prologue history advances one sentence", errors)
	var retried_history: Array = GameState.get_value(&"meta_progress.dialogue_history.entries", [])
	_expect(retried_history.size() == before_history_failure["meta_progress"]["dialogue_history"]["entries"].size() + 2, "Prologue retry records each shown sentence once", errors)
	prologue._dialogue_next.pressed.emit()
	_expect(not prologue._dialogue_active, "Recovered prologue dialogue can finish", errors)
	prologue._slot_id = "../invalid_sleep_slot"
	prologue._begin_first_sleep()
	_expect(prologue._progress == before_failed_sleep, "Failed sleep restores local completion and notes", errors)
	_expect(not prologue._dialogue_active, "Failed sleep does not begin transition dialogue", errors)
	_expect(not GameState.get_value(&"meta_progress.knowledge_entries", {}).get("PROLOGUE_COMPLETE", false), "Failed sleep does not persist completion", errors)
	prologue._slot_id = RESET_TEST_SLOT
	_expect(prologue._save_progress(), "Ordinary save after failed sleep succeeds", errors)
	_expect(not GameState.get_value(&"meta_progress.knowledge_entries", {}).get("PROLOGUE_COMPLETE", false), "Later ordinary save does not leak failed completion", errors)
	prologue._begin_first_sleep()
	_expect(prologue._progress.get("P6_complete", false) and prologue._dialogue_active, "Sleep can be retried after saving recovers", errors)
	_expect(SaveManager.inspect_slot(RESET_TEST_SLOT).get("save_point_id", "") == "SAVE_P6_COMPLETE", "Sleep dialogue history does not overwrite P6 boundary", errors)
	prologue._dismiss_dialogue_for_test()
	prologue._progress["P6_complete"] = true
	prologue._progress["introduced"] = ["EDGAR", "MARA1", "MARA2", "LUCA", "IRIS"]
	prologue._progress["p3_journal_seen"] = true
	prologue._progress["P3B_complete"] = true
	prologue._progress["P4_complete"] = true
	prologue._progress["p4_memory_anchor_seen"] = true
	prologue._add_notebook("주방의 규칙적인 진동")
	prologue._progress["iris_greeting_seen"] = true
	prologue._progress["P5_complete"] = true
	var save_ok: bool = prologue._save_progress("SAVE_P6_COMPLETE", true)
	_expect(save_ok, "P6 completion save failed", errors)
	var history_before_reset: Dictionary = GameState.get_value(&"meta_progress.dialogue_history", {}).duplicate(true)
	var reset_result: Dictionary = bootstrap.request_sleep_transition(RESET_TEST_SLOT)
	_expect(bool(reset_result.get("ok", false)), "normal reset request failed", errors)
	_expect(int(GameState.get_value(&"loop_state.day_index", -1)) == 1, "normal reset day index mismatch", errors)
	_expect((GameState.get_value(&"loop_state.event_local_states", {}) as Dictionary).is_empty(), "normal reset kept physical event state", errors)
	_expect(GameState.get_value(&"meta_progress.dialogue_history", {}) == history_before_reset, "First normal reset preserves viewed dialogue history", errors)
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(RESET_TEST_SLOT).get("ok", false), "First reset history save reloads", errors)
	_expect(GameState.get_value(&"meta_progress.dialogue_history", {}) == history_before_reset, "Reload after first reset preserves dialogue history", errors)
	var knowledge: Dictionary = GameState.get_value(&"meta_progress.knowledge_entries", {})
	_expect(bool(knowledge.get("PROLOGUE_COMPLETE", false)), "normal reset lost prologue completion knowledge", errors)
	_expect(bool(knowledge.get("NOTE_JOURNAL", false)), "normal reset lost journal knowledge", errors)
	_expect(bool(knowledge.get("CLR_00_SIGNATURES", false)), "normal reset lost signature knowledge", errors)
	_expect(String(knowledge.get("MEM_FATHER_TEA_HAND_FRAGMENT", "")) == "sensory_fragment", "normal reset lost P4 tea memory anchor", errors)
	_expect("주방의 규칙적인 진동" in knowledge.get("prologue_notebook_entries", []), "normal reset lost written notebook text", errors)
	prologue.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(RESET_TEST_SLOT)
	GameState.reset_for_test()


func _expect(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(message)
