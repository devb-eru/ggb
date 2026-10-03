extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const MODALS := preload("res://scripts/systems/modal_notebook.gd")
const FIELD := preload("res://scripts/systems/field_notebook.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const PREFIX := "NB_REALITY_"
const FIELD_NODES := ["EDR_FIELD_NOTEBOOK", "EDR_EXIT_PANEL", "EDR_FACILITY_FREE_LOOK", "EDR_AIRLOCK_CONFIRM", "EDR_SURFACE_THRESHOLD", "EDR_FINAL_FRAME"]
const SIGNATURE := {
	"reality": ["다섯 서명이 저전력 보존 인덱스로 접힌다. 문양과 이름은 지워지지 않는다.", "The five signatures fold into the low-power preservation index. Their patterns and names are not erased."],
	"stay": ["다섯 서명이 서로의 경계를 유지한 채 저택 각 방향으로 흩어진다. 누구의 이름도 하나로 합쳐지지 않는다.", "The five signatures spread across the mansion, keeping their boundaries. No one's name is merged into another."],
}


static func context(state: Dictionary, base: Dictionary) -> Dictionary:
	var frozen := base.duplicate(true)
	frozen.node_id = state.ending_run.current_node_id
	frozen.chapter_id = "CHAPTER_4"
	frozen.location_id = state.loop_state.location_id
	return frozen


static func descriptor(key: String) -> Dictionary:
	return CONTENT.descriptor(PREFIX + key, 1, {"body": {}})


static func line_keys(state: Dictionary, action: String, value: Variant, prefix: String) -> Array:
	match prefix + action:
		"ending_continue": return ["ENTRY_READ_" + str(value)]
		"ending_identity": return ["IDENTITY_" + str(value).to_upper()]
		"ending_authority": return ["AUTHORITY"]
		"ending_sign": return ["SIGN_" + String(state.ending_run.branch_id).to_upper()]
		"reality_farewell": return WAKE.farewell(state, str(value)).notebook_keys
		"reality_continue":
			return ["DISCONNECT_HEAT", "DISCONNECT_PRESSURE", "DISCONNECT_TASTE"] if value == "EDR_DISCONNECT" else ["WAKE_BODY"]
		"reality_body":
			return ["BODY_%s_%s" % [value, "REPEAT" if value in state.ending_run.get("required_interactions_seen", []) else "FIRST"]]
		"field_inspect": return ["EXIT_READ_" + str(value)]
		"surface_inspect": return ["OBJECT_READ_" + str(value).to_upper()]
	return []


static func typed_lines(state: Dictionary, lines: Array, action: String, value: Variant, prefix: String, base: Dictionary, locale: String) -> Dictionary:
	if not ROLLOUT.enabled() or state.meta_progress.dialogue_history.get("schema_version", 0) != 2:
		return {"ok":true, "lines":lines}
	var keys := line_keys(state, action, value, prefix)
	if keys.is_empty(): return {"ok":true, "lines":lines}
	if keys.size() != lines.size(): return {"ok":false, "error_ids":["NB_REALITY_LINE_COUNT"]}
	var result := lines.duplicate(true)
	for index in range(keys.size()):
		var item := descriptor(keys[index])
		var shown := CONTENT.presentation(item, locale)
		if not shown.ok or shown.text != lines[index].text or shown.speaker != lines[index].speaker:
			return {"ok":false, "error_ids":["NB_REALITY_DISPLAY_MISMATCH:" + keys[index]]}
		result[index].notebook_content = item
		result[index].history_context = context(state, base)
	return {"ok":true, "lines":result}


static func field_descriptor(state: Dictionary, page: String, expanded: bool) -> Dictionary:
	var displayed := MODALS.field_options(state, page, expanded)
	var selected := {}
	for segment in displayed.get("segments", {}):
		if segment == "body" or String(segment).begins_with("addendum_") or String(segment).begins_with("sources_"):
			selected[segment] = displayed.segments[segment].duplicate(true)
	return CONTENT.descriptor(PREFIX + "FIELD_%s_%s" % [page, "FULL" if expanded else "SUMMARY"], 1, selected)


static func write_field(state: Dictionary, page: String, expanded: bool, base: Dictionary, locale: String) -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	if archive.get("schema_version", 0) != 2: return {"ok":true}
	var item := field_descriptor(state, page, expanded)
	var original := CONTENT.presentation(item, "ko-KR")
	if not original.ok: return original
	if original.text != FIELD.page_text(state, page, expanded): return {"ok":false, "error_ids":["NB_REALITY_FIELD_SOURCE_MISMATCH"]}
	var knowledge: Dictionary = state.meta_progress.knowledge_entries
	var ledger: Dictionary = knowledge.get(KNOWLEDGE.KEY, KNOWLEDGE.create())
	var valid := KNOWLEDGE.validate(ledger, archive)
	if not valid.ok: return valid
	var latest := {}
	for revision in ledger.revisions: latest[revision.metadata.knowledge_id] = revision
	if latest.has("REALITY_" + page):
		var previous := ARCHIVE.resolve(archive, latest["REALITY_" + page].observation_ref)
		if not previous.ok: return previous
		var old: Dictionary = previous.entry.observation
		if int(old.content_version) == 1:
			# A summary reread must not downgrade an already acquired full page.
			if not expanded and old.content_id == PREFIX + "FIELD_" + page + "_FULL": return {"ok":true, "changed":false}
			var old_segments := {}
			for segment in old.segments: old_segments[segment.segment_id] = segment.safe_variables
			if old.content_id == item.content_id and old_segments == item.segments: return {"ok":true, "changed":false}
	var sources: Array = []
	var modal_id: String = MODALS.field_options(state, page, expanded).content_id
	var displayed: Dictionary = {}
	for entry in archive.entries:
		if entry.get("record_class") == "authored" and entry.observation.content_id == modal_id: displayed = entry
	if not displayed.is_empty():
		for segment in displayed.observation.segments:
			if item.segments.has(segment.segment_id) and item.segments[segment.segment_id] == segment.safe_variables:
				sources.append(ARCHIVE.make_reference(displayed, segment.segment_id))
	# Only existing acquired sources are linked; handoff indices never invent REC documents.
	for owner in WAKE.OWNERS:
		if not state.meta_progress.servants[owner].researcher_record_acquired: continue
		if page != "SUBJECT_HANDOFF_PAGE" and FIELD.OWNERS.get(page, "") != owner: continue
		var id := "REC_" + String(owner).to_upper()
		if latest.has(id): sources.append(latest[id].observation_ref.duplicate(true))
	var frozen := base.duplicate(true)
	for key in ["event_occurrence_id", "conversation_session_id", "presentation_token"]: frozen[key] = ARCHIVE.new_uid()
	var shown := CONTENT.presentation(item, locale)
	if not shown.ok: return shown
	var observation := CONTENT.observe(item, frozen, shown.speaker, shown.text, locale, "replay_committed")
	if not observation.ok: return observation
	var acquired := KNOWLEDGE.acquire(ledger, archive, observation.observation, ARCHIVE.new_uid(), sources)
	if not acquired.ok: return acquired
	knowledge[KNOWLEDGE.KEY] = acquired.ledger
	state.meta_progress.dialogue_history = acquired.archive
	return {"ok":true, "changed":acquired.changed}
