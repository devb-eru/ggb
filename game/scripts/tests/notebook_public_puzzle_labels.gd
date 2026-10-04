extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const LABELS := preload("res://scripts/systems/notebook_puzzle_labels.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
const PATCH := "res://data/notebook/puzzle_labels_v2.json"


static func has_internal_label(text: String) -> bool:
	var expression := RegEx.new()
	expression.compile("(^|[^A-Z0-9_])(A1|B4|C5|D4|J[1-5]|P[145]|E1|F0[-_][A-E]|F1)(?=$|[^A-Z0-9_])")
	return expression.search(text) != null


static func sample_segments(row: Dictionary) -> Dictionary:
	var segments := {}
	for segment in row.visible_segment_ids:
		var values := {}
		for key in row.variables[segment]:
			var type: String = row.variables[segment][key]
			if type == "int": values[key] = 70 if key == "opacity" else (180 if key == "degrees" else 2)
			elif type.begins_with("enum:"):
				var options: Dictionary = row.enums[type.trim_prefix("enum:")]["ko-KR"]
				values[key] = "command" if options.has("command") else options.keys()[0]
			else: values[key] = "literal archived text"
		segments[segment] = values
	return segments


static func historical_entry(id: String, locale: String) -> Dictionary:
	var row := CONTENT.definition(id, 1)
	var descriptor := CONTENT.descriptor(id, 1, sample_segments(row))
	var shown := CONTENT.presentation(descriptor, locale)
	if not shown.ok: return {}
	var context := {"chapter_id":"CHAPTER_2" if row.producer_id in ["NP07", "NP08"] else "CHAPTER_4", "node_id":row.node_ids[0],
		"location_id":"M1_LIBRARY_INNER", "event_occurrence_id":ARCHIVE.new_uid(),
		"conversation_session_id":ARCHIVE.new_uid(), "presentation_token":ARCHIVE.new_uid()}
	var observed := CONTENT.observe(descriptor, context, shown.speaker, shown.text, locale,
		"replay_committed" if row.disclosure_owner == "event_note_commit" else "displayed")
	if not observed.ok: return {}
	var appended := ARCHIVE.append_observation(ARCHIVE.create(), JSON.parse_string(JSON.stringify(observed.observation)), 0)
	return appended.archive.entries[0] if appended.ok else {}


static func catalog_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATCH))
	if catalog.contents.size() != LABELS.VERSION_TWO.size(): errors.append("public puzzle version allowlist count")
	for id in LABELS.VERSION_TWO:
		if not catalog.contents.has(id):
			errors.append("missing public puzzle row: " + id)
			continue
		var old := CONTENT.definition(id, 1)
		var current := CONTENT.definition(id, 2)
		var before := old.duplicate(true)
		var after := current.duplicate(true)
		for field in ["locales", "enums", "localization_keys", "source_symbol"]:
			before.erase(field)
			after.erase(field)
		if before != after: errors.append("public wording changed identity, geometry or disclosure: " + id)
		for locale in ["ko-KR", "en-US"]:
			var historical := historical_entry(id, locale)
			if historical.is_empty():
				errors.append("old version cannot be archived: " + id)
				continue
			var frozen := historical.duplicate(true)
			var old_descriptor := CONTENT.descriptor(id, 1, sample_segments(old))
			var descriptor := CONTENT.descriptor(id, 2, sample_segments(current))
			for language in ["ko-KR", "en-US"]:
				var replay := CONTENT.render_entry(historical, language)
				var expected := CONTENT.presentation(old_descriptor, language)
				if not replay.ok or replay.entry.text != expected.speaker + ": " + expected.text or historical != frozen:
					errors.append("historical public wording changed: " + id)
				var live := CONTENT.presentation(descriptor, language)
				if not live.ok or has_internal_label(live.text): errors.append("internal label in current public row: " + id)
			if id in VISUALS.CORE:
				var observation: Dictionary = historical.observation.duplicate(true)
				var shown := CONTENT.presentation(descriptor, locale)
				var updated := CONTENT.observe(descriptor, observation, shown.speaker, shown.text, locale)
				if not updated.ok: errors.append("new visual observation invalid: " + id)
				else:
					var entry := {"record_class":"authored", "observation":updated.observation}
					var drawing := VISUALS.material(entry, "body", locale)
					if drawing.is_empty() or drawing != VISUALS.material(historical, "body", locale): errors.append("new label changed old/new archived geometry: " + id)
	return errors


static func live_errors(entry: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if entry.get("record_class") != "authored": return errors
	var observation: Dictionary = entry.observation
	if observation.content_id not in LABELS.VERSION_TWO: return errors
	if int(observation.content_version) != 2: errors.append("live producer selected historical version: " + observation.content_id)
	for locale in ["ko-KR", "en-US"]:
		var shown := CONTENT.render_entry(entry, locale)
		if not shown.ok or has_internal_label(shown.entry.text): errors.append("live public label/replay invalid: " + observation.content_id + ":" + locale)
	return errors


static func screen_errors(view: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	for node in view.find_children("*", "", true, false):
		if not node is Control or not node.is_visible_in_tree(): continue
		var value := ""
		if node is Label or node is Button: value = node.text
		elif node is RichTextLabel: value = node.get_parsed_text()
		if has_internal_label(value): errors.append("visible internal label at " + str(node.get_path()) + ": " + value)
	return errors
