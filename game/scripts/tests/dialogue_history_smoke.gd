extends RefCounted

const CONTEXT := preload("res://scripts/systems/dialogue_history_context.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CHAPTER := preload("res://scripts/systems/chapter_one_session.gd")
const MIRROR := preload("res://scripts/systems/black_mirror_session.gd")
const BASEMENT := preload("res://scripts/systems/basement_session.gd")
const VIEW := preload("res://scripts/prologue/prologue_controller.gd")
const SLOT := "__test_dialogue_history"
var errors := PackedStringArray()


func _entry(sequence: int, text: String, chapter: Variant = null) -> Dictionary:
	var entry := {"sequence": sequence, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "Narrator", "text": text}, "viewed_locale": "en-US"}
	if chapter != null:
		entry["chapter_id"] = chapter
	return entry


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var repository := DialogueRepository.new()
	_expect(repository.is_ready(), "localized catalogs are ready")
	for language in ["ko-KR", "en-US"]:
		for suffix in ["ALL", "PROLOGUE", "1", "2", "3", "4", "LEGACY"]:
			var text := repository.get_text(StringName("CH1_HISTORY_CHAPTER_" + suffix), language)
			_expect(not text.is_empty() and not text.begins_with("["), "translated chapter label: " + suffix + language)
	var history := {"next_sequence": 4, "entries": [_entry(0, "Old line"), _entry(1, "Unknown chapter", "FUTURE_PRIVATE"), _entry(2, "Known line", "CHAPTER_1"), _entry(3, "Bad variables")]}
	history.entries[3].variables = {}
	var unchanged := history.duplicate(true)
	var rendered := repository.render_history(history, "en-US")
	_expect(not rendered.ok and rendered.entries.size() == 3, "partial error preserves three valid records")
	_expect(rendered.entries[0].chapter_id == "LEGACY" and rendered.entries[1].chapter_id == "LEGACY", "missing and unknown chapters remain reachable")
	_expect(history == unchanged, "rendering never rewrites source history")
	for invalid in [7, {}, []]:
		var result := repository.render_history({"entries": [_entry(0, "Malformed classification", invalid)]}, "en-US")
		_expect(result.ok and result.entries[0].chapter_id == "LEGACY", "invalid chapter metadata has a safe display fallback")

	var view := VIEW.new()
	view.configure_session(SLOT, "P1_ENTRY", true)
	tree.root.add_child(view)
	view._dismiss_dialogue_for_test()
	var before_ui := GameState.get_snapshot()
	view._show_history_result(rendered)
	await tree.process_frame
	await tree.process_frame
	var body := view._modal_body.find_child("HistoryTranscript", true, false) as Label
	_expect(body != null and body.text.contains("Old line") and body.text.contains("Known line"), "All displays legacy and known entries")
	_expect(body.text.contains(view._dialogue_ui_text("CH1_HISTORY_READ_ERROR")), "partial warning remains alongside valid content")
	_expect(view._modal_body.find_child("HistoryRetry", true, false) != null, "partial errors offer retry")
	var buttons := view._modal_body.get_node("HistoryChapterButtons")
	_expect(buttons.get_child_count() == 3 and not buttons.has_node("HistoryChapter_CHAPTER_4"), "future and empty chapter filters are hidden")
	var legacy := buttons.get_node("HistoryChapter_LEGACY") as Button
	legacy.pressed.emit()
	_expect(body.text.contains("Unknown chapter") and not body.text.contains("Known line"), "legacy filter shows unclassified records")
	_expect(legacy.button_pressed, "selection has a real toggle state")
	view._close_modal()
	view._show_history_result(rendered)
	await tree.process_frame
	await tree.process_frame
	_expect(view._history_selected == "LEGACY", "reopening restores selected filter")
	_expect(tree.root.gui_get_focus_owner().name == "HistoryChapter_LEGACY", "reopening focuses enabled selected filter")
	view._close_modal()
	view._show_history_result({"ok": true, "entries": []})
	await tree.process_frame
	await tree.process_frame
	_expect(tree.root.gui_get_focus_owner().name == "HistoryClose", "empty history focuses Close")
	_expect((view._modal_body.find_child("HistoryTranscript", true, false) as Label).text == view._dialogue_ui_text("CH1_HISTORY_EMPTY"), "empty history is distinct from errors")
	view._close_modal()
	view._show_history_result({"ok": false, "entries": []})
	_expect((view._modal_body.find_child("HistoryTranscript", true, false) as Label).text == view._dialogue_ui_text("CH1_HISTORY_READ_ERROR"), "all-invalid history is not empty")
	view._close_modal()
	_expect(GameState.get_snapshot() == before_ui, "history filters and errors leave gameplay and history unchanged")
	var long_history := {"entries": []}
	for index in range(80):
		long_history.entries.append(_entry(index, "Long history line %d. A recorded observation remains available." % index, "CHAPTER_1"))
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		view._reading_text_scale = 2.0
		view._show_history_result(repository.render_history(long_history, language))
		await tree.process_frame
		await tree.process_frame
		var scroll := view._history_modal_scroll()
		_expect(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.size.y, "long history has a scrollable viewport")
		scroll.scroll_vertical = 123
		view._close_modal()
		view._show_history_result(repository.render_history(long_history, language))
		await tree.process_frame
		await tree.process_frame
		_expect(view._history_modal_scroll().scroll_vertical == 123, "scroll survives reopening: " + language)
		_expect(view._modal_body.get_node("HistoryChapterButtons").columns == 2, "large text uses wrapped chapter controls")
		var close := view._modal_body.get_node("HistoryClose") as Button
		_expect(view._modal_panel.get_global_rect().encloses(close.get_global_rect()), "large-text Close stays inside history panel")
		view._close_modal()
	view.queue_free()
	await tree.process_frame

	var catalog := CHECKPOINTS.new()
	var cases := {"A1":"CHAPTER_1", "J3":"CHAPTER_2", "D4":"CHAPTER_2", "D5":"CHAPTER_3", "D6":"CHAPTER_3", "J4":"CHAPTER_3", "E6":"CHAPTER_3", "F0_A":"CHAPTER_4", "F2":"CHAPTER_4", "EDR_FIELD_NOTEBOOK":"CHAPTER_4"}
	for node_id in cases:
		var loaded := catalog.snapshot_for(node_id)
		_expect(loaded.get("ok", false), "checkpoint loads: " + node_id)
		if not loaded.get("ok", false):
			continue
		_expect(StateWriter.new(GameState).install_snapshot(loaded.snapshot, GameState.revision, &"HISTORY_TEST_SEED").ok, "checkpoint installs")
		var session: ChapterOneSession = _session(int(loaded.snapshot.meta_progress.journal_stage))
		_expect(session.history_chapter_id() == cases[node_id], "source stage maps to story chapter: " + node_id)
	_expect(CONTEXT.chapter_for_stage("UNRECOGNIZED") == "LEGACY", "unknown stages do not invent a chapter")

	for pair in [["D4", "D5", "CHAPTER_2"], ["E6", "F0_A", "CHAPTER_3"], ["J3", "D_SLEEP", "CHAPTER_2"]]:
		var source := catalog.snapshot_for(pair[0])
		var next := catalog.snapshot_for(pair[1])
		StateWriter.new(GameState).install_snapshot(source.snapshot, GameState.revision, &"HISTORY_BOUNDARY_SEED")
		var session: ChapterOneSession = _session(int(source.snapshot.meta_progress.journal_stage))
		var committed: Dictionary = session._commit(next.snapshot, "Boundary record")
		_expect(committed.get("ok", false), "boundary event saves: " + pair[0])
		if not committed.get("ok", false):
			continue
		_expect(committed.history_context.chapter_id == pair[2], "result captures source chapter before advancement")
		_expect(session.record_viewed_line("Narrator", "Boundary record", "en-US", committed.history_context).ok, "record uses frozen event context")
		_expect(GameState.get_value(&"meta_progress.dialogue_history").entries.back().chapter_id == pair[2], "record not reclassified using advanced state")
		_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "boundary history reloads")
		var resumed: Dictionary = session.initialize()
		_expect(resumed.get("ok", false) and resumed.get("history_context", {}).get("chapter_id") == pair[2], "resumed feedback preserves original chapter")

	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors}


func _session(journal: int) -> ChapterOneSession:
	if journal >= 3:
		return BASEMENT.new(GameState, SaveManager, SLOT)
	if journal >= 2:
		return MIRROR.new(GameState, SaveManager, SLOT)
	return CHAPTER.new(GameState, SaveManager, SLOT)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
