extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const REALITY := preload("res://scripts/systems/reality_notebook.gd")
const STORY := preload("res://scripts/systems/stay_story.gd")
const TEXT := preload("res://scripts/ui/stay_story_texts.gd")
const WRITER := preload("res://scripts/systems/notebook_event_notes.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const PREFIX := "NB_STAY_"
const NODES := ["EDS_MEMORY_CHARTER", "EDS_APPEARANCE_CONTROL", "EDS_AUTONOMY_CHARTER", "EDS_CENTRAL_HALL", "EDS_DINING_ROOM", "EDS_TABLE_OBJECTS", "EDS_FINAL_FRAME"]
const OPENING := ["주인공이 정면을 보고 앉았다. 사용인들은 과거처럼 양옆에 서 있다.", "You sit facing forward. The servants stand on either side as they once did."]
const SENSORY := ["난로 향 뒤에 금속 냄새, 새소리 뒤에 팬 회전음이 남는다.\n다섯 서명은 섞이지 않고 각자의 경계를 유지한다.", "Behind the hearth's scent remains the smell of metal; behind birdsong, the turning fan.\nThe five signatures do not merge. Each retains its own boundary."]


static func descriptor(key: String) -> Dictionary:
	var segments := {}
	for id in CONTENT.definition(PREFIX + key, 1).get("visible_segment_ids", []): segments[id] = {}
	return CONTENT.descriptor(PREFIX + key, 1, segments)


static func seating(state: Dictionary, key: String) -> Dictionary:
	var count := 0
	for servant in state.meta_progress.servants.values():
		if servant.core_event_complete: count += 1
	var segments := {"intro_" + ("low" if count < 2 else "all" if count == 5 else "four" if count == 4 else "mid"): {}}
	for owner in STORY.OWNERS:
		segments[owner + ("_sit" if count >= 2 and state.meta_progress.servants[owner].core_event_complete else "_stand")] = {}
	if key == "FINAL_SEATING": segments.sensory = {}
	return CONTENT.descriptor(PREFIX + key, 1, segments)


static func table_keys(state: Dictionary, owner: String) -> Array:
	var complete: bool = state.meta_progress.servants[owner].core_event_complete
	var keys := ["TABLE_%s_%s" % [owner.to_upper(), "COMPLETE" if complete else "INCOMPLETE"]]
	if complete and not STORY.WAKE.farewell(state, owner).warning:
		keys.append("OVERLAY_" + String(state.meta_progress.event_history[STORY.WAKE.EVENTS[owner]].outcome_id).to_upper())
	if owner == "iris": keys.append("IRIS_" + STORY.RESEARCHERS.iris_state(state).to_upper())
	return keys


static func typed_lines(state: Dictionary, lines: Array, action: String, value: Variant, prefix: String, base: Dictionary, locale: String) -> Dictionary:
	if not ROLLOUT.enabled() or state.meta_progress.dialogue_history.get("schema_version", 0) != 2: return {"ok":true, "lines":lines}
	var items: Array = []
	match prefix + action:
		"stay_memory": items.append(descriptor("MEMORY_%d" % value))
		"story_hall": items.append(descriptor("HALL_READ_" + str(value).to_upper()))
		"story_sit": items.append(seating(state, "SEATING_READ"))
		"story_table":
			for key in table_keys(state, str(value)): items.append(descriptor(key))
		_: return {"ok":true, "lines":lines}
	if items.size() != lines.size(): return {"ok":false, "error_ids":["NB_STAY_LINE_COUNT"]}
	var result := lines.duplicate(true)
	for index in range(items.size()):
		var shown := CONTENT.presentation(items[index], locale)
		if not shown.ok or shown.text != lines[index].text or shown.speaker != lines[index].speaker:
			return {"ok":false, "error_ids":["NB_STAY_DISPLAY_MISMATCH"]}
		result[index].notebook_content = items[index]
		result[index].history_context = REALITY.context(state, base)
	return {"ok":true, "lines":result}


static func write_sentence(state: Dictionary, index: int, base: Dictionary, locale: String) -> Dictionary:
	return WRITER.write(state, PREFIX + "NOTE_%d" % index, STORY.SENTENCES[index], base, locale)


static func final_text(state: Dictionary, locale: String) -> String:
	var language := 1 if locale.begins_with("en") else 0
	var opening: String = OPENING[language] if STORY.progress(state).elapsed < 2 else TEXT.seating(state, locale)
	return opening + "\n" + SENSORY[language]
