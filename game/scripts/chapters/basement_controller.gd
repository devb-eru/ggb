class_name BasementController
extends BlackMirrorController

const BASEMENT_SESSION := preload("res://scripts/systems/basement_session.gd")
const BASEMENT_RULES := preload("res://data/puzzles/puzzle_basement.tres")
const ENDING_SIGNATURE := preload("res://scripts/ui/ending_signature.gd")
const ENDING_TEXTS := preload("res://scripts/ui/ending_decision_texts.gd")
const FIELD_TEXTS := preload("res://scripts/ui/field_notebook_texts.gd")
const STAY_TEXTS := preload("res://scripts/ui/stay_charter_texts.gd")
const STORY_TEXTS := preload("res://scripts/ui/stay_story_texts.gd")
const STAY_NOTES := preload("res://scripts/systems/stay_notebook.gd")
const WAKE_TEXTS := preload("res://scripts/ui/reality_wake_texts.gd")
const SURFACE_TEXTS := preload("res://scripts/ui/reality_surface_texts.gd")
const CREDITS_TEXTS := preload("res://scripts/ui/ending_credits_texts.gd")
const GALLERY_TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")
const D5_TRANSITION_ART := preload("res://scripts/ui/d5_transition_art.gd")
const FRACTURE_REST_TEXTS := preload("res://scripts/ui/fracture_rest_texts.gd")
const CORE_STORY_TEXTS := preload("res://scripts/ui/core_story_texts.gd")
const BASEMENT_TEXTS := preload("res://scripts/ui/basement_display_texts.gd")
const FRACTURE_COMMON_TEXTS := preload("res://scripts/ui/fracture_common_display_texts.gd")
const RELATIONSHIP_TEXTS := preload("res://scripts/ui/relationship_display_texts.gd")
const FRACTURE_RESOLUTION_TEXTS := preload("res://scripts/ui/fracture_resolution_display_texts.gd")
const FRACTURE_SURFACE_TEXTS := preload("res://scripts/ui/fracture_surface_texts.gd")
const MARA1_NOTES := preload("res://scripts/systems/mara1_notebook.gd")
const IRIS_NOTES := preload("res://scripts/systems/iris_notebook.gd")
const LUCA_NOTES := preload("res://scripts/systems/luca_notebook.gd")
const EDGAR_NOTES := preload("res://scripts/systems/edgar_notebook.gd")
const MARA2_NOTES := preload("res://scripts/systems/mara2_notebook.gd")
const SETTLEMENT_NOTES := preload("res://scripts/systems/settlement_notebook.gd")
const JOURNAL_DISPLAY := preload("res://scripts/systems/journal_four_display_notebook.gd")
const CORE_NOTES := preload("res://scripts/systems/core_notebook.gd")
const FINAL_NOTES := preload("res://scripts/systems/final_notebook.gd")
const REALITY_NOTES := preload("res://scripts/systems/reality_notebook.gd")
var _surface_active_seconds := 0.0
var _stay_inspection_open := false
var _demo_stinger_seconds := 0.0
var _demo_stinger_save_failed := false
var _d5_hold_seconds := 0.0
var _d5_hold_active := false
var _d6_guidance_seconds := 0.0
var _d6_guidance_failed := false
var _d6_sleep_transition_seconds := 0.0
var _d6_sleep_transition_active := false
var _d6_sleep_transition_route := ""
var _d6_sleep_transition_failed := false
const FULL_D5_HOLD_SECONDS := 10.0
const D6_SLEEP_TRANSITION_SECONDS := 6.0
const FULL_D5_HOLD_KO := FRACTURE_SURFACE_TEXTS.HOLD_KO
const FULL_D5_HOLD_EN := FRACTURE_SURFACE_TEXTS.HOLD_EN
const OBJECTIVE_TEXT := {"D_SLEEP": "J3를 기억한 채 잠들어 다음 아침을 맞는다", "D0": "기록 내실의 세 눌림점에서 평면도를 꺼낸다", "D0_A": "C5 투명지와 저택 도면의 방향·기준점을 검증한다", "D1": "세 축의 순서와 깊이를 도면대로 적용한다", "DF": "압력핀 잠김 · 같은 침실에서 잠든다", "D2": "지하창고의 반복 구조를 조사한다", "D4": "태엽 심장의 연동 링과 정상 기동을 확인한다", "D5": "위장 필터 너머 드러난 공간을 확인한다", "DEMO_END": "데모 공개 구간 종료", "D6": "파열된 저택을 확인한 뒤 침실로 돌아간다", "E1_ENTRY": "같은 침실의 다른 아침"}

func _make_session() -> ChapterOneSession:
	var created := BASEMENT_SESSION.new(GameState, SaveManager, _slot_id)
	var source := String(GameState.get_value(&"meta_progress.knowledge_entries.reselect_source_slot_id", ""))
	if OS.is_debug_build() and (_slot_id.begins_with("__dev_checkpoint") or source.begins_with("__dev_checkpoint")):
		created.ending_meta_store = EndingMetaStore.new("user://development/profile")
	return created

func _supported_hint_stages() -> Array:
	return ["D0_A", "D1", "DF", "D4", "F0_A", "F0_B", "F0_C", "F0_D", "F0_E"]

