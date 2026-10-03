extends RefCounted

const NOTES := preload("res://scripts/systems/notebook_legacy_notes.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")
const GALLERY := preload("res://scripts/systems/ending_gallery_pages.gd")
const SLOT := "__test_notebook_legacy_notes"
var errors := PackedStringArray()
var checks := 0

class ControlledSave extends Node:
	var reject := false
	var lose_ack := false
	var transactions: Array[String] = []
	func get_build_flavor() -> String:
		return SaveManager.get_build_flavor()
	func inspect_slot(slot: String) -> Dictionary:
		return SaveManager.inspect_slot(slot)
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		transactions.append(transaction)
		if reject: return {"ok": false, "error_ids": ["TEST_NOTE_SAVE"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_NOTE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run() -> Dictionary:
	_read_model()
	_capture_and_validation()
	_limits_and_retention()
	_commands()
	print("NOTEBOOK_LEGACY_NOTES_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": SLOT, "run_id": "notes", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 0}


func _open(archive: Dictionary, knowledge: Dictionary, locale: String = "ko-KR"):
	var query := QUERY.new()
	var result := query.open(archive, KNOWLEDGE.create(), _scope(archive), locale, knowledge)
	_expect(result.ok, "legacy note query opens: " + str(result))
	return query


func _read_model() -> void:
	var archive := ARCHIVE.create()
	var knowledge := {NOTES.PROLOGUE: ["  원문\n줄바꿈  ", "같은 문장", "같은 문장", ""], NOTES.CHAPTER: {"INTERNAL_KEY": "마지막 값", "DO_NOT_PARSE": {"secret": "HIDDEN_BODY"}}, "private_truth": "NOT_PUBLIC"}
	for index in range(51): knowledge[NOTES.CHAPTER]["internal_%d" % index] = "조사 원문 %d" % index
	var before := JSON.stringify([archive, knowledge])
	var query = _open(archive, knowledge)
	var key: String = query.cache_key()
	var page: Dictionary = query.page({"tab": "clues"}, 0, key)
	_expect(page.count == 56 and page.items.size() == 50 and page.pages == 2, "all stored originals including empty text are paged")
	_expect(query.diagnostics().render_count == 0 and query.diagnostics().error_count == 1, "open projects metadata without rendering and diagnoses malformed notes")
	_expect(query.page({"tab": "dialogue"}, 0, key).count == 0 and query.page({"tab": "people"}, 0, key).count == 0, "raw notebook never becomes conversation or inferred people")
	_expect(query.page({"tab": "clues"}, 1, key).items.size() == 6, "last page remains reachable")
	var original: Dictionary = query.detail(page.items[0].key, key)
	_expect(original.text == knowledge[NOTES.PROLOGUE][0] and original.kind == "legacy_note" and not original.note_snapshot, "raw whitespace and original language preserved without source fabrication")
	_expect(original.sources.is_empty() and original.speaker.is_empty() and original.epistemic.is_empty(), "unknown acquisition has no fabricated sources or verified state")
	_expect(page.items[1].reference.uid != page.items[2].reference.uid, "same text at different addresses is not deduplicated")
	var facets: Dictionary = query.facets({"tab": "clues"}, key)
	_expect(facets.values.chapters == ["LEGACY"] and facets.values.locations.is_empty() and facets.values.speakers.is_empty(), "no inferred historical chapter or location")
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(key, 20)
	for hidden in ["INTERNAL_KEY", "DO_NOT_PARSE", "HIDDEN_BODY", "NOT_PUBLIC", "internal_50"]:
		_expect(query.page({"tab": "clues", "needle": hidden}, 0, key).count == 0, "only actual public text indexed: " + hidden)
	_expect(query.page({"tab": "clues", "needle": "조사 원문 50"}, 0, key).count == 1, "search reaches off-page original")
	var english = _open(archive, knowledge, "en-US")
	_expect(english.detail(page.items[0].key, english.cache_key()).text == original.text, "locale changes only chrome, not historical original")
	_expect(JSON.stringify([archive, knowledge]) == before, "read/search never writes canonical notes or archive")
	knowledge[NOTES.PROLOGUE][0] = "변경된 값"
	_expect(query.detail(page.items[0].key, key).text == original.text, "open query freezes last visible value")
	var reopened = _open(archive, knowledge)
	_expect(not reopened.detail(page.items[0].key, reopened.cache_key()).ok, "changed uncaptured value cannot resolve an old content address")
	var same: Dictionary = NOTES.project(knowledge, archive.source_origin_id).entries[0]
	_expect(same.entry_uid == NOTES.project(knowledge, ARCHIVE.fork(archive).archive.source_origin_id).entries[0].entry_uid, "same included value retains identity across fork")
	_expect(same.entry_uid != NOTES.project(knowledge, ARCHIVE.create().source_origin_id).entries[0].entry_uid, "another source origin never aliases notes")
	var bad := NOTES.project({NOTES.PROLOGUE: {}, NOTES.CHAPTER: []}, archive.source_origin_id)
	_expect(bad.entries.is_empty() and bad.errors.size() == 2, "malformed containers are not stringified as public evidence")
	_expect(not query.index_step(reopened.cache_key()).ok, "another model generation is not an accepted callback key")
	var first_order := NOTES.project({NOTES.CHAPTER: {"b": "second", "a": "first"}}, archive.source_origin_id)
	var next_order := NOTES.project({NOTES.CHAPTER: {"a": "first", "b": "second"}}, archive.source_origin_id)
	_expect(first_order == next_order, "JSON key ordering cannot reorder unknown-time notes or change their cache identity")


func _capture_and_validation() -> void:
	var archive := ARCHIVE.create()
	var knowledge := {NOTES.CHAPTER: {"last_value": "보존할 원문"}}
	var note: Dictionary = NOTES.project(knowledge, archive.source_origin_id).entries[0]
	var ref := ARCHIVE.make_reference(note, "legacy")
	var captured := ARCHIVE.capture_legacy_note_reference(archive, "bookmarks", note, int(archive.revision))
	_expect(captured.ok and archive.entries.is_empty(), "pure capture creates one atomic candidate")
	if not captured.ok: return
	archive = captured.archive
	_expect(archive.entries.size() == 1 and archive.entries[0].protection_reasons == ["bookmark:legacy"], "snapshot and protection installed together")
	var query = _open(archive, knowledge)
	_expect(query.page({"tab": "clues"}, 0, query.cache_key()).count == 1, "captured and current same raw value displayed only once")
	var retry := ARCHIVE.capture_legacy_note_reference(archive, "bookmarks", note, int(archive.revision))
	_expect(retry.ok and not retry.changed and retry.archive == archive, "capture retry idempotent")
	knowledge[NOTES.CHAPTER].last_value = "그 뒤의 다른 값"
	query = _open(archive, knowledge)
	_expect(query.page({"tab": "clues"}, 0, query.cache_key()).count == 2 and query.detail(QUERY.reference_key(ref), query.cache_key()).text == "보존할 원문", "overwritten canonical value leaves pinned original intact")
	_expect(query.detail(QUERY.reference_key(ref), query.cache_key()).note_snapshot, "preserved original is explicitly distinguished from current last value")
	var json: Dictionary = JSON.parse_string(JSON.stringify(archive))
	_expect(ARCHIVE.validate(json).ok and ARCHIVE.resolve(json, ref).ok, "note identity and references survive JSON numeric normalization")
	var removed := ARCHIVE.set_reference(archive, "bookmarks", ref, false, int(archive.revision))
	_expect(removed.ok and removed.archive.entries.size() == 1, "unpin never deletes legacy original under normal quota")
	for invalid in [null, [], {}, "bad", true, {"version": 1}]:
		var broken := archive.duplicate(true)
		broken.entries[0][NOTES.MARKER] = invalid
		_expect(not ARCHIVE.validate(broken).ok, "invalid marker rejected without script exception")
	for field in ["version", "container", "locator", "text_sha256"]:
		var broken := archive.duplicate(true)
		broken.entries[0][NOTES.MARKER][field] = []
		_expect(not ARCHIVE.validate(broken).ok, "bad source field rejected: " + field)
	var changed := archive.duplicate(true)
	changed.entries[0].legacy_payload.variables.text = "위조된 원문"
	_expect(not ARCHIVE.validate(changed).ok, "changed original checksum and identity rejected")
	changed = archive.duplicate(true)
	changed.entries[0].record_class = "authored"
	_expect(not ARCHIVE.validate(changed).ok, "note marker cannot label an authored conversation")
	for id in GALLERY.WAKE.BODY:
		var original: String = GALLERY.WAKE.BODY[id][2]
		var bait: Dictionary = NOTES.project({NOTES.CHAPTER: {"body_bait": original}}, archive.source_origin_id).entries[0]
		var sample := ARCHIVE.capture_legacy_note_reference(archive, "comparison", bait, int(archive.revision))
		var state := {"meta_progress": {"dialogue_history": sample.archive}}
		_expect(not GALLERY._body_repeat_seen(state, id), "pinned note cannot fabricate a body reobservation: " + id)
		var old := {"meta_progress": {"dialogue_history": {"entries": [{"line_id": "CH1_HISTORY_TRANSCRIPT", "variables": {"text": original}}]}}}
		_expect(GALLERY._body_repeat_seen(old, id), "actual legacy transcript compatibility is unchanged: " + id)


func _limits_and_retention() -> void:
	for collection in ["bookmarks", "comparison"]:
		var archive := ARCHIVE.create()
		var limit: int = ARCHIVE.BOOKMARK_LIMIT if collection == "bookmarks" else ARCHIVE.COMPARISON_LIMIT
		for index in range(limit):
			var note: Dictionary = NOTES.project({NOTES.PROLOGUE: [str(index)]}, archive.source_origin_id).entries[0]
			archive = ARCHIVE.capture_legacy_note_reference(archive, collection, note, int(archive.revision)).archive
		var before := archive.duplicate(true)
		var extra: Dictionary = NOTES.project({NOTES.PROLOGUE: ["overflow"]}, archive.source_origin_id).entries[0]
		var refused := ARCHIVE.capture_legacy_note_reference(archive, collection, extra, int(archive.revision))
		_expect(not refused.ok and refused.error_id == "NB_REFERENCE_LIMIT" and archive == before, "capacity never leaves an orphan captured original: " + collection)
		var maintained := ARCHIVE.maintain(archive, int(archive.revision))
		_expect(maintained.ok and maintained.archive.entries.size() == limit, "legacy note originals survive maintenance: " + collection)


func _commands() -> void:
	var game := preload("res://scripts/autoload/game_state.gd").new()
	game.reset_for_test()
	var state: Dictionary = game.get_snapshot()
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries = {NOTES.PROLOGUE: ["명시적으로 고정할 원문"]}
	_expect(StateWriter.new(game).install_snapshot(state, game.revision, &"NEW_GAME_NOTE_TEST").ok, "isolated gameplay snapshot installs")
	SaveManager.delete_test_slot(SLOT)
	var seeded := SaveManager.save_snapshot(SLOT, "P1_ENTRY", game.get_snapshot(), game.revision, "NEW_GAME_NOTE_TEST")
	_expect(seeded.ok, "isolated real save exists")
	if not seeded.ok:
		game.free()
		return
	var saves := ControlledSave.new()
	var archive: Dictionary = state.meta_progress.dialogue_history
	var note: Dictionary = NOTES.project(state.meta_progress.knowledge_entries, archive.source_origin_id).entries[0]
	var ref := ARCHIVE.make_reference(note, "legacy")
	var scope := COMMANDS.scope(game, saves, SLOT)
	var command := ARCHIVE.new_uid()
	var bytes := FileAccess.get_file_as_bytes(SaveManager._slot_paths(SLOT).main)
	saves.reject = true
	var failed := COMMANDS.set_reference(game, saves, SLOT, "bookmarks", ref, true, scope, game.revision, command)
	_expect(not failed.ok and game.get_snapshot() == state, "failed pin rolls back original materialization and all metadata")
	_expect(FileAccess.get_file_as_bytes(SaveManager._slot_paths(SLOT).main) == bytes, "failed pin leaves durable original untouched")
	saves.reject = false
	saves.lose_ack = true
	var saved := COMMANDS.set_reference(game, saves, SLOT, "bookmarks", ref, true, scope, game.revision, command)
	_expect(saved.ok and saved.get("recovered_acknowledgement", false), "lost ack recovered using exact original snapshot")
	_expect(saves.transactions.size() == 2 and saves.transactions[0] == saves.transactions[1], "retry preserves command ID")
	if saved.ok:
		var confirmed := SaveManager.confirm_snapshot_commit(SLOT, "NOTEBOOK_META_" + command)
		_expect(confirmed.ok and StateSnapshotValidator.same_persisted_value(confirmed.snapshot, game.get_snapshot()), "actual file reload preserves note marker and raw source")
		var query = _open(confirmed.snapshot.meta_progress.dialogue_history, confirmed.snapshot.meta_progress.knowledge_entries)
		_expect(query.detail(QUERY.reference_key(ref), query.cache_key()).text == note.legacy_payload.variables.text, "file round trip keeps original retrievable")
		var after: Dictionary = game.get_snapshot()
		var gameplay := after.duplicate(true)
		gameplay.meta_progress.dialogue_history = state.meta_progress.dialogue_history
		_expect(gameplay == state, "pin never changes knowledge, loop, relation, field_read or endings")
		saves.lose_ack = false
		var again := COMMANDS.set_reference(game, saves, SLOT, "comparison", ref, true, scope, game.revision, ARCHIVE.new_uid())
		_expect(again.ok and game.get_snapshot().meta_progress.dialogue_history.entries.size() == 1, "another collection reuses the same protected original")
		var before := game.get_snapshot()
		var forged := ref.duplicate(true)
		forged.uid = ARCHIVE.new_uid()
		_expect(not COMMANDS.set_reference(game, saves, SLOT, "comparison", forged, true, scope, game.revision, ARCHIVE.new_uid()).ok and game.get_snapshot() == before, "unknown content address cannot inject an arbitrary original")
		_expect(not COMMANDS.set_reference(game, saves, SLOT, "comparison", ref, true, scope + "different", game.revision, ARCHIVE.new_uid()).ok, "foreign scope rejected before materialization")
		_expect(not COMMANDS.set_reference(game, saves, SLOT, "comparison", ref, true, scope, game.revision - 1, ARCHIVE.new_uid()).ok, "stale gameplay revision rejected")
		var changed := before.duplicate(true)
		changed.meta_progress.knowledge_entries[NOTES.CHAPTER] = {"changing": "before overwrite"}
		StateWriter.new(game).install_snapshot(changed, game.revision, &"TEST_NEW_RAW_NOTE")
		var fresh: Dictionary = NOTES.project({NOTES.CHAPTER: changed.meta_progress.knowledge_entries[NOTES.CHAPTER]}, archive.source_origin_id).entries[0]
		var stale_ref := ARCHIVE.make_reference(fresh, "legacy")
		changed.meta_progress.knowledge_entries[NOTES.CHAPTER].changing = "after overwrite"
		StateWriter.new(game).install_snapshot(changed, game.revision, &"TEST_OVERWRITE_RAW_NOTE")
		before = game.get_snapshot()
		_expect(not COMMANDS.set_reference(game, saves, SLOT, "comparison", stale_ref, true, scope, game.revision, ARCHIVE.new_uid()).ok and game.get_snapshot() == before, "uncommitted former last value cannot be recaptured after canonical overwrite")
	SaveManager.delete_test_slot(SLOT)
	saves.free()
	game.free()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(message)
