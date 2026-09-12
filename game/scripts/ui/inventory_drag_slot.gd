class_name InventoryDragSlot
extends Button

signal drag_started(item_id: String)

var item_id := ""
var item_label := ""
var _texts := DialogueRepository.new()


func set_inventory_item(next_item_id: String, next_label: String) -> void:
	item_id = next_item_id
	item_label = next_label
	set_meta("item_id", item_id)
	var texts := _texts
	var locale := TranslationServer.get_locale()
	text = item_label if not item_id.is_empty() else texts.get_text("UI_INV_EMPTY", locale)
	disabled = item_id.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_DRAG if not disabled else Control.CURSOR_ARROW
	tooltip_text = texts.get_text("UI_INV_DRAG_HINT" if not disabled else "UI_INV_EMPTY_DESC", locale)
	accessibility_description = texts.get_text("UI_INV_DESC", locale, {"item": item_label}) if not disabled else texts.get_text("UI_INV_EMPTY_DESC", locale)


func _get_drag_data(_at_position: Vector2) -> Variant:
	return _build_drag_payload(true)


func get_drag_payload_for_test() -> Dictionary:
	return _build_drag_payload(false)


func _build_drag_payload(include_preview: bool) -> Dictionary:
	if disabled or item_id.is_empty():
		return {}
	drag_started.emit(item_id)
	if include_preview:
		var preview := PanelContainer.new()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.035, 0.11, 0.96)
		style.border_color = Color(0.95, 0.64, 0.30, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(7)
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		preview.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = item_label
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
		preview.add_child(label)
		set_drag_preview(preview)
	return {
		"kind": "inventory_item",
		"item_id": item_id,
		"label": item_label,
	}