func _puzzle_hint_text(level: int) -> String:
	if session.stage().begins_with("F0_"):
		return preload("res://scripts/ui/core_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())
	return preload("res://scripts/ui/basement_hint_texts.gd").text(session.stage(), level, TranslationServer.get_locale())

func _puzzle_hint_title() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if session.stage().begins_with("F0_"):
		return ("Core puzzle hints · " if english else "코어 퍼즐 생각 정리 · ") + session.stage().replace("_", "-")
	match session.stage():
		"D0_A": return "Floorplan overlay hints" if english else "저택 도면 생각 정리"
		"D1", "DF": return "Pressure axis hints" if english else "압력축 생각 정리"
		_: return "Clockwork heart hints" if english else "태엽 심장 생각 정리"

func _basement() -> BasementSession:
	return session as BasementSession

func _history_enabled() -> bool:
	if session == null:
		return false
	var current_stage := session.stage()
	if current_stage in ["DEMO_END", "ENDING_CREDITS", "POST_CREDITS", "ENDING_BODY_PENDING"]:
		return false
	return not (current_stage == "D5" and SaveManager.get_build_flavor() == "demo")

func _feedback(result: Dictionary) -> void:
	if session != null and session.stage() == "D5" and SaveManager.get_build_flavor() == "demo" and result.get("ok", false):
		_set_status(BASEMENT_TEXTS.ui("d5_demo_running", TranslationServer.get_locale()))
		return
	var displayed := result.duplicate(true)
	var descriptors: Array = result.get("notebook_feedback", [])
	var first_id := String(descriptors[0].get("content_id", "")) if not descriptors.is_empty() else ""
	if result.get("ok", false) and (first_id.begins_with(JOURNAL_DISPLAY.PREFIX) or first_id.begins_with(CORE_NOTES.PREFIX) or first_id.begins_with(FINAL_NOTES.PREFIX)):
		_show_notebook_feedback(result, descriptors)
		return
	var original := String(result.get("text", ""))
	var locale := TranslationServer.get_locale()
	displayed["text"] = _d6_text(ENDING_TEXTS.feedback(CORE_STORY_TEXTS.feedback(FRACTURE_RESOLUTION_TEXTS.feedback(RELATIONSHIP_TEXTS.feedback(FRACTURE_COMMON_TEXTS.feedback(BASEMENT_TEXTS.feedback(original, locale), locale), locale), locale), locale), locale))
	if displayed["text"] != original:
		displayed["speaker"] = CORE_STORY_TEXTS.speaker(String(result.get("speaker", "주인공")), locale)
	super._feedback(displayed)
	if not displayed.get("ok", false) and displayed.has("notebook_status"):
		_queue_notebook_content(String(displayed.notebook_status), _status_label.text, true)
		_notebook_surface_allowed()


func _show_notebook_feedback(result: Dictionary, descriptors: Array) -> void:
	var lines: Array = []
	var originals := PackedStringArray()
	for descriptor in descriptors:
		var original := NOTEBOOK_CONTENT.presentation(descriptor, "ko-KR")
		var shown := NOTEBOOK_CONTENT.presentation(descriptor, TranslationServer.get_locale())
		if not original.ok or not shown.ok or shown.segments.size() != 1:
			_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
			return
		originals.append(original.text)
		lines.append({"speaker": shown.speaker, "portrait": "", "text": shown.text, "notebook_content": descriptor.duplicate(true), "history_context": result.history_context})
	if originals != String(result.text).split("\n", false):
		push_error("NB_TYPED_FEEDBACK_SOURCE_MISMATCH")
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	# Unknown old quotations bypass prose-based translation; their frozen text is literal.
	_show_dialogue(lines)

func _update_objective() -> void:
	if session != null:
		_objective_label.text = BASEMENT_TEXTS.objective(session.stage(), TranslationServer.get_locale()) if BASEMENT_TEXTS.OBJECTIVES.has(session.stage()) else OBJECTIVE_TEXT.get(session.stage(), BASEMENT_TEXTS.objective("default", TranslationServer.get_locale()))


func _queue_notebook_surface(key: String, text: String) -> void:
	_queue_notebook_content(FRACTURE_SURFACE_TEXTS.PREFIX + key, text)


func _queue_core_surface(key: String, text: String, values: Dictionary = {}) -> void:
	if _notebook_surface_enabled():
		_notebook_surfaces.queue_descriptor(CORE_NOTES.descriptor("SCREEN_" + key, values), text, TranslationServer.get_locale(), session.history_context())


func _core_board(key: String, text: String, rect: Rect2, values: Dictionary = {}) -> void:
	_board_label(text, rect)
	_queue_core_surface(key, text, values)


func _notebook_surface_board(key: String, text: String, rect: Rect2) -> void:
	_board_label(text, rect)
	_queue_notebook_surface(key, text)


func _notebook_world_choice(group: String, index: int, id: String, rect: Rect2, action: String, value: String) -> void:
	var locale := TranslationServer.get_locale()
	var label := FRACTURE_COMMON_TEXTS.ui(FRACTURE_SURFACE_TEXTS.CHOICES[group][index], locale)
	if not _notebook_surface_enabled():
		_action(id, label, rect, action, value)
		return
	_add_hotspot(id, label, rect, _notebook_world_choice_pressed.bind(_notebook_surfaces.generation, group, index, label, locale, action, value))


func _notebook_world_choice_pressed(generation: int, group: String, index: int, label: String, locale: String, action: String, value: String) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(), generation): return
	if not _notebook_surface_allowed(): return
	var options_id := FRACTURE_SURFACE_TEXTS.PREFIX + "OPTIONS_" + group
	var selection_id := FRACTURE_SURFACE_TEXTS.PREFIX + "SELECT_%s_%d" % [group, index]
	if not _notebook_surfaces.choose(session, _notebook_surface_scope(), options_id, selection_id, label, locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act(action, value)
	_notebook_surfaces.dispatched(options_id, result.get("ok", false))
	if result.get("ok", false): _set_status("")
	_render_room()
	_feedback(result)


func _render_room() -> void:
	_render_basement_room()


func _render_basement_room() -> void:
	set_process(false)
	super._render_room()
	if session == null: return
	if CORE_STORY_TEXTS.is_english(TranslationServer.get_locale()) and session.stage() in ["F0_A","F0_B","F0_C","F0_D","F0_E","F1","F2"]:
		_location_label.text = CORE_STORY_TEXTS.location(_current_room,int(session.snapshot()["loop_state"]["day_index"])+1,TranslationServer.get_locale())
	if session.stage() == "D6":
		_clear_hotspots()
		_build_d6_inspection()
		call_deferred("_restore_world_focus")
		return
	if session.stage() in ["ENDING_CREDITS","POST_CREDITS"]:
		_clear_hotspots()
		_build_ending_credits()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "STAY_STORY":
		_clear_hotspots()
		_build_stay_story()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "STAY_CHARTER":
		_clear_hotspots()
		_build_stay_charter()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "REALITY_SURFACE":
		_clear_hotspots()
		_build_reality_surface()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "FIELD_NOTEBOOK":
		_clear_hotspots()
		_build_field_notebook()
		call_deferred("_restore_world_focus")
		return
	if session.stage() == "REALITY_WAKE":
		_clear_hotspots()
		_build_reality_wake()
		call_deferred("_restore_world_focus")
		return
	if session.stage() in ["D5", "DEMO_END", "E1_ENTRY", "LUCA_GUIDE", "LUCA_S2", "E2_INTRO", "E3_3", "E_HUB", "E3_1", "E3_2", "E3_4", "E3_5", "J4", "E3_4M", "E5", "E6", "F0_A", "F0_B", "F0_C", "F0_D", "F0_E", "F1", "F2", "F3", "EDC", "ENDING_SEQUENCE", "ENDING_BODY_PENDING"]:
		_clear_hotspots()
		if session.stage() == "D5":
			_add_d5_transition_art(_demo_stinger_seconds / 60.0 if SaveManager.get_build_flavor() == "demo" else (_d5_hold_seconds / FULL_D5_HOLD_SECONDS if _d5_hold_active else 0.0))
			if SaveManager.get_build_flavor() == "demo":
				_objective_label.text = BASEMENT_TEXTS.ui("d5_demo_objective", TranslationServer.get_locale())
				var beat := mini(5, int(_demo_stinger_seconds / 10.0))
				_notebook_surface_board(FRACTURE_SURFACE_TEXTS.demo_key(beat, _basement().d5_reaction()), _demo_stinger_beat(beat), Rect2(350, 300, 1200, 240))
				if _demo_stinger_save_failed:
					_action("D5_SAVE_RETRY", BASEMENT_TEXTS.ui("d5_save_retry", TranslationServer.get_locale()), Rect2(510,640,870,130), "d_fracture")
				else:
					set_process(true)
			else:
				if _d5_hold_active:
					_objective_label.text = "INPUT HOLD · CAMOUFLAGE FILTER SEPARATING" if TranslationServer.get_locale().begins_with("en") else "입력 고정 · 위장 필터 분리 중"
					_notebook_surface_board("HOLD_%d" % (0 if _d5_hold_seconds < 3.0 else 1 if _d5_hold_seconds < 7.0 else 2), _full_d5_hold_beat(), Rect2(350, 300, 1200, 260))
					set_process(true)
				else:
					_notebook_surface_board("D5_IDLE", BASEMENT_TEXTS.ui("d5_idle", TranslationServer.get_locale()), Rect2(350, 300, 1200, 240))
					_add_hotspot("D5_CONFIRM", "Release the handle and look around" if TranslationServer.get_locale().begins_with("en") else "손잡이를 놓고 드러난 공간을 확인한다", Rect2(510, 640, 870, 130), _begin_full_fracture_hold)
		elif session.stage() == "DEMO_END":
			_board_label(BASEMENT_TEXTS.ui("demo_end", TranslationServer.get_locale()), Rect2(330, 280, 1260, 280))
			_add_hotspot("RETURN_TITLE", BASEMENT_TEXTS.ui("return_title", TranslationServer.get_locale()), Rect2(520, 650, 830, 120), _return_to_title)
		elif session.stage() == "E1_ENTRY":
			_location_label.text = FRACTURE_COMMON_TEXTS.ui("e1_location", TranslationServer.get_locale())
			_objective_label.text = FRACTURE_COMMON_TEXTS.ui("e1_objective", TranslationServer.get_locale()) if not session.known("E1_complete") else FRACTURE_COMMON_TEXTS.ui("e1_objective_done", TranslationServer.get_locale())
			var seen: Array = session.snapshot()["meta_progress"]["knowledge_entries"].get("E1_objects_seen", [])
			for index in range(4):
				var id: String = ["bed", "window", "mirror", "call_cord"][index]
				var label: String = FRACTURE_COMMON_TEXTS.e1_object(id, TranslationServer.get_locale())
				_action("E1_" + id, label + (FRACTURE_COMMON_TEXTS.checked_suffix(TranslationServer.get_locale()) if id in seen else ""), Rect2(280 + (index % 2) * 730, 220 + (index / 2) * 190, 650, 140), "e1_inspect", id)
			_action("E1_EXIT", FRACTURE_COMMON_TEXTS.ui("e1_exit", TranslationServer.get_locale()), Rect2(510, 680, 870, 100), "move", "M1_CENTRAL_HALL")
		else:
			_build_fracture_intro()
			if session.stage() in ["E3_1", "E3_2", "E3_3", "E3_4", "E3_5"]:
				_localize_relationship_view()
			elif session.stage() in ["J4", "E3_4M", "E5", "E6"]:
				_localize_fracture_resolution_view()
		call_deferred("_restore_world_focus")
		return
	match _current_room:
		"M1_BASEMENT_ENTRY":
			_location_label.text = BASEMENT_TEXTS.location(_current_room, TranslationServer.get_locale())
			_action("DESCEND", BASEMENT_TEXTS.ui("descend", TranslationServer.get_locale()), Rect2(470, 310, 970, 260), "move", "B1_BASEMENT_STAIR", false)
			_replace_back("M1_GREAT_CLOCK", BASEMENT_TEXTS.ui("back_clock", TranslationServer.get_locale()))
		"B1_BASEMENT_STAIR":
			_location_label.text = BASEMENT_TEXTS.location(_current_room, TranslationServer.get_locale())
			_action("AXIS_ROOM", BASEMENT_TEXTS.ui("axis_room", TranslationServer.get_locale()), Rect2(470, 310, 970, 260), "move", "B1_AXIS_CHAMBER", false)
			_replace_back("M1_BASEMENT_ENTRY", BASEMENT_TEXTS.ui("back_entry", TranslationServer.get_locale()))
		"B1_AXIS_CHAMBER":
			_location_label.text = BASEMENT_TEXTS.location(_current_room, TranslationServer.get_locale())
			_build_axes()
			_replace_back("B1_BASEMENT_STAIR", BASEMENT_TEXTS.ui("back_stair", TranslationServer.get_locale()))
		"B1_STORAGE":
			_location_label.text = BASEMENT_TEXTS.location(_current_room, TranslationServer.get_locale())
			for index in range(4):
				var id: String = ["barrel", "cable", "filter", "drawing"][index]
				var label: String = BASEMENT_TEXTS.storage_name(id, TranslationServer.get_locale())
				_action("STORE_" + id, label, Rect2(310 + (index % 2) * 700, 220 + (index / 2) * 190, 600, 130), "d_storage", id)
				_queue_puzzle_surface(PUZZLE_NOTES.surface("D_STORAGE_" + id.to_upper()), label)
			_action("HEART_DOOR", BASEMENT_TEXTS.ui("heart_door", TranslationServer.get_locale()), Rect2(500, 680, 900, 120), "move", "B1_CLOCKWORK_HEART", false)
			_replace_back("B1_AXIS_CHAMBER", BASEMENT_TEXTS.ui("back_axes", TranslationServer.get_locale()))
		"B1_CLOCKWORK_HEART":
			_location_label.text = BASEMENT_TEXTS.location(_current_room, TranslationServer.get_locale())
			_build_heart()
			_replace_back("B1_STORAGE", BASEMENT_TEXTS.ui("back_storage", TranslationServer.get_locale()))
	call_deferred("_restore_world_focus")


func _build_d6_inspection() -> void:
	var saved_route := String(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("fracture_rest_route", ""))
	if not _d6_sleep_transition_active and not _d6_sleep_transition_failed and _d6_sleep_transition_route.is_empty() and saved_route in ["bedroom", "emergency_capsule"]:
		_d6_sleep_transition_route = "capsule" if saved_route == "emergency_capsule" else "bedroom"
		_d6_sleep_transition_active = true
		_d6_sleep_transition_seconds = 0.0
	if _d6_sleep_transition_active or _d6_sleep_transition_failed:
		_build_d6_sleep_transition()
		return
	var checkpoint := int(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("guidance_checkpoint", 0))
	_d6_guidance_seconds = maxf(_d6_guidance_seconds, float(checkpoint))
	set_process(checkpoint < 480 and not _d6_guidance_failed)
	var room := String(session.snapshot()["loop_state"]["location_id"])
	_objective_label.text = "달라진 통로를 조사하거나 쉴 곳을 선택한다"
	if Array(session.snapshot()["meta_progress"]["knowledge_entries"].get("D6_objects_seen", [])).size() >= 2:
		_objective_label.text = "복구 절차는 수면 중 실행됩니다 · 더 조사하거나 쉴 곳을 선택한다"
	if room == "H0_SERVICE_SPINE":
		_location_label.text = "드러난 서비스 통로"
		var ids := ["wall", "sign", "trace", "capsule"]
		var labels := ["벗겨진 벽지", "서비스 척추 표지", "사용인 진단 잔상", "비상 캡슐의 표면"]
		for index in range(4):
			_action("D6_INSPECT_" + ids[index], labels[index], Rect2(280 + index % 2 * 700, 210 + index / 2 * 180, 610, 130), "d6_inspect", ids[index])
		_action("D6_INSPECT_notebook", "수첩의 낙서와 배선을 겹쳐 본다", Rect2(280, 550, 1310, 70), "d6_inspect", "notebook")
		_action("D6_BEDROOM", "침실로 돌아간다", Rect2(280, 640, 610, 100), "d6_move", "M2_BEDROOM", false)
		_add_hotspot("D6_CAPSULE", "가까운 비상 캡슐에서 쉰다", Rect2(980, 640, 610, 100), _confirm_d6_rest.bind("capsule"))
	elif room == "M2_BEDROOM":
		_location_label.text = "주인공의 침실 · 파열 이후"
		_action("D6_RETURN", "통로를 조금 더 본다", Rect2(280, 420, 610, 130), "d6_move", "H0_SERVICE_SPINE", false)
		_add_hotspot("D6_BED", "침대에서 쉰다", Rect2(980, 420, 610, 130), _confirm_d6_rest.bind("bedroom"))
	else:
		_notebook_surface_board("D6_ENTRY", _d6_text(FRACTURE_SURFACE_TEXTS.ENTRY), Rect2(350, 280, 1200, 200))
		_action("D6_SPINE", "드러난 서비스 통로로", Rect2(510, 600, 870, 130), "d6_move", "H0_SERVICE_SPINE", false)
	if checkpoint >= 480:
		_objective_label.text = "휴식 경로: 침실 또는 비상 캡슐 · 조사는 계속할 수 있다"
	if _d6_guidance_failed:
		_add_hotspot("D6_GUIDANCE_RETRY", "안내 기록 저장 재시도", Rect2(510, 810, 870, 70), _retry_d6_guidance)
	_objective_label.text = _d6_text(_objective_label.text)
	_location_label.text = _d6_text(_location_label.text)
	for node in _hotspot_layer.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.text = _d6_text(node.text)
		if node is Button:
			node.add_theme_font_size_override("font_size", int(round(20 * _reading_text_scale)))
	if _reading_text_scale > 1.0:
		var expanded := {
			"D6_INSPECT_notebook": Rect2(280, 550, 1310, 90),
			"D6_BEDROOM": Rect2(280, 665, 610, 140),
			"D6_CAPSULE": Rect2(980, 665, 610, 140),
			"D6_GUIDANCE_RETRY": Rect2(510, 850, 870, 110)
		}
		for id in expanded:
			var control := _hotspot_layer.get_node_or_null(NodePath(id)) as Control
			if control != null: _place(control, expanded[id])


func _d6_text(source: String) -> String:
	return FRACTURE_REST_TEXTS.text(source, TranslationServer.get_locale())


func _d6_guidance_text(checkpoint: int) -> String:
	return FRACTURE_SURFACE_TEXTS.guidance_text(checkpoint, _basement().d5_reaction(), TranslationServer.get_locale())


func _localized_notebook_entry(entry: String) -> String:
	var locale := TranslationServer.get_locale()
	return _d6_text(CORE_STORY_TEXTS.feedback(FRACTURE_RESOLUTION_TEXTS.feedback(RELATIONSHIP_TEXTS.feedback(FRACTURE_COMMON_TEXTS.feedback(BASEMENT_TEXTS.feedback(super._localized_notebook_entry(entry), locale), locale), locale), locale), locale))


func _core_text(id: String) -> String:
	return CORE_STORY_TEXTS.text(id, TranslationServer.get_locale())


func _retry_d6_guidance() -> void:
	_d6_guidance_failed = false
	_tick_d6_guidance(0.0)


func _tick_d6_guidance(delta: float) -> void:
	if session.stage() != "D6" or _interaction_blocked() or _d6_guidance_failed: return
	if not _notebook_surface_allowed(): return
	var checkpoint := int(session.snapshot()["loop_state"]["event_local_states"].get("D6", {}).get("guidance_checkpoint", 0))
	if checkpoint >= 480: return
	_d6_guidance_seconds = minf(480.0, _d6_guidance_seconds + maxf(delta, 0.0))
	var next := 180 if checkpoint < 180 else (300 if checkpoint < 300 else 480)
	if _d6_guidance_seconds < next: return
	var result := session.act("d6_guidance", str(next))
	_d6_guidance_failed = not result.get("ok", false)
	_render_room()
	if _d6_guidance_failed:
		_set_status(_d6_text("안내 기록을 저장하지 못했다. 다시 시도하거나 조사를 계속할 수 있다."))
	else:
		_set_status(_d6_guidance_text(next))
		_queue_notebook_surface(FRACTURE_SURFACE_TEXTS.guidance_key(next, _basement().d5_reaction()), _d6_guidance_text(next))
		_notebook_surface_allowed()


func _confirm_d6_rest(route: String) -> void:
	if not _notebook_surface_allowed(): return
	var content := FRACTURE_REST_TEXTS.confirmation(route, TranslationServer.get_locale())
	_show_recorded_choice(content.title, content.body, [
		{"label": content.labels[0], "action": _close_modal},
		{"label": content.labels[1], "action": _start_d6_rest.bind(route)},
	], MODAL_NOTES.options("FRACTURE_REST_" + route.to_upper()))


func _start_d6_rest(route: String) -> void:
	_close_modal()
	var result := session.act("d6_rest", route)
	if not result.get("ok", false):
		_feedback(result)
		return
	_begin_d6_sleep_transition(route)


func _begin_d6_sleep_transition(route: String) -> void:
	_d6_sleep_transition_route = "capsule" if route == "capsule" or route == "emergency_capsule" else "bedroom"
	_d6_sleep_transition_seconds = 0.0
	_d6_sleep_transition_failed = false
	_d6_sleep_transition_active = true
	set_process(true)
	_render_room()


func _build_d6_sleep_transition() -> void:
	_location_label.text = _d6_text("수면 전환 · 비상 캡슐" if _d6_sleep_transition_route == "capsule" else "수면 전환 · 침실")
	_objective_label.text = _d6_text("눈을 감은 뒤의 상태를 확인한다")
	var shade := ColorRect.new()
	shade.name = "D6SleepShade"
	shade.color = Color(0.012, 0.015, 0.024, 0.30 + 0.55 * clampf(_d6_sleep_transition_seconds / D6_SLEEP_TRANSITION_SECONDS, 0.0, 1.0))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(shade)
	_place(shade, Rect2(0, 90, 1920, 990))
	if _d6_sleep_transition_failed:
		_board_label(_d6_text("수면 전환을 저장하지 못했습니다. 현재 파열 상태와 선택한 경로는 유지됩니다."), Rect2(300, 280, 1320, 260))
		_add_hotspot("D6_SLEEP_RETRY", _d6_text("수면 전환 저장 재시도"), Rect2(510, 650, 900, 130), _retry_d6_sleep_transition)
		return
	var presentation: Dictionary = FRACTURE_REST_TEXTS.sleep_transition(_d6_sleep_transition_route, _d6_sleep_transition_seconds, TranslationServer.get_locale())
	var beat := 0 if _d6_sleep_transition_seconds < 2.0 else 1 if _d6_sleep_transition_seconds < 4.0 else 2
	_notebook_surface_board("SLEEP_%s_%d" % [_d6_sleep_transition_route.to_upper(), beat], String(presentation["body"]), Rect2(300, 230, 1320, 480))
	set_process(true)


func _retry_d6_sleep_transition() -> void:
	if not _notebook_surface_allowed(): return
	_d6_sleep_transition_seconds = 0.0
	_d6_sleep_transition_failed = false
	_d6_sleep_transition_active = true
	set_process(true)
	_render_room()


func _tick_d6_sleep_transition(delta: float) -> void:
	if not _d6_sleep_transition_active or _interaction_blocked() or session.stage() != "D6":
		return
	if not _notebook_surface_allowed(): return
	var previous_beat := 0 if _d6_sleep_transition_seconds < 2.0 else (1 if _d6_sleep_transition_seconds < 4.0 else 2)
	_d6_sleep_transition_seconds = minf(D6_SLEEP_TRANSITION_SECONDS, _d6_sleep_transition_seconds + maxf(delta, 0.0))
	if _d6_sleep_transition_seconds >= D6_SLEEP_TRANSITION_SECONDS:
		_d6_sleep_transition_active = false
		set_process(false)
		var result := session.sleep()
		_d6_sleep_transition_failed = not result.get("ok", false)
		if not _d6_sleep_transition_failed:
			_d6_sleep_transition_route = ""
		_render_room()
		_feedback(result)
		return
	var current_beat := 0 if _d6_sleep_transition_seconds < 2.0 else (1 if _d6_sleep_transition_seconds < 4.0 else 2)
	if current_beat != previous_beat:
		_render_room()


func _present_dialogue_line() -> void:
	super._present_dialogue_line()
	_refresh_d5_focus_controls()


func _refresh_d5_focus_controls() -> void:
	var panel := _dialogue_layer.get_node_or_null("D5Focus") as Control
	var allowed: bool = session != null and session.stage() == "D5" and SaveManager.get_build_flavor() == "full" and _dialogue_active and bool(_dialogue_lines[_dialogue_index].get("d5_focus_allowed", false))
	if not allowed:
		if panel != null: panel.visible = false
		return
	var owners := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
	if panel == null:
		panel = Control.new()
		panel.name = "D5Focus"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dialogue_layer.add_child(panel)
		for index in range(5):
			var button := _make_button("", Rect2(250 + index * 290, 330, 270, 190), _select_d5_focus.bind(owners[index]))
			button.name = owners[index]
			panel.add_child(button)
	panel.visible = true
	var english := TranslationServer.get_locale().begins_with("en")
	var names := ["Edgar", "Mara 1", "Luca", "Iris", "Mara 2"] if english else ["에드가", "마라 1", "루카", "이리스", "마라 2"]
	var patterns := ["| |", "/ /", "|| . ||", "( * )", "[ [ ] ]"]
	var selected := String(session.snapshot()["loop_state"]["event_local_states"].get("D5", {}).get("D5_FOCUS_OWNER", ""))
	_update_d5_transition_art(1.0)
	for index in range(5):
		var button := panel.get_node(owners[index]) as Button
		button.text = names[index] + "\n" + patterns[index] + ("\n" + ("Looking" if english else "바라보는 중") if selected == owners[index] else "")
		button.add_theme_font_size_override("font_size", int(round(18 * _reading_text_scale)))


func _select_d5_focus(owner: String) -> void:
	if not _dialogue_active or not bool(_dialogue_lines[_dialogue_index].get("d5_focus_allowed", false)) or _modal_active:
		return
	var result := session.act("d5_focus", owner)
	if result.get("ok", false):
		_set_status("")
		_refresh_d5_focus_controls()
	else:
		_set_status("Could not save the viewing choice. Try again or continue reading." if TranslationServer.get_locale().begins_with("en") else "시선 기록을 저장하지 못했다. 다시 선택하거나 계속 읽을 수 있다.")


func _show_full_fracture_transition() -> void:
	if _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	if not _notebook_surface_allowed(): return
	_update_d5_transition_art(1.0)
	_show_dialogue(preload("res://scripts/ui/fracture_transition_texts.gd").lines(TranslationServer.get_locale(), _basement().d5_reaction()), _do.bind("d_fracture", null, false))


func _add_d5_transition_art(progress: float) -> void:
	var art := Control.new()
	art.set_script(D5_TRANSITION_ART)
	art.name = "D5TransitionArt"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(art)
	_hotspot_layer.move_child(art, 0)
	art.present(progress, _d5_visual_owner(), _d5_motion_mode())


func _update_d5_transition_art(progress: float) -> void:
	var art = _hotspot_layer.get_node_or_null("D5TransitionArt")
	if art != null:
		art.present(progress, _d5_visual_owner(), String(art.motion_mode))


func _d5_visual_owner() -> String:
	var local: Dictionary = session.snapshot()["loop_state"]["event_local_states"].get("D5", {})
	var selected := String(local.get("D5_FOCUS_OWNER", ""))
	return selected if not selected.is_empty() else String(_basement().d5_reaction().get("owner", ""))


func _d5_motion_mode() -> String:
	return String(AccessibilityProfileStore.new().load_profile().get("profile", {}).get("motion_mode", "standard"))


func _begin_full_fracture_hold() -> void:
	if _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	if not _notebook_surface_allowed(): return
	_d5_hold_seconds = 0.0
	_d5_hold_active = true
	_set_status("")
	_render_room()


func _full_d5_hold_beat() -> String:
	var source := FULL_D5_HOLD_EN if TranslationServer.get_locale().begins_with("en") else FULL_D5_HOLD_KO
	var index := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	return source[index]


func _tick_full_d5_hold(delta: float) -> void:
	if not _d5_hold_active or _interaction_blocked() or session.stage() != "D5" or SaveManager.get_build_flavor() != "full":
		return
	if not _notebook_surface_allowed(): return
	var previous_beat := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	_d5_hold_seconds = minf(FULL_D5_HOLD_SECONDS, _d5_hold_seconds + maxf(delta, 0.0))
	_update_d5_transition_art(_d5_hold_seconds / FULL_D5_HOLD_SECONDS)
	if _d5_hold_seconds >= FULL_D5_HOLD_SECONDS:
		_d5_hold_active = false
		set_process(false)
		_show_full_fracture_transition()
		return
	var current_beat := 0 if _d5_hold_seconds < 3.0 else (1 if _d5_hold_seconds < 7.0 else 2)
	if current_beat != previous_beat:
		_render_room()


func _demo_stinger_beat(index: int) -> String:
	return FRACTURE_SURFACE_TEXTS.demo_text(index, _basement().d5_reaction(), TranslationServer.get_locale())


func _build_fracture_intro() -> void:
	match session.stage():
		"EDC":
			_build_ending_decision()
			return
		"ENDING_SEQUENCE":
			_build_ending_entry()
			return
		"ENDING_BODY_PENDING":
			_objective_label.text = ENDING_TEXTS.text("unavailable_objective", TranslationServer.get_locale())
			var ending: Dictionary = session.snapshot()["ending_run"]
			_board_label(ENDING_TEXTS.unavailable(String(ending.get("current_node_id", "")), TranslationServer.get_locale()), Rect2(350,250,1200,330))
			_add_hotspot("ENDING_UNAVAILABLE_TITLE", ENDING_TEXTS.text("unavailable_return", TranslationServer.get_locale()), Rect2(520,650,880,110), _return_to_title)
			return
		"F3":
			_build_final_inspection()
			return
		"F2":
			_build_confrontation()
			return
		"F1":
			_build_father_record()
			return
		"F0_E":
			_build_core_self()
			return
		"F0_D":
			_build_core_roles()
			return
		"F0_C":
			_build_core_overlay()
			return
		"F0_B":
			_build_core_samples()
			return
		"F0_A":
			_build_core_room_network()
			return
		"E6":
			_build_core_approach()
			return
		"E5":
			_build_last_evening()
			return
		"J4", "E3_4M":
			_build_journal_four()
		"E3_5":
			_build_mara2_relationship()
		"E3_4":
			_build_edgar_relationship()
		"E3_3":
			_build_luca_relationship()
		"E3_2":
			_build_iris_relationship()
		"E3_1":
			_build_mara1_relationship()
		"LUCA_GUIDE":
			_objective_label.text = FRACTURE_COMMON_TEXTS.ui("luca_guide_objective", TranslationServer.get_locale())
			_notebook_surface_board("LUCA_GUIDE", FRACTURE_COMMON_TEXTS.ui("luca_guide_board", TranslationServer.get_locale()), Rect2(340, 220, 1250, 220))
			_action("LUCA_GUIDE", FRACTURE_COMMON_TEXTS.ui("luca_guide_action", TranslationServer.get_locale()), Rect2(410, 520, 1100, 120), "move", "M1_KITCHEN")
			_action("E1_RETURN", FRACTURE_COMMON_TEXTS.ui("e1_return", TranslationServer.get_locale()), Rect2(510, 720, 850, 90), "move", "M2_BEDROOM", false)
		"LUCA_S2":
			_objective_label.text = FRACTURE_COMMON_TEXTS.ui("luca_s2_objective", TranslationServer.get_locale())
			_notebook_surface_board("LUCA_S2", FRACTURE_COMMON_TEXTS.ui("luca_s2_board", TranslationServer.get_locale()), Rect2(270, 190, 1380, 230))
			_queue_notebook_surface("OPTIONS_LUCA", FRACTURE_SURFACE_TEXTS.choice_text("LUCA", TranslationServer.get_locale()))
			for index in range(3):
				_notebook_world_choice("LUCA", index, "LUCA_S2_%d" % index, Rect2(400, 470 + index * 125, 1100, 100), "e2_luca", ["ask", "hold", "withdraw"][index])
		"E2_INTRO":
			_objective_label.text = FRACTURE_COMMON_TEXTS.ui("e2_objective", TranslationServer.get_locale())
			_action("E2_REPORT", FRACTURE_COMMON_TEXTS.ui("e2_report", TranslationServer.get_locale()), Rect2(380, 180, 1170, 100), "e2_report")
			if session.known("E2_report_seen"):
				_queue_notebook_surface("OPTIONS_E2", FRACTURE_SURFACE_TEXTS.choice_text("E2", TranslationServer.get_locale()))
				for index in range(3):
					_notebook_world_choice("E2", index, "E2_Q_%d" % index, Rect2(380, 320 + index * 110, 1170, 85), "e2_question", ["house", "body", "memory"][index])
				_action("E2_FINISH", FRACTURE_COMMON_TEXTS.ui("e2_finish", TranslationServer.get_locale()), Rect2(380, 710, 1170, 100), "e2_finish")
		"E_HUB":
			_add_hotspot("J4_CONFIRM", FRACTURE_COMMON_TEXTS.ui("hub_finish", TranslationServer.get_locale()), Rect2(570, 885, 800, 60), _show_j4_confirmation)
			_objective_label.text = FRACTURE_COMMON_TEXTS.ui("hub_objective", TranslationServer.get_locale())
			_notebook_surface_board("E_HUB", FRACTURE_COMMON_TEXTS.ui("hub_board", TranslationServer.get_locale()), Rect2(330, 130, 1260, 390))
			_action("MARA1_ENTRY", FRACTURE_COMMON_TEXTS.ui("hub_mara1", TranslationServer.get_locale()), Rect2(330, 550, 620, 90), "move", "M1_SERVICE_HALL", false)
			_action("IRIS_ENTRY", FRACTURE_COMMON_TEXTS.ui("hub_iris", TranslationServer.get_locale()), Rect2(990, 550, 620, 90), "move", "M1_GREENHOUSE", false)
			_action("LUCA_ENTRY", FRACTURE_COMMON_TEXTS.ui("hub_luca", TranslationServer.get_locale()), Rect2(330, 670, 620, 90), "move", "M1_KITCHEN", false)
			_action("EDGAR_ENTRY", FRACTURE_COMMON_TEXTS.ui("hub_edgar", TranslationServer.get_locale()), Rect2(990, 670, 620, 90), "move", "M1_GREAT_CLOCK", false)
			_action("MARA2_ENTRY", FRACTURE_COMMON_TEXTS.ui("hub_mara2", TranslationServer.get_locale()), Rect2(330, 790, 620, 80), "move", "M1_NORTH_ARCHIVE_HALL", false)
			_action("E1_RETURN", FRACTURE_COMMON_TEXTS.ui("e1_return", TranslationServer.get_locale()), Rect2(990, 790, 620, 80), "move", "M2_BEDROOM", false)


func _relationship_text(source: String) -> String:
	return RELATIONSHIP_TEXTS.text(source, TranslationServer.get_locale())


func _localize_relationship_view() -> void:
	_location_label.text = _relationship_text(_location_label.text)
	_objective_label.text = _relationship_text(_objective_label.text)
	for node in _hotspot_layer.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.text = _relationship_text(String(node.text))


func _relationship_actions(actions: Array) -> Array:
	var localized: Array = []
	for item in actions:
		var copy: Dictionary = item.duplicate()
		copy["label"] = _relationship_text(String(item.get("label", "")))
		localized.append(copy)
	return localized


func _show_relationship_modal(title: String, body: String, actions: Array) -> void:
	_show_modal(_relationship_text(title), _relationship_text(body), _relationship_actions(actions))


func _show_relationship_choice(key: String, title: String, body: String, actions: Array) -> void:
	_show_recorded_choice(_relationship_text(title), _relationship_text(body), _relationship_actions(actions), MODAL_NOTES.options(key))


func _fracture_resolution_text(source: String) -> String:
	return FRACTURE_RESOLUTION_TEXTS.text(source, TranslationServer.get_locale())


func _localize_fracture_resolution_view() -> void:
	_location_label.text = _fracture_resolution_text(_location_label.text)
	_objective_label.text = _fracture_resolution_text(_objective_label.text)
	for node in _hotspot_layer.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.text = _fracture_resolution_text(String(node.text))


func _fracture_resolution_actions(actions: Array) -> Array:
	var localized: Array = []
	for item in actions:
		var copy: Dictionary = item.duplicate()
		copy["label"] = _fracture_resolution_text(String(item.get("label", "")))
		localized.append(copy)
	return localized


func _show_fracture_resolution_modal(title: String, body: String, actions: Array) -> void:
	_show_modal(_fracture_resolution_text(title), _fracture_resolution_text(body), _fracture_resolution_actions(actions))


func _build_mara1_relationship() -> void:
	_objective_label.text = "마라 1 · 끊긴 배선과 삭제 기록"
	if _current_room == "M1_SERVICE_HALL":
		_location_label.text = "사용인 작업 회랑"
		_mara1_board("ENTRY", Rect2(300, 230, 1300, 220))
		_action("WIRING_ENTER", "배선실로", Rect2(450, 520, 1000, 110), "move", "M1_WIRING_ROOM", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "배선실"
	var rules = BasementSession.MARA1_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_1_complete"):
		_mara1_board("COMPLETE", Rect2(300, 260, 1300, 250))
	elif not local["panel"]:
		_action("MARA_PANEL", "패널과 세 단자의 신호를 조사한다", Rect2(300, 300, 1300, 220), "mara1_panel")
	elif not local["bridge"]:
		for index in range(3):
			var x := 210 + index * 520
			var clue: String = MARA1_NOTES.SCREEN["TERMINAL_%d" % index]
			_board_label(clue + ("\n출처 확인함" if local["sources"].has(str(index)) else ""), Rect2(x, 190, 490, 110))
			_queue_notebook_content(MARA1_NOTES.PREFIX + "SCREEN_TERMINAL_%d" % index, _relationship_text(clue))
			for source_index in range(3):
				var source: String = rules.SOURCES[source_index]
				_action("MARA_SOURCE_%d_%d" % [index, source_index], source, Rect2(x, 330 + source_index * 105, 490, 85), "mara1_source", [index, source])
		_action("MARA_BRIDGE", "스패너로 가짜 브리지를 해제한다", Rect2(340, 680, 1220, 100), "mara1_bridge")
	elif not local["restored"]:
		_board_label(MARA1_NOTES.SCREEN.ORDER + "\n선택한 파편 수: %d / 3" % local["order"].size(), Rect2(290, 150, 1340, 120))
		_queue_notebook_content(MARA1_NOTES.PREFIX + "SCREEN_ORDER", _relationship_text(MARA1_NOTES.SCREEN.ORDER))
		for index in range(3):
			var id: String = ["command", "consent", "failure"][index]
			_action("MARA_LOG_" + id, rules.LOGS[id], Rect2(220 + index * 520, 310, 490, 260), "mara1_log", id)
			_queue_notebook_content(MARA1_NOTES.PREFIX + "SCREEN_LOG_" + id.to_upper(), _relationship_text(rules.LOGS[id]))
		_action("MARA_CLEAR", "파편을 다시 펼친다", Rect2(260, 640, 650, 100), "mara1_clear")
		_action("MARA_RESTORE", "기록 순서를 검증한다", Rect2(980, 640, 650, 100), "mara1_restore")
	else:
		_action("MARA_CONFESS", "마라 1의 이야기를 듣는다", Rect2(330, 250, 1250, 150), "mara1_confess")
		if local["confessed"]:
			_add_hotspot("MARA_CHOICE", "기록 보존 방식을 정한다", Rect2(330, 520, 1250, 150), _show_mara1_choice)
	_replace_back("M1_SERVICE_HALL", "작업 회랑으로 · 진행 보존")


func _mara1_board(key: String, rect: Rect2) -> void:
	var text := _relationship_text(MARA1_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(MARA1_NOTES.PREFIX + "SCREEN_" + key, text)


func _show_mara1_choice() -> void:
	if not _notebook_surface_allowed(): return
	_show_relationship_choice("MARA1", "기록을 어떻게 남길까", "두 방식 모두 사건과 명령자·수행자의 책임을 보존한다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "책임자와 원문을 그대로 남긴다", "action": _modal_act.bind("mara1_choose", "original_attribution")},
		{"label": "피해자 식별 정보만 보호한다", "action": _modal_act.bind("mara1_choose", "protected_identifiers")},
	])


func _build_iris_relationship() -> void:
	_objective_label.text = "이리스 · 계절 센서와 빼앗긴 전력"
	if _current_room == "M1_GREENHOUSE":
		_location_label.text = "온실"
		_iris_board("ENTRY", Rect2(300, 210, 1300, 230))
		_action("IRIS_CONTROL", "계절 제어실로", Rect2(400, 530, 1100, 130), "move", "H0_CLIMATE_CONTROL", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "계절 제어실"
	var rules = BasementSession.IRIS_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_2_complete"):
		_iris_board("COMPLETE", Rect2(300, 250, 1300, 250))
	elif not local["panel"]:
		_action("IRIS_PANEL", "세 계기와 입력 출처를 조사한다", Rect2(300, 260, 1300, 240), "iris_panel")
	elif local["channels"].size() < 9:
		for row in range(3):
			var gauge: String = ["temperature", "humidity", "light"][row]
			_board_label(["온도", "습도", "광량"][row], Rect2(130, 200 + row * 170, 140, 100))
			for index in range(3):
				var clue: String = rules.CLUES[rules.CHANNELS[gauge][index]]
				var key := "%s_%d" % [gauge, index]
				_add_hotspot("IRIS_CHANNEL_" + key, clue + ("\n확인함" if local["channels"].has(key) else ""), Rect2(280 + index * 510, 200 + row * 170, 470, 135), _show_iris_channel.bind(gauge, index))
				_queue_notebook_content(IRIS_NOTES.PREFIX + "SCREEN_CHANNEL_" + key.to_upper(), _relationship_text(clue))
	elif not local["power"]:
		_board_label(IRIS_NOTES.SCREEN.ORDER + " 선택 %d / 5" % local["order"].size(), Rect2(270, 130, 1380, 90))
		_queue_notebook_content(IRIS_NOTES.PREFIX + "SCREEN_ORDER", _relationship_text(IRIS_NOTES.SCREEN.ORDER))
		for index in range(5):
			var id: String = ["audit", "warning", "conversion", "loss", "command"][index]
			_action("IRIS_LOG_" + id, rules.LOGS[id], Rect2(270, 250 + index * 90, 1380, 80), "iris_log", id)
			_queue_notebook_content(IRIS_NOTES.PREFIX + "SCREEN_LOG_" + id.to_upper(), _relationship_text(rules.LOGS[id]))
		_action("IRIS_CLEAR", "다시 펼친다", Rect2(280, 740, 640, 85), "iris_clear")
		_action("IRIS_RESTORE", "순서 검증", Rect2(1000, 740, 640, 85), "iris_restore")
	elif not local["mismatch"]:
		_iris_board("AUDIT", Rect2(320, 180, 1250, 250))
		_action("IRIS_AUDIT_WRONG", "경고가 승인으로 바뀌었다", Rect2(330, 510, 1250, 95), "iris_audit", "warning_is_consent")
		_action("IRIS_AUDIT", "자격 소유자를 실행자로 기록했다", Rect2(330, 650, 1250, 95), "iris_audit", "credential_owner_not_executor")
	else:
		_action("IRIS_CONFRONT", "이리스의 이야기를 듣는다", Rect2(330, 280, 1250, 140), "iris_confront")
		if local["confronted"]:
			_add_hotspot("IRIS_CHOICE", "기록과 현재 온실을 어떻게 둘까", Rect2(330, 520, 1250, 140), _show_iris_choice)
	_replace_back("M1_GREENHOUSE", "온실로 · 진행 보존")


func _iris_board(key: String, rect: Rect2) -> void:
	var text := _relationship_text(IRIS_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(IRIS_NOTES.PREFIX + "SCREEN_" + key, text)


func _show_iris_channel(gauge: String, index: int) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": IRIS_NOTES.CHANNEL_LABELS[0], "action": _close_modal}]
	for source_index in range(BasementSession.IRIS_RELATIONSHIP.SOURCES.size()):
		var source: String = BasementSession.IRIS_RELATIONSHIP.SOURCES[source_index]
		actions.append({"label": IRIS_NOTES.CHANNEL_LABELS[source_index + 1], "action": _modal_act.bind("iris_source", [gauge, index, source])})
	if not _notebook_surface_enabled():
		_show_relationship_modal(IRIS_NOTES.CHANNEL_TITLE, IRIS_NOTES.CHANNEL_BODY, actions)
		return
	_show_recorded_choice(_relationship_text(IRIS_NOTES.CHANNEL_TITLE), _relationship_text(IRIS_NOTES.CHANNEL_BODY), _relationship_actions(actions), IRIS_NOTES.channel_options())


func _show_iris_choice() -> void:
	if not _notebook_surface_allowed(): return
	_show_relationship_choice("IRIS", "지금의 온실", "두 방식 모두 외부값과 책임 기록을 보존한다. 현재 보이는 계절 연출을 유지할지 정한다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "불완전한 외부값과 책임 로그를 그대로 남긴다", "action": _modal_act.bind("iris_choose", "external_truth")},
		{"label": "외부값은 보존하고 현재 온실 연출은 유지한다", "action": _modal_act.bind("iris_choose", "shelter_projection")},
	])


func _build_luca_relationship() -> void:
	_objective_label.text = "루카 · 생명 유지 장치와 유예된 기상"
	if _current_room == "M1_KITCHEN":
		_location_label.text = "주방"
		_luca_board("ENTRY", Rect2(300, 240, 1300, 220))
		_action("LIFE_SUPPORT_ENTER", "생명 유지실로", Rect2(400, 530, 1100, 130), "move", "H0_LIFE_SUPPORT", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "생명 유지실"
	var rules = BasementSession.LUCA_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_3_complete"):
		_luca_board("COMPLETE", Rect2(300, 260, 1300, 240))
	elif not local["panel"]:
		_action("LUCA_PANEL", "배관의 맥박과 진단 패널 조사", Rect2(300, 300, 1300, 220), "luca_panel")
	elif not local["matched"]:
		for index in range(3):
			var id: String = ["decoration", "main", "aux"][index]
			var label: String = LUCA_NOTES.SCREEN["PIPE_" + id.to_upper()]
			_action("LUCA_PIPE_" + id, label + (" · 연결 선택" if id in local["pipes"] else ""), Rect2(320, 240 + index * 135, 1300, 105), "luca_pipe", id)
			_queue_notebook_content(LUCA_NOTES.PREFIX + "SCREEN_PIPE_" + id.to_upper(), _relationship_text(label))
		_action("LUCA_MATCH", "선택한 두 관을 진단 패널에 연결", Rect2(320, 690, 1300, 100), "luca_match")
	elif not local["stable"]:
		_luca_board("CYCLE", Rect2(250, 140, 1420, 130))
		for index in range(4):
			var phase: String = local["slots"].get(str(index), "")
			_add_hotspot("LUCA_SLOT_%d" % index, "슬롯 %d\n%s" % [index + 1, rules.PHASE_LABELS.get(phase, "미배치")], Rect2(260 + index * 360, 350, 320, 150), _show_luca_slot.bind(index))
		_action("LUCA_PREVIEW", "전체 주기 미리 확인", Rect2(300, 610, 610, 110), "luca_preview")
		_action("LUCA_RUN", "주기 실행과 안전 밸브 확인", Rect2(1000, 610, 610, 110), "luca_run")
	elif local["logs"].size() < 3:
		for index in range(3):
			var id: String = ["preservation", "approval", "blank"][index]
			_action("LUCA_LOG_" + id, rules.LOGS[id] + (" · 확인함" if id in local["logs"] else ""), Rect2(300, 210 + index * 180, 1300, 140), "luca_log", id)
			_queue_notebook_content(LUCA_NOTES.PREFIX + "SCREEN_LOG_" + id.to_upper(), _relationship_text(rules.LOGS[id]))
	else:
		_action("LUCA_CONFESS", "루카의 이야기를 듣는다", Rect2(330, 270, 1250, 150), "luca_confess")
		if local["confessed"]: _add_hotspot("LUCA_CHOICE", "위험 기록을 읽을 순서를 정한다", Rect2(330, 510, 1250, 150), _show_luca_choice)
	_replace_back("M1_KITCHEN", "주방으로 · 진행 보존")


func _luca_board(key: String, rect: Rect2) -> void:
	var text := _relationship_text(LUCA_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(LUCA_NOTES.PREFIX + "SCREEN_" + key, text)


func _show_luca_slot(index: int) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": LUCA_NOTES.SLOT_LABELS[0], "action": _close_modal}]
	for phase_index in range(BasementSession.LUCA_RELATIONSHIP.PHASES.size()):
		var phase: String = BasementSession.LUCA_RELATIONSHIP.PHASES[phase_index]
		actions.append({"label": LUCA_NOTES.SLOT_LABELS[phase_index + 1], "action": _modal_act.bind("luca_slot", [index, phase])})
	if not _notebook_surface_enabled():
		_show_relationship_modal(LUCA_NOTES.SLOT_TITLE, LUCA_NOTES.SLOT_BODY, actions)
		return
	_show_recorded_choice(_relationship_text(LUCA_NOTES.SLOT_TITLE), _relationship_text(LUCA_NOTES.SLOT_BODY), _relationship_actions(actions), LUCA_NOTES.slot_options())


func _show_luca_choice() -> void:
	if not _notebook_surface_allowed(): return
	_show_relationship_choice("LUCA", "확인할 순서", "두 선택 모두 같은 위험 기록을 읽는다. 지금 생존한다는 사실이 기상 안전을 보장하지는 않는다.", [
		{"label": "아직 결정하지 않는다", "action": _close_modal},
		{"label": "위험 수치를 먼저 전부 읽는다", "action": _modal_act.bind("luca_choose", "full_disclosure")},
		{"label": "장치를 안정시킨 뒤 기록을 함께 읽는다", "action": _modal_act.bind("luca_choose", "stabilize_first")},
	])


func _build_edgar_relationship() -> void:
	_objective_label.text = "에드가 · 보안 코어와 선택 권한"
	if _current_room == "M1_GREAT_CLOCK":
		_location_label.text = "대시계"
		_edgar_board("ENTRY", Rect2(300, 240, 1300, 210))
		_action("EDGAR_MACHINE", "보안 기계실로", Rect2(400, 530, 1100, 130), "move", "H0_CLOCK_MACHINE", false)
		_replace_back("M1_CENTRAL_HALL", "중앙홀로")
		return
	_location_label.text = "대시계 기계실"
	var rules = BasementSession.EDGAR_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if session.known("E3_4_complete"):
		_edgar_board("COMPLETE", Rect2(300, 270, 1300, 220))
	elif not local["audit"]:
		_board_label("네 권한 변경 이력을 선행 사건 순서로 놓는다. 선택 %d / 4" % local["order"].size(), Rect2(300, 120, 1300, 90))
		_queue_notebook_content(EDGAR_NOTES.PREFIX + "SCREEN_ORDER", _relationship_text(EDGAR_NOTES.SCREEN.ORDER))
		for index in range(4):
			var id: String = ["vacancy", "protocol", "extension", "consent"][index]
			_action("EDGAR_LOG_" + id, rules.LOGS[id], Rect2(300, 240 + index * 105, 1300, 95), "edgar_log", id)
			_queue_notebook_content(EDGAR_NOTES.PREFIX + "SCREEN_LOG_" + id.to_upper(), _relationship_text(rules.LOGS[id]))
		_action("EDGAR_CLEAR", "다시 펼친다", Rect2(300, 720, 600, 90), "edgar_clear")
		_action("EDGAR_AUDIT", "이력 순서를 확인한다", Rect2(1000, 720, 600, 90), "edgar_audit")
	elif not local["validated"]:
		var functions: Array = rules.OWNERS.keys()
		for index in range(4):
			var function: String = functions[index]
			var owner: String = local["owners"].get(function, "미배치")
			_add_hotspot("EDGAR_OWNER_" + function, rules.CLUES[function] + "\n현재 토큰: " + owner, Rect2(300, 180 + index * 125, 1300, 105), _show_edgar_owner.bind(function))
			_queue_notebook_content(EDGAR_NOTES.PREFIX + "SCREEN_FUNCTION_" + function, _relationship_text(rules.CLUES[function]))
		_action("EDGAR_VALIDATE", "현재 권한 배치 검증", Rect2(300, 720, 1300, 100), "edgar_validate")
	else:
		_action("EDGAR_CONFESS", "명령과 에드가의 결정을 대조한다", Rect2(300, 270, 1300, 150), "edgar_confess")
		if local["confessed"]: _add_hotspot("EDGAR_CHOICE", "책임을 남길 방식을 정한다", Rect2(300, 540, 1300, 150), _show_edgar_choice)
	_replace_back("M1_GREAT_CLOCK", "대시계로 · 진행 보존")


func _edgar_board(key: String, rect: Rect2) -> void:
	var text := _relationship_text(EDGAR_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(EDGAR_NOTES.PREFIX + "SCREEN_" + key, text)


func _show_edgar_owner(function: String) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": EDGAR_NOTES.OWNER_LABELS[0], "action": _close_modal}]
	for owner in BasementSession.EDGAR_RELATIONSHIP.OWNERS.values():
		actions.append({"label": owner, "action": _modal_act.bind("edgar_owner", [function, owner])})
	var body: String = BasementSession.EDGAR_RELATIONSHIP.CLUES[function]
	if not _notebook_surface_enabled():
		_show_relationship_modal(function, body, actions)
		return
	_show_recorded_choice(_relationship_text(function), _relationship_text(body), _relationship_actions(actions), EDGAR_NOTES.options("OWNER_" + function))


func _show_edgar_choice() -> void:
	if not _notebook_surface_allowed(): return
	_show_relationship_choice("EDGAR", "책임의 기록", "두 선택 모두 현재 선택권은 주인공에게 반환된다. 용서 여부나 엔딩을 결정하는 선택이 아니다.", [
		{"label": "기록을 다시 읽는다", "action": _close_modal},
		{"label": "당신이 한 결정도 공식 기록에 남겨요.", "action": _modal_act.bind("edgar_choose", "responsibility_recorded")},
		{"label": "기록보다 먼저, 내 권한을 내게 직접 돌려줘요.", "action": _modal_act.bind("edgar_choose", "authority_returned")},
	])


func _build_mara2_relationship() -> void:
	_objective_label.text = "마라 2 · 원본과 분산된 주석"
	var rules = BasementSession.MARA2_RELATIONSHIP
	var local: Dictionary = rules.progress(session.snapshot())
	if _current_room in ["M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY"]:
		_location_label.text = "북쪽 기록 회랑" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "색분해실 입구"
		_mara2_board("ENTRY", Rect2(300, 240, 1300, 230))
		_action("MARA2_FORWARD", "안쪽으로", Rect2(400, 540, 1100, 120), "move", "M1_COLOR_ROOM_ENTRY" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "H0_COLOR_SEPARATION", false)
		_replace_back("M1_CENTRAL_HALL" if _current_room == "M1_NORTH_ARCHIVE_HALL" else "M1_NORTH_ARCHIVE_HALL", "회랑으로")
		return
	if _current_room == "H0_COLOR_SEPARATION":
		_location_label.text = "색분해실"
		if local["sources"].size() < 15:
			for column in range(3):
				var portrait: String = ["A", "B", "C"][column]
				_board_label("초상화 " + portrait, Rect2(230 + column * 510, 150, 470, 70))
				for index in range(5):
					var owner: String = rules.OWNERS[(index + column) % 5]
					_add_hotspot("MARA2_SOURCE_" + portrait + owner, rules.SIGNS[owner] + (" · 확인" if local["sources"].has(portrait + "_" + owner) else ""), Rect2(230 + column * 510, 260 + index * 105, 470, 90), _show_mara2_source.bind(portrait, owner))
					_queue_notebook_content(MARA2_NOTES.PREFIX + "SCREEN_SOURCE_" + portrait + "_" + owner, _relationship_text(rules.SIGNS[owner]))
		elif not local["overlay"]:
			for index in range(3):
				var id: String = ["A", "B", "C"][index]
				var x := 230 + index * 510
				var text := _relationship_text(MARA2_NOTES.portrait_text(id))
				_board_label(text, Rect2(x, 170, 470, 170))
				_queue_notebook_content(MARA2_NOTES.PREFIX + "SCREEN_PORTRAIT_" + id, text)
				_action("MARA2_ORDER_" + id, "이 시점의 조각 놓기", Rect2(x, 370, 470, 85), "mara2_portrait", id)
				_add_hotspot("MARA2_START_" + id, "3음 시작점", Rect2(x, 485, 470, 85), _show_mara2_alignment.bind(id, "start"))
				_add_hotspot("MARA2_OUTLINE_" + id, "이중 윤곽 기준점", Rect2(x, 600, 470, 85), _show_mara2_alignment.bind(id, "outline"))
			_action("MARA2_CLEAR", "시점 순서 다시 놓기", Rect2(250, 760, 630, 80), "mara2_clear")
			_action("MARA2_OVERLAY", "기록 중첩 검증", Rect2(1000, 760, 630, 80), "mara2_overlay")
		else:
			_mara2_board("OVERLAY", Rect2(300, 260, 1300, 230))
			_action("ARCHIVE_ENTER", "인격 아카이브로", Rect2(400, 550, 1100, 130), "move", "H0_PERSONALITY_ARCHIVE", false)
		_replace_back("M1_COLOR_ROOM_ENTRY", "입구로 · 진행 보존")
		return
	_location_label.text = "인격 아카이브"
	if session.known("E3_5_complete"):
		_mara2_board("COMPLETE", Rect2(300, 270, 1300, 230))
	elif not local["solved"]:
		for index in range(4):
			var owner: String = rules.OWNERS[index]
			_action("MARA2_BACKUP_" + owner, owner + " 보조 영역" + (" · 확인" if owner in local["backups"] else ""), Rect2(240 + index * 380, 180, 340, 100), "mara2_backup", owner)
		for index in range(12):
			var rect := Rect2(240 + (index % 6) * 250, 360 + (index / 6) * 135, 220, 110)
			var label := "%d · %s" % [index + 1, local["cells"].get(str(index), "결손")]
			if index in rules.GAPS: _add_hotspot("MARA2_CELL_%d" % index, label, rect, _show_mara2_cell.bind(index))
			else: _board_label(label, rect)
			_queue_notebook_content(MARA2_NOTES.PREFIX + MARA2_NOTES.cell_key(index, local["cells"].get(str(index), "결손")), _relationship_text(label))
		_action("MARA2_CHECKSUM", "12칸 체크섬 비교", Rect2(400, 720, 1100, 100), "mara2_checksum")
	else:
		_action("MARA2_CONFESS", "자기 저장 영역 양도 기록을 듣는다", Rect2(300, 270, 1300, 150), "mara2_confess")
		if local["confessed"]: _add_hotspot("MARA2_CHOICE", "원본과 주석 보존 방식", Rect2(300, 520, 1300, 150), _show_mara2_choice)
	_replace_back("H0_COLOR_SEPARATION", "색분해실로 · 진행 보존")


func _mara2_board(key: String, rect: Rect2) -> void:
	var text := _relationship_text(MARA2_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(MARA2_NOTES.PREFIX + "SCREEN_" + key, text)


func _show_mara2_source(portrait: String, owner: String) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": MARA2_NOTES.SOURCE_LABELS[0], "action": _close_modal}]
	for candidate in BasementSession.MARA2_RELATIONSHIP.OWNERS:
		actions.append({"label": candidate, "action": _modal_act.bind("mara2_source", [portrait, owner, candidate])})
	var body: String = BasementSession.MARA2_RELATIONSHIP.SIGNS[owner]
	if not _notebook_surface_enabled():
		_show_relationship_modal("초상화 " + portrait, body, actions)
		return
	_show_recorded_choice(_relationship_text("초상화 " + portrait), _relationship_text(body), _relationship_actions(actions), MARA2_NOTES.options("SOURCE_" + portrait + "_" + owner))


func _show_mara2_alignment(portrait: String, kind: String) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": MARA2_NOTES.ALIGN_LABELS[0], "action": _close_modal}]
	for index in range(3): actions.append({"label": MARA2_NOTES.ALIGN_LABELS[index + 1], "action": _modal_act.bind("mara2_align", [portrait, kind, index])})
	if not _notebook_surface_enabled():
		_show_relationship_modal("초상화 " + portrait, MARA2_NOTES.ALIGN_BODY, actions)
		return
	_show_recorded_choice(_relationship_text("초상화 " + portrait), _relationship_text(MARA2_NOTES.ALIGN_BODY), _relationship_actions(actions), MARA2_NOTES.options("ALIGN_" + portrait + "_" + kind.to_upper()))


func _show_mara2_cell(index: int) -> void:
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label": MARA2_NOTES.CELL_LABELS[0], "action": _close_modal}]
	for glyph in MARA2_NOTES.CELL_LABELS.slice(1): actions.append({"label": glyph, "action": _modal_act.bind("mara2_cell", [index, glyph])})
	if not _notebook_surface_enabled():
		_show_relationship_modal("결손 %d칸" % [index + 1], MARA2_NOTES.CELL_BODY, actions)
		return
	_show_recorded_choice(_relationship_text("결손 %d칸" % [index + 1]), _relationship_text(MARA2_NOTES.CELL_BODY), _relationship_actions(actions), MARA2_NOTES.options("CELL_%d" % (index + 1)))


func _show_mara2_choice() -> void:
	if not _notebook_surface_allowed(): return
	_show_relationship_choice("MARA2", "기록의 보존", "둘 다 원본과 감정 주석을 보존한다. 병합은 완전 회복의 약속이 아니며, 분리는 포기가 아니다.", [
		{"label": "설명을 다시 생각한다", "action": _close_modal},
		{"label": "감정 주석을 원본에 다시 합친다.", "action": _modal_act.bind("mara2_choose", "merged")},
		{"label": "원본과 주석을 분리해 서로 참조하게 한다.", "action": _modal_act.bind("mara2_choose", "separated")},
	])


func _show_j4_confirmation() -> void:
	if not _notebook_surface_allowed(): return
	var totals: Dictionary = BasementSession.JOURNAL_FOUR.summary(session.snapshot())
	var body := FRACTURE_RESOLUTION_TEXTS.j4_confirmation(totals, TranslationServer.get_locale())
	var actions: Array = [
		{"label": "계속 조사한다", "action": _close_modal},
		{"label": "기록을 정리한다", "action": _modal_act.bind("j4_confirm", true)},
	]
	if _notebook_surface_enabled():
		_show_recorded_choice(_fracture_resolution_text(JOURNAL_DISPLAY.MODAL_TITLE), body, _fracture_resolution_actions(actions), JOURNAL_DISPLAY.confirmation(totals))
	else:
		_show_fracture_resolution_modal(JOURNAL_DISPLAY.MODAL_TITLE, body, actions)
	var confirm := _modal_body.get_child(4) as Button
	confirm.disabled = true
	var delay := Timer.new()
	delay.name = "J4ConfirmDelay"
	delay.one_shot = true
	delay.wait_time = 0.5
	add_child(delay)
	delay.timeout.connect(_enable_j4_confirm.bind(weakref(confirm)))
	delay.timeout.connect(delay.queue_free)
	delay.start()


func _enable_j4_confirm(reference: WeakRef) -> void:
	var button = reference.get_ref()
	if is_instance_valid(button) and _modal_active and button.is_inside_tree():
		button.disabled = false
		_cycle_modal_focus()


func _build_final_inspection() -> void:
	_objective_label.text = _ending_text("f3_objective")
	_location_label.text = _ending_text("location")
	var local: Dictionary = BasementSession.FINAL_INSPECTION.progress(session.snapshot())
	if not local["entered"]:
		_action("F3_ENTER",_ending_text("f3_enter"),Rect2(400,400,1100,130),"f3_enter")
		return
	_action("F3_WAKE",_ending_text("f3_wake"),Rect2(200,250,700,220),"f3_inspect","wake")
	_action("F3_STAY",_ending_text("f3_stay"),Rect2(1020,250,700,220),"f3_inspect","stay")
	_action("F3_NOTEBOOK",_ending_text("f3_notebook"),Rect2(610,530,700,130),"f3_inspect","notebook")
	if local["seen"].size()==3:
		_action("F3_SUMMARY",_ending_text("f3_summary"),Rect2(400,720,1100,85),"f3_summary")
	if local["summary_seen"]:
		_action("F3_OPEN",_ending_text("f3_open"),Rect2(400,830,1100,85),"f3_open")


func _build_ending_entry() -> void:
	var locale := TranslationServer.get_locale()
	_location_label.text = GALLERY_TEXTS.text("entry_location",locale)
	var rules = BasementSession.ENDING_ENTRY
	var node: String = session.snapshot()["ending_run"]["current_node_id"]
	_objective_label.text = GALLERY_TEXTS.text("identity_objective" if node == "ED_ALL_CEREMONY" else "entry_objective",locale)
	if node != "ED_ALL_CEREMONY":
		_reality_board("ENTRY_SCREEN_" + node, GALLERY_TEXTS.entry(node,locale), Rect2(250,170,1420,510))
		_add_hotspot("ENDING_CONTINUE", GALLERY_TEXTS.text("entry_continue",locale), Rect2(450,770,1020,100), _ending_read.bind([{"speaker":"SYSTEM", "text":GALLERY_TEXTS.entry(node,locale)}], "continue", node))
		return
	var local: Dictionary = rules.progress(session.snapshot())
	var index: int = local["identity_index"]
	_reality_board("CEREMONY_IDENTITY_NEUTRAL", GALLERY_TEXTS.text("identity_neutral",locale), Rect2(250,150,1420,130))
	if index < rules.OWNERS.size():
		var identity := {"speaker":GALLERY_TEXTS.WAKE.name_for(rules.OWNERS[index],locale),"text":GALLERY_TEXTS.identity(index,locale)}
		_reality_board("CEREMONY_PROGRESS_" + String(rules.OWNERS[index]).to_upper(), GALLERY_TEXTS.text("identity_progress",locale) % [index + 1, identity["speaker"]], Rect2(300,360,1320,140))
		_add_hotspot("ENDING_IDENTITY", GALLERY_TEXTS.text("identity_listen",locale), Rect2(450,650,1020,120), _ending_read.bind([identity], "identity", rules.OWNERS[index]))
	elif not local["authority_seen"]:
		_add_hotspot("ENDING_AUTHORITY", GALLERY_TEXTS.text("authority_listen",locale), Rect2(450,450,1020,120), _ending_read.bind([{"speaker":GALLERY_TEXTS.WAKE.name_for("edgar",locale), "portrait":"EDGAR", "text":GALLERY_TEXTS.text("authority",locale)}], "authority", null))
	else:
		_reality_board("CEREMONY_SIGNATURE_GUIDE", GALLERY_TEXTS.text("signature_guide",locale), Rect2(250,320,1420,120))
		var signature = ENDING_SIGNATURE.new()
		signature.name = "ENDING_SIGNATURE"
		_hotspot_layer.add_child(signature)
		_place(signature, Rect2(460,510,1000,170))
		signature.signed.connect(_finish_ending_signature)
		signature.assistance_suggested.connect(func(): _set_status(GALLERY_TEXTS.text("signature_assistance",TranslationServer.get_locale())))
		_add_hotspot("ENDING_AUTO_SIGN", GALLERY_TEXTS.text("auto_sign",locale), Rect2(600,760,720,100), signature.finish_signature)


func _ending_read(lines: Array, action: String, value: Variant, prefix: String = "ending_") -> void:
	if _interaction_blocked(): return
	if not _notebook_surface_allowed(): return
	var typed := REALITY_NOTES.typed_lines(session.snapshot(), lines, action, value, prefix, session.history_context(), TranslationServer.get_locale())
	if typed.ok: typed = STAY_NOTES.typed_lines(session.snapshot(), typed.lines, action, value, prefix, session.history_context(), TranslationServer.get_locale())
	if not typed.ok:
		push_error(str(typed.error_ids))
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	_show_dialogue(typed.lines, _do.bind(prefix + action, value, false))


func _queue_reality_surface(key: String, text: String) -> void:
	if _notebook_surface_enabled():
		_notebook_surfaces.queue(REALITY_NOTES.PREFIX + key, text, TranslationServer.get_locale(), REALITY_NOTES.context(session.snapshot(), session.history_context()))


func _reality_board(key: String, text: String, rect: Rect2) -> void:
	_board_label(text, rect)
	_queue_reality_surface(key, text)


func _reality_world_choice(group: String, index: int, id: String, label: String, rect: Rect2, action: String, value: Variant) -> void:
	if not _notebook_surface_enabled():
		_action(id, label, rect, action, value, false)
		return
	_add_hotspot(id, label, rect, _reality_world_choice_pressed.bind(_notebook_surfaces.generation, group, index, label, TranslationServer.get_locale(), action, value))


func _reality_world_choice_pressed(generation: int, group: String, index: int, label: String, locale: String, action: String, value: Variant) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(), generation): return
	if not _notebook_surface_allowed(): return
	var options_id := REALITY_NOTES.PREFIX + group + "_OPTIONS"
	if not _notebook_surfaces.choose(session, _notebook_surface_scope(), options_id, REALITY_NOTES.PREFIX + "%s_SELECT_%d" % [group,index], label, locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act(action, value)
	_notebook_surfaces.dispatched(options_id, result.get("ok",false))
	if result.get("ok",false): _set_status("")
	_render_room()
	_feedback(result)


func _build_reality_wake() -> void:
	var rules = BasementSession.REALITY_WAKE
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	_location_label.text = WAKE_TEXTS.text("location_body" if node in ["EDR_WAKE_BODY","EDR_BODY_CHECK"] else "location_handoff", locale)
	_objective_label.text = WAKE_TEXTS.text("objective", locale) % WAKE_TEXTS.text(node, locale)
	if node in ["EDR_WAKE_BODY","EDR_BODY_CHECK"]:
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.075,0.095,0.105)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotspot_layer.add_child(backdrop)
		_place(backdrop, Rect2(0,90,1920,990))
	match node:
		"EDR_FAREWELL":
			var owner: String = rules.OWNERS[rules.index(state)]
			_reality_board("HANDOFF_BOARD_" + owner.to_upper(), WAKE_TEXTS.text("handoff_board", locale) % WAKE_TEXTS.name_for(owner, locale), Rect2(300,230,1320,270))
			_add_hotspot("REALITY_FAREWELL", WAKE_TEXTS.text("farewell", locale), Rect2(450,680,1020,120), _ending_read.bind(WAKE_TEXTS.farewell(state,owner,locale)["lines"], "farewell", owner, "reality_"))
		"EDR_DISCONNECT":
			_add_hotspot("REALITY_DISCONNECT", WAKE_TEXTS.text("disconnect", locale), Rect2(450,450,1020,150), _reality_disconnect)
		"EDR_WAKE_BODY":
			_reality_board("WAKE_BOARD", WAKE_TEXTS.text("wake_board", locale), Rect2(300,260,1320,300))
			_add_hotspot("REALITY_WAKE", WAKE_TEXTS.text("wake", locale), Rect2(450,730,1020,120), _ending_read.bind([{"speaker":"SYSTEM","text":WAKE_TEXTS.text("wake_body", locale)}],"continue",node,"reality_"))
		"EDR_BODY_CHECK":
			var seen: Array = state["ending_run"].get("required_interactions_seen", [])
			var index := 0
			var count := 0
			for object in rules.BODY:
				var data: Array = WAKE_TEXTS.body(object, locale)
				var repeated: bool = object in seen
				if repeated: count += 1
				var line := {"speaker":WAKE_TEXTS.text("protagonist", locale) if repeated else "SYSTEM", "text":data[2] if repeated else data[1]}
				if repeated:
					line["observed_fact_ids"] = [preload("res://scripts/systems/dialogue_observed_facts.gd").body_repeat_id(object)]
				_add_hotspot(object, data[0] + (WAKE_TEXTS.text("checked", locale) if repeated else ""), Rect2(400,250+index*170,1120,120), _ending_read.bind([line],"body",object,"reality_"))
				_queue_reality_surface("BODY_LABEL_%s_%s" % [object,"REPEAT" if repeated else "FIRST"], data[0] + (WAKE_TEXTS.text("checked",locale) if repeated else ""))
				index += 1
			if count >= 2: _action("REALITY_BODY_FINISH",WAKE_TEXTS.text("body_finish", locale),Rect2(400,800,1120,100),"reality_body_finish",null,false)


func _reality_disconnect() -> void:
	if _interaction_blocked(): return
	if not _notebook_surface_allowed(): return
	var locale := TranslationServer.get_locale()
	var lines := [
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_heat", locale)},
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_pressure", locale)},
		{"speaker":"SYSTEM","text":WAKE_TEXTS.text("disconnect_taste", locale)},
	]
	var typed := REALITY_NOTES.typed_lines(session.snapshot(), lines, "continue", "EDR_DISCONNECT", "reality_", session.history_context(), locale)
	if not typed.ok:
		push_error(str(typed.error_ids))
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	_show_dialogue(typed.lines, _reality_fade)


func _notebook_open_block_reason() -> String:
	var reason := super._notebook_open_block_reason()
	if not reason.is_empty(): return reason
	if _d5_hold_active or _d6_sleep_transition_active or (session != null and session.stage() == "D5" and SaveManager.get_build_flavor() == "demo" and _demo_stinger_seconds < 60.0):
		return "현재 장면을 확인한 뒤 수첩을 열 수 있습니다." if not TranslationServer.get_locale().begins_with("en") else "Open the notebook after the current scene finishes."
	return ""


func _open_notebook() -> void:
	if _unified_notebook_enabled() and session != null and session.stage() not in ["FIELD_NOTEBOOK", "REALITY_SURFACE"] and not String(session.snapshot().loop_state.location_id).begins_with("R0_"):
		super._open_notebook()
		return
	if not _notebook_surface_allowed(): return
	if session != null and session.stage() in ["FIELD_NOTEBOOK","REALITY_SURFACE"]:
		_open_field_page("FIELD_NOTEBOOK_COVER",false)
		return
	if session != null and str(session.snapshot()["loop_state"]["location_id"]).begins_with("R0_"):
		_set_status(WAKE_TEXTS.text("notebook_unavailable", TranslationServer.get_locale()))
		return
	super._open_notebook()


func _build_field_notebook() -> void:
	var rules = BasementSession.FIELD_NOTEBOOK
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var at_exit: bool = state["ending_run"]["current_node_id"] == "EDR_EXIT_PANEL"
	_location_label.text = FIELD_TEXTS.text("location_exit" if at_exit else "location_book", locale)
	_objective_label.text = FIELD_TEXTS.text("objective_exit" if at_exit else "objective_book", locale)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.075,0.095,0.105)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(backdrop)
	_place(backdrop,Rect2(0,90,1920,990))
	var seen: Array = state["ending_run"].get("required_interactions_seen",[])
	if at_exit:
		var index := 0
		var complete := true
		for id in rules.EXIT:
			if id not in seen: complete = false
			_add_hotspot(id,FIELD_TEXTS.exit_text(id,0,locale)+(FIELD_TEXTS.text("checked",locale) if id in seen else ""),Rect2(400,210+index*170,1120,120),_ending_read.bind([{"speaker":"SYSTEM","text":FIELD_TEXTS.exit_text(id,1,locale)}],"inspect",id,"field_"))
			_queue_reality_surface("EXIT_LABEL_%s_%s" % [id,"CHECKED" if id in seen else "UNCHECKED"], FIELD_TEXTS.exit_text(id,0,locale)+(FIELD_TEXTS.text("checked",locale) if id in seen else ""))
			index += 1
		if complete: _action("FIELD_UNLOCK",FIELD_TEXTS.text("unlock",locale),Rect2(400,780,1120,100),"field_unlock",null,false)
		return
	var pages: Array = state["loop_state"]["event_local_states"].get("FIELD_NOTEBOOK",{}).get("pages",[])
	var index := 0
	for id in rules.PAGES:
		_add_hotspot(id,FIELD_TEXTS.title(id,locale)+(FIELD_TEXTS.text("read",locale) if id in pages else (FIELD_TEXTS.text("required",locale) if id in rules.REQUIRED else "")),Rect2(200+(index%3)*520,170+(index/3)*180,480,140),_open_field_page.bind(id,false))
		_queue_reality_surface("FIELD_LABEL_%s_%s" % [id,"READ" if id in pages else "UNREAD"], FIELD_TEXTS.title(id,locale)+(FIELD_TEXTS.text("read",locale) if id in pages else (FIELD_TEXTS.text("required",locale) if id in rules.REQUIRED else "")))
		index += 1
	if rules.REQUIRED[0] in seen and rules.REQUIRED[1] in seen: _action("FIELD_FINISH",FIELD_TEXTS.text("finish",locale),Rect2(400,790,1120,100),"field_finish",null,false)


func _build_reality_surface() -> void:
	var rules = BasementSession.REALITY_SURFACE
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var location: String = state["loop_state"]["location_id"]
	var progress: Dictionary = rules.local(state)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.19,0.17,0.14) if location == "R0_SURFACE_THRESHOLD" else Color(0.075,0.095,0.105)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(backdrop)
	_place(backdrop,Rect2(0,90,1920,990))
	_location_label.text = SURFACE_TEXTS.text(location,locale)
	_objective_label.text = SURFACE_TEXTS.text("objective",locale)
	if node == "EDR_FINAL_FRAME":
		_objective_label.text = SURFACE_TEXTS.text("final_objective",locale)
		_reality_board("FINAL_FRAME_" + String(progress.look).to_upper(), SURFACE_TEXTS.final_frame(progress["look"],locale),Rect2(250,260,1420,250))
		var labels: Array[String] = []
		for direction in ["left","center","right"]: labels.append(SURFACE_TEXTS.view_text(direction,0,locale))
		_queue_reality_surface("LOOK_OPTIONS", "\n".join(labels))
		var index := 0
		for direction in ["left","center","right"]:
			_reality_world_choice("LOOK",index,"SURFACE_LOOK_"+direction,SURFACE_TEXTS.view_text(direction,0,locale),Rect2(250+index*500,650,440,100),"surface_look",direction)
			index += 1
		set_process(true)
		return
	if node == "EDR_AIRLOCK_CONFIRM":
		_reality_board("AIRLOCK_BOARD", SURFACE_TEXTS.text("airlock_board",locale),Rect2(300,250,1320,260))
		_queue_reality_surface("AIRLOCK_OPTIONS", SURFACE_TEXTS.text("cancel",locale) + "\n" + SURFACE_TEXTS.text("enter",locale))
		_reality_world_choice("AIRLOCK",0,"SURFACE_CANCEL",SURFACE_TEXTS.text("cancel",locale),Rect2(300,630,620,120),"surface_cancel",null)
		_reality_world_choice("AIRLOCK",1,"SURFACE_ENTER",SURFACE_TEXTS.text("enter",locale),Rect2(1000,630,620,120),"surface_enter",null)
		return
	var index := 0
	for id in rules.OBJECTS:
		if rules.OBJECTS[id][0] != location: continue
		_add_hotspot("SURFACE_OBJ_"+id,SURFACE_TEXTS.object_text(id,0,locale)+(SURFACE_TEXTS.text("checked",locale) if id in progress["seen"] else ""),Rect2(350,200+index*160,1220,110),_ending_read.bind([{"speaker":"SYSTEM","text":SURFACE_TEXTS.object_text(id,1,locale)}],"inspect",id,"surface_"))
		_queue_reality_surface("OBJECT_LABEL_%s_%s" % [String(id).to_upper(),"CHECKED" if id in progress.seen else "UNCHECKED"], SURFACE_TEXTS.object_text(id,0,locale)+(SURFACE_TEXTS.text("checked",locale) if id in progress.seen else ""))
		index += 1
	if node == "EDR_FACILITY_FREE_LOOK":
		var target := "R0_CRYO_CHAMBER" if location == "R0_FACILITY_EXIT" else "R0_FACILITY_EXIT"
		_action("SURFACE_MOVE",SURFACE_TEXTS.text("move_cryo" if target == "R0_CRYO_CHAMBER" else "move_exit",locale),Rect2(250,760,650,100),"surface_move",target,false)
		if location == "R0_FACILITY_EXIT": _action("SURFACE_AIRLOCK",SURFACE_TEXTS.text("airlock",locale),Rect2(1020,760,650,100),"surface_airlock",null,false)
	else:
		_action("SURFACE_OUTSIDE",SURFACE_TEXTS.text("outside",locale),Rect2(400,760,1120,100),"surface_outside",null,false)


func _process(delta: float) -> void:
	if not get_window().has_focus() or _interaction_blocked(): return
	if session.stage() == "D5" and SaveManager.get_build_flavor() == "full" and _d5_hold_active:
		_tick_full_d5_hold(minf(delta, 0.1))
		return
	if session.stage() == "D6":
		if _d6_sleep_transition_active:
			_tick_d6_sleep_transition(minf(delta, 0.1))
			return
		_tick_d6_guidance(minf(delta, 0.1))
		return
	if session.stage() == "D5" and SaveManager.get_build_flavor() == "demo":
		_tick_demo_stinger(minf(delta, 0.1))
		return
	if session.stage() in ["REALITY_SURFACE", "STAY_STORY"] and not _notebook_surface_allowed(): return
	_surface_active_seconds += minf(delta,0.1)
	if _surface_active_seconds >= 1.0:
		_surface_active_seconds -= 1.0
		if session.stage() == "STAY_STORY":
			var result := session.act("story_tick")
			if result.get("ok",false): _render_room()
			else: _feedback(result)
		else: _on_surface_tick()


func _tick_demo_stinger(delta: float) -> void:
	if _interaction_blocked(): return
	if _demo_stinger_save_failed or session.stage() != "D5" or SaveManager.get_build_flavor() != "demo": return
	if not _notebook_surface_allowed(): return
	var previous_beat := int(_demo_stinger_seconds / 10.0)
	_demo_stinger_seconds = minf(60.0, _demo_stinger_seconds + maxf(0.0, delta))
	_update_d5_transition_art(_demo_stinger_seconds / 60.0)
	if _demo_stinger_seconds >= 60.0:
		var result := session.act("d_fracture")
		_demo_stinger_save_failed = not result.get("ok", false)
		_render_room()
		if _demo_stinger_save_failed: _feedback(result)
	elif int(_demo_stinger_seconds / 10.0) != previous_beat:
		_render_room()


func _queue_stay_surface(key: String, text: String) -> void:
	if _notebook_surface_enabled():
		_notebook_surfaces.queue(STAY_NOTES.PREFIX + key,text,TranslationServer.get_locale(),REALITY_NOTES.context(session.snapshot(),session.history_context()))


func _stay_board(key: String, text: String, rect: Rect2) -> void:
	_board_label(text,rect)
	_queue_stay_surface(key,text)


func _queue_stay_seating(key: String, text: String) -> void:
	if _notebook_surface_enabled():
		_notebook_surfaces.queue_descriptor(STAY_NOTES.seating(session.snapshot(),key),text,TranslationServer.get_locale(),REALITY_NOTES.context(session.snapshot(),session.history_context()))


func _stay_world_choice(group: String, index: int, id: String, label: String, rect: Rect2, action: String, value: Variant) -> void:
	if not _notebook_surface_enabled():
		_action(id,label,rect,action,value,false)
		return
	var locale := TranslationServer.get_locale()
	var item := STAY_NOTES.descriptor(group + "_OPTIONS")
	var shown := NOTEBOOK_CONTENT.presentation(item,locale)
	var row := NOTEBOOK_CONTENT.definition(item.get("content_id",""),1)
	var language := "en-US" if locale.begins_with("en") else "ko-KR"
	if not shown.ok or row.locales[language].get("option_%d" % index,"") != label:
		push_error("NB_STAY_CHOICE_DISPLAY_MISMATCH:" + group)
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	_queue_stay_surface(group + "_OPTIONS",shown.text)
	_add_hotspot(id,label,rect,_stay_world_choice_pressed.bind(_notebook_surfaces.generation,group,index,label,locale,action,value))


func _stay_world_choice_pressed(generation: int, group: String, index: int, label: String, locale: String, action: String, value: Variant) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(),generation): return
	if not _notebook_surface_allowed(): return
	var options_id := STAY_NOTES.PREFIX + group + "_OPTIONS"
	if not _notebook_surfaces.choose(session,_notebook_surface_scope(),options_id,STAY_NOTES.PREFIX + "%s_SELECT_%d" % [group,index],label,locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act(action,value)
	_notebook_surfaces.dispatched(options_id,result.get("ok",false))
	if result.get("ok",false): _set_status("")
	_render_room()
	_feedback(result)


func _show_stay_modal(group: String, title: String, body: String, actions: Array) -> void:
	if not _notebook_surface_enabled():
		_show_modal(title,body,actions)
		return
	_show_recorded_choice(title,body,actions,STAY_NOTES.descriptor(group + "_OPTIONS"),REALITY_NOTES.context(session.snapshot(),session.history_context()))


func _build_stay_story() -> void:
	var rules = BasementSession.STAY_STORY
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var local: Dictionary = rules.progress(state)
	_location_label.text = _story_text("hall_location" if node == "EDS_CENTRAL_HALL" else "dining_location")
	_objective_label.text = _story_text("objective")
	if state["ending_run"].get("ending_appearance_mode","") == "layered" or _stay_inspection_open:
		for x in [160,960,1760]:
			var line := ColorRect.new()
			line.color = Color(0.7,0.8,0.85,0.3)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hotspot_layer.add_child(line)
			_place(line,Rect2(x,110,3,810))
	var appearance_mode: String = state["ending_run"].get("ending_appearance_mode","contextual")
	_board_label(_stay_text("display_status") % _stay_text("mode_"+appearance_mode),Rect2(200,105,1520,55))
	_add_hotspot("STORY_INSPECT",_stay_text("inspect"),Rect2(200,970,700,60),_toggle_stay_inspection)
	_add_hotspot("STORY_APPEARANCE",_stay_text("settings"),Rect2(1020,970,700,60),_show_stay_mode_settings)
	match node:
		"EDS_CENTRAL_HALL":
			if local.has("channel"): _stay_board("CHANNEL_" + String(local.channel).to_upper(),_story_text("channel_selected") % STAY_TEXTS.owner(local["channel"],locale),Rect2(250,720,1420,55))
			var index := 0
			for id in rules.HALL:
				_add_hotspot("STORY_HALL_"+id,STORY_TEXTS.hall(id,0,locale),Rect2(250+(index%2)*750,210+(index/2)*170,670,120),_story_channel_menu if id == "cord" else _ending_read.bind([{"speaker":"SYSTEM","text":STORY_TEXTS.hall(id,1,locale)}],"hall",id,"story_"))
				_queue_stay_surface("HALL_LABEL_" + String(id).to_upper(),STORY_TEXTS.hall(id,0,locale))
				index += 1
			_action("STORY_DINE",_story_text("dine"),Rect2(400,800,1120,100),"story_dine",null,false)
		"EDS_DINING_ROOM":
			_board_label(STORY_TEXTS.seating(state,locale),Rect2(250,200,1420,440))
			_queue_stay_seating("SEATING_SCREEN",STORY_TEXTS.seating(state,locale))
			_add_hotspot("STORY_SIT",_story_text("sit"),Rect2(400,780,1120,100),_ending_read.bind([{"speaker":"SYSTEM","text":STORY_TEXTS.seating(state,locale)}],"sit",null,"story_"))
		"EDS_TABLE_OBJECTS":
			for index in range(2):
				var prefix := _story_text("written" if index in local["written"] else "write")
				_stay_world_choice("WRITE_%d_%s" % [index,"WRITTEN" if index in local.written else "NEW"],0,"STORY_WRITE_%d"%index,prefix+STORY_TEXTS.sentence(index,locale),Rect2(250,180+index*105,1420,85),"story_write",index)
			var index := 0
			for owner in rules.TABLE:
				_add_hotspot("STORY_TABLE_"+owner,STORY_TEXTS.table_title(owner,locale),Rect2(250+(index%2)*750,420+(index/2)*110,670,85),_ending_read.bind(STORY_TEXTS.table_lines(state,owner,locale),"table",owner,"story_"))
				_queue_stay_surface("TABLE_LABEL_" + String(owner).to_upper(),STORY_TEXTS.table_title(owner,locale))
				index += 1
			_stay_world_choice("TEA_" + String(local.tea).to_upper(),0,"STORY_TEA_WARM",_story_text("warm")+(_story_text("selected") if local["tea"] == "warm" else ""),Rect2(250,755,670,60),"story_tea","warm")
			_stay_world_choice("TEA_" + String(local.tea).to_upper(),1,"STORY_TEA_HOT",_story_text("hot")+(_story_text("selected") if local["tea"] == "hot" else ""),Rect2(1000,755,670,60),"story_tea","hot")
			if local["written"].size() == 2: _action("STORY_FINAL",_story_text("final"),Rect2(400,850,1120,80),"story_final",null,false)
		"EDS_FINAL_FRAME":
			_objective_label.text = _story_text("final_objective")
			var text := STAY_NOTES.final_text(state,locale)
			_board_label(text,Rect2(250,200,1420,500))
			if local.elapsed < 2: _queue_stay_surface("FINAL_OPENING",text)
			else: _queue_stay_seating("FINAL_SEATING",text)
			if local["elapsed"] < 2: set_process(true)
			else: _action("STORY_FINISH",_story_text("finish"),Rect2(400,800,1120,100),"story_finish",null,false)


func _story_channel_menu() -> void:
	if _interaction_blocked(): return
	if not _notebook_surface_allowed(): return
	var actions: Array = [{"label":_story_text("close"),"action":_close_modal}]
	for owner in BasementSession.STAY_STORY.OWNERS:
		actions.append({"label":STAY_TEXTS.owner(owner,TranslationServer.get_locale()),"action":_modal_act.bind("story_channel",owner)})
	_show_stay_modal("CHANNEL",_story_text("channel_title"), _story_text("channel_body"), actions)


func _story_text(id: String) -> String:
	return STORY_TEXTS.text(id, TranslationServer.get_locale())


func _build_ending_credits() -> void:
	var state := session.snapshot()
	var locale := TranslationServer.get_locale()
	_location_label.text = CREDITS_TEXTS.text(state["ending_run"]["branch_id"],locale)
	_objective_label.text = CREDITS_TEXTS.text("objective",locale)
	if session.stage() == "POST_CREDITS":
		_board_label(CREDITS_TEXTS.text("post_body",locale),Rect2(300,210,1320,210))
		_add_hotspot("CREDITS_RESELECT",CREDITS_TEXTS.text("reselect",locale),Rect2(450,590,1020,110),_reselect_menu)
		_add_hotspot("CREDITS_GALLERY",CREDITS_TEXTS.text("gallery",locale),Rect2(450,470,1020,95),_gallery_menu)
		_add_hotspot("CREDITS_TITLE",CREDITS_TEXTS.text("title",locale),Rect2(450,760,1020,110),_return_to_title)
		return
	if not state["ending_run"].get("credits_started",false):
		var meta: Dictionary = session.ensure_ending_meta()
		if not meta.get("ok", false):
			_board_label(CREDITS_TEXTS.text("save_error",locale) % meta.get("error", "unknown"),Rect2(300,210,1320,300))
			_action("CREDITS_RETRY",CREDITS_TEXTS.text("retry",locale),Rect2(450,650,1020,100),"credits_start",null,false)
			return
		_action("CREDITS_START",CREDITS_TEXTS.text("start",locale),Rect2(450,440,1020,130),"credits_start",null,false)
		return
	var rules = BasementSession.ENDING_CREDITS
	var index: int = rules.page(state)
	_board_label(CREDITS_TEXTS.page(index,locale),Rect2(300,210,1320,460))
	if index < rules.PAGES.size()-1: _action("CREDITS_NEXT",CREDITS_TEXTS.text("next",locale),Rect2(450,770,1020,100),"credits_next",index,false)
	else: _action("CREDITS_FINISH",CREDITS_TEXTS.text("finish",locale),Rect2(450,770,1020,100),"credits_finish",null,false)


func _gallery_menu(page: int = 0) -> void:
	if _dialogue_active or session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	if _modal_active: _close_modal()
	var store = preload("res://scripts/systems/ending_gallery_store.gd").new(session.ending_meta_store.root_path.path_join("ending_gallery"))
	var entries: Array[Dictionary] = store.list_entries()
	var actions: Array = [{"label":GALLERY_TEXTS.text("close",locale),"action":_close_modal}]
	for index in range(page * 4, mini(entries.size(), page * 4 + 4)):
		var entry: Dictionary = entries[index]
		var label: String = GALLERY_TEXTS.text(entry["branch"],locale)
		actions.append({"label":GALLERY_TEXTS.text("record",locale) % [label,index + 1],"action":_gallery_page.bind(entry["id"],0)})
	if page > 0: actions.append({"label":GALLERY_TEXTS.text("previous_list",locale),"action":_gallery_menu.bind(page-1)})
	if (page+1)*4 < entries.size(): actions.append({"label":GALLERY_TEXTS.text("next_list",locale),"action":_gallery_menu.bind(page+1)})
	_show_modal(GALLERY_TEXTS.text("title",locale), GALLERY_TEXTS.text("empty" if entries.is_empty() else "description",locale), actions)


func _gallery_page(id: String, page: int) -> void:
	if session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	var entry: Dictionary = preload("res://scripts/systems/ending_gallery_store.gd").new(session.ending_meta_store.root_path.path_join("ending_gallery")).read_entry(id)
	if not entry.get("ok", false): return
	var pages: Array[Dictionary] = preload("res://scripts/systems/ending_gallery_pages.gd").build(entry["state"],locale)
	if page < 0 or page >= pages.size(): return
	if _modal_active: _close_modal()
	var actions: Array = [{"label":GALLERY_TEXTS.text("back",locale),"action":_gallery_menu}]
	if page > 0: actions.append({"label":GALLERY_TEXTS.text("previous_record",locale),"action":_gallery_page.bind(id,page-1)})
	if page+1 < pages.size(): actions.append({"label":GALLERY_TEXTS.text("next_record",locale),"action":_gallery_page.bind(id,page+1)})
	_show_modal("%s · %d/%d" % [pages[page]["title"],page+1,pages.size()], pages[page]["text"], actions)


func _reselect_source() -> String:
	return str(session.snapshot()["meta_progress"]["knowledge_entries"].get("reselect_source_slot_id", _slot_id))


func _reselect_menu(page: int = 0) -> void:
	if _dialogue_active or session.stage() != "POST_CREDITS": return
	var locale := TranslationServer.get_locale()
	if _modal_active: _close_modal()
	var source := _reselect_source()
	var entries: Array[Dictionary] = SaveManager.list_reselect_slots(source)
	var actions: Array = [{"label":CREDITS_TEXTS.text("cancel",locale),"action":_close_modal}]
	if SaveManager.load_f3_reselect(source).get("ok", false):
		actions.append({"label":CREDITS_TEXTS.text("new_copy",locale),"action":_confirm_reselect})
	for index in range(page * 4, mini(entries.size(), page * 4 + 4)):
		var entry: Dictionary = entries[index]
		actions.append({"label":CREDITS_TEXTS.text("resume_copy",locale) % [index + 1, entry["save_point_id"]],"action":_resume_reselect.bind(entry["slot_id"])})
	if page > 0: actions.append({"label":CREDITS_TEXTS.text("previous_list",locale),"action":_reselect_menu.bind(page - 1)})
	if (page + 1) * 4 < entries.size(): actions.append({"label":CREDITS_TEXTS.text("next_list",locale),"action":_reselect_menu.bind(page + 1)})
	_show_modal(CREDITS_TEXTS.text("reselect_title",locale), CREDITS_TEXTS.text("reselect_body",locale), actions)


func _confirm_reselect() -> void:
	_close_modal()
	var locale := TranslationServer.get_locale()
	_show_modal(CREDITS_TEXTS.text("confirm_title",locale), CREDITS_TEXTS.text("confirm_body",locale), [{"label":CREDITS_TEXTS.text("cancel",locale),"action":_close_modal},{"label":CREDITS_TEXTS.text("create",locale),"action":_create_reselect}])


func _create_reselect() -> void:
	if session.stage() != "POST_CREDITS": return
	_close_modal()
	var result: Dictionary = SaveManager.create_f3_reselect_slot(_reselect_source())
	if not result.get("ok", false):
		_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("create_failed",TranslationServer.get_locale())}])
		return
	_resume_reselect(result["slot_id"])


func _resume_reselect(target: String) -> void:
	if session.stage() != "POST_CREDITS": return
	var allowed := false
	for entry in SaveManager.list_reselect_slots(_reselect_source()):
		if entry["slot_id"] == target: allowed = true
	if not allowed: return
	if _modal_active: _close_modal()
	var result := LoadCoordinator.new(GameState, SaveManager).load_and_install(target)
	if not result.get("ok", false):
		_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("load_failed",TranslationServer.get_locale())}])
		return
	_slot_id = target
	session = _make_session()
	_render_room()
	_show_dialogue([{"speaker":CREDITS_TEXTS.text("notice",TranslationServer.get_locale()),"text":CREDITS_TEXTS.text("copy_entered",TranslationServer.get_locale())}])


