extends RefCounted

const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const VIEWS := [preload("res://scripts/chapters/chapter_one_controller.gd"), preload("res://scripts/chapters/black_mirror_controller.gd"), preload("res://scripts/chapters/basement_controller.gd")]
const SLOT := "__test_notebook_presentation"
const EXPECTED := "user://__test_notebook_presentation_expected.json"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class ControlledSave extends Node:
	var reject := false
	var reject_game := false
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject or (reject_game and transaction.begins_with("CH1_")): return {"ok": false, "error_id": "TEST_CURSOR_SAVE"}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_id": "TEST_CURSOR_ACK"} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var phase := "seed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor-phase="): phase = arg.trim_prefix("--cursor-phase=")
	TranslationServer.set_locale("ko-KR" if phase == "seed" else "en-US")
	if phase == "seed":
		await _cases(tree)
		if not errors.is_empty(): return {"ok": false, "errors": errors}
		_seed("A1")
		var view = _view(tree, 0)
		view._show_dialogue(_lines())
		view._advance_dialogue()
		var expected := {"pid": OS.get_process_id(), "cursor": CURSOR.read(GameState.get_snapshot()), "archive": GameState.get_snapshot().meta_progress.dialogue_history}
		_expect(expected.cursor.index == 1 and expected.cursor.phase == "reading", "second line is durably active")
		var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
		file.store_string(JSON.stringify(expected))
		file.close()
		view.queue_free()
		await tree.process_frame
	elif phase in ["resume", "completed"]:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		_expect(int(expected.pid) != OS.get_process_id(), "resume runs in a distinct OS process")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "real slot reload")
		var before: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
		var view = _view(tree, 0)
		_expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot().meta_progress.dialogue_history), "restart does not append a history line")
		if phase == "resume":
			_expect(view._dialogue_active and view._dialogue_index == 1, "new process restores exact second line")
			_expect(view._dialogue_lines[1].presentation_token == expected.cursor.lines[1].presentation_token, "same display token survives new process")
			_expect(view._dialogue_label.text == CONTENT.presentation(expected.cursor.lines[1].notebook_content, "en-US").text, "exact descriptor restores current language")
			view._advance_dialogue()
			_expect(not view._dialogue_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "explicit close persists completion")
		else:
			_expect(not view._dialogue_active, "completed queue does not replay startup feedback")
			SaveManager.delete_test_slot(SLOT)
		view.queue_free()
		await tree.process_frame
	else:
		_expect(false, "unknown process phase")
	print("NOTEBOOK_PRESENTATION_CHECKS: ", phase, " ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _cases(tree: SceneTree) -> void:
	for family_index in range(VIEWS.size()):
		_seed(["A1", "C0", "D0"][family_index])
		var view = _view(tree, family_index)
		view._show_dialogue(_lines())
		var state := GameState.get_snapshot()
		var cursor := CURSOR.read(state)
		_expect(CURSOR.matches(cursor, state) and CURSOR.observed(cursor, state), "controller persists a matching observed cursor " + str(family_index))
		if cursor.is_empty():
			view.queue_free()
			await tree.process_frame
			return
		_expect(not _has_token(cursor.lines[1].presentation_token), "pending second line is not disclosed")
		var archive: Dictionary = state.meta_progress.dialogue_history.duplicate(true)
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "JSON save reloads cursor")
		view = _view(tree, family_index)
		_expect(view._dialogue_active and view._dialogue_index == 0 and view._dialogue_lines[0].presentation_token == cursor.lines[0].presentation_token, "controller restores frozen line " + str(family_index))
		_expect(StateSnapshotValidator.same_persisted_value(archive, GameState.get_snapshot().meta_progress.dialogue_history), "restore does not append or disclose " + str(family_index))
		view._advance_dialogue()
		_expect(view._dialogue_index == 1 and _has_token(cursor.lines[1].presentation_token), "explicit next discloses exactly next token")
		view._advance_dialogue()
		_expect(not view._dialogue_active and CURSOR.read(GameState.get_snapshot()).phase == "completed", "last line completion durable")
		view.queue_free()
		await tree.process_frame
	await _failures(tree)
	await _storage_boundaries(tree)
	await _continuation(tree)
	await _d5(tree)
	await _handoffs(tree)
	await _silent_movement(tree)
	await _silent_manipulation(tree)


