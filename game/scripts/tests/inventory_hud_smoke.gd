extends RefCounted

const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const SLOT := "__test_inventory_wake"
var errors: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: errors.append(message)

func run(tree: SceneTree) -> Dictionary:
	var checkpoints := CHECKPOINTS.new()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for pair in [
			["A1", "chapter_one_controller"], ["C0", "black_mirror_controller"],
			["D0", "basement_controller"], ["E_HUB", "basement_controller"],
		]:
			var fixture := checkpoints.snapshot_for(pair[0])
			expect(fixture.ok, "checkpoint " + pair[0])
			if not fixture.ok: continue
			GameState.reset_for_test()
			expect(StateWriter.new(GameState).install_snapshot(fixture.snapshot, GameState.revision, &"INVENTORY_SEED").ok, "seed")
			var view = load("res://scripts/chapters/" + pair[1] + ".gd").new()
			view.configure_session(SLOT, "MORNING_ROUTE")
			tree.current_scene.add_child(view)
			await tree.process_frame
			expect(view._inventory_panel.is_visible_in_tree(), locale + " " + pair[0] + " HUD visible")
			expect(view._inventory_slots.size() == 6, "six styled slots remain")
			var state: Dictionary = GameState.get_snapshot()
			state.loop_state.inventory = ["RUB_BEDROOM", "NEUTRAL_CLEANER", "MANSION_FLOORPLAN"]
			expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"INVENTORY_ITEMS").ok, "items seed")
			view._render_room()
			expect(view._inventory_item_ids() == state.loop_state.inventory, "HUD reads physical inventory")
			expect(view._inventory_slots[0].text != "RUB_BEDROOM", "localized item label")
			view._dismiss_dialogue_for_test()
			var toggle := InputEventAction.new()
			toggle.action = "inventory_toggle"
			toggle.pressed = true
			view._unhandled_input(toggle)
			expect(view._inventory_slots[0].has_focus(), "inventory shortcut focuses a visible item")
			view._inventory_slots[0].pressed.emit()
			expect(view._selected_item == "RUB_BEDROOM", "slot can be selected")
			if pair[0] == "A1":
				var reset := ResetCoordinator.new(GameState, SaveManager).request_normal_reset(SLOT)
				expect(reset.ok, "real normal reset")
				expect(GameState.get_value("loop_state.inventory", []).is_empty(), "reset clears physical items")
				view._render_room()
				expect(view._inventory_panel.is_visible_in_tree(), "HUD survives real reset")
				expect(view._inventory_item_ids().is_empty() and view._selected_item.is_empty(), "no stale reset item or selection")
			view.queue_free()
			await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale("ko-KR")
	return {"ok": errors.is_empty(), "errors": errors}
