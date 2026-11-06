extends RefCounted

const BASEMENT := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CORE_SELF := preload("res://scripts/systems/core_self_authority.gd")
const SLOT := "__test_world_choice"

var errors: Array[String] = []
var serial: int = 0


func run(tree: SceneTree) -> Dictionary:
	errors.clear()
	serial = 0
	if not OS.is_debug_build() or tree.current_scene == null:
		return {"ok": false, "errors": ["A debug project with a current scene is required."]}
	var original_locale: String = TranslationServer.get_locale()
	var original_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var cases: Array[Dictionary] = [
		{"id": "LUCA_S2", "choices": ["LUCA_S2_0", "LUCA_S2_1", "LUCA_S2_2"]},
		{"id": "E2_INTRO", "variant": "report_seen", "choices": ["E2_Q_0", "E2_Q_1", "E2_Q_2", "E2_FINISH"], "plain": ["E2_REPORT"]},
		{"id": "E5", "variant": "seated", "choices": ["E5_QUESTION_wish", "E5_QUESTION_leave", "E5_QUESTION_stay"], "plain": ["E5_TABLE", "E5_SEATS", "E5_HALL"]},
		{"id": "E6", "variant": "edgar", "choices": ["EDGAR_S3_ask", "EDGAR_S3_order", "EDGAR_S3_wait", "E6_OPEN"], "plain": ["E6_HALL"]},
		{"id": "E6", "variant": "mara2", "choices": ["MARA2_FU_write", "MARA2_FU_call", "MARA2_FU_joke"], "plain": ["E6_CLOCK", "E6_HALL"]},
		{"id": "F0_E", "plain": ["F0E_PIECE_0", "F0E_PIECE_1", "F0E_PIECE_2", "F0E_CLEAR", "F0E_PAST"]},
		{"id": "F0_E", "variant": "author", "choices": ["F0E_AUTHOR_father", "F0E_AUTHOR_system", "F0E_AUTHOR_subject", "F0E_AUTHOR_servant"]},
		{"id": "F0_E", "variant": "intent", "choices": ["F0E_INTENT_reality", "F0E_INTENT_stay", "F0E_INTENT_undecided"]},
		{"id": "F2", "variant": "entered", "choices": ["F2_consent", "F2_awakening", "F2_outside", "F2_release", "F2_wish"]},
		{"id": "EDR_AIRLOCK_CONFIRM", "choices": ["SURFACE_CANCEL", "SURFACE_ENTER"]},
		{"id": "EDR_FINAL_FRAME", "choices": ["SURFACE_LOOK_left", "SURFACE_LOOK_center", "SURFACE_LOOK_right"]},
		{"id": "EDS_AUTONOMY_CHARTER", "choices": ["STAY_ROLE_edgar", "STAY_ROLE_mara1", "STAY_ROLE_luca", "STAY_ROLE_iris", "STAY_ROLE_mara2"], "plain": ["STAY_INSPECT_FRAME", "STAY_MODE_SETTINGS"]},
		{"id": "EDS_TABLE_OBJECTS", "choices": ["STORY_WRITE_0", "STORY_WRITE_1", "STORY_TEA_WARM", "STORY_TEA_HOT"], "plain": ["STORY_TABLE_edgar"]},
		{"id": "EDC", "choices": ["EDC_REALITY", "EDC_STAY", "EDC_CANCEL"], "plain": ["EDC_SUBJECT"]},
		{"id": "D6", "variant": "spine", "choices": ["D6_CAPSULE"], "plain": ["D6_BEDROOM", "D6_INSPECT_wall"]},
		{"id": "D5", "variant": "focus"},
	]
	for locale: String in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for test_case: Dictionary in cases:
			await _inspect_case(tree, test_case)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(original_locale)
	ProjectSettings.set_setting("ggb/build_flavor", original_flavor)
	return {"ok": errors.is_empty(), "errors": errors}


func _fixture(id: String, variant: String) -> Dictionary:
	var loaded: Dictionary = CHECKPOINTS.new().snapshot_for(id)
	_expect(bool(loaded.get("ok", false)), "checkpoint " + id)
	if not loaded.get("ok", false): return {}
	var state: Dictionary = loaded.snapshot.duplicate(true)
	state.meta_progress.dialogue_history = ARCHIVE.create()
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	knowledge.erase("notebook_knowledge")
	var locals: Dictionary = state.loop_state.event_local_states
	match id:
		"E2_INTRO":
			knowledge.E2_report_seen = true
		"E5":
			state.loop_state.location_id = "M1_DINING_ROOM"
			locals.E5 = {"entered": true, "seated": true, "seen": [], "question": ""}
		"E6":
			knowledge.erase("core_access_open")
			if variant == "mara2":
				state.loop_state.location_id = "M1_NORTH_ARCHIVE_HALL"
				state.meta_progress.servants.mara2.core_event_complete = true
				state.meta_progress.event_history.erase("MARA2_FU")
			else:
				state.loop_state.location_id = "H0_CLOCK_MACHINE"
				state.meta_progress.event_history.erase("EDGAR_S3")
		"F0_E":
			if variant in ["author", "intent"]:
				var mark: Dictionary = knowledge.self_authored_mark
				var pieces: Array = CORE_SELF.MARKS[String(mark.type)]
				locals.F0_E = {"sequence": pieces.duplicate(), "past_verified": true, "current_verified": variant == "intent"}
				if variant == "intent": knowledge.subject_authority_restored = true
		"F2":
			locals.F2 = {"entered": true, "questions": [], "facts": [], "recapped": false}
		"D6":
			state.loop_state.location_id = "H0_SERVICE_SPINE"
	return state


