extends RefCounted


static func _text(key: String, locale: String) -> String:
	return TEXT.localized_text[locale][key]

const NOTES := preload("res://scripts/systems/notebook_chapter_surfaces.gd")
const CONTENT := NOTES.CONTENT
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const VIEW := preload("res://scripts/chapters/chapter_one_controller.gd")
const TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
const SLOT := "__test_notebook_chapter_surfaces"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var fixtures := {}
var view: ChapterOneController
var serial := 0
var matrix_cases := 0
var inherited_paths: Array = []

class ControlledSave extends Node:
	var reject := true
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["ERR_TEST_CHAPTER_SURFACE"]}
		var result := SaveManager.save_snapshot(slot,point,state,revision,transaction)
		return {"ok":false,"error_ids":["ERR_TEST_CHAPTER_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary: return SaveManager.confirm_snapshot_commit(slot,transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor","full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	for language in ["ko-KR","en-US"]:
		TranslationServer.set_locale(language)
		print("CHAPTER_SURFACE_PHASE: ",language)
		_matrix(language)
		_install(_fixture("B1","M1_SERVANT_COMMON"))
		view = VIEW.new()
		view.configure_session(SLOT,"B1")
		tree.current_scene.add_child(view)
		view._dismiss_dialogue_for_test()
		_present()
		_labels()
		_journal()
		_clocks()
		_failure_and_scope()
		view.queue_free()
		view = null
		await tree.process_frame
		await _later_controllers(tree)
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(covered.has(id+":"+language),"unvisited actual ID "+id+":"+language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(segments.has(id+":"+segment+":"+language),"unvisited actual segment "+id+":"+segment+":"+language)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor",flavor)
	print("CHAPTER_SURFACE_COVERAGE: actual IDs/locales=",covered.size()," segments/locales=",segments.size()," matrix cases=",matrix_cases)
	print("NOTEBOOK_INHERITED_ACTION_AUDIT: " + JSON.stringify({"paths": inherited_paths, "errors": errors}))
	return {"ok":errors.is_empty(),"errors":errors,"not_covered":["prologue_surfaces","unified_notebook_UI","OS_input","restart_cursor","B2_exact_modal_pause"]}


func _labels() -> void:
	for read in [false,true]:
		var state := _fixture("B1","M1_SERVANT_COMMON")
		for owner in ["edgar","luca","mara1","mara2"]: state.meta_progress.knowledge_entries["schedule_"+owner] = read
		_install(state)
		_present()
		_expect(not _has_id("NB_CH1_B1_EDGAR"),"document title does not expose body")
	_install(_fixture("B2","M1_LIBRARY_OUTER"))
	_present()
	for known in [false,true]:
		var state := _fixture("B2","M1_NORTH_ARCHIVE_HALL")
		state.meta_progress.knowledge_entries["north_library_shortcut"] = known
		_install(state)
		_present()
		if not known:
			_press("NORTH_LINK")
			_expect(GameState.get_value("loop_state.location_id","") == "M1_NORTH_ARCHIVE_HALL","link label cannot bypass B2 gate")
			view._dismiss_dialogue_for_test()
	for pressure in ["entering","hidden"]:
		var state := _fixture("J1","M1_LIBRARY_INNER")
		state.loop_state.event_local_states.CHAPTER_ONE.edgar_state = pressure
		_install(state)
		_present()
		_expect(not _has_id(NOTES.PREFIX+"INNER_DESK"),"occluded room labels not recorded")
		view._edgar_timer.stop()


func _journal() -> void:
	var state := _fixture("J1","M1_LIBRARY_INNER")
	state.loop_state.event_local_states.CHAPTER_ONE.inspected = []
	_install(state)
	_present()
	_expect(not _has_id(NOTES.PREFIX+"J1_FRAGMENT_0_BACK"),"desk label does not disclose fragments")
	for front in [false,true]:
		for length in range(4):
			state = _fixture("J1","M1_LIBRARY_INNER")
			var local: Dictionary = state.loop_state.event_local_states.CHAPTER_ONE
			local.inspected = ["desk"]
			local.edgar_state = "absent"
			local.j1_front = [front,front,front]
			local.j1_order = [2,0,1].slice(0,length)
			_install(state)
			_present()
			_expect(GameState.get_value("meta_progress.journal_stage",0) == 0,"fragment view does not restore journal")
			_expect(not _has_id(NOTES.PREFIX+"J1_FRAGMENT_0_"+("BACK" if front else "FRONT")),"unshown face excluded")
	state = _fixture("B5","M1_LIBRARY_INNER")
	state.loop_state.event_local_states.CHAPTER_ONE.edgar_state = "absent"
	_install(state)
	_present()


func _clocks() -> void:
	_install(_fixture("BF","M1_GREAT_CLOCK"))
	_present()
	var state := _fixture("B3_A","M1_GREAT_CLOCK")
	state.loop_state.event_local_states.CHAPTER_ONE.rubbed = []
	_install(state)
	_present()
	_expect(not _has_id(NOTES.PREFIX+"CLOCK_CARD_LIBRARY_BACK"),"collect notice does not expose card")
	state = _fixture("B3_A","M1_GREAT_CLOCK")
	state.loop_state.event_local_states.CHAPTER_ONE.rubbed = CLOCK.CLOCKS.duplicate()
	state.loop_state.event_local_states.CHAPTER_ONE.board.library_back = false
	_install(state)
	_present()
	_expect(not _has_id(NOTES.PREFIX+"CLOCK_CARD_LIBRARY_BACK"),"unflipped library card hidden")
	_press("B3_FLIP")
	_present()
	_expect(_has_id(NOTES.PREFIX+"CLOCK_CARD_LIBRARY_BACK"),"flipped library card observed")
	for phase in CLOCK.PHASES:
		state = _fixture("B3_B","M1_GREAT_CLOCK")
		var local: Dictionary = state.loop_state.event_local_states.CHAPTER_ONE
		local.roles = {}
		local.phase = phase
		_install(state)
		_present()
		for role in CLOCK.ROLES:
			var id: String = "CLOCK_MENU_"+String(role).to_upper()
			_expect(not _has_id(NOTES.PREFIX+id),"unopened dropdown excluded")
			var button := view._hotspot_layer.get_node("ROLE_"+role) as OptionButton
			button.show_popup()
			_present()
			_expect(_has_id(NOTES.PREFIX+id),"opened dropdown preserved")
			button.get_popup().hide()
		_press("PHASE_2")
		_present()
		for entry in _archive().entries:
			if String(entry.get("observation",{}).get("content_id","")).begins_with(NOTES.PREFIX):
				_expect(entry.observation.entry_kind == "document_segment","puzzle setting is not narrative consent")
	var count: int = _archive().entries.size()
	view._render_room()
	_present()
	_expect(_archive().entries.size() == count,"redraw does not duplicate observation")


func _failure_and_scope() -> void:
	var state := _fixture("B3_A","M1_GREAT_CLOCK")
	state.loop_state.event_local_states.CHAPTER_ONE.rubbed = CLOCK.CLOCKS.duplicate()
	_install(state)
	var controlled := ControlledSave.new()
	view.session._save = controlled
	var before := GameState.get_snapshot()
	_expect(not view._notebook_surface_allowed(),"save failure holds input")
	_press("B3_ROTATE_0")
	_press("B3_PIECE_0")
	_expect(GameState.get_snapshot() == before and view._swap_from == -1,"mutation and transient swap held")
	controlled.reject = false
	_press("B3_ROTATE_0")
	_expect(GameState.get_snapshot() == before,"explicit retry required")
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"retry saved")
	controlled.lose_ack = true
	_press("B3_ROTATE_0")
	_present()
	var count: int = _archive().entries.size()
	_present()
	_expect(_archive().entries.size() == count,"lost acknowledgment not duplicated")
	view.session._save = SaveManager
	controlled.free()
	_install(_fixture("B3_B","M1_GREAT_CLOCK"))
	_present()
	var old_scope := view._notebook_surface_scope()
	var generation: int = view._notebook_surfaces.generation
	_install(_fixture("B3_B","M1_GREAT_CLOCK"))
	var button := view._hotspot_layer.get_node("ROLE_reference") as OptionButton
	view._role_menu_displayed(button,"reference",generation,old_scope)
	_present()
	_expect(not _has_id(NOTES.PREFIX+"CLOCK_MENU_REFERENCE"),"stale popup callback after load ignored")
	view._role_menu_displayed(button,"reference",view._notebook_surfaces.generation,view._notebook_surface_scope())
	_expect(view._notebook_surfaces.has_pending(),"pending menu before slot change")
	var prior_slot: String = view.session.slot_id
	view.session.slot_id = "__test_other_notebook_scope"
	before = GameState.get_snapshot()
	_expect(not view._flush_notebook_surfaces(view._notebook_surfaces.generation),"slot scope blocks stale pending")
	_expect(GameState.get_snapshot() == before,"stale slot writes nothing")
	view.session.slot_id = prior_slot
	_install(_fixture("B3_B","M1_GREAT_CLOCK"))
	controlled = ControlledSave.new()
	view.session._save = controlled
	button = view._hotspot_layer.get_node("ROLE_reference") as OptionButton
	var original: int = button.selected
	button.show_popup()
	button.get_popup().hide()
	button.select(2)
	button.item_selected.emit(2)
	_expect(button.selected == original,"failed capture restores displayed role")
	controlled.reject = false
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"role menu capture retry")
	button.select(2)
	button.item_selected.emit(2)
	_present()
	button = view._hotspot_layer.get_node("ROLE_reference") as OptionButton
	button.select(0)
	button.item_selected.emit(0)
	_expect(button.selected == 2,"placeholder does not imply cleared role")
	before = GameState.get_snapshot()
	view._role_selected(3,"reference",generation,old_scope)
	_expect(GameState.get_snapshot() == before,"stale role selection ignored")
	view.session._save = SaveManager
	controlled.free()


func _later_controllers(tree: SceneTree) -> void:
	for item in [
		[preload("res://scripts/chapters/black_mirror_controller.gd"),"C4"],
		[preload("res://scripts/chapters/basement_controller.gd"),"D0"],
	]:
		_install(_fixture(item[1],"M1_LIBRARY_INNER"))
		view = item[0].new()
		view.configure_session(SLOT,item[1])
		tree.current_scene.add_child(view)
		view._dismiss_dialogue_for_test()
		_present()
		for entry in _archive().entries:
			_expect(not String(entry.get("observation",{}).get("content_id","")).begins_with(NOTES.PREFIX),"discarded base chapter controls excluded")
		_expect((view._hotspot_layer.get_node_or_null("INNER_desk") != null) == (item[1] == "C4"), "mirror retains parent investigation before J3; basement replaces it")
		_expect(view._hotspot_layer.get_node_or_null("J1_RESTORE") == null, "completed J1 cannot be restored again through the later UI")
		if item[1] == "C4":
			_inherited_action(item[1], "M1_LIBRARY_INNER", "INNER_desk", "NB_CH1_CH1_INNER_DESK")
		for owner in ["edgar", "luca", "mara1", "mara2"]:
			_inherited_action(item[1], "M1_SERVANT_COMMON", "DOC_" + owner, "NB_CH1_CH1_B1_TEXT_" + String(owner).to_upper(), "NB_CH1_NOTE_B1_" + String(owner).to_upper())
		_inherited_action(item[1], "M1_PARLOR", "RUB_CLOCK", "NB_CH1_CH1_CLOCK_PARLOR", "NB_CH1_NOTE_CLOCK_PARLOR")
		_inherited_action(item[1], "M2_BEDROOM", "AS_ROUTINE", "NB_CH1_ROUTINE")
		_inherited_action(item[1], "M1_NORTH_ARCHIVE_HALL", "MARA2_MEMORY", "NB_CH1_MARA2_MEMORY")
		view.queue_free()
		view = null
		await tree.process_frame


func _inherited_action(stage: String, room: String, button_id: String, content_id: String, note_id: String = "") -> void:
	_install(_fixture(stage, room))
	_present()
	var before := GameState.get_snapshot()
	var start: int = _archive().entries.size()
	_expect(view.session.stage() == stage, "inherited fixture uses its actual later stage")
	_press(button_id)
	for index in range(20):
		if not view._dialogue_active: break
		view._advance_dialogue()
	_expect(not view._dialogue_active, "inherited dialogue completes " + button_id)
	var found_dialogue := false
	var found_note := note_id.is_empty()
	var observed: Array = []
	for entry in _archive().entries.slice(start):
		_expect(entry.get("record_class") == "authored", "inherited action cannot silently produce unmapped text")
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if observation.content_id not in [content_id, note_id]: continue
		_expect(observation.node_id == stage and observation.chapter_id == "CHAPTER_2" and observation.location_id == room, "shared producer uses actual later event context")
		if observation.content_id == content_id:
			found_dialogue = true
			_expect(observation.producer_id == "NP04", "inherited dialogue retains its producer")
		else:
			found_note = true
			_expect(observation.producer_id == "NP06", "inherited acquisition retains its producer")
		for segment in observation.segments:
			_expect(segment.viewed_locale == TranslationServer.get_locale().replace("_", "-"), "inherited observation captures display locale")
			observed.append([observation.producer_id, observation.content_id, observation.node_id, segment.segment_id, segment.viewed_locale])
		_expect(CONTENT.render_entry(entry,"ko-KR").ok and CONTENT.render_entry(entry,"en-US").ok, "inherited record rereads in both languages")
	_expect(found_dialogue and found_note, "visible inherited action records expected dialogue and acquisition " + button_id)
	_expect(before.meta_progress.journal_stage == GameState.get_snapshot().meta_progress.journal_stage, "revisiting earlier material cannot regress journal restoration")
	inherited_paths.append({"stage": stage, "room": room, "button": button_id, "observed": observed})


func _matrix(locale: String) -> void:
	for length in range(4):
		for first in range(3):
			for second in range(3):
				if second == first: continue
				var third := 3-first-second
				var order := [first,second,third].slice(0,length)
				var labels := PackedStringArray()
				for id in order: labels.append(_text("CH1_J1_FRAGMENT_%d" % id,locale).get_slice("\n",0))
				_matches(NOTES.order(order),_text("CH1_J1_ORDER",locale)+" → ".join(labels),locale)
	for clock in CLOCK.CLOCKS:
		for index in range(4):
			for rotation in [0,90,180,270]:
				for back in [false,true]:
					var board := {"pieces":[clock,clock,clock,clock],"rotations":[rotation,rotation,rotation,rotation],"library_back":back}
					var actual_back: bool = clock == "library_outer" and back
					var text: String = _text("CH1_CLOCK_CARD",locale) % [index+1,_text("CH1_CLOCK_NAME_"+String(clock).to_upper(),locale),_text("CH1_CLOCK_DIR_%d" % rotation,locale),_text("CH1_CLOCK_PATTERN_"+("LIBRARY_BACK" if actual_back else String(clock).to_upper()),locale),_text("CH1_CLOCK_BACK" if actual_back else "CH1_CLOCK_FRONT",locale)]
					_matches(NOTES.card(index,board),text,locale)
	for role in CLOCK.ROLES:
		for selected in [""]+CLOCK.CLOCKS:
			_matches(NOTES.role(role,selected),_text("CH1_CLOCK_ROLE_"+String(role).to_upper(),locale)+" · "+_text("CH1_CLOCK_SELECT" if selected == "" else "CH1_CLOCK_NAME_"+String(selected).to_upper(),locale),locale)
	for rotation in [0,90,180,270]:
		_matches(NOTES.surface("J2_BOARD",{"direction":str(rotation)}),_text("CH1_J2_BOARD",locale)+_text("CH1_CLOCK_DIR_%d" % rotation,locale),locale)
	_expect(NOTES.order(JSON.parse_string("[2,0,1]")) == NOTES.order([2,0,1]),"JSON indices normalized")


func _fixture(stage: String, room: String) -> Dictionary:
	if not fixtures.has(stage):
		var result := CHECKPOINTS.new().snapshot_for(stage)
		_expect(result.ok,"checkpoint "+stage)
		fixtures[stage] = result.snapshot
	var state: Dictionary = fixtures[stage].duplicate(true)
	state.loop_state.location_id = room
	state.meta_progress.dialogue_history = ARCHIVE.create()
	state.meta_progress.knowledge_entries.erase(preload("res://scripts/systems/notebook_knowledge.gd").KEY)
	state.meta_progress.knowledge_entries.chapter_notebook = {}
	state.loop_state.event_local_states.CHAPTER_ONE = VIEW.SESSION_SCRIPT.new(GameState,SaveManager,SLOT).local_state(state)
	state.loop_state.event_local_states.CHAPTER_ONE.erase("last_feedback")
	return state


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
		view._edgar_timer.stop()
	GameState.reset_for_test()
	serial += 1
	var token := "NB_CHAPTER_SURFACE_FIXTURE_%d" % serial
	var result := StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(token))
	_expect(result.ok,"fixture install "+str(result.get("error_ids",[])))
	_expect(SaveManager.save_snapshot(SLOT,"SAVE_CAMPAIGN_PROGRESS",GameState.get_snapshot(),GameState.revision,token).ok,"fixture save")
	if view != null: view._render_room()


