extends "res://scripts/tests/notebook_prologue_smoke.gd"

const NOTES := preload("res://scripts/systems/notebook_prologue_surfaces.gd")
const TEXT := preload("res://data/dialogue/prologue/prologue_text.tres")
var surface_ids := {}
var surface_segments := {}
var matrix_cases := 0
var runtime_audit := preload("res://scripts/tests/notebook_runtime_audit.gd").new()

class ControlledSave extends Node:
	var reject := true
	var lose_ack := false
	func get_build_flavor() -> String: return SaveManager.get_build_flavor()
	func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
		if reject and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["ERR_TEST_PROLOGUE_SURFACE"]}
		var result := SaveManager.save_snapshot(slot,point,state,revision,transaction)
		return {"ok":false,"error_ids":["ERR_TEST_PROLOGUE_ACK"]} if result.ok and lose_ack else result
	func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary: return SaveManager.confirm_snapshot_commit(slot,transaction)


func run(tree: SceneTree) -> Dictionary:
	await super.run(tree)
	var locale := TranslationServer.get_locale()
	var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor","full")
	for language in ["ko-KR","en-US"]:
		TranslationServer.set_locale(language)
		print("PROLOGUE_SURFACE_PHASE: ",language)
		_matrix(language)
		await _additional_paths(tree,language)
		for id in CONTENT.diagnostics().content_ids:
			if not String(id).begins_with(NOTES.PREFIX): continue
			_expect(surface_ids.has(id+":"+language),"unvisited surface "+id+":"+language)
			for segment in CONTENT.definition(id,1).visible_segment_ids:
				_expect(surface_segments.has(id+":"+segment+":"+language),"unvisited segment "+id+":"+segment+":"+language)
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(locale)
	ProjectSettings.set_setting("ggb/build_flavor",flavor)
	print("PROLOGUE_SURFACE_COVERAGE: IDs/locales=",surface_ids.size()," segments/locales=",surface_segments.size()," matrix cases=",matrix_cases)
	_expect(runtime_audit.emit("prologue-surfaces", errors.is_empty()).ok, "runtime trace validates")
	return {"ok":errors.is_empty(),"errors":errors,"not_covered":["unified_notebook_UI","OS_input","restart_cursor"]}


func _additional_paths(tree: SceneTree, language: String) -> void:
	var view := _view(tree)
	await tree.process_frame
	_drain(view)
	_present(view)
	_expect(not _has("P2_WINDOW_LABEL"),"bedroom does not disclose other room surfaces")
	view._enter_room("M1_PARLOR")
	_drain(view)
	_present(view)
	_expect(not _has("WINDOW_INSPECTION_MULTILINE"),"unopened window inspection hidden")
	view._on_window_pressed(0)
	_present(view)
	for pair in [["WATER","TOP"],["SOFT_CLOTH","MIDDLE"],["SOFT_CLOTH","BOTTOM"],["SOFT_CLOTH","TOP"],["WATER","MIDDLE"],["WATER","BOTTOM"],["SOFT_CLOTH","MIDDLE"],["SOFT_CLOTH","BOTTOM"],["SOFT_CLOTH","TOP"]]:
		view._apply_window_tool(pair[0],pair[1])
		_drain(view)
		_present(view)
	view._on_window_pressed(1)
	view._apply_window_tool("SOFT_CLOTH","TOP")
	view._apply_window_tool("SOFT_CLOTH","MIDDLE")
	_present(view)
	view._reading_text_scale = 2.0
	view._refresh_window_inspection(true)
	_present(view)
	view._close_window_inspection()
	_present(view)
	_expect(view._hotspot_layer.get_node("WINDOW_0").text.contains(view._dialogue_ui_text("UI_DUTY_COMPLETE")),"closing inspection refreshes outer cleaning status")
	view._enter_room("M1_LIBRARY_OUTER")
	_drain(view)
	_present(view)
	view._on_shelf_item_dropped("BOOK_FLORA","SHELF_CLOCK")
	_present(view)
	_expect(view._progress.p3_placed.is_empty(),"wrong shelf observation does not place a book")
	view._enter_room("M1_KITCHEN")
	_drain(view)
	for step in range(6):
		view._on_tea_item_dropped("SPOON","TEA_%d" % step)
		_present(view)
		view._on_tea_item_dropped(view.TEA_STEP_ITEMS[(step+1)%6],"TEA_%d" % ((step+1)%6))
		_present(view)
		view._on_tea_item_dropped(view.TEA_STEP_ITEMS[step],"TEA_%d" % step)
		_drain(view)
		_present(view)
	_expect(not _has("P4_STEP_5_DONE"),"undisplayed completed sixth tile excluded")
	_collect(language)
	view.queue_free()
	await tree.process_frame
	await _failure_and_scope(tree,language)


