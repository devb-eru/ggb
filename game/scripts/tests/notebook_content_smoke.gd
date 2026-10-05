extends RefCounted

const PUBLIC_LABELS := preload("res://scripts/tests/notebook_public_puzzle_labels.gd")

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
const VIEWS := [preload("res://scripts/chapters/chapter_one_controller.gd"), preload("res://scripts/chapters/black_mirror_controller.gd"), preload("res://scripts/chapters/basement_controller.gd")]
const PROVIDERS := [preload("res://scripts/ui/clock_hint_texts.gd"), preload("res://scripts/ui/mirror_hint_texts.gd"), preload("res://scripts/ui/basement_hint_texts.gd"), preload("res://scripts/ui/core_hint_texts.gd")]
const SLOT := "__test_notebook_content"
var errors := PackedStringArray()
var covered := {}
var required_tuples := {}
var observed_tuples := {}
var unmapped_tuples := {}
var catalog_hashes := {}
var historical_tuples := {}
var historical_replayed := {}


class RejectingSave:
	extends Node
	var delegate: Node
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if PRESENTATION.read(state).get("kind") == "dialogue":
			return {"ok": false, "error_ids": ["TEST_NOTEBOOK_CONTENT_SAVE"]}
		return delegate.save_snapshot(slot, point, state, revision, transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	GameState.reset_for_test()
	SaveManager.delete_test_slot(SLOT)
	var diagnostics := CONTENT.diagnostics()
	var hint_ids: Array = diagnostics.content_ids.filter(func(id: String) -> bool: return id.begins_with("NB_HINT_"))
	_expect(diagnostics.ok and hint_ids.size() == 60, "60 authored hint IDs with bilingual versioned content")
	if not diagnostics.ok: return {"ok": false, "errors": diagnostics.error_ids}
	_prepare_tuple_audit()
	_validate_versioned_content()
	errors.append_array(PUBLIC_LABELS.catalog_errors())
	_validate_segments()
	_validate_enums()
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		for stage in ["B3_A", "B3_B", "BF", "C3", "C4", "CF", "D0_A", "D1", "DF", "D4", "F0_A", "F0_B", "F0_C", "F0_D", "F0_E"]:
			await _validate_live_hints(tree, stage, language)
	_expect(covered.size() == 120, "all 60 content IDs actually displayed in both languages")
	await _validate_failed_write(tree)
	await _validate_skipped_hints(tree)
	_validate_historical_tuples()
	var missing: Array = []
	for key in required_tuples:
		if not observed_tuples.has(key): missing.append(JSON.parse_string(key))
	_expect(missing.is_empty(), "every registered NP20 node/variant/segment/locale was actually displayed")
	_expect(unmapped_tuples.is_empty(), "no unregistered NP20 runtime tuple")
	var observed: Array = observed_tuples.keys()
	observed.sort()
	print("NOTEBOOK_HINT_BRANCH_AUDIT: " + JSON.stringify({"scope":"NP20_CONTROLLER_REQUEST_DISPLAY_AND_COMMIT_NOT_OS_INPUT", "catalog_sha256":catalog_hashes, "required_count":required_tuples.size(), "observed_count":observed_tuples.size(), "historical_required":historical_tuples.size(), "historical_replayed":historical_replayed.keys(), "not_covered":missing, "unmapped":unmapped_tuples.keys(), "tuple_fields":["producer", "content", "version", "node", "variant", "segment", "locale"], "observed":observed.map(func(key: String) -> Array: return JSON.parse_string(key)), "errors":errors}))
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor", flavor)
	return {"ok": errors.is_empty(), "errors": errors, "authored_hint_ids": hint_ids.size(), "covered_id_locales": covered.size(), "producer_groups_covered": ["NP20"], "other_groups": "NOT_COVERED"}


func _prepare_tuple_audit() -> void:
	# Derive required nodes from catalog data, independently of the executed stage list.
	for path in CONTENT.CATALOGS:
		var raw := FileAccess.get_file_as_string(path)
		var catalog: Dictionary = JSON.parse_string(raw)
		for id in catalog.contents:
			for version in catalog.contents[id]:
				var row: Dictionary = catalog.contents[id][version]
				if row.producer_id != "NP20": continue
				catalog_hashes[path] = raw.sha256_text()
				for node in row.node_ids:
					for segment in row.visible_segment_ids:
						for locale in row.locales:
							var key := JSON.stringify([row.producer_id, id, int(version), node, row.action_or_variant, segment, locale])
							if int(version) != PUBLIC_LABELS.LABELS.version(id):
								historical_tuples[key] = true
								continue
							_expect(not required_tuples.has(key), "unique NP20 catalog tuple")
							required_tuples[key] = true


func _collect_tuple(entry: Dictionary) -> void:
	var observation: Dictionary = entry.observation
	for segment in observation.segments:
		var key := JSON.stringify([observation.producer_id, observation.content_id, int(observation.content_version), observation.node_id, observation.variant_id, segment.segment_id, segment.viewed_locale])
		if not required_tuples.has(key): unmapped_tuples[key] = true
		else: observed_tuples[key] = true


func _validate_historical_tuples() -> void:
	for key in historical_tuples:
		var tuple: Array = JSON.parse_string(key)
		var parts := {}
		parts[tuple[5]] = {}
		var descriptor := CONTENT.descriptor(tuple[1], int(tuple[2]), parts)
		var shown := CONTENT.presentation(descriptor, tuple[6])
		_expect(shown.ok, "historical hint presentation")
		if not shown.ok: continue
		var observation := CONTENT.observe(descriptor, _context(tuple[3]), shown.speaker, shown.text, tuple[6])
		_expect(observation.ok, "historical hint source accepts original node and semantic version")
		if not observation.ok: continue
		var appended := ARCHIVE.append_observation(ARCHIVE.create(), observation.observation, 0)
		_expect(appended.ok, "historical hint fixture archive")
		if not appended.ok: continue
		var entry: Dictionary = JSON.parse_string(JSON.stringify(appended.archive.entries[0]))
		var frozen := entry.duplicate(true)
		var valid := true
		for language in ["ko-KR", "en-US"]:
			var rendered := CONTENT.render_entry(entry, language)
			var expected := CONTENT.presentation(descriptor, language)
			var matches: bool = rendered.ok and expected.ok and not rendered.entry.fallback and rendered.entry.text == expected.speaker + ": " + expected.text and entry == frozen
			_expect(matches, "historical hint replay retains exact old wording and immutable source")
			valid = valid and matches
		if valid: historical_replayed[key] = true
	_expect(historical_replayed.size() == historical_tuples.size(), "all noncurrent NP20 tuples replay independently of live coverage")


func _context(stage: String) -> Dictionary:
	var value := preload("res://scripts/systems/dialogue_history_context.gd").capture(stage, "M1_CENTRAL_HALL")
	value.event_occurrence_id = ARCHIVE.new_uid()
	value.conversation_session_id = ARCHIVE.new_uid()
	value.presentation_token = ARCHIVE.new_uid()
	return value


func _validate_versioned_content() -> void:
	var descriptor := CONTENT.hint_descriptor("B3_A", 0)
	var text: String = PROVIDERS[0].text("B3_A", 0, "ko-KR")
	var observed := CONTENT.observe(descriptor, _context("B3_A"), "주인공", text, "ko-KR")
	_expect(observed.ok, "explicit hint source builds authored observation")
	if not observed.ok: return
	var archive := ARCHIVE.create()
	archive = ARCHIVE.append_observation(archive, observed.observation, archive.revision).archive
	var original := archive.duplicate(true)
	var entry: Dictionary = archive.entries[0]
	var rendered := CONTENT.render_entry(entry, "en-US")
	_expect(rendered.ok and rendered.entry.text == "Protagonist: " + PROVIDERS[0].text("B3_A", 0, "en-US"), "authored observation uses exact current-language semantic version")
	_expect(not rendered.entry.fallback and archive == original, "translation never overwrites captured original or UIDs")
	_expect(entry.protection_reasons == ["content:hint"], "hint is protected independently of ordinary transcript count")
	_expect(not CONTENT.observe(descriptor, _context("B3_A"), "주인공", text + " changed", "ko-KR").ok, "changed wording is not falsely labeled as old semantic version")
	_expect(not CONTENT.observe(descriptor, _context("C3"), "주인공", text, "ko-KR").ok, "wrong source stage rejected")
	_expect(not CONTENT.observe(descriptor, _context("B3_A"), "에드가", text, "ko-KR").ok, "wrong displayed speaker rejected")
	var wrong := descriptor.duplicate(true)
	wrong.segments.body = {"secret": "unseen"}
	_expect(not CONTENT.observe(wrong, _context("B3_A"), "주인공", text, "ko-KR").ok, "undeclared private variables rejected")
	wrong = descriptor.duplicate(true)
	wrong.segments.hidden = {}
	_expect(not CONTENT.observe(wrong, _context("B3_A"), "주인공", text, "ko-KR").ok, "unknown segment cannot be appended")
	var unavailable := entry.duplicate(true)
	unavailable.observation.content_version = 999
	var fallback := CONTENT.render_entry(unavailable, "en-US")
	_expect(fallback.ok and fallback.entry.fallback and fallback.entry.segments[0].text == text and fallback.entry.segments[0].viewed_locale == "ko-KR", "missing historical version uses marked captured original, not latest text")
	var broken := entry.duplicate(true)
	broken.observation.variant_id = "unrequested_H5"
	_expect(not CONTENT.render_entry(broken, "en-US").ok, "mismatched variant cannot render a different branch")
	broken = entry.duplicate(true)
	broken.observation.segments[0].disclosure = "acquired"
	_expect(not CONTENT.render_entry(broken, "en-US").ok, "acquired but undisplayed segment cannot render")
	var legacy := {"sequence": 1, "line_id": "CH1_HISTORY_TRANSCRIPT", "speaker_id": "SYSTEM", "variables": {"speaker": "Old speaker", "text": "Original legacy"}}
	var repository := DialogueRepository.new()
	var combined := repository.render_history({"entries": [entry, legacy]}, "en-US")
	_expect(combined.ok and combined.entries.size() == 2 and combined.entries[1].text == "Old speaker: Original legacy", "compatibility viewer handles authored and legacy without reclassifying old data")
	_expect(archive == original, "all replays preserve snapshot")


func _validate_segments() -> void:
	# Test-only version with a hidden back page. It never enters shipped catalogs.
	var id := "TEST_NOTEBOOK_SEGMENTS"
	var row := CONTENT.definition("NB_HINT_B3_A_H1", 1)
	row.visible_segment_ids = ["front", "back"]
	row.localization_keys = {"front": "TEST_FRONT", "back": "TEST_BACK"}
	row.variables = {"front": {"visible": "string", "count": "int"}, "back": {}}
	for language in row.locales:
		row.locales[language]["front"] = "Front {visible} {count}"
		row.locales[language]["back"] = "HIDDEN_BACK_SENTINEL"
	CONTENT._contents[id] = {"1": row}
	var descriptor := {"content_id": id, "content_version": 1, "variant_id": "requested_H1", "segments": {"front": {"visible": "{back}", "count": 2}}}
	var observed := CONTENT.observe(descriptor, _context("B3_A"), "Protagonist", "Front {back} 2", "en-US")
	_expect(observed.ok and observed.observation.segments.size() == 1, "front-only observation captures exactly one public segment")
	if observed.ok:
		var archive := ARCHIVE.create()
		archive = ARCHIVE.append_observation(archive, observed.observation, 0).archive
		var read := CONTENT.render_entry(archive.entries[0], "en-US")
		_expect(read.ok and read.entry.segments.size() == 1 and not read.entry.text.contains("HIDDEN_BACK_SENTINEL") and read.entry.text.contains("{back}"), "replay never expands variables recursively or reveals back content")
		var reference := ARCHIVE.make_reference(archive.entries[0], "back")
		_expect(not ARCHIVE.resolve(archive, reference).ok, "catalog back page alone does not grant a comparison reference")
		var state := GameState.make_default_snapshot()
		state.meta_progress.dialogue_history = archive
		var reloaded := StateSnapshotValidator.new().normalize(JSON.parse_string(JSON.stringify(state)))
		_expect(reloaded == state, "numeric public variables keep their frozen JSON representation across reload")
		_expect(CONTENT.render_entry(reloaded.meta_progress.dialogue_history.entries[0], "en-US").entry.segments[0].text == "Front {back} 2", "integer placeholder preserves display formatting after reload")
	CONTENT._contents.erase(id)


func _validate_enums() -> void:
	var id := "TEST_NOTEBOOK_ENUM"
	var row := CONTENT.definition("NB_HINT_B3_A_H1", 1)
	row.visible_segment_ids = ["body"]
	row.localization_keys = {"body": "TEST_ENUM_BODY"}
	row.variables = {"body": {"phase": "enum:phase"}}
	row.enums = {"phase": {"ko-KR": {"a": "첫 위상", "b": "{phase}"}, "en-US": {"a": "First Phase", "b": "{phase}"}}}
	row.locales["ko-KR"].body = "현재 {phase}"
	row.locales["en-US"].body = "Current {phase}"
	_expect(CONTENT._valid_row(row), "closed bilingual enum is a valid declared variable type")
	CONTENT._contents[id] = {"1": row}
	var descriptor := CONTENT.descriptor(id, 1, {"body": {"phase": "a"}})
	var observed := CONTENT.observe(descriptor, _context("B3_A"), "주인공", "현재 첫 위상", "ko-KR")
	_expect(observed.ok, "enum stores a stable public token instead of translated text")
	if observed.ok:
		var archive := ARCHIVE.create()
		archive = ARCHIVE.append_observation(archive, observed.observation, 0).archive
		var original := archive.duplicate(true)
		var entry: Dictionary = archive.entries[0]
		_expect(entry.observation.segments[0].safe_variables == {"phase": "a"}, "enum saves only declared token")
		_expect(CONTENT.render_entry(entry, "en-US").entry.segments[0].text == "Current First Phase" and archive == original, "enum replay localizes without changing source")
		entry.observation.content_version = 999
		var fallback := CONTENT.render_entry(entry, "en-US")
		_expect(fallback.ok and fallback.entry.fallback and fallback.entry.segments[0].text == "현재 첫 위상", "missing enum version preserves the full captured original")
	for value in ["missing", "첫 위상", 1, {"hidden": true}]:
		descriptor.segments.body.phase = value
		_expect(not CONTENT.observe(descriptor, _context("B3_A"), "주인공", "현재 첫 위상", "ko-KR").ok, "undeclared enum token or non-string rejected")
	descriptor.segments.body = {"phase": "b"}
	_expect(CONTENT.observe(descriptor, _context("B3_A"), "Protagonist", "Current {phase}", "en-US").ok, "localized enum labels are not recursively interpreted as templates")
	var broken := row.duplicate(true)
	broken.enums.phase["en-US"].erase("b")
	_expect(not CONTENT._valid_row(broken), "different language token sets are rejected")
	broken = row.duplicate(true)
	broken.enums.phase["en-US"].a = 9
	_expect(not CONTENT._valid_row(broken), "non-string enum translation is rejected")
	broken = row.duplicate(true)
	broken.variables.body.phase = "enum:absent"
	_expect(not CONTENT._valid_row(broken), "undefined enum type is rejected")
	broken = row.duplicate(true)
	broken.enums = []
	_expect(not CONTENT._valid_row(broken), "malformed enum container is rejected")
	CONTENT._contents.erase(id)


func _new_view(tree: SceneTree, stage: String) -> Node:
	SaveManager.delete_test_slot(SLOT)
	var fixture := CHECKPOINTS.new().snapshot_for(stage)
	_expect(fixture.ok, "checkpoint exists: " + stage)
	if not fixture.ok: return null
	_expect(StateWriter.new(GameState).install_snapshot(fixture.snapshot, GameState.revision, &"LOAD_NOTEBOOK_HINT_TEST").ok, "checkpoint installs: " + stage)
	var index := 0 if stage in ["B3_A", "B3_B", "BF"] else (1 if stage in ["C3", "C4", "CF"] else 2)
	var view: Node = VIEWS[index].new()
	view.configure_session(SLOT, stage)
	tree.root.add_child(view)
	view._dismiss_dialogue_for_test()
	_expect(view.session.stage() == stage, "actual controller resumes requested stage: " + stage)
	return view


func _read_button(view: Node) -> Button:
	for child in view._modal_body.get_children():
		if child is Button and ("힌트를 읽는다" in child.text or "Read hint H" in child.text): return child
	return null


func _validate_live_hints(tree: SceneTree, stage: String, language: String) -> void:
	var view := _new_view(tree, stage)
	if view == null: return
	await tree.process_frame
	var before := GameState.get_snapshot()
	view._show_clock_hint_menu(0)
	_expect(_gameplay(GameState.get_snapshot()) == _gameplay(before), "opening hint menu records no content: " + stage)
	for level in range(5):
		var button := _read_button(view)
		_expect(button != null, "explicit request control exists: %s H%d" % [stage, level + 1])
		if button == null: break
		var count: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
		button.pressed.emit()
		var after := GameState.get_snapshot()
		_expect(after.meta_progress.dialogue_history.entries.size() == count + 1, "only requested hint appends one observation")
		var entry: Dictionary = after.meta_progress.dialogue_history.entries.back()
		errors.append_array(PUBLIC_LABELS.live_errors(entry))
		errors.append_array(PUBLIC_LABELS.screen_errors(view))
		_expect(entry.get("record_class") == "authored", "live hint is authored, not unmapped")
		if entry.get("record_class") != "authored": break
		var descriptor := CONTENT.hint_descriptor(stage, level)
		var observation: Dictionary = entry.observation
		_collect_tuple(entry)
		covered[observation.content_id + ":" + language] = true
		_expect(observation.content_id == descriptor.content_id and observation.node_id == stage and observation.segments.size() == 1, "content ID and actual failure/source node frozen")
		_expect(observation.location_id == before.loop_state.location_id and observation.entry_kind == "hint_revealed", "actual room and hint kind stored")
		_expect(observation.segments[0].captured_text == view._dialogue_label.text and observation.segments[0].viewed_locale == language, "stored text is exactly the displayed requested hint")
		view._present_dialogue_line()
		_expect(GameState.get_snapshot() == after, "rerender preserves UID and does not repeat append")
		var rendered := CONTENT.render_entry(entry, "en-US" if language == "ko-KR" else "ko-KR")
		_expect(rendered.ok and not rendered.entry.fallback, "other language resolves exact authored version")
		var only_history := after.duplicate(true)
		only_history.meta_progress.dialogue_history = before.meta_progress.dialogue_history
		_expect(_gameplay(only_history) == _gameplay(before), "reading hint changes no puzzle, bond, journal, or ending field")
		view._dialogue_next.pressed.emit()
	view._close_modal()
	var committed := GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "authored hints reload through real save manager")
	_expect(StateSnapshotValidator.same_persisted_value(GameState.get_snapshot(), committed), "reload preserves UID, semantic version, protected content, and captured original")
	view.queue_free()
	await tree.process_frame


