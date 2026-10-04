extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const FIELD := preload("res://scripts/systems/field_notebook.gd")
const MIRROR := preload("res://data/puzzles/puzzle_black_mirror.tres")


static func options(key: String, segments: Dictionary = {}) -> Dictionary:
	var version := 2 if key == "FIELD_SUBJECT_HANDOFF_PAGE_FULL" else 1
	var row := CONTENT.definition("NB_MODAL_" + key + "_OPTIONS", version)
	if row.is_empty(): return {}
	var visible := segments.duplicate(true)
	if visible.is_empty():
		for id in row.default_segments: visible[id] = {}
	return CONTENT.descriptor("NB_MODAL_" + key + "_OPTIONS", version, visible)


static func field_options(state: Dictionary, page: String, expanded: bool) -> Dictionary:
	var key := "FIELD_" + page + ("_FULL" if expanded else "_SUMMARY")
	var descriptor := options(key)
	if not expanded or descriptor.is_empty(): return descriptor
	if page in FIELD.OWNERS:
		var owner: String = FIELD.OWNERS[page]
		if state.meta_progress.servants[owner].core_event_complete and not FIELD.WAKE.farewell(state, owner).warning:
			var outcome: String = state.meta_progress.event_history.get(FIELD.WAKE.EVENTS[owner], {}).get("outcome_id", "")
			descriptor.segments["addendum_" + outcome] = {}
	if page == "SUBJECT_HANDOFF_PAGE":
		var mask := FIELD.handoff_mask(state)
		descriptor.segments["sources_none" if mask == 0 else "sources_present"] = {} if mask == 0 else {"records": "mask_%02d" % mask}
	return descriptor


static func route_options(local: Dictionary) -> Dictionary:
	var descriptor := options("MIRROR_ROUTE")
	if descriptor.is_empty(): return descriptor
	var result := MIRROR.inspect_trace(local.rotation, local.flipped, local.anchored, local.path)
	descriptor.segments["result_" + ("success" if result.ok else String(result.category))] = {}
	if local.path.is_empty(): descriptor.segments.route_empty = {}
	for index in range(local.path.size()):
		descriptor.segments["route_%d_%s" % [index + 1, local.path[index]]] = {}
	return descriptor


static func route_body(descriptor: Dictionary, locale: String) -> String:
	var row := CONTENT.definition(descriptor.get("content_id", ""), 1)
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	var lines := PackedStringArray()
	for segment in row.get("visible_segment_ids", []):
		if descriptor.segments.has(segment) and segment != "header" and not String(segment).begins_with("option_"):
			lines.append(row.locales[language][segment])
	return "\n".join(lines)