func _on_surface_tick() -> void:
	if session == null or session.stage() != "REALITY_SURFACE" or session.snapshot()["ending_run"]["current_node_id"] != "EDR_FINAL_FRAME":
		set_process(false)
		return
	if not get_window().has_focus() or _interaction_blocked(): return
	if not _notebook_surface_allowed(): return
	var result := session.act("surface_tick")
	if not result.get("ok",false):
		_feedback(result)
		return
	if session.stage() != "REALITY_SURFACE": _render_room()


func _open_field_page(page: String, expanded: bool) -> void:
	if _dialogue_active: return
	if _modal_active: _close_modal()
	if not _notebook_surface_allowed(): return
	var rules = BasementSession.FIELD_NOTEBOOK
	var locale := TranslationServer.get_locale()
	var text: String = FIELD_TEXTS.page_text(session.snapshot(),page,expanded,locale)
	var pages: Array = rules.PAGES.keys()
	var next_page: String = pages[(pages.find(page)+1)%pages.size()]
	_show_recorded_choice(FIELD_TEXTS.title(page,locale),text,[
		{"label":FIELD_TEXTS.text("close",locale),"action":_modal_act.bind("field_read",{"page":page,"expanded":expanded})},
		{"label":FIELD_TEXTS.text("summary" if expanded else "expand",locale),"action":_open_field_page.bind(page,not expanded)},
		{"label":FIELD_TEXTS.text("next",locale) + FIELD_TEXTS.title(next_page,locale),"action":_advance_field_page.bind(page,expanded,next_page)},
	], MODAL_NOTES.field_options(session.snapshot(), page, expanded))


