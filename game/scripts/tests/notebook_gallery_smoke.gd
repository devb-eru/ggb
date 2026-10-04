extends RefCounted

const HOST := preload("res://scripts/systems/notebook_gallery_host.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const VIEWS := preload("res://scripts/systems/notebook_view_store.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const TITLE := preload("res://scenes/ui/start_screen.tscn")
const BASEMENT := preload("res://scripts/chapters/basement_controller.gd")
const SLOT := "__test_notebook_gallery"
var errors := PackedStringArray()
var checks := 0
var root_path := "user://__test_notebook_gallery_%d" % Time.get_ticks_usec()
var serial := 0

class FailedViews extends VIEWS:
	func save_view(_scope: Dictionary, _frontier: Dictionary, _state: Dictionary) -> Dictionary:
		return {"ok": false, "error_id": "TEST_VIEW_WRITE"}


func run(tree: SceneTree) -> Dictionary:
	var before := GameState.get_snapshot()
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	TranslationServer.set_locale("ko-KR")
	var store := EndingGalleryStore.new(root_path.path_join("ending_gallery"))
	var reality := _fixture("CREDITS_REALITY", "NB_CH1_NOTE_B4")
	var stay := _fixture("CREDITS_STAY", "NB_MIRROR_NOTE_C5_INFO")
	var first := store.capture(reality)
	var second := store.capture(stay)
	_expect(first.ok and second.ok and first.id != second.id, "separate ending payloads captured")
	if first.ok and second.ok:
		var original := _bytes(store)
		await _host(tree, store, first.id, second.id)
		await _title(tree, store)
		await _post_credits(tree, store, reality, first.id)
		_expect(_bytes(store) == original, "all entry points preserve exact gallery bytes and file names")
		await _legacy_and_damage(tree, store, reality)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_install(before)
	_expect(StateSnapshotValidator.same_persisted_value(before, GameState.get_snapshot()), "gallery suite restores caller state")
	print("NOTEBOOK_GALLERY_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _fixture(checkpoint: String, clue: String) -> Dictionary:
	var loaded := CHECKPOINTS.new().snapshot_for(checkpoint)
	_expect(loaded.ok, "completed-ending fixture is valid")
	var state: Dictionary = loaded.snapshot
	var archive := ARCHIVE.create()
	var ledger := KNOWLEDGE.create()
	for index in range(14):
		var observation := _observation("NB_PR_DUTY_1")
		var appended := ARCHIVE.append_observation(archive, observation, int(archive.revision))
		_expect(appended.ok, "fixture dialogue append")
		archive = appended.archive
	var acquired := KNOWLEDGE.acquire(ledger, archive, _observation(clue), ARCHIVE.new_uid())
	_expect(acquired.ok, "fixture captures only its observed clue")
	archive = acquired.archive
	archive = ARCHIVE.set_reference(archive, "comparison", ARCHIVE.make_reference(archive.entries[0], "body"), true, int(archive.revision)).archive
	archive = ARCHIVE.set_reference(archive, "bookmarks", ARCHIVE.make_reference(archive.entries[0], "body"), true, int(archive.revision)).archive
	state.meta_progress.dialogue_history = archive
	state.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = acquired.ledger
	# Fixtures explicitly record these bodies, not an inference from checkpoint progress.
	state.meta_progress.knowledge_entries.erase("chapter_notebook")
	state.meta_progress.knowledge_entries.erase("prologue_notebook")
	_expect(StateSnapshotValidator.new().validate(state).ok, "captured fixture validates")
	return state


func _observation(id: String) -> Dictionary:
	var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var definition := CONTENT.definition(id, 1)
	if not definition.has("node_ids"):
		_expect(false, "missing authored fixture: " + id)
		return {}
	var context := {"node_id": definition.node_ids[0], "location_id": "M1_LIBRARY_OUTER", "chapter_id": "PROLOGUE", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	var result := CONTENT.observe(descriptor, context, shown.speaker, shown.text, "ko-KR", "replay_committed" if definition.disclosure_owner == "event_note_commit" else "displayed")
	_expect(result.ok, "fixture observation")
	return result.observation


func _new_host(tree: SceneTree):
	var host := HOST.new()
	host.view_store = VIEWS.new(root_path.path_join("views"))
	tree.current_scene.add_child(host)
	return host


func _host(tree: SceneTree, store: EndingGalleryStore, first: String, second: String) -> void:
	var owner := Control.new()
	var button := Button.new()
	button.text = "Return target"
	owner.add_child(button)
	tree.current_scene.add_child(owner)
	button.grab_focus()
	var before := GameState.get_snapshot()
	var host = _new_host(tree)
	_expect(host.begin(owner, store, first, "ko-KR", 2.0), "verified gallery host opens")
	_expect(not owner.visible and owner.process_mode == Node.PROCESS_MODE_DISABLED, "owner hidden and disabled during archive view")
	_expect(host._scope.namespace == "gallery" and host._scope.slot == first and host._scope.run_id.contains(first), "archive hash namespaces view and query")
	var other := store.read_entry(second)
	var foreign := ARCHIVE.make_reference(other.state.meta_progress.dialogue_history.entries.back(), "body")
	_expect(not host.model.detail(QUERY.reference_key(foreign), host.model.cache_key()).ok, "other ending is absent even when profile owns both")
	var archive: Dictionary = host._source.meta_progress.dialogue_history
	var archive_before := JSON.stringify(archive)
	var rows: Dictionary = host.model.page({"tab": "dialogue"}, 0, host.model.cache_key())
	_expect(rows.count == 14, "only captured conversations, not current gameplay or all authorship")
	var ref: Dictionary = rows.items[0].reference
	host.panel.set_tab("dialogue")
	host.panel.show_detail(rows.items[0].key)
	await tree.process_frame
	_expect(host.panel.find_child("NotebookReference_bookmarks", true, false) == null, "bookmark editing unavailable in gallery")
	host.panel.reference_requested.emit("bookmarks", ref, false)
	_expect(JSON.stringify(host._source.meta_progress.dialogue_history) == archive_before, "injected bookmark signal cannot mutate capture")
	var basket_before: int = host.model.comparison(host.model.cache_key()).items.size()
	host.panel.find_child("NotebookReference_comparison", true, false).pressed.emit()
	_expect(host.model.comparison(host.model.cache_key()).items.size() == basket_before + 1, "actual temporary comparison button adds only selected observed material")
	host.panel.find_child("NotebookReference_comparison", true, false).pressed.emit()
	_expect(host.model.comparison(host.model.cache_key()).items.size() == basket_before, "actual temporary comparison button removes it again")
	var stale: String = host.model.cache_key()
	_expect(host.model.edit_gallery_comparison(ref, true, stale).ok, "observed material may enter temporary basket")
	_expect(not host.model.edit_gallery_comparison(ref, false, stale).ok, "stale generation cannot edit basket")
	_expect(not host.model.edit_gallery_comparison(foreign, true, host.model.cache_key()).ok, "cross-archive reference rejected")
	var unseen: Dictionary = ref.duplicate()
	unseen.segment_id = "unobserved_back"
	_expect(not host.model.edit_gallery_comparison(unseen, true, host.model.cache_key()).ok, "same observation UID cannot expose an unseen segment")
	for row in rows.items:
		var result: Dictionary = host.model.edit_gallery_comparison(row.reference, true, host.model.cache_key())
		_expect(result.ok or result.get("error_id") == "NB_GALLERY_COMPARISON_LIMIT", "only bounded capacity can stop adding observed material")
	_expect(host.model.comparison(host.model.cache_key()).items.size() == ARCHIVE.COMPARISON_LIMIT, "many-material basket respects existing twelve-material cap")
	host._present({})
	host.panel.find_child("NotebookCompare", true, false).pressed.emit()
	var pair: Array = host.panel.visible_pair()
	_expect(pair.size() == 2 and pair[0] != pair[1] and not pair[1].is_empty(), "basket displays exactly two distinct materials")
	host.panel.find_child("NotebookSwapPair", true, false).pressed.emit()
	_expect(host.panel.visible_pair() == [pair[1], pair[0]], "A/B swap works without puzzle adjudication")
	TranslationServer.set_locale("en-US")
	await tree.process_frame
	await tree.process_frame
	_expect(host.model.comparison(host.model.cache_key()).items.size() == 12 and host._locale == "en-US", "language rebuild keeps session basket in same frozen capture")
	_expect(JSON.stringify(host._source.meta_progress.dialogue_history) == archive_before, "comparison and locale preserve original references and knowledge")
	var clue_key := QUERY.reference_key(ARCHIVE.make_reference(archive.entries.back(), "body"))
	host.panel.set_tab("clues")
	host.panel.show_detail(clue_key)
	host.panel._open_visual(clue_key)
	_expect(host.panel._visual.visible, "archived waveform retains its exact observed visual")
	host.panel._visual.find_child("NotebookVisualIn", true, false).pressed.emit()
	_expect(host.panel._visual._canvas.view.zoom > 1, "archive-only visual may be enlarged without puzzle interaction")
	host.panel._close_visual()
	host.panel.set_tab("dialogue")
	host.panel.show_detail(rows.items[1].key)
	await tree.process_frame
	var view_scope: Dictionary = host._view_scope.duplicate()
	var frontier: Dictionary = host.model.view_frontier()
	var views = host.view_store
	host._remember_view()
	_expect(host._flush_view(), "scoped convenience position can be saved")
	var prefs: Dictionary = views.load_view(view_scope, frontier)
	_expect(prefs.state.general.pair == ["", ""] and not prefs.state.general.comparing, "temporary comparison does not persist in view preferences")
	var held := InputEventKey.new()
	held.keycode = KEY_ENTER
	held.pressed = true
	host._input(held)
	host.request_close()
	_expect(not owner.visible, "held closing key cannot fall through to owner")
	held.pressed = false
	host._input(held)
	host._process(0)
	await tree.process_frame
	_expect(owner.visible and owner.process_mode == Node.PROCESS_MODE_INHERIT and button.has_focus(), "release restores owner and its prior focus")
	host = _new_host(tree)
	_expect(host.begin(owner, store, first, "en-US", 2.0), "same archive reopens")
	for frame in range(3): await tree.process_frame
	_expect(host.model.comparison(host.model.cache_key()).items.size() == 1, "reopening discards temporary basket and uses captured basket")
	_expect(host.panel._selected == rows.items[1].key, "same archive retains last reading location")
	host.view_store = FailedViews.new()
	host._remember_view()
	_expect(not host._flush_view() and not host.panel._notice.text.is_empty(), "failed convenience write is visible and non-blocking")
	host.request_close()
	await tree.process_frame
	_expect(owner.visible, "failed preference write never traps user in archive")
	var sibling: Dictionary = store.read_entry(first).state
	sibling.meta_progress.dialogue_history = ARCHIVE.set_reference(sibling.meta_progress.dialogue_history, "bookmarks", ARCHIVE.make_reference(sibling.meta_progress.dialogue_history.entries[0], "body"), false, int(sibling.meta_progress.dialogue_history.revision)).archive
	var sibling_entry := store.capture(sibling)
	_expect(sibling_entry.ok and sibling_entry.id != first, "different capture can retain identical observation UIDs and origin")
	host = _new_host(tree)
	_expect(host.begin(owner, store, sibling_entry.id, "en-US", 2.0), "same-lineage separate archive opens")
	_expect(host._view_scope != view_scope and rows.items[1].key not in host._view_state.seen, "payload hash isolates same-UID read state, not just different-origin captures")
	host.request_close()
	await tree.process_frame
	# Remove only this test-created sibling so the enclosing original-bytes assertion stays exact.
	DirAccess.remove_absolute(store.root_path.path_join(sibling_entry.id + ".json"))
	host = _new_host(tree)
	_expect(host.begin(owner, store, second, "en-US", 2.0), "different ending opens independently")
	_expect(host._view_scope != view_scope and rows.items[1].key not in host._view_state.seen and host.panel._selected != rows.items[1].key, "no read marker or selection from another ending")
	owner.queue_free()
	await tree.process_frame
	await tree.process_frame
	_expect(not is_instance_valid(host), "destroyed owner closes host without resurrecting gameplay")
	_expect(GameState.get_snapshot() == before, "host lifetime, comparison, and view preferences never mutate GameState")
	var model := QUERY.new()
	var scope := {"namespace": "full", "slot": "slot_01", "run_id": "test", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 0}
	_expect(model.open(archive, _ledger(store, first), scope, "ko-KR").ok and not model.enable_gallery_comparison(), "temporary edit capability cannot be enabled in live scope")


func _ledger(store: EndingGalleryStore, id: String) -> Dictionary:
	return store.read_entry(id).state.meta_progress.knowledge_entries[KNOWLEDGE.KEY]


func _title(tree: SceneTree, store: EndingGalleryStore) -> void:
	var screen := TITLE.instantiate()
	screen.gallery_store = store
	screen.configure_profile_store(AccessibilityProfileStore.new(root_path.path_join("accessibility")))
	tree.current_scene.add_child(screen)
	await tree.process_frame
	screen._profile.text_scale = 2.0
	screen._apply_profile()
	screen._open_gallery()
	await tree.process_frame
	_expect(screen._gallery_notebook_button.is_visible_in_tree(), "title gallery exposes notebook under opt-in")
	var id: String = screen._gallery_entries[screen._gallery_entry_index].id
	screen._gallery_notebook_button.pressed.emit()
	var host = screen._gallery_notebook_host
	_expect(is_instance_valid(host) and host._scope.slot == id and not screen.visible, "title opens selected archive and suspends title")
	if is_instance_valid(host):
		host.request_close()
		await tree.process_frame
		_expect(screen.visible and screen._gallery_controls.visible and screen._gallery_notebook_button.has_focus(), "title close returns to gallery with focused notebook action")
	screen.gallery_store = EndingGalleryStore.new(root_path.path_join("empty"))
	screen._open_gallery()
	_expect(not screen._gallery_notebook_button.visible, "empty gallery has no stale notebook action")
	screen._gallery_notebook_button.pressed.emit()
	_expect(not is_instance_valid(screen._gallery_notebook_host), "empty gallery cannot reuse previous capture")
	screen.queue_free()
	await tree.process_frame


func _post_credits(tree: SceneTree, store: EndingGalleryStore, source: Dictionary, id: String) -> void:
	var state := source.duplicate(true)
	for step in [{"action": "start", "value": null}, {"action": "next", "value": 0}, {"action": "next", "value": 1}, {"action": "finish", "value": null}]:
		var result := EndingCredits.apply(state, step.action, step.value)
		_expect(result.ok, "actual credits rule builds post-credits fixture")
		if not result.ok: return
		state = result.state
	_install(state)
	SaveManager.delete_test_slot(SLOT)
	var session := BasementSession.new(GameState, SaveManager, SLOT)
	var saved: Dictionary = SaveManager.save_snapshot(SLOT, session._save_point(state), GameState.get_snapshot(), GameState.revision, "NB_GALLERY_TEST")
	_expect(saved.ok, "post-credits slot fixture saved")
	var view := BASEMENT.new()
	view.configure_session(SLOT, "ENDING_POST_CREDITS")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	view.session.ending_meta_store = EndingMetaStore.new(store.root_path.get_base_dir())
	_expect(view.session.stage() == "POST_CREDITS", "real controller is in post-credits stage")
	var before := GameState.get_snapshot()
	var path := SaveManager.get_save_root().path_join(SLOT).path_join("progress.json")
	var bytes := FileAccess.get_file_as_bytes(path)
	view._gallery_page(id, 0)
	var button: Button
	for candidate in view._modal_body.find_children("*", "Button", true, false):
		if candidate.text == view.GALLERY_TEXTS.text("notebook_open", TranslationServer.get_locale()): button = candidate
	_expect(button != null, "post-credits gallery page offers actual notebook button")
	if button != null:
		button.pressed.emit()
		var host = view._gallery_notebook_host
		_expect(is_instance_valid(host) and host._scope.slot == id and not view.visible, "post-credits entry opens selected immutable snapshot")
		if is_instance_valid(host):
			host.request_close()
			await tree.process_frame
			await tree.process_frame
			_expect(view.visible and view._modal_active and view._gallery_notebook_host == null, "post-credits close returns to gallery menu")
	_expect(GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(path) == bytes, "post-credits reading changes neither runtime nor slot bytes")
	view._close_modal()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for key in ["create_failed", "load_failed", "copy_entered"]:
			view._show_reselect_notice(key)
			var body: Label = view._modal_body.find_child("ModalBodyText", true, false)
			_expect(view._modal_active and not view._dialogue_active and view._recorded_modal_request.is_empty(), "replay notice bypasses story record and cursor: " + key)
			_expect(body != null and body.text == view.CREDITS_TEXTS.text(key, locale), "replay notice preserves current-language wording: " + key)
			var buttons := view._modal_body.find_children("*", "Button", true, false)
			_expect(buttons.size() == 1 and buttons[0].focus_mode == Control.FOCUS_ALL, "replay notice has one keyboard-accessible close action")
			if buttons.size() == 1: buttons[0].pressed.emit()
			_expect(not view._modal_active and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before) and FileAccess.get_file_as_bytes(path) == bytes, "notice open/close preserves archive, gameplay, cursor, and disk bytes")
	# This fixture has no captured F3 source; exercise the real failed-create path.
	_expect(not SaveManager.load_f3_reselect(SLOT).get("ok", false), "post-credits fixture has no replay source")
	view._create_reselect()
	var failure_body: Label = view._modal_body.find_child("ModalBodyText", true, false)
	_expect(view._modal_active and failure_body != null and failure_body.text == view.CREDITS_TEXTS.text("create_failed", "en-US"), "actual create failure shows the excluded notice")
	view._close_modal()
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), before) and FileAccess.get_file_as_bytes(path) == bytes, "actual failed replay creation adds no unmapped record")
	view.queue_free()
	await tree.process_frame


