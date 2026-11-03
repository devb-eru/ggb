extends Node

const SCRIPT := preload("res://scripts/systems/ep01_script.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const SESSION := preload("res://scripts/systems/chapter_one_session.gd")
const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const PROLOGUE := preload("res://scenes/prologue/prologue.tscn")
const PRESENTATION := preload("res://scripts/systems/notebook_presentation.gd")
var failures: Array[String] = []

class ResetHost extends Control:
	var _reset_owner_generation := 0
	var _reset_coordinator: ResetCoordinator
	func request_sleep_transition(slot: String) -> Dictionary:
		return _reset_coordinator.request_normal_reset(slot)


func _ready() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value: failures.append(message)


func _run() -> void:
	await get_tree().process_frame
	var game := get_tree().root.get_node("GameState")
	var save := get_tree().root.get_node("SaveManager")
	var original: Dictionary = game.get_snapshot()
	check(VIEW != null, "chapter controller and saved presentation callbacks compile")
	check(SCRIPT.source().get("nodes", []).size() == 557, "all live master rows imported")
	check(CONTENT.diagnostics().ok, "authored notebook catalog validates")
	check(CONTENT.definition("NB_CH1_NOTE_A1_SENTENCE", 3).locales["ko-KR"].body.begins_with("아빠는 어디에?\n"), "new marks use the revised authored sentence")
	check(not CONTENT.definition("NB_CH1_NOTE_A1_SENTENCE", 2).is_empty(), "previous mark observations retain their immutable definition")
	var state: Dictionary = original.duplicate(true)
	state.loop_state.location_id = "M2_BEDROOM"
	for row in SCRIPT.source().nodes:
		var variables := {"knowledge_count": 3} if row.ko_KR.contains("{knowledge_count}") else {}
		var shown := SCRIPT.line(row.node_id, state, "ko-KR", variables)
		check(not shown.is_empty() and shown.text == String(row.ko_KR).replace("{knowledge_count}", "3"), "verbatim Korean: " + row.node_id)
		check(not SCRIPT.line(row.node_id, state, "en-US", variables).is_empty(), "untranslated fallback: " + row.node_id)
	var intro := SCRIPT.segment("EP01_SLEEP_FIRST_001", state)
	check(intro.ok and intro.kind == "choice" and intro.lines.size() == 14, "expanded first sleep reaches its confirmation")
	check(SCRIPT.node("EP01_SLEEP_FIRST_011").speaker_id == "SERVANT_EDGAR", "corrected nightmare speaker")
	check(SCRIPT.node("EP01_AS_EDGAR_015").speaker_id == "SERVANT_EDGAR", "corrected Edgar response source")
	var morning := SCRIPT.segment("EP01_RESET_FIRST_008", state)
	check(morning.ok and morning.lines.size() == 5, "date answer follows only its four lines and merge")
	check(not morning.lines.any(func(line: Dictionary) -> bool: return line.text.contains("16분")), "morning answer cannot enter another answer")
	var edgar := SCRIPT.segment("EP01_AS_EDGAR_001", state, "ko-KR", ["EP01_AS_002"])
	check(edgar.ok and edgar.kind == "choice" and edgar.next == "EP01_CHOICE_AS_EDGAR_REPEAT", "new Edgar question is a real choice")
	var options := SCRIPT.edges(edgar.next)
	check(options.size() == 2, "both new choices are selectable")
	for option in options:
		var branch := SCRIPT.segment(SCRIPT.node(option.target_id).next_id, state, "ko-KR", ["EP01_AS_002"])
		check(branch.ok and branch.next == "EP01_HUB_DAILY_HALL", "source response returns to the new daily hall hub")
	state.loop_state.location_id = "M1_SERVANT_COMMON"
	for owner in ["edgar", "mara1"]:
		for tier in range(3):
			state.meta_progress.servants[owner]["alert" if owner == "edgar" else "bond"] = tier * 2
			state.loop_state.event_local_states = {}
			var first := SCRIPT.segment("EP01_ROUTER_B1_" + owner.to_upper(), state)
			check(first.ok, "conditional conversation: %s/%d" % [owner, tier])
			var flags := SCRIPT.completed_flags(first.ids)
			check(flags.size() == 1, "completion receipt belongs to one condition")
			state.loop_state.event_local_states.merge(flags)
			var repeated := SCRIPT.segment("EP01_ROUTER_B1_" + owner.to_upper(), state)
			check(repeated.ok and repeated.lines.size() == 1, "same condition selects only repeated response")
			check(repeated.ids[0] == "EP01_B1_" + owner.to_upper() + "_REPEAT_001", "authored repeat ID")
			state.loop_state.event_local_states = {}
			check(SCRIPT.segment("EP01_ROUTER_B1_" + owner.to_upper(), state).ids == first.ids, "next loop restores full first response")
	await _conversation_flow(game, save)
	await _physical_flow(game, save)
	await _first_sleep_flow(game, save)
	if failures.is_empty():
		print("EP01_SHEET_SMOKE PASS: 557 source rows, choices, condition variants, repeat/reset behavior")
	else:
		for message in failures: push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _drain(view: Control) -> void:
	for _step in range(150):
		if not view._dialogue_active: return
		view._advance_dialogue()
	check(false, "dialogue must finish within its authored block")


func _travel(view: Control, destination: String) -> void:
	var current: String = view.session.snapshot().loop_state.location_id
	if current == destination: return
	if current == "M1_LIBRARY_INNER":
		check(view.session.act("move", "M1_LIBRARY_OUTER").get("ok", false), "physical exit from inner archive")
		current = "M1_LIBRARY_OUTER"
	if current != "M1_CENTRAL_HALL":
		check(view.session.act("move", "M1_CENTRAL_HALL").get("ok", false), "physical route through hall")
	check(view.session.act("move", destination).get("ok", false), "physical travel: " + destination)
	view._render_room()


func _physical_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_ep01_physical"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var initial: Dictionary = game.get_snapshot()
	initial.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	initial.loop_state.day_index = 1
	check(StateWriter.new(game).install_snapshot(initial, game.revision, &"EP01_PHYSICAL").get("ok", false), "physical chapter fixture installs")
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	_drain(view)
	view._open_mark_choices()
	_drain(view)
	check(view._modal_active and view._recorded_modal_request.actions.size() == 3, "A1 exposes all three authored marks")
	if not view._modal_active: return
	view._recorded_choice_pressed(view._recorded_modal_request, 0)
	_drain(view)
	check(view.session.stage() == "AS" and not view._modal_active, "mark choice commits physical A1 and finishes its source response")
	check(game.get_value("meta_progress.knowledge_entries.self_authored_mark.text", "") == "아빠는 어디에?", "physical mark uses revised sentence")
	check(view.session.act("routine").get("ok", false), "prepare next morning")
	check(view.session.sleep().get("ok", false), "physical loop resets")
	view.queue_free()
	await get_tree().process_frame
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	_drain(view)
	view._do("confirm_mark")
	check(view._dialogue_lines.any(func(line: Dictionary) -> bool: return line.history_context.node_id == "EP01_A1_REACTION_002"), "yesterday's trace monologue plays at next-morning confirmation")
	_drain(view)
	check(view._modal_active and view.session.stage() == "B1", "A2 source reaches optional Edgar/continue choice after confirmation")
	if not view._modal_active: return
	# The second route continues to the existing schedule investigation surface.
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_drain(view)
	_travel(view, "M1_SERVANT_COMMON")
	for owner in ["edgar", "luca"]:
		view._do("read_schedule", owner)
		check(view._dialogue_active, "authored schedule opens: " + owner)
		_drain(view)
	view._do("schedule_window", "after_tea_before_bell")
	_drain(view)
	check(view.session.known("KN_B1_LIBRARY_WINDOW"), "authored B1 result preserves access knowledge")
	check(view.session.act("routine").get("ok", false), "physical approach window prepares")
	_travel(view, "M1_LIBRARY_OUTER")
	view._do("move", "M1_LIBRARY_INNER", false)
	_drain(view)
	for object in ["alcove", "index", "drawer"]:
		view._do("inspect_inner", object)
		if object == "drawer": check(view._dialogue_active and view._dialogue_lines[0].history_context.node_id == "EP01_B2_DRAWER_001", "noisy observation is shown before Edgar's warning")
		_drain(view)
	check(view._modal_active and view.session.local_state().edgar_state == "entering", "B2 warning waits for a real response")
	if not view._modal_active: return
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	_drain(view)
	check(view.session.local_state().edgar_state == "absent", "authored hiding conversation rejoins investigation")
	view._do("inspect_inner", "desk")
	_drain(view)
	for index in range(3):
		check(view.session.act("j1_piece", index).get("ok", false), "physical J1 piece")
		check(view.session.act("j1_flip", index).get("ok", false), "physical J1 face")
	view._do("j1_restore")
	_drain(view)
	check(int(game.get_value("meta_progress.journal_stage", 0)) == 1, "source J1 document follows physical restoration")
	for room in SESSION.CLOCK_ROOMS:
		_travel(view, room)
		view._do("rub_clock")
		_drain(view)
	for index in range(4):
		var board: Dictionary = view.session.local_state().board
		var other: int = board.pieces.find(CLOCK.SOLUTION[CLOCK.ROLES[index]])
		if other != index: view.session.act("board_swap", [index, other])
		for turn in range(4):
			if int(view.session.local_state().board.rotations[index]) != 0: view.session.act("board_rotate", index)
	if not view.session.local_state().board.library_back: view.session.act("board_flip")
	view._do("board_check")
	_drain(view)
	check(view.session.known("clock_network_layout_solved"), "source B3-A result preserves solved layout")
	for role in CLOCK.ROLES:
		if role != "excluded": view.session.act("role", [role, CLOCK.SOLUTION[role]])
	view._do("test_clock")
	check(view._dialogue_active and view._dialogue_lines[0].text == view._dialogue_ui_text("CH1_CLOCK_RESULT_EXCLUDED"), "weak test retains the exact existing diagnosis when the sheet has no corresponding branch")
	_drain(view)
	check(not view._modal_active and not view.session.local_state().clock_locked, "source weak test cannot execute the actual clock")
	_travel(view, "M1_GREAT_CLOCK")
	view._do("activate_clock", true)
	check(view._dialogue_active and view._dialogue_lines[0].history_context.node_id == "EP01_BF_COMMON_001", "excluded-slot failure uses the authored common failure, not a false reference diagnosis")
	_drain(view)
	check(view.session.stage() == "BF" and view.session.snapshot().meta_progress.failure_knowledge.B3_B.category == "excluded", "source failure preserves the exact puzzle diagnosis")
	_travel(view, "M2_BEDROOM")
	check(view.session.sleep().get("ok", false), "sleep restores the failed physical mechanism")
	view.queue_free()
	await get_tree().process_frame
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	_drain(view)
	view._do("shortcut")
	_drain(view)
	check(view.session.local_state().rubbed.size() == 4 and not view.session.local_state().clock_locked, "source shortcut rebuilds verified materials after a real reset")
	view.session.act("role", ["excluded", CLOCK.SOLUTION.excluded])
	view.session.act("phase", "+1")
	_travel(view, "M1_GREAT_CLOCK")
	view._do("activate_clock", true)
	_drain(view)
	check(view.session.stage() == "B4", "source success preserves explicit waveform recording step")
	view._do("record_wave")
	_drain(view)
	_travel(view, "M1_LIBRARY_OUTER")
	view._do("move", "M1_LIBRARY_INNER", false)
	_drain(view)
	for turn in range(3): view.session.act("wave_rotate")
	view._do("restore_j2")
	_drain(view)
	check(view.session.stage() == "J2_COMPLETE" and not view._modal_active, "source J2 document completes the chapter")
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)


