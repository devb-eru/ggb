extends RefCounted

const PROLOGUE_SCENE := preload("res://scenes/prologue/prologue.tscn")
const CAPTURE_ARG := "--capture-prologue"
const CAPTURE_FILE := "user://prologue_dialogue_1280x720.png"
const RESET_TEST_SLOT := "__test_prologue_reset"


func run(tree: SceneTree) -> Dictionary:
	var prologue = PROLOGUE_SCENE.instantiate()
	prologue.configure_session("__test_prologue", "P1_ENTRY", true)
	tree.root.add_child(prologue)
	await tree.process_frame
	await tree.process_frame
	if CAPTURE_ARG in OS.get_cmdline_user_args():
		prologue._advance_dialogue()
		prologue._advance_dialogue()
		await tree.process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		var image := tree.root.get_texture().get_image()
		if image != null and not image.is_empty():
			image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			var save_error := image.save_png(CAPTURE_FILE)
			if save_error == OK:
				print("PROLOGUE_CAPTURE: %s" % ProjectSettings.globalize_path(CAPTURE_FILE))
	var errors: PackedStringArray = prologue.run_smoke_scenario()
	prologue.queue_free()
	await tree.process_frame
	await _validate_reset_integration(tree, errors)
	return {"ok": errors.is_empty(), "errors": errors}


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
