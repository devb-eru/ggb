extends RefCounted

const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const SOURCE := "__test_reselect_presentation"
var errors := PackedStringArray()
var checks := 0
var serial := 0

class RejectGame extends Node:
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if transaction.begins_with("CH1_"): return {"ok": false, "error_ids": ["TEST_RESELECT_ACTION"]}
		return SaveManager.save_snapshot(slot, point, state, revision, transaction)
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for kind in ["dialogue", "modal", "pending", "completed", "no_cursor"]:
			print("RESELECT_CASE: ", locale, " / ", kind)
			await _case(tree, kind)
	SaveManager.delete_test_slot(SOURCE)
	print("NOTEBOOK_RESELECT_PRESENTATION_CHECKS: ", checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _case(tree: SceneTree, kind: String) -> void:
	var host = tree.current_scene
	SaveManager.delete_test_slot(SOURCE)
	var state: Dictionary = CHECKPOINTS.new().snapshot_for("EDC").snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	_install(state)
	var session := BasementSession.new(GameState, SaveManager, SOURCE)
	_expect(session.initialize().ok and SaveManager.capture_f3_reselect(SOURCE).ok, "capture real F3 source")
	var created: Dictionary = SaveManager.create_f3_reselect_slot(SOURCE)
	_expect(created.ok, "create actual replay slot")
	if not created.ok: return
	var target: String = created.slot_id
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(target).ok, "load replay for progress")
	host._launch_campaign(target)
	await _frames(tree)
	var view = host._prologue
	_drain(view)
	if kind == "dialogue":
		view._do("f3_cancel")
		_drain(view)
		view._do("f3_inspect", "wake")
		view._advance_dialogue()
	elif kind != "no_cursor":
		view._confirm_ending("stay")
		if kind == "pending":
			var rejecting := RejectGame.new()
			view.session._save = rejecting
			view._recorded_choice_pressed(view._recorded_modal_request, 1)
			view.session._save = SaveManager
			rejecting.free()
		elif kind == "completed": view._close_modal()
	await _frames(tree)
	var cursor := CURSOR.read(GameState.get_snapshot())
	if kind == "no_cursor":
		_expect(cursor.is_empty() and not view._dialogue_active and not view._modal_active, "new copy without cursor does not replay source feedback")
	else:
		_expect(CURSOR.matches(cursor, GameState.get_snapshot()) and CURSOR.observed(cursor, GameState.get_snapshot()), "fixture has durable observed presentation")
		_expect(cursor.get("phase") == {"dialogue": "reading", "modal": "choosing", "pending": "selection_pending", "completed": "completed"}[kind], "fixture reaches exact pending phase")
	var tracker = view.get_node("PresentationViewTracker")
	var focus: Control = _focus_target(view, kind)
	_expect(focus != null, "fixture has real focus target")
	if focus != null: focus.grab_focus()
	tracker._process(0.01)
	_expect(tracker.flush(), "save reading position in replay scope")
	var position: Dictionary = tracker.saved.duplicate(true)
	var identity: String = tracker.identity
	var expected := GameState.get_snapshot()
	var copy_bytes := _bytes(target)
	var post: Dictionary = CHECKPOINTS.new().snapshot_for("CREDITS_REALITY").snapshot
	post.meta_progress.dialogue_history = ARCHIVE.create()
	for step in [["start", null], ["next", 0], ["next", 1], ["finish", null]]:
		var applied := EndingCredits.apply(post, step[0], step[1])
		_expect(applied.ok, "post-credits fixture follows rules")
		post = applied.state
	_install(post)
	var source_session := BasementSession.new(GameState, SaveManager, SOURCE)
	_expect(source_session.initialize().ok, "save original post-credits progress")
	host._launch_campaign(SOURCE)
	await _frames(tree)
	var original = host._prologue
	_drain(original)
	await _frames(tree)
	var old_tracker = original.get_node("PresentationViewTracker")
	var original_id: int = original.get_instance_id()
	var source_bytes := _bytes(SOURCE)
	var stored_locale := TranslationServer.get_locale()
	if "--reselect-same-locale" not in OS.get_cmdline_user_args():
		TranslationServer.set_locale("en-US" if stored_locale.begins_with("ko") else "ko-KR")
	original._resume_reselect(target)
	_expect(original._modal_active and not original._dialogue_active, "copy notice covers pending gameplay")
	_expect(StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "entry notice neither advances nor discloses")
	_expect(not old_tracker.flush(), "old scope cannot write into replay position")
	if kind == "pending":
		var stale_requests := []
		original.campaign_requested.connect(func(slot: String) -> void: stale_requests.append(slot))
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(target).ok, "external reload invalidates pending notice scope")
		original._close_modal()
		await _frames(tree)
		_expect(stale_requests.is_empty() and host._prologue == original and original._modal_active, "stale notice cannot dispatch after another load")
		_expect(StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "stale notice preserves reloaded state")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SOURCE).ok, "return through a fresh original screen")
		host._launch_campaign(SOURCE)
		await _frames(tree)
		original = host._prologue
		_drain(original)
		await _frames(tree)
		original_id = original.get_instance_id()
		source_bytes = _bytes(SOURCE)
		original._resume_reselect(target)
	var stale_origin: WeakRef = weakref(original)
	original._open_notebook()
	await _frames(tree)
	_expect(original._notebook_is_open(), "unified notebook can overlay the copy notice")
	original._close_modal()
	await _frames(tree)
	_expect(not original._notebook_is_open() and original._modal_active and host._prologue == original, "closing notebook returns to notice instead of dispatching handoff")
	_expect(StateSnapshotValidator.same_persisted_value(expected, GameState.get_snapshot()), "notebook over notice is read-only")
	# Double activation must not expose the destination beneath a pending handoff.
	original._cancel_prologue_modal()
	original._close_modal()
	await tree.process_frame
	view = host._prologue
	_expect(view.get_instance_id() != original_id, "replay uses normal controller initialization")
	tracker = view.get_node("PresentationViewTracker")
	await _frames(tree)
	_expect(view._slot_id == target, "fresh controller owns the replay slot")
	var after := GameState.get_snapshot()
	if kind in ["completed", "no_cursor"]:
		_validate_world_return(expected, after, view)
	else:
		_expect(StateSnapshotValidator.same_persisted_value(expected, after), "pending handoff preserves entire gameplay, history and cursor")
	_expect(_bytes(SOURCE) == source_bytes, "handoff preserves original save bytes")
	var loaded: Dictionary = SaveManager.load_slot(target)
	_expect(loaded.ok and StateSnapshotValidator.same_persisted_value(after, loaded.snapshot), "ordinary initialization saves exactly the restored state")
	var original_header: Dictionary = JSON.parse_string(copy_bytes.get_string_from_utf8()).save_header
	var current_header: Dictionary = loaded.header.duplicate(true) if loaded.ok else {}
	for key in ["transaction_id", "state_revision", "created_at_utc", "updated_at_utc", "checksum"]:
		original_header.erase(key)
		current_header.erase(key)
	_expect(StateSnapshotValidator.same_persisted_value(original_header, current_header), "only ordinary commit metadata changes in replay header; identity and boundary preserved")
	_expect(tracker.live_scope.get("slot") == target and tracker.identity == identity, "fresh tracker restores matching replay surface")
	if kind == "dialogue":
		_expect(view._dialogue_active and view._dialogue_index == int(cursor.index), "exact dialogue index resumes")
		if view._dialogue_active:
			_expect(view._dialogue_lines[view._dialogue_index].presentation_token == cursor.lines[int(cursor.index)].presentation_token, "same dialogue token resumes")
			_expect(view._dialogue_label.text == CURSOR.localized_lines(cursor, TranslationServer.get_locale())[int(cursor.index)].text, "dialogue resumes in current language without changing stored observation")
	elif kind in ["completed", "no_cursor"]:
		_expect(not view._modal_active and not view._dialogue_active, "completed presentation stays closed")
	else:
		_expect(view._modal_active and not view._recorded_modal_request.is_empty(), "pending confirmation resumes")
		if not view._recorded_modal_request.is_empty():
			_expect(view._recorded_modal_request.history_context.presentation_token == cursor.lines[0].presentation_token, "same confirmation token resumes")
			_expect(view._recorded_modal_request.selection_recorded == (kind == "pending"), "pending answer is preserved without automatic execution")
	var captured: Dictionary = tracker._capture(tracker._surface()) if not tracker._surface().is_empty() else {}
	_expect(captured.get("focus") == position.get("focus"), "replay restores prior keyboard focus")
	_expect(tracker.flush(), "reading position remains writable after replay load")
	if view.get_instance_id() != original_id:
		host._on_campaign_requested(SOURCE, stale_origin)
		_expect(host._prologue == view and view._slot_id == target, "stale source cannot switch the replay back")
	if view.get_parent() == host: host.remove_child(view)
	view.queue_free()
	host._prologue = null
	await tree.process_frame
	SaveManager.delete_test_slot(target)
	TranslationServer.set_locale(stored_locale)


