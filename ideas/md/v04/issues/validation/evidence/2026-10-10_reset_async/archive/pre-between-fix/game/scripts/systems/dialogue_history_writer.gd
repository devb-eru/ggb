extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
const SURFACE_RECEIPT := preload("res://scripts/systems/notebook_surface_receipt.gd")
const LEGACY_FEEDBACK := preload("res://scripts/systems/notebook_legacy_feedback.gd")


static func record(game: Node, saves: Node, slot: String, point: String, speaker: String, text: String, locale: String, chapter_id: String = "LEGACY", observed_fact_ids: Variant = [], context: Dictionary = {}) -> Dictionary:
	if text.is_empty():
		return {"ok": true}
	var state: Dictionary = game.get_snapshot()
	var appended := append_to_snapshot(state, speaker, text, locale, chapter_id, observed_fact_ids, context)
	if not appended.ok: return appended
	if not appended.changed: return {"ok": true, "entry_uid": appended.entry_uid}
	return _commit_snapshot(game, saves, slot, point, state, appended.entry_uid)


static func append_to_snapshot(state: Dictionary, speaker: String, text: String, locale: String, chapter_id: String, observed_fact_ids: Variant, context: Dictionary) -> Dictionary:
	# The caller owns a detached candidate and must commit it with its gameplay writes.
	var history: Dictionary = state["meta_progress"]["dialogue_history"]
	var legacy_origin: Dictionary = {}
	if history.has("schema_version"):
		if context.has(LEGACY_FEEDBACK.REPLAY):
			var source := LEGACY_FEEDBACK.verify(state, context, speaker, text, observed_fact_ids)
			if not source.ok: return source
			legacy_origin = source.origin
		if legacy_origin.is_empty() and not context.has("notebook_content") and requires_authored():
			return {"ok": false, "error_ids": ["NB_PRODUCER_ID_REQUIRED"]}
		if context.has("notebook_content") and not context.notebook_content is Dictionary:
			return {"ok": false, "error_ids": ["NB_CONTENT_DESCRIPTOR"]}
	var cursor: Dictionary = context.get("presentation_cursor", {})
	if context.has("presentation_cursor") and not PRESENTATION.matches(cursor, state):
		return {"ok": false, "error_ids": ["NB_PRESENTATION_STALE"]}
	var facts := preload("res://scripts/systems/dialogue_observed_facts.gd").capture(state, observed_fact_ids)
	if not facts.ok:
		return facts
	var payload := {
		"chapter_id": chapter_id, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM",
		"variables": {"speaker": speaker, "text": text}, "viewed_locale": locale,
	}
	var entry_uid := ""
	if history.has("schema_version"):
		var frozen := context.duplicate(true)
		frozen.erase("presentation_cursor")
		frozen.erase("surface_receipt")
		if not frozen.has("presentation_token"): frozen.presentation_token = ARCHIVE.new_uid()
		var appended: Dictionary
		if not legacy_origin.is_empty():
			frozen.erase("observed_fact_ids")
			payload.viewed_locale = "en-US" if locale.begins_with("en") else "ko-KR"
			appended = ARCHIVE.append_legacy_feedback(history, payload, frozen, legacy_origin, int(history.revision))
		elif frozen.has("notebook_content"):
			var observed := preload("res://scripts/systems/notebook_content.gd").observe(frozen.notebook_content, frozen, speaker, text, locale)
			if not observed.ok: return observed
			appended = ARCHIVE.append_observation(history, observed.observation, int(history.revision))
		else:
			appended = ARCHIVE.append_unmapped(history, payload, frozen, int(history.revision))
		if not appended.ok: return appended
		var receipt_changed := false
		if context.has("surface_receipt"):
			var previous: Dictionary = state.loop_state.event_local_states.get(SURFACE_RECEIPT.KEY, {}).duplicate(true)
			if not frozen.has("notebook_content") or not context.surface_receipt is Dictionary or context.surface_receipt.get("key") != SURFACE_RECEIPT.fingerprint({"context": frozen, "speaker": speaker, "text": text, "locale": locale}): return {"ok": false, "error_ids": ["NB_SURFACE_RECEIPT_IDENTITY"]}
			if not SURFACE_RECEIPT.install(state, context.surface_receipt, frozen): return {"ok": false, "error_ids": ["NB_SURFACE_RECEIPT_SCHEMA"]}
			receipt_changed = not StateSnapshotValidator.same_persisted_value(previous, state.loop_state.event_local_states[SURFACE_RECEIPT.KEY])
		if not appended.changed and cursor.is_empty() and not receipt_changed: return {"ok": true, "changed": false, "entry_uid": appended.entry_uid}
		state.meta_progress.dialogue_history = appended.archive
		entry_uid = appended.entry_uid
	else:
		payload.sequence = int(history.next_sequence)
		history.entries.append(payload)
		history.next_sequence = int(history.next_sequence) + 1
	if not cursor.is_empty(): PRESENTATION.install(state, cursor)
	return {"ok": true, "changed": true, "entry_uid": entry_uid}


