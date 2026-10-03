extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const SLOT := "__test_notebook_person_retention"
const IDS := ["NB_PR_P4_LINK_IRIS_HELLO", "NB_PR_P4_LINK_GUIDE", "NB_PR_DUTY_1", "NB_PR_P3B_COMPLETE", "NB_PR_P2_TOOL_BIRD_LINE"]
const ORDER := ["IRIS", "LUCA", "EDGAR", "MARA2", "MARA1"]
var errors := PackedStringArray()
var checks := 0


class LostAcknowledgement:
	extends Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var saved := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		return {"ok": false, "error_ids": ["TEST_ACK_LOST"]} if saved.ok else saved
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func run() -> Dictionary:
	_test_retention()
	_test_unavailable()
	_test_atomic_writer()
	print("NOTEBOOK_PERSON_RETENTION_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _observe(id: String) -> Dictionary:
	var definition := CONTENT.definition(id, 1)
	var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var context := {"node_id": definition.node_ids[0], "chapter_id": "PROLOGUE", "location_id": "M1_CENTRAL_HALL", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	var result := CONTENT.observe(descriptor, context, shown.speaker, shown.text, "ko-KR")
	_expect(result.ok, "real authored person fixture: " + id)
	return result.observation


func _raw_append(archive: Dictionary, observed: Dictionary) -> Dictionary:
	var entry := {"entry_uid": ARCHIVE.new_uid(), "source_origin_id": archive.source_origin_id, "sequence": int(archive.next_sequence), "record_class": "authored", "observation": observed.duplicate(true), "protection_reasons": []}
	archive.entries.append(entry)
	archive.next_sequence += 1
	return ARCHIVE.make_reference(entry, observed.segments[0].segment_id)


func _groups(archive: Dictionary, locale: String) -> Array:
	var query := QUERY.new()
	var scope := {"namespace": "test", "slot": SLOT, "run_id": "test", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}
	_expect(query.open(archive, KNOWLEDGE.create(), scope, locale).ok, "retained people query opens")
	return query.groups("people", {}, 0, query.cache_key()).items.map(func(item: Dictionary) -> String: return item.id)


func _test_retention() -> void:
	# An existing valid v2 save without person links must stay readable until a write.
	var archive := ARCHIVE.create()
	var refs: Array = []
	for id in IDS: refs.append(_raw_append(archive, _observe(id)))
	var normal := _observe("NB_PR_P1_INSPECT_BED")
	for index in range(2001):
		normal.presentation_token = ARCHIVE.new_uid()
		_raw_append(archive, normal)
	_expect(ARCHIVE.validate(archive).ok, "existing archive without new optional links is valid")
	var before := archive.duplicate(true)
	for locale in ["ko-KR", "en-US"]: _expect(_groups(archive, locale) == ORDER, "pre-prune disclosed ordering")
	_expect(archive == before, "viewing old save never upgrades or prunes it")
	var maintained := ARCHIVE.maintain(archive, int(archive.revision))
	_expect(maintained.ok and archive == before, "retention prepares an immutable candidate")
	if not maintained.ok: return
	var after: Dictionary = maintained.archive
	_expect(after.source_links.size() == 5 and after.entries.size() == 2005, "five first person sources protected independently of 2000 normal lines")
	_expect(maintained.pruned_uids == [archive.entries[5].entry_uid], "only oldest ordinary line pruned")
	for index in range(refs.size()):
		var resolved := ARCHIVE.resolve(after, refs[index])
		_expect(resolved.ok and resolved.entry.observation == archive.entries[index].observation, "first source UID, language, meaning and body survive")
		_expect(resolved.entry.protection_reasons.size() == 1 and resolved.entry.protection_reasons[0].begins_with("person_source:"), "first source has typed durable consumer")
	for locale in ["ko-KR", "en-US"]: _expect(_groups(after, locale) == ORDER, "post-prune disclosed ordering")
	var pinned := ARCHIVE.set_reference(after, "bookmarks", refs[0], true, int(after.revision))
	var unpinned := ARCHIVE.set_reference(pinned.archive, "bookmarks", refs[0], false, int(pinned.archive.revision))
	_expect(unpinned.ok and ARCHIVE.resolve(unpinned.archive, refs[0]).ok and unpinned.archive.source_links == after.source_links, "removing bookmark cannot release person evidence")
	var repeated := ARCHIVE.maintain(after, int(after.revision))
	_expect(repeated.ok and repeated.archive.source_links == after.source_links and repeated.pruned_uids.is_empty(), "maintenance cannot create duplicate first-person consumers")
	var forked := ARCHIVE.fork(after)
	var again := ARCHIVE.append_observation(forked.archive, _observe(IDS[0]), int(forked.archive.revision))
	_expect(again.ok and again.archive.source_links == after.source_links, "branch inherits only included first-person references, without moving them")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(after))
	_expect(ARCHIVE.validate(roundtrip).ok and _groups(roundtrip, "ko-KR") == ORDER, "JSON reload keeps first-person order and references")
	var later_only := ARCHIVE.create()
	_raw_append(later_only, _observe(IDS[2]))
	_raw_append(later_only, _observe(IDS[0]))
	var later := ARCHIVE.maintain(later_only, 0)
	_expect(later.ok and _groups(later.archive, "ko-KR") == ["EDGAR", "IRIS"], "missing pruned past is not invented or borrowed from another archive")
	var old := {"next_sequence": 1, "entries": [{"sequence": 0, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "이리스", "text": "오래된 말"}, "viewed_locale": "ko-KR"}]}
	var legacy := ARCHIVE.migrate_verified_legacy(old, "person-legacy".sha256_text())
	var legacy_maintained := ARCHIVE.maintain(legacy.archive, 0)
	_expect(legacy_maintained.ok and legacy_maintained.archive.source_links.is_empty() and legacy_maintained.archive.entries[0].legacy_payload == old.entries[0], "legacy name strings never create inferred identity")


