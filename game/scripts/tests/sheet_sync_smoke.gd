extends Node

const SCRIPT := preload("res://scripts/systems/ep01_script.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CONTROLLER := preload("res://scripts/chapters/chapter_one_controller.gd")
const MIRROR_CONTROLLER := preload("res://scripts/chapters/black_mirror_controller.gd")
const PROLOGUE_TEXT := preload("res://data/dialogue/prologue/prologue_text.tres")
var failures: Array[String] = []
var checks := 0
var observed_sheet_nodes: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if "--sheet-journal-only" in OS.get_cmdline_user_args():
		await journal_reference_flow(get_tree().root.get_node("GameState"), get_tree().root.get_node("SaveManager"))
		for failure in failures: printerr(failure)
		print("SHEET_JOURNAL_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--sheet-diagnostics-only" in OS.get_cmdline_user_args():
		await run_diagnostics_only()
		return
	if "--sheet-discard-only" in OS.get_cmdline_user_args():
		await run_discard_only()
		return
	var state: Dictionary = get_tree().root.get_node("GameState").get_snapshot()
	check(CONTROLLER != null, "controller compiles")
	check(MIRROR_CONTROLLER != null, "mirror controller compiles")
	check(preload("res://scripts/ui/black_mirror_display_texts.gd").objective("C5_INFO", "ko-KR") == "대상 신체와 인격 채널을 확인하고 회로 탁본을 기록한다", "C5 objective no longer requires five optional owner channels")
	check(CONTENT.diagnostics().ok, "all notebook catalogs validate: " + str(CONTENT.diagnostics()))
	short_reaction_variants(state)
	for stage in ["C3", "C4", "J3"]:
		var count := 5 if stage == "C3" else (4 if stage == "C4" else 3)
		for level in range(count):
			var hint := CONTENT.hint_descriptor(stage, level)
			var hint_row := CONTENT.definition(hint.content_id, hint.content_version)
			var source_id := "EP02_%s_FB_HINT%d" % [stage, level + 1]
			check(hint_row.locales["ko-KR"].body == SCRIPT.text(source_id), "latest hint uses exact sheet text: " + source_id)
			check(hint_row.get("source_sheet_segments", {}).get("body") == source_id, "hint source provenance: " + source_id)
	check(CONTENT.hint_descriptor("C4", 0).content_version >= 3, "C4 hint preserves both historical versions")
	const MODALS := preload("res://scripts/systems/modal_notebook.gd")
	for configuration in [[0, false, true, "result_overlay_no_rot"], [270, false, true, "result_overlay_ccw"], [90, true, true, "result_overlay_flipped"], [90, false, false, "result_anchor_missing"]]:
		var local := {"rotation": configuration[0], "flipped": configuration[1], "anchored": configuration[2], "path": []}
		var shown := MODALS.route_options(local)
		check(shown.content_version >= 2 and shown.segments.has(configuration[3]), "dry overlay selects actual transform-specific source result: " + configuration[3])
		check(not shown.segments.has("dry_ring") and not shown.segments.has("dry_branches"), "invalid transform cannot disclose successful downstream reactions")
	var cabinet_state := state.duplicate(true)
	cabinet_state.loop_state.location_id = "M1_KITCHEN"
	const OBJECT_SURFACES := preload("res://scripts/systems/ep02_object_surfaces.gd")
	check(OBJECT_SURFACES.available(cabinet_state).has("OBJ_CHEM_CABINET"), "locked cabinet is inspectable before the cleaning hypothesis")
	check(OBJECT_SURFACES.pages(cabinet_state, "OBJ_CHEM_CABINET") == ["EP02_OBJ_CHEM_LOCKED_PRE"], "early cabinet cannot disclose already-acquired materials")
	cabinet_state.meta_progress.failure_knowledge.C4 = {"status": "active", "attempts": 1}
	check("EP02_OBJ_CHEM_RESET" in OBJECT_SURFACES.pages(cabinet_state, "OBJ_CHEM_CABINET"), "fresh-loop cabinet can disclose actual replenishment after recorded failure")
	check(SCRIPT.source().nodes.size() == 557, "557 source nodes")
	check(SCRIPT.source("EP02").nodes.size() == 490, "490 EP02 rows")
	var wet_state := state.duplicate(true)
	wet_state.loop_state.event_local_states.BLACK_MIRROR = {"locked": true}
	wet_state.meta_progress.failure_knowledge.C4 = {"verified_prefix": []}
	check(not SCRIPT.segment("EP02_C4_ACTUAL_001", wet_state).get("ids", []).has("EP02_C4_ACTUAL_002"), "zero verified wet segments cannot narrate successful entry and branches")
	wet_state.meta_progress.failure_knowledge.C4.verified_prefix = ["entry", "short_branch", "long_branch"]
	check(SCRIPT.segment("EP02_C4_ACTUAL_001", wet_state).get("ids", []).has("EP02_C4_ACTUAL_002"), "verified three-segment prefix permits its actual sensory narration")
	wet_state.loop_state.event_local_states.BLACK_MIRROR.locked = false
	check(not SCRIPT.segment("EP02_C4_ACTUAL_001", wet_state).get("ids", []).has("EP02_C4_ACTUAL_002"), "permanent prefix knowledge cannot fabricate the current loop's uncommitted physical reaction")
	var compound_state := state.duplicate(true)
	check(preload("res://scripts/systems/sheet_dialogue_effects.gd").apply(compound_state, ["EP02_C21_003"]).ok, "compound source knowledge applies")
	check(compound_state.meta_progress.knowledge_entries.get("KN_C21_WATER_FIRST", false) and compound_state.meta_progress.knowledge_entries.get("KN_C21_STABILIZER_BEFORE_ACTIVE", false), "semicolon separated information IDs remain independently queryable")
	check(not compound_state.meta_progress.knowledge_entries.has("KN_C21_WATER_FIRST;KN_C21_STABILIZER_BEFORE_ACTIVE"), "compound source metadata cannot become a synthetic knowledge ID")
	var unverified := state.duplicate(true)
	check(preload("res://scripts/systems/sheet_dialogue_effects.gd").apply(unverified, ["EP02_C4_003", "EP02_C4_DRY_SUCCESS_001", "EP02_C3_CARD_SUCCESS_001", "EP02_J3_SUCCESS_001"]).ok, "unverified story metadata is safely inspected")
	for key in ["KN_C4_OVERLAY", "KN_C4_ROUTE", "KN_C3_RATIO", "KN_J3_MAP_REQUIRED"]:
		check(not unverified.meta_progress.knowledge_entries.has(key), "reading alone cannot forge validated knowledge: " + key)
	unverified.loop_state.event_local_states.BLACK_MIRROR = {"rotation": 90, "flipped": false, "anchored": true}
	check(preload("res://scripts/systems/sheet_dialogue_effects.gd").apply(unverified, ["EP02_C4_003"]).ok and unverified.meta_progress.knowledge_entries.get("KN_C4_OVERLAY", false), "actual overlay predicate permits verified source fact")
	var unresolved := state.duplicate(true)
	unresolved.meta_progress.failure_knowledge.C4 = {"status": "active", "attempts": 1}
	check(preload("res://scripts/systems/sheet_dialogue_effects.gd").apply(unresolved, ["EP02_C5_005"]).ok and unresolved.meta_progress.failure_knowledge.C4.status == "active", "reading C5 text cannot clear an unopened mirror failure")
	unresolved.meta_progress.knowledge_entries.mirror_tracing_acquired = true
	check(preload("res://scripts/systems/sheet_dialogue_effects.gd").apply(unresolved, ["EP02_C5_005"]).ok and unresolved.meta_progress.failure_knowledge.C4.status == "resolved" and unresolved.meta_progress.failure_knowledge.C4.attempts == 1, "C5 exposure source effect resolves actual failure without losing attempt history")
	for row in SCRIPT.source("EP02").nodes:
		var line := SCRIPT.line(row.node_id, state, "ko-KR")
		var raw := CONTENT.definition("NB_" + row.node_id, int(SCRIPT.source("EP02").notebook_versions["NB_" + row.node_id]))
		check(raw.locales["ko-KR"].body == row.ko_KR, "EP02 developer source remains verbatim: " + row.node_id)
		check(not line.is_empty() and line.get("text") == SCRIPT.text(row.node_id, "ko-KR"), "EP02 player Korean: " + row.node_id)
		check(not SCRIPT.line(row.node_id, state, "en-US").is_empty(), "EP02 fallback: " + row.node_id)
	var mirror_intro := SCRIPT.segment("EP02_C0_001", state)
	check(mirror_intro.ok and mirror_intro.kind == "choice" and mirror_intro.next == "EP02_CHOICE_C0_RESPONSE", "C0 includes unnamed new dialogue before its choice")
	for content_id in SCRIPT.source("EP02").notebook_versions:
		var definition := CONTENT.definition(content_id, SCRIPT.notebook_version(content_id))
		if definition.entry_kind != "options_presented": continue
		var route: String = definition.source_symbol
		var cases := {}
		if route in SCRIPT.source("EP02").get("conditional_choice_routes", []):
			cases[route] = SCRIPT.visible_choice_edges(route, state)[0].target_id
		var menu := SCRIPT.segment(route, state, "ko-KR", [], cases)
		check(menu.ok and menu.kind == "choice" and menu.next == route, "all EP02 authored menus are real choices: " + route)
	var prologue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/sheets/prologue_runtime.json"))
	var prologue_count := 0
	for row in prologue.nodes:
		if row.package_id != "CNT-EP00": continue
		prologue_count += 1
		check(PROLOGUE_TEXT.localized_text["ko-KR"].get(row.node_id) == row.ko_KR, "prologue resource matches sheet: " + row.node_id)
	check(prologue_count == 210, "all 210 non-overlapping prologue nodes checked")
	check(CONTENT.definition("NB_PR_P3_OPTIONS", SCRIPT.notebook_version("NB_PR_P3_OPTIONS")).locales["ko-KR"].author == "이건 누가 쓴 장부야?", "new P3 choice version")
	check(CONTENT.definition("NB_PR_P3_OPTIONS", 1).locales["ko-KR"].author == "누가 쓴 장부입니까?", "old P3 choice remains immutable")
	for row in SCRIPT.source().nodes:
		var variables := {"knowledge_count": 3} if row.ko_KR.contains("{knowledge_count}") else {}
		var line := SCRIPT.line(row.node_id, state, "ko-KR", variables)
		check(not line.is_empty() and line.get("text") == String(row.ko_KR).replace("{knowledge_count}", "3"), "Korean: " + row.node_id)
		check(not SCRIPT.line(row.node_id, state, "en-US", variables).is_empty(), "fallback: " + row.node_id)
	for index in range(2):
		var event := "EP01_DLG_EDGAR_%03d" % (index + 1)
		var entry := event + "_010"
		var segment := SCRIPT.segment(entry, state)
		check(segment.ok and segment.next == "EP01_HUB_DAILY_HALL", "returns to hub: " + event)
		check(SCRIPT.completed_persistent_flags([entry]).is_empty(), "intermediate line cannot complete: " + event)
		check(SCRIPT.completed_persistent_flags(segment.ids).get(event + "_complete", false), "last line completes: " + event)
	for mask in range(4):
		state.meta_progress["flags"] = {}
		for index in range(2):
			state.meta_progress.flags["EP01_DLG_EDGAR_%03d_complete" % (index + 1)] = not bool(mask & (1 << index))
		var id := SCRIPT.options_content_id("EP01_CHOICE_EDGAR_HALL", state)
		var row := CONTENT.definition(id, SCRIPT.notebook_version(id))
		check(not row.is_empty(), "variant exists: " + str(mask))
		check(row.get("choices", []).size() == SCRIPT.visible_choice_edges("EP01_CHOICE_EDGAR_HALL", state).size(), "visible menu/record match: " + str(mask))
	var hub := SCRIPT.segment("EP01_HUB_DAILY_HALL", state)
	check(hub.ok and hub.kind == "choice", "daily hall is selectable")
	var game := get_tree().root.get_node("GameState")
	var save := get_tree().root.get_node("SaveManager")
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.loop_state.day_index = 1
	seed.loop_state.location_id = "M1_CENTRAL_HALL"
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"SHEET_EFFECT_SEED").get("ok", false), "legacy snapshot without flags installs")
	const SLOT := "__test_sheet_sync_effects"
	save.delete_test_slot(SLOT)
	var session := ChapterOneSession.new(game, save, SLOT)
	check(session.finish_sheet_conversation(["EP01_DLG_EDGAR_001_010"]).get("ok", false), "partial receipt commits without completion")
	check(not game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_001_complete", false), "partial receipt remains incomplete")
	check(session.finish_sheet_conversation(["EP01_DLG_EDGAR_001_100"]).get("ok", false), "final receipt commits atomically")
	check(game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_001_complete", false), "final receipt persisted flag")
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "new optional flags reload from disk")
	check(game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_001_complete", false), "completion survives load")
	var malformed: Dictionary = game.get_snapshot()
	malformed.meta_progress.flags.EP01_DLG_EDGAR_001_complete = "true"
	check(not StateSnapshotValidator.new().validate(malformed).get("ok", false), "non-boolean flags rejected")
	save.delete_test_slot(SLOT)
	await hall_flow(game, save)
	await mirror_flow(game, save)
	await cleaner_flow(game, save)
	await cleaner_discard_flow(game, save)
	await diagnostic_persistence_flow(game, save)
	await journal_reference_flow(game, save)
	await failure_flow(game, save)
	await legacy_dry_modal(game, save)
	for failure in failures: printerr(failure)
	var coverage_file := FileAccess.open("user://sheet-sync-observed.json", FileAccess.WRITE)
	check(coverage_file != null, "actual disclosure evidence can be written")
	if coverage_file != null:
		coverage_file.store_string(JSON.stringify({"nodes": observed_sheet_nodes.keys(), "test": "actual controller flows; excludes static source rendering"}, "\t"))
		coverage_file.close()
	print("SHEET_SYNC_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func run_discard_only() -> void:
	await cleaner_discard_flow(get_tree().root.get_node("GameState"), get_tree().root.get_node("SaveManager"))
	for failure in failures: printerr(failure)
	print("SHEET_DISCARD_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func run_diagnostics_only() -> void:
	await diagnostic_persistence_flow(get_tree().root.get_node("GameState"), get_tree().root.get_node("SaveManager"))
	for failure in failures: printerr(failure)
	print("SHEET_DIAGNOSTIC_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func drain(view: Control) -> void:
	for step in range(150):
		if not view._dialogue_active:
			collect_sheet_disclosures()
			return
		view._advance_dialogue()
	check(false, "dialogue terminates")


func short_reaction_variants(initial: Dictionary) -> void:
	const SHORT := preload("res://scripts/systems/ep02_short_reactions.gd")
	var state := initial.duplicate(true)
	state.loop_state.location_id = "M1_MIRROR_GALLERY"
	state.meta_progress.knowledge_entries.c2_cleaning_record = true
	state.loop_state.event_local_states.BLACK_MIRROR = {"materials_ready": true}
	check(SHORT.available(state).get("MARA1") == "EP02_REL_MARA1_C2_FIRST", "Mara1 first short reaction has a normalized room binding")
	check(not SHORT.available(state).has("MARA2") and not SHORT.available(state).has("IRIS"), "original mirror metadata cannot summon relocated servants")
	state.meta_progress.failure_knowledge.C4 = {"status": "active", "attempts": 1}
	state.meta_progress.servants.mara1.bond = 4
	check(SHORT.available(state).get("MARA1") == "EP02_REL_MARA1_CSHORT_HIGH", "Mara1 support flavor requires prepared materials and strong bond")
	state.meta_progress.servants.mara1.alert = 4
	check(SHORT.available(state).get("MARA1") == "EP02_REL_MARA1_CSHORT_ALERT", "Mara1 alert flavor takes precedence over support")
	check(not SHORT.available(state).has("EDGAR"), "unwitnessed Edgar has no free-floating repeat reaction")
	state.loop_state.event_local_states.BLACK_MIRROR.witnesses = ["EDGAR"]
	state.loop_state.event_local_states.BLACK_MIRROR.intervention_handled = true
	check(SHORT.available(state).get("EDGAR") == "EP02_REL_EDGAR_C4_REPEAT", "actual intervention provides Edgar repeat presence")
	for pair in [[0, "LOW"], [2, "MID"], [4, "HIGH"]]:
		state.meta_progress.servants.edgar.alert = pair[0]
		check(SHORT.edgar_warning(state) == "EP02_REL_EDGAR_C0_" + pair[1], "Edgar boundary warning matches alert tier")
	state.loop_state.location_id = "M1_KITCHEN"
	state.meta_progress.knowledge_entries.c21_chemical_record = true
	check(SHORT.available(state).get("LUCA") == "EP02_REL_LUCA_C21_LOW", "Luca low-bond flavor")
	state.meta_progress.servants.luca.bond = 4
	check(SHORT.available(state).get("LUCA") == "EP02_REL_LUCA_C21_HIGH", "Luca high-bond flavor")
	state.meta_progress.servants.luca.alert = 4
	check(SHORT.available(state).get("LUCA") == "EP02_REL_LUCA_CSHORT_ALERT", "Luca alert flavor after failure preparation")
	state.loop_state.event_local_states.BLACK_MIRROR.mixture_test_failed = true
	check(SHORT.available(state).get("LUCA") == "EP02_REL_LUCA_C3_ERROR", "Luca reassurance requires an actual recorded test failure")
	state.loop_state.location_id = "M1_COLOR_ROOM_ENTRY"
	check(SHORT.available(state).get("MARA2") == "EP02_REL_MARA2_PRE", "Mara2 prediagnostic line")
	state.meta_progress.knowledge_entries.c5_info_complete = true
	check(SHORT.available(state).get("MARA2") == "EP02_REL_MARA2_POST", "Mara2 postdiagnostic line")
	state.meta_progress.knowledge_entries.mara2_archive_index_known = true
	check(SHORT.available(state).get("MARA2") == "EP02_REL_MARA2_INDEX", "Mara2 index flavor requires actual index knowledge")
	state.loop_state.location_id = "M1_GREENHOUSE"
	check(SHORT.available(state).get("IRIS") == "EP02_REL_IRIS_PRE", "Iris line before seasonal conversation")
	state.meta_progress.event_history.EP02_DIALOGUE_EFFECTS = {"EFF_EP02_0044": true}
	check(SHORT.available(state).get("IRIS") == "EP02_REL_IRIS_POST", "Iris line after real conversation receipt")

func collect_sheet_disclosures() -> void:
	var archive: Dictionary = get_tree().root.get_node("GameState").get_snapshot().meta_progress.dialogue_history
	for entry in archive.get("entries", []):
		var observation: Dictionary = entry.get("observation", {})
		var row := CONTENT.definition(observation.content_id, int(observation.content_version))
		for segment in observation.get("segments", []):
			var source_id: String = row.get("source_sheet_segments", {}).get(segment.get("segment_id", ""), "")
			if not SCRIPT.node(source_id).is_empty(): observed_sheet_nodes[source_id] = true
		if observation.get("producer_id") != "EP02_SHEET": continue
		var identity: String = row.get("source_symbol", "")
		if not SCRIPT.node(identity).is_empty(): observed_sheet_nodes[identity] = true


func legacy_dry_modal(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_legacy_dry"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.journal_stage = 2
	for key in ["PROLOGUE_COMPLETE", "c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record"]: seed.meta_progress.knowledge_entries[key] = true
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_MIRROR_GALLERY"
	seed.loop_state.event_local_states.BLACK_MIRROR = {"materials_ready": true, "cleaner_ready": true, "signal_ready": true}
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"LEGACY_DRY_SEED").get("ok", false), "legacy dry fixture installs")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	var row := CONTENT.definition("NB_MODAL_MIRROR_ROUTE_OPTIONS", 1)
	var segments := {"result_anchor_missing": {}, "route_empty": {}}
	for id in row.default_segments: segments[id] = {}
	var descriptor := CONTENT.descriptor("NB_MODAL_MIRROR_ROUTE_OPTIONS", 1, segments)
	var old_body := preload("res://scripts/systems/modal_notebook.gd").route_body(descriptor, "ko-KR")
	view._show_recorded_choice(row.locales["ko-KR"].header, old_body, [{"label": row.locales["ko-KR"].option_0, "action": view._close_modal}, {"label": row.locales["ko-KR"].option_1, "action": view._replay_route_feedback}], descriptor, {}, view._mirror_modal_view("mirror_route", view._mirror().mirror_local()))
	check(view._modal_active, "legacy v1 dry modal really opens and saves")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "legacy dry modal reloads with current catalogs")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._recorded_modal_request.get("history_context", {}).get("notebook_content", {}).get("content_version", 0) == 1, "saved dry modal keeps historical definition version")
	check(view._recorded_modal_request.get("body", "") == old_body, "saved dry modal keeps the exact historical displayed body")
	if press(view, 0): check(not view._modal_active, "old dry return action remains selectable")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)


func cleaner_discard_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_discard"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.journal_stage = 2
	for key in ["PROLOGUE_COMPLETE", "c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record", "c3_formula_verified"]: seed.meta_progress.knowledge_entries[key] = true
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_KITCHEN"
	seed.loop_state.event_local_states.BLACK_MIRROR = {"materials_ready": true}
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"DISCARD_SEED").get("ok", false), "discard fixture installs")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	view._do("c_pour", "water", false)
	check(view._mirror().mirror_local().mixture.water == 1, "discard fixture performs a real initial pour after its introduction")
	var original: Dictionary = view._mirror().mirror_local().mixture.duplicate(true)
	view._hotspot_layer.get_node("c_discard").pressed.emit()
	check(view._modal_active and view._recorded_modal_request.get("body", "") == SCRIPT.text("EP02_C3_UI_DISCARD_CONFIRM"), "real discard control displays authored confirmation")
	check(view._recorded_modal_request.get("focus", -1) == 0, "discard defaults to cancel")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "discard confirmation reloads")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	if "--sheet-discard-only" in OS.get_cmdline_user_args(): print("DISCARD_ROUNDTRIP water types=", typeof(original.water), "/", typeof(view._mirror().mirror_local().mixture.water), " values=", original.water, "/", view._mirror().mirror_local().mixture.water)
	check(view._modal_active and StateSnapshotValidator.same_persisted_value(original, view._mirror().mirror_local().mixture), "restoring confirmation never discards automatically")
	if press(view, 0): check(StateSnapshotValidator.same_persisted_value(original, view._mirror().mirror_local().mixture), "normal cancellation leaves all ingredients intact")
	view._do("c_pour", "stabilizer", false)
	view._do("c_inspect", "OBJ_C3_MIX_STATION")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_FB_DIFFUSION_WAIT"), "inspection exposes only actual undispersed stabilizer")
	drain(view)
	view._do("c_disperse")
	check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_DIFFUSE")), "actual stabilizer dispersion carries its source sensory caption")
	drain(view)
	view._do("c_pour", "water", false)
	check(preload("res://data/puzzles/puzzle_black_mirror.tres").order_locked(view._mirror().mirror_local().mixture), "returning to water after additive creates the actual order lock")
	var locked: Dictionary = game.get_snapshot()
	check(not view.session.act("c_mix").get("ok", false) and game.get_snapshot() == locked, "order lock blocks changes without consuming state")
	view._do("c_mix")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_UI_POUR_DISABLED"), "order-lock rejection displays exact source warning")
	drain(view)
	var locked_mix: Dictionary = view._mirror().mirror_local().mixture.duplicate(true)
	view._confirm_cleaner_discard()
	if press(view, 0):
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_UI_DISCARD_CANCEL"), "locked cancellation explains the retained safety lock")
		drain(view)
	check(view._mirror().mirror_local().mixture == locked_mix, "locked cancellation cannot repair or consume the mixture")
	view._confirm_cleaner_discard()
	var controlled := preload("res://scripts/tests/notebook_mirror_smoke.gd").ControlledSave.new()
	controlled.delegate = save
	controlled.reject_game = true
	view.session._save = controlled
	press(view, 1)
	check(controlled.rejected_game_saves == 1 and view._mirror().mirror_local().mixture == locked_mix, "failed domain save cannot apply disposal")
	view.session._save = save
	view.queue_free()
	await get_tree().process_frame
	controlled.free()
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "failed disposal can reload its saved state")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(StateSnapshotValidator.same_persisted_value(locked_mix, view._mirror().mirror_local().mixture), "reload does not replay the rejected destructive action")
	drain(view)
	if not view._modal_active: view._confirm_cleaner_discard()
	if press(view, 1): drain(view)
	check(view._mirror().mirror_local().mixture == preload("res://data/puzzles/puzzle_black_mirror.tres").empty_mixture(), "confirmed disposal clears the physical mixture")
	check(view.session.known("c3_formula_verified") and view._mirror().mirror_local().materials_ready, "disposal preserves permanent formula and prepared tools")
	for spec in [[4, 1, 3, "EP02_C3_FB_RATIO_ACID"], [4, 2, 2, "EP02_C3_FB_RATIO_BASE"]]:
		for index in range(spec[0]): view._do("c_pour", "water", false)
		for index in range(spec[1]): view._do("c_pour", "stabilizer", false)
		view._do("c_disperse")
		drain(view)
		for index in range(spec[2]): view._do("c_pour", "active", false)
		view._do("c_mix")
		drain(view)
		view._do("c_test")
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text(spec[3]), "actual one-sided excess uses its source test-circle feedback: " + spec[3])
		check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_TEST_BAD")), "actual nonneutral test includes the source open-circle caption")
		drain(view)
		check(not view._mirror().mirror_local().cleaner_ready, "non-neutral test cannot produce cleaner")
		view._do("c_discard")
		drain(view)
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)