static func requires_authored() -> bool:
	# Audit mode must not silently accept new raw dialogue as a mapped producer.
	return OS.is_debug_build() and "--notebook-require-authored" in OS.get_cmdline_user_args()


static func record_async(game: Node, saves: Node, slot: String, point: String, speaker: String, text: String, locale: String, chapter_id: String = "LEGACY", observed_fact_ids: Variant = [], context: Dictionary = {}, completion_guard: Callable = Callable()) -> Dictionary:
	if text.is_empty(): return {"ok":true}
	return await _write_async(game, saves, slot, point, {"kind":"dialogue", "speaker":speaker, "text":text,
		"locale":locale, "chapter":chapter_id, "facts":observed_fact_ids, "context":context}, completion_guard)


static func save_cursor_async(game: Node, saves: Node, slot: String, point: String, cursor: Dictionary, completion_guard: Callable = Callable()) -> Dictionary:
	return await _write_async(game, saves, slot, point, {"kind":"cursor", "cursor":cursor}, completion_guard)


static func save_prologue_async(game: Node, saves: Node, slot: String, point: String, payload: Dictionary, completion_guard: Callable = Callable()) -> Dictionary:
	return await _write_async(game, saves, slot, point, {"kind":"prologue", "payload":payload}, completion_guard)


static func save_reset_step_async(game: Node, saves: Node, slot: String, point: String, payload: Dictionary, completion_guard: Callable = Callable()) -> Dictionary:
	return await _write_async(game, saves, slot, point, {"kind":"reset", "payload":payload}, completion_guard)


static func _write_async(game: Node, saves: Node, slot: String, point: String, recording: Dictionary, completion_guard: Callable) -> Dictionary:
	if not is_instance_valid(game) or not is_instance_valid(saves) or not saves.has_method("begin_history_write") or not saves.is_inside_tree(): return {"ok":false, "error_id":"NB_COMMAND_SERVICE_UNAVAILABLE"}
	var command := ARCHIVE.new_uid()
	var begun: Dictionary = saves.begin_history_write(game, slot, point, recording, game.revision, command, completion_guard)
	if not begun.ok: return begun
	var tree := saves.get_tree()
	while is_instance_valid(saves):
		var result: Dictionary = saves.notebook_reference_result(command)
		if not result.get("pending", false): return result
		await tree.process_frame
	return {"ok":false, "error_id":"NB_COMMAND_CANCELLED"}


static func save_cursor(game: Node, saves: Node, slot: String, point: String, cursor: Dictionary) -> Dictionary:
	var state: Dictionary = game.get_snapshot()
	if not PRESENTATION.matches(cursor, state) or not PRESENTATION.observed(cursor, state):
		return {"ok": false, "error_ids": ["NB_PRESENTATION_STALE"]}
	PRESENTATION.install(state, cursor)
	return _commit_snapshot(game, saves, slot, point, state, "")


static func _commit_snapshot(game: Node, saves: Node, slot: String, point: String, state: Dictionary, entry_uid: String) -> Dictionary:
	var transaction := StringName("HISTORY_R%06d" % (game.revision + 1))
	var installed: Dictionary = StateWriter.new(game).install_snapshot(state, game.revision, transaction)
	if not installed.get("ok", false):
		return installed
	var saved: Dictionary = saves.save_snapshot(slot, point, game.get_snapshot(), game.revision, String(transaction))
	if not saved.get("ok", false):
		if saves.has_method("confirm_snapshot_commit"):
			var confirmed: Dictionary = saves.confirm_snapshot_commit(slot, String(transaction))
			if confirmed.get("ok", false) and StateSnapshotValidator.same_persisted_value(state, confirmed.snapshot):
				return {"ok": true, "entry_uid": entry_uid, "recovered_acknowledgement": true}
		game.rollback_failed_persistence(installed["previous_snapshot"], int(installed["revision"]), transaction, &"ERR_DIALOGUE_HISTORY_SAVE")
	else:
		saved["entry_uid"] = entry_uid
	return saved
