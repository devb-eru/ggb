extends RefCounted

const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const VIEW := preload("res://scenes/prologue/prologue.tscn")
const SLOT := "__test_notebook_knowledge"
var errors := PackedStringArray()


class FullArchiveRecheck extends StateSnapshotValidator:
	func _validate_dialogue_history(value: Variant, problems: PackedStringArray, _archive_checked: bool = false) -> void:
		super._validate_dialogue_history(value, problems, false)


class CountArchiveChecks extends StateSnapshotValidator:
	var reused := 0
	var checked := 0
	func _validate_dialogue_history(value: Variant, problems: PackedStringArray, archive_checked: bool = false) -> void:
		if value is Dictionary and value.has("schema_version"):
			if archive_checked: reused += 1
			else: checked += 1
		super._validate_dialogue_history(value, problems, archive_checked)


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
	_validate_dense_ledger()
	_validate_numeric_sources()
	_validate_snapshot_archive_reuse()
	await _validate_live_retry(tree)
	await _validate_legacy(tree)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors}


func _validate_snapshot_archive_reuse() -> void:
	var acquired := KNOWLEDGE.acquire(KNOWLEDGE.create(), ARCHIVE.create(), _observe(), ARCHIVE.new_uid())
	_expect(acquired.ok, "snapshot reuse fixture acquired with real source links")
	if not acquired.ok: return
	var state := GameState.make_default_snapshot()
	state.meta_progress.dialogue_history = acquired.archive
	state.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = acquired.ledger
	var variants: Array = [state.duplicate(true)]
	var empty := GameState.make_default_snapshot()
	empty.meta_progress.dialogue_history = ARCHIVE.create()
	empty.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = KNOWLEDGE.create()
	variants.append(empty)
	var no_ledger := state.duplicate(true)
	no_ledger.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	variants.append(no_ledger)
	for mutation in ["ledger_schema", "ledger_revision", "source_missing", "source_origin", "orphan_links", "archive_version", "archive_entry", "archive_sequence", "archive_protection", "legacy_payload", "missing_history", "non_dictionary_history", "legacy_history"]:
		var altered := state.duplicate(true)
		var archive: Dictionary = altered.meta_progress.dialogue_history
		var ledger: Dictionary = altered.meta_progress.knowledge_entries[KNOWLEDGE.KEY]
		match mutation:
			"ledger_schema": ledger.schema_version = 99
			"ledger_revision": ledger.revision += 1
			"source_missing": ledger.revisions[0].source_refs.clear()
			"source_origin": ledger.revisions[0].observation_ref.source_origin_id = ARCHIVE.new_uid()
			"orphan_links": ledger.revisions.clear(); ledger.revision = 0
			"archive_version": archive.schema_version = 99
			"archive_entry": archive.entries[0].observation.segments[0].safe_variables = []
			"archive_sequence": archive.entries[0].sequence = -1
			"archive_protection": archive.entries[0].protection_reasons.clear()
			"legacy_payload":
				var old := ARCHIVE.migrate_verified_legacy({"next_sequence":1, "entries":[{"sequence":0, "line_id":"OLD_UNKNOWN", "speaker_id":"SYSTEM", "variables":{}}]}, "reuse-legacy".sha256_text())
				_expect(old.ok, "legacy validation reuse fixture migrates")
				if old.ok:
					old.archive.entries[0].legacy_payload.line_id = ""
					altered.meta_progress.dialogue_history = old.archive
					altered.meta_progress.knowledge_entries[KNOWLEDGE.KEY] = KNOWLEDGE.create()
			"missing_history": altered.meta_progress.erase("dialogue_history")
			"non_dictionary_history": altered.meta_progress.dialogue_history = []
			"legacy_history": altered.meta_progress.dialogue_history = {"next_sequence":0, "entries":[]}
		variants.append(altered)
	for index in range(variants.size()):
		var fixture: Dictionary = variants[index]
		var frozen := fixture.duplicate(true)
		var validator := CountArchiveChecks.new()
		var result := validator.validate(fixture)
		_expect(result == FullArchiveRecheck.new().validate(fixture), "single-check snapshot has identical acceptance and ordered errors " + str(index))
		_expect(fixture == frozen, "snapshot archive validation never mutates caller " + str(index))
		if index < 2: _expect(result.ok and validator.reused == 1 and validator.checked == 0, "only a fully successful ledger reuses its checked archive")
		elif index < 12: _expect(not result.ok and validator.reused == 0 and validator.checked == 1, "failed ledger or missing ledger retains the full archive check " + str(index))
		elif index == 12: _expect(not result.ok and validator.reused == 1 and validator.checked == 0, "valid archive and empty ledger still check invalid legacy payload")
		else: _expect(not result.ok and validator.reused == 0 and validator.checked == 0, "missing or pre-archive history never receives a structural reuse token")
	print("KNOWLEDGE_SNAPSHOT_REUSE_CASES: ", variants.size())


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
	_expect(not KNOWLEDGE.validate(KNOWLEDGE.create(), archive).ok, "empty ledger cannot bypass orphan source protection")
	var malformed_empty := ARCHIVE.create()
	malformed_empty.entries.append({})
	_expect(not KNOWLEDGE.validate(KNOWLEDGE.create(), malformed_empty).ok, "empty ledger still validates the complete archive")
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