func diagnostic_persistence_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_diagnostics"
	const DIAGNOSTICS := preload("res://scripts/systems/ep02_diagnostic_state.gd")
	const CAPTIONS := preload("res://scripts/systems/ep02_sensory_captions.gd")
	check(CAPTIONS.decorate(["EP02_C3_FB_EMPTY"], ["EP02_CAP_TEST_BAD"], {"captions_enabled": false}) == ["EP02_C3_FB_EMPTY"], "turning sensory captions off preserves indispensable feedback")
	check(CAPTIONS.decorate(["EP02_CAP_TRACE"], ["EP02_CAP_TRACE", "NOT_A_CAPTION"], {}) == ["EP02_CAP_TRACE"], "caption policy neither duplicates lines nor accepts unknown source IDs")
	check(CAPTIONS.wet({}).is_empty(), "unexecuted wet route cannot announce opening or hardening")
	check(CAPTIONS.wet({"locked": true}) == ["EP02_CAP_HARDEN"] and CAPTIONS.wet({"surface_open": true}) == ["EP02_CAP_OPEN", "EP02_CAP_COLD"], "wet captions distinguish committed failure and actual exposure")
	const ROUTE_NOTES := preload("res://scripts/systems/modal_notebook.gd")
	var full_path: Array = ["entry", "short_branch", "long_branch", "clockwise_ring"]
	for count in range(5):
		var local := {"rotation": 90, "flipped": false, "anchored": true, "path": full_path.slice(0, count)}
		for enabled in [false, true]:
			var shown := ROUTE_NOTES.route_options(local, {"captions_enabled": enabled, "motion_mode": "standard"})
			check(shown.segments.has("caption_entry") == (enabled and count >= 1), "dry entry caption requires a verified prefix and the caption setting")
			check(shown.segments.has("caption_branches") == (enabled and count >= 3), "dry branch caption cannot precede both real branch responses")
			check(shown.segments.has("caption_ring") == (enabled and count == 4), "dry ring caption requires actual closure")
			check(shown.segments.has("result_success") == (count == 4), "essential route verdict survives disabled sensory captions")
	for mode in ["standard", "reduced", "static"]:
		var shown := ROUTE_NOTES.route_options({"rotation": 90, "flipped": false, "anchored": true, "path": full_path}, {"captions_enabled": false, "motion_mode": mode})
		check(shown.segments.has("motion_assist") == (mode != "standard"), "motion assistance describes only an actually selected reduced/static mode")
	var profiles := AccessibilityProfileStore.new()
	var previous_profile: Dictionary = profiles.load_profile().profile
	var profile := previous_profile.duplicate(true)
	profile.captions_enabled = true
	profile.audio.muted = false
	profile.audio.master = 1.0
	profile.audio.effects = 1.0
	check(profiles.save_profile(profile).get("ok", false), "diagnostic caption fixture enables sensory captions")
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.journal_stage = 2
	for key in ["PROLOGUE_COMPLETE", "c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record", "mirror_tracing_acquired"]: seed.meta_progress.knowledge_entries[key] = true
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.meta_progress.knowledge_entries.c5_raw_capture = BlackMirrorSession.CHANNELS.duplicate(true)
	seed.meta_progress.knowledge_entries.self_authored_mark = {"type": "sentence", "text": "어제의 표식", "day": 1}
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_MIRROR_GALLERY"
	seed.loop_state.event_local_states.BLACK_MIRROR = {"surface_open": true}
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"DIAGNOSTIC_SEED").get("ok", false), "diagnostic persistence fixture installs")
	check(DIAGNOSTICS.required_count(game.get_snapshot()) == 0, "unexamined raw capture cannot pretend required diagnostics were inspected")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	for mode in ["color_pattern_label", "pattern_label", "label_only"]:
		profile.signature_mode = mode
		check(profiles.save_profile(profile).get("ok", false), "signature mode saves: " + mode)
		view._render_room()
		for owner in BlackMirrorSession.CHANNELS:
			var signature: Control = view._hotspot_layer.get_node("CHANNEL_SIGNATURE_" + owner)
			check(signature.owner_id == owner and signature.signature_mode == mode and signature.visible == (mode != "label_only") and not signature.is_processing(), "actual channel glyph respects selected signature mode without animation: " + owner + "/" + mode)
			if mode == "pattern_label": check(signature.ink() == Color.WHITE, "monochrome mode does not depend on owner hue: " + owner)
			check(not view._hotspot_layer.get_node("SCAN_" + owner).text.is_empty(), "channel names remain readable in every signature mode")
	profile.signature_mode = "color_pattern_label"
	check(profiles.save_profile(profile).get("ok", false), "channel fixture restores its initial signature mode")
	view._render_room()
	profile.signature_mode = "pattern_label"
	profile.audio.muted = true
	check(profiles.save_profile(profile).get("ok", false), "quiet monochrome channel profile saves")
	view._render_room()
	for owner in BlackMirrorSession.CHANNELS:
		var signature = view._hotspot_layer.get_node("CHANNEL_SIGNATURE_" + owner)
		check(signature.quiet_channel and signature.visible and signature.ink() == Color.WHITE and signature.get_meta("is_placeholder", false), "quiet mode shows a non-color schematic cue without claiming a final audio sample: " + owner)
		check(not view._hotspot_layer.get_node("CHANNEL_INDEX_" + owner).text.is_empty(), "monochrome channels have explicit visible numbers")
	view._open_sheet_objects()
	if press_hint(view, 0):
		check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_C5_CH_MONO_MODE")) and view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_C5_CH_AUDIO_REDUCED")), "actual quiet/monochrome profile exposes matching source mode notices")
		drain(view)
	profile.signature_mode = "color_pattern_label"
	profile.audio.muted = false
	check(profiles.save_profile(profile).get("ok", false), "mode notice fixture restores its active profile")
	view._render_room()
	view._open_sheet_objects()
	if press_hint(view, 0):
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_SYS_UI_C5_REQUIRED"), "ordinary exploration menu opens the source diagnostic guide")
		drain(view)
	check(DIAGNOSTICS.required_count(game.get_snapshot()) == 0, "reading instructions cannot manufacture mandatory diagnostic knowledge")
	for key in ["BODY", "EDGAR", "SUBJECT"]:
		view._do("c_scan", key)
		drain(view)
	check(DIAGNOSTICS.required_count(game.get_snapshot()) == 1, "owner and subject-authority scans cannot count as personality inspection")
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	view._do("routine")
	drain(view)
	var world_session: ChapterOneSession = view.session
	view.queue_free()
	await get_tree().process_frame
	var slept := world_session.sleep()
	check(slept.get("ok", false), "actual normal reset completes between partial diagnostic investigations: " + str(slept.get("error_id", slept.get("error_ids", slept.get("text", "")))))
	check(game.get_snapshot().loop_state.day_index == 3, "diagnostic persistence uses a real new day rather than a fabricated checkpoint")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	check(view._mirror().mirror_local().diagnostics_scanned.is_empty() and view._mirror().mirror_local().channels_scanned.is_empty(), "physical per-day scan state resets completely")
	check(DIAGNOSTICS.required_count(game.get_snapshot()) == 1 and DIAGNOSTICS.seen(game.get_snapshot(), "EDGAR") and DIAGNOSTICS.seen(game.get_snapshot(), "SUBJECT"), "actual diagnostic and channel knowledge persists across reset")
	travel(view, ["M1_CENTRAL_HALL", "M1_PARLOR", "M1_MIRROR_GALLERY"])
	for key in ["BODY", "EDGAR", "SUBJECT"]:
		view._do("c_scan", key)
		var identity: String = "EP02_C5_HOT_BODY_REPEAT" if key == "BODY" else "EP02_C5_CH_%s_REPEAT" % key
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text(identity), "post-reset inspection uses permanent repeat state: " + key)
		drain(view)
	check(game.get_snapshot().meta_progress.knowledge_entries.c5_inspections.size() == 3, "reinspection cannot duplicate persistent inspection IDs")
	profile.captions_enabled = false
	check(profiles.save_profile(profile).get("ok", false), "sensory caption setting can be disabled")
	view._do("c_scan", "MARA2")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C5_CH_MARA2_FIRST"), "captions-off channel inspection retains its authored puzzle information")
	check(not view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_PURPLE")), "captions-off channel inspection does not expose optional sensory text")
	drain(view)
	profile.captions_enabled = true
	check(profiles.save_profile(profile).get("ok", false), "sensory caption setting can be reenabled")
	view._do("c_scan", "MARA2")
	check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_PURPLE")), "actual Mara2 repeat inspection exposes its authored three-note caption")
	drain(view)
	check(DIAGNOSTICS.required_count(game.get_snapshot()) == 1, "sensory text cannot substitute optional Mara2 for required personality inspection")
	for owner in ["LUCA", "MARA1", "IRIS"]:
		view._do("c_scan", owner)
		if owner == "IRIS": check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_FIVE")), "five-channel comparison caption requires all five actual channel inspections")
		drain(view)
	view._hotspot_layer.get_node("C5_INFO").pressed.emit()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C5_CH_SCAN_PROGRESS_2"), "record control reports actual one-of-two permanent progress")
	drain(view)
	view._do("c_scan", "PERSONALITY")
	drain(view)
	view._hotspot_layer.get_node("C5_INFO").pressed.emit()
	check(view._modal_active and view._recorded_modal_request.get("body", "") == SCRIPT.text("EP02_C5_CH_TRACE_PROMPT"), "real tracing control opens the authored confirmation")
	check(not view.session.known("c5_info_complete") and "M1_GREENHOUSE" not in view.session.available_rooms(), "opening confirmation cannot grant progress or greenhouse access")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "unconfirmed tracing prompt reloads")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._modal_active and not view.session.known("c5_info_complete"), "reload never accepts tracing consent automatically")
	if press(view, 0): check(not view.session.known("c5_info_complete"), "cancel preserves inspected information without acquiring the tracing record")
	view._confirm_sheet_trace()
	var controlled := preload("res://scripts/tests/notebook_mirror_smoke.gd").ControlledSave.new()
	controlled.delegate = save
	controlled.reject_game = true
	view.session._save = controlled
	press(view, 1)
	check(controlled.rejected_game_saves == 1 and not view.session.known("c5_info_complete") and not view.session.known("C5_MIRROR_TRACING"), "failed tracing save cannot grant record ownership")
	view.session._save = save
	view.queue_free()
	await get_tree().process_frame
	controlled.free()
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "rejected tracing action reloads safely")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(not view.session.known("c5_info_complete"), "rejected tracing action is not replayed on reload")
	drain(view)
	if not view._modal_active: view._confirm_sheet_trace()
	if press(view, 1): drain(view)
	check(view.session.known("c5_info_complete") and view.session.known("C5_MIRROR_TRACING"), "successful explicit confirmation owns the permanent tracing")
	check("M1_GREENHOUSE" in view.session.available_rooms(), "confirmed tracing unlocks only the approved ordinary greenhouse route")
	check(game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_EP02_C5_CH_TRACE_DONE" and entry.observation.content_version >= 2), "tracing completion really discloses the natural-language authored version")
	check(game.get_snapshot().meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0035", false), "confirmation does not skip the source tracing-completion effects")
	check(game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_EP02_CAP_TRACE"), "successful tracing really discloses the optional source sensory caption")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)
	check(profiles.save_profile(previous_profile).get("ok", false), "diagnostic caption fixture restores the original accessibility profile")


func journal_reference_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_journal_reference"
	const REFERENCES := preload("res://scripts/systems/ep02_journal_reference.gd")
	const NOTICES := preload("res://scripts/systems/ep02_disclosure_notices.gd")
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.journal_stage = 2
	seed.meta_progress.notebook_persistence_confirmed = true
	for key in ["PROLOGUE_COMPLETE", "c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record", "mirror_tracing_acquired", "c5_info_complete", "C5_MIRROR_TRACING", "KN_B1_LIBRARY_WINDOW"]: seed.meta_progress.knowledge_entries[key] = true
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.meta_progress.knowledge_entries.self_authored_mark = {"type": "sentence", "text": "어제의 표식", "day": 1}
	seed.meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
	seed.loop_state.day_index = 2
	seed.loop_state.time_block = "evening_free"
	seed.loop_state.location_id = "M1_LIBRARY_INNER"
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"JOURNAL_REFERENCE_SEED").get("ok", false), "J3 reference fixture installs")
	var policy := seed.duplicate(true)
	policy.meta_progress.knowledge_entries.erase("c2_cleaning_record")
	policy.meta_progress.knowledge_entries.erase("c21_chemical_record")
	check(NOTICES.after("EP02_C2_001", policy, {}).is_empty(), "notice policy cannot claim unread coating information")
	policy.meta_progress.knowledge_entries.c2_cleaning_record = true
	check(NOTICES.after("EP02_C2_001", policy, {}) == ["EP02_SYS_UI_INFO_1"], "coating-only investigation shows actual one-of-two progress")
	policy.meta_progress.knowledge_entries.c21_chemical_record = true
	check(NOTICES.after("EP02_C21_001", policy, {}) == ["EP02_SYS_UI_INFO_DONE"], "both investigated records show actual two-of-two progress")
	policy.meta_progress.knowledge_entries.c3_formula_verified = true
	check(NOTICES.after("EP02_C3_SUCCESS_001", policy, {}).is_empty(), "formula knowledge alone cannot award or announce a physical cleaner")
	policy.loop_state.event_local_states.BLACK_MIRROR = {"cleaner_ready": true}
	check(NOTICES.after("EP02_C3_SUCCESS_001", policy, {"captions_enabled": false}).has("EP02_C3_UI_ACQUIRE_LABEL"), "actual cleaner acquisition remains visible without sensory captions")
	policy.loop_state.event_local_states.BLACK_MIRROR = {"locked": false}
	policy.meta_progress.failure_knowledge.C4 = {"status": "active"}
	check(NOTICES.after("EP02_CF_001", policy, {}).is_empty(), "old failure knowledge cannot announce a new physical lock")
	policy.loop_state.event_local_states.BLACK_MIRROR.locked = true
	check(NOTICES.after("EP02_CF_001", policy, {}).has("EP02_SYS_UI_CF_FREE"), "actual failure notice preserves free investigation rather than forcing sleep")
	policy.meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
	check(NOTICES.after("EP02_J3_MEMORY_001", policy, {}).is_empty(), "optional memory notices require actual reference-point investigation")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	var before: Dictionary = game.get_snapshot()
	check(not view.session.act("j3_restore").get("ok", false) and game.get_snapshot() == before, "J3 cannot restore before a real reference comparison")
	view._hotspot_layer.get_node("J3_OVERLAY").pressed.emit()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_UI_PLACE_TRACE"), "real tracing control reveals the authored placement feedback")
	drain(view)
	view._hotspot_layer.get_node("J3_POINT_BED").pressed.emit()
	drain(view)
	before = game.get_snapshot()
	check(not view.session.act("j3_point", "BED").get("ok", false) and game.get_snapshot() == before, "duplicate reference rejects without world or failure-state consumption")
	view._hotspot_layer.get_node("J3_COMPARE").pressed.emit()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_FB_ONE_POINT"), "one real point receives the one-point source response")
	drain(view)
	var controlled := preload("res://scripts/tests/notebook_mirror_smoke.gd").ControlledSave.new()
	controlled.delegate = save
	controlled.reject_game = true
	view.session._save = controlled
	view._hotspot_layer.get_node("J3_POINT_GREEN").pressed.emit()
	check(controlled.rejected_game_saves == 1 and view._mirror().mirror_local().j3_reference_points == ["BED"], "failed reference save cannot add a phantom second point")
	view.session._save = save
	controlled.free()
	view._hotspot_layer.get_node("J3_POINT_GREEN").pressed.emit()
	drain(view)
	view._hotspot_layer.get_node("J3_COMPARE").pressed.emit()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_FB_TWO_POINTS"), "two real points receive the two-point source response")
	drain(view)
	view._hotspot_layer.get_node("J3_POINT_CLOCK").pressed.emit()
	drain(view)
	var before_memory: Dictionary = view._mirror().mirror_local().duplicate(true)
	view._open_j3_memory()
	check(view._modal_active and not view._j3_memory_seen(), "optional impression opens a real choice without reading the memory automatically")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "optional memory chooser reloads")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._modal_active and not view._j3_memory_seen(), "chooser reload cannot auto-select the memory")
	if press(view, 0): check(not view._modal_active and not view._j3_memory_seen() and StateSnapshotValidator.same_persisted_value(view._mirror().mirror_local(), before_memory), "skipping memory closes the chooser without changing puzzle inputs")
	view._open_j3_memory()
	if press(view, 1): drain(view)
	check(view._j3_memory_seen() and StateSnapshotValidator.same_persisted_value(view._mirror().mirror_local(), before_memory), "actually reading the memory records its source without solving reference comparison")
	view._open_j3_memory()
	check(view._recorded_modal_request.get("history_context", {}).get("notebook_content", {}).get("content_id") == "NB_MODAL_EP02_J3_MEMORY_REPLAY_OPTIONS", "only an observed memory enables the replay chooser")
	if press(view, 1): drain(view)
	check(view._status_label.text == SCRIPT.text("EP02_J3_UI_MEMORY_REPLAY") and StateSnapshotValidator.same_persisted_value(view._mirror().mirror_local(), before_memory), "actual replay uses the clipped source reminder without changing puzzle inputs")
	view._hotspot_layer.get_node("J3_FLIP").pressed.emit()
	before = game.get_snapshot()
	check(not view.session.act("j3_compare").get("ok", false) and game.get_snapshot() == before, "flipping early cannot skip the front-page contradiction")
	view._hotspot_layer.get_node("J3_FLIP").pressed.emit()
	view._hotspot_layer.get_node("J3_COMPARE").pressed.emit()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_FB_ALL_FALSE"), "three marked points on the front reveal the false-alignment source response")
	drain(view)
	check(not REFERENCES.ready(view._mirror().mirror_local()), "three points alone cannot finish the front/back comparison")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "partial J3 references reload")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	check(view._mirror().mirror_local().j3_reference_points.size() == 3 and view._mirror().mirror_local().j3_false_alignment_seen and not view._mirror().mirror_local().j3_sides_compared, "reload preserves actual reference progress without completing comparison")
	view._hotspot_layer.get_node("J3_FLIP").pressed.emit()
	view._hotspot_layer.get_node("J3_COMPARE").pressed.emit()
	drain(view)
	check(REFERENCES.ready(view._mirror().mirror_local()), "real reverse-page comparison completes only J3 reference reasoning")
	check(not view.session.known("basement_overlay_solved") and not view.session.known("basement_axis_depths"), "J3 comparison cannot solve D0 orientation or award axis-depth information")
	view._hotspot_layer.get_node("J3_REMOVE").pressed.emit()
	drain(view)
	check(not REFERENCES.ready(view._mirror().mirror_local()) and view._mirror().mirror_local().j3_reference_points.size() == 3, "lifting the tracing preserves reference knowledge but removes its physical placement")
	view._hotspot_layer.get_node("J3_OVERLAY").pressed.emit()
	drain(view)
	check(REFERENCES.ready(view._mirror().mirror_local()), "replacing the tracing reuses the already compared information")
	view._hotspot_layer.get_node("J3_PART_2").pressed.emit()
	check(view._mirror().mirror_local().j3_held_part == 2 and view._mirror().mirror_local().j3_order.is_empty(), "picking a fragment does not place it automatically")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "held J3 fragment reloads")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	check(view._mirror().mirror_local().j3_held_part == 2 and view._hotspot_layer.has_node("J3_DROP_0"), "reload restores a held fragment without silently placing it")
	view._hotspot_layer.get_node("J3_DROP_0").pressed.emit()
	check(view._mirror().mirror_local().j3_order == [2] and view._hotspot_layer.has_node("J3_ORDER_CONFLICT"), "dropping in a wrong position marks the actual conflicting sequence")
	view._hotspot_layer.get_node("J3_CLEAR").pressed.emit()
	for part in range(4):
		view._hotspot_layer.get_node("J3_PART_%d" % part).pressed.emit()
		view._hotspot_layer.get_node("J3_DROP_%d" % part).pressed.emit()
	check(view._mirror().mirror_local().j3_order == [0, 1, 2, 3] and not view._hotspot_layer.has_node("J3_ORDER_CONFLICT"), "all sentence fragments can be reordered through actual pick/drop controls")
	view._hotspot_layer.get_node("J3_RESTORE").pressed.emit()
	check(view._modal_active and view._recorded_modal_request.get("body", "") == SCRIPT.text("EP02_J3_UI_COMMIT_PROMPT") and int(game.get_snapshot().meta_progress.journal_stage) == 2, "restoration control asks for explicit recording consent before progression")
	if press(view, 0): check(int(game.get_snapshot().meta_progress.journal_stage) == 2, "cancelled restoration confirmation keeps the page unfinished")
	view._confirm_sheet_j3_restore()
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "J3 recording confirmation reloads")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._modal_active and int(game.get_snapshot().meta_progress.journal_stage) == 2, "confirmation reload never records the page automatically")
	check(view._mirror().mirror_local().j3_order == [0, 1, 2, 3], "reloaded JSON fragment indices retain canonical integer identity for real restoration")
	controlled = preload("res://scripts/tests/notebook_mirror_smoke.gd").ControlledSave.new()
	controlled.delegate = save
	controlled.reject_game = true
	view.session._save = controlled
	press(view, 1)
	check(controlled.rejected_game_saves == 1 and int(game.get_snapshot().meta_progress.journal_stage) == 2, "rejected J3 recording save cannot grant restored progress; saves=%d stage=%s status=%s modal=%s" % [controlled.rejected_game_saves, str(game.get_snapshot().meta_progress.journal_stage), view._status_label.text, str(view._recorded_modal_request)])
	view.session._save = save
	view.queue_free()
	await get_tree().process_frame
	controlled.free()
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "rejected J3 recording reloads safely")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	if not view._modal_active: view._confirm_sheet_j3_restore()
	press(view, 1)
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_SUCCESS_001"), "completed references and sentence order enter the authored J3 success; status=" + view._status_label.text)
	drain(view)
	check(view.session.snapshot().meta_progress.journal_stage == 3 and not view.session.known("basement_overlay_solved"), "J3 completion permanently records its page without completing D0")
	check(save.inspect_slot(SLOT).get("save_point_id") == "SAVE_J3_COMPLETE", "full source completion, not confirmation opening, reaches the final J3 checkpoint")
	check(game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_EP02_J3_UI_COMMIT_DONE" and entry.observation.content_version >= 2), "actual J3 completion shows its natural-language permanent-record notice")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)


func press(view: Control, index: int) -> bool:
	if not view._modal_active or index >= view._recorded_modal_request.get("actions", []).size():
		check(false, "requested menu option exists: " + str(index))
		return false
	view._recorded_choice_pressed(view._recorded_modal_request, index)
	return true

func travel(view: Control, destinations: Array) -> void:
	for destination in destinations:
		view._do("move", destination, false)
		check(view.session.snapshot().loop_state.location_id == destination, "physical travel: " + destination)


func verify_hints(view: Control, game: Node, save: Node, slot: String, stage: String, count: int) -> Control:
	view._show_clock_hint_menu(0)
	check(view._modal_active and hint_buttons(view).size() == 2, "hint entry offers first hint: " + stage)
	if not press_hint(view, 1): return view
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_%s_FB_HINT1" % stage), "actual hint disclosure matches source: " + stage)
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(slot).get("ok", false), "hint presentation reload: " + stage)
	view = MIRROR_CONTROLLER.new()
	view.configure_session(slot, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._dialogue_active, "unread hint resumes: " + stage)
	drain(view)
	for level in range(2, count + 1):
		if not press_hint(view, 1): return view
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_%s_FB_HINT%d" % [stage, level]), "actual next hint: %s:%d" % [stage, level])
		drain(view)
	check(view._modal_active and hint_buttons(view).size() == 1, "source hint count caps menu: " + stage)
	press_hint(view, 0)
	return view


