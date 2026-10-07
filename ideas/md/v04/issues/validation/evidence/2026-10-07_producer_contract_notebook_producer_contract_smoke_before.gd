extends RefCounted

const WRITER := preload("res://scripts/systems/dialogue_history_writer.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CONTEXT := preload("res://scripts/systems/dialogue_history_context.gd")
var errors := PackedStringArray()
var assertions := 0
var cases: Array = []


class CountingSave extends Node:
	var calls := 0
	func save_snapshot(_slot: String, _point: String, _state: Dictionary, _revision: int, _transaction: String) -> Dictionary:
		calls += 1
		return {"ok": false, "error_ids": ["TEST_UNEXPECTED_SAVE"]}


func run() -> Dictionary:
	var strict := OS.is_debug_build() and "--notebook-require-authored" in OS.get_cmdline_user_args()
	GameState.reset_for_test()
	var original: Dictionary = GameState.get_snapshot()
	for locale in ["ko-KR", "en-US"]:
		for versioned in [false, true]:
			var state := _state(original, versioned)
			var before := state.duplicate(true)
			var context := _context()
			var raw := WRITER.append_to_snapshot(state, "Narrator", "Unregistered new dialogue", locale, "CHAPTER_1", [], context)
			var reject: bool = strict and versioned
			_expect(raw.ok != reject, "missing descriptor follows strict/versioned policy")
			if reject:
				_expect("NB_PRODUCER_ID_REQUIRED" in raw.get("error_ids", []), "missing descriptor reports a developer contract error")
				_expect(state == before, "rejected raw candidate leaves all state unchanged")
			else:
				_expect(state.meta_progress.dialogue_history.entries.size() == 1, "non-strict transitional and ordinary recording remains compatible")
			cases.append({"locale": locale, "versioned": versioned, "raw_rejected": not raw.ok})
		_validate_authored(original, locale)
		_validate_rejection_before_persistence(original, locale, strict)
	_expect(GameState.get_snapshot() == original, "candidate checks never install gameplay state")
	print("NOTEBOOK_PRODUCER_CONTRACT_AUDIT: " + JSON.stringify({"strict_requested": strict, "cases": cases, "assertions": assertions, "errors": errors, "scope": "WRITER_CONTRACT_NOT_FULL_PRODUCER_COVERAGE"}))
	return {"ok": errors.is_empty(), "errors": errors, "assertions": assertions, "strict_requested": strict}


func _state(base: Dictionary, versioned: bool = true) -> Dictionary:
	var state := base.duplicate(true)
	state.meta_progress.dialogue_history = ARCHIVE.create() if versioned else {"next_sequence": 0, "entries": []}
	return state


func _context() -> Dictionary:
	var context := CONTEXT.capture("A1", "M2_BEDROOM")
	context.event_occurrence_id = ARCHIVE.new_uid()
	context.conversation_session_id = ARCHIVE.new_uid()
	context.presentation_token = ARCHIVE.new_uid()
	return context


func _validate_authored(base: Dictionary, locale: String) -> void:
	var descriptor := CONTENT.descriptor("NB_CH1_WAKE", 1, {"line_01": {}})
	var shown := CONTENT.presentation(descriptor, locale)
	_expect(shown.ok, "authored source resolves in both languages")
	if not shown.ok: return
	var state := _state(base)
	var context := _context()
	context.notebook_content = descriptor
	var appended := WRITER.append_to_snapshot(state, shown.speaker, shown.text, locale, "CHAPTER_1", [], context)
	_expect(appended.ok and appended.changed, "valid explicit descriptor records")
	if not appended.ok: return
	var entry: Dictionary = state.meta_progress.dialogue_history.entries.back()
	_expect(entry.record_class == "authored" and entry.observation.content_id == "NB_CH1_WAKE", "valid line never falls back to unmapped")
	_expect(entry.observation.content_protection == CONTENT.definition("NB_CH1_WAKE", 1).protection_reasons, "protection comes from authored catalog")
	var before := state.duplicate(true)
	var retry := WRITER.append_to_snapshot(state, shown.speaker, shown.text, locale, "CHAPTER_1", [], context)
	_expect(retry.ok and not retry.changed and retry.entry_uid == appended.entry_uid and state == before, "same token retry is idempotent")
	for kind in ["missing_id", "unknown_id", "missing_version", "wrong_variant", "missing_segments", "wrong_node", "missing_location", "display_mismatch"]:
		var candidate := _state(base)
		var untouched := candidate.duplicate(true)
		var frozen := _context()
		frozen.notebook_content = descriptor.duplicate(true)
		var text: String = shown.text
		match kind:
			"missing_id": frozen.notebook_content.erase("content_id")
			"unknown_id": frozen.notebook_content.content_id = "NB_UNREGISTERED_TEST"
			"missing_version": frozen.notebook_content.erase("content_version")
			"wrong_variant": frozen.notebook_content.variant_id = "unregistered"
			"missing_segments": frozen.notebook_content.segments = {}
			"wrong_node": frozen.node_id = "UNREGISTERED_NODE"
			"missing_location": frozen.erase("location_id")
			"display_mismatch": text += " altered"
		var rejected := WRITER.append_to_snapshot(candidate, shown.speaker, text, locale, "CHAPTER_1", [], frozen)
		_expect(not rejected.ok and candidate == untouched, "invalid descriptor/context rejects without mutation: " + kind)


func _validate_rejection_before_persistence(base: Dictionary, locale: String, strict: bool) -> void:
	if not strict: return
	var saves := CountingSave.new()
	var before := GameState.get_snapshot()
	var revision: int = GameState.revision
	# GameState may use either rollout schema, so test the v2 candidate independently too.
	var candidate := _state(base)
	var result := WRITER.append_to_snapshot(candidate, "Narrator", "Unregistered new dialogue", locale, "CHAPTER_1", [], _context())
	_expect(not result.ok, "strict v2 candidate cannot reach save")
	if before.meta_progress.dialogue_history.has("schema_version"):
		result = WRITER.record(GameState, saves, "__test_producer_contract", "SAVE_CAMPAIGN_PROGRESS", "Narrator", "Unregistered new dialogue", locale, "CHAPTER_1", [], _context())
		_expect(not result.ok and saves.calls == 0, "missing ID rejected before save callback")
		_expect(GameState.get_snapshot() == before and GameState.revision == revision, "missing ID never installs or rolls back state")
	saves.free()


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value: errors.append(message)