func _advance_field_page(page: String, expanded: bool, next_page: String) -> void:
	if _dialogue_active or not _modal_active:
		return
	var result := session.act("field_read", {"page":page,"expanded":expanded})
	if not result.get("ok",false):
		_set_status(_display_feedback(String(result.get("text",str(result.get("error_ids",[]))))))
		return
	_set_status("")
	_close_modal()
	_open_field_page(next_page,false)


func _reality_fade() -> void:
	var shade := ColorRect.new()
	shade.color = Color.BLACK
	shade.modulate.a = 0.0
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_modal_active = true
	var tween := create_tween()
	tween.tween_property(shade,"modulate:a",1.0,0.5)
	tween.tween_property(shade,"modulate:a",0.0,0.5)
	tween.tween_callback(func():
		shade.queue_free()
		_modal_active = false
		_do("reality_continue","EDR_DISCONNECT",false)
	)


func _finish_ending_signature() -> void:
	if _interaction_blocked(): return
	if not _notebook_surface_allowed():
		var signature = _hotspot_layer.get_node_or_null("ENDING_SIGNATURE")
		if signature != null: signature.allow_retry()
		return
	var text: String = REALITY_NOTES.SIGNATURE[session.snapshot().ending_run.branch_id][1 if TranslationServer.get_locale().begins_with("en") else 0]
	_ending_read([{"speaker":"SYSTEM", "text":text}], "sign", null)


