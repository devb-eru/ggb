extends RefCounted

const CATALOG := preload("res://scripts/systems/developer_checkpoints.gd")
var errors: Array[String] = []

class FailedSave:
	extends Node
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		return {"ok":false,"error_ids":["DEV_TEST_DISK_FAILURE"]}


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)


func run(bootstrap: Node) -> Dictionary:
	var tree := bootstrap.get_tree()
	var catalog := CATALOG.new()
	var rows := catalog.entries()
	_expect(rows.size() >= 75, "catalog spans prologue, all chapters, relationships and ending nodes")
	var product_before := _product_fingerprints()
	var profile_before := _profile_fingerprints()
	var original_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor", null)
	var panel = bootstrap._developer_panel
	await tree.create_timer(0.3).timeout
	await _click(tree, panel.launch_button)
	_expect(panel.panel.visible and bootstrap._start_screen.process_mode == Node.PROCESS_MODE_DISABLED, "developer menu suspends the underlying title")
	panel.search.text = "C4"
	panel._filter("C4")
	_expect(panel.selected_id == "C4" and panel.filtered.size() == 1, "search finds the mirror event")
	panel.jump_button.grab_focus()
	await _key(tree, KEY_ENTER)
	await tree.process_frame
	_expect(bootstrap._developer_active and not panel.panel.visible, "jump opens playable developer session")
	if not is_instance_valid(bootstrap._prologue):
		print("DEV_INPUT_DIAG: ", errors, " focus_suspended=", bootstrap._focus_suspended, " button=", panel.launch_button.get_global_rect(), " panel=", panel.panel.visible)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png("user://developer-input-failure.png")
		return {"ok":false,"errors":errors}
	_expect(bootstrap._prologue.session.stage() == "C4", "C4 needs no previous playthrough")
	bootstrap._prologue._dismiss_dialogue_for_test()
	var mirror = bootstrap._prologue.session
	for action in ["c_rotate", "c_anchor"]:
		_expect(mirror.act(action).get("ok", false), "mirror controls work after jump: " + action)
	for segment in mirror.MIRROR.PATH:
		_expect(mirror.act("c_segment", segment).get("ok", false), "mirror route is editable")
	_expect(mirror.act("c_dry").get("ok", false) and mirror.mirror_local().dry_passed, "jumped mirror can be solved normally")
	_expect(mirror.act("c_verify_plan").get("ok", false), "jumped mirror plan can be confirmed")
	_expect(mirror.act("c_wet", true).get("ok", false) and mirror.stage() == "C5_INFO", "jumped event advances into the next event")
	var saved_mirror := GameState.get_snapshot()
	var stale_controller: WeakRef = weakref(bootstrap._prologue)
	bootstrap._on_prologue_return_to_title()
	await tree.process_frame
	_expect(ProjectSettings.get_setting("ggb/build_flavor", null) == original_flavor, "return restores original build flavor")
	bootstrap._developer_resume()
	await tree.process_frame
	_expect(bootstrap._prologue.session.stage() == "C5_INFO" and GameState.get_snapshot().meta_progress.knowledge_entries.mirror_tracing_acquired == saved_mirror.meta_progress.knowledge_entries.mirror_tracing_acquired, "developer resume restores progress, not checkpoint defaults")
	var active_controller = bootstrap._prologue
	var active_controller_id: int = active_controller.get_instance_id()
	bootstrap._on_campaign_requested("slot_01", stale_controller)
	_expect(bootstrap._prologue == active_controller and bootstrap._prologue._slot_id == CATALOG.SLOT, "stale normal-slot transition cannot replace a developer session")
	bootstrap._on_campaign_requested(CATALOG.SLOT, weakref(active_controller))
	await tree.process_frame
	_expect(bootstrap._prologue.get_instance_id() != active_controller_id and bootstrap._prologue._slot_id == CATALOG.SLOT, "current controller can still request a campaign transition")
	for row in rows:
		var loaded := catalog.snapshot_for(row.id)
		_expect(loaded.get("ok", false), "fixture schema validates: " + row.id)
		if not loaded.get("ok", false): continue
		bootstrap._developer_jump(row.id)
		for frame in range(2): await tree.process_frame
		var view = bootstrap._prologue
		_expect(is_instance_valid(view) and view._slot_id == CATALOG.SLOT, "production controller launches: " + row.id)
		_expect(SaveManager.inspect_slot(CATALOG.SLOT).get("available", false), "jump autosave is readable: " + row.id)
		_expect(StateSnapshotValidator.new().validate(GameState.get_snapshot()).ok, "initialized state remains valid: " + row.id)
		if row.id.begins_with("EDR_") or row.id.begins_with("EDS_") or row.id.begins_with("CREDITS_") or row.id == "ED_ALL_CEREMONY":
			_expect(GameState.get_snapshot().ending_run.current_node_id == loaded.snapshot.ending_run.current_node_id, "ending jump preserves requested node: " + row.id)
		elif not row.id.begins_with("P"):
			var expected_stage: String = "EDC" if row.id.begins_with("EDC_") else row.id
			_expect(view.session.stage() == expected_stage, "controller is at requested event: " + row.id)
		if int(loaded.snapshot.meta_progress.journal_stage) >= 3:
			_expect(view.session.ending_meta_store.root_path == CATALOG.META_ROOT, "ending meta is isolated: " + row.id)
		view._dismiss_dialogue_for_test()
		if row.id == "P4":
			_expect(not view._progress.P4_complete and view._morning_tasks_complete(), "tea checkpoint has its prerequisites but remains playable")
		if row.id == "EDR_FIELD_NOTEBOOK":
			for page in view.session.FIELD_NOTEBOOK.REQUIRED:
				_expect(view.session.act("field_read", page).get("ok", false), "field page can be read after direct jump")
			_expect(view.session.act("field_finish").get("ok", false), "field notebook can advance after direct jump")
		if row.id == "F0_E":
			var rules = view.session.CORE_SELF
			var mark: Dictionary = GameState.get_snapshot().meta_progress.knowledge_entries.self_authored_mark
			for piece in rules.MARKS[mark.type]: view.session.act("f0e_piece", piece)
			view.session.act("f0e_past")
			view.session.act("f0e_author", "subject")
			_expect(view.session.act("f0e_intent", "undecided").get("ok", false) and view.session.stage() == "F1", "persistent A1 information supports F0-E continuation")
		if row.id == "CREDITS_REALITY":
			view.session.act("credits_start")
			view.session.act("credits_next", 0)
			view.session.act("credits_next", 1)
			_expect(view.session.act("credits_finish").get("ok", false), "developer ending can finish")
		if row.id == "E_HUB":
			var mode = view.process_mode
			panel.toggle()
			_expect(view.process_mode == Node.PROCESS_MODE_DISABLED, "game timers pause while choosing a checkpoint")
			await _key(tree, KEY_ESCAPE)
			_expect(not panel.panel.visible and view.process_mode == mode, "Escape returns to the unchanged session")
			await _key(tree, KEY_F10)
			_expect(panel.panel.visible, "F10 opens developer panel during play")
			panel.close()
	var before_invalid := GameState.get_snapshot()
	var failed_save := FailedSave.new()
	_expect(not catalog.activate("P1", GameState, failed_save).get("ok", false), "save error refuses checkpoint jump")
	_expect(GameState.get_snapshot() == before_invalid, "save error rolls back the previous game state")
	failed_save.free()
	var view_before = bootstrap._prologue
	bootstrap._developer_jump("not-a-real-event")
	_expect(GameState.get_snapshot() == before_invalid and bootstrap._prologue == view_before, "unknown event does not destroy current session")
	bootstrap._developer_jump("EDC_ALL")
	await tree.process_frame
	var first_run: String = SaveManager.load_slot(CATALOG.SLOT).header.run_id
	var clone: Dictionary = SaveManager.create_f3_reselect_slot(CATALOG.SLOT)
	_expect(clone.get("ok", false), "developer final decision supports a reselect copy")
	if clone.get("ok", false):
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(clone.slot_id).get("ok", false), "developer copy loads")
		var copy_view = preload("res://scripts/chapters/basement_controller.gd").new()
		copy_view.configure_session(clone.slot_id, "DEV_COPY")
		var copy_session = copy_view._make_session()
		_expect(copy_session.ending_meta_store.root_path == CATALOG.META_ROOT, "reselect provenance keeps developer ending isolation")
		var notebook = preload("res://scripts/systems/notebook_host.gd").new()
		notebook.game = GameState
		notebook.saves = SaveManager
		notebook._slot = clone.slot_id
		var scope: Dictionary = notebook._current_scope()
		_expect(scope.namespace == "development" and scope.slot == clone.slot_id and scope.run_id == SaveManager.inspect_slot(clone.slot_id).get("run_id"), "actual developer F3 clone retains notebook namespace and its own run identity")
		_expect(preload("res://scripts/systems/notebook_commands.gd").scope(GameState, SaveManager, clone.slot_id).begins_with("development:"), "actual developer F3 clone uses matching reference command namespace")
		notebook.free()
		copy_view.free()
	bootstrap._developer_jump("CREDITS_STAY")
	await tree.process_frame
	_expect(SaveManager.load_slot(CATALOG.SLOT).header.run_id != first_run, "each new checkpoint gets a distinct run identity")
	_expect(not SaveManager.load_f3_reselect(CATALOG.SLOT).get("ok", false), "direct ending jump cannot reuse an earlier run's F3 snapshot")
	if "--developer-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		panel.toggle()
		panel.search.text = ""
		panel._filter("")
		for frame in range(3): await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://developer-panel.png")
		print("DEVELOPER_CAPTURE: " + ProjectSettings.globalize_path("user://developer-panel.png"))
		panel.close()
	bootstrap._on_prologue_return_to_title()
	await tree.process_frame
	_expect(_product_fingerprints() == product_before, "normal saves remain byte-for-byte unchanged")
	_expect(_profile_fingerprints() == profile_before, "normal ending meta and gallery remain untouched")
	return {"ok":errors.is_empty(),"errors":errors,"checkpoints":rows.size()}


func _key(tree: SceneTree, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame


func _click(tree: SceneTree, button: Button) -> void:
	await tree.process_frame
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame


func _product_fingerprints() -> Dictionary:
	var result := {}
	for root in ["user://saves", "user://saves_full"]:
		for slot in ["slot_01", "slot_02", "slot_03"]:
			if not DirAccess.dir_exists_absolute(root.path_join(slot)): continue
			for name in DirAccess.get_files_at(root.path_join(slot)):
				var path: String = root.path_join(slot).path_join(name)
				result[path] = FileAccess.get_sha256(path)
	return result


func _profile_fingerprints() -> Dictionary:
	var result := {}
	for root in ["user://profile", "user://profile/ending_gallery"]:
		if not DirAccess.dir_exists_absolute(root): continue
		for name in DirAccess.get_files_at(root):
			var path: String = root.path_join(name)
			result[path] = FileAccess.get_sha256(path)
	return result
