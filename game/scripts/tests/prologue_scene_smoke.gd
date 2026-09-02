extends RefCounted

const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const CAPTURE_ARG := "--capture-prologue"
const CAPTURE_FILE := "user://prologue_dialogue_1280x720.png"
const CAPTURE_P2_ARG := "--capture-p2-window"
const CAPTURE_P2_FILE := "user://p2_window_drag_1280x720.png"
const CAPTURE_P3_ARG := "--capture-p3-journal-choice"
const CAPTURE_P3_FILE := "user://p3_journal_choice_1280x720.png"
const RESET_TEST_SLOT := "__test_prologue_reset"


func run(tree: SceneTree) -> Dictionary:
	var prologue = PROLOGUE_SCENE.instantiate()
	prologue.configure_session("__test_prologue", "P1_ENTRY", true)
	tree.root.add_child(prologue)
	await tree.process_frame
	await tree.process_frame
	if CAPTURE_P3_ARG in OS.get_cmdline_user_args():
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
	prologue.queue_free()
	await tree.process_frame
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
	prologue.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(RESET_TEST_SLOT)
	GameState.reset_for_test()


func _expect(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(message)