func hint_buttons(view: Control) -> Array:
	return view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button)


func press_hint(view: Control, index: int) -> bool:
	var buttons := hint_buttons(view)
	check(view._modal_active and index < buttons.size(), "requested utility control exists")
	if not view._modal_active or index >= buttons.size(): return false
	buttons[index].pressed.emit()
	return true

func cleaner_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_cleaner_flow"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.meta_progress.journal_stage = 2
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.meta_progress.knowledge_entries.c0_mirror_seen = true
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_MIRROR_GALLERY"
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"SHEET_CLEANER_SEED").get("ok", false), "cleaner seed")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	view._do("c_hypothesis")
	drain(view)
	check(view._recorded_modal_request.get("actions", []).size() == 3, "C1 investigation route menu")
	press(view, 0)
	drain(view)
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M1_SERVANT_COMMON", "M1_TOOL_ROOM"])
	view._do("c_read_cleaning")
	drain(view)
	check(not view._modal_active, "cleaning record cannot pull Mara1 away from the mirror gallery")
	travel(view, ["M1_SERVANT_COMMON", "M1_CENTRAL_HALL", "M1_PARLOR", "M1_MIRROR_GALLERY"])
	check(view._hotspot_layer.has_node("SHEET_REACTION_MARA1_S2"), "Mara1 is visibly present at her authored location")
	view._open_sheet_reaction("MARA1_S2")
	drain(view)
	check(view._recorded_modal_request.get("actions", []).size() == 3, "Mara1 reaction is selectable")
	var bond: int = game.get_snapshot().meta_progress.servants.mara1.bond
	if press(view, 0): drain(view)
	check(game.get_snapshot().meta_progress.servants.mara1.bond == bond + 1, "Mara1 source relation effect")
	var before_short: Dictionary = game.get_snapshot().meta_progress.servants.duplicate(true)
	view._open_sheet_objects()
	if press_hint(view, 0):
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_REL_MARA1_C2_FIRST"), "nearby-actor menu opens first short Mara1 line")
		check(view._dialogue_lines[0].history_context.location_id == "M1_MIRROR_GALLERY", "relocated short reaction records actual mirror-gallery disclosure")
		check(SCRIPT.node("EP02_REL_MARA1_C2_FIRST").location_id == "M1_TOOL_ROOM", "source location metadata remains unchanged")
		drain(view)
	view._open_sheet_reaction("MARA1_S2")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_REL_MARA1_C2_REPEAT"), "completed relation button allows repeat flavor without replaying S2")
	drain(view)
	check(game.get_snapshot().meta_progress.servants == before_short, "flavor never duplicates relationship rewards")
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY"])
	view._open_sheet_reaction("MARA2_S2")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_REL_MARA2_PRE"), "Mara2 prediagnostic flavor is available at the normalized color-room entrance")
	drain(view)
	check(not view.session.known("c5_info_complete") and not view.session.known("mara2_archive_index_known"), "prediagnostic flavor cannot unlock diagnosis or archive index")
	travel(view, ["M1_NORTH_ARCHIVE_HALL", "M1_CENTRAL_HALL", "M1_PARLOR", "M1_MIRROR_GALLERY"])
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M1_SERVANT_COMMON", "M1_TOOL_ROOM"])
	view._do("c_read_cleaning")
	drain(view)
	check(not view._modal_active, "completed Mara1 reaction does not repeat")
	travel(view, ["M1_SERVANT_COMMON", "M1_KITCHEN"])
	view._do("c_read_chemicals")
	drain(view)
	check(not view._modal_active, "chemical labels do not force the optional Luca question")
	view._open_sheet_reaction("LUCA_C21")
	drain(view)
	check(view._recorded_modal_request.get("actions", []).size() == 1, "conditional Luca prompt requires input")
	if press(view, 0): drain(view)
	check(game.get_snapshot().meta_progress.servants.luca.bond == 1, "Luca source relation effect")
	var before_reason: Dictionary = view._mirror().mirror_local()
	check(not view.session.act("c_reason", {"ratio": true, "difference": false}).get("ok", false), "one relation cannot verify the integer combination")
	view._do("c_reason", {"ratio": true, "difference": true})
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_CARD_001"), "observed relations open authored deduction cards")
	drain(view)
	check(view.session.known("KN_C3_RATIO"), "read deduction records its named knowledge")
	check(view._mirror().mirror_local().cleaner_ready == before_reason.cleaner_ready and view._mirror().mirror_local().mixture == before_reason.mixture, "deduction cannot manufacture or alter physical ingredients")
	view._do("c_inspect", "OBJ_CHEM_CABINET")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_OBJ_CHEM_LOCKED_PRE"), "unprepared cabinet cannot claim physical bottles are already unlocked")
	drain(view)
	view._do("c_prepare")
	drain(view)
	view._do("c_inspect", "OBJ_CHEM_CABINET")
	check(view._dialogue_active and view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_OBJ_CHEM_WATER")), "prepared cabinet discloses the actual five-unit measuring container")
	check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_OBJ_CHEM_ACQUIRE")), "prior locked inspection cannot suppress real material-acquisition feedback")
	drain(view)
	view._do("c_inspect", "OBJ_CHEM_CABINET")
	check(not view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_OBJ_CHEM_ACQUIRE")), "repeat cabinet inspection cannot claim another material acquisition")
	drain(view)
	view = await verify_hints(view, game, save, SLOT, "C3", 5)
	const EVIDENCE_NOTES := preload("res://scripts/systems/ep02_evidence_notes.gd")
	check(not EVIDENCE_NOTES.available(game.get_snapshot()).has("EP02_SYS_NOTE_C3"), "deduced but unmanufactured cleaner cannot disclose formula-validation summary")
	check(view._notebook_tools().any(func(tool: Dictionary) -> bool: return tool.id == "SheetEvidenceNotes"), "notebook exposes eligible investigation summaries")
	var before_summary := view._mirror().mirror_local().duplicate(true)
	view._open_sheet_evidence_notes()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_SYS_NOTE_C0"), "notebook summary opens exact source text rather than legacy paraphrase")
	drain(view)
	check(view._mirror().mirror_local() == before_summary and not view.session.known("c3_formula_verified"), "reading source summaries cannot change mixture or validate a formula")
	for material in ["active", "stabilizer"]:
		var unchanged: Dictionary = game.get_snapshot()
		check(not view.session.act("c_pour", material).get("ok", false), "dry-bottle additive is blocked: " + material)
		check(game.get_snapshot() == unchanged, "blocked additive consumes neither state nor failure attempt: " + material)
		view._do("c_pour", material)
		var source_id := "EP02_C3_FB_ACTIVE_FIRST_BLOCK" if material == "active" else "EP02_C3_FB_STABILIZER_FIRST_BLOCK"
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text(source_id), "blocked additive discloses exact source text: " + material)
		drain(view)
	view._do("c_test")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_FB_EMPTY"), "empty mixture uses authored empty-bottle feedback rather than a fictional split test circle")
	check(not view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_TEST_BAD")), "an empty bottle cannot fabricate a nonneutral test circle caption")
	drain(view)
	check(view._hotspot_layer.has_node("POUR_WATER_FIVE"), "authored five-unit measure has a real control")
	view._hotspot_layer.get_node("POUR_WATER_FIVE").pressed.emit()
	check(view._mirror().mirror_local().mixture.water == 5, "five-unit measuring action adds exactly five real units")
	var before_overflow: Dictionary = game.get_snapshot()
	check(not view.session.act("c_pour_water_five").get("ok", false), "five-unit pour cannot overflow the eight-unit bottle")
	check(game.get_snapshot() == before_overflow, "rejected bulk pour is atomic and does not partially fill")
	check(view._status_label.text == SCRIPT.text("EP02_C3_UI_WATER_ADD_5"), "actual pouring displays authored current-count caption")
	check(game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_EP02_C3_UI_WATER_ADD_5"), "visible count caption has its own authored notebook observation")
	view._do("c_inspect", "OBJ_C3_MIX_STATION")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_WATER_001"), "mixture inspection reveals only the reached water milestone")
	drain(view)
	view._do("c_pour", "stabilizer", false)
	var before_block: Dictionary = game.get_snapshot()
	check(not view.session.act("c_pour", "active").get("ok", false), "undispersed stabilizer blocks active input")
	check(game.get_snapshot() == before_block, "early active input does not consume ingredients or failures")
	view._do("c_pour", "active")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_FB_ACTIVE_EARLY"), "early active input uses authored non-consumption message")
	drain(view)
	view._do("c_disperse")
	drain(view)
	for index in range(2): view._do("c_pour", "active", false)
	check(view._mirror().mirror_local().mixture.active == 2, "actual material ID fills active solution")
	view._do("c_mix")
	drain(view)
	view._do("c_test")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C3_TEST_001"), "only a valid actual mixture displays the closed-circle source result")
	check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.text == SCRIPT.text("EP02_CAP_TEST_OK")), "actual neutral test includes its closed-circle sensory caption")
	drain(view)
	check(view._mirror().mirror_local().cleaner_ready, "real cleaner produced")
	var alert_state: Dictionary = game.get_snapshot()
	alert_state.meta_progress.servants.edgar.alert = 4
	check(StateWriter.new(game).install_snapshot(alert_state, game.revision, &"SHEET_PATROL_SEED").get("ok", false), "high alert fixture")
	travel(view, ["M1_SERVANT_COMMON", "M1_CENTRAL_HALL", "M1_GREAT_CLOCK"])
	view._do("c_bell")
	drain(view)
	check(not view._modal_active, "clock signal does not open a mirror-only patrol menu")
	travel(view, ["M1_CENTRAL_HALL", "M1_PARLOR", "M1_MIRROR_GALLERY"])
	for step in range(100):
		if view._dialogue_active: break
		await get_tree().create_timer(0.01).timeout
	drain(view)
	check(not view._modal_active, "arrival returns to the authored overlay hub")
	view = await verify_hints(view, game, save, SLOT, "C4", 4)
	view._hotspot_layer.get_node("c_rotate_ccw").pressed.emit()
	check(view._mirror().mirror_local().rotation == 270 and view._status_label.text == SCRIPT.text("EP02_C4_UI_ROTATE_CCW"), "counterclockwise control performs the actual reverse rotation")
	view._hotspot_layer.get_node("C_ALPHA_LOW").pressed.emit()
	check(view._status_label.text == SCRIPT.text("EP02_C4_UI_ALPHA_LOW"), "low transparency control discloses its actual display change")
	view._open_trace_overlay()
	var overlay := view._modal_body.get_node_or_null("MirrorOverlayDiagram")
	check(overlay != null and overlay.overlay_transparency == "low" and overlay.layer_visibility().wave > overlay.layer_visibility().groove, "low transparency changes the actual runtime drawing layers")
	press(view, 0)
	view._hotspot_layer.get_node("C_ALPHA_HIGH").pressed.emit()
	check(view._mirror().mirror_local().overlay_transparency == "high" and view._status_label.text == SCRIPT.text("EP02_C4_UI_ALPHA_HIGH"), "high transparency has its own persisted display state")
	view._hotspot_layer.get_node("c_anchor_other").pressed.emit()
	check(not view._mirror().mirror_local().anchored and view._status_label.text == SCRIPT.text("EP02_C4_UI_ANCHOR_OTHER"), "other reference point remains an invalid actual anchor")
	view._do("c_rotate", null, false)
	view._do("c_rotate", null, false)
	view._do("c_anchor", null, false)
	view._open_patrol()
	drain(view)
	check(view._modal_active and view._recorded_modal_request.get("actions", []).size() == 3, "high-alert patrol inspection opens source choices")
	if press(view, 0): drain(view)
	check(view._mirror().mirror_local().intervention_handled, "source patrol selection performs real handling")
	for segment in ["entry", "short_branch", "long_branch", "clockwise_ring"]: view._do("c_segment", segment, false)
	view._do("c_dry")
	check(view._modal_active, "dry path keeps existing visual feedback")
	check(view._recorded_modal_request.get("history_context", {}).get("notebook_content", {}).get("content_version", 0) >= 2, "new dry modal uses versioned source text")
	check(String(view._recorded_modal_request.get("body", "")).contains(SCRIPT.text("EP02_C4_DRY_004")), "actual complete dry route discloses authored closed-ring reaction")
	if press(view, 0): drain(view)
	view._do("c_transparency", "low", false)
	check(view._mirror().mirror_local().dry_passed, "changing visual transparency cannot invalidate a verified physical path")
	view._do("c_verify_plan")
	drain(view)
	check(view._mirror().mirror_local().dry_passed, "real reversible test passed")
	view._confirm_wet_trace()
	drain(view)
	check(view._modal_active and view._recorded_modal_request.get("actions", []).size() == 3, "source irreversible confirmation choices")
	check(view._recorded_modal_request.get("focus", -1) == 1, "irreversible confirmation defaults to reviewing the plan rather than executing")
	if press(view, 0): drain(view)
	check(view._modal_active and view._modal_body.has_node("MirrorRouteFeedback"), "retry dry choice opens real feedback after its save")
	check(view._mirror().mirror_local().cleaner_ready, "dry review does not consume cleaner")
	if press(view, 0): drain(view)
	view._confirm_wet_trace()
	drain(view)
	if press(view, 1): drain(view)
	check(view._mirror().mirror_local().cleaner_ready and not view._mirror().mirror_local().surface_open, "plan review never commits wet action")
	view._confirm_wet_trace()
	drain(view)
	if press(view, 2): drain(view)
	check(view._mirror().mirror_local().surface_open, "source wet selection opens actual surface")
	for identity in ["EP02_CAP_OPEN", "EP02_CAP_COLD"]:
		check(game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_" + identity), "actual source wet-choice path discloses committed exposure caption: " + identity)
	check(not view._mirror().mirror_local().cleaner_ready, "wet selection consumes cleaner exactly once")
	check(view.session.stage() == "C5_INFO", "source scene chain reaches diagnostic scan stage")
	check("C4_SUCCESS" in game.get_snapshot().meta_progress.servants.edgar.residual_memory, "actual intervening Edgar receives source success witness memory")
	var premature := view.session.act("c_record")
	check(not premature.get("ok", false), "diagnostic recording requires both authored mandatory items")
	for diagnostic in ["BODY", "PERSONALITY"]:
		check(view._hotspot_layer.has_node("SCAN_" + diagnostic), "mandatory diagnostic has a real control")
		view._do("c_scan", diagnostic)
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C5_HOT_%s_FIRST" % diagnostic), "first diagnostic uses authored source")
		drain(view)
		if diagnostic == "BODY":
			var incomplete := view.session.act("c_record")
			check(not incomplete.get("ok", false) and incomplete.get("text") == SCRIPT.text("EP02_C5_CH_SCAN_PROGRESS_2"), "single mandatory scan reports actual one-of-two progress")
	view._do("c_scan", "BODY")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C5_HOT_BODY_REPEAT"), "repeat diagnostic uses authored source")
	drain(view)
	check(view._mirror().mirror_local().channels_scanned.is_empty(), "optional owner scans not required")
	check(not EVIDENCE_NOTES.available(game.get_snapshot()).has("EP02_SYS_NOTE_C5"), "two mandatory diagnostics cannot reveal uninspected external and wake conclusions")
	for diagnostic in ["EXTERNAL", "WAKE"]:
		view._do("c_scan", diagnostic)
		drain(view)
	check(EVIDENCE_NOTES.available(game.get_snapshot()).has("EP02_SYS_NOTE_C5"), "complete observed evidence unlocks the four-fact source summary")
	for suffix in ["FIRST", "REPEAT"]:
		view._do("c_scan", "SUBJECT")
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C5_CH_SUBJECT_" + suffix), "subject authority has its own first/repeat source")
		drain(view)
	check(view._mirror().mirror_local().channels_scanned.is_empty(), "subject authority never creates a sixth servant channel")
	view._do("c_record")
	drain(view)
	check(view.session.known("c5_info_complete"), "two mandatory diagnostics allow source recording")
	check(not view._modal_active, "C5 recording cannot teleport Mara2 or Iris into the mirror room")
	view = await verify_hints(view, game, save, SLOT, "J3", 3)
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY"])
	view._open_sheet_reaction("MARA2_S2")
	drain(view)
	check(view._modal_active and view._recorded_modal_request.get("actions", []).size() == 3, "Mara2 source reaction has three actual choices")
	if press(view, 0): drain(view)
	check(view.session.known("mara2_archive_index_known"), "Mara2 comparison preserves archive index knowledge")
	travel(view, ["M1_NORTH_ARCHIVE_HALL", "M1_CENTRAL_HALL"])
	check(view._hotspot_layer.has_node("GREENHOUSE_DOOR"), "C5 exposes the ordinary greenhouse doorway")
	travel(view, ["M1_GREENHOUSE"])
	check(not view.session.act("move", "H0_CLIMATE_CONTROL").get("ok", false), "opening ordinary greenhouse cannot bypass D5 climate-room lock")
	check(view._hotspot_layer.get_node("GREENHOUSE_INNER_LOCK").disabled, "ordinary greenhouse displays a locked functional doorway")
	view._open_sheet_reaction("IRIS_S2")
	drain(view)
	check(view._modal_active and view._recorded_modal_request.get("actions", []).size() == 4, "Iris source reaction has four seasons")
	if press(view, 2):
		check(view._dialogue_active, "Iris result awaits reading before season commit")
		view.queue_free()
		await get_tree().process_frame
		check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "load interrupted Iris result")
		view = MIRROR_CONTROLLER.new()
		view.configure_session(SLOT, "MORNING_ROUTE")
		add_child(view)
		await get_tree().process_frame
		drain(view)
	check(game.get_snapshot().meta_progress.get("iris_season_image") == "autumn", "Iris stores actual selected season rather than placeholder")
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "diagnostic and season receipt reload")
	check(game.get_snapshot().meta_progress.get("iris_season_image") == "autumn", "season survives disk reload")
	var library_state: Dictionary = game.get_snapshot()
	library_state.meta_progress.knowledge_entries.KN_B1_LIBRARY_WINDOW = true
	library_state.meta_progress.knowledge_entries.self_authored_mark = {"type": "sentence", "text": "어제의 표식", "day": 1}
	check(StateWriter.new(game).install_snapshot(library_state, game.revision, &"SHEET_LIBRARY_SEED").get("ok", false), "previous chapter library knowledge fixture")
	travel(view, ["M1_CENTRAL_HALL", "M1_LIBRARY_OUTER"])
	view._do("routine")
	drain(view)
	travel(view, ["M1_LIBRARY_INNER"])
	view._do("j3_overlay")
	drain(view)
	for point in ["BED", "GREEN", "CLOCK"]:
		view._do("j3_point", point)
		drain(view)
	view._do("j3_compare")
	drain(view)
	view._do("j3_flip_page", null, false)
	view._do("j3_compare")
	drain(view)
	for part in [0, 1, 2, 3]: view._do("j3_piece", part, false)
	view._do("j3_restore")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_SUCCESS_001"), "actual J3 restoration opens source success")
	check(save.inspect_slot(SLOT).get("save_point_id") != "SAVE_J3_COMPLETE", "restoration alone cannot skip unread final script checkpoint")
	check(preload("res://scripts/systems/notebook_presentation.gd").resume_family(game.get_snapshot()) == "black_mirror_controller", "unread J3 success retains its real scene family")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "unfinished J3 success reload")
	view = MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_SUCCESS_001"), "J3 source success resumes before the commit chain")
	drain(view)
	check(game.get_snapshot().meta_progress.journal_stage == 3, "actual J3 journal stage committed")
	check(save.inspect_slot(SLOT).get("save_point_id") == "SAVE_J3_COMPLETE", "last J3 source line writes the registered final checkpoint")
	check(not view._dialogue_active and not view._modal_active, "EP02 authored commit chain finishes without an orphan menu")
	view._do("c_inspect", "OBJ_JOURNAL")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_J3_DOC_001"), "physical journal inspection uses source document paragraphs")
	drain(view)
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)