func _failure_and_scope(tree: SceneTree, language: String) -> void:
	var view := _view(tree)
	await tree.process_frame
	_drain(view)
	view._enter_room("M1_PARLOR")
	_drain(view)
	_present(view)
	var controlled := ControlledSave.new()
	view._prologue_surface_saves = controlled
	view._on_window_pressed(0)
	var before := GameState.get_snapshot()
	_expect(not view._prologue_surface_allowed(),"failed inspection capture blocks next action")
	var old_state: Dictionary = view._progress.duplicate(true)
	view._apply_window_tool("SOFT_CLOTH","TOP")
	view._close_window_inspection()
	_expect(GameState.get_snapshot() == before and view._progress == old_state and view._inspection_active,"failed capture holds tool and close")
	_expect(is_instance_valid(view._prologue_surface_retry) and view._prologue_surface_retry.get_parent() == view and view._prologue_surface_retry.z_index > view._inspection_layer.z_index,"retry accessible above window overlay")
	await tree.process_frame
	_expect(view._prologue_surface_retry.has_focus(),"retry receives keyboard focus")
	controlled.reject = false
	view._apply_window_tool("SOFT_CLOTH","TOP")
	_expect(GameState.get_snapshot() == before,"explicit retry is required")
	view._prologue_surface_retry.pressed.emit()
	await tree.process_frame
	_expect(not is_instance_valid(view._prologue_surface_retry),"retry saves and removes failure control")
	controlled.lose_ack = true
	view._apply_window_tool("SOFT_CLOTH","TOP")
	_present(view)
	var count: int = _archive().entries.size()
	_present(view)
	_expect(_archive().entries.size() == count,"lost acknowledgment does not duplicate observation")
	view._prologue_surface_saves = null
	controlled.free()
	view._close_window_inspection()
	var stale: Callable = view._hotspot_layer.get_node("CLOCK").pressed.get_connections()[0].callable
	view._rebuild_current_room_content()
	_present(view)
	before = GameState.get_snapshot()
	stale.call()
	_expect(GameState.get_snapshot() == before and not view._dialogue_active,"stale generation cannot inspect clock")
	view._on_window_pressed(2)
	var original_slot: String = view._slot_id
	view._slot_id = "__test_other_prologue_surface"
	before = GameState.get_snapshot()
	_expect(not view._prologue_surface_allowed() and GameState.get_snapshot() == before,"queued surface cannot write into another slot")
	view._slot_id = original_slot
	_present(view)
	view._close_window_inspection()
	# A recipe redraw may block its deferred story continuation until explicit retry.
	view._enter_room("M1_KITCHEN")
	_drain(view)
	_present(view)
	view._progress.tea_step = 5
	view._progress.p4_life_support_seen = true
	view._progress.p4_life_support_pending = true
	controlled = ControlledSave.new()
	view._prologue_surface_saves = controlled
	view._rebuild_current_room_content()
	await tree.process_frame
	_expect(not view._dialogue_active and view._progress.p4_life_support_pending,"failed surface holds deferred pulse scene")
	controlled.reject = false
	view._prologue_surface_retry.pressed.emit()
	await tree.process_frame
	_expect(view._dialogue_active,"explicit retry resumes deferred pulse scene")
	_drain(view)
	view._prologue_surface_saves = null
	controlled.free()
	_present(view)
	_collect(language)
	var old_drop: Callable = view._hotspot_layer.get_node("TEA_5").inventory_item_dropped.get_connections()[0].callable
	view._rebuild_current_room_content()
	_present(view)
	before = GameState.get_snapshot()
	old_state = view._progress.duplicate(true)
	old_drop.call("TEAPOT","TEA_5")
	_expect(GameState.get_snapshot() == before and view._progress == old_state,"stale drop callback cannot complete tea")
	before = GameState.get_snapshot()
	_expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"surface archive reloads")
	# Event arrays are untyped JSON numbers; compare exact persisted values, not int/float container types.
	_expect(StateSnapshotValidator.same_persisted_value(before,GameState.get_snapshot()),"reload keeps viewed states and stable identities: "+_difference(before,GameState.get_snapshot()))
	before = GameState.get_snapshot()
	view._hotspot_layer.get_node("TEA_5").inventory_item_dropped.emit("TEAPOT","TEA_5")
	_expect(GameState.get_snapshot() == before and view._progress == old_state,"old view input after load is rejected even without pending capture")
	view.queue_free()
	await tree.process_frame


