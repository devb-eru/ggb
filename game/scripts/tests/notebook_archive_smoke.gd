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
	_validate_session_retention()
	_validate_protection_index()
	_validate_numeric_commands()
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
	_expect(not result.entries.any(func(entry: Dictionary) -> bool: return entry.has(ARCHIVE.SESSION_PRUNED)), "fully pruned session does not create evidence in unrelated sessions")
	var missing := ARCHIVE.make_reference(before.entries[12001], "front")
	_expect(not ARCHIVE.resolve(result, missing).ok, "pruned reference not retargeted to another sequence")
	var pin_ref := ARCHIVE.make_reference(before.entries[12001], "front")
	var pinned := ARCHIVE.set_reference(before, "bookmarks", pin_ref, true, before.revision)
	_expect(pinned.ok and pinned.pruned_uids.is_empty() and ARCHIVE.resolve(pinned.archive, pin_ref).ok, "pin and retention are computed together")
	var unpinned := ARCHIVE.set_reference(pinned.archive, "bookmarks", pin_ref, false, pinned.archive.revision)
	_expect(unpinned.ok and unpinned.pruned_uids == [pin_ref.uid], "removing final protection restores normal retention")
	var repeated := ARCHIVE.set_reference(unpinned.archive, "bookmarks", pin_ref, false, unpinned.archive.revision)
	_expect(repeated.ok and not repeated.changed and repeated.archive == unpinned.archive, "unpin retry remains idempotent after its target is pruned")


func _validate_session_retention() -> void:
	var archive := preload("res://scripts/tests/notebook_retention_fixture.gd").create()
	var original := archive.duplicate(true)
	var result := ARCHIVE.maintain(archive, archive.revision)
	_expect(result.ok and result.pruned_uids == [archive.entries[0].entry_uid], "session retention prunes only excess ordinary entry")
	if not result.ok: return
	var retained: Dictionary = result.archive
	for entry in retained.entries:
		_expect(entry.get(ARCHIVE.SESSION_PRUNED, false) == (int(entry.sequence) in [1, 4]), "retention evidence uses full origin/occurrence/session tuple: %d" % int(entry.sequence))
		_expect(entry.observation == original.entries[int(entry.sequence)].observation, "retention marker never rewrites observed content")
	_expect(archive == original, "pruning candidate does not mark original or earlier save")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(retained))
	_expect(ARCHIVE.validate(roundtrip).ok, "session marker archive validates after JSON numeric conversion")
	_expect(roundtrip.entries.map(func(entry: Dictionary) -> bool: return entry.get(ARCHIVE.SESSION_PRUNED, false)) == retained.entries.map(func(entry: Dictionary) -> bool: return entry.get(ARCHIVE.SESSION_PRUNED, false)), "session markers retain exact boolean values after JSON roundtrip")
	_expect(ARCHIVE.maintain(retained, retained.revision).archive.entries == retained.entries, "repeated maintenance preserves exact evidence without adding history")
	_expect(ARCHIVE.fork(retained).archive.entries == retained.entries, "fork retains evidence without changing observed identity")
	for invalid in [false, 1, "true", null, []]:
		var damaged := retained.duplicate(true)
		damaged.entries[0][ARCHIVE.SESSION_PRUNED] = invalid
		_expect(ARCHIVE.validate(damaged).get("error_id") == "NB_SESSION_RETENTION", "invalid retention marker rejected: " + str(invalid))
	var legacy: Dictionary = ARCHIVE.migrate_verified_legacy({"next_sequence":1, "entries":[{"sequence":0}]}, "retention-legacy".sha256_text()).archive
	legacy.entries[0][ARCHIVE.SESSION_PRUNED] = true
	_expect(ARCHIVE.validate(legacy).get("error_id") == "NB_SESSION_RETENTION", "legacy session history is not inferred")
	legacy.entries[0].record_class = "unmapped"
	legacy.entries[0].snapshot_context = {"presentation_token":ARCHIVE.new_uid()}
	_expect(ARCHIVE.validate(legacy).get("error_id") == "NB_SESSION_RETENTION", "unmapped session history is not inferred")
	var unmarked := retained.duplicate(true)
	for entry in unmarked.entries: entry.erase(ARCHIVE.SESSION_PRUNED)
	var maintained := ARCHIVE.maintain(unmarked, unmarked.revision)
	_expect(maintained.ok and maintained.archive.entries == unmarked.entries, "sequence gaps alone never reconstruct old pruning history")


