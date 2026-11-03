extends RefCounted

const SOURCE := "res://data/dialogue/sheets/prologue_runtime.json"
static var _source: Dictionary = {}
static var _nodes: Dictionary = {}


static func source() -> Dictionary:
	if _source.is_empty() and FileAccess.file_exists(SOURCE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if parsed is Dictionary:
			_source = parsed
			for row in parsed.get("nodes", []):
				if row.get("package_id") == "CNT-EP00": _nodes[row.node_id] = row
	return _source


static func node(key: String) -> Dictionary:
	source()
	var identity: String = _source.get("prologue_aliases", {}).get(key, key)
	return _nodes.get(identity, {}).duplicate(true)


static func response_ids(key: String) -> Array:
	return source().get("prologue_response_sequences", {}).get(key, [key]).duplicate()


static func render_overrides(key: String) -> Dictionary:
	source()
	var identity: String = _source.get("prologue_aliases", {}).get(key, key)
	return _source.get("prologue_render_overrides", {}).get(identity, {}).duplicate(true)
