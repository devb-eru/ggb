extends RefCounted

const CAPTURE := preload("res://scripts/systems/notebook_surface_capture.gd")
const RECEIPT := preload("res://scripts/systems/notebook_surface_receipt.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const SLOT := "__test_surface_resume"
const ID := "NB_FINAL_EDC_SCREEN_NOTICE"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class Saves extends Node:
	var reject := false
	var lose_ack := false
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject: return {"ok": false, "error_ids": ["TEST_SURFACE_REJECT"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false} if lose_ack and result.ok else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)

class Session extends RefCounted:
	var saves: Node
	func record_viewed_line(speaker: String, text: String, locale: String, context: Dictionary) -> Dictionary:
		return WRITER.record(GameState, saves, SLOT, "SAVE_F3_COMPLETE", speaker, text, locale, "CHAPTER_4", [], context)


func run(tree: SceneTree) -> Dictionary:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--surface-resume-phase="):
			return await _process_world(tree, arg.trim_prefix("--surface-resume-phase="))
	return _capture_cases()


func _capture_cases() -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		_case(locale)
		_dynamic(locale)
	SaveManager.delete_test_slot(SLOT)
	print("NOTEBOOK_SURFACE_RESUME_CHECKS: ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _process_world(tree: SceneTree, phase: String) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	TranslationServer.set_locale("ko-KR")
	var path := "user://__test_surface_process_expected.json"
	var target := ""
	var expected := {}
	if phase == "seed":
		var state: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
		state.meta_progress.dialogue_history = ARCHIVE.create()
		_install(state)
		_expect(BasementSession.new(GameState, SaveManager, SLOT).initialize().ok, "save actual F3 source")
		_expect(SaveManager.capture_f3_reselect(SLOT).ok, "capture actual F3 replay boundary")
		var created := SaveManager.create_f3_reselect_slot(SLOT)
		_expect(created.ok, "create actual replay copy")
		if not created.ok: return {"ok": false, "errors": errors}
		target = created.slot_id
	elif phase == "resume":
		expected = JSON.parse_string(FileAccess.get_file_as_string(path))
		target = expected.slot
		_expect(int(expected.pid) != OS.get_process_id(), "reopen in a distinct OS process")
	else: return {"ok": false, "errors": ["Unknown surface process phase"]}
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(target).ok, "install actual replay file")
	var host = tree.current_scene
	host._launch_campaign(target)
	for frame in range(6): await tree.process_frame
	var view = host._prologue
	_expect(not view._dialogue_active and not view._modal_active, "world visible without replaying source feedback")
	_expect(view._notebook_surface_allowed(), "actual visible boards committed")
	var snapshot := GameState.get_snapshot()
	_expect(RECEIPT.valid(snapshot.loop_state.event_local_states.get(RECEIPT.KEY)), "actual world has durable receipt")
	if phase == "seed":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "slot": target, "snapshot": snapshot}))
		file.close()
	else:
		_expect(StateSnapshotValidator.same_persisted_value(expected.snapshot, snapshot), "new process preserves entire world, history and receipt")
		_expect(StateSnapshotValidator.same_persisted_value(expected.snapshot, SaveManager.load_slot(target).snapshot), "persisted replay remains identical after process reopen")
		_expect(snapshot.meta_progress.dialogue_history.entries.size() == 3, "exact three actual EDC surfaces, no duplication")
	view.queue_free()
	host._prologue = null
	await tree.process_frame
	if phase == "resume":
		SaveManager.delete_test_slot(target)
		SaveManager.delete_test_slot(SLOT)
		DirAccess.remove_absolute(path)
	print("NOTEBOOK_SURFACE_PROCESS_CHECKS: ", phase, " ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _case(locale: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	var state: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	_install(state)
	var saves := Saves.new()
	var session := Session.new()
	session.saves = saves
	var scope := _scope()
	var view := CAPTURE.new()
	view.begin(scope, GameState.get_snapshot())
	_queue(view, locale)
	var initial := GameState.get_snapshot()
	_expect(view.flush(session, scope), "first visible surface saves")
	var saved := GameState.get_snapshot()
	_validate_state_guard(initial, saved)
	var cursor_anchor := preload("res://scripts/systems/notebook_presentation.gd").anchor(saved)
	_expect(_count() == 1 and RECEIPT.valid(saved.loop_state.event_local_states.get(RECEIPT.KEY)), "observation and receipt saved together")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real slot reload")
	scope = _scope()
	var restored := CAPTURE.new()
	restored.begin(scope, GameState.get_snapshot())
	_queue(restored, locale)
	_expect(restored.flush(session, scope) and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "same language and snapshot adds nothing after recreation")
	var stale := scope.duplicate(true)
	stale.load_epoch = int(stale.load_epoch) + 1
	_expect(not restored.flush(session, stale), "old load scope cannot write")
	var changed_scope := scope.duplicate(true)
	changed_scope.node = "F3"
	restored.begin(changed_scope, GameState.get_snapshot())
	_queue(restored, locale)
	_expect(restored.flush(session, changed_scope) and _count() == 2, "actual new scope is a new visit")
	restored.begin(scope, GameState.get_snapshot())
	_queue(restored, locale)
	_expect(restored.flush(session, scope) and _count() == 3, "returning to earlier scope is not global dedup")
	_queue(restored, locale, true)
	_expect(restored.flush(session, scope) and _count() == 4, "explicit fresh attempt stays a new occurrence")
	var before_fail := GameState.get_snapshot()
	var bytes := _bytes()
	_queue(restored, locale, true)
	saves.reject = true
	_expect(not restored.flush(session, scope), "failed save rejected")
	_expect(StateSnapshotValidator.same_persisted_value(before_fail, GameState.get_snapshot()) and bytes == _bytes(), "failure rolls back both history and receipt")
	_expect(not restored.flush(session, scope), "no implicit retry after failure")
	saves.reject = false
	saves.lose_ack = true
	_expect(restored.flush(session, scope, true) and _count() == 5, "lost acknowledgement recovers atomic history and receipt once")
	saves.lose_ack = false
	var recovered := GameState.get_snapshot()
	var next := CAPTURE.new()
	next.begin(scope, recovered)
	_queue(next, locale)
	_expect(next.flush(session, scope) and StateSnapshotValidator.same_persisted_value(recovered, GameState.get_snapshot()), "retry receipt survives recreation")
	var other_locale := "en-US" if locale.begins_with("ko") else "ko-KR"
	var translated := CAPTURE.new()
	translated.begin(scope, GameState.get_snapshot())
	_queue(translated, other_locale)
	_expect(translated.flush(session, scope) and _count() == 6, "new displayed translation is retained separately")
	var after_translation := GameState.get_snapshot()
	var again := CAPTURE.new()
	again.begin(scope, after_translation)
	_queue(again, other_locale)
	_expect(again.flush(session, scope) and StateSnapshotValidator.same_persisted_value(after_translation, GameState.get_snapshot()), "same translated display is idempotent")
	_expect(preload("res://scripts/systems/notebook_presentation.gd").anchor(GameState.get_snapshot()) == cursor_anchor, "receipt changes do not invalidate game presentation anchors")
	var foreign := scope.duplicate(true)
	foreign.slot = SLOT + "_other"
	_expect(RECEIPT.read(GameState.get_snapshot(), foreign).is_empty(), "receipt never crosses slot identity")
	foreign = scope.duplicate(true)
	foreign.branch = ARCHIVE.new_uid()
	_expect(RECEIPT.read(GameState.get_snapshot(), foreign).is_empty(), "receipt never crosses branch identity")
	var old := GameState.get_snapshot()
	old.loop_state.event_local_states.erase(RECEIPT.KEY)
	_install(old)
	var legacy := CAPTURE.new()
	legacy.begin(_scope(), GameState.get_snapshot())
	_queue(legacy, locale)
	_expect(legacy.flush(session, _scope()) and _count() == 7, "old save without receipt honestly records visible surface")
	var corrupt: Dictionary = GameState.get_snapshot().loop_state.event_local_states[RECEIPT.KEY].duplicate(true)
	corrupt.schema_version = 2
	_expect(not RECEIPT.valid(corrupt), "future receipt schema is not silently accepted")
	var invalid := GameState.get_snapshot()
	invalid.loop_state.event_local_states[RECEIPT.KEY] = corrupt
	var valid_before := GameState.get_snapshot()
	_expect(not StateWriter.new(GameState).install_snapshot(invalid, GameState.revision, &"SURFACE_FUTURE").ok and StateSnapshotValidator.same_persisted_value(valid_before, GameState.get_snapshot()), "snapshot writer rejects future receipt without changing state")
	corrupt = GameState.get_snapshot().loop_state.event_local_states[RECEIPT.KEY].duplicate(true)
	corrupt.receipts[corrupt.receipts.keys()[0]].presentation_token = "bad"
	_expect(not RECEIPT.valid(corrupt), "malformed identity is rejected")
	var request: Dictionary = legacy.requests[ID].duplicate(true)
	request.context.surface_receipt.key = "0".repeat(64)
	var before_bad := GameState.get_snapshot()
	var before_bad_bytes := _bytes()
	_expect(not session.record_viewed_line(request.speaker, request.text, request.locale, request.context).ok, "mismatched displayed fingerprint rejected")
	_expect(StateSnapshotValidator.same_persisted_value(before_bad, GameState.get_snapshot()) and before_bad_bytes == _bytes(), "bad receipt cannot install history or save")
	saves.free()


func _validate_state_guard(before: Dictionary, after: Dictionary) -> void:
	var assertions := preload("res://scripts/tests/notebook_state_assertions.gd")
	_expect(assertions.same_surface_gameplay(before, after), "surface state guard accepts backed receipt")
	for kind in ["knowledge", "inventory", "relationship", "cursor", "archive", "receipt"]:
		var changed := after.duplicate(true)
		match kind:
			"knowledge": changed.meta_progress.knowledge_entries.TEST_FALSE_FACT = true
			"inventory": changed.loop_state.inventory.append("TEST_FALSE_ITEM")
			"relationship": changed.meta_progress.servants.mara1.bond += 1
			"cursor": changed.loop_state.event_local_states.NOTEBOOK_PRESENTATION = {}
			"archive": changed.meta_progress.dialogue_history.next_sequence += 1
			"receipt":
				var receipts: Dictionary = changed.loop_state.event_local_states[RECEIPT.KEY].receipts
				receipts[receipts.keys()[0]].presentation_token = ARCHIVE.new_uid()
		_expect(not assertions.same_surface_gameplay(before, changed), "surface state guard rejects " + kind)


func _dynamic(locale: String) -> void:
	var state: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	_install(state)
	var session := Session.new()
	session.saves = SaveManager
	var scope := _scope()
	var puzzles := preload("res://scripts/systems/notebook_puzzle_surfaces.gd")
	for rotation in [0, 90]:
		var descriptor: Dictionary = puzzles.trace({"rotation": rotation, "flipped": false, "anchored": false, "path": []}, true)
		var row := CONTENT.definition(descriptor.content_id, 1)
		var shown := CONTENT.presentation(descriptor, locale)
		var context := {"node_id": row.node_ids[0], "chapter_id": "CHAPTER_2", "location_id": scope.location}
		var view := CAPTURE.new()
		view.begin(scope, GameState.get_snapshot())
		view.queue_descriptor(descriptor, shown.text, locale, context)
		_expect(view.flush(session, scope) and _count() == (1 if rotation == 0 else 2), "changed visible values create distinct observations")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "dynamic surface reload")
		scope = _scope()
		var saved := GameState.get_snapshot()
		var again := CAPTURE.new()
		again.begin(scope, saved)
		again.queue_descriptor(descriptor, shown.text, locale, context)
		_expect(again.flush(session, scope) and StateSnapshotValidator.same_persisted_value(saved, GameState.get_snapshot()), "JSON numeric roundtrip retains exact dynamic observation")
	# One live visit can switch back to a value already captured earlier.
	var toggled := CAPTURE.new()
	for rotation in [0, 90, 0]:
		toggled.begin(scope, GameState.get_snapshot())
		var descriptor: Dictionary = puzzles.trace({"rotation": rotation, "flipped": false, "anchored": false, "path": []}, true)
		var row := CONTENT.definition(descriptor.content_id, 1)
		var shown := CONTENT.presentation(descriptor, locale)
		toggled.queue_descriptor(descriptor, shown.text, locale, {"node_id": row.node_ids[0], "chapter_id": "CHAPTER_2", "location_id": scope.location})
		_expect(toggled.flush(session, scope), "returning visible value refreshes current batch")
	var before_reopen := GameState.get_snapshot()
	var final_descriptor: Dictionary = puzzles.trace({"rotation": 0, "flipped": false, "anchored": false, "path": []}, true)
	var final_row := CONTENT.definition(final_descriptor.content_id, 1)
	var final_shown := CONTENT.presentation(final_descriptor, locale)
	var reopened := CAPTURE.new()
	reopened.begin(scope, before_reopen)
	reopened.queue_descriptor(final_descriptor, final_shown.text, locale, {"node_id": final_row.node_ids[0], "chapter_id": "CHAPTER_2", "location_id": scope.location})
	_expect(reopened.flush(session, scope) and StateSnapshotValidator.same_persisted_value(before_reopen, GameState.get_snapshot()), "restored A-B-A value does not append again")