func _silent_movement(tree: SceneTree) -> void:
	var original := TranslationServer.get_locale()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		await _silent_movement_locale(tree)
	TranslationServer.set_locale(original)


func _silent_movement_locale(tree: SceneTree) -> void:
	for family_index in range(VIEWS.size()):
		_seed(["A1", "C0", "D0"][family_index])
		var state := GameState.get_snapshot()
		state.loop_state.location_id = "M1_CENTRAL_HALL"
		serial += 1
		_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("SILENT_MOVE_%d" % serial)).ok, "prepare silent movement location")
		var view = _view(tree, family_index)
		for index in range(20):
			if not view._dialogue_active: break
			view._advance_dialogue()
		_expect(view._notebook_surface_allowed(), "flush source room before silent movement")
		var before: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
		var button = view._hotspot_layer.get_node_or_null("GO_M1_PARLOR")
		_expect(button != null, "silent movement button is exposed")
		var controlled := ControlledSave.new()
		controlled.reject_game = true
		view.session._save = controlled
		var rejected := GameState.get_snapshot()
		if button != null: button.pressed.emit()
		_expect(GameState.get_snapshot() == rejected, "failed silent move keeps world and completed cursor together")
		view.session._save = SaveManager
		controlled.free()
		button = view._hotspot_layer.get_node_or_null("GO_M1_PARLOR")
		if button != null: button.pressed.emit()
		_expect(GameState.get_value("loop_state.location_id", "") == "M1_PARLOR" and not view._dialogue_active, "movement is applied without dialogue")
		_expect(view._notebook_surface_allowed(), "flush destination before reload")
		var completed := CURSOR.read(GameState.get_snapshot())
		_expect(CURSOR.matches(completed, GameState.get_snapshot()) and completed.phase == "completed", "silent movement reanchors the completed cursor atomically")
		for entry in GameState.get_snapshot().meta_progress.dialogue_history.entries.slice(before):
			_expect(entry.get("observation", {}).get("content_id") != "NB_CH1_MOVE", "undisplayed move is not a conversation")
		var archived: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "silent movement reload")
		view = _view(tree, family_index)
		_expect(not view._dialogue_active, "reload cannot reveal suppressed movement feedback: " + str(family_index))
		_expect(StateSnapshotValidator.same_persisted_value(archived, GameState.get_snapshot().meta_progress.dialogue_history), "silent reload cannot append a hidden or replayed line: " + str(family_index))
		view.queue_free()
		await tree.process_frame


func _silent_manipulation(tree: SceneTree) -> void:
	var original := TranslationServer.get_locale()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for stage in ["J1", "B3_A"]:
			_seed(stage)
			var state := GameState.get_snapshot()
			state.loop_state.location_id = "M1_LIBRARY_INNER" if stage == "J1" else "M1_GREAT_CLOCK"
			var session := preload("res://scripts/systems/chapter_one_session.gd").new(GameState, SaveManager, SLOT)
			var local := session.local_state(state)
			local.inspected = ["desk"]
			local.edgar_state = "absent"
			local.j1_front = [false, false, false]
			local.rubbed = preload("res://data/puzzles/puzzle_clock_network.tres").CLOCKS.duplicate()
			local.board.library_back = false
			state.loop_state.event_local_states.CHAPTER_ONE = local
			serial += 1
			_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("SILENT_PUZZLE_%d" % serial)).ok, "prepare silent manipulation")
			var view = _view(tree, 0)
			for index in range(20):
				if not view._dialogue_active: break
				view._advance_dialogue()
			_expect(view._notebook_surface_allowed(), "initial puzzle disclosure")
			var start: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
			var button = view._hotspot_layer.get_node_or_null("J1_FLIP_0" if stage == "J1" else "B3_FLIP")
			_expect(button != null, "silent manipulation button exists")
			if button != null: button.pressed.emit()
			_expect(not view._dialogue_active, "piece flip is not a conversation")
			_expect(view.session.local_state().j1_front[0] if stage == "J1" else view.session.local_state().board.library_back, "silent flip changes the actual puzzle")
			_expect(view._notebook_surface_allowed(), "newly exposed face is observed")
			var added: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries.slice(start)
			_expect(not added.is_empty(), "silent puzzle still records newly displayed material")
			for entry in added:
				_expect(entry.get("observation", {}).get("producer_id") != "NP04", "silent flip cannot append a spoken line")
			var archive: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
			view.queue_free()
			await tree.process_frame
			_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "silent manipulation reload")
			view = _view(tree, 0)
			_expect(not view._dialogue_active and StateSnapshotValidator.same_persisted_value(archive, GameState.get_snapshot().meta_progress.dialogue_history), "silent manipulation restart cannot repeat old dialogue")
			view.queue_free()
			await tree.process_frame
	TranslationServer.set_locale(original)