func _validate_dense_ledger() -> void:
	var archive := ARCHIVE.create()
	archive.source_origin_id = "%032x" % 80001
	archive.branch_id = "%032x" % 80002
	archive.entries.append({"entry_uid":"%032x" % 90000, "source_origin_id":archive.source_origin_id, "sequence":0, "record_class":"legacy", "chapter_id":"LEGACY", "legacy_payload":{"sequence":0, "line_id":"CH1_HISTORY_TRANSCRIPT", "speaker_id":"SYSTEM", "variables":{"speaker":"Earlier speaker", "text":"Preserved source"}}, "protection_reasons":[]})
	var ledger := KNOWLEDGE.create()
	var template := _observe()
	var metadata: Dictionary = CONTENT.definition(template.content_id, 1).knowledge
	for index in range(600):
		var observed := template.duplicate(true)
		for field in ["event_occurrence_id", "conversation_session_id", "presentation_token"]: observed[field] = "%032x" % (index + 10000)
		var entry := {"entry_uid":"%032x" % (index + 1), "source_origin_id":archive.source_origin_id, "sequence":index + 1, "record_class":"authored", "observation":observed, "protection_reasons":[]}
		archive.entries.append(entry)
		var own := ARCHIVE.make_reference(entry, "body")
		var refs := [own]
		if index > 0: refs.append(ARCHIVE.make_reference(archive.entries[index], "body"))
		if index % 7 == 0: refs.append(ARCHIVE.make_reference(archive.entries[0], "legacy"))
		var revision := "%032x" % (index + 20000)
		ledger.revisions.append({"knowledge_uid":"%032x" % 70000, "revision_uid":revision, "previous_revision_uid":"" if index == 0 else "%032x" % (index + 19999), "sequence":index, "metadata":metadata.duplicate(true), "observation_ref":own, "source_refs":refs})
		for ref in refs: archive.source_links.append({"consumer_kind":"knowledge_source", "consumer_uid":revision, "target":ref.duplicate(true)})
	ledger.revision = ledger.revisions.size()
	archive.next_sequence = archive.entries.size()
	_rebuild_protection(archive)
	var before := {"archive":archive.duplicate(true), "ledger":ledger.duplicate(true)}
	var started := Time.get_ticks_usec()
	_expect(KNOWLEDGE.validate(ledger, archive).ok, "600-revision source graph validates")
	var elapsed := Time.get_ticks_usec() - started
	_expect(before.archive == archive and before.ledger == ledger, "dense validation never changes source data")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(before))
	_expect(KNOWLEDGE.validate(parsed.ledger, parsed.archive).ok, "dense graph resolves JSON numeric versions")
	var reordered := ledger.duplicate(true)
	for row in reordered.revisions: row.source_refs.reverse()
	_expect(KNOWLEDGE.validate(reordered, archive).ok, "source ordering is not identity or ownership")
	for fault in ["duplicate_source", "numeric_duplicate", "reordered_duplicate", "missing_link", "orphan_link", "wrong_consumer", "broken_chain", "wrong_owner", "metadata", "missing_own", "hidden_segment", "wrong_origin", "wrong_version", "malformed_reference", "bad_archive"]:
		var damaged := before.duplicate(true)
		var row: Dictionary = damaged.ledger.revisions[10]
		match fault:
			"duplicate_source": row.source_refs.append(row.source_refs[0].duplicate(true))
			"numeric_duplicate":
				var ref: Dictionary = row.source_refs[0].duplicate(true)
				ref.content_version = 1.0
				row.source_refs.append(ref)
			"reordered_duplicate":
				var ref := {}
				var fields: Array = row.source_refs[0].keys()
				fields.reverse()
				for field in fields: ref[field] = row.source_refs[0][field]
				row.source_refs.append(ref)
			"missing_link": damaged.archive.source_links.pop_back()
			"orphan_link": damaged.archive.source_links.append({"consumer_kind":"knowledge_source", "consumer_uid":"%032x" % 99999, "target":row.observation_ref.duplicate(true)})
			"wrong_consumer": damaged.archive.source_links[0].consumer_uid = "%032x" % 99999
			"broken_chain": row.previous_revision_uid = "%032x" % 99999
			"wrong_owner": row.knowledge_uid = "%032x" % 99999
			"metadata": row.metadata.epistemic_state = "refuted"
			"missing_own": row.source_refs.remove_at(0)
			"hidden_segment": row.source_refs[1].segment_id = "hidden"
			"wrong_origin": row.source_refs[1].source_origin_id = "%032x" % 99999
			"wrong_version": row.source_refs[1].content_version = 2
			"malformed_reference": row.source_refs[1].erase("kind")
			"bad_archive": damaged.archive.entries.back().observation.segments[0].disclosure = "acquired"
		if fault in ["missing_link", "orphan_link", "wrong_consumer"]:
			_rebuild_protection(damaged.archive)
			_expect(ARCHIVE.validate(damaged.archive).ok, "graph fault is not hidden by archive corruption: " + fault)
		var unchanged := damaged.duplicate(true)
		_expect(not KNOWLEDGE.validate(damaged.ledger, damaged.archive).ok and damaged == unchanged, "invalid graph rejected without mutation: " + fault)
	print("NOTEBOOK_GRAPH_TIMING: " + JSON.stringify({"entries":archive.entries.size(), "revisions":600, "source_links":archive.source_links.size(), "validate_usec":elapsed, "sha256":JSON.stringify(before, "", true).sha256_text(), "acceptance":"MEASUREMENT_ONLY"}))