func _build_ending_decision() -> void:
	for label in ["notice", "reality", "stay"]:
		_queue_notebook_content(FINAL_NOTES.PREFIX + "EDC_SCREEN_" + label.to_upper(), _ending_text(label))
	_objective_label.text = _ending_text("objective")
	_location_label.text = _ending_text("location")
	_board_label(_ending_text("notice"), Rect2(250,150,1420,100))
	_add_hotspot("EDC_REALITY", _ending_text("reality"), Rect2(200,300,700,220), _confirm_ending.bind("reality"))
	_add_hotspot("EDC_STAY", _ending_text("stay"), Rect2(1020,300,700,220), _confirm_ending.bind("stay"))
	_add_hotspot("EDC_SUBJECT", _ending_text("notebook"), Rect2(610,580,700,130), _edc_summary)
	_action("EDC_CANCEL", _ending_text("cancel"), Rect2(400,790,1100,100), "f3_cancel")
	_world_focus = "EDC_SUBJECT"
	call_deferred("_restore_world_focus")


func _restore_world_focus() -> void:
	if session != null and session.stage() == "EDC": _world_focus = "EDC_SUBJECT"
	if session != null and session.stage() == "STAY_CHARTER" and session.snapshot()["ending_run"]["current_node_id"] == "EDS_APPEARANCE_CONTROL": _world_focus = "STAY_MODE_NEUTRAL"
	super._restore_world_focus()