func _inspect_case(tree: SceneTree, test_case: Dictionary) -> void:
	var id: String = String(test_case.id)
	var variant: String = String(test_case.get("variant", ""))
	var label: String = "%s/%s/%s" % [TranslationServer.get_locale(), id, variant]
	var state: Dictionary = _fixture(id, variant)
	if state.is_empty(): return
	GameState.reset_for_test()
	serial += 1
	var installed: Dictionary = StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("WORLD_CHOICE_FIXTURE_%d" % serial))
	_expect(bool(installed.get("ok", false)), label + " fixture install: " + str(installed.get("error_ids", [])))
	if not installed.get("ok", false): return
	var view: BasementController = BASEMENT.new()
	view.configure_session(SLOT, id)
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view.set_process(false)
	view._edgar_timer.stop()
	view._render_room()
	_expect(view._notebook_surface_allowed(), label + " surface capture")
	view.set_process(false)
	await tree.process_frame
	var expected_stage: String = id
	if id.begins_with("EDR_"): expected_stage = "REALITY_SURFACE"
	elif id == "EDS_AUTONOMY_CHARTER": expected_stage = "STAY_CHARTER"
	elif id == "EDS_TABLE_OBJECTS": expected_stage = "STAY_STORY"
	_expect(view.session.stage() == expected_stage, label + " expected gameplay stage")
	var choices: Array = test_case.get("choices", [])
	var choice_rects: Array[Rect2] = []
	for button_id: String in choices:
		var button: Button = view._hotspot_layer.get_node_or_null(NodePath(button_id)) as Button
		_expect_choice(button, label + "/" + button_id)
		if button != null:
			var rect: Rect2 = button.get_rect()
			_expect(rect.size.x >= 300 and rect.size.y >= 88, label + " readable narrative rectangle: " + button_id)
			for other: Rect2 in choice_rects:
				_expect(not rect.intersects(other), label + " narrative choices do not overlap: " + button_id)
			choice_rects.append(rect)
	var plain: Array = test_case.get("plain", [])
	for button_id: String in plain:
		var button: Button = view._hotspot_layer.get_node_or_null(NodePath(button_id)) as Button
		_expect(button != null, label + " unchanged control " + button_id)
		if button != null:
			_expect(not bool(button.get_meta("authored_choice", false)), label + " movement/inspection/puzzle not migrated: " + button_id)
			_expect(button.has_theme_stylebox_override("normal"), label + " legacy world style retained: " + button_id)
	if id == "E6":
		var movement: Control = view._hotspot_layer.get_node_or_null("E6_HALL") as Control
		if movement != null:
			_expect(movement.position == Vector2(350, 850) and movement.size == Vector2(1200, 70), label + " movement rectangle retained")
	if id == "D5":
		await _inspect_d5(tree, view, label)
	elif not choices.is_empty():
		var last: Button = view._hotspot_layer.get_node_or_null(NodePath(String(choices.back()))) as Button
		if last != null:
			var before: Dictionary = view.session.snapshot()
			last.grab_focus()
			await tree.process_frame
			_expect(last.theme_type_variation == &"DialogueChoiceSelectedButton", label + " focus highlights authored choice")
			_expect(view.session.snapshot() == before, label + " focus does not dispatch a gameplay choice")
	view.queue_free()
	await tree.process_frame


func _inspect_d5(tree: SceneTree, view: BasementController, label: String) -> void:
	view._show_full_fracture_transition()
	for _index: int in range(16):
		if not view._dialogue_active: break
		var line: Dictionary = view._dialogue_lines[view._dialogue_index]
		if bool(line.get("d5_focus_allowed", false)): break
		view._advance_dialogue()
	view._refresh_d5_focus_controls()
	await tree.process_frame
	var panel: Control = view._dialogue_layer.get_node_or_null("D5Focus") as Control
	_expect(panel != null and panel.is_visible_in_tree(), label + " D5 viewing choices appear on an allowed line")
	if panel == null: return
	for owner: String in ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]:
		_expect_choice(panel.get_node_or_null(NodePath(owner)) as Button, label + "/D5Focus/" + owner)
	var last: Button = panel.get_node_or_null("MARA2") as Button
	if last != null:
		var before: Dictionary = view.session.snapshot()
		last.grab_focus()
		await tree.process_frame
		_expect(last.theme_type_variation == &"DialogueChoiceSelectedButton", label + " fifth D5 choice highlights")
		_expect(view.session.snapshot() == before, label + " D5 focus does not save a viewing selection")
	view._dismiss_dialogue_for_test()


func _expect_choice(button: Button, label: String) -> void:
	_expect(button != null, label + " expected narrative button exists")
	if button == null: return
	_expect(bool(button.get_meta("authored_choice", false)), label + " authored_choice metadata")
	_expect(button.theme != null, label + " authored theme assigned")
	_expect(button.theme_type_variation in [&"DialogueChoiceButton", &"DialogueChoiceSelectedButton"], label + " authored theme variation")
	_expect(button.pressed.get_connections().size() == 1, label + " exactly one gameplay callback")
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		_expect(not button.has_theme_stylebox_override(style_name), label + " no legacy " + style_name + " override")
		var style: StyleBoxTexture = button.get_theme_stylebox(style_name) as StyleBoxTexture
		_expect(style != null and style.texture != null, label + " textured " + style_name + " style")
		if style != null and style.texture != null:
			_expect(style.texture.resource_path in ["res://assets/ui/dialogue_editor/choice_idle.res", "res://assets/ui/dialogue_editor/choice_selected.res"], label + " authored choice texture: " + style_name)


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
