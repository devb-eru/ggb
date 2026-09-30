class_name InventoryDropTarget
extends Button

signal inventory_item_dropped(item_id: String, target_id: String)

var target_id := ""
var accepted_item_ids := PackedStringArray()
var drop_enabled := true


func configure(next_target_id: String, next_accepted_item_ids: PackedStringArray = PackedStringArray()) -> void:
	target_id = next_target_id
	accepted_item_ids = next_accepted_item_ids.duplicate()
	tooltip_text = "인벤토리 아이템을 이곳에 놓습니다."


func set_drop_enabled(enabled: bool) -> void:
	drop_enabled = enabled
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if enabled else Control.CURSOR_FORBIDDEN


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drop_enabled or not (data is Dictionary):
		return false
	if String(data.get("kind", "")) != "inventory_item":
		return false
	var dropped_item_id := String(data.get("item_id", ""))
	return not dropped_item_id.is_empty() and (accepted_item_ids.is_empty() or dropped_item_id in accepted_item_ids)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	inventory_item_dropped.emit(String(data.get("item_id", "")), target_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		self_modulate = Color(1.10, 1.04, 0.92, 1.0) if drop_enabled else Color(0.72, 0.72, 0.72, 1.0)
	elif what == NOTIFICATION_DRAG_END:
		self_modulate = Color.WHITE
