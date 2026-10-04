extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const RECEIPT := preload("res://scripts/systems/notebook_surface_receipt.gd")
var scope: Dictionary = {}
var generation := 0
var requests: Dictionary = {}
var active: Array = []
var selections: Dictionary = {}
var occurrence := ""
var conversation := ""
var retry_required := false
var resume_receipts := {}


func begin(current: Dictionary, state: Dictionary = {}) -> void:
	if scope != current:
		var can_resume: bool = scope.is_empty() or scope.get("load_epoch") != current.get("load_epoch") or scope.get("session") != current.get("session")
		requests.clear()
		selections.clear()
		retry_required = false
		scope = current.duplicate(true)
		occurrence = ARCHIVE.new_uid()
		conversation = ARCHIVE.new_uid()
		resume_receipts = {}
		var saved := RECEIPT.read(state, current) if can_resume else {}
		if not saved.is_empty():
			occurrence = saved.occurrence
			conversation = saved.conversation
			resume_receipts = saved.receipts
	active.clear()
	generation += 1


func queue(id: String, text: String, locale: String, context: Dictionary, new_attempt: bool = false) -> void:
	if id not in active: active.append(id)
	if requests.has(id) and requests[id].attempted and (not new_attempt or not requests[id].recorded): return
	var source := context.duplicate(true)
	if new_attempt:
		source.event_occurrence_id = ARCHIVE.new_uid()
		source.conversation_session_id = ARCHIVE.new_uid()
	if not source.has("event_occurrence_id"): source.event_occurrence_id = occurrence
	if not source.has("conversation_session_id"): source.conversation_session_id = conversation
	requests[id] = _request(id, text, locale, source)
	_attach_receipt(requests[id], new_attempt)


func has_pending() -> bool:
	for id in requests:
		if (id in active or requests[id].attempted) and not requests[id].recorded: return true
	return false


func queue_descriptor(descriptor: Dictionary, text: String, locale: String, context: Dictionary, new_attempt: bool = false) -> void:
	# A variable surface has one identity per disclosed value set, not per repaint.
	var key := JSON.stringify([descriptor, locale], "", true)
	if key not in active: active.append(key)
	if requests.has(key) and requests[key].attempted and (not new_attempt or not requests[key].recorded): return
	var source := context.duplicate(true)
	if new_attempt:
		source.event_occurrence_id = ARCHIVE.new_uid()
		source.conversation_session_id = ARCHIVE.new_uid()
	if not source.has("event_occurrence_id"): source.event_occurrence_id = occurrence
	if not source.has("conversation_session_id"): source.conversation_session_id = conversation
	var request := _request(descriptor.content_id, text, locale, source)
	request.context.notebook_content = descriptor.duplicate(true)
	_attach_receipt(request, new_attempt)
	requests[key] = request


func _attach_receipt(request: Dictionary, new_attempt: bool) -> void:
	if scope.is_empty(): return
	var key := RECEIPT.fingerprint(request)
	if not new_attempt and resume_receipts.has(key):
		for field in resume_receipts[key]: request.context[field] = resume_receipts[key][field]
	request.context.surface_receipt = {"scope": RECEIPT.stable_scope(scope), "occurrence": occurrence,
		"conversation": conversation, "key": key, "identity": RECEIPT.identity(request.context), "keep": []}


func prepare_receipts() -> void:
	var keep := []
	for id in requests:
		if (id in active or (requests[id].attempted and not requests[id].recorded)) and requests[id].context.has("surface_receipt"):
			var key: String = requests[id].context.surface_receipt.key
			if key not in keep: keep.append(key)
	keep.sort()
	for id in requests:
		var request: Dictionary = requests[id]
		if not request.context.has("surface_receipt"): continue
		# A returning visible value may already be observed but no longer be in the saved batch.
		if id in active and request.recorded and request.context.surface_receipt.keep != keep: request.recorded = false
		request.context.surface_receipt.keep = keep.duplicate()


func live(current: Dictionary, expected_generation: int) -> bool:
	return scope == current and generation == expected_generation


func flush(session: Object, current: Dictionary, explicit_retry: bool = false) -> bool:
	if scope != current: return false
	if retry_required and not explicit_retry: return false
	prepare_receipts()
	for id in requests:
		var request: Dictionary = requests[id]
		if id not in active and not request.attempted: continue
		if not _write(session, request):
			retry_required = true
			return false
	retry_required = false
	return true


func choose(session: Object, current: Dictionary, group: String, id: String, text: String, locale: String) -> bool:
	if group not in active or not flush(session, current): return false
	var selected: Dictionary = selections.get(group, {})
	if selected.is_empty() or selected.id != id or selected.dispatched:
		var source: Dictionary = requests[group].context.duplicate(true)
		source.erase("surface_receipt")
		selected = _request(id, text, locale, source)
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


func _write(session: Object, request: Dictionary) -> bool:
	if request.recorded: return true
	request.attempted = true
	var result: Dictionary = session.record_viewed_line(request.speaker, request.text, request.locale, request.context)
	request.recorded = result.get("ok", false)
	return request.recorded