func _build_stay_charter() -> void:
	var rules = BasementSession.STAY_CHARTER
	var locale := TranslationServer.get_locale()
	var state := session.snapshot()
	var node: String = state["ending_run"]["current_node_id"]
	var local: Dictionary = rules.progress(state)
	var mode: String = state["ending_run"].get("ending_appearance_mode","")
	if mode == "unset": mode = ""
	_location_label.text = _stay_text("location")
	_objective_label.text = _stay_text(node)
	if mode == "layered" or _stay_inspection_open:
		for x in [160,960,1760]:
			var line := ColorRect.new()
			line.color = Color(0.7,0.8,0.85,0.3)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hotspot_layer.add_child(line)
			_place(line,Rect2(x,110,3,810))
		_board_label(_stay_text("structure"),Rect2(200,115,1520,60))
	if not mode.is_empty():
		_board_label("FILTER: DISPLAY ONLY · "+STAY_TEXTS.mode(mode,locale)+_stay_text("changeable"),Rect2(200,900,1520,60))
		_add_hotspot("STAY_INSPECT_FRAME",_stay_text("inspect"),Rect2(200,970,700,65),_toggle_stay_inspection)
		_add_hotspot("STAY_MODE_SETTINGS",_stay_text("settings"),Rect2(1020,970,700,65),_show_stay_mode_settings)
	match node:
		"EDS_MEMORY_CHARTER":
			for index in range(3):
				_add_hotspot("STAY_MEMORY_%d"%index,_stay_text("principle")%[index+1,_stay_text("checked") if index in local["principles"] else ""],Rect2(350,220+index*170,1220,120),_ending_read.bind([{"speaker":"SYSTEM","text":STAY_TEXTS.principle(index,locale)}],"memory",index,"stay_"))
				_queue_stay_surface("MEMORY_LABEL_%d_%s" % [index,"CHECKED" if index in local.principles else "UNCHECKED"],_stay_text("principle")%[index+1,_stay_text("checked") if index in local.principles else ""])
			if local["principles"].size() == 3: _stay_world_choice("MEMORY_FINISH",0,"STAY_MEMORY_FINISH",_stay_text("memory_finish"),Rect2(400,780,1120,100),"stay_memory_finish",null)
		"EDS_APPEARANCE_CONTROL":
			_stay_world_choice("APPEARANCE",0,"STAY_LAYERED",STAY_TEXTS.mode("layered",locale),Rect2(200,260,700,200),"stay_appearance","layered")
			_stay_world_choice("APPEARANCE",1,"STAY_CONTEXTUAL",STAY_TEXTS.mode("contextual",locale),Rect2(1020,260,700,200),"stay_appearance","contextual")
			_add_hotspot("STAY_MODE_NEUTRAL",_stay_text("neutral"),Rect2(460,540,1000,100),func(): _set_status(_stay_text("neutral_detail")))
			if not mode.is_empty(): _stay_world_choice("APPEARANCE_FINISH",0,"STAY_APPEARANCE_FINISH",_stay_text("appearance_finish"),Rect2(400,750,1120,100),"stay_appearance_finish",null)
		"EDS_AUTONOMY_CHARTER":
			_stay_board("AUTONOMY",_stay_text("autonomy"),Rect2(200,180,1520,120))
			var index := 0
			for owner in rules.OWNERS:
				_stay_world_choice("ROLE_%s_%s" % [String(owner).to_upper(),"PROPOSED" if owner in local.proposed else "FIXED"],0,"STAY_ROLE_"+owner,STAY_TEXTS.owner(owner,locale)+_stay_text("proposed" if owner in local["proposed"] else "fixed"),Rect2(250+(index%2)*750,350+(index/2)*140,670,100),"stay_propose",owner)
				index += 1
			if local["proposed"].size() == 5: _stay_world_choice("AUTONOMY_FINISH",0,"STAY_AUTONOMY_FINISH",_stay_text("autonomy_finish"),Rect2(400,790,1120,85),"stay_autonomy_finish",null)