func _scope() -> Dictionary:
	var state := GameState.get_snapshot()
	return {"namespace": "full", "slot": SLOT, "origin": state.meta_progress.dialogue_history.source_origin_id,
		"branch": state.meta_progress.dialogue_history.branch_id, "location": state.loop_state.location_id,
		"node": "EDC", "day": state.loop_state.day_index, "load_epoch": GameState.load_epoch}


func _queue(view: RefCounted, locale: String, fresh: bool = false) -> void:
	var definition := CONTENT.definition(ID, 1)
	var segments := {}
	for id in definition.visible_segment_ids: segments[id] = {}
	var descriptor := CONTENT.descriptor(ID, 1, segments)
	var shown := CONTENT.presentation(descriptor, locale)
	_expect(shown.ok, "authored presentation exists")
	view.queue(ID, shown.text, locale, {"node_id": "EDC", "chapter_id": "CHAPTER_4", "location_id": GameState.get_value("loop_state.location_id")}, fresh)


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("SURFACE_FIXTURE_%d" % serial)).ok, "install fixture")


func _count() -> int:
	return GameState.get_value("meta_progress.dialogue_history.entries").size()


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.get_save_root().path_join(SLOT).path_join("progress.json"))


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		print("SURFACE_RESUME_ASSERT: ", message)
