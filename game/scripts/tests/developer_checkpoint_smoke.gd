extends RefCounted

const CATALOG := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const VIEWS := preload("res://scripts/systems/notebook_view_store.gd")
const PRESENTATION_VIEWS := preload("res://scripts/systems/presentation_view_store.gd")
const SEEDED_ARG := "--developer-isolation-seeded-smoke"
var errors: Array[String] = []
var seeded := false

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
	if SEEDED_ARG in OS.get_cmdline_user_args():
		if not await _seed_product_fixtures(tree, catalog): return {"ok":false,"errors":errors}
		seeded = true
	var product_before := _product_fingerprints()
	var profile_before := _profile_fingerprints()
	if seeded:
		_expect(product_before.size() >= 12 and profile_before.size() >= 29, "seeded comparison covers nonempty product saves and recursive profile files")
		print("NP22_SEEDED_BASELINE: ", JSON.stringify({"product_files": product_before.size(), "profile_files": profile_before.size()}))
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
		if seeded:
			await _copy_notebook(tree, copy_view, clone.slot_id)
		else: copy_view.free()
	bootstrap._developer_jump("CREDITS_STAY")
	await tree.process_frame
	_expect(SaveManager.load_slot(CATALOG.SLOT).header.run_id != first_run, "each new checkpoint gets a distinct run identity")
	_expect(not SaveManager.load_f3_reselect(CATALOG.SLOT).get("ok", false), "direct ending jump cannot reuse an earlier run's F3 snapshot")
	if seeded: await _developer_gallery(tree, bootstrap._prologue)
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
	if seeded: print("NP22_SEEDED_PRESERVATION: ", JSON.stringify({"product_unchanged":_product_fingerprints() == product_before,"profile_unchanged":_profile_fingerprints() == profile_before,"checkpoints":rows.size()}))
	return {"ok":errors.is_empty(),"errors":errors,"checkpoints":rows.size()}


func _seed_product_fixtures(tree: SceneTree, catalog) -> bool:
	var token := OS.get_environment("GGB_ISOLATED_PROFILE_TOKEN")
	var root := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	var appdata := OS.get_environment("APPDATA").replace("\\", "/").trim_suffix("/")
	if token.is_empty() or appdata.is_empty() or not root.begins_with(appdata + "/Godot/app_userdata/") or FileAccess.get_file_as_string("user://__test_np22_isolated_marker") != token:
		_expect(false, "seeded product fixtures require explicit isolated APPDATA marker")
		return false
	if not _product_fingerprints().is_empty() or not _profile_fingerprints().is_empty():
		_expect(false, "seeded fixtures refuse an existing product profile")
		return false
	if not preload("res://scripts/systems/notebook_rollout.gd").enabled():
		_expect(false, "seeded notebook fixtures require explicit debug notebook v2 rollout")
		return false
	var original: Variant = ProjectSettings.get_setting("ggb/build_flavor", null)
	var loaded: Dictionary = catalog.snapshot_for("P4")
	if not loaded.ok:
		_expect(false, "valid product fixture checkpoint")
		return false
	var state: Dictionary = loaded.snapshot
	var ref := ARCHIVE.make_reference(state.meta_progress.dialogue_history.entries[0], "legacy")
	var pinned := ARCHIVE.set_reference(state.meta_progress.dialogue_history, "bookmarks", ref, true, int(state.meta_progress.dialogue_history.revision))
	_expect(pinned.ok, "seed product bookmark")
	if not pinned.ok: return false
	state.meta_progress.dialogue_history = pinned.archive
	for flavor in ["demo", "full"]:
		ProjectSettings.set_setting("ggb/build_flavor", flavor)
		for slot in ["slot_01", "slot_02", "slot_03"]:
			for index in range(2):
				_expect(SaveManager.save_snapshot(slot, "SAVE_NEW_GAME", state, GameState.revision, "NP22_SEED_%s_%s_%d" % [flavor, slot, index]).ok, "valid product main and backup: " + flavor + "/" + slot)
			var verified: Dictionary = SaveManager.load_slot(slot)
			_expect(verified.ok and StateSnapshotValidator.same_persisted_value(state, verified.snapshot), "product fixture validates after reload")
			if not verified.ok: continue
			var archive: Dictionary = verified.snapshot.meta_progress.dialogue_history
			var scope := {"namespace":flavor,"slot":slot,"run_id":verified.header.run_id,"source_origin_id":archive.source_origin_id,"branch_id":archive.branch_id,"load_epoch":0}
			var query := QUERY.new()
			_expect(query.open(archive, verified.snapshot.meta_progress.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), scope, "ko-KR", verified.snapshot.meta_progress.knowledge_entries).ok, "product notebook query opens")
			var panel = preload("res://scripts/ui/notebook_panel.gd").new()
			tree.current_scene.add_child(panel)
			panel.present(query, "ko-KR", "dialogue", 1.0)
			panel.show_detail(QUERY.reference_key(ref))
			for frame in range(3): await tree.process_frame
			var preferences := {"seen":[QUERY.reference_key(ref)],"groups":[],"general":panel.capture_view(),"dialogue":panel.capture_view()}
			var persistent := VIEWS.persistent_scope(scope)
			var views := VIEWS.new()
			for index in range(2): _expect(views.save_view(persistent, query.view_frontier(), preferences).ok, "seed product notebook main and backup")
			_expect(views.load_view(persistent, query.view_frontier()).state.seen == preferences.seen, "seeded product reading state loads")
			var presentation_views := PRESENTATION_VIEWS.new()
			var presentation_identity: String = ("np22-product-" + flavor + slot).sha256_text()
			var presentation_view := {"focus":"seeded:source","scrolls":{},"layout":["ko-KR",1.0,1280.0,720.0]}
			for index in range(2): _expect(presentation_views.save_view(persistent, presentation_identity, presentation_view), "seed product presentation main and backup")
			panel.queue_free()
			await tree.process_frame
			query.close()
	ProjectSettings.set_setting("ggb/build_flavor", original)
	var gallery := EndingGalleryStore.new()
	var meta := EndingMetaStore.new()
	for ending in ["CREDITS_REALITY", "CREDITS_STAY"]:
		var completed: Dictionary = catalog.snapshot_for(ending)
		_expect(completed.ok, "normal completed-ending fixture")
		if completed.ok:
			_expect(meta.commit_completed(completed.snapshot).ok, "seed normal ending meta")
			_expect(gallery.capture(completed.snapshot).ok, "seed normal gallery capture")
	_expect(gallery.list_entries().size() == 2 and meta.load_profile().profile.ending_meta.reality_seen and meta.load_profile().profile.ending_meta.stay_seen, "both normal endings validate before developer actions")
	return errors.is_empty()