func failure_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_failure_flow"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	var known: Dictionary = seed.meta_progress.knowledge_entries
	known.PROLOGUE_COMPLETE = true
	known.self_authored_mark = {"type": "sentence", "text": "어제의 표식", "day": 1}
	for key in ["c0_mirror_seen", "c1_cleaning_hypothesis", "c2_cleaning_record", "c21_chemical_record"]: known[key] = true
	known.j2_restored_day = 1
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.meta_progress.journal_stage = 2
	seed.meta_progress.servants.edgar.alert = 4
	seed.meta_progress.servants.mara1.bond = 4
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_MIRROR_GALLERY"
	seed.loop_state.event_local_states.BLACK_MIRROR = {"materials_ready": true, "cleaner_ready": true, "signal_ready": true}
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"SHEET_FAILURE_SEED").get("ok", false), "failure fixture prepared physical tools")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	view._confirm_wet_trace()
	drain(view)
	if press(view, 2):
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C4_FB_FAIL_TOOL"), "actual confiscation uses the source failure classification")
		check(not view._dialogue_lines[0].text.contains("tool_confiscated") and view._dialogue_lines[0].notebook_content.content_version >= 2, "player failure explanation hides the internal category in a new authored version")
		check(game.get_snapshot().meta_progress.failure_knowledge.C4.category == "tool_confiscated", "natural-language projection cannot change the real failure category")
		view.queue_free()
		await get_tree().process_frame
		check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "source failure preface reload")
		view = MIRROR_CONTROLLER.new()
		view.configure_session(SLOT, "MORNING_ROUTE")
		add_child(view)
		await get_tree().process_frame
		drain(view)
	check(view._mirror().mirror_local().locked, "actual unhandled patrol locks mirror for the day")
	check(game.get_snapshot().meta_progress.failure_knowledge.get("C4", {}).get("status") == "active", "physical failure information retained")
	check("C4_FAIL" in game.get_snapshot().meta_progress.servants.edgar.residual_memory, "direct witness source memory applied")
	check(not game.get_snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == "NB_EP02_C4_ACTUAL_002"), "real confiscation never archives an unobserved successful three-segment reaction")
	view._do("routine")
	drain(view)
	travel(view, ["M1_PARLOR", "M1_CENTRAL_HALL", "M2_BEDROOM"])
	view._confirm_sleep()
	drain(view)
	check(view._recorded_modal_request.get("actions", []).size() == 2, "failed-day source sleep choice")
	if press(view, 0): drain(view)
	check(game.get_snapshot().loop_state.day_index == 2, "continue investigation does not reset")
	view._confirm_sleep()
	drain(view)
	if press(view, 1):
		for step in range(500):
			if not view._reset_transition_pending and view._campaign_sleep_request.is_empty(): break
			await get_tree().create_timer(0.01).timeout
		drain(view)
	check(game.get_snapshot().loop_state.day_index == 3, "source sleep executes actual normal reset")
	check(game.get_snapshot().loop_state.location_id == "M2_BEDROOM" and not view._mirror().mirror_local().locked, "same bedroom and reset coating")
	check("C4_FAIL" in game.get_snapshot().meta_progress.servants.edgar.residual_memory, "witness memory survives physical reset")
	check(view._mirror().can_prepare_mirror_shortcut(), "retained failure enables shortcut")
	view._do("c_shortcut")
	drain(view)
	check(view.session.snapshot().loop_state.location_id == "M1_KITCHEN" and view._mirror().mirror_local().materials_ready, "source shortcut prepares actual kitchen route")
	check(not view._mirror().mirror_local().cleaner_ready, "shortcut never gives manufactured cleaner")
	view._do("c_inspect", "OBJ_FOLDED_NOTE")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_DOC_NOTE_001"), "optional source documents reachable after shortcut")
	drain(view)
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)

