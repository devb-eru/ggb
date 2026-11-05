extends Node

const VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const CURSOR := preload("res://scripts/systems/notebook_presentation.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const SLOT := "__test_ep02_modal_boundaries"
var errors := PackedStringArray()
var checks := 0
var cases := 0
var serial := 0
var case_locale := "ko-KR"
var view: BlackMirrorController
var controlled: PhaseSave
var traces: Array = []

class PhaseSave extends Node:
	var phase := ""
	var reject := false
	var lose_ack := false
	var rejected := 0
	var lost := 0
	var lost_transactions: Array = []
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		var target: bool = transaction.begins_with("HISTORY_") and CURSOR.read(state).get("phase") == phase
		if phase == "effect": target = transaction.begins_with("CH1_") and state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0046", false)
		if target and reject:
			rejected += 1
			return {"ok": false, "error_ids": ["TEST_EP02_PHASE_REJECT"]}
		var result := SaveManager.save_snapshot(slot, point, state, revision, transaction)
		if target and lose_ack and result.get("ok", false):
			lost += 1
			lost_transactions.append(transaction)
			return {"ok": false, "error_ids": ["TEST_EP02_PHASE_ACK"]}
		return result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
		return SaveManager.confirm_snapshot_commit(slot, transaction)


func _ready() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		case_locale = locale
		TranslationServer.set_locale(locale)
		for ack in [false, true]: await _options("C4", false, ack)
		for index in range(3):
			for switch_answer in [false, true]: await _c4_answer(index, switch_answer)
		for escape in [false, true]: await _c4_close(escape)
		await _c4_restore()
		for replay in [false, true]:
			for ack in [false, true]: await _options("J3", replay, ack)
			for index in range(2): await _j3_close(replay, index)
		for phase in ["reading", "finish_pending"]: await _j3_body(phase)
		await _j3_completion()
	await _cleanup()
	SaveManager.delete_test_slot(SLOT)
	_check(cases == 44, "independent boundary denominator: 44")
	var trace := FileAccess.open("user://__test_ep02_modal_boundary_trace.json", FileAccess.WRITE)
	_check(trace != null, "write isolated boundary trace")
	if trace != null:
		trace.store_string(JSON.stringify({"pid": OS.get_process_id(), "cases": traces}, "", true))
		trace.close()
	print("EP02_MODAL_BOUNDARY_RESULT: ", {"ok": errors.is_empty(), "cases": cases, "checks": checks, "errors": errors})
	get_tree().quit(0 if errors.is_empty() else 1)


func _fresh(stage: String, replay := false) -> void:
	await _cleanup()
	TranslationServer.set_locale(case_locale)
	SaveManager.delete_test_slot(SLOT)
	var fixture := CHECKPOINTS.new().snapshot_for(stage)
	_check(fixture.get("ok", false), "valid fixture " + stage)
	if not fixture.get("ok", false): return
	var state: Dictionary = fixture.snapshot
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase("notebook_knowledge")
	state.meta_progress.knowledge_entries.erase("chapter_notebook")
	state.loop_state.event_local_states.erase(CURSOR.KEY)
	if stage == "C4":
		state.loop_state.location_id = "M1_MIRROR_GALLERY"
		state.meta_progress.servants.edgar.alert = 0
		state.loop_state.event_local_states.BLACK_MIRROR.merge({"rotation": 90, "flipped": false, "anchored": true, "path": RULES.PATH.duplicate(), "cleaner_ready": true, "signal_ready": true, "intervention_handled": false, "dry_passed": false}, true)
	else:
		state.loop_state.location_id = "M1_LIBRARY_INNER"
		state.meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
		state.loop_state.event_local_states.BLACK_MIRROR.merge({"j3_reference_points": ["BED", "GREEN", "CLOCK"], "j3_overlay_seen": true}, true)
	GameState.reset_for_test()
	serial += 1
	_check(StateWriter.new(GameState).install_snapshot(state, GameState.revision, StringName("EP02_MODAL_FIXTURE_%d" % serial)).ok, "install boundary fixture")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	view._dismiss_dialogue_for_test()
	_check(not view._async_history_enabled(), "modal phase suite uses the real synchronous writer")
	controlled = PhaseSave.new()
	add_child(controlled)
	view.session._save = controlled
	if replay:
		view._open_j3_memory()
		if _request():
			view._recorded_choice_pressed(view._recorded_modal_request, 1)
			_drain()
		_check(view._j3_memory_seen(), "replay fixture actually read memory")
		_check(_receipt(), "actual memory completion receipt")


func _cleanup() -> void:
	if is_instance_valid(view):
		view.session._save = SaveManager
		view.queue_free()
		await get_tree().process_frame
	view = null
	if is_instance_valid(controlled): controlled.queue_free()
	controlled = null
	await get_tree().process_frame


func _open(stage: String) -> void:
	if stage == "C4":
		view._confirm_wet_trace()
		_drain()
	else: view._open_j3_memory()


func _options(stage: String, replay: bool, ack: bool) -> void:
	var old := errors.size()
	await _fresh(stage, replay)
	var physical: Dictionary = view._mirror().mirror_local().duplicate(true)
	controlled.phase = "choosing"
	controlled.reject = not ack
	controlled.lose_ack = ack
	_open(stage)
	if not _request():
		_case("options/%s/%s/%s" % [stage, replay, ack], old)
		return
	var request: Dictionary = view._recorded_modal_request
	var id: String = request.history_context.notebook_content.content_id
	var token: String = request.history_context.presentation_token
	if not ack:
		_check(controlled.rejected == 1 and not request.recorded and _count(id) == 0, "rejected options are not observations")
		var before := GameState.get_snapshot()
		var disk := _disk()
		view._recorded_choice_pressed(request, 1)
		_check(_same(before, GameState.get_snapshot()) and _same(disk, _disk()), "undurable options cannot dispatch or change disk")
		controlled.reject = false
		controlled.lose_ack = true
		_check(view._record_modal_options(request), "explicit options retry reconciles lost acknowledgement")
	_check(controlled.lost == 1 and request.recorded and _count(id) == 1, "options have exactly one durable observation")
	_check(request.history_context.presentation_token == token, "options retry keeps original token")
	_check(_same(physical, view._mirror().mirror_local()), "options never apply physical action")
	_check(_same(GameState.get_snapshot(), _disk()), "options are durable on the real slot")
	_check(view._record_modal_options(request) and _count(id) == 1, "options rerender is idempotent")
	_case("options/%s/%s/%s" % [stage, replay, ack], old)


func _c4_answer(index: int, switch_answer: bool) -> void:
	var old := errors.size()
	await _fresh("C4")
	_open("C4")
	if not _request():
		_case("answer/%s/%s" % [index, switch_answer], old)
		return
	var request: Dictionary = view._recorded_modal_request
	var before := GameState.get_snapshot()
	var disk := _disk()
	var rejected_id: String = request.row.choices[index].content_id
	controlled.phase = "selection_pending"
	controlled.reject = true
	view._recorded_choice_pressed(request, index)
	_check(controlled.rejected == 1 and _same(before, GameState.get_snapshot()) and _same(disk, _disk()), "rejected answer cannot apply world action or add observation")
	_check(view._modal_active and _count(rejected_id) == 0, "failed answer stays an unobserved choice")
	var target := (index + 1) % 3 if switch_answer else index
	controlled.reject = false
	controlled.lose_ack = true
	view._recorded_choice_pressed(request, target)
	var accepted_id: String = request.row.choices[target].content_id
	_check(controlled.lost == 1 and _count(accepted_id) == 1, "explicit accepted answer saves once after acknowledgement loss")
	_check(_count(rejected_id) == (0 if switch_answer else 1), "switching answers does not disclose the rejected answer")
	var local: Dictionary = view._mirror().mirror_local()
	_check(local.cleaner_ready == (target != 2), "only accepted wet answer consumes cleaner")
	_check(local.surface_open == (target == 2), "only accepted wet answer opens physical surface")
	_check(local.dry_passed == (target == 0), "only accepted dry answer runs route diagnosis")
	var after := GameState.get_snapshot()
	view._recorded_choice_pressed(request, index)
	_check(_same(after, GameState.get_snapshot()), "completed answer callback cannot dispatch again")
	_case("answer/%s/%s" % [index, switch_answer], old)


func _c4_close(escape: bool) -> void:
	var old := errors.size()
	await _fresh("C4")
	_open("C4")
	if not _request():
		_case("close/c4/%s" % escape, old)
		return
	var request: Dictionary = view._recorded_modal_request
	var physical: Dictionary = view._mirror().mirror_local().duplicate(true)
	controlled.phase = "completed"
	controlled.reject = true
	if escape: view._cancel_prologue_modal()
	else: view._recorded_choice_pressed(request, 1)
	_check(controlled.rejected == 1 and view._modal_active, "failed close keeps actual choice open")
	_check(_same(physical, view._mirror().mirror_local()), "failed close cannot run dry or wet action")
	var pending := GameState.get_snapshot()
	_check(_same(pending, _disk()), "failed close preserves the last committed cursor")
	var descriptor: Dictionary = CURSOR.read(pending).lines[0].notebook_content
	_check(descriptor.content_version == 2, "current C4 options remain version 2")
	var token: String = request.get("selection_token", "")
	var answer_id: String = request.row.choices[1].content_id
	_check(_count(answer_id) == (0 if escape else 1), "Escape is not the review answer")
	await _reload(true)
	if _request():
		request = view._recorded_modal_request
		_check(_same(pending, GameState.get_snapshot()), "localized restore never rediscloses or executes")
		if not escape: _check(request.selection_recorded and request.selection_token == token, "review pending answer keeps original token")
		controlled.phase = "completed"
		controlled.lose_ack = true
		if escape: view._cancel_prologue_modal()
		else: view._recorded_choice_pressed(request, 1)
		_check(controlled.lost >= 1 and not view._modal_active, "explicit close retry reconciles durable acknowledgement: " + str({"lost": controlled.lost, "modal": view._modal_active, "phase": CURSOR.read(GameState.get_snapshot()).get("phase")}))
		_check(_unique(controlled.lost_transactions).size() == controlled.lost, "close and subsequent visible status use distinct committed transactions")
		_check(_same(physical, view._mirror().mirror_local()), "closing preserves physical puzzle")
		_check(_count(answer_id) == (0 if escape else 1), "close retry adds no answer duplicate")
	_case("close/c4/%s" % escape, old)


func _c4_restore() -> void:
	var old := errors.size()
	await _fresh("C4")
	_open("C4")
	if not _request():
		_case("restore/c4/choosing", old)
		return
	var before := GameState.get_snapshot()
	await _reload(true)
	if _request():
		var request: Dictionary = view._recorded_modal_request
		var row: Dictionary = request.row.locales[_locale()]
		_check(_same(before, GameState.get_snapshot()), "choosing reload is read only")
		_check(request.focus == 1 and request.actions[1].label == row.option_1, "localized restore keeps safe review focus")
		_check(not request.selection_recorded and CURSOR.read(before).phase == "choosing", "choosing restore never invents an answer")
	_case("restore/c4/choosing", old)


func _j3_close(replay: bool, index: int) -> void:
	var old := errors.size()
	await _fresh("J3", replay)
	_open("J3")
	if not _request():
		_case("close/j3/%s/%s" % [replay, index], old)
		return
	var request: Dictionary = view._recorded_modal_request
	_check(request.row.choices.all(func(choice: Dictionary) -> bool: return choice.kind == "ui"), "J3 options are UI-only")
	var before := GameState.get_snapshot()
	controlled.phase = "completed"
	controlled.reject = true
	view._recorded_choice_pressed(request, index)
	_check(controlled.rejected == 1 and view._modal_active and not view._dialogue_active, "undurable J3 close cannot start reading or finish skipping")
	_check(_same(before, GameState.get_snapshot()) and _same(before, _disk()), "failed UI-only close adds no selected-answer cursor or observation")
	_check(view._j3_memory_seen() == replay, "failed close cannot acquire a new memory")
	await _reload(true)
	if _request():
		request = view._recorded_modal_request
		_check(not request.selection_recorded and request.get("selection_token", "").is_empty(), "reloaded UI-only chooser invents no answer token")
		controlled.phase = "completed"
		controlled.lose_ack = true
		view._recorded_choice_pressed(request, index)
		_check(controlled.lost >= 1, "UI-only close retry reconciles acknowledgement: " + str(controlled.lost))
		_check(_unique(controlled.lost_transactions).size() == controlled.lost, "UI-only close and status have distinct durable transactions")
		if index == 0:
			_check(not view._dialogue_active and view._j3_memory_seen() == replay, "skip does not start unseen memory")
		else:
			_check(view._dialogue_active, "explicit successful close starts actual memory")
			_drain()
			_check(view._j3_memory_seen() and _receipt(), "actual completed read or replay preserves one effect receipt")
		var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries
		_check(entries.all(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("producer_id") != "NP05" or entry.observation.get("entry_kind") != "choice_confirmed"), "UI-only memory never becomes a selected answer observation")
	_case("close/j3/%s/%s" % [replay, index], old)


func _j3_body(phase: String) -> void:
	var old := errors.size()
	await _fresh("J3")
	_open("J3")
	if not _request():
		_case("memory/" + phase, old)
		return
	controlled.phase = phase
	controlled.reject = true
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	if phase == "finish_pending":
		for index in range(16):
			if not view._dialogue_active or view._dialogue_index == view._dialogue_lines.size() - 1: break
			view._advance_dialogue()
		_check(view._dialogue_active and view._j3_memory_seen() and not _receipt(), "terminal observation may precede completion receipt")
	else:
		_check(not view._j3_memory_seen() and not _receipt(), "failed first memory observation reveals no durable memory")
	var before := GameState.get_snapshot()
	var disk := _disk()
	var token: String = view._dialogue_lines[view._dialogue_index].presentation_token if view._dialogue_active else ""
	view._advance_dialogue()
	_check(controlled.rejected > 0 and view._dialogue_active, "targeted memory write actually rejected")
	_check(_same(before, GameState.get_snapshot()) and _same(disk, _disk()), "failed observation or completion cursor preserves exact state and disk")
	_check(view._dialogue_lines[view._dialogue_index].presentation_token == token, "failed memory stays on the same presentation token")
	controlled.reject = false
	controlled.lose_ack = true
	_drain()
	_check(controlled.lost > 0 and view._j3_memory_seen() and _receipt(), "memory retry completes once after acknowledgement recovery")
	_check(_token_count(token) == 1, "retried memory line has one observation")
	_check(_same(GameState.get_snapshot(), _disk()), "memory completion is durable")
	_case("memory/" + phase, old)


func _reload(change_locale: bool) -> void:
	if is_instance_valid(view):
		view.session._save = SaveManager
		view.queue_free()
		await get_tree().process_frame
	if is_instance_valid(controlled): controlled.queue_free()
	await get_tree().process_frame
	if change_locale: TranslationServer.set_locale("en-US" if _locale() == "ko-KR" else "ko-KR")
	_check(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "load actual durable slot")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	add_child(view)
	await get_tree().process_frame
	controlled = PhaseSave.new()
	add_child(controlled)
	view.session._save = controlled


func _j3_completion() -> void:
	var old := errors.size()
	await _fresh("J3")
	_open("J3")
	if not _request():
		_case("memory/completion", old)
		return
	view._recorded_choice_pressed(view._recorded_modal_request, 1)
	for index in range(16):
		if not view._dialogue_active or view._dialogue_index == view._dialogue_lines.size() - 1: break
		view._advance_dialogue()
	_check(view._dialogue_active and view._j3_memory_seen() and not _receipt(), "memory completion starts after actual terminal observation")
	controlled.phase = "effect"
	controlled.reject = true
	view._advance_dialogue()
	_check(controlled.rejected == 1 and view._modal_active and CURSOR.read(GameState.get_snapshot()).get("phase") == "finish_pending", "failed EFF46 completion keeps durable finish_pending and actual retry modal")
	_check(not _receipt() and view._j3_memory_seen(), "failed completion preserves observed memory without publishing effect")
	_check(_same(GameState.get_snapshot(), _disk()), "failed completion rolls back to actual durable state")
	var buttons: Array = view._modal_body.get_children().filter(func(child: Node) -> bool: return child is Button and child.is_visible_in_tree() and not child.disabled)
	_check(buttons.size() == 1, "actual completion retry has one button")
	if buttons.size() == 1:
		var history: Dictionary = GameState.get_snapshot().meta_progress.dialogue_history.duplicate(true)
		controlled.reject = false
		controlled.lose_ack = true
		buttons[0].pressed.emit()
		_check(controlled.lost == 1 and _receipt() and not view._modal_active, "actual completion retry commits EFF46 once despite acknowledgement loss")
		_check(_same(history, GameState.get_snapshot().meta_progress.dialogue_history), "completion retry adds no duplicate observed sentence")
		_check(_same(GameState.get_snapshot(), _disk()), "completed memory receipt is on disk")
	_case("memory/completion", old)


func _request() -> bool:
	var ok := view._modal_active and not view._recorded_modal_request.is_empty()
	_check(ok, "actual recorded choice exists")
	return ok


func _drain() -> void:
	for index in range(64):
		if not view._dialogue_active: return
		var before := CURSOR.read(GameState.get_snapshot())
		view._advance_dialogue()
		if view._dialogue_active and _same(before, CURSOR.read(GameState.get_snapshot())):
			_check(false, "unexpected blocked dialogue outside targeted rejection")
			return
	_check(false, "dialogue exceeded bounded traversal")


func _disk() -> Dictionary:
	var loaded := SaveManager.load_slot(SLOT)
	_check(loaded.get("ok", false), "real slot remains readable")
	return loaded.get("snapshot", {})


func _count(id: String) -> int:
	return GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("content_id") == id).size()


func _token_count(token: String) -> int:
	return GameState.get_snapshot().meta_progress.dialogue_history.entries.filter(func(entry: Dictionary) -> bool: return entry.get("observation", {}).get("presentation_token") == token).size()


func _receipt() -> bool:
	return GameState.get_snapshot().meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0046", false)


func _unique(values: Array) -> Array:
	var seen := {}
	for value in values: seen[value] = true
	return seen.keys()


func _locale() -> String:
	return "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"


func _same(left: Variant, right: Variant) -> bool:
	return StateSnapshotValidator.same_persisted_value(left, right)


func _case(label: String, old: int) -> void:
	cases += 1
	var disk := _disk()
	traces.append({"case_id": label, "starting_locale": case_locale, "ending_locale": _locale(), "passed": old == errors.size(), "errors": errors.slice(old), "snapshot": GameState.get_snapshot(), "disk": disk, "ack_loss_transactions": controlled.lost_transactions.duplicate(), "rejected_writes": controlled.rejected})
	print("EP02_MODAL_BOUNDARY_CASE: ", case_locale, ">", _locale(), " ", label, " ", "PASS" if old == errors.size() else errors.slice(old))


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)