func _validate_numeric_sources() -> void:
	var first := KNOWLEDGE.acquire(KNOWLEDGE.create(), ARCHIVE.create(), _observe(), ARCHIVE.new_uid())
	_expect(first.ok, "numeric source seed acquires")
	if not first.ok: return
	var source: Dictionary = first.ledger.revisions[0].observation_ref
	var numeric := source.duplicate(true)
	numeric.content_version = 1.0
	var observation := _observe()
	var revision := ARCHIVE.new_uid()
	var second := KNOWLEDGE.acquire(first.ledger, first.archive, observation, revision, [source, numeric])
	_expect(second.ok, "equivalent source arguments coalesce in acquisition")
	if not second.ok: return
	_expect(second.ledger.revisions[1].source_refs.size() == 2, "one owner and one external source are retained")
	var retried := KNOWLEDGE.acquire(second.ledger, second.archive, observation, revision, [numeric])
	_expect(retried.ok and not retried.changed and retried.archive == second.archive and retried.ledger == second.ledger, "numeric reference retry is idempotent and byte-model preserving")
	var wrong := numeric.duplicate(true)
	wrong.content_version = 2
	_expect(not KNOWLEDGE.acquire(second.ledger, second.archive, observation, revision, [wrong]).ok, "different meaning version cannot alias a retry")
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(second))
	_expect(KNOWLEDGE.validate(normalized.ledger, normalized.archive).ok, "numeric source merge survives JSON reload")


func _rebuild_protection(archive: Dictionary) -> void:
	# Independent full scan, so graph acceptance never trusts the optimized index.
	for entry in archive.entries:
		var reasons := {}
		if entry.record_class == "authored":
			for reason in entry.observation.content_protection: reasons["content:" + reason] = true
		for link in archive.source_links:
			if link.target.uid == entry.entry_uid: reasons[link.consumer_kind + ":" + link.consumer_uid] = true
		entry.protection_reasons = reasons.keys()
		entry.protection_reasons.sort()


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
	if is_instance_valid(view._notebook_host):
		_expect(await preload("res://scripts/tests/notebook_test_wait.gd").ready(view.get_tree(), view._notebook_host), "notebook model ready before read-only inspection")
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