func _validate_protection_index() -> void:
	var archive := ARCHIVE.create()
	archive.source_origin_id = "%032x" % 90001
	archive.branch_id = "%032x" % 90002
	for index in range(1200):
		var observed := _observation(index, index % 3 == 0)
		var back: Dictionary = observed.segments[0].duplicate(true)
		back.segment_id = "back"
		back.localization_key = "TEST_OBSERVATION_BACK"
		observed.segments.append(back)
		archive.entries.append({"entry_uid":"%032x" % (index + 1), "source_origin_id":archive.source_origin_id, "sequence":index, "record_class":"authored", "observation":observed, "protection_reasons":[]})
	archive.next_sequence = archive.entries.size()
	for index in range(50): archive.bookmarks.append(ARCHIVE.make_reference(archive.entries[index >> 1], "front" if index % 2 == 0 else "back"))
	for index in range(12): archive.comparison.append(ARCHIVE.make_reference(archive.entries[index], "front"))
	for index in range(600):
		var entry: Dictionary = archive.entries[index]
		var consumer := "%032x" % (index + 2000)
		for part in ["front", "back"]:
			archive.source_links.append({"consumer_kind":ARCHIVE.SOURCE_KINDS[index % 3], "consumer_uid":consumer, "target":ARCHIVE.make_reference(entry, part)})
	for entry in archive.entries: entry.protection_reasons = _reference_reasons(archive, entry)
	var original := archive.duplicate(true)
	var validation_start := Time.get_ticks_usec()
	_expect(ARCHIVE.validate(archive).ok, "dense multi-segment protection validates")
	var validation_usec := Time.get_ticks_usec() - validation_start
	var maintenance_start := Time.get_ticks_usec()
	var result := ARCHIVE.maintain(archive, archive.revision)
	var maintenance_usec := Time.get_ticks_usec() - maintenance_start
	_expect(result.ok and result.pruned_uids.is_empty(), "dense maintenance retains protected and in-quota records")
	if not result.ok: return
	for entry in result.archive.entries:
		_expect(entry.protection_reasons == _reference_reasons(original, entry), "indexed union matches independent scan: " + entry.entry_uid)
	_expect(archive == original and result.archive.entries == original.entries, "maintenance and validation preserve original content and reasons")
	var json_archive: Dictionary = JSON.parse_string(JSON.stringify(archive))
	_expect(ARCHIVE.validate(json_archive).ok, "JSON numeric conversion preserves dense protection")
	for corruption in ["missing_reason", "extra_reason", "duplicate_link", "hidden_segment", "wrong_origin", "wrong_version", "missing_uid", "invalid_kind"]:
		var damaged := archive.duplicate(true)
		match corruption:
			"missing_reason": damaged.entries[0].protection_reasons.pop_back()
			"extra_reason": damaged.entries[1199].protection_reasons.append("bookmark:front")
			"duplicate_link": damaged.source_links.append(damaged.source_links[0].duplicate(true))
			"hidden_segment": damaged.source_links[0].target.segment_id = "hidden"
			"wrong_origin": damaged.source_links[0].target.source_origin_id = "%032x" % 99999
			"wrong_version": damaged.source_links[0].target.content_version = 2
			"missing_uid": damaged.source_links[0].target.uid = "%032x" % 99999
			"invalid_kind": damaged.source_links[0].consumer_kind = "unknown"
		var damaged_before := damaged.duplicate(true)
		_expect(not ARCHIVE.validate(damaged).ok and damaged == damaged_before, "corrupt references fail without repair: " + corruption)
	for variant in ["numeric", "key_order"]:
		var changed := archive.duplicate(true)
		var target: Dictionary = changed.source_links[0].target
		if variant == "numeric": target.content_version = 1.0
		else:
			var reordered := {}
			var fields: Array = target.keys()
			fields.reverse()
			for field in fields: reordered[field] = target[field]
			changed.source_links[0].target = reordered
		_expect(ARCHIVE.validate(changed).ok, "equivalent reference remains valid: " + variant)
		changed.source_links.append(original.source_links[0].duplicate(true))
		_expect(not ARCHIVE.validate(changed).ok, "equivalent reference is still a duplicate: " + variant)
	var resolved := ARCHIVE.resolve_many(archive, [archive.source_links[0].target, archive.source_links[0].target])
	_expect(resolved.ok and resolved.items.size() == 2, "batch resolution preserves duplicate requests and order")
	if resolved.ok:
		resolved.items[0].entry.observation.segments[0].captured_text = "changed"
		resolved.items[0].segment.captured_text = "changed"
		_expect(resolved.items[1].entry == original.entries[0] and archive == original, "resolved entries and segments cannot alias another result or source")
	print("NOTEBOOK_PROTECTION_TIMING: " + JSON.stringify({"entries":1200, "source_links":1200, "validation_usec":validation_usec, "maintenance_usec":maintenance_usec, "acceptance":"MEASUREMENT_ONLY"}))


