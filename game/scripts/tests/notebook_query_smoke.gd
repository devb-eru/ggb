extends RefCounted

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree) -> Dictionary:
	var state_before := GameState.get_snapshot()
	var fixture := _fixture()
	if not fixture.get("ok", false): return {"ok": false, "errors": errors}
	_test_read_model(fixture)
	_test_disclosure()
	_test_legacy_and_damage()
	_test_revisions()
	var legacy := preload("res://scripts/tests/notebook_legacy_notes_smoke.gd").new().run()
	for message in legacy.errors: _expect(false, "legacy adapter: " + message)
	await _test_panel(tree, fixture)
	var views := await preload("res://scripts/tests/notebook_view_smoke.gd").new().run(tree, fixture)
	for message in views.errors: _expect(false, "view sidecar: " + message)
	var browse := await preload("res://scripts/tests/notebook_browse_smoke.gd").new().run(tree, fixture)
	for message in browse.errors: _expect(false, "browsing: " + message)
	var visuals := await preload("res://scripts/tests/notebook_visual_smoke.gd").new().run(tree)
	for message in visuals.errors: _expect(false, "visuals: " + message)
	var search := await preload("res://scripts/tests/notebook_search_smoke.gd").new().run(tree, fixture)
	for message in search.errors: _expect(false, "search: " + message)
	var investigation := await preload("res://scripts/tests/notebook_investigation_smoke.gd").new().run(tree)
	for message in investigation.errors: _expect(false, "investigation: " + message)
	var people := preload("res://scripts/tests/notebook_person_retention_smoke.gd").new().run()
	for message in people.errors: _expect(false, "person retention: " + message)
	var memory := await preload("res://scripts/tests/notebook_memory_disclosure_smoke.gd").new().run(tree)
	for message in memory.errors: _expect(false, "memory disclosure: " + message)
	var self_mark := await preload("res://scripts/tests/notebook_self_mark_smoke.gd").new().run(tree)
	for message in self_mark.errors: _expect(false, "self mark: " + message)
	var gallery := await preload("res://scripts/tests/notebook_gallery_smoke.gd").new().run(tree)
	for message in gallery.errors: _expect(false, "gallery: " + message)
	_expect(GameState.get_snapshot() == state_before, "all read operations preserve live game state")
	print("NOTEBOOK_QUERY_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _observe(id: String, parts: Dictionary = {"body": {}}, version: int = 1, session: String = "") -> Dictionary:
	var definition := CONTENT.definition(id, version)
	var descriptor := CONTENT.descriptor(id, version, parts)
	var display := CONTENT.presentation(descriptor, "ko-KR")
	if not display.ok:
		_expect(false, "fixture presentation: " + id)
		return {}
	var context := {"node_id": definition.node_ids[0], "location_id": "M1_LIBRARY_OUTER", "chapter_id": "PROLOGUE", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": session if not session.is_empty() else ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
	var result := CONTENT.observe(descriptor, context, display.speaker, display.text, "ko-KR")
	_expect(result.ok, "fixture observation: " + id)
	return result.get("observation", {})


func _append(archive: Dictionary, observation: Dictionary) -> Dictionary:
	var result := ARCHIVE.append_observation(archive, observation, int(archive.revision))
	_expect(result.ok, "fixture append")
	return result.get("archive", archive)


func _fixture() -> Dictionary:
	var archive := ARCHIVE.create()
	var session := ARCHIVE.new_uid()
	var occurrence := ARCHIVE.new_uid()
	for index in range(105):
		if index == 100:
			session = ARCHIVE.new_uid()
			occurrence = ARCHIVE.new_uid()
		var observed := _observe("NB_PR_DUTY_1", {"body": {}}, 1, session)
		observed.event_occurrence_id = occurrence
		archive = _append(archive, observed)
	var ledger := KNOWLEDGE.create()
	var acquired := KNOWLEDGE.acquire(ledger, archive, _observe("NB_NOTE_P_PULSE"), ARCHIVE.new_uid(), [ARCHIVE.make_reference(archive.entries[0], "body")])
	_expect(acquired.ok, "fixture linked clue")
	if not acquired.ok: return {}
	archive = acquired.archive
	ledger = acquired.ledger
	for index in [0, 51, 102]:
		var ref := ARCHIVE.make_reference(archive.entries[index], "body")
		archive = ARCHIVE.set_reference(archive, "comparison", ref, true, int(archive.revision)).archive
	archive = ARCHIVE.set_reference(archive, "bookmarks", ARCHIVE.make_reference(archive.entries[51], "body"), true, int(archive.revision)).archive
	return {"ok": true, "archive": archive, "ledger": ledger}


func _scope(archive: Dictionary) -> Dictionary:
	return {"namespace": "test", "slot": "__test_readonly", "run_id": "run-one", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}


func _open(fixture: Dictionary, locale: String = "ko-KR"):
	var query := QUERY.new()
	var result: Dictionary = query.open(fixture.archive, fixture.ledger, _scope(fixture.archive), locale)
	_expect(result.ok, "query open: " + str(result.get("error_id", "")))
	return query


func _test_read_model(fixture: Dictionary) -> void:
	var before := JSON.stringify(fixture)
	var query = _open(fixture)
	var key: String = query.cache_key()
	var page: Dictionary = query.page({"tab": "dialogue"}, 0, key)
	_expect(page.ok and page.count == 105 and page.items.size() == 50 and page.pages == 3, "50 row page does not lose the 51st or final row")
	_expect(query.diagnostics().render_count == 0, "opening and paging do not render all bodies")
	_expect(page.items[0].reference.uid == fixture.archive.entries[100].entry_uid and page.items[4].reference.uid == fixture.archive.entries[104].entry_uid, "latest dialogue session first, actual order within session")
	_expect(query.page({"tab": "dialogue"}, 99, key).items.size() == 5, "invalid old page clamps to final page")
	_expect(query.page({"tab": "dialogue", "bookmarks_only": true}, 99, key).page == 0, "shrinking filters never strand an empty page")
	_expect(query.page({"tab": "dialogue", "chapters": ["PROLOGUE", "CHAPTER_1"], "speakers": ["EDGAR"]}, 0, key).count == 105, "OR within one field, AND across fields")
	_expect(query.page({"tab": "dialogue", "chapters": ["CHAPTER_2"]}, 0, key).count == 0, "chapter filter only uses captured chapter")
	_expect(query.page({"tab": "people"}, 0, key).count == 105, "only actually displayed known speakers enter people view")
	var facets: Dictionary = query.facets({"tab": "people"}, key)
	_expect(facets.values.speakers == ["EDGAR"] and facets.values.chapters == ["PROLOGUE"], "no unseen person or future chapter facet")
	_expect(not query.page({"tab": "dialogue", "secret_flag": true}, 0, key).ok, "unknown query capabilities rejected")
	var clue: Dictionary = query.page({"tab": "clues"}, 0, key)
	_expect(clue.count == 1, "knowledge source indexed once in its category")
	var detail: Dictionary = query.detail(clue.items[0].key, key)
	_expect(detail.text == "주방의 규칙적인 진동" and detail.sources.size() == 1, "authored clue and actual quoted source preserved")
	_expect(not detail.has("lifetime") and not detail.has("bond") and not detail.has("alert"), "pre-A2 view has no technical lifetime or hidden relationship values")
	var anchor: Dictionary = query.anchor_for(page.items[20].key, {"tab": "dialogue"})
	_expect(query.anchor_page({"tab": "dialogue"}, anchor, key).key == page.items[20].key, "stable UID anchor survives paging")
	var missing := anchor.duplicate(true)
	missing.key = "gone"
	_expect(query.anchor_page({"tab": "dialogue"}, missing, key).key == page.items[20].key, "missing anchor selects next stable sort key")
	var initial: Dictionary = query.page({"tab": "clues", "needle": "진동"}, 0, key)
	_expect(not initial.complete and initial.count == 0, "unbuilt index never reports final empty result")
	var renders: int = query.diagnostics().render_count
	query.index_step(key, 10000)
	_expect(query.diagnostics().render_count - renders == 50, "one index step capped at fifty disclosed segments")
	while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(key, 20)
	_expect(query.page({"tab": "clues", "needle": "진동"}, 0, key).count == 1, "incremental search reaches actual localized body")
	_expect(query.page({"tab": "dialogue", "needle": "NB_PR_DUTY_1"}, 0, key).count == 0, "internal IDs are not search keywords")
	var foreign := _scope(fixture.archive)
	foreign.load_epoch = 2
	_expect(not query.matches_scope(foreign), "load epoch invalidates callbacks even at same slot")
	var changed: Dictionary = fixture.archive.duplicate(true)
	changed.entries.clear()
	_expect(query.page({"tab": "dialogue"}, 0, key).count == 105, "query owns a frozen snapshot")
	var english = _open(fixture, "en-US")
	var en_clue: Dictionary = english.page({"tab": "clues"}, 0, english.cache_key())
	_expect(english.detail(en_clue.items[0].key, english.cache_key()).text == "The kitchen's rhythmic vibration", "same observed version can render current language")
	_expect(query.open(fixture.archive, fixture.ledger, foreign, "en-US").ok, "explicit reopen replaces frozen query")
	_expect(not query.index_step(key).ok and not query.detail(anchor.key, key).ok, "stale asynchronous result cannot apply after reopen")
	_expect(JSON.stringify(fixture) == before, "queries, links and comparison do not mutate any persistent payload")
	var json: Dictionary = JSON.parse_string(JSON.stringify(fixture))
	var roundtrip = _open(json)
	_expect(roundtrip.comparison(roundtrip.cache_key()).items.size() == 3 and roundtrip.page({"tab": "dialogue", "bookmarks_only": true}, 0, roundtrip.cache_key()).count == 1, "integral JSON versions keep bookmark and basket reference identity")
	var invalid: Dictionary = fixture.archive.duplicate(true)
	invalid.next_sequence = -1
	_expect(not QUERY.new().open(invalid, fixture.ledger, _scope(invalid), "ko-KR").ok, "structurally damaged snapshot is not rescued by display layer")


func _test_disclosure() -> void:
	for malformed in [{}, {"record_class": "authored", "observation": []}, {"record_class": "authored", "observation": {"segments": ["bad"]}}]:
		_expect(not CONTENT.render_segment(malformed, "body", "ko-KR").ok, "malformed direct segment input returns an error without a script exception")
	var archive := ARCHIVE.create()
	archive = _append(archive, _observe("NB_CH1_CH1_B1_TEXT_EDGAR", {"line_01": {}}))
	archive = _append(archive, _observe("NB_HINT_C4_H1"))
	var query = _open({"archive": archive, "ledger": KNOWLEDGE.create()}, "en-US")
	var key: String = query.cache_key()
	query.index_step(key, 50)
	var page: Dictionary = query.page({"tab": "dialogue"}, 0, key)
	_expect(page.count == 1 and page.items[0].title == "Archived record", "partial page uses safe generic metadata")
	_expect(query.detail(page.items[0].key, key).summary.is_empty(), "full-page summary cannot hint at the unread correction")
	_expect(query.page({"tab": "dialogue", "needle": "Correction:"}, 0, key).count == 0, "undisplayed line never reaches search")
	_expect(query.page({"tab": "clues"}, 0, key).count == 1, "one requested hint does not expose remaining hint count")
	var hidden := ARCHIVE.make_reference(archive.entries[0], "line_02")
	_expect(not query.detail(QUERY.reference_key(hidden), key).ok, "forged hidden segment is unavailable")
	var full := _observe("NB_CH1_CH1_B1_TEXT_EDGAR", {"line_01": {}, "line_02": {}})
	_expect(CONTENT.review_metadata(full, "en-US").title == "Archived record", "internal event IDs in authored headings are not exposed by the new UI")
	_expect(query.comparison(key).items.is_empty(), "unseen objects never prepopulate comparison")
	var mismatch := archive.duplicate(true)
	mismatch.entries[0].observation.variant_id = "wrong"
	var partial = _open({"archive": mismatch, "ledger": KNOWLEDGE.create()})
	_expect(partial.diagnostics().error_count == 1 and partial.page({"tab": "clues"}, 0, partial.cache_key()).count == 1, "content display error does not hide other valid entries")
	CONTENT._load()
	var saved: Dictionary = CONTENT._contents["NB_HINT_C4_H1"].duplicate(true)
	CONTENT._contents["NB_HINT_C4_H1"].erase("1")
	var fallback = _open({"archive": archive, "ledger": KNOWLEDGE.create()}, "en-US")
	var hint: Dictionary = fallback.page({"tab": "clues"}, 0, fallback.cache_key())
	_expect(fallback.detail(hint.items[0].key, fallback.cache_key()).fallback, "missing content version retains original instead of newer spoiler text")
	CONTENT._contents["NB_HINT_C4_H1"] = saved


func _test_legacy_and_damage() -> void:
	var legacy := {"next_sequence": 10002, "entries": []}
	for index in range(10002):
		legacy.entries.append({"sequence": index, "speaker_id": "SYSTEM", "line_id": "CH1_HISTORY_TRANSCRIPT", "variables": {"speaker": "Unknown then", "text": "legacy needle %d" % index}})
	legacy.entries[500].line_id = "NO_SUCH_OLD_TEXT"
	var migrated := ARCHIVE.migrate_verified_legacy(legacy, "query-legacy-fixture".sha256_text())
	_expect(migrated.ok, "legacy fixture migration")
	if not migrated.ok: return
	var query = _open({"archive": migrated.archive, "ledger": KNOWLEDGE.create()})
	var key: String = query.cache_key()
	_expect(query.page({"tab": "dialogue"}, 0, key).count == 10002 and query.diagnostics().render_count == 0, "10000-plus legacy rows do not cause whole-history rendering on open")
	var ref := ARCHIVE.make_reference(migrated.archive.entries[9999], "legacy")
	var detail: Dictionary = query.detail(QUERY.reference_key(ref), key)
	_expect(detail.ok and detail.legacy and detail.text.contains("legacy needle 9999"), "valid old original text survives unknown classification")
	ref = ARCHIVE.make_reference(migrated.archive.entries[500], "legacy")
	_expect(not query.detail(QUERY.reference_key(ref), key).ok, "bad legacy content reports partial display failure")
	_expect(query.page({"tab": "dialogue"}, 0, key).count == 10002, "failed rendering never deletes saved original rows")
	_expect(query.page({"tab": "people"}, 0, key).count == 0, "legacy body strings do not infer identities")


func _test_revisions() -> void:
	var first := KNOWLEDGE.acquire(KNOWLEDGE.create(), ARCHIVE.create(), _observe("NB_NOTE_P_PULSE"), ARCHIVE.new_uid())
	if not first.ok:
		_expect(false, "revision fixture")
		return
	var version := CONTENT.definition("NB_NOTE_P_PULSE", 1)
	version.knowledge.epistemic_state = "refuted"
	CONTENT._contents["NB_NOTE_P_PULSE"]["2"] = version
	var next := KNOWLEDGE.acquire(first.ledger, first.archive, _observe("NB_NOTE_P_PULSE", {"body": {}}, 2), ARCHIVE.new_uid(), [first.ledger.revisions[0].observation_ref])
	_expect(next.ok, "revision fixture update")
	if next.ok:
		var query = _open(next)
		var key: String = query.cache_key()
		_expect(query.page({"tab": "clues"}, 0, key).count == 0, "refuted and superseded revisions collapsed by default")
		_expect(query.page({"tab": "clues", "include_previous": true, "include_refuted": true}, 0, key).count == 2, "explicit prior-revision view keeps both immutable versions")
		var old_ref: Dictionary = first.ledger.revisions[0].observation_ref
		_expect(query.detail(QUERY.reference_key(old_ref), key).epistemic == "observed", "later refutation never rewrites historical epistemic status")
	CONTENT._contents["NB_NOTE_P_PULSE"].erase("2")


func _test_panel(tree: SceneTree, fixture: Dictionary) -> void:
	var query = _open(fixture)
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	_expect(panel.present(query, "ko-KR", "dialogue", 2.0), "shared panel presents at 720p / 200%")
	await tree.process_frame
	_expect(panel.find_children("NotebookRow*", "Button", true, false).size() == 50, "panel creates at most fifty result buttons")
	var close: Button = panel.find_child("NotebookClose", true, false)
	_expect(close.has_focus() and close.get_global_rect().end.y <= panel.get_global_rect().end.y, "close remains focused and reachable")
	var search: LineEdit = panel.find_child("NotebookSearch", true, false)
	search.text = "nN"
	search.text_submitted.emit("nN")
	_expect(panel._selected.is_empty() and not panel._detail_visible, "search Enter never selects a card")
	panel.set_filters({"tab": "clues"})
	var page: Dictionary = query.page({"tab": "clues"}, 0, query.cache_key())
	_expect(panel.show_detail(page.items[0].key), "clue opens actual detail")
	_expect(not panel._list_scroll.visible and panel._detail_scroll.visible, "compact mode displays list or detail without crushing either")
	var link: Dictionary = query.detail(page.items[0].key, query.cache_key())
	_expect(panel.show_detail(link.sources[0], true), "actual source link opens within panel")
	panel.show_detail(page.items[0].key, true)
	panel._back()
	_expect(panel._back_stack.size() == 1 and panel.find_child("NotebookBack", true, false) != null, "multi-hop back navigation retains the remaining return path")
	panel._back()
	_expect(panel._selected == page.items[0].key, "source navigation returns to original card")
	var basket: Dictionary = query.comparison(query.cache_key())
	_expect(basket.items.size() == 3 and panel.visible_pair().size() == 2, "three saved materials, exactly two selected slots")
	_expect(panel.select_pair(1, basket.items[2].key), "third material replaces only selected side")
	_expect(panel.visible_pair() == [basket.items[0].key, basket.items[2].key], "A/B choice retained independently")
	_expect(not panel.select_pair(0, "unseen"), "comparison rejects undisclosed or uncommitted material")
	panel._comparison_mode = true
	panel._responsive()
	_expect(panel._pair_panels[0].get_parent().visible and not panel._pair_panels[1].get_parent().visible, "compact comparison shows A/B switching, not three panes")
	panel._compact_side = 1
	panel._responsive()
	_expect(panel.visible_pair() == [basket.items[0].key, basket.items[2].key] and panel._pair_panels[1].get_parent().visible, "changing compact view never replaces selected materials")
	var english = _open(fixture, "en-US")
	_expect(panel.present(english, "en-US", "records", 1.0), "panel can switch language and caller entry tab")
	_expect(close.text == "Close" and panel._search.placeholder_text == "Search disclosed records", "English chrome is not Korean or an internal string ID")
	panel.present(query, "ko-KR", "clues", 2.0)
	var old_key: String = query.cache_key()
	query.close()
	_expect(not panel.show_detail(page.items[0].key) and not query.page({}, 0, old_key).ok, "closed model rejects stale panel callback")
	panel._process(0.0)
	_expect(panel._list.get_child_count() == 0 and panel._detail.get_child_count() == 0 and panel.visible_pair() == ["", ""], "invalidated panel clears previously rendered cross-scope text")
	panel.dismiss()
	_expect(not panel.visible and panel.query == null and panel._list.get_child_count() == 0, "dismiss releases material references and widgets")
	panel.queue_free()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(message)
