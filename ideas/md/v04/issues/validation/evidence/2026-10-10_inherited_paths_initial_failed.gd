extends SceneTree

const MIRROR := preload("res://scripts/chapters/black_mirror_controller.gd")
const BASEMENT := preload("res://scripts/chapters/basement_controller.gd")
const BASE := preload("res://scripts/chapters/chapter_one_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const RECEIPT := preload("res://scripts/systems/notebook_surface_receipt.gd")
const MIRROR_STAGES := ["C_SLEEP", "C0", "C1", "C2", "C3", "C_BELL", "C4", "CF", "C5_INFO", "J3"]
const BASEMENT_STAGES := ["D_SLEEP", "D0", "D0_A", "D1", "DF", "D2", "D4"]
const INNER_TARGETS := ["desk", "index", "drawer", "alcove", "gap", "link"]
const SLOT := "__test_notebook_inherited_paths"

var game: Node
var saves: Node
var view: ChapterOneController
var fixtures := {}
var errors: Array[String] = []
var cases: Array = []
var exclusions: Array = []
var serial := 0
var assertions := 0
var new_classes := {"authored": 0, "legacy": 0, "unmapped": 0}
var baseline_classes := {"authored": 0, "legacy": 0, "unmapped": 0}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = root.get_node("GameState")
	saves = root.get_node("SaveManager")
	_expect("--ggb-dev-notebook-v2" in OS.get_cmdline_user_args(), "development rollout explicitly requested")
	_expect("--notebook-require-authored" in OS.get_cmdline_user_args(), "strict writer explicitly requested")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for stage in MIRROR_STAGES + BASEMENT_STAGES:
			print("INHERITED_PATH_PHASE: ", locale, " ", stage)
			var controller: Script = MIRROR if stage in MIRROR_STAGES else BASEMENT
			if not _install(stage, "M1_SERVANT_COMMON"): continue
			view = controller.new()
			view.configure_session(SLOT, stage)
			host.add_child(view)
			view._dismiss_dialogue_for_test()
			view.set_process(false)
			for owner in ["edgar", "luca", "mara1", "mara2"]:
				_audit_action(stage, "M1_SERVANT_COMMON", "DOC_" + owner,
					"NB_CH1_CH1_B1_TEXT_" + owner.to_upper(), "NB_CH1_NOTE_B1_" + owner.to_upper())
			_audit_action(stage, "M2_BEDROOM", "AS_ROUTINE", "NB_CH1_ROUTINE")
			_audit_action(stage, "M1_NORTH_ARCHIVE_HALL", "MARA2_MEMORY", "NB_CH1_MARA2_MEMORY")
			for clock in [["M1_PARLOR", "PARLOR"], ["M1_LIBRARY_OUTER", "LIBRARY_OUTER"]]:
				_audit_action(stage, clock[0], "RUB_CLOCK", "NB_CH1_CH1_CLOCK_" + clock[1], "NB_CH1_NOTE_CLOCK_" + clock[1])
			if stage in MIRROR_STAGES:
				_audit_action(stage, "M2_BEDROOM", "RUB_CLOCK", "NB_CH1_CH1_CLOCK_BEDROOM", "NB_CH1_NOTE_CLOCK_BEDROOM")
			else:
				_audit_absent(stage, "M2_BEDROOM", ["RUB_CLOCK"])
			if stage in MIRROR_STAGES and stage != "J3":
				for target in INNER_TARGETS:
					var suffix: String = "LINK_OPEN" if target == "link" else target.to_upper()
					_audit_action(stage, "M1_LIBRARY_INNER", "INNER_" + target, "NB_CH1_CH1_INNER_" + suffix)
			else:
				var buttons: Array = []
				for target in INNER_TARGETS: buttons.append("INNER_" + target)
				_audit_absent(stage, "M1_LIBRARY_INNER", buttons)
			_audit_absent(stage, "M1_GREAT_CLOCK", ["RUB_CLOCK"])
			view.queue_free()
			view = null
			await process_frame
	saves.delete_test_slot(SLOT)
	var expected_actions := 400
	var expected_exclusions := 144
	_expect(cases.size() == expected_actions, "independent UI-call denominator: 400 stage/room/action/locale cases")
	_expect(exclusions.size() == expected_exclusions, "independent replaced-control denominator: 144 cases")
	_expect(new_classes.legacy == 0 and new_classes.unmapped == 0, "no newly written legacy or unmapped entry in bounded cases")
	var result := {
		"schema_version": 1, "suite_id": "inherited-paths", "ok": errors.is_empty(),
		"harness_sha256": FileAccess.get_sha256(get_script().resource_path),
		"engine_version": Engine.get_version_info().string,
		"source_corpus": preload("res://scripts/tests/notebook_runtime_audit.gd").new()._source_corpus(),
		"catalog_fingerprints": _catalog_fingerprints(),
		"required_action_cases": expected_actions, "required_exclusion_cases": expected_exclusions,
		"assertions": assertions, "cases": cases, "exclusions": exclusions,
		"baseline_entry_classes": baseline_classes, "new_entry_classes": new_classes,
		"basis": "checkpoint-derived dispatch; first and repeated actual UI callbacks; committed archive delta after presentation; real disk reload",
		"fixture_policy": "empty archive and knowledge source ledger; existing gameplay prerequisites retained; before-action visible records counted separately",
		"not_covered": ["natural_campaign_reachability", "OS_input", "save_failure_and_process_restart", "legacy_migration", "NP22_consumers", "all_producers", "post_fracture_inherited_controls"],
		"errors": errors,
	}
	print("NOTEBOOK_INHERITED_PATH_AUDIT: " + JSON.stringify(result))
	print("NOTEBOOK_INHERITED_PATH_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
	quit(0 if errors.is_empty() else 1)


func _install(stage: String, room: String) -> bool:
	if not fixtures.has(stage):
		var loaded := CHECKPOINTS.new().snapshot_for(stage)
		if not _expect(loaded.get("ok", false), "checkpoint " + stage): return false
		fixtures[stage] = loaded.snapshot
	var state: Dictionary = fixtures[stage].duplicate(true)
	state.loop_state.location_id = room
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
	state.meta_progress.knowledge_entries.chapter_notebook = {}
	var local: Dictionary = BASE.SESSION_SCRIPT.new(game, saves, SLOT).local_state(state)
	local.erase("last_feedback")
	local.attention = 0
	local.inspected = []
	local.edgar_state = "absent"
	state.loop_state.event_local_states.CHAPTER_ONE = local
	if view != null:
		view._dismiss_dialogue_for_test()
		view._close_modal()
		view._edgar_timer.stop()
	game.reset_for_test()
	serial += 1
	var token := "NB_INHERITED_FIXTURE_%d" % serial
	var installed := StateWriter.new(game).install_snapshot(state, game.revision, StringName(token))
	if not _expect(installed.get("ok", false), "fixture install " + stage + " " + str(installed)): return false
	var saved: Dictionary = saves.save_snapshot(SLOT, "SAVE_CAMPAIGN_PROGRESS", game.get_snapshot(), game.revision, token)
	if not _expect(saved.get("ok", false), "fixture durability " + stage + " " + str(saved)): return false
	if view != null: view._render_room()
	return true


func _present() -> bool:
	view.set_process(false)
	return _expect(view._notebook_surface_allowed(), "flush visible surfaces " + view.session.stage())


func _audit_action(stage: String, room: String, button: String, content: String, note: String = "") -> void:
	if not _install(stage, room) or not _present(): return
	var key := "%s/%s/%s/%s" % [stage, room, button, TranslationServer.get_locale().replace("_", "-")]
	_expect(view.session.stage() == stage, "actual stage " + key)
	var baseline := _archive()
	for entry in baseline.entries: baseline_classes[entry.record_class] += 1
	var passes: Array = []
	var journal: int = game.get_snapshot().meta_progress.journal_stage
	for attempt in range(2):
		var before := _archive()
		var control := view._hotspot_layer.get_node_or_null(NodePath(button)) as Button
		if not _expect(control != null and control.is_visible_in_tree(), "live UI control " + key): break
		control.pressed.emit()
		for index in range(30):
			if not view._dialogue_active: break
			view._advance_dialogue()
		_expect(not view._dialogue_active and not view._modal_active, "action dialogue ends " + key)
		if not _present(): break
		var after := _archive()
		var delta := _new_entries(before, after, key)
		var observed: Array = []
		var found := false
		var found_note := note.is_empty() or attempt > 0
		for entry in delta:
			new_classes[entry.record_class] += 1
			_expect(entry.record_class == "authored", "new class is authored " + key)
			if entry.record_class != "authored": continue
			var observation: Dictionary = entry.observation
			if observation.content_id == content: found = true
			if observation.content_id == note: found_note = true
			if observation.producer_id in ["NP04", "NP06"]:
				_expect(observation.node_id == stage and observation.chapter_id == "CHAPTER_2" and observation.location_id == room, "actual inherited context " + key)
			if observation.content_id == content: _expect(observation.producer_id == "NP04", "dialogue producer " + key)
			if observation.content_id == note: _expect(observation.producer_id == "NP06", "acquisition producer " + key)
			_expect(CONTENT.render_entry(entry, "ko-KR").get("ok", false) and CONTENT.render_entry(entry, "en-US").get("ok", false), "bilingual reread " + key)
			for segment in observation.segments:
				_expect(segment.viewed_locale == TranslationServer.get_locale().replace("_", "-"), "viewed locale " + key)
				observed.append([observation.producer_id, observation.content_id, observation.content_version, observation.node_id, observation.variant_id, segment.segment_id, segment.viewed_locale])
		_expect(found and found_note, "expected newly observed dialogue and first acquisition " + key + " attempt " + str(attempt))
		_expect(game.get_snapshot().meta_progress.journal_stage == journal, "journal does not regress " + key)
		var loaded: Dictionary = saves.load_slot(SLOT)
		_expect(loaded.get("ok", false) and loaded.get("snapshot", {}).get("meta_progress", {}).get("dialogue_history", {}) == after, "disk archive matches committed action " + key)
		view._render_room()
		_present()
		_expect(_archive() == after, "redraw produces no record " + key)
		passes.append({"attempt": attempt + 1, "new_entry_count": delta.size(), "tuples": observed, "archive_sha256": _digest(after)})
	cases.append({"key": key, "stage": stage, "location": room, "button": button, "content": content, "note": note, "baseline_count": baseline.entries.size(), "passes": passes})
	_expect(passes.size() == 2, "first and repeat both dispatched " + key)


func _audit_absent(stage: String, room: String, buttons: Array) -> void:
	if not _install(stage, room) or not _present(): return
	_expect(view.session.stage() == stage, "actual exclusion stage " + stage + " " + room)
	var before := _archive()
	for button in buttons:
		var key := "%s/%s/%s/%s" % [stage, room, button, TranslationServer.get_locale().replace("_", "-")]
		_expect(view._hotspot_layer.get_node_or_null(NodePath(button)) == null, "replaced UI control absent " + key)
		exclusions.append({"key": key, "button": button, "basis": "derived controller removes or replaces control; not a callable gameplay path"})
	for entry in before.entries:
		_expect(not String(entry.get("observation", {}).get("content_id", "")).begins_with("NB_CH1_SURFACE_"), "discarded parent labels excluded " + stage + " " + room)
	view._render_room()
	_present()
	_expect(_archive() == before, "excluded-control redraw has no new observation " + stage + " " + room)


func _new_entries(before: Dictionary, after: Dictionary, key: String) -> Array:
	var prior := {}
	for entry in before.entries: prior[_identity(entry)] = entry
	var delta: Array = []
	for entry in after.entries:
		var identity := _identity(entry)
		if not prior.has(identity):
			delta.append(entry)
			continue
		var original: Dictionary = prior[identity].duplicate(true)
		var current: Dictionary = entry.duplicate(true)
		original.erase("protection_reasons")
		current.erase("protection_reasons")
		_expect(original == current, "previous observed source immutable " + key)
		prior.erase(identity)
	_expect(prior.is_empty(), "previous sources remain present " + key)
	_expect(ARCHIVE.validate(after).get("ok", false), "result archive validates " + key)
	return delta


func _archive() -> Dictionary:
	return game.get_snapshot().meta_progress.dialogue_history


func _identity(entry: Dictionary) -> String:
	return JSON.stringify([entry.source_origin_id, entry.entry_uid])


func _digest(value: Dictionary) -> String:
	return JSON.stringify(RECEIPT._canonical(value), "", true, true).sha256_text()


func _catalog_fingerprints() -> Dictionary:
	var result := {}
	for path in CONTENT.CATALOGS: result[path] = FileAccess.get_sha256(path).to_lower()
	return result


func _expect(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		errors.append(message)
		print("INHERITED_PATH_ASSERT: ", message)
	return condition
