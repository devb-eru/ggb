class_name PracticeInventory
extends Node

signal item_added(item_id: StringName)

var _items: Array[StringName] = []


func add_item(item_id: StringName) -> bool:
	if item_id in _items:
		return false

	_items.append(item_id)
	item_added.emit(item_id)
	return true


func has_item(item_id: StringName) -> bool:
	return item_id in _items