func _failures(tree: SceneTree) -> void:
	_seed("A1")
	var view = _view(tree, 0)
	view._show_dialogue(_lines())
	var original := GameState.get_snapshot()
	var controlled := ControlledSave.new()
	controlled.reject = true
	view.session._save = controlled
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == original and view._history_recorded_index == 0, "failed next save rolls back both cursor and history")
	_expect(view._dialogue_active and view._dialogue_index == 1, "visible failed line remains for explicit retry")
	controlled.reject = false
	controlled.lose_ack = true
	_expect(view._record_current_history_line(), "lost acknowledgement confirms exact combined snapshot")
	var after := GameState.get_snapshot()
	_expect(CURSOR.read(after).index == 1 and after.meta_progress.dialogue_history.entries.size() == original.meta_progress.dialogue_history.entries.size() + 1, "retry writes one line only")
	controlled.reject = true
	view._advance_dialogue()
	_expect(view._dialogue_active and GameState.get_snapshot() == after, "failed completed save cannot close queue")
	view.session._save = SaveManager
	controlled.free()
	var raw: Dictionary = JSON.parse_string(JSON.stringify(CURSOR.read(after)))
	_expect(CURSOR.valid(raw), "JSON integral float indices supported")
	for key in ["index", "family", "after", "lines"]:
		var corrupt: Dictionary = raw.duplicate(true)
		corrupt[key] = -99 if key == "index" else {"unexpected": true}
		_expect(not CURSOR.valid(corrupt), "invalid cursor field rejected: " + key)
	for key in ["portrait", "audio_cue", "d5_focus_allowed", "observed_fact_ids"]:
		var corrupt: Dictionary = raw.duplicate(true)
		corrupt.lines[0][key] = {"invalid": true}
		_expect(not CURSOR.valid(corrupt), "invalid presentation metadata rejected: " + key)
	var oversized: Dictionary = raw.duplicate(true)
	oversized.lines = []
	for index in range(40):
		var line: Dictionary = raw.lines[0].duplicate(true)
		line.presentation_token = ARCHIVE.new_uid()
		line.history_context.presentation_token = line.presentation_token
		line.text = "가".repeat(10000)
		oversized.lines.append(line)
	_expect(JSON.stringify(oversized).length() < 1048576 and not CURSOR.valid(oversized), "UTF-8 byte limit applies to multibyte text, not character count")
	var changed := after.duplicate(true)
	changed.loop_state.day_index += 1
	_expect(not CURSOR.matches(raw, changed), "changed world invalidates cursor")
	changed = after.duplicate(true)
	changed.meta_progress.dialogue_history = preload("res://scripts/systems/notebook_rollout.gd").fork_history(changed.meta_progress.dialogue_history)
	_expect(not CURSOR.matches(raw, changed), "different branch invalidates cursor")
	CURSOR.carry(changed, after)
	_expect(CURSOR.matches(CURSOR.read(changed), changed), "explicit verified branch carry rebinds identity")
	_expect(CURSOR.read({"loop_state": 3}).is_empty(), "malformed loop root is safely rejected")
	_expect(CURSOR.read({"loop_state": {"event_local_states": []}}).is_empty(), "malformed local root is safely rejected")
	_expect(not CURSOR.valid_route({"method": "queue_free", "args": []}), "arbitrary continuation not deserializable")
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "reload creates new load epoch")
	var loaded := GameState.get_snapshot()
	view._advance_dialogue()
	_expect(GameState.get_snapshot() == loaded and view._dialogue_active, "stale controller callback cannot advance loaded slot")
	view.queue_free()
	await tree.process_frame


