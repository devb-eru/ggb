extends SceneTree

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
var errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _observation(index: int, protected: bool = false) -> Dictionary:
	return {
		"producer_id": "TEST_ONLY", "event_id": "B4", "node_id": "B4_OBSERVE", "location_id": "M1_LIBRARY_INNER", "chapter_id": "CHAPTER_1",
		"event_occurrence_id": "%032x" % (index + 1), "conversation_session_id": "%032x" % (index + 1), "presentation_token": "%032x" % (index + 1),
		"entry_kind": "dialogue", "content_id": "TEST_OBSERVATION", "content_version": 1, "variant_id": "observed", "speaker_id": "PROTAGONIST",
		"segments": [{"segment_id": "front", "disclosure": "displayed", "localization_key": "TEST_OBSERVATION_FRONT", "safe_variables": {}, "captured_text": "Visible front %d" % index, "viewed_locale": "en-US"}],
		"content_protection": ["journal"] if protected else [],
	}


func _run() -> void:
	var source := {"next_sequence": 2, "entries": [
		{"sequence": 0, "line_id": "OLD", "speaker_id": "SYSTEM", "variables": {"text": "원본"}},
		{"sequence": 1, "chapter_id": "PRIVATE_UNKNOWN", "line_id": "OLD2", "speaker_id": "SYSTEM", "custom_field": ["preserve"]},
	]}
	var unchanged := source.duplicate(true)
	var migrated := ARCHIVE.migrate_verified_legacy(source, "fixture".sha256_text())
	_expect(migrated.ok, "verified legacy candidate migrates")
	if not migrated.ok: _finish(); return
	var archive: Dictionary = migrated.archive
	_expect(source == unchanged, "migration does not rewrite source")
	_expect(archive == ARCHIVE.migrate_verified_legacy(source, "fixture".sha256_text()).archive, "same verified source produces identical UIDs")
	_expect(archive.source_origin_id != ARCHIVE.migrate_verified_legacy(source, "other".sha256_text()).archive.source_origin_id, "unproven backup origin stays separate")
	_expect(archive.entries[1].legacy_payload == source.entries[1] and archive.entries[1].chapter_id == "LEGACY", "unknown original metadata survives intact")
	_expect(not ARCHIVE.migrate_verified_legacy(source, "").ok, "missing verified identity rejected")
	var invalid := source.duplicate(true)
	invalid.entries[1].sequence = 0
	_expect(not ARCHIVE.migrate_verified_legacy(invalid, "fixture".sha256_text()).ok, "duplicate legacy order not repaired silently")
	var observation := _observation(1)
	var old := archive.duplicate(true)
	var appended := ARCHIVE.append_observation(archive, observation, archive.revision)
	_expect(appended.ok and archive == old, "append returns a candidate without modifying current archive")
	if not appended.ok: _finish(); return
	archive = appended.archive
	var retry := ARCHIVE.append_observation(archive, observation, archive.revision)
	_expect(retry.ok and not retry.changed and retry.entry_uid == appended.entry_uid, "same presentation is idempotent")
	var conflicting := observation.duplicate(true)
	conflicting.variant_id = "different"
	_expect(not ARCHIVE.append_observation(archive, conflicting, archive.revision).ok, "token cannot overwrite a different observation")
	_expect(not ARCHIVE.append_observation(archive, _observation(2), 0).ok, "stale revision rejects instead of replacing current state")
	var ref := ARCHIVE.make_reference(archive.entries.back(), "front")
	var pinned := ARCHIVE.set_reference(archive, "bookmarks", ref, true, archive.revision)
	_expect(pinned.ok and pinned.archive.entries.back().protection_reasons == ["bookmark:front"], "bookmark and protection appear in one candidate")
	_expect(archive.bookmarks.is_empty() and archive.entries.back().protection_reasons.is_empty(), "uncommitted pin does not alter source")
	archive = pinned.archive
	archive = ARCHIVE.set_reference(archive, "comparison", ref, true, archive.revision).archive
	var consumer := "%032x" % 800
	archive = ARCHIVE.add_source_link(archive, "knowledge_source", consumer, ref, archive.revision).archive
	archive = ARCHIVE.set_reference(archive, "bookmarks", ref, false, archive.revision).archive
	_expect(archive.entries.back().protection_reasons == ["comparison:front", "knowledge_source:" + consumer], "unpin retains comparison and knowledge protection")
	var hidden := ref.duplicate(true)
	hidden.segment_id = "back"
	_expect(not ARCHIVE.resolve(archive, hidden).ok and not ARCHIVE.set_reference(archive, "comparison", hidden, true, archive.revision).ok, "undisplayed back segment cannot resolve or enter comparison")
	var wrong_version := ref.duplicate(true)
	wrong_version.content_version = 2
	_expect(not ARCHIVE.resolve(archive, wrong_version).ok, "reference never substitutes newer content")
	var resolved := ARCHIVE.resolve(archive, ref)
	resolved.segment.captured_text = "mutated return value"
	_expect(ARCHIVE.resolve(archive, ref).segment.captured_text != resolved.segment.captured_text, "resolved copies cannot mutate archive")
	var hidden_observation := _observation(2)
	hidden_observation.segments[0].disclosure = "acquired"
	_expect(not ARCHIVE.append_observation(archive, hidden_observation, archive.revision).ok, "acquisition alone is not replay evidence")
	hidden_observation = _observation(2)
	hidden_observation.segments[0].safe_variables["private_state"] = {"bond": 5}
	_expect(not ARCHIVE.append_observation(archive, hidden_observation, archive.revision).ok, "raw state dictionaries cannot become template variables")
	var forked := ARCHIVE.fork(archive)
	_expect(forked.ok and forked.archive.branch_id != archive.branch_id and forked.archive.entries == archive.entries, "fork replaces branch but preserves existing observation identity")
	var left := ARCHIVE.append_observation(archive, _observation(3), archive.revision)
	var right := ARCHIVE.append_observation(forked.archive, _observation(3), forked.archive.revision)
	_expect(left.archive.entries.back().sequence == right.archive.entries.back().sequence and left.entry_uid != right.entry_uid, "reused sequence on two branches cannot alias UID")
	var future := archive.duplicate(true)
	future.schema_version = 999
	_expect(not ARCHIVE.validate(future).ok, "future archive schema is rejected without rewriting")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(archive))
	_expect(ARCHIVE.validate(roundtrip).ok and ARCHIVE.resolve(roundtrip, ref).ok, "JSON number representation preserves identities and references")
	var corrupt := archive.duplicate(true)
	corrupt.entries.back().protection_reasons = []
	_expect(not ARCHIVE.validate(corrupt).ok, "durable references without matching protection are invalid")
	_validate_limits()
	_validate_retention()
	_finish()