func _drain_prologue(view: Control) -> void:
	for _step in range(180):
		await get_tree().process_frame
		if not view._dialogue_active: return
		# Headless frames can outrun the real-time reset fade that gates input.
		if view._fade.visible:
			await get_tree().create_timer(0.02).timeout
			continue
		view._advance_dialogue()
	check(false, "first-sleep authored block must finish; index=%d total=%d status=%s fade=%s pending=%s" % [view._dialogue_index, view._dialogue_lines.size(), view._status_label.text, view._fade.visible, str(view._prologue_async_request)])


func _reload_prologue(view: Control, host: Control, slot: String, game: Node, save: Node) -> Control:
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(slot).get("ok", false), "first-sleep cursor reloads from disk")
	var restored := PROLOGUE.instantiate()
	restored.configure_session(slot, "P1_ENTRY", false)
	host.add_child(restored)
	await get_tree().process_frame
	return restored


func _first_sleep_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_ep01_first_sleep"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var old_locale := TranslationServer.get_locale()
	var before_sleep: Dictionary = game.get_snapshot()
	before_sleep.loop_state.event_local_states.EP01_B1_EDGAR_001_seen = true
	before_sleep.loop_state.event_local_states.EP01_B1_MARA1_001_seen = true
	check(StateWriter.new(game).install_snapshot(before_sleep, game.revision, &"EP01_REPEAT_RESET").get("ok", false), "repeat receipts seed before a real reset")
	TranslationServer.set_locale("en-US")
	var host := ResetHost.new()
	host._reset_coordinator = ResetCoordinator.new(game, save)
	add_child(host)
	var view := PROLOGUE.instantiate()
	view.configure_session(SLOT, "P1_ENTRY", false)
	host.add_child(view)
	await get_tree().process_frame
	await _drain_prologue(view)
	view._progress.P1_complete = true
	view._progress.P4_complete = true
	view._progress.current_room = "M2_BEDROOM"
	view._mark_intro("P6")
	view._prologue_surfaces.begin({})
	view._enter_room("M2_BEDROOM")
	await _drain_prologue(view)
	view._on_sleep_bed()
	check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP01_SLEEP_FIRST_001"), "actual first sleep uses source dialogue with Korean fallback in English")
	await _drain_prologue(view)
	check(view._dialogue_choice_active and view._dialogue_choice_mode == "ep01_sleep", "first sleep waits for its source confirmation")
	view._on_dialogue_choice_pressed(1)
	check(not view._progress.P6_complete and int(game.get_value("loop_state.day_index", -1)) == 0, "declining sleep never commits or resets the day")
	view._on_sleep_bed()
	await _drain_prologue(view)
	view = await _reload_prologue(view, host, SLOT, game, save)
	check(view._dialogue_choice_active and view._dialogue_choice_mode == "ep01_sleep", "first sleep confirmation survives reload without choosing")
	view._on_dialogue_choice_pressed(0)
	check(view._progress.P6_complete and view._dialogue_active, "confirmed sleep commits progress and starts the new transition lines")
	await _drain_prologue(view)
	# Execute the real ResetCoordinator through the controller's owned fade task.
	for _step in range(600):
		if not view._reset_transition_pending: break
		await get_tree().create_timer(0.01).timeout
	check(int(game.get_value("loop_state.day_index", -1)) == 1, "first-sleep transition performs exactly one physical reset")
	check(not game.get_value("loop_state.event_local_states.EP01_B1_EDGAR_001_seen", false) and not game.get_value("loop_state.event_local_states.EP01_B1_MARA1_001_seen", false), "real reset clears both servants' per-loop repeat receipts")
	check(PRESENTATION.first_wake_pending(game.get_snapshot()), "physical reset retains unfinished first morning")
	await _drain_prologue(view)
	check(view._dialogue_choice_active and view._dialogue_choice_mode == "ep01_morning", "first morning opens all three authored answers")
	view = await _reload_prologue(view, host, SLOT, game, save)
	check(view._dialogue_choice_active and view._dialogue_choice_mode == "ep01_morning", "first-morning choice resumes after reload")
	var handed_off := []
	view.campaign_requested.connect(func(slot: String) -> void: handed_off.append(slot))
	view._on_dialogue_choice_pressed(1)
	check(view._dialogue_active and view._dialogue_lines[0].history_context.node_id == "EP01_RESET_FIRST_008", "date choice follows its own source answer")
	await _drain_prologue(view)
	check(handed_off == [SLOT], "first-morning answer hands off once")
	check(not PRESENTATION.first_wake_pending(game.get_snapshot()), "expanded first morning commits its handoff receipt")
	check(int(game.get_value("loop_state.day_index", -1)) == 1, "morning choice never repeats the physical reset")
	host.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)
	TranslationServer.set_locale(old_locale)