func _test_unavailable() -> void:
	var unknown := _observe(IDS[2])
	unknown.content_version = 999
	var archive: Dictionary = ARCHIVE.append_observation(ARCHIVE.create(), unknown, 0).archive
	_expect(archive.source_links.is_empty() and _groups(archive, "en-US").is_empty(), "missing exact content version cannot prove a public person")
	var invalid := _observe(IDS[2])
	invalid.segments[0].localization_key = "WRONG"
	var candidate := ARCHIVE.append_observation(archive, invalid, int(archive.revision))
	_expect(candidate.ok and candidate.archive.source_links.is_empty(), "invalid content identity is not first-person proof")
	var valid := ARCHIVE.append_observation(candidate.archive, _observe(IDS[2]), int(candidate.archive.revision))
	_expect(valid.ok and valid.archive.source_links.size() == 1 and valid.archive.source_links[0].target.uid == valid.entry_uid, "first provable named source wins over unreadable earlier entries")
	var alias := CONTENT.definition(IDS[4], 1)
	alias.speaker_id = "MARA"
	CONTENT._contents["TEST_PERSON_ALIAS"] = {"1": alias}
	var alias_archive: Dictionary = ARCHIVE.append_observation(ARCHIVE.create(), _observe("TEST_PERSON_ALIAS"), 0).archive
	var canonical := ARCHIVE.append_observation(alias_archive, _observe(IDS[4]), int(alias_archive.revision))
	_expect(canonical.ok and canonical.archive.source_links.size() == 1 and _groups(canonical.archive, "ko-KR") == ["MARA1"], "MARA alias and MARA1 share one first-person consumer")
	CONTENT._contents.erase("TEST_PERSON_ALIAS")


func _write(observed: Dictionary, saves: Node) -> Dictionary:
	var context := observed.duplicate(true)
	context.notebook_content = CONTENT.descriptor(observed.content_id, int(observed.content_version), {"body": {}})
	var shown := CONTENT.presentation(context.notebook_content, "ko-KR")
	return WRITER.record(GameState, saves, SLOT, "SAVE_NEW_GAME", shown.speaker, shown.text, "ko-KR", "PROLOGUE", [], context)


func _test_atomic_writer() -> void:
	var original := GameState.get_snapshot()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	SaveManager.delete_test_slot(SLOT)
	GameState.reset_for_test()
	var state := GameState.get_snapshot()
	state.meta_progress.dialogue_history = ARCHIVE.create()
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"TEST_PERSON_EMPTY").ok, "install isolated person writer fixture")
	_expect(SaveManager.save_snapshot(SLOT, "SAVE_NEW_GAME", state, GameState.revision, "TEST_PERSON_BASE").ok, "write baseline snapshot")
	var before := GameState.get_snapshot()
	var paths: Dictionary = SaveManager._slot_paths(SLOT)
	var bytes := FileAccess.get_file_as_bytes(paths.main)
	var blocker := ProjectSettings.globalize_path(paths.temporary)
	_expect(DirAccess.make_dir_recursive_absolute(blocker) == OK, "isolated temporary-save failure")
	var observed := _observe(IDS[2])
	var rejected := _write(observed, SaveManager)
	_expect(not rejected.ok and GameState.get_snapshot() == before and FileAccess.get_file_as_bytes(paths.main) == bytes, "failed save rolls back both first-person link and utterance")
	_expect(DirAccess.remove_absolute(blocker) == OK, "remove isolated empty fault directory")
	var saved := _write(observed, SaveManager)
	var committed := GameState.get_snapshot()
	_expect(saved.ok and committed.meta_progress.dialogue_history.source_links.size() == 1, "successful retry persists first-person proof with the same utterance")
	var retry := _write(observed, SaveManager)
	_expect(retry.ok and GameState.get_snapshot() == committed, "acknowledged retry cannot duplicate proof or entry")
	var lost := LostAcknowledgement.new()
	var recovered := _write(_observe(IDS[1]), lost)
	lost.free()
	_expect(recovered.ok and recovered.get("recovered_acknowledgement", false), "lost acknowledgement reconciles first-person link with actual disk commit")
	committed = GameState.get_snapshot()
	var loaded := LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT)
	_expect(loaded.ok and StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), committed), "actual slot reload retains exact person sources")
	SaveManager.delete_test_slot(SLOT)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	_expect(StateWriter.new(GameState).install_snapshot(original, GameState.revision, &"TEST_PERSON_RESTORE").ok, "restore caller state")
	_expect(GameState.get_snapshot() == original, "writer regression leaves caller snapshot unchanged")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: errors.append(message)
