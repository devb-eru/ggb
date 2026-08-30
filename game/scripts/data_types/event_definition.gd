class_name EventDefinition
extends Resource

@export var event_id: StringName = &""
@export var category: StringName = &"system"
@export var entry_node_id: StringName = &"entry"
@export var save_point_id: StringName = &""
@export var nodes: Array[EventNodeDefinition] = []


func find_node(node_id: StringName) -> EventNodeDefinition:
	for node in nodes:
		if node.node_id == node_id:
			return node
	return null