func _toggle_stay_inspection() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	_stay_inspection_open = not _stay_inspection_open
	_render_room()


func _show_stay_mode_settings() -> void:
	if _interaction_blocked(): return
	if not _notebook_surface_allowed(): return
	_show_stay_modal("MODE_SETTINGS",_stay_text("settings_title"), _stay_text("settings_body"), [
		{"label":_stay_text("keep"),"action":_close_modal},
		{"label":_stay_text("layered_button"),"action":_modal_act.bind("stay_appearance","layered")},
		{"label":_stay_text("contextual_button"),"action":_modal_act.bind("stay_appearance","contextual")},
	])


func _stay_text(id: String) -> String:
	return STAY_TEXTS.text(id, TranslationServer.get_locale())


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session != null and session.stage() == "EDC":
		# An interrupted confirmation never executes on focus return.
		if _modal_active and not _notebook_is_open(): _close_modal()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and session != null and session.stage() == "EDC":
		call_deferred("_restore_world_focus")


func _edc_summary() -> void:
	if _interaction_blocked(): return
	var locale := TranslationServer.get_locale()
	_show_recorded_choice(_ending_text("summary_title"), ENDING_TEXTS.summary("wake", locale) + "\n\n" + ENDING_TEXTS.summary("stay", locale), [{"label": _ending_text("return"), "action": _close_modal}], MODAL_NOTES.options("EDC_SUMMARY"))


func _ending_text(id: String) -> String:
	return ENDING_TEXTS.text(id, TranslationServer.get_locale())


func _confirm_ending(decision: String) -> void:
	if _interaction_blocked() or session.stage() != "EDC": return
	if not BasementSession.ENDING_DECISION.CONFIRMATIONS.has(decision): return
	_show_recorded_choice(_ending_text("confirm_title"), ENDING_TEXTS.confirmation(decision, TranslationServer.get_locale()) + "\n\n" + _ending_text("confirm_notice"), [
		{"label": _ending_text("confirm_cancel"), "action": _modal_act.bind("f3_cancel")},
		{"label": _ending_text("confirm_commit"), "action": _modal_act.bind("edc_commit", decision)},
	], MODAL_NOTES.options("EDC_" + decision.to_upper()))


func _build_confrontation() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f2_objective")
	var rules = BasementSession.CONFRONTATION
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("F2_ENTER",_core_text("f2_enter"),Rect2(400,400,1100,130),"f2_enter")
		return
	var index := 0
	var labels := PackedStringArray()
	for question in FINAL_NOTES.QUESTIONS: labels.append(CORE_STORY_TEXTS.question(question, locale))
	_queue_notebook_content(FINAL_NOTES.PREFIX + "F2_OPTIONS", "\n".join(labels))
	for question in FINAL_NOTES.QUESTIONS:
		if _notebook_surface_enabled():
			_add_hotspot("F2_"+question, labels[index], Rect2(350,160+index*115,1200,95), _final_question_pressed.bind(_notebook_surfaces.generation, index, labels[index], locale))
		else:
			_action("F2_"+question, labels[index], Rect2(350,160+index*115,1200,95),"f2_question",question)
		index += 1
	if not local["recapped"]:
		_action("F2_RECAP",_core_text("f2_recap"),Rect2(350,790,1200,100),"f2_recap")
	else:
		_action("F2_FINISH",_core_text("f2_finish"),Rect2(350,790,1200,100),"f2_finish")


func _build_father_record() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f1_objective")
	var rules = BasementSession.FATHER_RECORD
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("F1_ENTER",_core_text("f1_enter"),Rect2(400,400,1100,130),"f1_enter")
		return
	_action("F1_INSPECT",_core_text("f1_inspect"),Rect2(300,150,1300,100),"f1_inspect")
	if not local["authenticated"]:
		var mark: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"].get("self_authored_mark",{})
		_action("F1_AUTH",_core_text("f1_auth"),Rect2(400,350,1100,120),"f1_authenticate",mark.get("type",""))
	else:
		for index in range(8):
			if index <= int(local["next"]):
				var mode := "replay" if index < int(local["next"]) else "play"
				var label: String = _core_text(mode) + CORE_STORY_TEXTS.father_title(index,locale)
				_action("F1_SEG_%d"%index, label,Rect2(250+(index%2)*740,290+(index/2)*105,700,85),"f1_play",index)
				_queue_notebook_content(FINAL_NOTES.PREFIX + "F1_TITLE_%s_%d" % [mode.to_upper(), index], label)
		if session.known("father_final_record_played"):
			if not local["j5_read"]:
				_action("J5_PAGE",_core_text("j5_page"),Rect2(400,780,1100,100),"f1_page")
			else:
				_action("J5_WRITE",_core_text("j5_write"),Rect2(400,780,1100,100),"f1_write","subject")


func _build_core_self() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f0e_objective")
	var rules = BasementSession.CORE_SELF
	var local: Dictionary = rules.progress(session.snapshot())
	var mark: Dictionary = session.snapshot()["meta_progress"]["knowledge_entries"].get("self_authored_mark",{})
	if not rules.MARKS.has(mark.get("type","")):
		_board_label(_core_text("f0e_missing_mark"), Rect2(300,250,1300,250))
		return
	if not local["past_verified"]:
		var shown_sequence: PackedStringArray = []
		for canonical_piece in local["sequence"]: shown_sequence.append(CORE_STORY_TEXTS.mark_piece(mark["type"],canonical_piece,locale))
		var mark_text := _core_text("f0e_mark") % [CORE_STORY_TEXTS.feedback(str(mark.get("text","")),locale)," → ".join(shown_sequence)]
		if _notebook_surface_enabled():
			var descriptor := CORE_NOTES.mark_surface(mark, local.sequence, locale)
			var shown := NOTEBOOK_CONTENT.presentation(descriptor, locale)
			if shown.ok:
				mark_text = shown.text
				_notebook_surfaces.queue_descriptor(descriptor, mark_text, locale, session.history_context())
		_board_label(mark_text, Rect2(300,130,1300,160))
		var pieces: Array = rules.MARKS[mark["type"]]
		for i in range(3):
			var piece: String = pieces[[2,0,1][i]]
			_action("F0E_PIECE_%d"%i,CORE_STORY_TEXTS.mark_piece(mark["type"],piece,locale),Rect2(400,330+i*115,1100,95),"f0e_piece",piece,false)
			_queue_core_surface("E_PIECE_%s_%d" % [String(mark.type).to_upper(), pieces.find(piece)], CORE_STORY_TEXTS.mark_piece(mark.type, piece, locale))
		_action("F0E_CLEAR",_core_text("rearrange"),Rect2(400,710,520,85),"f0e_clear",null,false)
		_action("F0E_PAST",_core_text("verify_past"),Rect2(980,710,520,85),"f0e_past")
	elif not local["current_verified"]:
		_core_board("E_AUTHOR", _core_text("f0e_author_board"),Rect2(300,140,1300,150))
		_queue_core_choices("AUTHOR")
		for i in range(4):
			var writer: String = ["father","system","subject","servant"][i]
			_core_choice("AUTHOR", i, "F0E_AUTHOR_"+writer, _core_text("author_"+writer), Rect2(400,330+i*115,1100,95),"f0e_author",writer)
	else:
		_core_board("E_INTENT", _core_text("f0e_intent_board"),Rect2(300,150,1300,150))
		_queue_core_choices("INTENT")
		for i in range(3):
			var intent: String = ["reality","stay","undecided"][i]
			_core_choice("INTENT", i, "F0E_INTENT_"+intent,CORE_STORY_TEXTS.intent(intent,locale),Rect2(400,370+i*130,1100,105),"f0e_intent",intent)


func _build_core_roles() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f0d_objective")
	var rules = BasementSession.CORE_ROLES
	var local: Dictionary = rules.progress(session.snapshot())
	_core_board("D_GUIDE", _core_text("f0d_board"), Rect2(220,105,1480,100))
	for index in range(5):
		var record: String = ["notebook","command","father","residents","passphrase"][index]
		var title: String = CORE_STORY_TEXTS.record_name(record,locale)
		if record == "residents" and not session.snapshot()["meta_progress"]["servants"]["mara2"]["researcher_record_acquired"]: title += " · " + _core_text("anonymous_index")
		if local["selected"] == record: title += " [" + _core_text("selected") + "]"
		_action("F0D_CARD_"+record, title, Rect2(180,235+index*115,620,95), "f0d_select", record)
		var anonymous: bool = record == "residents" and not session.snapshot().meta_progress.servants.mara2.researcher_record_acquired
		_queue_core_surface("D_CARD" + ("_YES" if local.selected == record else "_NO") + ("_ANON" if anonymous else ""), title, {"record":record})
		var placed: String = local["slots"][index]
		var slot_title: String = rules.LABELS[index]+"\n"+(_core_text("empty_slot") if placed.is_empty() else CORE_STORY_TEXTS.record_name(placed,locale))
		if local["locked"] == index: slot_title += " [" + _core_text("locked") + "]"
		_action("F0D_SLOT_%d"%index, slot_title, Rect2(880,235+index*115,650,95), "f0d_place", index, false)
		_queue_core_surface("D_SLOT" + ("_YES" if local.locked == index else "_NO"), slot_title, {"role":str(index), "record":"empty" if placed.is_empty() else placed})
		if local["failures"] >= 3 and local["locked"] < 0:
			_action("F0D_LOCK_%d"%index, _core_text("lock_confirm"), Rect2(1560,235+index*115,220,95), "f0d_lock", index)
	_action("F0D_VERIFY", _core_text("verify_roles"), Rect2(350,850,1200,85), "f0d_verify")


func _build_core_overlay() -> void:
	_objective_label.text = _core_text("f0c_objective")
	var rules = BasementSession.CORE_OVERLAY
	var local: Dictionary = session.snapshot()["loop_state"]["event_local_states"].get("F0_C", rules.initial())
	var board := preload("res://scripts/chapters/core_overlay_board.gd").new()
	board.state = local
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.add_child(board)
	_place(board, Rect2(150,170,850,660))
	_core_board("C_GUIDE", _core_text("f0c_board"), Rect2(150,835,850,125))
	for index in range(3):
		var layer: String = rules.LAYERS[index]
		var y := 160 + index*230
		var anchor_names := [_core_text("anchor_unset"), _core_text("anchor_origin"), _core_text("anchor_right"), _core_text("anchor_down")]
		var anchor_index := clampi(int(local[layer]["anchor"]) + 1, 0, 3)
		var layer_label := "%s · %d° · %s · %s" % [layer,local[layer]["turn"]*90,_core_text("flip_yes") if local[layer]["flip"] else _core_text("flip_no"),anchor_names[anchor_index]]
		_board_label(layer_label, Rect2(1050,y,720,55))
		_queue_core_surface("C_LAYER_" + layer, layer_label + "\n" + _core_text("opacity") % local[layer].opacity, {"degrees":int(local[layer].turn) * 90, "flipped":"yes" if local[layer].flip else "no", "anchor":str(int(local[layer].anchor)), "opacity":int(local[layer].opacity)})
		if not local["locked"]:
			if layer != "D4":
				_action(layer+"_ROTATE", _core_text("rotate_90"), Rect2(1050,y+65,340,55), "f0c", {"action":"rotate","layer":layer}, false)
				_action(layer+"_FLIP", _core_text("flip_horizontal"), Rect2(1410,y+65,340,55), "f0c", {"action":"flip","layer":layer}, false)
			_action(layer+"_ANCHOR", _core_text("cycle_anchor"), Rect2(1050,y+130,340,55), "f0c", {"action":"anchor","layer":layer,"value":(int(local[layer]["anchor"])+2)%4-1}, false)
		_action(layer+"_OPACITY", _core_text("opacity") % local[layer]["opacity"], Rect2(1410,y+130,340,55), "f0c", {"action":"opacity","layer":layer,"value":20 if local[layer]["opacity"] >= 100 else int(local[layer]["opacity"])+10}, false)
	if not local["locked"]:
		_action("F0C_VERIFY", _core_text("verify_overlay"), Rect2(1050,885,700,75), "f0c", {"action":"verify"})
	else:
		for index in range(3):
			var point: String = rules.INVESTIGATION[index]
			var point_label: String = _core_text(point.to_lower())
			_action("F0C_"+point, point_label, Rect2(1020+index*250,885,230,75), "f0c", {"action":"inspect","value":point})
			_queue_core_surface("C_" + point, point_label)


func _build_core_samples() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f0b_objective")
	var rules = BasementSession.CORE_SAMPLES
	var local: Dictionary = rules.progress(session.snapshot())
	_core_board("B_GUIDE", _core_text("f0b_board"), Rect2(240, 110, 1440, 110))
	for index in range(4):
		var room: String = rules.ROOMS[index]
		var y := 245 + index * 160
		_core_board("B_ROOM" + ("_YES" if room in local.verified else "_NO"), CORE_STORY_TEXTS.room_name(room,locale) + (" · " + _core_text("verified") if room in local["verified"] else ""), Rect2(160, y, 290, 125), {"room":room})
		for column in range(2):
			var sample: int = [1, 0][column] if index % 2 == 0 else column
			var label: String = CORE_STORY_TEXTS.sample_label(room,sample,locale)
			if local["selected"].get(room, -1) == sample: label += " [" + _core_text("selected") + "]"
			_action("F0B_%s_%d" % [room, sample], label, Rect2(480 + column * 460, y, 430, 125), "f0b_inspect", [room, sample])
			_queue_core_surface("B_SAMPLE_%s_%d" % [room.to_upper(), sample] + ("_YES" if local.selected.get(room, -1) == sample else "_NO"), label)
		if room not in local["verified"]:
			_action("F0B_SEND_" + room, _core_text("send"), Rect2(1410, y, 330, 125), "f0b_send", room)


func _build_core_room_network() -> void:
	var locale := TranslationServer.get_locale()
	_objective_label.text = _core_text("f0a_objective")
	var rules = BasementSession.CORE_ROOMS
	var local: Dictionary = rules.progress(session.snapshot())
	_core_board("A_GUIDE", _core_text("f0a_board"), Rect2(650, 345, 620, 245))
	var positions := [Vector2(675, 110), Vector2(1275, 345), Vector2(675, 650), Vector2(75, 345)]
	for slot in range(4):
		var pos: Vector2 = positions[slot]
		var room: String = local["tiles"][slot]
		var label := "%s · %s%s\n%s\n%s → %s" % [CORE_STORY_TEXTS.direction(slot,locale), CORE_STORY_TEXTS.room_name(room,locale), " [" + _core_text("selected") + "]" if local["selected"] == slot else "", CORE_STORY_TEXTS.port(room,locale), "Output" if CORE_STORY_TEXTS.is_english(locale) else "출력", CORE_STORY_TEXTS.direction(local["directions"][slot],locale)]
		_action("F0A_TILE_%d" % slot, label, Rect2(pos, Vector2(550, 150)), "f0a_select", slot, false)
		_queue_core_surface("A_TILE" + ("_YES" if local.selected == slot else "_NO"), label, {"direction":str(slot), "room":room, "port":room, "output":str(int(local.directions[slot]))})
		_action("F0A_ROTATE_%d" % slot, _core_text("f0a_rotate"), Rect2(pos + Vector2(0, 160), Vector2(550, 65)), "f0a_rotate", slot, false)
	_action("F0A_NOTES", _core_text("f0a_notes"), Rect2(180, 930, 720, 60), "f0a_notes")
	_action("F0A_SIGNAL", _core_text("f0a_signal"), Rect2(1020, 930, 720, 60), "f0a_signal")



