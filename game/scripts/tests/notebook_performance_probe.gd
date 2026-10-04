extends RefCounted

const FIXTURE := preload("res://scripts/tests/notebook_performance_fixture.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const SLOT := "__test_notebook_performance"
var errors: Array = []
var timings := {}


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="): return arg.trim_prefix(name + "=")
	return fallback


func _record(name: String, start: int) -> void:
	if not timings.has(name): timings[name] = []
	timings[name].append((Time.get_ticks_usec() - start) / 1000.0)


func _require(ok: bool, message: String) -> void:
	if not ok: errors.append(message)


func _counts(archive: Dictionary) -> Dictionary:
	var result := {"normal":0, "protected":0, "legacy":0}
	for entry in archive.entries:
		result["legacy" if entry.record_class == "legacy" else ("normal" if entry.protection_reasons.is_empty() else "protected")] += 1
	return result


func run(tree: SceneTree) -> Dictionary:
	var id := _arg("--nb-perf-fixture", FIXTURE.IDS[0])
	var locale := _arg("--nb-perf-locale", "ko-KR")
	var warm := int(_arg("--nb-perf-warm", "100"))
	var cycles := int(_arg("--nb-perf-cycles", "0"))
	if id not in FIXTURE.IDS or locale not in ["ko-KR", "en-US"] or warm < 0 or warm > 1000 or cycles < 0 or cycles > 100:
		return {"ok":false, "errors":["invalid benchmark arguments"]}
	var live_before := JSON.stringify(GameState.get_snapshot(), "", true)
	var build_start := Time.get_ticks_usec()
	var fixture := FIXTURE.build(id)
	_record("fixture_build_ms", build_start)
	if not fixture.get("ok", false): return fixture
	var encoded := JSON.stringify({"archive":fixture.archive, "ledger":fixture.ledger}, "", true)
	_require(encoded.sha256_text() == fixture.manifest.sha256, "deterministic input hash")
	var start := Time.get_ticks_usec()
	var decoded: Dictionary = JSON.parse_string(encoded)
	_record("fixture_parse_ms", start)
	_require(decoded == JSON.parse_string(encoded), "fixture JSON roundtrip")
	fixture.archive = decoded.archive
	fixture.ledger = decoded.ledger
	var frozen_input := JSON.stringify(decoded, "", true)
	var scope := {"namespace":"test", "slot":SLOT, "run_id":id, "source_origin_id":fixture.archive.source_origin_id,
		"branch_id":fixture.archive.branch_id, "load_epoch":1}
	var query := QUERY.new()
	var open_start := Time.get_ticks_usec()
	start = open_start
	var opened: Dictionary = query.open(fixture.archive, fixture.ledger, scope, locale)
	_record("query_open_ms", start)
	_require(opened.ok, "read model opens")
	if not opened.ok: return {"ok":false, "errors":errors}
	var key: String = query.cache_key()
	start = Time.get_ticks_usec()
	var page: Dictionary = query.page({"tab":"dialogue"}, 0, key)
	_record("first_page_model_ms", start)
	_require(page.ok and page.items.size() == 50 and query.diagnostics().render_count == 0, "first page is capped without rendering all bodies")
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	start = Time.get_ticks_usec()
	_require(panel.present(query, locale, "dialogue", 1.0), "actual panel presents")
	await tree.process_frame
	await tree.process_frame
	_record("panel_present_ms", start)
	_record("model_to_panel_ms", open_start)
	_require(panel._close.has_focus(), "first panel has a valid keyboard focus")
	print("NOTEBOOK_PERF_PHASE: ", id, " first panel ready")
	start = Time.get_ticks_usec()
	panel._search.text = "진동" if locale == "ko-KR" else "vibration"
	panel._search.text_changed.emit(panel._search.text)
	while panel._search_delay >= 0.0 or query.diagnostics().indexed < query.diagnostics().index_total:
		await tree.process_frame
		if Time.get_ticks_usec() - start > 120000000:
			errors.append("first search exceeded 120-second probe deadline")
			break
	_record("first_search_ui_ms", start)
	_require(query.diagnostics().indexed == query.diagnostics().index_total, "search index completes")
	var hidden: Dictionary = query.page({"tab":"records", "all_sections":true, "needle":FIXTURE.HIDDEN}, 0, key)
	_require(hidden.ok and hidden.complete and hidden.count == 0, "undisclosed back page never enters search")
	for level in range(2, 6):
		var unseen := preload("res://scripts/systems/notebook_content.gd").definition("NB_HINT_B3_A_H%d" % level, 1)
		var sentinel: String = unseen.locales[locale].body
		_require(query.page({"tab":"clues", "all_sections":true, "needle":sentinel}, 0, key).count == 0, "unrequested hint body is not indexed")
	panel.set_process(false)
	var baseline: Dictionary = fixture.manifest.counts
	for iteration in range(warm):
		start = Time.get_ticks_usec()
		page = query.page({"tab":"dialogue", "chapters":["CHAPTER_1", "LEGACY"]}, iteration % 40, key)
		_record("warm_page_model_ms", start)
		_require(page.ok and page.items.size() <= 50, "warm page size")
		start = Time.get_ticks_usec()
		var facets: Dictionary = query.facets({"tab":"dialogue"}, key)
		_record("warm_facets_model_ms", start)
		_require(facets.ok, "warm facets")
		for spec in [{"name":"match", "text":"진동" if locale == "ko-KR" else "vibration"},
			{"name":"miss", "text":"ABSENT_PERF_QUERY"}, {"name":"hidden", "text":FIXTURE.HIDDEN},
			{"name":"long", "text":"공개 앞면 진동 기록" if locale == "ko-KR" else "Public front vibration record"}]:
			start = Time.get_ticks_usec()
			var result: Dictionary = query.page({"tab":"dialogue", "all_sections":true, "needle":spec.text}, 0, key)
			_record("warm_search_" + spec.name + "_model_ms", start)
			_require(result.ok and result.complete, "warm search complete")
			if spec.name in ["miss", "hidden"]: _require(result.count == 0, "non-public search result empty")
		start = Time.get_ticks_usec()
		var materials: Dictionary = query.comparison(key)
		for item in materials.items.slice(0, 2): _require(query.detail(item.key, key).ok, "two comparison materials resolve")
		_record("two_materials_model_ms", start)
		start = Time.get_ticks_usec()
		var appended := ARCHIVE.append_observation(fixture.archive, FIXTURE.append_observation(fixture), int(fixture.archive.revision))
		_record("append_prune_ms", start)
		_require(appended.ok, "append and prune")
		if not appended.ok: break
		var expected: Dictionary = baseline.duplicate()
		expected.normal = mini(int(baseline.normal) + 1, ARCHIVE.NORMAL_LIMIT)
		_require(_counts(appended.archive) == expected, "normal quota does not evict protected or legacy records")
		var snapshot := GameState.make_default_snapshot()
		snapshot.meta_progress.dialogue_history = appended.archive
		start = Time.get_ticks_usec()
		var saved: Dictionary = SaveManager.save_snapshot(SLOT, "SAVE_BROKEN_RESET_COMPLETE", snapshot, 1, "NB_PERF_%d" % iteration)
		_record("durable_save_ms", start)
		_require(saved.ok, "atomic test-slot save succeeds")
		if not saved.ok: break
		if iteration == 0:
			start = Time.get_ticks_usec()
			var loaded: Dictionary = SaveManager.load_slot(SLOT)
			_record("saved_slot_load_ms", start)
			_require(loaded.ok and StateSnapshotValidator.same_persisted_value(loaded.snapshot, snapshot), "saved slot roundtrips exactly")
	_require(JSON.stringify({"archive":fixture.archive, "ledger":fixture.ledger}, "", true) == frozen_input, "profiling never mutates decoded input fixture")
	_require(JSON.stringify(GameState.get_snapshot(), "", true) == live_before, "profiling never installs a live snapshot")
	panel.dismiss()
	panel.queue_free()
	query.close()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	var lifecycle := {}
	if cycles > 0:
		lifecycle = await preload("res://scripts/tests/notebook_lifecycle_probe.gd").new().run(tree, fixture, locale, cycles)
		errors.append_array(lifecycle.errors)
	return {"ok":errors.is_empty(), "errors":errors, "manifest":fixture.manifest, "locale":locale, "warm_iterations":warm,
		"lifecycle":lifecycle,
		"timings_ms":timings, "engine":Engine.get_version_info().string, "os":OS.get_name(), "os_version":OS.get_version(),
		"cpu":OS.get_processor_name(), "cpu_threads":OS.get_processor_count(), "display":DisplayServer.get_name(),
		"acceptance":"MEASUREMENT_ONLY", "not_covered":["OS_input", "IME", "device_class_acceptance", "rendered_visual_QA",
			"OS_disk_cache_flush", "input_frame_capture", "50_open_close_memory", "warm_UI_input_p95"]}
