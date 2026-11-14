extends Node

const ROOT := "res://scenes/ui/notebook/"
const PANEL_SCRIPT := preload("res://scripts/ui/notebook_panel.gd")
const EDITED_MATERIAL_PATH := "user://__test_notebook_material_scene.tscn"
var output := ProjectSettings.globalize_path("res://").path_join("../outputs/notebook-scenes-2026-11-15/")
var errors: Array[String] = []
var checks := 0
var stage: MarginContainer

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var window := get_tree().root
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size = Vector2i(1280, 720)
	TranslationServer.set_locale("ko-KR")
	var background := ColorRect.new()
	background.color = Color("19151e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	stage = MarginContainer.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: stage.add_theme_constant_override("margin_" + edge, 24)
	add_child(stage)
	var before := GameState.get_snapshot()
	var edited_material: PackedScene
	await _authored_previews()
	var source = preload("res://scripts/tests/notebook_query_smoke.gd").new()
	var fixture: Dictionary = source._fixture()
	_expect(fixture.get("ok", false), "existing disclosed-record fixture validates")
	if fixture.get("ok", false):
		var query = source._open(fixture)
		while query.diagnostics().indexed < query.diagnostics().index_total: query.index_step(query.cache_key(), 50)
		await _edited_panel(query)
		await _legacy_construction(query)
		await _component_edits(query)
		await _overlay_edits(query)
		edited_material = await _material_edits(query)
		query.close()
	var visual_source = preload("res://scripts/tests/notebook_visual_smoke.gd").new()
	var visual_fixture: Dictionary = visual_source._fixture()
	await _visual_component(visual_fixture)
	if edited_material != null: await _visual_material_edits(visual_fixture, edited_material)
	visual_fixture.query.close()
	DirAccess.remove_absolute(EDITED_MATERIAL_PATH)
	_expect(GameState.get_snapshot() == before, "scene editing and UI inspection preserve live gameplay state")
	var report := {"ok": errors.is_empty(), "checks": checks, "errors": errors}
	var file := FileAccess.open(output.path_join("scene-edit-audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("NOTEBOOK_SCENE_EDIT_SMOKE: ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func _authored_previews() -> void:
	for spec in [
		["notebook_panel.tscn", ["NotebookSearch", "NotebookClose", "NotebookLeftBookmarks", "NotebookToolsScroll", "BookOpen", "NotebookBrowser", "NotebookVisualViewer"], "01-authored-notebook"],
		["notebook_browser.tscn", ["NotebookBrowseBack", "NotebookBrowseScroll"], "02-authored-browser"],
		["notebook_visual_viewer.tscn", ["NotebookVisualReturn", "NotebookVisualIn", "NotebookVisualCanvas", "NotebookVisualScroll"], "03-authored-visual-viewer"],
		["notebook_overlay.tscn", ["IntegratedNotebook", "NotebookLoading", "NotebookLoadingClose"], "03b-authored-host-overlay"],
		["notebook_material.tscn", ["Field_title", "Field_location_label", "FieldSearch_title", "NotebookVisualPreview", "NotebookMaterialBody"], "03c-authored-material"],
	]:
		var packed: PackedScene = load(ROOT + spec[0])
		_expect(packed != null, "native scene exists: " + spec[0])
		if packed == null: continue
		var preview: Control = packed.instantiate()
		for name in spec[1]: _expect(preview.find_child(name, true, false) != null, "authored node exists before runtime: " + name)
		_strip_scripts(preview)
		stage.add_child(preview)
		preview.show()
		await _frames()
		_expect(preview.get_child_count() > 0 and preview.size.x > 0 and preview.size.y > 0, "native scene lays out with no runtime script: " + spec[0])
		await _shot(spec[2])
		preview.queue_free()
		await _frames()
		if spec[0] == "notebook_panel.tscn":
			var standalone = packed.instantiate()
			stage.add_child(standalone)
			await _frames()
			_expect(standalone._list.get_child_count() > 0 and standalone._detail.get_child_count() > 0, "F6-style standalone startup retains authored example records")
			_expect(standalone._chapter.text == "장: 전체", "F6-style chapter selector shows its authored selection")
			await _shot("01b-standalone-preview-with-script")
			standalone.queue_free()
			await _frames()

func _edited_panel(query) -> void:
	var edited = load(ROOT + "notebook_panel.tscn").instantiate()
	edited.theme = edited.theme.duplicate(true)
	edited.theme.default_font_size = 23
	var search: LineEdit = edited.find_child("NotebookSearch", true, false)
	search.add_theme_font_size_override("font_size", 31)
	search.custom_minimum_size.y = 53
	edited.find_child("NotebookLeftBookmarks", true, false).add_theme_constant_override("separation", 21)
	edited.find_child("NotebookArtwork", true, false).add_theme_constant_override("margin_left", 116)
	edited.find_child("BookOpen", true, false).self_modulate.a = 0.81
	var panel = _save_reload(edited, "panel")
	stage.add_child(panel)
	await _frames()
	_expect(panel.present(query, "ko-KR", "clues", 1.0), "edited panel presents actual disclosed model")
	await _frames()
	_expect(panel._list.get_children().all(func(node: Node) -> bool: return node.has_meta("reference_key")) and panel._detail.get_child_count() == 0, "actual presentation replaces examples with acquired records")
	search = panel._search
	var stable_nodes: Dictionary = {}
	for name in ["NotebookSearch", "NotebookClose", "BookOpen", "NotebookLeftBookmarks", "NotebookToolsScroll"]:
		stable_nodes[name] = panel.find_child(name, true, false).get_instance_id()
	_expect(search.get_theme_font_size("font_size") == 31 and search.custom_minimum_size.y == 53, "saved search typography and height survive startup")
	_expect(panel.theme.default_font_size == 23, "saved default typography survives model presentation")
	_expect(panel.find_child("NotebookLeftBookmarks", true, false).get_theme_constant("separation") == 21, "saved bookmark spacing survives startup")
	_expect(panel.find_child("NotebookArtwork", true, false).get_theme_constant("margin_left") == 116 and is_equal_approx(panel.find_child("BookOpen", true, false).self_modulate.a, 0.81), "saved artwork placement and tint survive startup")
	await _shot("04-edited-notebook-live")
	panel._tabs.dialogue.pressed.emit()
	await _frames()
	_expect(panel._filters.tab == "dialogue" and panel._list.get_child_count() > 0, "authored tab signal opens dialogue records")
	search.text = "일과"
	search.text_changed.emit(search.text)
	await get_tree().create_timer(0.25).timeout
	await _frames()
	_expect(panel._filters.get("needle", "") == "일과" and panel._list.get_child_count() > 0, "authored search field applies real public-record search")
	search.text_submitted.emit(search.text)
	_expect(panel._selected.is_empty(), "search submit does not select a game choice or record")
	panel._clear_search()
	panel._tabs.clues.pressed.emit()
	await _frames()
	var rows: Array = panel._list.get_children().filter(func(node: Node) -> bool: return node.has_meta("reference_key"))
	_expect(not rows.is_empty(), "disclosed clue creates an interactive row")
	if not rows.is_empty():
		var key: String = rows[0].get_meta("reference_key")
		rows[0].pressed.emit()
		_expect(panel._selected == key and panel._detail.get_child_count() > 0, "native row opens exact disclosed detail")
		await _shot("05-live-record-detail")
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	await _frames()
	_expect(panel._comparison_mode and panel.visible_pair().size() == 2 and not panel.visible_pair()[0].is_empty(), "authored comparison action reads existing saved references")
	await _shot("06-live-comparison")
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	panel.find_child("NotebookFilters", true, false).pressed.emit()
	await _frames()
	_expect(panel._browser.visible and not panel._body.visible, "authored filter action opens the native browser")
	_expect(_readable_button_width(panel._browser.find_child("NotebookBrowseBack", true, false)), "browser back label remains readable inside the notebook")
	panel._browser.find_child("NotebookBrowseBack", true, false).pressed.emit()
	await _frames()
	_expect(not panel._browser.visible and panel._body.visible, "browser back restores material area")
	panel.present(query, "ko-KR", "clues", 2.0)
	await _frames()
	_expect(panel._search.get_theme_font_size("font_size") == 62 and panel.theme.default_font_size == 46, "accessibility doubles saved authored fonts")
	await _shot("07-edited-notebook-200")
	panel.present(query, "ko-KR", "clues", 1.0)
	await _frames()
	_expect(panel._search.get_theme_font_size("font_size") == 31 and panel.theme.default_font_size == 23, "repeated presentations restore authored fonts without accumulation")
	for name in stable_nodes: _expect(panel.find_child(name, true, false).get_instance_id() == stable_nodes[name], "fixed scene node remains the same instance: " + name)
	panel.dismiss()
	panel.queue_free()
	await _frames()

func _legacy_construction(query) -> void:
	var panel = PANEL_SCRIPT.new()
	stage.add_child(panel)
	await _frames()
	_expect(panel.present(query, "ko-KR", "clues"), "legacy script.new panel callers still present models")
	_expect(panel.find_children("NotebookSearch", "LineEdit", true, false).size() == 1 and panel.find_children("NotebookClose", "Button", true, false).size() == 1, "legacy fallback creates exactly one authored control tree")
	panel.dismiss()
	panel.queue_free()
	await _frames()

func _component_edits(query) -> void:
	var edited = load(ROOT + "notebook_browser.tscn").instantiate()
	edited.add_theme_constant_override("separation", 27)
	edited.find_child("NotebookBrowseBack", true, false).add_theme_font_size_override("font_size", 35)
	var browser = _save_reload(edited, "browser")
	stage.add_child(browser)
	await _frames()
	var back: Button = browser.find_child("NotebookBrowseBack", true, false)
	var back_id := back.get_instance_id()
	browser.present("filters", query, "ko-KR", {"tab":"clues"})
	await _frames()
	_expect(browser.get_theme_constant("separation") == 27 and back.get_theme_font_size("font_size") == 35, "browser keeps saved spacing and back-button typography")
	for name in ["NotebookBrowseBack", "NotebookApplyFilters", "NotebookResetFilters"]:
		_expect(_readable_button_width(browser.find_child(name, true, false)), "browser action has room for its actual label: " + name)
	await _shot("08-edited-filters")
	browser.dismiss()
	browser.present("sessions", query, "en-US", {"tab":"dialogue"})
	await _frames()
	_expect(browser.find_child("NotebookBrowseBack", true, false).get_instance_id() == back_id and back.get_theme_font_size("font_size") == 35, "browser mode changes reuse the authored back button")
	browser.dismiss()
	browser.queue_free()
	await _frames()

func _visual_component(fixture: Dictionary) -> void:
	var edited = load(ROOT + "notebook_visual_viewer.tscn").instantiate()
	edited.add_theme_constant_override("separation", 27)
	edited.find_child("NotebookVisualIn", true, false).add_theme_font_size_override("font_size", 35)
	var viewer = _save_reload(edited, "visual")
	stage.add_child(viewer)
	await _frames()
	var zoom: Button = viewer.find_child("NotebookVisualIn", true, false)
	var zoom_id := zoom.get_instance_id()
	_expect(viewer.present(fixture.query, fixture.keys[0], "ko-KR", {}), "native viewer opens real recorded diagram")
	await _frames()
	_expect(viewer.get_theme_constant("separation") == 27 and zoom.get_theme_font_size("font_size") == 35, "visual viewer retains saved layout and typography")
	zoom.pressed.emit()
	_expect(is_equal_approx(viewer._canvas.view.zoom, 1.25), "authored zoom control adjusts only the material view")
	await _shot("09-edited-visual-viewer")
	viewer.dismiss()
	viewer.present(fixture.query, fixture.keys[1], "en-US", {})
	await _frames()
	_expect(viewer.find_child("NotebookVisualIn", true, false).get_instance_id() == zoom_id and zoom.get_theme_font_size("font_size") == 35, "viewer reuses native controls across materials and languages")
	viewer.dismiss()
	viewer.queue_free()
	await _frames()

func _overlay_edits(query) -> void:
	var edited = load(ROOT + "notebook_overlay.tscn").instantiate()
	edited.get_node("Background").color = Color("302838")
	edited.get_node("Margin").add_theme_constant_override("margin_left", 36)
	var loading: VBoxContainer = edited.get_node("Margin/NotebookLoading")
	loading.theme = loading.theme.duplicate(true)
	loading.theme.default_font_size = 24
	loading.get_node("Message").add_theme_font_size_override("font_size", 29)
	var overlay = _save_reload(edited, "overlay")
	stage.add_child(overlay)
	await _frames()
	var panel = overlay.get_node("Margin/IntegratedNotebook")
	_expect(panel.present(query, "ko-KR", "clues"), "native host overlay uses the same working panel")
	_expect(overlay.get_node("Background").color == Color("302838") and overlay.get_node("Margin").get_theme_constant("margin_left") == 36, "host backdrop and margin edits survive startup")
	var host = load("res://scripts/systems/notebook_host.gd").new()
	host._loading = overlay.get_node("Margin/NotebookLoading")
	host._loading_label = host._loading.get_node("Message")
	host._loading_retry = host._loading.get_node("NotebookLoadingRetry")
	host._loading_close = host._loading.get_node("NotebookLoadingClose")
	host._scale_loading(2.0)
	_expect(host._loading.theme.default_font_size == 48 and host._loading_label.get_theme_font_size("font_size") == 58, "actual host scales saved loading typography relatively")
	panel.hide()
	host._loading.show()
	await _shot("10-edited-loading-overlay")
	host.free()
	panel.dismiss()
	overlay.queue_free()
	await _frames()

func _material_edits(query) -> PackedScene:
	var edited = load(ROOT + "notebook_material.tscn").instantiate()
	edited.get_node("Field_title").add_theme_font_size_override("font_size", 37)
	edited.add_theme_constant_override("separation", 18)
	edited.get_node("NotebookVisualPreview").custom_minimum_size.y = 234
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK and ResourceSaver.save(packed, EDITED_MATERIAL_PATH) == OK, "save actual material-scene Inspector edits")
	edited.free()
	var material: PackedScene = ResourceLoader.load(EDITED_MATERIAL_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var edited_panel = load(ROOT + "notebook_panel.tscn").instantiate()
	edited_panel.material_scene = material
	var panel = _save_reload(edited_panel, "material_panel")
	stage.add_child(panel)
	await _frames()
	_expect(panel.material_scene.resource_path == EDITED_MATERIAL_PATH, "saved panel uses the Inspector-selected material scene")
	var result: Dictionary = query.page({"tab":"clues"}, 0, query.cache_key())
	var key: String = result.items[0].key
	for scale in [1.0, 2.0, 1.0]:
		_expect(panel.present(query, "ko-KR", "clues", scale) and panel.show_detail(key), "edited material opens the actual acquired record at scale " + str(scale))
		await _frames()
		var title: Label = panel._detail.find_child("Field_title", true, false)
		_expect(title != null and title.get_theme_font_size("font_size") == roundi(37 * scale), "material title preserves authored font with nonaccumulating relative scale " + str(scale))
		if title != null:
			_expect(title.get_parent().get_theme_constant("separation") == 18, "actual material layout keeps authored separation")
		await _shot("11-material-edits-" + str(roundi(scale * 100)))
	panel.find_child("NotebookCompare", true, false).pressed.emit()
	await _frames()
	for side in range(2):
		var title: Label = panel._pair_panels[side].find_child("Field_title", true, false)
		_expect(title != null and title.get_theme_font_size("font_size") == 37 and title.get_parent().get_theme_constant("separation") == 18, "comparison uses the same edited material scene on side " + str(side))
	await _shot("12-material-edits-comparison")
	panel.dismiss()
	panel.queue_free()
	await _frames()
	return material

func _visual_material_edits(fixture: Dictionary, material: PackedScene) -> void:
	var panel = load(ROOT + "notebook_panel.tscn").instantiate()
	panel.material_scene = material
	stage.add_child(panel)
	await _frames()
	_expect(panel.present(fixture.query, "ko-KR", "clues") and panel.show_detail(fixture.keys[0]), "edited material displays the acquired visual record")
	await _frames()
	var preview: Control = panel._detail.find_child("NotebookVisualPreview", true, false)
	_expect(preview != null and preview.visible and preview.custom_minimum_size.y == 234, "actual visual preview retains the saved material-scene height")
	await _shot("13-material-edits-visual")
	panel.dismiss()
	panel.queue_free()
	await _frames()

func _save_reload(edited: Control, id: String):
	var packed := PackedScene.new()
	var path := "user://__test_notebook_scene_" + id + ".tscn"
	_expect(packed.pack(edited) == OK and ResourceSaver.save(packed, path) == OK, "save real Inspector edits: " + id)
	edited.free()
	var reloaded = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	DirAccess.remove_absolute(path)
	return reloaded

func _strip_scripts(node: Node) -> void:
	for child in node.get_children(): _strip_scripts(child)
	node.set_script(null)

func _readable_button_width(button: Button) -> bool:
	var text_width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	return button.size.x >= text_width

func _frames() -> void:
	for index in range(5): await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(message)