func _final_question_pressed(generation: int, index: int, label: String, locale: String) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(), generation): return
	if not _notebook_surface_allowed(): return
	var options_id := FINAL_NOTES.PREFIX + "F2_OPTIONS"
	if not _notebook_surfaces.choose(session, _notebook_surface_scope(), options_id, FINAL_NOTES.PREFIX + "F2_SELECT_%d" % index, label, locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act("f2_question", FINAL_NOTES.QUESTIONS[index])
	_notebook_surfaces.dispatched(options_id, result.get("ok", false))
	if result.get("ok", false): _set_status("")
	_render_room()
	_feedback(result)


func _queue_core_choices(group: String) -> void:
	var labels := PackedStringArray()
	var values: Array = CORE_NOTES.OWNERS if group == "AUTHOR" else CORE_NOTES.INTENTS
	for value in values:
		labels.append(_core_text("author_" + value) if group == "AUTHOR" else CORE_STORY_TEXTS.intent(value, TranslationServer.get_locale()))
	_queue_notebook_content(CORE_NOTES.PREFIX + "E_" + group + "_OPTIONS", "\n".join(labels))


func _core_choice(group: String, index: int, id: String, label: String, rect: Rect2, action: String, value: String) -> void:
	if not _notebook_surface_enabled():
		_action(id, label, rect, action, value)
		return
	_add_hotspot(id, label, rect, _core_choice_pressed.bind(_notebook_surfaces.generation, group, index, label, TranslationServer.get_locale(), action, value))


func _core_choice_pressed(generation: int, group: String, index: int, label: String, locale: String, action: String, value: String) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(), generation): return
	if not _notebook_surface_allowed(): return
	var options_id := CORE_NOTES.PREFIX + "E_" + group + "_OPTIONS"
	var selected_id := CORE_NOTES.PREFIX + "E_" + group + "_SELECT_%d" % index
	if not _notebook_surfaces.choose(session, _notebook_surface_scope(), options_id, selected_id, label, locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act(action, value)
	_notebook_surfaces.dispatched(options_id, result.get("ok", false))
	if result.get("ok", false): _set_status("")
	_render_room()
	_feedback(result)


func _settlement_board(key: String, rect: Rect2) -> void:
	var text := _fracture_resolution_text(SETTLEMENT_NOTES.SCREEN[key])
	_board_label(text, rect)
	_queue_notebook_content(SETTLEMENT_NOTES.PREFIX + "SCREEN_" + key, text)


func _queue_settlement_choices(group: String) -> void:
	var labels := PackedStringArray()
	for label in SETTLEMENT_NOTES.CHOICES[group]: labels.append(_fracture_resolution_text(label))
	_queue_notebook_content(SETTLEMENT_NOTES.PREFIX + group + "_OPTIONS", "\n".join(labels))


func _settlement_choice(group: String, index: int, id: String, rect: Rect2, action: String, value: String) -> void:
	var locale := TranslationServer.get_locale()
	var label := _fracture_resolution_text(SETTLEMENT_NOTES.CHOICES[group][index])
	if not _notebook_surface_enabled():
		_action(id, label, rect, action, value)
		return
	_add_hotspot(id, label, rect, _settlement_choice_pressed.bind(_notebook_surfaces.generation, group, index, label, locale, action, value))


func _settlement_choice_pressed(generation: int, group: String, index: int, label: String, locale: String, action: String, value: String) -> void:
	if _interaction_blocked() or not _notebook_surfaces.live(_notebook_surface_scope(), generation): return
	if not _notebook_surface_allowed(): return
	var options_id := SETTLEMENT_NOTES.PREFIX + group + "_OPTIONS"
	var selected_id := SETTLEMENT_NOTES.PREFIX + group + "_SELECT_%d" % index
	if not _notebook_surfaces.choose(session, _notebook_surface_scope(), options_id, selected_id, label, locale):
		_set_status(_dialogue_ui_text("CH1_HISTORY_SAVE_ERROR"))
		return
	var result := session.act(action, value)
	_notebook_surfaces.dispatched(options_id, result.get("ok", false))
	if result.get("ok", false): _set_status("")
	_render_room()
	_feedback(result)


func _show_settlement_modal(key: String, title: String, body: String, actions: Array) -> void:
	if not _notebook_surface_allowed(): return
	_show_recorded_choice(_fracture_resolution_text(title), _fracture_resolution_text(body), _fracture_resolution_actions(actions), SETTLEMENT_NOTES.options(key))


func _build_core_approach() -> void:
	_objective_label.text = "코어 접근 · 남은 후속 반응"
	var state := session.snapshot()
	var rules = BasementSession.CORE_APPROACH
	var location: String = state["loop_state"]["location_id"]
	if location == "M1_NORTH_ARCHIVE_HALL" and rules.pending(state, "MARA2_FU"):
		_settlement_board("MARA2", Rect2(300, 150, 1300, 150))
		_queue_settlement_choices("MARA2")
		for index in range(3):
			var id: String = ["write", "call", "joke"][index]
			_settlement_choice("MARA2", index, "MARA2_FU_" + id, Rect2(350, 335 + index * 110, 1200, 90), "e6_mara2", id)
	elif location == "H0_CLOCK_MACHINE":
		if rules.pending(state, "EDGAR_S3"):
			_queue_settlement_choices("EDGAR")
			for index in range(3):
				var id: String = ["ask", "order", "wait"][index]
				_settlement_choice("EDGAR", index, "EDGAR_S3_" + id, Rect2(350, 250 + index * 100, 1200, 85), "e6_edgar", id)
		if not session.known("core_access_open"):
			_action("E6_OPEN", "후속 대화 없이 접근로를 연다", Rect2(350, 570, 1200, 90), "e6_open")
		else:
			_add_hotspot("E6_ENTER", "코어 경로 진입 확인", Rect2(350, 570, 1200, 90), _show_core_entry_confirmation)
	else:
		_settlement_board("OPTIONAL", Rect2(300, 250, 1300, 200))
	if location != "M1_NORTH_ARCHIVE_HALL" and rules.pending(state, "MARA2_FU"):
		_action("E6_ARCHIVE", "북쪽 기록 회랑 · 마라 2 후속", Rect2(250, 735, 680, 85), "e6_move", "M1_NORTH_ARCHIVE_HALL", false)
	if location != "H0_CLOCK_MACHINE":
		_action("E6_CLOCK", "보안 기계실 · 다음 경로", Rect2(980, 735, 680, 85), "e6_move", "H0_CLOCK_MACHINE", false)
	_action("E6_HALL", "중앙홀로 돌아간다", Rect2(350, 850, 1200, 70), "e6_move", "M1_CENTRAL_HALL", false)


func _show_core_entry_confirmation() -> void:
	_show_settlement_modal("E6_ENTER", "코어 경로 진입", "진입하면 이전 공간으로 돌아갈 수 없고, 미확인 후속 반응은 종료됩니다. 완료한 관계와 저녁의 결산은 유지됩니다. 현실·잔류 선택은 아직 하지 않습니다.", [
		{"label": "아직 조사한다", "action": _close_modal},
		{"label": "문턱을 넘는다", "action": _modal_act.bind("e6_enter", true)},
	])


func _build_last_evening() -> void:
	_objective_label.text = "마지막으로 정상인 저녁"
	var rules = BasementSession.LAST_EVENING
	var local: Dictionary = rules.progress(session.snapshot())
	if not local["entered"]:
		_action("E5_ENTER", "저녁 준비를 따라 식당으로 간다", Rect2(400, 400, 1100, 140), "e5_enter")
		return
	if session.snapshot()["loop_state"]["location_id"] == "M1_CENTRAL_HALL":
		_action("E5_RETURN", "식당으로 돌아간다", Rect2(400, 400, 1100, 140), "e5_inspect", "dining")
		return
	_action("E5_TABLE", "식탁의 목재와 프레임", Rect2(260, 220, 680, 100), "e5_inspect", "table")
	_action("E5_SEATS", "다섯 사용인의 자리와 문양", Rect2(980, 220, 680, 100), "e5_inspect", "seats")
	_action("E5_HALL", "중앙홀 시계를 다시 본다", Rect2(260, 345, 1400, 85), "e5_inspect", "hall")
	if not local["seated"]:
		_action("E5_SIT", "북쪽 정면의 내 자리에 앉는다", Rect2(350, 510, 1200, 140), "e5_sit")
	elif String(local["question"]).is_empty():
		_queue_settlement_choices("QUESTION")
		var index := 0
		for question in ["wish", "leave", "stay"]:
			_settlement_choice("QUESTION", index, "E5_QUESTION_" + question, Rect2(350, 475 + index * 110, 1200, 95), "e5_question", question)
			index += 1
	else:
		_add_hotspot("E5_FINISH", "코어 접근 준비를 마친다", Rect2(350, 600, 1200, 140), _show_e5_confirmation)


func _show_e5_confirmation() -> void:
	_show_settlement_modal("E5_FINISH", "코어 접근 준비", "저녁의 결산을 마칩니다. 남을지 떠날지는 코어에서 다시 확인합니다.", [
		{"label": "아직 준비되지 않았다", "action": _close_modal},
		{"label": "준비를 마친다", "action": _modal_act.bind("e5_finish", true)},
	])


func _journal_board(key: String, text: String, rect: Rect2) -> void:
	var displayed := _fracture_resolution_text(text)
	_board_label(displayed, rect)
	_queue_notebook_content(JOURNAL_DISPLAY.PREFIX + key, displayed)


func _build_journal_four() -> void:
	_objective_label.text = "네 번째 일지 · 약속과 권한"
	if session.stage() == "E3_4M":
		_journal_board("SCREEN_MINIMUM", JOURNAL_DISPLAY.SCREEN.MINIMUM, Rect2(300, 250, 1300, 250))
		_action("EDGAR_MINIMUM", "코어 접근 핀을 받아 꽂는다", Rect2(400, 590, 1100, 120), "j4_minimum")
	else:
		var rules = BasementSession.JOURNAL_FOUR
		var local: Dictionary = rules.progress(session.snapshot())
		if local["ordered"]:
			_action("J4_READ", "약속과 권한의 모순 문장을 읽는다", Rect2(300, 320, 1300, 230), "j4_read")
		else:
			_journal_board("SCREEN_GUIDE", JOURNAL_DISPLAY.SCREEN.GUIDE, Rect2(280, 140, 1360, 120))
			_journal_board(JOURNAL_DISPLAY.order_key(local.pages), JOURNAL_DISPLAY.order_text(local.pages), Rect2(300, 695, 1300, 50))
			for index in range(4):
				var id: String = ["roles", "promise", "activation", "transition"][index]
				_action("J4_PAGE_" + id, rules.PAGES[id], Rect2(300, 290 + index * 100, 1300, 85), "j4_page", id)
				_queue_notebook_content(JOURNAL_DISPLAY.PREFIX + "SCREEN_PAGE_" + id.to_upper(), _fracture_resolution_text(rules.PAGES[id]))
			_action("J4_CLEAR", "다시 펼친다", Rect2(300, 750, 610, 90), "j4_clear")
			_action("J4_ORDER", "순서를 확인한다", Rect2(1000, 750, 610, 90), "j4_order")

func _build_great_clock(_local: Dictionary) -> void:
	_action("BASEMENT_DOOR", BASEMENT_TEXTS.ui("basement_door", TranslationServer.get_locale()), Rect2(430, 300, 1050, 230), "move", "M1_BASEMENT_ENTRY", false)

func _build_loop_bedroom(local: Dictionary) -> void:
	super._build_loop_bedroom(local)
	for id in ["CSHORT", "RUB_CLOCK"]:
		var old := _hotspot_layer.get_node_or_null(id)
		if old != null:
			_hotspot_layer.remove_child(old)
			old.queue_free()
	if _basement().can_use_basement_shortcut(true):
		_action("D_FASTPATH", BASEMENT_TEXTS.ui("fastpath", TranslationServer.get_locale()), Rect2(350, 770, 1050, 90), "d_fastpath")
	elif _basement().can_use_basement_shortcut():
		_action("DSHORT", BASEMENT_TEXTS.ui("shortcut", TranslationServer.get_locale()), Rect2(350, 770, 1050, 90), "d_shortcut")

func _build_inner(_local: Dictionary, _journal: int) -> void:
	var local := _basement().basement_local()
	if not local["floorplan_ready"]:
		_puzzle_surface_board(PUZZLE_NOTES.surface("D_DRAWER_BOARD"), BASEMENT_TEXTS.ui("drawer_board", TranslationServer.get_locale()), Rect2(290, 210, 1350, 220))
		for index in range(3):
			var id: String = ["bedroom", "greenhouse", "great_clock"][index]
			_action("DRAWER_" + id, BASEMENT_TEXTS.ui("point_" + id, TranslationServer.get_locale()), Rect2(280 + index * 510, 540, 450, 140), "d_drawer_point", id)
			_queue_puzzle_surface(PUZZLE_NOTES.surface("D_POINT_" + id.to_upper()), BASEMENT_TEXTS.ui("point_" + id, TranslationServer.get_locale()))
		return
	_puzzle_surface_board(PUZZLE_NOTES.floorplan(local), BASEMENT_TEXTS.floorplan_status(local, TranslationServer.get_locale()), Rect2(260, 180, 1390, 210))
	_action("D_ROTATE", BASEMENT_TEXTS.ui("rotate_90", TranslationServer.get_locale()), Rect2(360, 440, 520, 90), "d_rotate", null, false)
	_action("D_FLIP", BASEMENT_TEXTS.ui("flip_horizontal", TranslationServer.get_locale()), Rect2(1030, 440, 520, 90), "d_flip", null, false)
	for index in range(3):
		var anchor: String = ["bedroom", "greenhouse", "great_clock"][index]
		_action("D_ANCHOR_%d" % index, BASEMENT_TEXTS.ui("anchor_" + anchor, TranslationServer.get_locale()), Rect2(280 + index * 510, 575, 450, 85), "d_anchor", anchor, false)
	_action("D_OVERLAY", BASEMENT_TEXTS.ui("verify_overlay", TranslationServer.get_locale()), Rect2(510, 745, 880, 105), "d_overlay")

func _build_axes() -> void:
	var axes: Dictionary = _basement().basement_local()["axes"]
	if axes["locked"]:
		_puzzle_surface_board(PUZZLE_NOTES.surface("D_AXIS_LOCKED"), BASEMENT_TEXTS.ui("axis_locked", TranslationServer.get_locale()), Rect2(380, 310, 1140, 250))
		return
	if axes["open"]:
		_action("STORAGE_ENTER", BASEMENT_TEXTS.ui("storage_enter", TranslationServer.get_locale()), Rect2(470, 330, 980, 250), "move", "B1_STORAGE", false)
		return
	for index in range(3):
		var axis: String = BASEMENT_RULES.AXES[index]
		_puzzle_surface_board(PUZZLE_NOTES.axis(axis, axes), BASEMENT_TEXTS.axis_status(axis, axes, TranslationServer.get_locale()), Rect2(240 + index * 520, 230, 460, 110))
		for depth in range(1, 4):
			_action("DEPTH_%s_%d" % [axis, depth], str(depth), Rect2(245 + index * 520 + (depth - 1) * 155, 410, 140, 85), "d_axis_depth", [axis, depth], false)
		_add_hotspot("PUSH_" + axis, BASEMENT_TEXTS.ui("axis_push", TranslationServer.get_locale()), Rect2(250 + index * 520, 560, 430, 100), _confirm_axis.bind(axis))
	_add_hotspot("CENTRAL_CW", BASEMENT_TEXTS.ui("central_cw", TranslationServer.get_locale()), Rect2(320, 755, 610, 105), _confirm_central.bind("clockwise"))
	_add_hotspot("CENTRAL_CCW", BASEMENT_TEXTS.ui("central_ccw", TranslationServer.get_locale()), Rect2(1030, 755, 580, 105), _confirm_central.bind("counterclockwise"))

func _confirmation_notebook() -> void:
	_close_modal()
	_open_notebook()

func _confirm_axis(axis: String) -> void:
	_show_recorded_choice(BASEMENT_TEXTS.axis_confirmation_title(axis, TranslationServer.get_locale()), BASEMENT_TEXTS.ui("axis_modal_body", TranslationServer.get_locale()), [
		{"label": BASEMENT_TEXTS.ui("review_plan", TranslationServer.get_locale()), "action": _confirmation_notebook},
		{"label": BASEMENT_TEXTS.ui("review_depth", TranslationServer.get_locale()), "action": _close_modal},
		{"label": BASEMENT_TEXTS.ui("axis_push", TranslationServer.get_locale()), "action": _modal_act.bind("d_axis_push", {"value": axis, "confirmed": true})},
	], MODAL_NOTES.options("BASEMENT_AXIS_" + axis.to_upper()))

func _confirm_central(direction: String) -> void:
	_show_recorded_choice(BASEMENT_TEXTS.central_confirmation_title(direction, TranslationServer.get_locale()), BASEMENT_TEXTS.ui("central_modal_body", TranslationServer.get_locale()), [
		{"label": BASEMENT_TEXTS.ui("review_direction", TranslationServer.get_locale()), "action": _close_modal},
		{"label": BASEMENT_TEXTS.ui("move_selected", TranslationServer.get_locale()), "action": _modal_act.bind("d_axis_central", {"value": direction, "confirmed": true})},
	], MODAL_NOTES.options("BASEMENT_CENTRAL_" + direction.to_upper()))

func _build_heart() -> void:
	var heart: Dictionary = _basement().basement_local()["heart"]
	_puzzle_surface_board(PUZZLE_NOTES.heart(heart), BASEMENT_TEXTS.heart_status(heart, TranslationServer.get_locale()), Rect2(270, 175, 1370, 180))
	var operations := ["turn", "turn", "turn", "reset", "fix", "unfix", "wind", "stabilize", "inspect_auxiliary"]
	var names := ["handle_a", "handle_b", "handle_c", "reset_rings", "fix_rings", "unfix_rings", "wind_lever", "stabilize", "inspect_panel"]
	for index in range(operations.size()):
		_action("HEART_%d" % index, BASEMENT_TEXTS.ui(names[index], TranslationServer.get_locale()), Rect2(235 + (index % 3) * 515, 415 + (index / 3) * 115, 455, 85), "d_heart", {"action": operations[index], "value": ["A", "B", "C"][index] if index < 3 else null})
	_add_hotspot("AUXILIARY", BASEMENT_TEXTS.ui("auxiliary_check", TranslationServer.get_locale()), Rect2(510, 805, 880, 88), _confirm_auxiliary)

func _confirm_auxiliary() -> void:
	_show_recorded_choice(BASEMENT_TEXTS.ui("auxiliary_modal_title", TranslationServer.get_locale()), BASEMENT_TEXTS.ui("auxiliary_modal_body", TranslationServer.get_locale()), [
		{"label": BASEMENT_TEXTS.ui("do_not_pull", TranslationServer.get_locale()), "action": _close_modal},
		{"label": BASEMENT_TEXTS.ui("review_record", TranslationServer.get_locale()), "action": _confirmation_notebook},
		{"label": BASEMENT_TEXTS.ui("pull_auxiliary", TranslationServer.get_locale()), "action": _modal_act.bind("d_heart", {"action": "pull_auxiliary", "confirmed": true})},
	], MODAL_NOTES.options("BASEMENT_AUXILIARY"))
