extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const PREFIX := "NB_CH1_SURFACE_"
const NODES := ["A1", "AS", "A2", "B1", "B2", "J1", "B3_A", "B3_B", "BF", "B4", "B5", "J2_COMPLETE"]


static func surface(key: String, values: Dictionary = {}) -> Dictionary:
	var row := CONTENT.definition(PREFIX + key, 1)
	if row.is_empty(): return {}
	var segments := {}
	for segment in row.visible_segment_ids:
		var variables := {}
		for field in row.variables[segment]:
			if not values.has(field): return {}
			variables[field] = values[field]
		segments[segment] = variables
	return CONTENT.descriptor(PREFIX + key, 1, segments)


static func fragment(id: int, front: bool) -> Dictionary:
	return surface("J1_FRAGMENT_%d_%s" % [id, "FRONT" if front else "BACK"])


static func order(parts: Array) -> Dictionary:
	var values := {}
	for index in range(parts.size()): values["part%d" % index] = str(int(parts[index]))
	return surface("J1_ORDER_%d" % parts.size(), values)


static func card(index: int, board: Dictionary) -> Dictionary:
	var clock: String = board.pieces[index]
	var back: bool = clock == "library_outer" and board.library_back
	return surface("CLOCK_CARD_" + ("LIBRARY_BACK" if back else clock.to_upper()),
		{"position": index + 1, "direction": str(int(board.rotations[index]))})


static func role(role_id: String, selected: String) -> Dictionary:
	return surface("CLOCK_ROLE_" + role_id.to_upper(), {"clock": "unset" if selected.is_empty() else selected})