func _present() -> void:
	var before := GameState.get_snapshot()
	_expect(view._notebook_surface_allowed(),"surface capture")
	var after := GameState.get_snapshot()
	_expect(before == after or STATE_ASSERTIONS.same_surface_gameplay(before, after), "display changes only backed observations and their valid receipt: " + str(STATE_ASSERTIONS.changed_paths(before, after)))
	view.set_process(false)
	_collect()


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null,"missing button "+id)
	if button != null: button.pressed.emit()


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _has_id(id: String) -> bool:
	for entry in _archive().entries:
		if entry.get("observation",{}).get("content_id") == id: return true
	return false


func _collect() -> void:
	var before := GameState.get_snapshot()
	for entry in _archive().entries:
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_1","chapter context")
		for segment in observation.segments:
			covered[observation.content_id+":"+segment.viewed_locale] = true
			segments[observation.content_id+":"+segment.segment_id+":"+segment.viewed_locale] = true
		_expect(CONTENT.render_entry(entry,"ko-KR").ok and CONTENT.render_entry(entry,"en-US").ok,"bilingual replay")
	_expect(GameState.get_snapshot() == before,"replay is read only")


func _matches(descriptor: Dictionary, expected: String, locale: String) -> void:
	var result := CONTENT.presentation(descriptor,locale)
	matrix_cases += 1
	_expect(result.ok and result.get("text","") == expected,"matrix "+str(descriptor.get("content_id",""))+" "+locale)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(descriptor))
	var replay := CONTENT.presentation(decoded,locale)
	_expect(replay.ok and replay.get("text","") == expected,"serialized matrix "+str(descriptor.get("content_id","")))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("CHAPTER_SURFACE_ASSERT: ",message)
