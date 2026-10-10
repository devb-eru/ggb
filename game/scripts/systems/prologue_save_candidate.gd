extends RefCounted

const NOTES := preload("res://scripts/systems/notebook_knowledge.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const HISTORY := preload("res://scripts/systems/dialogue_history_writer.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")


static func prepare(previous: Dictionary, request: Dictionary) -> Dictionary:
	# Only detached data crosses this boundary; no scene nodes or current locale reads.
	for field in ["progress", "pending_notes", "scope", "recording", "window"]:
		if not request.get(field) is Dictionary: return {"ok":false, "error_id":"NB_PROLOGUE_REQUEST"}
	for field in ["inventory", "surfaces"]:
		if not request.get(field) is Array: return {"ok":false, "error_id":"NB_PROLOGUE_REQUEST"}
	for field in ["room", "locale"]:
		if not request.get(field) is String: return {"ok":false, "error_id":"NB_PROLOGUE_REQUEST"}
	for field in ["complete", "already_complete", "cursor_enabled", "complete_cursor"]:
		if not request.get(field) is bool: return {"ok":false, "error_id":"NB_PROLOGUE_REQUEST"}
	var progress: Dictionary = request.progress
	var candidate := previous.duplicate(true)
	var states: Dictionary = previous.loop_state.event_local_states.duplicate(true)
	states.PROLOGUE = progress.duplicate(true)
	if not request.window.is_empty(): states[CURSOR.WINDOW_KEY] = request.window.duplicate(true)
	else: states.erase(CURSOR.WINDOW_KEY)
	var knowledge: Dictionary = previous.meta_progress.knowledge_entries.duplicate(true)
	knowledge.prologue_notebook_entries = Array(progress.get("notebook_entries", [])).duplicate(true)
	for servant in Array(progress.get("introduced", [])): knowledge["INTRO_%s" % servant] = true
	var markers := {"p3_journal_seen":"NOTE_JOURNAL", "P3B_complete":"CLR_00_SIGNATURES",
		"p4_life_support_seen":"OBS_KITCHEN_REGULAR_PULSE", "bird_observed":"OBS_REPEATING_BIRD", "P5_complete":"OBS_WEATHER_CONTRADICTION"}
	for marker in markers:
		if bool(progress.get(marker, false)): knowledge[markers[marker]] = true
	if bool(progress.get("p4_memory_anchor_seen", false)): knowledge.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
	if request.complete or bool(progress.get("P6_complete", false)): knowledge.PROLOGUE_COMPLETE = true
	var history: Dictionary = previous.meta_progress.dialogue_history.duplicate(true)
	if not request.pending_notes.is_empty():
		var ledger: Dictionary = knowledge.get(NOTES.KEY, NOTES.create())
		for note in request.pending_notes.values():
			if not note is Dictionary: return {"ok":false, "error_id":"NB_PROLOGUE_REQUEST"}
			if note.has("error_id") or note.get("scope") != request.scope:
				return {"ok":false, "error_id":note.get("error_id", "NB_NOTE_STALE_SCOPE"), "note_error":true}
			var acquired := NOTES.acquire(ledger, history, note.observation, note.revision_uid)
			if not acquired.ok: return {"ok":false, "error_id":acquired.error_id, "note_error":true}
			ledger = acquired.ledger
			history = acquired.archive
		knowledge[NOTES.KEY] = ledger
	if not request.already_complete:
		candidate.loop_state.event_local_states = states
		candidate.loop_state.location_id = request.room
		candidate.loop_state.time_block = String(progress.get("time_block", "morning"))
		candidate.loop_state.inventory = request.inventory.duplicate(true)
		candidate.meta_progress.knowledge_entries = knowledge
		candidate.meta_progress.dialogue_history = history
	for surface in request.surfaces:
		var appended := HISTORY.append_to_snapshot(candidate, surface.speaker, surface.text, surface.locale, "PROLOGUE", [], surface.context)
		if not appended.ok: return appended
	var recording: Dictionary = request.recording
	if not recording.is_empty():
		var spec: Dictionary = recording.presentation
		var built: Dictionary
		if spec.kind == "choice": built = CURSOR.create_prologue_choice(candidate, spec.line, spec.choice, request.locale, spec.phase)
		else: built = CURSOR.create(candidate, "prologue_controller", spec.lines, spec.index, request.locale, spec.after, spec.phase)
		if not built.ok: return built
		var context: Dictionary = recording.context.duplicate(true)
		context.presentation_cursor = built.value
		var retry := _committed_choice_retry(previous, recording, request.locale)
		if not retry.ok: return retry
		if retry.committed:
			CURSOR.install(candidate, built.value)
		else:
			var appended := HISTORY.append_to_snapshot(candidate, recording.speaker, recording.text, request.locale, "PROLOGUE", [], context)
			if not appended.ok: return appended
	elif request.complete_cursor:
		var cursor := CURSOR.read(previous)
		if not CURSOR.matches(cursor, previous) or not CURSOR.observed(cursor, previous) or cursor.family != "prologue_controller": return {"ok":false, "error_id":"NB_PRESENTATION_STALE"}
		cursor.phase = "completed"
		cursor.after = {}
		CURSOR.install(candidate, cursor)
	elif request.cursor_enabled: CURSOR.carry(candidate, previous)
	return {"ok":true, "snapshot":candidate}


static func _committed_choice_retry(previous: Dictionary, recording: Dictionary, locale: String) -> Dictionary:
	var spec: Dictionary = recording.presentation
	var prior := CURSOR.read(previous)
	var not_committed := {"ok":true, "committed":false}
	if spec.get("kind") != "choice" or spec.get("phase") != "selection_pending": return not_committed
	if not CURSOR.matches(prior, previous) or not CURSOR.observed(prior, previous) or prior.family != "prologue_controller" or prior.kind != "choice" or prior.phase != "selection_pending": return not_committed
	var selected: String = spec.choice.get("last_selected", "")
	if selected.is_empty() or prior.choice.mode != spec.choice.mode or prior.choice.last_selected != selected: return not_committed
	var token: String = prior.choice.tokens.get(selected, "")
	if token.is_empty() or recording.context.get("presentation_token") != token or spec.choice.tokens.get(selected) != token or prior.lines[0].presentation_token != spec.line.presentation_token: return not_committed
	var fresh := CONTENT.observe(recording.context.notebook_content, recording.context, recording.speaker, recording.text, locale)
	if not fresh.ok: return fresh
	for entry in previous.meta_progress.dialogue_history.entries:
		if entry.get("record_class") == "authored" and entry.observation.presentation_token == token:
			# Redisclosure changes display language, never the original observation or intent.
			if _choice_identity(entry.observation) != _choice_identity(fresh.observation): return {"ok":false, "error_id":"NB_PRESENTATION_CONFLICT"}
			return {"ok":true, "committed":true}
	return not_committed


static func _choice_identity(observation: Dictionary) -> Dictionary:
	var identity := observation.duplicate(true)
	for segment in identity.segments:
		segment.erase("captured_text")
		segment.erase("viewed_locale")
	return identity