func _validate_limits() -> void:
	var archive := ARCHIVE.create()
	for index in range(51):
		archive = ARCHIVE.append_observation(archive, _observation(index), archive.revision).archive
	var original := archive.duplicate(true)
	for collection in ["bookmarks", "comparison"]:
		archive = original.duplicate(true)
		var limit := ARCHIVE.BOOKMARK_LIMIT if collection == "bookmarks" else ARCHIVE.COMPARISON_LIMIT
		for index in range(limit):
			archive = ARCHIVE.set_reference(archive, collection, ARCHIVE.make_reference(archive.entries[index], "front"), true, archive.revision).archive
		var before := archive.duplicate(true)
		var denied := ARCHIVE.set_reference(archive, collection, ARCHIVE.make_reference(archive.entries[limit], "front"), true, archive.revision)
		_expect(not denied.ok and archive == before, "collection limit does not evict a previous reference: " + collection)
		var repeat := ARCHIVE.set_reference(archive, collection, archive[collection][0], true, archive.revision)
		_expect(repeat.ok and not repeat.changed, "duplicate add at capacity is idempotent: " + collection)


func _validate_retention() -> void:
	var legacy := {"next_sequence": 10000, "entries": []}
	for index in range(10000):
		legacy.entries.append({"sequence": index, "line_id": "OLD", "speaker_id": "SYSTEM", "variables": {"text": "Legacy %d" % index}})
	var archive: Dictionary = ARCHIVE.migrate_verified_legacy(legacy, "large-fixture".sha256_text()).archive
	# Construct the large fixed population once; incremental append is tested above.
	for index in range(4002):
		archive.entries.append({"entry_uid": "%032x" % (index + 1), "source_origin_id": archive.source_origin_id, "sequence": index + 10000, "record_class": "authored", "observation": _observation(index, index < 2001), "protection_reasons": ["content:journal"] if index < 2001 else []})
	archive.next_sequence = 14002
	var before := archive.duplicate(true)
	var maintained := ARCHIVE.maintain(archive, archive.revision)
	_expect(maintained.ok and archive == before, "retention produces a candidate without mutating source")
	if not maintained.ok: return
	var result: Dictionary = maintained.archive
	_expect(result.entries.size() == 14001 and maintained.pruned_uids == ["%032x" % 2002], "only oldest excess normal entry pruned")
	_expect(result.entries.filter(func(e: Dictionary) -> bool: return e.record_class == "legacy").size() == 10000, "all legacy survives independently")
	_expect(result.entries.filter(func(e: Dictionary) -> bool: return not e.protection_reasons.is_empty()).size() == 2001, "protected records do not consume normal quota")
	_expect(result.entries.back().entry_uid == "%032x" % 4002 and result.next_sequence == 14002, "newest entry retained and order never renumbered")
	var missing := ARCHIVE.make_reference(before.entries[12001], "front")
	_expect(not ARCHIVE.resolve(result, missing).ok, "pruned reference not retargeted to another sequence")
	var pin_ref := ARCHIVE.make_reference(before.entries[12001], "front")
	var pinned := ARCHIVE.set_reference(before, "bookmarks", pin_ref, true, before.revision)
	_expect(pinned.ok and pinned.pruned_uids.is_empty() and ARCHIVE.resolve(pinned.archive, pin_ref).ok, "pin and retention are computed together")
	var unpinned := ARCHIVE.set_reference(pinned.archive, "bookmarks", pin_ref, false, pinned.archive.revision)
	_expect(unpinned.ok and unpinned.pruned_uids == [pin_ref.uid], "removing final protection restores normal retention")
	var repeated := ARCHIVE.set_reference(unpinned.archive, "bookmarks", pin_ref, false, unpinned.archive.revision)
	_expect(repeated.ok and not repeated.changed and repeated.archive == unpinned.archive, "unpin retry remains idempotent after its target is pruned")


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)


func _finish() -> void:
	print("NOTEBOOK_ARCHIVE_SMOKE: " + ("PASS" if errors.is_empty() else str(errors)))
	quit(0 if errors.is_empty() else 1)