func _legacy_and_damage(tree: SceneTree, store: EndingGalleryStore, source: Dictionary) -> void:
	var legacy := source.duplicate(true)
	legacy.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	legacy.meta_progress.dialogue_history = {"next_sequence": 8, "entries": [
		{"sequence": 4, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "Narrator", "text": "Preserved original"}, "viewed_locale": "en-US"},
		{"sequence": 7, "line_id": "OLD_UNKNOWN", "speaker_id": "SYSTEM", "chapter_id": "UNKNOWN_OLD", "extra": ["preserve"]},
	]}
	var entry := store.capture(legacy)
	_expect(entry.ok, "legacy gallery capture supported")
	if not entry.ok: return
	var bytes := _bytes(store)
	var owner := Control.new()
	tree.current_scene.add_child(owner)
	var host = _new_host(tree)
	_expect(host.begin(owner, store, entry.id, "en-US", 1.0), "legacy archive adapts in memory after hash verification")
	var page: Dictionary = host.model.page({"tab": "dialogue"}, 0, host.model.cache_key())
	_expect(page.count == 2, "unclassified legacy entry remains alongside readable original")
	var found := false
	for item in page.items:
		var detail: Dictionary = host.model.detail(item.key, host.model.cache_key())
		if detail.get("text", "").contains("Preserved original"): found = true
	_expect(found, "legacy body preserved verbatim")
	var scope: Dictionary = host._view_scope.duplicate()
	var files: Dictionary = host.view_store.paths(scope)
	host.request_close()
	await tree.process_frame
	_expect(_bytes(store) == bytes, "legacy adapter never changes original hash, file, or envelope")
	_write(files.main, JSON.stringify({"version": 999}))
	var future := FileAccess.get_file_as_bytes(files.main)
	host = _new_host(tree)
	_expect(host.begin(owner, store, entry.id, "en-US", 1.0) and not host._view_writable, "future view preferences do not prevent read-only archive access")
	host.request_close()
	await tree.process_frame
	_expect(FileAccess.get_file_as_bytes(files.main) == future, "future convenience version never overwritten")
	_write(files.main, "broken convenience data")
	host = _new_host(tree)
	_expect(host.begin(owner, store, entry.id, "en-US", 1.0), "damaged UI state falls back without dropping records")
	host.request_close()
	await tree.process_frame
	var capture_path := store.root_path.path_join(entry.id + ".json")
	var original := FileAccess.get_file_as_string(capture_path)
	for invalid in ["../progress", "f".repeat(64), ""]:
		host = _new_host(tree)
		_expect(not host.begin(owner, store, invalid, "ko-KR", 1.0) and owner.visible, "invalid or missing archive cannot suspend owner or read live slot")
		host.queue_free()
		await tree.process_frame
	for corrupted in [original.replace("Preserved original", "Tampered original"), "{\"gallery_version\":999}"]:
		_write(capture_path, corrupted)
		host = _new_host(tree)
		_expect(not host.begin(owner, store, entry.id, "ko-KR", 1.0) and owner.visible, "checksum or version failure is rejected before UI suspension")
		_expect(FileAccess.get_file_as_string(capture_path) == corrupted, "read failure never repairs or overwrites original")
		host.queue_free()
		await tree.process_frame
	_write(capture_path, original)
	owner.queue_free()
	await tree.process_frame


func _bytes(store: EndingGalleryStore) -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at(store.root_path):
		result[name] = FileAccess.get_file_as_bytes(store.root_path.path_join(name))
	return result


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "isolated fault fixture opens")
	if file != null:
		file.store_string(text)
		file.close()


func _install(state: Dictionary) -> void:
	serial += 1
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("NB_GALLERY_INSTALL_%d" % serial)).ok, "test snapshot installs through writer")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