func _validate_failed_write(tree: SceneTree) -> void:
	TranslationServer.set_locale("en-US")
	var view := _new_view(tree, "B3_A")
	if view == null: return
	await tree.process_frame
	_expect(view._notebook_surface_allowed(), "visible baseline surfaces committed before hint failure injection")
	var real: Node = view.session._save
	var fake := RejectingSave.new()
	fake.delegate = real
	view.session._save = fake
	var before := GameState.get_snapshot()
	view._show_clock_hint_menu(0)
	var button := _read_button(view)
	_expect(button != null, "failed-write fixture has the actual hint request button")
	if button != null: button.pressed.emit()
	_expect(view._dialogue_active and not view._dialogue_lines.is_empty(), "hint display reached before observation write is rejected")
	if not view._dialogue_active or view._dialogue_lines.is_empty():
		view.session._save = real
		view.queue_free()
		fake.free()
		await tree.process_frame
		return
	var token: String = view._dialogue_lines[0].presentation_token
	_expect(_gameplay(GameState.get_snapshot()) == _gameplay(before) and view._dialogue_active, "failed authored write leaves hint active and no committed disclosure")
	view._dialogue_next.pressed.emit()
	_expect(_gameplay(GameState.get_snapshot()) == _gameplay(before) and view._dialogue_active, "failed retry cannot advance to next hint")
	view.session._save = real
	view._dialogue_next.pressed.emit()
	var saved: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.entries.back()
	_expect(saved.get("record_class") == "authored" and saved.observation.presentation_token == token, "successful retry commits original presentation token once")
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.size() == before.meta_progress.dialogue_history.entries.size() + 1, "retry produces exactly one hint record")
	view.queue_free()
	fake.free()
	await tree.process_frame


