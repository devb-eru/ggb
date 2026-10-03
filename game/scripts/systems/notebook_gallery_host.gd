extends CanvasLayer

# This host has no GameState/SaveManager reference. Only view preferences may be saved.
signal closed
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const MIGRATION := preload("res://scripts/systems/notebook_migration.gd")
const VIEW_STORE := preload("res://scripts/systems/notebook_view_store.gd")
const TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")
const ADAPTER_VERSION := 1
var model := QUERY.new()
var panel
var view_store := VIEW_STORE.new()
var _source: Dictionary = {}
var _scope: Dictionary = {}
var _view_scope: Dictionary = {}
var _view_state := VIEW_STORE.empty_state()
var _view_writable := true
var _view_dirty := false
var _view_delay := -1.0
var _owner: WeakRef
var _focus: WeakRef
var _owner_mode := Node.PROCESS_MODE_INHERIT
var _owner_visible := true
var _locale := "ko-KR"
var _font_scale := 1.0
var _suspended := false
var _closing := false
var _held: Dictionary = {}


func begin(owner: Control, store: EndingGalleryStore, id: String, locale: String, font_scale: float) -> bool:
	if _suspended or not is_instance_valid(owner) or not owner.is_inside_tree(): return false
	var entry := store.read_entry(id)
	if not entry.get("ok", false) or entry.id != id: return false
	var adapted := MIGRATION.adapt_verified(entry.state, id, true)
	if not adapted.ok: return false
	_source = adapted.snapshot
	var archive: Dictionary = _source.meta_progress.dialogue_history
	_scope = {"namespace": "gallery", "slot": id, "run_id": "gallery-adapter-%d:%s" % [ADAPTER_VERSION, id], "source_origin_id": archive.source_origin_id, "branch_id": archive.branch_id, "load_epoch": 0}
	_locale = "en-US" if locale.begins_with("en") else "ko-KR"
	_font_scale = font_scale
	if not _open_model(): return false
	_view_scope = VIEW_STORE.persistent_scope(_scope)
	var loaded := view_store.load_view(_view_scope, model.view_frontier())
	_view_state = loaded.state.duplicate(true)
	_view_writable = loaded.writable
	_reconcile_seen()
	layer = 40
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var root := ColorRect.new()
	root.color = Color(0.025, 0.02, 0.04, 0.99)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	root.add_child(margin)
	panel = PANEL.new()
	panel.name = "GalleryNotebook"
	margin.add_child(panel)
	panel.close_requested.connect(request_close)
	panel.refresh_requested.connect(refresh)
	panel.reference_requested.connect(_comparison_requested)
	_owner = weakref(owner)
	_owner_mode = owner.process_mode
	_owner_visible = owner.visible
	var focused := get_viewport().gui_get_focus_owner()
	_focus = weakref(focused) if focused != null else null
	_clear_pressed(owner)
	if get_viewport().has_method("gui_cancel_drag"): get_viewport().call("gui_cancel_drag")
	owner.hide()
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	_suspended = true
	_present(_view_state.general)
	panel.material_viewed.connect(_material_viewed)
	panel.view_changed.connect(_remember_view)
	if not String(loaded.warning_id).is_empty(): panel.show_notice(TEXTS.text("notebook_view_reset", _locale))
	_remember_view()
	return true


func _open_model() -> bool:
	var meta: Dictionary = _source.meta_progress
	var opened := model.open(meta.dialogue_history, meta.knowledge_entries.get(KNOWLEDGE.KEY, KNOWLEDGE.create()), _scope, _locale, meta.knowledge_entries)
	return opened.ok and model.enable_gallery_comparison()


func _present(view: Dictionary) -> void:
	panel.present(model, _locale, "clues", _font_scale)
	panel.set_reference_editable(false, true)
	panel.set_review_state(_view_state.seen, _view_state.groups)
	panel.show_notice(TEXTS.text("notebook_readonly", _locale))
	panel._close.text = TEXTS.text("back", _locale)
	if not view.is_empty(): panel.restore_view(view)


func refresh() -> void:
	if not _active() or _closing: return
	var view: Dictionary = panel.capture_view()
	var compared: Array = model.comparison(model.cache_key()).items
	_locale = "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	if not _open_model():
		panel.show_notice(TEXTS.text("notebook_unavailable", _locale))
		return
	# Rebuild only this viewing session's temporary basket; never the captured archive.
	for item in model.comparison(model.cache_key()).items:
		model.edit_gallery_comparison(JSON.parse_string(item.key), false, model.cache_key())
	for item in compared: model.edit_gallery_comparison(JSON.parse_string(item.key), true, model.cache_key())
	_present(view)


