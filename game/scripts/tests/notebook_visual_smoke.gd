extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
const STORE := preload("res://scripts/systems/notebook_view_store.gd")
const SURFACES := preload("res://scripts/systems/notebook_puzzle_surfaces.gd")
const CORE_BOARD := preload("res://scripts/chapters/core_overlay_board.gd")
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree) -> Dictionary:
	var before := GameState.get_snapshot()
	var fixture := _fixture()
	_test_geometry(fixture)
	_test_disclosure(fixture)
	await _test_panel(tree, fixture)
	_expect(before == GameState.get_snapshot(), "all visual inspection leaves live puzzle and gameplay state unchanged")
	print("NOTEBOOK_VISUAL_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}


func _observe(id: String, segments: Dictionary, version: int = 1) -> Dictionary:
	var row := CONTENT.definition(id, version)
	var descriptor := CONTENT.descriptor(id, version, segments)
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	var observed := CONTENT.observe(descriptor, {"node_id": row.node_ids[0], "location_id": "M1_MIRROR_GALLERY", "chapter_id": "CHAPTER_2", "event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}, shown.speaker, shown.text, "ko-KR", "replay_committed" if row.disclosure_owner == "event_note_commit" else "displayed")
	_expect(observed.ok, "observed visual fixture: " + id)
	return observed.observation


func _fixture() -> Dictionary:
	var archive := ARCHIVE.create()
	var ledger := KNOWLEDGE.create()
	var keys: Array = []
	for id in VISUALS.ORIGINALS:
		var acquired := KNOWLEDGE.acquire(ledger, archive, _observe(id, {"body": {}}), ARCHIVE.new_uid())
		_expect(acquired.ok, "original material acquired atomically")
		archive = acquired.archive
		ledger = acquired.ledger
		var ref := ARCHIVE.make_reference(archive.entries.back(), "body")
		var pinned := ARCHIVE.set_reference(archive, "comparison", ref, true, int(archive.revision))
		_expect(pinned.ok, "visual comparison reference uses the normal protection contract")
		archive = pinned.archive
		keys.append(QUERY.reference_key(ref))
	_expect(KNOWLEDGE.validate(ledger, archive).ok, "three original materials and comparison references are valid")
	var scope := {"namespace": "test", "slot": "__test_visual", "run_id": "visual", "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 1}
	var query := QUERY.new()
	_expect(query.open(archive, ledger, scope, "ko-KR").ok, "visual query opens")
	return {"archive": archive, "ledger": ledger, "keys": keys, "scope": scope, "query": query}


func _test_geometry(fixture: Dictionary) -> void:
	for key in fixture.keys:
		var result: Dictionary = fixture.query.visual(key, fixture.query.cache_key())
		_expect(result.ok and not result.material.paths.is_empty() and not result.material.description.is_empty(), "acquired original has a diagram and non-colour description")
	var wave: Dictionary = fixture.query.visual(fixture.keys[0], fixture.query.cache_key()).material
	_expect(wave.paths.all(func(path: Dictionary) -> bool: return path.dashed) and wave.squares.size() == 1, "waveform differentiated by dashes and square without colour")
	var ports: Dictionary = fixture.query.visual(fixture.keys[2], fixture.query.cache_key()).material
	_expect(ports.circles.size() == 5 and ports.paths.size() == 4, "early port original has only central and four outer ports, no later solution targets")
	for layer in ["B4", "C5", "D4"]:
		var definition := CONTENT.definition("NB_CORE_SCREEN_C_LAYER_" + layer, 1)
		var canonical: Dictionary = JSON.parse_string(JSON.stringify(CORE_BOARD.visual_manifest(layer)))
		_expect(definition.visual == canonical, "frozen core source geometry agrees with original board manifest after JSON numeric normalization")
		for degrees in [0, 90, 180, 270]:
			for flipped in ["no", "yes"]:
				var values := {"degrees": degrees, "flipped": flipped, "anchor": "1", "opacity": 20}
				var entry := {"record_class": "authored", "observation": _observe("NB_CORE_SCREEN_C_LAYER_" + layer, {"body": values})}
				var visual := VISUALS.material(entry, "body", "en-US")
				_expect(not visual.is_empty() and visual.paths.size() == 1, "observed core replay exposes only one layer")
				var raw: Array = definition.visual.path.back()
				var expected := Vector2(raw[0], raw[1])
				if flipped == "yes": expected.x *= -1
				expected = expected.rotated(deg_to_rad(degrees)) + Vector2.RIGHT
				var actual: Array = visual.paths[0].points.back()
				_expect(expected.is_equal_approx(Vector2(actual[0], actual[1])), "replay honors archived transform, never current puzzle rotation")
				var current := {"record_class":"authored", "observation":_observe("NB_CORE_SCREEN_C_LAYER_" + layer, {"body":values}, 2)}
				_expect(VISUALS.supports(current, "body") and VISUALS.material(current, "body", "en-US") == visual, "new public label retains the exact archived one-layer drawing")
				current.observation.content_version = 3
				_expect(not VISUALS.supports(current, "body") and VISUALS.material(current, "body", "en-US").is_empty(), "unknown future core version does not receive a current drawing")
	for rotation in [0, 90, 180, 270]:
		var descriptor := SURFACES.trace({"rotation": rotation, "flipped": true, "anchored": false, "path": []}, true)
		var entry := {"record_class": "authored", "observation": _observe(descriptor.content_id, descriptor.segments)}
		var material := VISUALS.material(entry, "state", "ko-KR")
		_expect(material.paths.size() == 6 and material.squares.size() == 1, "seen mirror overlay retains both recorded patterns")
		_expect(VISUALS.material(entry, "title", "ko-KR").is_empty(), "opening just the overlay title cannot disclose its diagram")


func _test_disclosure(fixture: Dictionary) -> void:
	_expect(not fixture.query.visual("not-acquired", fixture.query.cache_key()).ok, "unacquired material is not synthesized from a template")
	_expect(not fixture.query.visual(fixture.keys[0], "old").ok, "visual query rejects stale scope")
	var future: Dictionary = fixture.archive.entries[0].duplicate(true)
	future.observation.content_version = 999
	_expect(not VISUALS.supports(future, "body") and VISUALS.material(future, "body", "ko-KR").is_empty(), "unknown content version never receives today's drawing")
	var hidden: Dictionary = fixture.archive.entries[0].duplicate(true)
	hidden.observation.segments = []
	_expect(not VISUALS.supports(hidden, "body"), "missing segment has no visual capability")
	var en := QUERY.new()
	_expect(en.open(fixture.archive, fixture.ledger, fixture.scope, "en-US").ok, "English visual query opens")
	_expect(en.visual(fixture.keys[0], en.cache_key()).material.title == "Recorded waveform", "visual labels follow UI locale without rewriting source")
	var malformed := ARCHIVE.append_observation(ARCHIVE.create(), _observe("NB_CORE_SCREEN_C_LAYER_B4", {"body": {"degrees": 360, "flipped": "no", "anchor": "0", "opacity": 70}}), 0)
	_expect(malformed.ok, "shape-range fixture keeps valid textual observation")
	var scope: Dictionary = fixture.scope.duplicate()
	scope.source_origin_id = malformed.archive.source_origin_id
	scope.branch_id = malformed.archive.branch_id
	var query := QUERY.new()
	_expect(query.open(malformed.archive, KNOWLEDGE.create(), scope, "ko-KR").ok, "text remains readable when its visual parameters cannot be replayed")
	var key := QUERY.reference_key(ARCHIVE.make_reference(malformed.archive.entries[0], "body"))
	_expect(query.detail(key, query.cache_key()).ok and not query.visual(key, query.cache_key()).ok and query.diagnostics().error_count == 1, "visual failure is diagnostic, not whole-record loss or silent fallback to another drawing")
	for invalid in [{"zoom": NAN, "x": 0, "y": 0}, {"zoom": 1, "x": false, "y": 0}, {"zoom": 5, "x": 0, "y": 0}, {"zoom": 2, "x": 2, "y": 0}, {"zoom": 1, "x": 0, "y": 0, "turn": 90}]:
		_expect(not VISUALS.valid_view(invalid), "invalid or gameplay transform fields rejected from view state")


func _test_panel(tree: SceneTree, fixture: Dictionary) -> void:
	var panel := PANEL.new()
	panel.size = Vector2(1280, 720)
	tree.current_scene.add_child(panel)
	await tree.process_frame
	panel.present(fixture.query, "ko-KR", "clues", 2.0)
	panel.show_detail(fixture.keys[0])
	var open: Button = panel._detail.find_child("NotebookVisualOpen_" + String(fixture.keys[0]).sha256_text(), true, false)
	_expect(open != null and panel._detail.find_child("NotebookVisualPreview", true, false) != null, "actual detail contains preview and explicit enlargement")
	open.grab_focus()
	open.pressed.emit()
	_expect(panel._visual.visible and not panel._body.visible and panel._visual._return.has_focus(), "enlargement is a separate focus layer")
	panel._visual.find_child("NotebookVisualIn", true, false).pressed.emit()
	panel._visual.find_child("NotebookVisualRight", true, false).pressed.emit()
	var position: Dictionary = panel._visual._canvas.view.duplicate()
	_expect(position.zoom == 1.25 and position.x > 0, "mouse-only buttons provide zoom and pan")
	panel._visual._canvas.grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	panel._visual._canvas._gui_input(right)
	_expect(panel._visual._canvas.view.x > position.x, "direction keys pan only the focused material")
	position = panel._visual._canvas.view.duplicate()
	panel._close.grab_focus()
	panel._visual._canvas._gui_input(right)
	_expect(panel._visual._canvas.view == position, "direction key outside material focus cannot pan a hidden input target")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._unhandled_key_input(escape)
	_expect(not panel._visual.visible and panel.visible and open.has_focus(), "Esc returns to material and its original focus without closing notebook")
	panel.select_pair(0, fixture.keys[0])
	panel.select_pair(1, fixture.keys[2])
	panel._comparison_mode = true
	panel._render_pair()
	panel._compact_side = 1
	panel._responsive()
	panel._open_visual(fixture.keys[2])
	panel._visual.find_child("NotebookVisualIn", true, false).pressed.emit()
	panel._close_visual()
	_expect(panel._comparison_mode and panel._pair == [fixture.keys[0], fixture.keys[2]] and panel._compact_side == 1, "enlargement returns to the same A/B selections and compact side")
	panel.select_pair(1, fixture.keys[1])
	_expect(panel._pair_panels[1].find_child("NotebookVisualPreview", true, false) != null, "third visual can replace one side of the comparison")
	var view := panel.capture_view()
	_expect(view.visuals[fixture.keys[0]] == position and view.visuals.size() == 2, "each visual keeps independent position keyed by observed reference")
	var state := STORE.empty_state()
	state.general = view
	var store := STORE.new("user://__test_visual_view")
	var scope := STORE.persistent_scope(fixture.scope)
	_expect(store.save_view(scope, fixture.query.view_frontier(), state).ok, "visual positions persist outside game state")
	var loaded := store.load_view(scope, fixture.query.view_frontier())
	_expect(loaded.source == "primary" and loaded.state.general.visuals == view.visuals, "actual file round trip preserves zoom and normalized pan")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.paths(scope).main))
	_expect(envelope.version == STORE.VERSION, "visual convenience state writes the current sidecar version")
	var old: Dictionary = JSON.parse_string(envelope.payload)
	old.state.general.erase("visuals")
	envelope.version = 2
	envelope.payload = JSON.stringify(old, "", true, true)
	envelope.checksum = String(envelope.payload).sha256_text()
	var file := FileAccess.open(store.paths(scope).main, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_expect(store.load_view(scope, fixture.query.view_frontier()).source == "primary", "real pre-visual version-two preferences remain readable without synthesizing visual state")
	var invalid := state.duplicate(true)
	invalid.general.visuals = {"unknown": {"zoom": INF, "x": 0, "y": 0}}
	_expect(not STORE.valid_state(invalid), "non-finite visual preference cannot reach storage")
	invalid.general.visuals.clear()
	for index in range(65): invalid.general.visuals[str(index)] = {"zoom": 1, "x": 0, "y": 0}
	_expect(not STORE.valid_state(invalid), "position cache bound is independent of unpruned game records")
	panel.restore_view(loaded.state.general)
	await tree.process_frame
	await tree.process_frame
	panel._open_visual(fixture.keys[0])
	_expect(panel._visual._canvas.view == position, "view restoration returns to stored material position")
	panel._visual.find_child("NotebookVisualReset", true, false).pressed.emit()
	_expect(panel._visual._canvas.view == {"zoom": 1.0, "x": 0.0, "y": 0.0}, "default-position button does not invoke puzzle reset")
	await tree.process_frame
	_expect(panel._close.get_global_rect().end.y <= panel.get_global_rect().end.y and panel._visual._return.get_global_rect().end.y <= panel.get_global_rect().end.y, "close and visual return remain visible at 720p and 200 percent text")
	var stale: Button = panel._visual.find_child("NotebookVisualIn", true, false)
	panel.dismiss()
	stale.pressed.emit()
	_expect(not panel._visual.visible and panel._visual_views.is_empty(), "dismiss frees material and invalidates old zoom callbacks")
	for path in store.paths(scope).values():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://__test_visual_view")
	panel.queue_free()
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_VISUAL_FAIL: ", message)