func _continuation(tree: SceneTree) -> void:
	_seed("B3_B")
	var view = _view(tree, 0)
	view._read_clock_hint(0)
	var cursor := CURSOR.read(GameState.get_snapshot())
	_expect(cursor.after == {"method": "_show_clock_hint_menu", "args": [1]}, "named bounded hint continuation captured")
	var pending := CURSOR.create(GameState.get_snapshot(), cursor.family, cursor.lines, cursor.index, cursor.locale, cursor.after, "finish_pending")
	_expect(WRITER.save_cursor(GameState, SaveManager, SLOT, "SAVE_CAMPAIGN_PROGRESS", pending.value).ok, "pending user continuation persists")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "continuation reload")
	view = _view(tree, 0)
	_expect(view._dialogue_active and not view._modal_active, "restore never autoexecutes continuation")
	view._advance_dialogue()
	_expect(not view._dialogue_active and view._modal_active, "explicit next dispatches original hint menu")
	view.queue_free()
	await tree.process_frame


func _storage_boundaries(tree: SceneTree) -> void:
	_seed("A1")
	var view = _view(tree, 0)
	view._show_dialogue(_lines())
	var state := GameState.get_snapshot()
	var cursor := CURSOR.read(state)
	var path := SaveManager.get_save_root().path_join(SLOT).path_join("progress.json")
	var backup := path.get_base_dir().path_join("progress.bak.json")
	var original := FileAccess.get_file_as_bytes(path)
	var document: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	var future: Dictionary = document.duplicate(true)
	future.state.loop_state.event_local_states[CURSOR.KEY].schema_version = CURSOR.VERSION + 1
	_write_bytes(backup, original)
	_write_document(path, future)
	var future_bytes := FileAccess.get_file_as_bytes(path)
	_expect(SaveManager.load_slot(SLOT).get("error_id") == &"ERR_SAVE_FUTURE_SCHEMA", "future cursor cannot fall back to older backup")
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", state, GameState.revision, "TEST_FUTURE_CURSOR").ok, "future cursor cannot be overwritten")
	_expect(FileAccess.get_file_as_bytes(path) == future_bytes and FileAccess.get_file_as_bytes(backup) == original, "future primary and backup bytes preserved")
	_write_bytes(path, original)
	_write_bytes(backup, future_bytes)
	_expect(not SaveManager.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", state, GameState.revision, "TEST_FUTURE_CURSOR_BACKUP").ok, "future cursor backup cannot be overwritten")
	_expect(FileAccess.get_file_as_bytes(backup) == future_bytes, "future backup exact bytes preserved")
	_write_bytes(backup, original)
	_write_bytes(path, "broken main".to_utf8_buffer())
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "valid backup recovers after bad primary")
	var restored := GameState.get_snapshot()
	var rebased := CURSOR.read(restored)
	_expect(CURSOR.matches(rebased, restored) and CURSOR.observed(rebased, restored), "backup branch retains valid same-line resume")
	_expect(rebased.branch_id != cursor.branch_id and rebased.source_origin_id == cursor.source_origin_id and StateSnapshotValidator.same_persisted_value({"lines": rebased.lines}, {"lines": cursor.lines}), "backup forks branch without reissuing frozen tokens")
	view = _view(tree, 0)
	_expect(view._dialogue_active and view._dialogue_lines[0].presentation_token == cursor.lines[0].presentation_token, "recovered backup restores original displayed line")
	view.queue_free()
	await tree.process_frame


func _write_document(path: String, document: Dictionary) -> void:
	document.save_header.checksum = ""
	document = SaveManager._canonicalize(document)
	document.save_header.checksum = JSON.stringify(document, "\t", false).sha256_text()
	_write_bytes(path, JSON.stringify(document, "\t", false).to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _d5(tree: SceneTree) -> void:
	_seed("D5")
	var view = _view(tree, 2)
	view._dismiss_dialogue_for_test()
	view._show_full_fracture_transition()
	var original := CURSOR.read(GameState.get_snapshot())
	_expect(original.get("after") == {"method": "_do", "args": ["d_fracture", null, false]}, "D5 continuation captured")
	_expect(view.session.act("d5_focus", "MARA2").ok, "D5 focus can change during dialogue")
	var cursor := CURSOR.read(GameState.get_snapshot())
	_expect(CURSOR.matches(cursor, GameState.get_snapshot()) and cursor.lines == original.lines, "D5 focus atomically preserves frozen dialogue and new world anchor")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "D5 reload")
	view = _view(tree, 2)
	_expect(view._dialogue_active and view._dialogue_lines[0].presentation_token == original.lines[0].presentation_token and view.session.stage() == "D5", "D5 resumes without executing fracture")
	var controlled := ControlledSave.new()
	controlled.reject_game = true
	view.session._save = controlled
	for index in range(view._dialogue_lines.size()): view._advance_dialogue()
	_expect(view.session.stage() == "D5" and CURSOR.read(GameState.get_snapshot()).phase == "finish_pending", "failed continuation keeps pending cursor and unadvanced world together")
	view.session._save = SaveManager
	controlled.free()
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "failed continuation restart")
	view = _view(tree, 2)
	_expect(view._dialogue_active and view._dialogue_index == view._dialogue_lines.size() - 1 and view.session.stage() == "D5", "pending final action awaits explicit user retry")
	view._advance_dialogue()
	_expect(view.session.stage() == "D6" and CURSOR.read(GameState.get_snapshot()).phase == "completed", "successful continuation and completed cursor commit atomically")
	view.queue_free()
	await tree.process_frame
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "successful continuation restart")
	view = _view(tree, 2)
	_expect(view.session.stage() == "D6" and not view._dialogue_active, "committed action does not replay prior dialogue or execute twice")
	view.queue_free()
	await tree.process_frame


