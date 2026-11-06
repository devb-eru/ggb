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