func _copy_notebook(tree: SceneTree, view, slot: String) -> void:
	tree.current_scene.add_child(view)
	for frame in range(3): await tree.process_frame
	var tracker := preload("res://scripts/systems/presentation_view_tracker.gd").new()
	tracker.view = view
	_expect(tracker._live().namespace == "development", "actual F3 copy presentation tracker retains developer namespace")
	tracker.free()
	view._dismiss_dialogue_for_test()
	view._open_notebook()
	var host = view._notebook_host
	var ready := await preload("res://scripts/tests/notebook_test_wait.gd").ready(tree, host)
	_expect(ready, "actual F3 copy notebook opens")
	if ready:
		_expect(host._scope.namespace == "development", "copy notebook remains in developer scope")
		var rows: Dictionary = host.model.page({"tab":"dialogue"}, 0, host.model.cache_key())
		_expect(not rows.items.is_empty(), "copy notebook contains acquired source material")
		if not rows.items.is_empty():
			var row: Dictionary = rows.items[0]
			host.panel.set_tab("dialogue")
			host.panel.show_detail(row.key)
			host.panel.reference_requested.emit("bookmarks", row.reference, true)
			var start := Time.get_ticks_msec()
			while not host._reference_job.is_empty() or not host._refresh_job.is_empty():
				if Time.get_ticks_msec() - start > 60000:
					_expect(false, "copy notebook save watchdog")
					break
				await tree.process_frame
			var saved: Dictionary = SaveManager.load_slot(slot)
			_expect(saved.ok and row.reference in saved.snapshot.meta_progress.dialogue_history.bookmarks, "copy bookmark persists through actual async host and reload")
		host.request_close()
		for frame in range(3): await tree.process_frame
	view.queue_free()
	await tree.process_frame


func _developer_gallery(tree: SceneTree, owner: Control) -> void:
	var store := EndingGalleryStore.new(CATALOG.META_ROOT.path_join("ending_gallery"))
	var entries := store.list_entries()
	_expect(not entries.is_empty(), "developer actions produced an isolated gallery capture")
	if entries.is_empty(): return
	var before := GameState.get_snapshot()
	var host = preload("res://scripts/systems/notebook_gallery_host.gd").new()
	tree.current_scene.add_child(host)
	_expect(host.begin(owner, store, entries[0].id, "ko-KR", 1.0), "actual developer gallery notebook opens")
	if host._active():
		var rows: Dictionary = host.model.page({"tab":"dialogue"}, 0, host.model.cache_key())
		_expect(not rows.items.is_empty(), "developer capture exposes only its acquired material")
		if not rows.items.is_empty():
			host.panel.set_tab("dialogue")
			host.panel.show_detail(rows.items[0].key)
			host.panel.reference_requested.emit("comparison", rows.items[0].reference, true)
		host.request_close()
		for frame in range(3): await tree.process_frame
	else: host.queue_free()
	_expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "developer gallery read and temporary comparison never mutate live state")


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
	_profile_files("user://profile", result)
	return result


func _profile_files(root: String, result: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(root): return
	for name in DirAccess.get_files_at(root):
		var path := root.path_join(name)
		if not _developer_view_file(path): result[path] = FileAccess.get_sha256(path)
	for name in DirAccess.get_directories_at(root): _profile_files(root.path_join(name), result)


func _developer_view_file(path: String) -> bool:
	var notebook := path.begins_with("user://profile/notebook_views/")
	if not notebook and not path.begins_with("user://profile/presentation_views/"): return false
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary or not envelope.get("payload") is String: return false
	var payload: Variant = JSON.parse_string(envelope.payload)
	if not payload is Dictionary or not payload.get("scope") is Dictionary: return false
	var store: RefCounted = VIEWS.new() if notebook else PRESENTATION_VIEWS.new()
	var expected: Dictionary = store.paths(payload.scope)
	if path not in expected.values() or not store._read(path, payload.scope).ok: return false
	if payload.scope.namespace == "development": return true
	if not notebook or payload.scope.namespace != "gallery": return false
	var gallery := EndingGalleryStore.new(CATALOG.META_ROOT.path_join("ending_gallery"))
	return gallery.list_entries().any(func(entry: Dictionary) -> bool: return entry.id == payload.scope.slot)
