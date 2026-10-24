extends RefCounted
## Permanent knowledge recorded in the same transaction as accepted movement.
const KEY := "visited_rooms_v1"
static var _rooms: Dictionary = {}

static func catalog() -> Dictionary:
	if _rooms.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/discovered_map.json"))
		_rooms = data.rooms
	return _rooms

static func valid(value: Variant) -> bool:
	if not value is Array or value.size() > catalog().size(): return false
	var seen := {}
	for id in value:
		if not id is String or not catalog().has(id) or seen.has(id): return false
		seen[id] = true
	return true

static func known(snapshot: Dictionary) -> Dictionary:
	var result := {}
	var meta: Dictionary = snapshot.get("meta_progress", {})
	var stored: Variant = meta.get("knowledge_entries", {}).get(KEY, [])
	if valid(stored):
		for id in stored: result[id] = true
	# Legacy saves recover only actual observations, never guessed story flags.
	for entry: Dictionary in meta.get("dialogue_history", {}).get("entries", []):
		var id := String(entry.get("observation", {}).get("location_id", entry.get("location_id", "")))
		if catalog().has(id): result[id] = true
	var current := String(snapshot.get("loop_state", {}).get("location_id", ""))
	if catalog().has(current): result[current] = true
	return result

static func remember(candidate: Dictionary, previous: Dictionary) -> void:
	var rooms := known(previous)
	rooms.merge(known(candidate))
	var ids: Array = rooms.keys()
	ids.sort()
	candidate.meta_progress.knowledge_entries[KEY] = ids
