extends RefCounted

const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const VIEW := preload("res://scenes/prologue/prologue.tscn")
const SLOT := "__test_notebook_knowledge"
var errors := PackedStringArray()


class LostAcknowledgement:
	extends Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var saved := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_ACK_LOST"]} if saved.ok else saved
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("ko-KR")
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	_validate_revisions()
	_validate_source_retention()
	await _validate_live_retry(tree)
	await _validate_legacy(tree)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors}


func _observe(id: String = "NB_NOTE_P_PULSE", version: int = 1) -> Dictionary:
	var row := CONTENT.definition(id, version)
	var context := {"node_id": row.event_id, "chapter_id": "PROLOGUE", "location_id": "M1_KITCHEN", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	return CONTENT.observe(CONTENT.descriptor(id, version, {"body": {}}), context, row.locales["ko-KR"].speaker, row.locales["ko-KR"].body, "ko-KR", "replay_committed").observation


func _validate_revisions() -> void:
	_expect(StateSnapshotValidator.same_persisted_value({"nested": [[0, 1]]}, {"nested": [[0.0, 1.0]]}), "JSON nested integer representation is semantically identical")
	for different in [{"nested": [[0, 2]]}, {"nested": [[false, 1]]}, {"nested": [[0, 1.000000001]]}, {"nested": [[0]]}, {"extra": 1}]:
		_expect(not StateSnapshotValidator.same_persisted_value({"nested": [[0, 1]]}, different), "disk acknowledgement must match exact values and structure")
	var archive := ARCHIVE.create()
	var ledger := KNOWLEDGE.create()
	var observed := _observe()
	var revision := ARCHIVE.new_uid()
	var acquired := KNOWLEDGE.acquire(ledger, archive, observed, revision)
	_expect(acquired.ok and ledger.revisions.is_empty() and archive.entries.is_empty(), "candidate does not mutate caller state")
	if not acquired.ok: return
	ledger = acquired.ledger
	archive = acquired.archive
	var first: Dictionary = ledger.revisions[0].duplicate(true)
	var repeat := KNOWLEDGE.acquire(ledger, archive, observed, revision)
	_expect(repeat.ok and not repeat.changed and repeat.ledger == ledger and repeat.archive == archive, "same request retry is exact and idempotent")
	var altered := observed.duplicate(true)
	altered.segments[0].captured_text = "different"
	_expect(not KNOWLEDGE.acquire(ledger, archive, altered, revision).ok, "conflicting revision retry rejected")
	_expect(not KNOWLEDGE.acquire(ledger, archive, altered, ARCHIVE.new_uid()).ok, "new request cannot persist false fallback text")
	for invalid in [[], {}, "1", null, true]:
		var malformed := ledger.duplicate(true)
		malformed.schema_version = invalid
		_expect(not KNOWLEDGE.validate(malformed, archive).ok, "malformed schema type rejects without script exception")
		malformed = ledger.duplicate(true)
		malformed.revisions[0].previous_revision_uid = invalid
		_expect(not KNOWLEDGE.validate(malformed, archive).ok, "malformed previous revision type rejects without script exception")
	var missing: Dictionary = first.observation_ref.duplicate(true)
	missing.segment_id = "unread_back"
	_expect(not KNOWLEDGE.acquire(ledger, archive, _observe(), ARCHIVE.new_uid(), [missing]).ok, "unseen source segment never acquired")
	# Test-only new semantic version: old revision must not be replaced or relabeled.
	var next_definition := CONTENT.definition("NB_NOTE_P_PULSE", 1)
	next_definition.locales["ko-KR"].body = "새로 확인한 시험 관찰"
	next_definition.locales["en-US"].body = "A newly verified test observation"
	next_definition.knowledge.epistemic_state = "verified"
	CONTENT._contents["NB_NOTE_P_PULSE"]["2"] = next_definition
	var update := KNOWLEDGE.acquire(ledger, archive, _observe("NB_NOTE_P_PULSE", 2), ARCHIVE.new_uid(), [first.observation_ref])
	_expect(update.ok, "explicit next revision appended")
	if update.ok:
		ledger = update.ledger
		archive = update.archive
		_expect(ledger.revisions[0] == first and ledger.revisions[1].knowledge_uid == first.knowledge_uid and ledger.revisions[1].previous_revision_uid == first.revision_uid, "revision chain retains stable card and immutable previous text/state")
		var entry: Dictionary = ARCHIVE.resolve(archive, first.observation_ref).entry
		_expect(CONTENT.render_entry(entry, "en-US").entry.segments[0].text == "The kitchen's rhythmic vibration", "new version does not leak into previous observation")
		var forked: Dictionary = ARCHIVE.fork(archive).archive
		_expect(KNOWLEDGE.validate(ledger, forked).ok, "branch fork preserves included revision references")
		_expect(not KNOWLEDGE.validate(ledger, ARCHIVE.create()).ok, "references cannot cross into another snapshot")
		var json: Dictionary = JSON.parse_string(JSON.stringify({"ledger": ledger, "archive": archive}))
		_expect(KNOWLEDGE.validate(json.ledger, json.archive).ok, "integral JSON numbers survive round trip")
		var broken := ledger.duplicate(true)
		broken.revisions[1].metadata.epistemic_state = "refuted"
		_expect(not KNOWLEDGE.validate(broken, archive).ok, "known version cannot be relabeled with different authored meaning")
		broken = ledger.duplicate(true)
		broken.revision = 1.5
		_expect(not KNOWLEDGE.validate(broken, archive).ok, "fractional revision rejected")
		broken = ledger.duplicate(true)
		broken.revisions[1].previous_revision_uid = ""
		_expect(not KNOWLEDGE.validate(broken, archive).ok, "broken revision chain rejected")
		broken = ledger.duplicate(true)
		broken.revisions.pop_back()
		broken.revision = 1
		_expect(not KNOWLEDGE.validate(broken, archive).ok, "orphan source protection consumer rejected")
		CONTENT._contents["NB_NOTE_P_PULSE"].erase("2")
		var newest: Dictionary = ARCHIVE.resolve(archive, ledger.revisions[1].observation_ref).entry
		_expect(CONTENT.render_entry(newest, "en-US").entry.fallback, "missing exact version retains recorded fallback")
		_expect(KNOWLEDGE.validate(ledger, archive).ok, "unavailable translation does not invalidate saved evidence")
	else:
		CONTENT._contents["NB_NOTE_P_PULSE"].erase("2")
	var hidden_hint := CONTENT.definition("NB_HINT_C4_H5", 1)
	var context := {"node_id": "C4", "chapter_id": "CHAPTER_2", "location_id": "M1_MIRROR_HALL", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	_expect(not CONTENT.observe(CONTENT.descriptor("NB_HINT_C4_H5", 1, {"body": {}}), context, hidden_hint.locales["ko-KR"].speaker, hidden_hint.locales["ko-KR"].body, "ko-KR", "replay_committed").ok, "event note permission cannot pre-disclose hints")


func _drain(view: Node) -> void:
	for index in range(30):
		if not view._dialogue_active: return
		view._dialogue_next.pressed.emit()
	_expect(false, "dialogue failed to advance")


func _validate_source_retention() -> void:
	var archive := ARCHIVE.create()
	var template := _observe()
	template.entry_kind = "dialogue"
	template.content_id = "TEST_NORMAL_SOURCE"
	template.producer_id = "TEST_ONLY"
	template.content_protection = []
	template.segments[0].disclosure = "displayed"
	for index in range(2003):
		var observed := template.duplicate(true)
		observed.presentation_token = "%032x" % (index + 1)
		archive.entries.append({"record_class": "authored", "entry_uid": "%032x" % (index + 1), "source_origin_id": archive.source_origin_id, "sequence": index, "observation": observed, "protection_reasons": []})
	archive.next_sequence = 2003
	var refs := [ARCHIVE.make_reference(archive.entries[0], "body"), ARCHIVE.make_reference(archive.entries[1], "body")]
	var dropped := ARCHIVE.make_reference(archive.entries[2], "body")
	var acquired := KNOWLEDGE.acquire(KNOWLEDGE.create(), archive, _observe(), ARCHIVE.new_uid(), refs)
	_expect(acquired.ok, "multiple old sources protected together before retention")
	if not acquired.ok: return
	for ref in refs: _expect(ARCHIVE.resolve(acquired.archive, ref).ok, "every quoted old source survives quota")
	_expect(not ARCHIVE.resolve(acquired.archive, dropped).ok, "only unprotected excess normal source pruned")
	_expect(acquired.archive.entries.filter(func(entry: Dictionary) -> bool: return entry.protection_reasons.is_empty()).size() == 2000, "knowledge sources do not consume ordinary retention quota")
	_expect(archive.entries.size() == 2003 and archive.source_links.is_empty(), "retention candidate never mutates original")


func _validate_live_retry(tree: SceneTree) -> void:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var view := VIEW.instantiate()
	view.configure_session(SLOT, "P1_ENTRY", false)
	tree.current_scene.add_child(view)
	await tree.process_frame
	_drain(view)
	view._enter_room("M1_KITCHEN")
	_drain(view)
	_expect(view._prologue_surface_allowed(), "displayed kitchen sources saved before the note-only failure fixture")
	view._progress.p4_life_support_seen = true
	_expect(view._save_progress(), "sensory exposure saves before optional record action")
	var before := GameState.get_snapshot()
	if not before.meta_progress.knowledge_entries.has(KNOWLEDGE.KEY):
		_expect(false, "missing initial ledger: " + str({"pending": view._pending_notebook, "status": view._status_label.text, "knowledge": before.meta_progress.knowledge_entries, "schema": before.meta_progress.dialogue_history.get("schema_version"), "errors": errors}))
		view.queue_free()
		await tree.process_frame
		return
	_expect(before.meta_progress.knowledge_entries.notebook_knowledge.revision == 1, "seen pulse alone does not acquire the note")
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var bytes := FileAccess.get_file_as_bytes(paths.main)
	var blocker := ProjectSettings.globalize_path(paths.temporary)
	_expect(DirAccess.make_dir_recursive_absolute(blocker) == OK, "create isolated failed-save fixture")
	view._record_p4_life_support_pulse()
	_expect(GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == bytes, "failed note save rolls back progress, archive and ledger together")
	var pending: Dictionary = view._pending_notebook.duplicate(true)
	_expect(pending.has("NOTE_P_PULSE"), "failed event keeps frozen retry request")
	view._open_notebook()
	_expect(GameState.get_snapshot() == before and view._pending_notebook == pending and FileAccess.get_file_as_bytes(paths.main) == bytes, "readonly notebook never flushes pending gameplay")
	view._close_modal()
	var exits: Array = []
	view.return_to_title_requested.connect(func(): exits.append(true))
	view._return_to_title()
	_expect(exits.is_empty() and view._pending_notebook == pending, "failed title save cannot destroy pending event")
	var progress: Dictionary = view._progress.duplicate(true)
	view._begin_first_sleep()
	_expect(view._progress == progress and view._pending_notebook == pending and GameState.get_snapshot() == before, "failed sleep rolls back only its new note and preserves previous pending note")
	_expect(DirAccess.remove_absolute(blocker) == OK, "remove empty isolated fault directory")
	view._record_p4_life_support_pulse()
	var committed := GameState.get_snapshot()
	var ledger: Dictionary = committed.meta_progress.knowledge_entries.notebook_knowledge
	var missing_ledger := committed.duplicate(true)
	missing_ledger.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	_expect(not StateSnapshotValidator.new().validate(missing_ledger).ok, "removing ledger cannot strand protected source consumers")
	_expect(ledger.revision == 2 and ledger.revisions.back().revision_uid == pending.NOTE_P_PULSE.revision_uid and view._pending_notebook.is_empty(), "successful retry commits exactly the original revision")
	_expect(ARCHIVE.resolve(committed.meta_progress.dialogue_history, ledger.revisions.back().observation_ref).entry.observation == pending.NOTE_P_PULSE.observation, "retry preserves acquisition locale/location/token")
	view._record_p4_life_support_pulse()
	_expect(GameState.get_snapshot() == committed, "repeat record button cannot duplicate acquired note")
	view._add_notebook("NOTE_P_WEATHER")
	var recovered_uid: String = view._pending_notebook.NOTE_P_WEATHER.revision_uid
	var lost_ack := LostAcknowledgement.new()
	_expect(view._persist_prologue_progress("SAVE_NEW_GAME", false, lost_ack), "prologue confirms its actual disk save after lost acknowledgement")
	lost_ack.free()
	committed = GameState.get_snapshot()
	ledger = committed.meta_progress.knowledge_entries.notebook_knowledge
	_expect(ledger.revision == 3 and ledger.revisions.back().revision_uid == recovered_uid and view._pending_notebook.is_empty(), "lost response preserves the committed original revision exactly once")
	var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
	var difference := _differences(committed, GameState.get_snapshot())
	_expect(loaded.ok and difference.is_empty(), "real save reload changed state: " + difference + (str(loaded) if not loaded.ok else ""))
	_expect(GameState.get_snapshot().meta_progress.knowledge_entries.notebook_knowledge == ledger, "normalized ledger retains exact typed references")
	view._add_notebook("NOTE_P_IMPRESSIONS")
	var before_namespace := GameState.get_snapshot()
	ProjectSettings.set_setting("ggb/build_flavor", "demo")
	_expect(not view._save_progress() and GameState.get_snapshot() == before_namespace, "pending full-game note cannot enter demo namespace")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	GameState.reset_for_test()
	var other := GameState.get_snapshot()
	_expect(not view._save_progress() and GameState.get_snapshot() == other, "old controller request cannot enter another load scope")
	view.queue_free()
	await tree.process_frame


func _validate_legacy(tree: SceneTree) -> void:
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var view := VIEW.instantiate()
	var progress: Dictionary = view._default_progress()
	var legacy := "수첩의 빈 페이지 아래에 이전 필압 같은 자국이 남아 있다."
	progress.notebook_entries.append(legacy)
	var state := GameState.get_snapshot()
	state.meta_progress.knowledge_entries.prologue_notebook_entries = progress.notebook_entries.duplicate()
	state.loop_state.event_local_states.PROLOGUE = progress
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"TEST_OLD_NOTE").ok, "old progress fixture accepted without a ledger")
	view.configure_session(SLOT, "P1_ENTRY", false)
	tree.current_scene.add_child(view)
	await tree.process_frame
	_drain(view)
	view._inspect_bedroom("notebook")
	_drain(view)
	var current := GameState.get_snapshot()
	_expect(not current.meta_progress.knowledge_entries.has(KNOWLEDGE.KEY), "old prose does not acquire invented historical revisions on load or duplicate inspection")
	_expect(current.meta_progress.knowledge_entries.prologue_notebook_entries == progress.notebook_entries, "legacy prose remains unchanged")
	view.queue_free()
	await tree.process_frame


func _expect(value: bool, message: String) -> void:
	if not value: errors.append(message)


func _differences(a: Variant, b: Variant, path: String = "state") -> String:
	if a == b: return ""
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return path + " key count changed"
		for key in a:
			if not b.has(key): return path + "." + key + " missing"
			var difference := _differences(a[key], b[key], path + "." + key)
			if not difference.is_empty(): return difference
		return ""
	if a is Array and b is Array and a.size() == b.size():
		for index in range(a.size()):
			var difference := _differences(a[index], b[index], path + "[%d]" % index)
			if not difference.is_empty(): return difference
		return ""
	return path + ": " + str(a) + " != " + str(b)
