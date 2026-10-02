extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
var scope: Dictionary = {}
var generation := 0
var requests: Dictionary = {}
var active: Array = []
var selections: Dictionary = {}
var occurrence := ""
var conversation := ""
var retry_required := false


func begin(current: Dictionary) -> void:
	if scope != current:
		requests.clear()
		selections.clear()
		retry_required = false
		scope = current.duplicate(true)
		occurrence = ARCHIVE.new_uid()
		conversation = ARCHIVE.new_uid()
	active.clear()
	generation += 1


func queue(id: String, text: String, locale: String, context: Dictionary) -> void:
	if id not in active: active.append(id)
	if requests.has(id) and requests[id].attempted: return
	var source := context.duplicate(true)
	if not source.has("event_occurrence_id"): source.event_occurrence_id = occurrence
	if not source.has("conversation_session_id"): source.conversation_session_id = conversation
	requests[id] = _request(id, text, locale, source)


func has_pending() -> bool:
	for id in requests:
		if (id in active or requests[id].attempted) and not requests[id].recorded: return true
	return false


func live(current: Dictionary, expected_generation: int) -> bool:
	return scope == current and generation == expected_generation


func flush(session: RefCounted, current: Dictionary, explicit_retry: bool = false) -> bool:
	if scope != current: return false
	if retry_required and not explicit_retry: return false
	for id in requests:
		var request: Dictionary = requests[id]
		if id not in active and not request.attempted: continue
		if not _write(session, request):
			retry_required = true
			return false
	retry_required = false
	return true


func choose(session: RefCounted, current: Dictionary, group: String, id: String, text: String, locale: String) -> bool:
	if group not in active or not flush(session, current): return false
	var selected: Dictionary = selections.get(group, {})
	if selected.is_empty() or selected.id != id or selected.dispatched:
		selected = _request(id, text, locale, requests[group].context)
		selected.dispatched = false
		selections[group] = selected
	return _write(session, selected)


func dispatched(group: String, success: bool) -> void:
	if selections.has(group): selections[group].dispatched = success


func _request(id: String, text: String, locale: String, source: Dictionary) -> Dictionary:
	var context := source.duplicate(true)
	context.presentation_token = ARCHIVE.new_uid()
	if not context.has("event_occurrence_id"): context.event_occurrence_id = ARCHIVE.new_uid()
	if not context.has("conversation_session_id"): context.conversation_session_id = ARCHIVE.new_uid()
	var row := CONTENT.definition(id, 1)
	var segments := {}
	for segment in row.get("visible_segment_ids", []): segments[segment] = {}
	context.notebook_content = CONTENT.descriptor(id, 1, segments)
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	return {"id": id, "text": text, "locale": locale, "context": context,
		"speaker": row.get("locales", {}).get(language, {}).get("speaker", ""), "attempted": false, "recorded": false}


func _write(session: RefCounted, request: Dictionary) -> bool:
	if request.recorded: return true
	request.attempted = true
	var result: Dictionary = session.record_viewed_line(request.speaker, request.text, request.locale, request.context)
	request.recorded = result.get("ok", false)
	return request.recorded
