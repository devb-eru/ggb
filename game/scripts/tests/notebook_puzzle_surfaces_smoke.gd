extends RefCounted

const STATE_ASSERTIONS := preload("res://scripts/tests/notebook_state_assertions.gd")

const NOTES := preload("res://scripts/systems/notebook_puzzle_surfaces.gd")
const CONTENT := NOTES.CONTENT
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const MIRROR_VIEW := preload("res://scripts/chapters/black_mirror_controller.gd")
const BASEMENT_VIEW := preload("res://scripts/chapters/basement_controller.gd")
const MIRROR := preload("res://scripts/ui/black_mirror_display_texts.gd")
const BASEMENT := preload("res://scripts/ui/basement_display_texts.gd")
const SLOT := "__test_notebook_puzzle_surfaces"
var errors := PackedStringArray()
var covered := {}
var segments := {}
var fixtures := {}
var view: ChapterOneController
var serial := 0
var matrix_cases := 0
var coverage := preload("res://scripts/tests/notebook_puzzle_coverage.gd").new()

class ControlledSave extends Node:
	var reject := true
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["ERR_TEST_PUZZLE_SAVE"]}
		var result := SaveManager.save_snapshot(slot,point,state,revision,transaction)
		return {"ok":false,"error_ids":["ERR_TEST_PUZZLE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary: return SaveManager.confirm_snapshot_commit(slot,transaction)


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor","full")
	var diagnostic := CONTENT.diagnostics()
	if not diagnostic.ok: return diagnostic
	for language in ["ko-KR","en-US"]:
		TranslationServer.set_locale(language)
		print("PUZZLE_SURFACE_PHASE: ",language," descriptor matrix")
		_matrix(language)
		print("PUZZLE_SURFACE_PHASE: ",language," mirror views")
		_install(_fixture("C4","M1_MIRROR_GALLERY"))
		view = MIRROR_VIEW.new()
		view.configure_session(SLOT,"C4")
		tree.current_scene.add_child(view)
		view._dismiss_dialogue_for_test()
		_mirror_views()
		_failure()
		view.queue_free()
		view = null
		await tree.process_frame
		print("PUZZLE_SURFACE_PHASE: ",language," basement views")
		_install(_fixture("D0","M1_LIBRARY_INNER"))
		view = BASEMENT_VIEW.new()
		view.configure_session(SLOT,"D0")
		tree.current_scene.add_child(view)
		view._dismiss_dialogue_for_test()
		_basement_views()
		view.queue_free()
		view = null
		await tree.process_frame
		for id in diagnostic.content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			var row := CONTENT.definition(id,1)
			_expect(row.locales[language].title not in ["퍼즐에서 확인한 자료","Observed Puzzle Material"],"specific public material title")
			_expect(row.event_id not in ["C_SLEEP","D_SLEEP"],"material family not assigned to unrelated sleep")
			_expect(covered.has(id+":"+language),"unvisited actual ID "+id+":"+language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(segments.has(id+":"+segment+":"+language),"unvisited actual segment "+id+":"+segment+":"+language)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor",flavor)
	print("PUZZLE_SURFACE_COVERAGE: actual IDs/locales=",covered.size()," segments/locales=",segments.size()," matrix cases=",matrix_cases)
	return {"ok":errors.is_empty(),"errors":errors,"not_covered":["unified_notebook_comparison_UI","OS_input","B4_C5_D4_visual_assets"]}


func _matrix(locale: String) -> void:
	var local := {"rotation":0,"flipped":false,"anchored":false,"path":[]}
	var routes: Array = [[]]
	for length in range(1,5):
		var next: Array = []
		for previous in routes:
			if previous.size() != length-1: continue
			for id in MIRROR.SEGMENTS:
				var route: Array = previous.duplicate()
				route.append(id)
				next.append(route)
		routes.append_array(next)
	for route in routes:
		local.path = route
		for rotation in [0,90,180,270]:
			local.rotation = rotation
			local.flipped = rotation in [90,270]
			local.anchored = rotation in [180,270]
			_matches(NOTES.trace(local),MIRROR.trace_status(local,locale),locale)
	for rotation in [0,90,180,270]:
		for flipped in [false,true]:
			for anchored in [false,true]:
				local.rotation = rotation
				local.flipped = flipped
				local.anchored = anchored
				local.path = ["entry","long_branch"]
				var descriptor := NOTES.trace(local,true)
				_matches(descriptor,MIRROR.ui("overlay_title",locale)+"\n"+MIRROR.ui("overlay_body",locale)+"\n"+MIRROR.trace_status(local,locale)+"\n"+MIRROR.ui("overlay_back",locale),locale)
				var diagram := NOTES.replay_overlay(descriptor)
				_expect(diagram != null,"versioned diagram available")
				if diagram != null:
					_expect(diagram.turn_degrees == rotation and diagram.mirrored == flipped and diagram.fixed_anchor == anchored,"frozen diagram parameters")
					diagram.free()
				descriptor.segments.erase("state")
				_expect(NOTES.replay_overlay(descriptor) == null,"undisclosed diagram cannot be synthesized")
	local.path = []
	_expect(NOTES.replay_overlay(NOTES.trace(local)) == null,"text board cannot imply a viewed diagram")
	var future := NOTES.trace(local,true)
	future.content_version = 2
	_expect(NOTES.replay_overlay(future) == null,"unknown diagram version not replaced")
	var reloaded_order: Array = JSON.parse_string("[2,0,3,1]")
	_expect(NOTES.j3_order(reloaded_order) == NOTES.j3_order([2,0,3,1]),"JSON fragment indices normalized")
	var reloaded_heart: Dictionary = JSON.parse_string('{"rings":[1,2,3],"wind":12}')
	_expect(NOTES.heart(reloaded_heart) == NOTES.heart({"rings":[1,2,3],"wind":12}),"JSON glyph indices normalized")
	for water in range(9):
		for stabilizer in range(9-water):
			for active in range(9-water-stabilizer):
				for flags in range(4):
					var mix := {"water":water,"stabilizer":stabilizer,"active":active,"dispersed":bool(flags & 1),"foamy":bool(flags & 2),"mixed":flags}
					_matches(NOTES.mixture(mix),MIRROR.mixture_status(mix,locale),locale)
	for rotation in [0,90,180,270]:
		for flipped in [false,true]:
			for anchor in ["","bedroom","greenhouse","great_clock"]:
				var floorplan := {"rotation":rotation,"flipped":flipped,"anchor":anchor}
				_matches(NOTES.floorplan(floorplan),BASEMENT.floorplan_status(floorplan,locale),locale)
	for axis in BASEMENT.AXES:
		for depth in range(1,4):
			for pushed in [false,true]:
				var axes := {"depths":{axis:depth},"pushed":[axis] if pushed else []}
				var descriptor := NOTES.axis(axis,axes)
				_matches(descriptor,BASEMENT.axis_status(axis,axes,locale),locale)
				_expect(not pushed or descriptor.segments.body.is_empty(),"hidden pushed depth excluded")
	for a in range(4):
		for b in range(4):
			for c in range(4):
				for wind in range(13):
					var heart := {"rings":[a,b,c],"wind":wind}
					_matches(NOTES.heart(heart),BASEMENT.heart_status(heart,locale),locale)
	for a in range(4):
		for b in range(4):
			if b == a: continue
			for c in range(4):
				if c in [a,b]: continue
				for d in range(4):
					if d in [a,b,c]: continue
					var order := [a,b,c,d]
					for length in range(1,5):
						var names := PackedStringArray()
						for id in order.slice(0,length): names.append(MIRROR.j3_part(id,locale).get_slice("\n",0))
						_matches(NOTES.j3_order(order.slice(0,length)),(" -> " if locale.begins_with("en") else " → ").join(names),locale)


func _mirror_views() -> void:
	for room in ["M1_TOOL_ROOM","M1_GREAT_CLOCK","M1_COLOR_ROOM_ENTRY"]:
		var state := _fixture("C4",room)
		state.meta_progress.knowledge_entries["color_room_entry_inspectable"] = false
		_install(state)
		_present()
		if room == "M1_COLOR_ROOM_ENTRY":
			state.meta_progress.knowledge_entries["color_room_entry_inspectable"] = true
			_install(state)
			_present()
	for stage in ["C3","C_BELL","C4"]:
		_install(_fixture(stage,"M1_KITCHEN"))
		_present()
		if stage == "C3":
			var before := GameState.get_snapshot()
			view._open_cleaner_quantity_table()
			for id in ["QuantityRatio","QuantityWaterDifference"]:
				var button := view._modal_body.get_node(NodePath(id)) as CheckButton
				button.button_pressed = true
				button.button_pressed = false
			view._close_modal()
			_expect(STATE_ASSERTIONS.same_gameplay(before, GameState.get_snapshot(), "utility"),"quantity scratch tool changes only its completed presentation cursor")
			_expect(STATE_ASSERTIONS.mutation_guards(before, GameState.get_snapshot(), "utility"), "read-only comparator rejects gameplay, disclosure, unfinished cursor and foreign-scope mutations")
	_install(_fixture("CF","M1_MIRROR_GALLERY"))
	_present()
	for length in range(5):
		var state := _fixture("C4","M1_MIRROR_GALLERY")
		var local: Dictionary = state.loop_state.event_local_states.BLACK_MIRROR
		local.path = ["entry","long_branch","clockwise_ring","short_branch"].slice(0,length)
		local.rotation = (length % 4) * 90
		local.flipped = length % 2 == 1
		local.anchored = length >= 2
		_install(state)
		_present()
		_expect(_count("OVERLAY_%d" % length) == 0,"opening diagram required")
		view._open_trace_overlay()
		_expect(view._recorded_modal_request.get("recorded",false),"overlay modal captured")
		_collect()
		var descriptor: Dictionary = view._recorded_modal_request.history_context.notebook_content.duplicate(true)
		var before := GameState.get_snapshot()
		var replay := NOTES.replay_overlay(descriptor)
		_expect(replay != null,"observed diagram replay")
		if replay != null: replay.free()
		_expect(GameState.get_snapshot() == before,"diagram replay is read only")
		view._recorded_choice_pressed(view._recorded_modal_request,0)
		_expect(_count("OVERLAY_%d" % length) == 1,"close adds no selection or duplicate")
	var channel_state := _fixture("C5_INFO","M1_MIRROR_GALLERY")
	channel_state.loop_state.event_local_states.BLACK_MIRROR.channels_scanned = []
	_install(channel_state)
	_present()
	for owner in MIRROR.CHANNELS:
		_expect(_count("C_CHANNEL_%s_UNCHECKED" % owner) == 1,"visible label captured")
	_press("SCAN_EDGAR")
	_drain()
	_present()
	channel_state.loop_state.event_local_states.BLACK_MIRROR.channels_scanned = MIRROR.CHANNELS.keys()
	_install(channel_state)
	_present()
	for length in range(5):
		var state := _fixture("J3","M1_LIBRARY_INNER")
		state.loop_state.event_local_states.BLACK_MIRROR.j3_order = [2,0,3,1].slice(0,length)
		_install(state)
		_present()
		_expect(GameState.get_value("meta_progress.journal_stage",0) == 2,"fragment display does not restore J3")


func _basement_views() -> void:
	for stage in ["D0","D0_A"]:
		_install(_fixture(stage,"M1_LIBRARY_INNER"))
		_present()
	for pushed in [[],["line","branch","ring"]]:
		var state := _fixture("D1","B1_AXIS_CHAMBER")
		state.loop_state.event_local_states.BASEMENT.axes.pushed = pushed
		_install(state)
		_present()
	_install(_fixture("DF","B1_AXIS_CHAMBER"))
	_present()
	_install(_fixture("D2","B1_STORAGE"))
	_present()
	_install(_fixture("D4","B1_CLOCKWORK_HEART"))
	_present()
	var count: int = _archive().entries.size()
	view._render_room()
	_present()
	_expect(_archive().entries.size() == count,"same frame redraw is not another observation")
	for stage in ["E_HUB","F0_A","EDS_DINING_ROOM"]:
		_install(_fixture(stage,"M1_LIBRARY_INNER"))
		_present()
		for entry in _archive().entries:
			_expect(not String(entry.get("observation",{}).get("content_id","")).begins_with(NOTES.PREFIX),"discarded intermediate puzzle UI not captured")


func _failure() -> void:
	_install(_fixture("C4","M1_MIRROR_GALLERY"))
	var controlled := ControlledSave.new()
	view.session._save = controlled
	var before := GameState.get_snapshot()
	_expect(not view._notebook_surface_allowed(),"failed surface save held")
	view._do("c_rotate",null,false)
	_expect(GameState.get_snapshot() == before,"failed observation blocks mutation")
	controlled.reject = false
	view._do("c_rotate",null,false)
	_expect(GameState.get_snapshot() == before,"explicit retry required")
	_expect(view._flush_notebook_surfaces(view._notebook_surfaces.generation,true),"explicit surface retry")
	controlled.lose_ack = true
	_press("c_rotate")
	_present()
	var count: int = _archive().entries.size()
	_present()
	_expect(_archive().entries.size() == count,"lost acknowledgment resolves without duplicates")
	view.session._save = SaveManager
	controlled.free()
	_collect()


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
	return state


func _install(state: Dictionary) -> void:
	if view != null:
		view.session._save = SaveManager
		view._dismiss_dialogue_for_test()
		view._close_modal()
	GameState.reset_for_test()
	serial += 1
	var token := "NB_PUZZLE_FIXTURE_%d" % serial
	var result := StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(token))
	_expect(result.ok,"fixture install "+str(result.get("error_ids",[])))
	_expect(SaveManager.save_snapshot(SLOT,"SAVE_BROKEN_RESET_COMPLETE",GameState.get_snapshot(),GameState.revision,token).ok,"fixture save")
	if view != null: view._render_room()


func _present() -> void:
	_expect(view._notebook_surface_allowed(),"surface capture")
	view.set_process(false)
	_collect()


func _press(id: String) -> void:
	var button := view._hotspot_layer.get_node_or_null(NodePath(id)) as Button
	_expect(button != null,"missing button "+id)
	if button != null: button.pressed.emit()


func _drain() -> void:
	for index in range(30):
		if not view._dialogue_active: return
		view._advance_dialogue()
	_expect(false,"blocked dialogue")


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _count(key: String) -> int:
	var count := 0
	for entry in _archive().entries:
		if entry.get("observation",{}).get("content_id") == NOTES.PREFIX+key: count += 1
	return count


func _collect() -> void:
	coverage.collect(_archive().entries, "puzzle-surfaces")
	var before := GameState.get_snapshot()
	for entry in _archive().entries:
		if entry.get("record_class") != "authored": continue
		var observation: Dictionary = entry.observation
		if not observation.content_id.begins_with(NOTES.PREFIX): continue
		_expect(observation.chapter_id == "CHAPTER_2","puzzle chapter context")
		for segment in observation.segments:
			covered[observation.content_id+":"+segment.viewed_locale] = true
			segments[observation.content_id+":"+segment.segment_id+":"+segment.viewed_locale] = true
		if observation.content_id.begins_with(NOTES.PREFIX+"OVERLAY_"):
			var values := {}
			for segment in observation.segments: values[segment.segment_id] = segment.safe_variables
			var descriptor := CONTENT.descriptor(observation.content_id,int(observation.content_version),values)
			var diagram := NOTES.replay_overlay(descriptor)
			_expect(diagram != null,"serialized observation reconstructs diagram")
			if diagram != null: diagram.free()
		_expect(CONTENT.render_entry(entry,"ko-KR").ok and CONTENT.render_entry(entry,"en-US").ok,"bilingual replay")
	_expect(GameState.get_snapshot() == before,"replay does not write")


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
		print("PUZZLE_SURFACE_ASSERT: ",message)
