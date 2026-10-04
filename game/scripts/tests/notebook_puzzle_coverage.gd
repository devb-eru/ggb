extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const PUBLIC := preload("res://scripts/tests/notebook_public_puzzle_labels.gd")
const SURFACE_CATALOG := "res://data/notebook/puzzle_surfaces_v1.json"
var required := {}
var errors := PackedStringArray()
var seen := {}


func _init() -> void:
	# Catalog membership, not a removable ID prefix, defines the display-suite owner.
	var surface_ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SURFACE_CATALOG)).contents
	for path in CONTENT.CATALOGS:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for id in catalog.contents:
			for version in catalog.contents[id]:
				var row: Dictionary = catalog.contents[id][version]
				if row.producer_id not in ["NP07", "NP08"]: continue
				var owner := "puzzle-surfaces" if surface_ids.has(id) else ("mirror" if row.producer_id == "NP07" else "basement")
				if int(version) == 1 and id in PUBLIC.LABELS.VERSION_TWO: owner = "historical"
				for locale in row.locales:
					for segment in row.visible_segment_ids:
						var key := JSON.stringify([id, int(version), row.action_or_variant, segment, locale])
						if required.has(key): errors.append("duplicate catalog tuple: " + key)
						required[key] = owner


func owned_ids(owner: String) -> Array:
	var ids := {}
	for key in required:
		if required[key] == owner: ids[JSON.parse_string(key)[0]] = true
	return ids.keys()


func collect(entries: Array, owner: String) -> void:
	for entry in entries:
		if owner != "historical": errors.append_array(PUBLIC.live_errors(entry))
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if observation.producer_id not in ["NP07", "NP08"]: continue
		for segment in observation.segments:
			var key := JSON.stringify([observation.content_id, int(observation.content_version), observation.variant_id, segment.segment_id, segment.viewed_locale])
			if not required.has(key):
				errors.append("unregistered observed tuple: " + key)
				continue
			if required[key] != owner: continue
			var rendered := CONTENT.render_entry(entry, segment.viewed_locale)
			if not rendered.ok or rendered.entry.get("fallback", true):
				errors.append("invalid observed source: " + key)
				continue
			seen[key] = true


func historical_report() -> Dictionary:
	var historical: Array = []
	for id in PUBLIC.LABELS.VERSION_TWO:
		var row := CONTENT.definition(id, 1)
		if row.producer_id not in ["NP07", "NP08"]: continue
		for locale in ["ko-KR", "en-US"]:
			var entry := PUBLIC.historical_entry(id, locale)
			if entry.is_empty(): errors.append("missing historical replay: " + id + ":" + locale)
			else: historical.append(entry)
	var live_seen := seen.duplicate()
	seen.clear()
	collect(historical, "historical")
	var replayed := seen.duplicate()
	seen = live_seen
	return replayed


func missing(reports: Dictionary) -> PackedStringArray:
	var result := errors.duplicate()
	for key in required:
		var owner: String = required[key]
		if not reports.get(owner, {}).has(key): result.append(owner + ": " + key)
	for owner in reports:
		for key in reports[owner]:
			if required.get(key, "") != owner: result.append("wrong coverage owner: " + owner + ": " + key)
	return result
