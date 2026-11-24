extends RefCounted

const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const SLOT := "__test_choice_routine"
var errors: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: errors.append(message)

func run(tree: SceneTree) -> Dictionary:
	var fixture := CHECKPOINTS.new().snapshot_for("AS")
	expect(fixture.ok, "AS checkpoint")
	GameState.reset_for_test()
	expect(StateWriter.new(GameState).install_snapshot(fixture.snapshot, GameState.revision, &"CHOICE_SEED").ok, "seed")
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	expect(view._hotspot_layer.has_node("AS_ROUTINE"), "routine initially visible")
	expect(view.session.act("routine").ok, "complete actual daily routine")
	view._render_room()
	expect(not view._hotspot_layer.has_node("AS_ROUTINE"), "routine disappears for completed day")
	expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload completed day")
	view._render_room()
	expect(not view._hotspot_layer.has_node("AS_ROUTINE"), "routine stays hidden after load")
	expect(view.session.sleep().ok, "real sleep")
	view._render_room()
	expect(view._hotspot_layer.has_node("AS_ROUTINE"), "routine returns next day")
	await _exercise_menu_reuse(tree, view)
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for count in [1, 2, 3, 4, 8]:
			var selected := []
			var actions: Array = []
			for index in range(count): actions.append({"label": ("선택 " if locale == "ko-KR" else "Choice ") + str(index + 1), "action": func(): selected.append(true)})
			view._show_modal("선택" if locale == "ko-KR" else "Choice", "본문" if locale == "ko-KR" else "Body", actions)
			await tree.process_frame
			expect(view._modal_panel.scene_file_path == "res://scenes/ui/choice_window.tscn", "modal instantiates authored choice scene")
			expect(view._modal_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "authored frame is not overridden")
			var buttons: Array[Button] = view._modal_panel.choice_buttons()
			expect(buttons.size() == count, "no three-choice limit")
			for button in buttons:
				expect(button.get_theme_stylebox("normal") is StyleBoxTexture, "authored textured style")
				expect(not button.has_theme_stylebox_override("normal"), "no legacy style override")
			buttons[-1].grab_focus()
			await tree.process_frame
			expect(buttons[-1].theme_type_variation == &"DialogueChoiceSelectedButton", "dynamic final option highlight")
			expect(selected.is_empty(), "focus cannot select")
			buttons[-1].pressed.emit()
			expect(selected.size() == 1, "single callback dispatch")
			view._close_modal()
			view._reading_text_scale = 2.0
			view._show_modal("Large text", "Body", actions)
			await tree.process_frame
			expect(view._modal_scroll.follow_focus, "long choices scroll with keyboard focus")
			view._close_modal()
			view._reading_text_scale = 1.0
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale("ko-KR")
	return {"ok": errors.is_empty(), "errors": errors}


func _exercise_menu_reuse(tree: SceneTree, view: ChapterOneController) -> void:
	view._open_menu()
	await tree.process_frame
	var title := view._modal_body.get_child(0)
	var scroll := view._modal_body.get_child(2) as ScrollContainer
	var continue_button := view._modal_body.get_child(3) as Button
	var history_button := view._modal_body.get_child(4) as Button
	continue_button.pressed.emit()
	view._open_menu()
	await tree.process_frame
	expect(view._modal_body.get_child(0) == title and view._modal_body.get_child(2) == scroll, "menu reopens with the same title and scroll")
	expect(view._modal_body.get_child(3) == continue_button and continue_button.has_focus(), "menu reopens with the same focused Continue button")
	scroll.custom_minimum_size.y = 430
	var handled: Array[String] = []
	view._show_modal("Confirm", "Body", [{"label": "OK", "action": func(): handled.append("previous")}])
	expect(view._modal_body.get_child(0) == title and view._modal_body.get_child(2) == scroll and scroll.custom_minimum_size.y == 100, "confirmation reuses the body and resets its minimum height")
	view._show_modal("Next", "Body", [{"label": "OK", "action": func(): handled.append("current")}])
	var confirm_button := view._modal_body.get_child(3) as Button
	expect(confirm_button == continue_button, "replacement confirmation reuses the first action button")
	expect(history_button.get_parent() != view._modal_body, "unused menu action leaves the active controls")
	history_button.pressed.emit()
	expect(view._modal_active and handled.is_empty(), "inactive menu button cannot change the confirmation")
	confirm_button.pressed.emit()
	expect(handled == ["current"], "reused action button dispatches only the current confirmation")
	view._show_history_result({"ok": true, "entries": []})
	expect(view._modal_body.has_node("HistoryTranscriptScroll") and scroll.get_parent() != view._modal_body, "legacy history gets its own scroll")
	view._open_menu()
	expect(view._modal_body.get_child(0) == title and view._modal_body.get_child(2) == scroll and view._modal_body.get_child(3) == continue_button, "returning from history restores the menu controls")
	continue_button.pressed.emit()