func _comparison_requested(collection: String, reference: Dictionary, enabled: bool) -> void:
	if not _active() or _closing or collection != "comparison": return
	var view: Dictionary = panel.capture_view()
	var result := model.edit_gallery_comparison(reference, enabled, model.cache_key())
	if not result.ok:
		panel.show_notice(TEXTS.text("notebook_comparison_limit" if result.get("error_id") == "NB_GALLERY_COMPARISON_LIMIT" else "notebook_unavailable", _locale))
		return
	_present(view)
	_remember_view()


func request_close() -> void:
	if not _suspended or _closing: return
	_closing = true
	get_viewport().set_input_as_handled()
	_finish_close()


func _input(event: InputEvent) -> void:
	var token := ""
	if event is InputEventKey: token = "key:%d" % (event.physical_keycode if event.physical_keycode else event.keycode)
	elif event is InputEventMouseButton and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]: token = "mouse:%d" % event.button_index
	if not token.is_empty():
		if event.is_pressed(): _held[token] = true
		else: _held.erase(token)
	if _closing: get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _suspended: return
	if event.is_action_pressed("notebook_toggle", false, true):
		var focused := get_viewport().gui_get_focus_owner()
		if not focused is LineEdit and not panel._search.has_ime_text(): request_close()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _held.clear()
	if what == NOTIFICATION_TRANSLATION_CHANGED and _suspended: refresh.call_deferred()


func _process(delta: float) -> void:
	if not _suspended: return
	if not _active():
		_held.clear()
		_closing = true
	if _view_delay >= 0:
		_view_delay -= delta
		if _view_delay <= 0: _flush_view()
	if _closing: _finish_close()


func _active() -> bool:
	var owner = _owner.get_ref() if _owner != null else null
	return _suspended and is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion()


func _finish_close() -> void:
	if not _closing or not _held.is_empty(): return
	_remember_view()
	_flush_view()
	var restored := _restore_owner()
	model.close()
	panel.dismiss()
	_source.clear()
	if restored: closed.emit()
	queue_free()


func _restore_owner() -> bool:
	var available := _active()
	_suspended = false
	if not available: return false
	var owner = _owner.get_ref()
	owner.process_mode = _owner_mode
	owner.visible = _owner_visible
	var focused = _focus.get_ref() if _focus != null else null
	if is_instance_valid(focused) and focused.is_visible_in_tree() and not (focused is BaseButton and focused.disabled): focused.grab_focus()
	return true


func _exit_tree() -> void:
	if _suspended:
		_remember_view()
		_flush_view()
		_restore_owner()
	model.close()
	_source.clear()


func _reconcile_seen() -> void:
	var catalog := model.review_catalog()
	var groups := {}
	for group in catalog.values(): groups[group] = true
	_view_state.seen = _view_state.seen.filter(func(key: String) -> bool: return catalog.has(key))
	_view_state.groups = _view_state.groups.filter(func(group: String) -> bool: return groups.has(group))


func _material_viewed(key: String) -> void:
	if not _active() or _closing: return
	var group: String = model.review_group(key)
	if group.is_empty(): return
	if key not in _view_state.seen: _view_state.seen.append(key)
	if group not in _view_state.groups: _view_state.groups.append(group)
	_remember_view()


func _remember_view() -> void:
	if not _active() or not is_instance_valid(panel) or panel._restoring_view or not panel._valid(): return
	var view: Dictionary = panel.capture_view()
	# Temporary comparisons are discarded on closing, including their back-stack views.
	view.pair = ["", ""]
	view.comparing = false
	for frame in view.back:
		if frame.has("view"): frame.view.comparing = false
	_view_state.general = view
	_view_dirty = true
	_view_delay = 0.35


func _flush_view() -> bool:
	_view_delay = -1.0
	if not _view_dirty: return true
	var saved: Dictionary = view_store.save_view(_view_scope, model.view_frontier(), _view_state) if _view_writable else {"ok": false}
	if saved.ok:
		_view_dirty = false
		return true
	if is_instance_valid(panel): panel.show_notice(TEXTS.text("notebook_view_failed", _locale))
	return false


func _clear_pressed(node: Node) -> void:
	if node is BaseButton and not node.toggle_mode: node.set_pressed_no_signal(false)
	for child in node.get_children(): _clear_pressed(child)
