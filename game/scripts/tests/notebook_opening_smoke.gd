extends "res://scripts/tests/notebook_host_smoke.gd"

const WAIT := preload("res://scripts/tests/notebook_test_wait.gd")


func run(tree: SceneTree) -> Dictionary:
	var old_locale := TranslationServer.get_locale()
	var old_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for scenario in ["success", "dialogue", "repeat", "locale", "revision", "reload", "slot", "session", "profile", "close", "escape", "held", "destroy", "large", "disk_invalid"]:
			await _opening_case(tree, scenario)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)
	ProjectSettings.set_setting("ggb/build_flavor", old_flavor)
	print("NOTEBOOK_OPENING_CHECKS: %d" % checks)
	return {"ok":errors.is_empty(), "errors":errors, "not_covered":["OS_INPUT", "IME", "PERFORMANCE_ACCEPTANCE", "FULL_HOST_REGRESSION"]}


func _opening_case(tree: SceneTree, scenario: String) -> void:
	var view = await _campaign_view(tree, "C3")
	view._reading_text_scale = 2.0
	var expected_rows := ""
	if scenario == "large":
		var fixture := preload("res://scripts/tests/notebook_performance_fixture.gd").build("NB-PERF-L10000")
		var large := GameState.get_snapshot()
		large.meta_progress.dialogue_history = fixture.archive
		large.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = fixture.ledger
		_expect(StateWriter.new(GameState).install_snapshot(large, GameState.revision, &"LOAD_OPENING_LARGE").ok, "install large opening fixture")
		_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", large, GameState.revision, "OPENING_LARGE").ok, "persist large opening fixture")
	var before := GameState.get_snapshot()
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var disk := FileAccess.get_file_as_bytes(paths.main)
	var backup_exists := FileAccess.file_exists(paths.backup)
	var backup := FileAccess.get_file_as_bytes(paths.backup) if backup_exists else PackedByteArray()
	var start := Time.get_ticks_usec()
	if scenario == "dialogue": view._open_dialogue_history()
	else: view._open_notebook()
	var begin_ms := (Time.get_ticks_usec() - start) / 1000.0
	var host = view._notebook_host
	_expect(is_instance_valid(host), "opening accepted: " + scenario)
	if not is_instance_valid(host):
		view.queue_free()
		await tree.process_frame
		return
	host.set_process(false)
	_expect(host._opening and host._loading.visible and not host.panel.visible and not host.model.diagnostics().ready, "loading precedes publication: " + scenario)
	_expect(not view.visible and view.process_mode == Node.PROCESS_MODE_DISABLED and host._suspended, "world suspended during preparation: " + scenario)
	_expect(tree.root.gui_get_focus_owner() == host._loading_close and host._loading_close.get_theme_font_size("font_size") == 36, "loading keyboard target and inherited 200 percent font")
	_expect(host._loading_close.custom_minimum_size == Vector2(44, 44) and host._loading_retry.custom_minimum_size == Vector2(44, 44), "loading actions keep minimum 44 by 44 targets")
	host._request_reference("bookmarks", {}, true)
	_expect(host.pending.is_empty() and host._reference_job.is_empty() and not host._view_dirty, "opening cannot mutate references or view state")
	if host._refresh_job.is_empty():
		_expect(false, "opening worker started")
		view.queue_free()
		await tree.process_frame
		return
	var worker: Thread = host._refresh_job.thread
	var candidate: WeakRef = weakref(host._refresh_job.model)
	match scenario:
		"disk_invalid":
			# Only the suite-owned isolated slot is damaged; restore exact bytes below.
			for path in [paths.main, paths.backup]:
				var file := FileAccess.open(path, FileAccess.WRITE)
				_expect(file != null, "open isolated slot for corruption fixture")
				if file != null:
					file.store_string("{invalid notebook opening fixture")
					file.close()
			_expect(not SaveManager.inspect_slot(SLOT).available, "both damaged candidates are unavailable")
		"repeat": host.refresh()
		"locale": TranslationServer.set_locale("ko-KR" if TranslationServer.get_locale().begins_with("en") else "en-US")
		"revision", "reload": _expect(StateWriter.new(GameState).install_snapshot(before, GameState.revision, &"LOAD_OPENING_OTHER" if scenario == "reload" else &"OPENING_OTHER").ok, "change scope or revision while opening")
		"slot": view._slot_id = "__test_notebook_other_slot"
		"session": view.session = view._make_session()
		"profile": host.view_profile = "other-opening-profile"
		"close": host._loading_close.pressed.emit()
		"escape":
			var escape := InputEventAction.new()
			escape.action = "ui_cancel"
			escape.pressed = true
			host._unhandled_input(escape)
		"held":
			host._input(_key(KEY_N, true))
			host.request_close()
		"destroy": host.free()
	var frames := 0
	var deadline := Time.get_ticks_msec() + 60000
	while worker.is_alive():
		await tree.process_frame
		frames += 1
		if Time.get_ticks_msec() > deadline:
			_expect(false, "opening worker watchdog")
			break
	var dispatch_ms := 0.0
	if scenario != "destroy":
		start = Time.get_ticks_usec()
		host._process(0.0)
		dispatch_ms = (Time.get_ticks_usec() - start) / 1000.0
		if scenario == "held":
			_expect(host._suspended and not view.visible and host._refresh_job.is_empty(), "closed preparation waits for held input release")
			host._input(_key(KEY_N, false))
			host._process(0.0)
		if scenario == "revision":
			_expect(host._opening and host._loading_retry.visible and not host.panel.visible and not host.model.diagnostics().ready, "stale initial candidate offers retry without publishing")
			host._loading_retry.pressed.emit()
		if scenario == "disk_invalid":
			_expect(host._opening and host._loading_retry.visible and not host.panel.visible and not host.model.diagnostics().ready, "invalid disk candidate cannot publish prepared records")
			_expect(GameState.get_snapshot() == before and host.pending.is_empty() and host._reference_job.is_empty(), "disk failure cannot mutate game or start a reference write")
			host._loading_retry.pressed.emit()
			_expect(host._refresh_job.is_empty() and host._opening and not host.panel.visible, "retry while disk remains invalid cannot start or publish")
			for path in [paths.main, paths.backup]:
				if path == paths.backup and not backup_exists:
					_expect(DirAccess.remove_absolute(path) == OK, "remove suite-created backup fixture")
					continue
				var file := FileAccess.open(path, FileAccess.WRITE)
				_expect(file != null, "restore isolated slot")
				if file != null:
					file.store_buffer(disk if path == paths.main else backup)
					file.close()
			_expect(SaveManager.inspect_slot(SLOT).available, "restored disk is revalidated")
			host._loading_retry.pressed.emit()
		host.set_process(true)
	if scenario in ["success", "dialogue", "repeat", "locale", "revision", "large", "disk_invalid"]:
		var ready := await WAIT.ready(tree, host)
		_expect(ready, "opening completes: " + scenario)
		if ready:
			_expect(host.panel.visible and not host._loading.visible and host.panel._reference_editable, "ready panel replaces loading")
			_expect(host.model._locale == ("en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"), "latest locale published")
			_expect(host.panel._filters.tab == ("dialogue" if scenario == "dialogue" else "clues"), "requested entry tab preserved")
			if scenario == "large":
				# Run the synchronous oracle afterwards so it cannot consume the worker's
				# entire lifetime and hide whether preparation yielded scene frames.
				var baseline := preload("res://scripts/systems/notebook_query.gd").new()
				_expect(baseline.open(before.meta_progress.dialogue_history, before.meta_progress.knowledge_entries[KNOWLEDGE.KEY], host._scope, TranslationServer.get_locale(), before.meta_progress.knowledge_entries, view._notebook_context_node()).ok, "synchronous comparison model")
				expected_rows = JSON.stringify(baseline._rows, "", true).sha256_text()
				baseline.close()
				_expect(frames > 0, "large initial preparation yields scene frames")
				_expect(JSON.stringify(host.model._rows, "", true).sha256_text() == expected_rows, "every large public row preserved")
				print("NOTEBOOK_OPENING_MEASUREMENT: ", JSON.stringify({"locale":host.model._locale, "begin_ms":begin_ms, "dispatch_ms":dispatch_ms, "worker_wait_frames":frames, "acceptance":"HEADLESS_SINGLE_SAMPLE_ONLY"}))
	else:
		_expect(candidate.get_ref() == null, "obsolete opening candidate released: " + scenario)
		if scenario in ["close", "escape", "held", "destroy"]:
			_expect(view.visible and view.process_mode == Node.PROCESS_MODE_PAUSABLE, "safe early close restores controller")
		else:
			_expect(not view.visible and view.process_mode == Node.PROCESS_MODE_DISABLED, "obsolete controller never resumes")
	_expect(GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == disk, "opening is read only: " + scenario)
	if scenario == "disk_invalid":
		_expect(FileAccess.file_exists(paths.backup) == backup_exists and (not backup_exists or FileAccess.get_file_as_bytes(paths.backup) == backup), "backup is restored byte-for-byte without repair writes")
	view.queue_free()
	await tree.process_frame
	await tree.process_frame