func _handoffs(tree: SceneTree) -> void:
	for index in range(2):
		_seed(["C_SLEEP", "D_SLEEP"][index])
		var sparse := GameState.get_snapshot()
		sparse.loop_state.event_local_states.erase("BLACK_MIRROR" if index == 0 else "BASEMENT")
		_expect(StateWriter.new(GameState).install_snapshot(sparse, GameState.revision, &"CURSOR_HANDOFF_SPARSE").ok, "outgoing state has no next-chapter local fields")
		var view = _view(tree, index)
		view._show_dialogue(_lines())
		view._advance_dialogue()
		var cursor := CURSOR.read(GameState.get_snapshot())
		view.queue_free()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "handoff slot reload")
		tree.current_scene._launch_campaign(SLOT)
		view = tree.current_scene._prologue
		_expect(view.get_script() == VIEWS[index] and view._dialogue_active and view._dialogue_index == 1, "campaign launcher retains unfinished outgoing chapter dialogue")
		_expect(view._dialogue_lines[1].presentation_token == cursor.lines[1].presentation_token, "outgoing chapter token retained")
		var archive: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
		view._advance_dialogue()
		await tree.process_frame
		await tree.process_frame
		view = tree.current_scene._prologue
		_expect(view.get_script() == VIEWS[index + 1] and not view._dialogue_active, "completed outgoing dialogue hands off exactly once without replay")
		var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries
		var copies := entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", entry.get("snapshot_context", {})).get("presentation_token") == cursor.lines[1].presentation_token)
		_expect(copies.size() == 1 and entries.size() >= archive.entries.size(), "handoff keeps old observation once; new room labels may be displayed")
		tree.current_scene._on_prologue_return_to_title()
		await tree.process_frame
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "completed handoff reloads again")
		tree.current_scene._launch_campaign(SLOT)
		view = tree.current_scene._prologue
		_expect(view.get_script() == VIEWS[index + 1] and not view._dialogue_active, "second restart does not replay previous chapter after initialization changes")
		tree.current_scene._on_prologue_return_to_title()
		await tree.process_frame


func _seed(checkpoint: String) -> void:
	SaveManager.delete_test_slot(SLOT)
	var fixture := CHECKPOINTS.new().snapshot_for(checkpoint)
	_expect(fixture.ok, "checkpoint " + checkpoint)
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase("notebook_knowledge")
	state.meta_progress.knowledge_entries.erase("chapter_notebook")
	state.loop_state.event_local_states.erase(CURSOR.KEY)
	GameState.reset_for_test()
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("CURSOR_TEST_%d" % serial)).ok, "fixture install")


func _view(tree: SceneTree, index: int):
	var view = VIEWS[index].new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	return view


func _lines() -> Array:
	var result := []
	for id in ["NB_PR_DUTY_1", "NB_PR_DUTY_2"]:
		var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
		var display := CONTENT.presentation(descriptor, TranslationServer.get_locale())
		var definition := CONTENT.definition(id, 1)
		result.append({"speaker": display.speaker, "text": display.text, "notebook_content": descriptor, "history_context": {"node_id": definition.node_ids[0], "chapter_id": "PROLOGUE", "location_id": "M2_BEDROOM"}})
	return result


func _has_token(token: String) -> bool:
	for entry in GameState.get_snapshot().meta_progress.dialogue_history.entries:
		if entry.get("observation", entry.get("snapshot_context", {})).get("presentation_token") == token: return true
	return false


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("CURSOR_ASSERT: ", message)