func _matrix(language: String) -> void:
	for index in range(3):
		for mask in range(16):
			var state := {"top_dust":bool(mask&1),"middle_stain":bool(mask&2),"bottom_wet":bool(mask&4),"dust_spread":bool(mask&8)}
			if state.dust_spread and not state.top_dust: continue
			var stage := 0 if state.top_dust or state.dust_spread else (1 if state.middle_stain else (2 if state.bottom_wet else 3))
			var stage_text := _text(["P2_STAGE_TOP","P2_STAGE_MIDDLE","P2_STAGE_BOTTOM","UI_DUTY_COMPLETE"][stage],language)
			_matches(NOTES.surface("P2_WINDOW_LABEL",{"index":index+1,"stage":str(stage)}),_text("P2_WINDOW_LABEL",language).format({"index":index+1,"state":stage_text}),language)
			for inline_labels in [false,true]:
				var lines := [_text("P2_TITLE",language).format({"index":index+1,"state":stage_text})]
				for pair in [["P2_TOP","P2_SPREAD" if state.dust_spread else ("P2_DUST" if state.top_dust else "P2_CLEAR")],["P2_MIDDLE","P2_STAIN" if state.middle_stain else "P2_CLEAR"],["P2_BOTTOM","P2_WET" if state.bottom_wet else "P2_DRY"]]:
					var line := _text(pair[0],language).format({"state":_text(pair[1],language)})
					lines.append(line.replace("\n"," · ") if inline_labels else line)
				_matches(NOTES.window(index,stage,state,inline_labels),"\n".join(lines),language)
	for index in range(6):
		var step := _text("P4_TEA_STEP_%d" % index,language)
		for key in ["P4_TEA_ORDER","P4_TEA_DONE"]:
			_matches(NOTES.surface(key,{"step":str(index)}),_text(key,language).format({"step":step}),language)
		var item := _text("P4_TEA_ITEM_"+String(["HOT_WATER","CUP","TEA_LEAVES","HOT_WATER","TIMER","TEAPOT"][index]),language)
		_matches(NOTES.surface("P4_TEA_REQUIRES",{"step":str(index),"item":str(index)}),_text("P4_TEA_REQUIRES",language).format({"step":step,"item":item}),language)


func _present(view: Node) -> void:
	var before := GameState.get_snapshot()
	_expect(view._prologue_surface_allowed(),"surface capture succeeds")
	var after := GameState.get_snapshot()
	_expect(preload("res://scripts/tests/notebook_state_assertions.gd").same_surface_gameplay(before,after),"surface capture only appends observations and backed receipts, not progress or knowledge")


func _collect(language: String) -> void:
	super._collect(language)
	runtime_audit.capture(_archive())
	for entry in _archive().entries:
		var observation: Dictionary = entry.get("observation",{})
		var id := String(observation.get("content_id",""))
		if not id.begins_with(NOTES.PREFIX): continue
		surface_ids[id+":"+language] = true
		_expect(observation.chapter_id == "PROLOGUE" and observation.entry_kind == "document_segment","surface is a prologue document, not a choice")
		for segment in observation.segments:
			surface_segments[id+":"+segment.segment_id+":"+language] = true


func _has(key: String) -> bool:
	for entry in _archive().entries:
		if entry.get("observation",{}).get("content_id") == NOTES.PREFIX+key: return true
	return false


func _archive() -> Dictionary: return GameState.get_snapshot().meta_progress.dialogue_history


func _text(key: String, language: String) -> String: return TEXT.localized_text[language][key]


func _difference(before: Variant, after: Variant, path: String = "snapshot") -> String:
	if before == after: return ""
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key): return path+"."+str(key)+" missing"
			if before[key] != after[key]: return _difference(before[key],after[key],path+"."+str(key))
	elif before is Array and after is Array and before.size() == after.size():
		for index in range(before.size()):
			if before[index] != after[index]: return _difference(before[index],after[index],path+"["+str(index)+"]")
	return path+" "+str(before).left(150)+" -> "+str(after).left(150)


func _matches(descriptor: Dictionary, expected: String, language: String) -> void:
	matrix_cases += 1
	var result := CONTENT.presentation(descriptor,language)
	_expect(result.ok and result.get("text","") == expected,"dynamic surface matches "+str(descriptor.get("content_id","")))
	var replay := CONTENT.presentation(JSON.parse_string(JSON.stringify(descriptor)),language)
	_expect(replay.ok and replay.get("text","") == expected,"serialized surface matches")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		print("PROLOGUE_SURFACE_ASSERT: ",message)