func _validate_world_return(before: Dictionary, after: Dictionary, view: Node) -> void:
	var old: Dictionary = before.meta_progress.dialogue_history
	var current: Dictionary = after.meta_progress.dialogue_history
	_expect(current.entries.size() >= old.entries.size(), "world return never deletes history")
	_expect(StateSnapshotValidator.same_persisted_value(old.entries, current.entries.slice(0, old.entries.size())), "world return preserves all prior observations")
	var added: int = current.entries.size() - old.entries.size()
	var normalized := current.duplicate(true)
	normalized.entries = old.entries.duplicate(true)
	normalized.next_sequence -= added
	normalized.revision -= added
	_expect(StateSnapshotValidator.same_persisted_value(old, normalized), "world capture changes only append counters, not pins, links or provenance")
	for entry in current.entries.slice(old.entries.size()):
		for previous in old.entries:
			if previous.get("record_class") != "authored": continue
			var a: Dictionary = previous.observation
			var b: Dictionary = entry.get("observation", {})
			if a.content_id == b.get("content_id") and a.content_version == b.get("content_version") and a.variant_id == b.get("variant_id") and StateSnapshotValidator.same_persisted_value(a.segments, b.get("segments")):
				print("RESELECT_KNOWN_DUPLICATE_SURFACE: ", a.content_id)
				break
		var matched := false
		for key in view._notebook_surfaces.active:
			var request: Dictionary = view._notebook_surfaces.requests[key]
			var observed: Dictionary = CURSOR.CONTENT.observe(request.context.notebook_content, request.context, request.speaker, request.text, request.locale)
			if observed.ok and StateSnapshotValidator.same_persisted_value(entry.get("observation"), observed.observation): matched = true
		_expect(entry.get("record_class") == "authored" and matched, "new observation belongs to an actually displayed destination surface")
	var gameplay := after.duplicate(true)
	gameplay.meta_progress.dialogue_history = old.duplicate(true)
	_expect(StateSnapshotValidator.same_persisted_value(before, gameplay), "completed return changes no gameplay, knowledge or completed cursor")
	print("RESELECT_WORLD_REOBSERVATIONS: ", added, " (separate duplicate-surface audit)")


func _focus_target(view: Node, kind: String) -> Control:
	if kind == "dialogue": return view._dialogue_next
	if kind in ["completed", "no_cursor"]: return view._menu_button
	var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)
	return buttons.back() if not buttons.is_empty() else null


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("RESELECT_FIXTURE_%d" % serial)).ok, "install validated fixture")


func _bytes(slot: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.get_save_root().path_join(slot).path_join("progress.json"))


func _frames(tree: SceneTree) -> void:
	for index in range(6): await tree.process_frame


func _drain(view: Node) -> void:
	for index in range(30):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false, "dialogue drain bounded")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		print("RESELECT_ASSERT: ", message)