func _conversation_flow(game: Node, save: Node) -> void:
	const SLOT := "__test_ep01_sheet"
	save.delete_test_slot(SLOT)
	game.reset_for_test()
	var state: Dictionary = game.get_snapshot()
	state.meta_progress.knowledge_entries.PROLOGUE_COMPLETE = true
	state.meta_progress.notebook_persistence_confirmed = true
	state.loop_state.location_id = "M1_SERVANT_COMMON"
	var installed := StateWriter.new(game).install_snapshot(state, game.revision, &"EP01_SHEET_SEED")
	check(installed.get("ok", false), "controller fixture installs")
	var view := VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	_drain(view)
	for owner in ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]:
		check(not view._hotspot_layer.get_node("EP01_TALK_" + owner).text.begins_with("UI_SPEAKER_"), "NPC name resolves through existing localization: " + owner)
	view._ep01_talk("EDGAR")
	check(view._dialogue_active, "real NPC hotspot opens authored dialogue")
	check(view._dialogue_lines[0].text == SCRIPT.text("EP01_B1_EDGAR_CH01"), "NPC opening question comes from the live sheet")
	view._advance_dialogue()
	check(not game.get_value("loop_state.event_local_states.EP01_B1_EDGAR_001_seen", false), "unfinished conversation never consumes its first response")
	var interrupted_text: String = view._dialogue_lines[view._dialogue_index].text
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "partial conversation reloads from disk")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._dialogue_active and view._dialogue_lines[view._dialogue_index].text == interrupted_text, "reload resumes the current authored line")
	_drain(view)
	check(game.get_value("loop_state.event_local_states.EP01_B1_EDGAR_001_seen", false) == true, "completion flag commits only after the last line")
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "conversation and receipts survive disk reload")
	view.queue_free()
	await get_tree().process_frame
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(not view._dialogue_active, "completed conversation is not replayed on reload")
	view._ep01_talk("EDGAR")
	check(view._dialogue_lines.size() == 2 and view._dialogue_lines[1].text == SCRIPT.text("EP01_B1_EDGAR_REPEAT_001"), "repeat click uses authored exhausted response after the question")
	_drain(view)
	view._ep01_play("EP01_AS_EDGAR_001", {}, ["EP01_AS_002"])
	_drain(view)
	check(view._modal_active and view._recorded_modal_request.actions.size() == 2, "actual additional choice presents both buttons")
	view.queue_free()
	await get_tree().process_frame
	check(LoadCoordinator.new(game, save).load_and_install(SLOT).get("ok", false), "additional choice persists to disk")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	check(view._modal_active and view._recorded_modal_request.actions.size() == 2, "reload restores the same additional choice")
	if view._modal_active:
		view._recorded_choice_pressed(view._recorded_modal_request, 1)
		check(view._dialogue_active and view._dialogue_lines[0].text == SCRIPT.text("EP01_AS_EDGAR_020"), "second choice follows its own updated answer")
		_drain(view)
	view.queue_free()
	await get_tree().process_frame
	save.delete_test_slot(SLOT)
