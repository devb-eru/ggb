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
		prologue._dismiss_dialogue_for_test()
		prologue._progress["P1_complete"] = true
		prologue._enter_room("M1_PARLOR")
		prologue._dismiss_dialogue_for_test()
		prologue._on_window_pressed(0)
		await _capture_view(tree, CAPTURE_P2_FILE, "P2_WINDOW_CAPTURE")
	elif CAPTURE_ARG in OS.get_cmdline_user_args():
		prologue._advance_dialogue()
		prologue._advance_dialogue()
		await _capture_view(tree, CAPTURE_FILE, "PROLOGUE_CAPTURE")
	var errors: PackedStringArray = prologue.run_smoke_scenario()
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en_US")
	prologue._show_p1_intro()
	_expect(prologue._dialogue_lines.size() == 4, "English P1 preserves four opening lines", errors)
	_expect("Morning light" in prologue._dialogue_label.text, "P1 uses English runtime locale", errors)
	prologue._advance_dialogue()
	_expect("Exactly three knocks" in prologue._dialogue_label.text, "English P1 preserves knock clue", errors)
	prologue._advance_dialogue()
	_expect("my lady" in prologue._dialogue_label.text, "English P1 keeps formal address", errors)
	prologue._advance_dialogue()
	_expect("northern archive corridor" in prologue._dialogue_label.text, "English P1 includes portrait task", errors)
	prologue._advance_dialogue()
	_expect(not prologue._dialogue_active, "English P1 completes normally", errors)
	_expect("Examine the light" in prologue._status_label.text, "English P1 completes with localized objective", errors)
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
	var reset_result: Dictionary = bootstrap.request_sleep_transition(RESET_TEST_SLOT)
	_expect(bool(reset_result.get("ok", false)), "normal reset request failed", errors)
	_expect(int(GameState.get_value(&"loop_state.day_index", -1)) == 1, "normal reset day index mismatch", errors)
	_expect((GameState.get_value(&"loop_state.event_local_states", {}) as Dictionary).is_empty(), "normal reset kept physical event state", errors)
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