func _validate_numeric_commands() -> void:
	var archive := ARCHIVE.create()
	archive = ARCHIVE.append_observation(archive, _observation(12), 0).archive
	var ref := ARCHIVE.make_reference(archive.entries[0], "front")
	var numeric := ref.duplicate(true)
	numeric.content_version = 1.0
	for collection in ["bookmarks", "comparison"]:
		var added := ARCHIVE.set_reference(archive, collection, ref, true, archive.revision)
		var original: Dictionary = added.archive.duplicate(true)
		var again := ARCHIVE.set_reference(added.archive, collection, numeric, true, added.archive.revision)
		_expect(again.ok and not again.changed and again.archive == original, "numeric pin add is idempotent: " + collection)
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(original))
		var removed := ARCHIVE.set_reference(parsed, collection, ref, false, parsed.revision)
		_expect(removed.ok and removed.changed and removed.archive[collection].is_empty() and removed.archive.entries[0].protection_reasons.is_empty(), "numeric pin removal after JSON reload: " + collection)
		var invalid := original.duplicate(true)
		invalid[collection].append(numeric)
		_expect(not ARCHIVE.validate(invalid).ok, "mixed numeric duplicate pins rejected: " + collection)
	var consumer := "%032x" % 999
	var sources := ARCHIVE.add_source_links(archive, "document_source", consumer, [ref, numeric], archive.revision)
	_expect(sources.ok and sources.archive.source_links.size() == 1, "numeric source targets merge in one transaction")
	if not sources.ok: return
	var retry := ARCHIVE.add_source_link(sources.archive, "document_source", consumer, numeric, sources.archive.revision)
	_expect(retry.ok and not retry.changed and retry.archive == sources.archive, "numeric source link retry does not write a new revision")
	var other := ARCHIVE.add_source_link(sources.archive, "document_source", "%032x" % 998, numeric, sources.archive.revision)
	_expect(other.ok and other.archive.source_links.size() == 2, "different consumers retain separate protection")
	for bad in [true, 1.5, INF, NAN, "1", 9007199254740992.0]:
		var invalid := ref.duplicate(true)
		invalid.content_version = bad
		_expect(ARCHIVE.reference_identity(invalid).is_empty() and not ARCHIVE.set_reference(archive, "bookmarks", invalid, true, archive.revision).ok, "invalid version never becomes a canonical reference")


func _reference_reasons(archive: Dictionary, entry: Dictionary) -> Array:
	# Independent pre-index algorithm: keep this oracle separate from production helpers.
	var reasons := {}
	if entry.record_class == "authored":
		for reason in entry.observation.content_protection: reasons["content:" + reason] = true
	for collection in ["bookmarks", "comparison"]:
		for ref in archive[collection]:
			if ref.uid == entry.entry_uid: reasons[("bookmark:" if collection == "bookmarks" else "comparison:") + ref.segment_id] = true
	for link in archive.source_links:
		if link.target.uid == entry.entry_uid: reasons[link.consumer_kind + ":" + link.consumer_uid] = true
	var result := reasons.keys()
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)


func _finish() -> void:
	print("NOTEBOOK_ARCHIVE_SMOKE: " + ("PASS" if errors.is_empty() else str(errors)))
	quit(0 if errors.is_empty() else 1)