func _validate_skipped_hints(tree: SceneTree) -> void:
	var view := _new_view(tree, "BF")
	if view == null: return
	var before: int = GameState.get_snapshot().meta_progress.dialogue_history.entries.size()
	var state := GameState.get_snapshot()
	state.meta_progress.failure_knowledge["B3_B"] = {"attempts": 4, "status": "active"}
	_expect(StateWriter.new(GameState).install_snapshot(state, GameState.revision, &"LOAD_HINT_FAILURE_SUPPORT").ok, "repeated-failure fixture installs")
	view._offer_clock_failure_support()
	var request: Button
	for child in view._modal_body.get_children():
		if child is Button and child.text.contains("Request stronger hint H5"): request = child
	_expect(request != null, "actual failure-support action offers H5")
	if request == null:
		view.queue_free()
		await tree.process_frame
		return
	_expect(GameState.get_snapshot().meta_progress.dialogue_history.entries.size() == before, "offering stronger support alone records no hint")
	request.pressed.emit()
	var history: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history
	_expect(history.entries.size() == before + 1 and history.entries.back().observation.content_id == "NB_HINT_B3_B_H5", "jump to H5 grants H5 only, never H1-H4")
	view._dialogue_next.pressed.emit()
	var menu_body: Label = view._modal_body.find_child("ModalBodyText", true, false)
	_expect(menu_body != null, "end-of-hints body is present")
	if menu_body != null:
		_expect(not menu_body.text.contains("all five") and not menu_body.text.contains("모두 읽었다"), "end-of-hints message does not claim skipped hints were read")
	view.queue_free()
	await tree.process_frame


func _gameplay(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.loop_state.event_local_states.erase(PRESENTATION.KEY)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
