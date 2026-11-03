extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const FIELD := preload("res://scripts/systems/field_notebook.gd")
const MIRROR := preload("res://data/puzzles/puzzle_black_mirror.tres")


static func options(key: String, segments: Dictionary = {}) -> Dictionary:
	var version := 2 if key == "FIELD_SUBJECT_HANDOFF_PAGE_FULL" else 1
	if key == "MIRROR_ROUTE": version = CONTENT.latest_version("NB_MODAL_MIRROR_ROUTE_OPTIONS")
	elif key == "EP02_DISCARD": version = CONTENT.latest_version("NB_MODAL_EP02_DISCARD_OPTIONS")
	elif key == "EP02_TRACE": version = CONTENT.latest_version("NB_MODAL_EP02_TRACE_OPTIONS")
	elif key == "EP02_J3_RESTORE": version = CONTENT.latest_version("NB_MODAL_EP02_J3_RESTORE_OPTIONS")
	elif key in ["EP02_J3_MEMORY", "EP02_J3_MEMORY_REPLAY"]: version = CONTENT.latest_version("NB_MODAL_" + key + "_OPTIONS")
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


static func route_options(local: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var descriptor := options("MIRROR_ROUTE")
	if descriptor.is_empty(): return descriptor
	var result := MIRROR.inspect_trace(local.rotation, local.flipped, local.anchored, local.path)
	var outcome := "result_" + ("success" if result.ok else String(result.category))
	if int(descriptor.content_version) >= 2 and result.category == "anchor_missing":
		if local.flipped: outcome = "result_overlay_flipped"
		elif int(local.rotation) == 270: outcome = "result_overlay_ccw"
		elif int(local.rotation) != 90: outcome = "result_overlay_no_rot"
	descriptor.segments[outcome] = {}
	if int(descriptor.content_version) >= 2:
		var count: int = result.verified_prefix.size()
		if count >= 1:
			descriptor.segments.dry_intro = {}
			descriptor.segments.dry_entry = {}
		if count >= 3: descriptor.segments.dry_branches = {}
		if result.ok:
			descriptor.segments.dry_ring = {}
			descriptor.segments.dry_success = {}
			descriptor.segments.dry_object_good = {}
		elif count == 0: descriptor.segments.dry_object_bad = {}
		var settings: Dictionary = AccessibilityProfileStore.new().load_profile().get("profile", {}) if profile.is_empty() else profile
		var row := CONTENT.definition(descriptor.content_id, descriptor.content_version)
		if settings.get("captions_enabled", true):
			for segment in ["caption_entry", "caption_branches", "caption_ring"]:
				var verified: bool = count >= 1 if segment == "caption_entry" else (count >= 3 if segment == "caption_branches" else result.ok)
				if verified and segment in row.visible_segment_ids: descriptor.segments[segment] = {}
		if settings.get("motion_mode", "standard") != "standard" and "motion_assist" in row.visible_segment_ids:
			descriptor.segments.motion_assist = {}
	if local.path.is_empty(): descriptor.segments.route_empty = {}
	for index in range(local.path.size()):
		descriptor.segments["route_%d_%s" % [index + 1, local.path[index]]] = {}
	return descriptor


static func route_body(descriptor: Dictionary, locale: String) -> String:
	var row := CONTENT.definition(descriptor.get("content_id", ""), int(descriptor.get("content_version", 1)))
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	var lines := PackedStringArray()
	for segment in row.get("visible_segment_ids", []):
		if descriptor.segments.has(segment) and segment != "header" and not String(segment).begins_with("option_"):
			lines.append(row.locales[language][segment])
	return "\n".join(lines)