func mirror_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_mirror_flow"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	seed.meta_progress.notebook_persistence_confirmed = true
	seed.meta_progress.journal_stage = 2
	seed.meta_progress.knowledge_entries.j2_restored_day = 1
	seed.loop_state.day_index = 2
	seed.loop_state.location_id = "M1_MIRROR_GALLERY"
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"SHEET_MIRROR_SEED").get("ok", false), "mirror seed")
	var view := MIRROR_CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	view._do("c_observe")
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP02_C0_001"), "real mirror action opens sheet introduction")
	drain(view)
	check(view._modal_active and view._recorded_modal_request.get("actions", []).size() == 3, "C0 three authored choices")
	var bond: int = game.get_snapshot().meta_progress.servants.edgar.bond
	if press(view, 0):
		check(game.get_snapshot().meta_progress.servants.edgar.bond == bond, "choice press alone cannot award bond")
		drain(view)
		check(game.get_snapshot().meta_progress.servants.edgar.bond == bond + 1, "completed reason branch awards source bond")
		check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "C0 relation receipt reload")
		check(game.get_snapshot().meta_progress.servants.edgar.bond == bond + 1, "C0 bond survives load")
		check(view.session.finish_sheet_conversation(["EP02_C0_REASON_001"]).get("ok", false), "repeat receipt transaction")
		check(game.get_snapshot().meta_progress.servants.edgar.bond == bond + 1, "once effect cannot duplicate")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)

