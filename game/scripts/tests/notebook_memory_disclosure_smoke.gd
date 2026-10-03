extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree) -> Dictionary:
	var original := GameState.get_snapshot()
	var initial := {"archive": ARCHIVE.create(), "ledger": KNOWLEDGE.create()}
	_acquire(initial, "NB_NOTE_P_PULSE")
	_acquire(initial, "NB_CH1_NOTE_A1_SENTENCE")
	var initial_text := JSON.stringify(initial)
	_test_reference_numbers(initial)
	for locale in ["ko-KR", "en-US"]:
		var query = _open(initial, locale, "E1_ENTRY")
		var detail: Dictionary = query.detail(_key(initial, "NB_NOTE_P_PULSE"), query.cache_key())
		_expect(detail.lifetime_label.is_empty() and detail.memory_notice.is_empty(), "future current-stage value cannot substitute for disclosed proof")
		_index(query)
		_expect(query.page({"tab": "clues", "needle": "Retained record" if locale == "en-US" else "기록 유지"}, 0, query.cache_key()).count == 0, "undisclosed lifetime labels are not indexed")
	var repeated := initial.duplicate(true)
	_acquire(repeated, "NB_CH1_NOTE_A2")
	for locale in ["ko-KR", "en-US"]:
		var query = _open(repeated, locale)
		var earlier: Dictionary = query.detail(_key(repeated, "NB_CH1_NOTE_A1_SENTENCE"), query.cache_key())
		_expect(earlier.previous and earlier.epistemic == "hypothesis", "lifetime display cannot verify an earlier hypothesis")
		_expect(earlier.lifetime_label.contains("Retained record" if locale == "en-US" else "기록 유지") and earlier.memory_notice.contains("physical state reset" if locale == "en-US" else "물리 상태는 되돌아"), "A2 unlocks observed continuity, not future system explanation")
		_expect(not earlier.memory_notice.contains("not restored" if locale == "en-US" else "복구되지"), "A2 does not predict broken reset")
		_index(query)
		var results: Dictionary = query.page({"tab": "clues", "needle": "Retained record" if locale == "en-US" else "기록 유지"}, 0, query.cache_key())
		_expect(results.count == 2, "only public labels of visible current revisions enter search")
		_expect(not QUERY.match_ranges(earlier, "Retained record" if locale == "en-US" else "기록 유지").is_empty(), "lifetime label participates in exact match navigation")
	var shattered := repeated.duplicate(true)
	_acquire(shattered, "NB_FRACTURE_NOTE_D5")
	_acquire(shattered, "NB_FRACTURE_NOTE_E1_WAKE")
	var interim = _open(shattered, "ko-KR", "E1_ENTRY")
	_expect(not interim.detail(_key(shattered, "NB_NOTE_P_PULSE"), interim.cache_key()).memory_notice.contains("복구되지"), "rupture and waking expectation alone do not reveal the rest outcome")
	var broken := shattered.duplicate(true)
	_acquire(broken, "NB_FRACTURE_NOTE_E1_DIFFERENT")
	for locale in ["ko-KR", "en-US"]:
		var query = _open(broken, locale)
		var detail: Dictionary = query.detail(_key(broken, "NB_NOTE_P_PULSE"), query.cache_key())
		_expect(detail.memory_notice.contains("not restored" if locale == "en-US" else "복구되지"), "observed different morning replaces normal-reset advisory")
		_expect(not detail.memory_notice.contains("physical state reset" if locale == "en-US" else "물리 상태는 되돌아"), "post-E1 material cannot assert a normal physical reset")
		var old_key: String = query.cache_key()
		var old_ref := _key(broken, "NB_NOTE_P_PULSE")
		_expect(query.open(initial.archive, initial.ledger, _scope(initial.archive), locale).ok, "earlier snapshot reopens")
		_expect(not query.detail(old_ref, old_key).ok and query.detail(_key(initial, "NB_NOTE_P_PULSE"), query.cache_key()).memory_notice.is_empty(), "rollback invalidates cached future awareness")
		await _panel(tree, broken, locale)
	var without_a2 := {"archive": ARCHIVE.create(), "ledger": KNOWLEDGE.create()}
	_acquire(without_a2, "NB_FRACTURE_NOTE_E1_DIFFERENT")
	var no_a2 = _open(without_a2, "ko-KR")
	var no_a2_detail: Dictionary = no_a2.detail(_key(without_a2, "NB_FRACTURE_NOTE_E1_DIFFERENT"), no_a2.cache_key())
	_expect(no_a2_detail.lifetime_label.is_empty() and no_a2_detail.memory_notice.contains("복구되지"), "one disclosed fact does not synthesize missing A2 evidence")
	var uncommitted := initial.duplicate(true)
	var observed := _observe("NB_CH1_NOTE_A2")
	uncommitted.archive = ARCHIVE.append_observation(uncommitted.archive, observed, int(uncommitted.archive.revision)).archive
	var not_acquired = _open(uncommitted, "ko-KR")
	_expect(not_acquired.detail(_key(uncommitted, "NB_NOTE_P_PULSE"), not_acquired.cache_key()).memory_notice.is_empty(), "raw event ID without a committed knowledge revision cannot assert the rule")
	_test_physical_and_legacy(broken)
	_expect(JSON.stringify(initial) == initial_text and GameState.get_snapshot() == original, "public memory labels do not mutate knowledge or gameplay")
	print("NOTEBOOK_MEMORY_DISCLOSURE_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _observe(id: String) -> Dictionary:
	var definition := CONTENT.definition(id, 1)
	var descriptor := CONTENT.descriptor(id, 1, {"body": {}})
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var context := {"node_id": definition.node_ids[0], "chapter_id": "CHAPTER_1", "location_id": "M2_BEDROOM", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	var result := CONTENT.observe(descriptor, context, shown.speaker, shown.text, "ko-KR", "replay_committed")
	_expect(result.ok, "actual authored memory fixture: " + id)
	return result.observation


func _acquire(fixture: Dictionary, id: String) -> void:
	var acquired := KNOWLEDGE.acquire(fixture.ledger, fixture.archive, _observe(id), ARCHIVE.new_uid())
	_expect(acquired.ok, "acquired memory evidence: " + id)
	if acquired.ok:
		fixture.archive = acquired.archive
		fixture.ledger = acquired.ledger


func _key(fixture: Dictionary, id: String) -> String:
	for entry in fixture.archive.entries:
		if entry.record_class == "authored" and entry.observation.content_id == id:
			return QUERY.reference_key(ARCHIVE.make_reference(entry, "body"))
	return ""


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": "__test_memory", "run_id": "test", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}


func _open(fixture: Dictionary, locale: String, node: String = ""):
	var query := QUERY.new()
	_expect(query.open(fixture.archive, fixture.ledger, _scope(fixture.archive), locale, {}, node).ok, "memory read model opens")
	return query


func _index(query) -> void:
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(query.cache_key(), 50)


func _panel(tree: SceneTree, fixture: Dictionary, locale: String) -> void:
	var compared := fixture.duplicate(true)
	for id in ["NB_NOTE_P_PULSE", "NB_CH1_NOTE_A1_SENTENCE"]:
		var ref: Dictionary = JSON.parse_string(_key(compared, id))
		compared.archive = ARCHIVE.set_reference(compared.archive, "comparison", ref, true, int(compared.archive.revision)).archive
	var query = _open(compared, locale)
	var panel := PANEL.new()
	tree.root.add_child(panel)
	panel.size = Vector2(1280, 720)
	await tree.process_frame
	panel.present(query, locale, "clues", 2.0)
	panel.set_filters({"tab": "clues", "needle": "not restored" if locale == "en-US" else "복구되지"})
	_index(query)
	panel._refresh()
	var key := _key(fixture, "NB_NOTE_P_PULSE")
	_expect(panel.show_detail(key), "memory material opens at 200 percent")
	await tree.process_frame
	await tree.process_frame
	var text := ""
	for child in panel._detail.find_children("*", "RichTextLabel", true, false): text += child.get_parsed_text()
	_expect(text.contains("not restored" if locale == "en-US" else "복구되지") and not text.contains("NB_CH1_NOTE_A2"), "actual panel renders public advisory without internal ID")
	_expect(panel._matches.any(func(item: Dictionary) -> bool: return item.field == "memory_notice"), "search navigation includes visible rest advisory")
	_expect(panel.find_child("NotebookClose", true, false).is_visible_in_tree(), "large-text material retains close control")
	_expect(panel.select_pair(0, key) and panel.select_pair(1, _key(compared, "NB_CH1_NOTE_A1_SENTENCE")), "two retained materials can be selected for comparison")
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	await tree.process_frame
	for body in panel._pair_panels:
		var comparison_text := ""
		for child in body.find_children("*", "RichTextLabel", true, false): comparison_text += child.get_parsed_text()
		_expect(comparison_text.contains("not restored" if locale == "en-US" else "복구되지") and comparison_text.contains("Retained record" if locale == "en-US" else "기록 유지"), "both A/B materials show the same disclosed boundary without rewriting their hypotheses")
	panel.queue_free()
	await tree.process_frame


func _test_reference_numbers(fixture: Dictionary) -> void:
	var archive: Dictionary = fixture.archive.duplicate(true)
	var ref := ARCHIVE.make_reference(archive.entries[0], "body")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(ref))
	var old := decoded.duplicate(true)
	_expect(QUERY.reference_key(ref) == QUERY.reference_key(decoded) and decoded == old, "integral JSON content version uses the same key without rewriting caller reference")
	var invalid := ref.duplicate(true)
	invalid.content_version = "1"
	_expect(QUERY.reference_key(invalid) != QUERY.reference_key(ref), "string version is not silently coerced")
	invalid.content_version = 1.5
	_expect(QUERY.reference_key(invalid) != QUERY.reference_key(ref), "fractional version cannot alias an integer content version")
	for collection in ["bookmarks", "comparison"]:
		archive = ARCHIVE.set_reference(archive, collection, decoded, true, int(archive.revision)).archive
	_expect(ARCHIVE.validate(archive).ok, "mixed JSON and native integral references are structurally valid")
	var query = _open({"archive": archive, "ledger": fixture.ledger}, "ko-KR")
	var key := QUERY.reference_key(ref)
	var pinned: Dictionary = query.page({"tab": "clues", "bookmarks_only": true}, 0, query.cache_key())
	_expect(pinned.count == 1 and pinned.items[0].key == key, "bookmark filtering resolves mixed integral references")
	_expect(query.comparison(query.cache_key()).items.size() == 1, "comparison resolves mixed integral references")
	var reference: Dictionary = query.reference_state(key, query.cache_key())
	_expect(reference.ok and reference.bookmarks and reference.comparison, "reference buttons agree with visible bookmark and comparison lists")


func _test_physical_and_legacy(fixture: Dictionary) -> void:
	var row := CONTENT.definition("NB_NOTE_P_PULSE", 1)
	row.knowledge.knowledge_id = "TEST_PHYSICAL_NOTE"
	row.knowledge.lifetime = "physical"
	CONTENT._contents["TEST_PHYSICAL_NOTE"] = {"1": row}
	var physical := fixture.duplicate(true)
	_acquire(physical, "TEST_PHYSICAL_NOTE")
	var query = _open(physical, "ko-KR")
	_expect(query.detail(_key(physical, "TEST_PHYSICAL_NOTE"), query.cache_key()).lifetime_label.contains("재확인"), "physical lifetime is not presented as retained current state")
	CONTENT._contents.erase("TEST_PHYSICAL_NOTE")
	query = _open(physical, "ko-KR")
	var fallback: Dictionary = query.detail(_key(physical, "TEST_PHYSICAL_NOTE"), query.cache_key())
	_expect(fallback.fallback and fallback.lifetime_label.is_empty() and fallback.memory_notice.is_empty(), "missing exact version retains original without new lifetime assertions")
	var legacy_notes := {"prologue_notebook_entries": ["수첩은 영구, 루프 99. 이전 원문 자체는 그대로 보존한다."]}
	_expect(query.open(fixture.archive, fixture.ledger, _scope(fixture.archive), "ko-KR", legacy_notes).ok, "legacy mixed fixture opens")
	var legacy: Dictionary = query.page({"tab": "clues", "sources": ["legacy"]}, 0, query.cache_key())
	_expect(legacy.count == 1, "legacy original remains accessible")
	var detail: Dictionary = query.detail(legacy.items[0].key, query.cache_key())
	_expect(detail.lifetime_label.is_empty() and detail.memory_notice.is_empty() and detail.text.contains("루프 99"), "legacy wording is neither rewritten nor promoted into structured world facts")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: errors.append(message)
