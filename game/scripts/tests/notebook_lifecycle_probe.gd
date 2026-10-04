extends RefCounted

const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const FIXTURE := preload("res://scripts/tests/notebook_performance_fixture.gd")
var errors: Array = []
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)


func _sample() -> Dictionary:
	return {"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}


func run(tree: SceneTree, fixture: Dictionary, locale: String, cycles: int) -> Dictionary:
	var before := JSON.stringify({"archive":fixture.archive, "ledger":fixture.ledger}, "", true)
	var live := JSON.stringify(GameState.get_snapshot(), "", true)
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	panel.dismiss()
	await tree.process_frame
	await tree.process_frame
	var baseline := _sample()
	var samples: Array = []
	for cycle in range(cycles):
		var result := await _cycle(tree, panel, fixture, locale, cycle)
		await tree.process_frame
		await tree.process_frame
		_expect(result.model.get_ref() == null, "cycle %d releases read model" % cycle)
		result.erase("model")
		result.closed = _sample()
		_expect(result.closed.nodes == baseline.nodes, "cycle %d returns to baseline node count" % cycle)
		_expect(result.closed.orphans == baseline.orphans, "cycle %d leaves no orphan nodes" % cycle)
		samples.append(result)
		if (cycle + 1) % 10 == 0: print("NOTEBOOK_LIFECYCLE_PROGRESS: ", fixture.manifest.fixture_id, " ", locale, " ", cycle + 1)
	_expect(JSON.stringify({"archive":fixture.archive, "ledger":fixture.ledger}, "", true) == before, "cycles preserve fixture")
	_expect(JSON.stringify(GameState.get_snapshot(), "", true) == live, "cycles never install live state")
	panel.queue_free()
	await tree.process_frame
	await tree.process_frame
	return {"ok":errors.is_empty(), "errors":errors, "checks":checks, "cycles":cycles, "baseline":baseline,
		"samples":samples, "after_panel_free":_sample(), "memory_kind":"Godot static allocator; NOT process working set or GPU",
		"input_kind":"programmatic Control calls; NOT OS input", "layout_kind":"headless 1280x720, font scales 1/1.5/2; NOT visual acceptance"}


func _cycle(tree: SceneTree, panel, fixture: Dictionary, locale: String, cycle: int) -> Dictionary:
	var model := QUERY.new()
	var model_ref: WeakRef = weakref(model)
	var scope := {"namespace":"test", "slot":"__test_notebook_lifecycle", "run_id":fixture.manifest.fixture_id,
		"source_origin_id":fixture.archive.source_origin_id, "branch_id":fixture.archive.branch_id, "load_epoch":cycle + 1}
	var start := Time.get_ticks_usec()
	_expect(model.open(fixture.archive, fixture.ledger, scope, locale).ok, "cycle read model opens")
	var key: String = model.cache_key()
	var scale: float = [1.0, 1.5, 2.0][cycle % 3]
	_expect(panel.present(model, locale, "dialogue", scale), "cycle panel presents")
	await tree.process_frame
	await tree.process_frame
	_expect(panel._close.has_focus(), "cycle initial keyboard focus")
	for tab in QUERY.TABS:
		_expect(panel.set_filters({"tab":tab, "all_sections":true}), "cycle tab is readable")
		var page: Dictionary = model.page({"tab":tab, "all_sections":true}, 0, key)
		_expect(page.ok and page.items.size() <= 50, "cycle page remains bounded")
	for index in range(12):
		model.page({"tab":"dialogue", "needle":"absent_%d" % index}, 0, key)
	# Populate the complete public search cache before testing its release.
	while model.diagnostics().indexed < model.diagnostics().index_total:
		_expect(model.index_step(key, QUERY.PAGE_SIZE).ok, "cycle public search indexing")
	_expect(model.page({"tab":"records", "all_sections":true, "needle":FIXTURE.HIDDEN}, 0, key).count == 0, "cycle hidden page never searchable")
	_expect(model._result_cache.size() <= 8 and model._order_cache.size() <= 3, "cycle query cache bounds")
	# Exercise both panel columns without changing the persistent comparison basket.
	var basket: Dictionary = model.comparison(key)
	panel._comparison_mode = true
	for index in range(basket.items.size()):
		_expect(panel.select_pair(index % 2, basket.items[index].key, false), "cycle comparison swap")
		_expect(panel.visible_pair().size() == 2, "comparison remains two columns")
	panel._comparison_mode = false
	panel._render_pair(false)
	for item in basket.items:
		var visual: Dictionary = model.visual(item.key, key)
		if visual.ok and not visual.material.is_empty():
			panel._open_visual(item.key)
			_expect(panel._visual.visible, "cycle visual opens")
			panel._close_visual()
			_expect(panel._visual._query == null, "cycle visual releases model")
	panel._open_browser("filters")
	panel._close_browser()
	_expect(panel._browser.query == null, "cycle browser releases model")
	var long_pages := 0
	for entry in fixture.archive.entries:
		if entry.record_class != "authored" or entry.observation.content_id != FIXTURE.LONG_ID: continue
		for part in entry.observation.segments:
			var ref_key: String = QUERY.reference_key(ARCHIVE.make_reference(entry, part.segment_id))
			_expect(panel.show_detail(ref_key, false, false, false), "long public page opens")
			var detail: Dictionary = model.detail(ref_key, key)
			var texts: Array = []
			var body: Node = panel._detail.find_child("NotebookMaterialBody", true, false)
			for label in body.get_children(): texts.append(label.text)
			_expect(detail.ok and detail.text == "\n".join(texts), "long public page remains complete in Control")
			var expected: String = preload("res://scripts/systems/notebook_content.gd").definition(FIXTURE.LONG_ID, 1).locales[locale][part.segment_id]
			_expect("\n".join(texts) == expected and expected.to_utf8_buffer().size() == FIXTURE.LONG_BYTES / 2, "Control preserves exact source page and UTF-8 byte count")
			_expect(FIXTURE.HIDDEN not in "\n".join(texts), "hidden page absent from Control")
			long_pages += 1
		break
	await tree.process_frame
	await tree.process_frame
	var opened := _sample()
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	panel.dismiss()
	model.close()
	_expect(panel.query == null and panel._browser.query == null and panel._visual._query == null, "dismiss releases all model references")
	_expect(not model.diagnostics().ready and model._rows.is_empty() and model._search.is_empty() and model._result_cache.is_empty() and model._order_cache.is_empty(), "close clears model and caches")
	_expect(not model.page({}, 0, key).ok, "closed key cannot read old model")
	_expect(panel._list.get_child_count() == 0 and panel._detail.get_child_count() == 0, "dismiss detaches list and detail nodes")
	for column in panel._pair_panels: _expect(column.get_child_count() == 0, "dismiss detaches comparison nodes")
	return {"cycle":cycle, "scale":scale, "exercise_ms":elapsed, "opened":opened, "long_pages":long_pages, "model":model_ref}