func hall_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_sheet_hall_flow"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var seed: Dictionary = game.get_snapshot()
	seed.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	seed.loop_state.day_index = 1
	seed.loop_state.location_id = "M2_BEDROOM"
	check(StateWriter.new(game).install_snapshot(seed, game.revision, &"SHEET_HALL_SEED").get("ok", false), "hall seed")
	var session := ChapterOneSession.new(game, save, SLOT)
	check(session.initialize().get("ok", false), "initialize hall session")
	check(session.act("mark", "sentence").get("ok", false), "create real mark to reach AS")
	check(session.act("move", "M1_CENTRAL_HALL").get("ok", false), "walk to central hall")
	var view := CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	drain(view)
	check(view._hotspot_layer.has_node("EP01_DAILY_HALL"), "real AS hall exposes hub hotspot")
	view._ep01_play("EP01_HUB_DAILY_HALL")
	check(view._recorded_modal_request.get("actions", []).size() == 2, "hall has talk and finish")
	if not press(view, 0):
		view.queue_free()
		return
	drain(view)
	check(view._recorded_modal_request.get("actions", []).size() == 3, "two unread stories and exit")
	if not press(view, 0):
		view.queue_free()
		return
	view._advance_dialogue()
	var interrupted: String = view._dialogue_lines[view._dialogue_index].text
	check(not game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_001_complete", false), "opening story cannot complete it")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "load interrupted story")
	view = CONTROLLER.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._dialogue_active and view._dialogue_lines[view._dialogue_index].text == interrupted, "same authored sentence resumes")
	drain(view)
	check(game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_001_complete", false), "story one completed through controller")
	check(view._recorded_modal_request.get("actions", []).size() == 2, "returns to parent hall")
	if press(view, 0):
		drain(view)
		check(view._recorded_modal_request.get("actions", []).size() == 2, "completed story is hidden")
		if press(view, 0):
			drain(view)
			check(game.get_snapshot().meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_002_complete", false), "story two completed through controller")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)
