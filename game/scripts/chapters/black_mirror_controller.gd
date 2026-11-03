class_name BlackMirrorController
extends ChapterOneController

const MIRROR_SESSION := preload("res://scripts/systems/black_mirror_session.gd")
const MIRROR_RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")
const OVERLAY_DIAGRAM := preload("res://scripts/chapters/mirror_overlay_diagram.gd")
const MIRROR_TEXTS := preload("res://scripts/ui/black_mirror_display_texts.gd")
const ROUTE_FEEDBACK := preload("res://scripts/chapters/mirror_route_feedback.gd")
const PUZZLE_NOTES := preload("res://scripts/systems/notebook_puzzle_surfaces.gd")
const SHEET_FEEDBACK := preload("res://scripts/systems/ep02_puzzle_feedback.gd")
const DIAGNOSTIC_STATE := preload("res://scripts/systems/ep02_diagnostic_state.gd")
var _sheet_feedback_action := ""
var _sheet_feedback_value: Variant = null
var _sheet_feedback_local: Dictionary = {}
var _sheet_feedback_snapshot: Dictionary = {}


func _ep01_scene_followup(context: Dictionary) -> String:
	if context.start == "EP02_SCENE_09":
		var state := session.snapshot()
		for owner in ["EDGAR", "MARA1"]:
			if owner not in _mirror().mirror_local().get("witnesses", []): continue
			var identity := "EP02_C4_SUCCESS_%s_001" % owner
			if identity in context.ids: break
			var servant: Dictionary = state.meta_progress.servants[owner.to_lower()]
			if owner != "EDGAR" and (int(servant.bond) < 4 or int(servant.alert) >= 4): continue
			var receipt := "EFF_EP02_0030" if owner == "EDGAR" else "EFF_EP02_0031"
			if state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).has(receipt): break
			return identity
	return super._ep01_scene_followup(context)


func _queue_puzzle_surface(descriptor: Dictionary, text: String) -> void:
	if not _notebook_surface_enabled() or descriptor.is_empty(): return
	var row := PUZZLE_NOTES.CONTENT.definition(descriptor.content_id, 1)
	# Derived E/F views discard these intermediate controls before presentation.
	if session.stage() not in row.node_ids: return
	_notebook_surfaces.queue_descriptor(descriptor, text, TranslationServer.get_locale(), session.history_context())


func _puzzle_surface_board(descriptor: Dictionary, text: String, rect: Rect2) -> void:
	_board_label(text, rect)
	_queue_puzzle_surface(descriptor, text)


func _do(action: String, value: Variant = null, show_text: bool = true) -> void:
	if not _notebook_surface_allowed(): return
	if action != "c_dry":
		var previous := _sheet_feedback_action
		var previous_value: Variant = _sheet_feedback_value
		var previous_local := _sheet_feedback_local
		var previous_snapshot := _sheet_feedback_snapshot
		_sheet_feedback_action = action
		_sheet_feedback_value = value
		_sheet_feedback_snapshot = session.snapshot()
		_sheet_feedback_local = _mirror().mirror_local(_sheet_feedback_snapshot).duplicate(true)
		var action_before := _sheet_feedback_local
		super._do(action, value, show_text)
		_sheet_feedback_action = previous
		_sheet_feedback_value = previous_value
		_sheet_feedback_local = previous_local
		_sheet_feedback_snapshot = previous_snapshot
		if not show_text and get_script().resource_path.ends_with("/black_mirror_controller.gd"):
			var status_id := SHEET_FEEDBACK.status(action, value, action_before, _mirror().mirror_local())
			if not status_id.is_empty(): _show_sheet_status(status_id)
		if action == "move" and value == "M1_MIRROR_GALLERY" and session.snapshot().loop_state.location_id == value and session.stage() == "C4":
			call_deferred("_open_sheet_mirror_arrival", _recorded_choice_scope())
		return
	if _interaction_blocked():
		return
	var local := _mirror().mirror_local().duplicate(true)
	var result := session.act(action, value)
	_render_room()
	if not result.get("ok", false):
		_feedback(result)
		return
	_set_status("")
	_show_route_feedback(local)


func _open_sheet_mirror_arrival(scope: Dictionary) -> void:
	for step in range(100):
		if not is_inside_tree() or is_queued_for_deletion() or scope != _recorded_choice_scope() or session.stage() != "C4" or session.snapshot().loop_state.location_id != "M1_MIRROR_GALLERY": return
		if _modal_active or _dialogue_active or _notebook_is_open(): return
		if not _interaction_blocked():
			_ep01_play("EP02_C4_001")
			return
		await get_tree().create_timer(0.02).timeout


func _feedback(result: Dictionary) -> void:
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and not result.get("ok", false) and _sheet_feedback_action.begins_with("j3_"):
		for identity in ["EP02_J3_UI_PAGE_LOCKED", "EP02_J3_FB_ORDER_BAD"]:
			if result.get("text", "") == EP01.text(identity):
				_ep01_pages([identity])
				return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and not result.get("ok", false) and _sheet_feedback_action == "j3_point" and result.get("text", "") == EP01.text("EP02_J3_UI_POINT_DUP"):
		_ep01_pages(["EP02_J3_UI_POINT_DUP"])
		return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and not result.get("ok", false) and _sheet_feedback_action == "c_record":
		var count := DIAGNOSTIC_STATE.required_count(session.snapshot())
		var identity := "EP02_C5_CH_SCAN_PROGRESS_%d" % (count + 1)
		if count < 2 and result.get("text", "") == EP01.text(identity):
			_ep01_pages([identity])
			return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and not result.get("ok", false) and _sheet_feedback_action in ["c_pour", "c_pour_water_five", "c_mix", "c_disperse", "c_settle"]:
		var source_ids := ["EP02_C3_FB_ACTIVE_FIRST_BLOCK", "EP02_C3_FB_STABILIZER_FIRST_BLOCK", "EP02_C3_FB_ACTIVE_EARLY", "EP02_C3_UI_POUR_DISABLED"]
		for identity in source_ids:
			if result.get("text", "") == EP01.text(identity):
				_ep01_pages([identity])
				return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and result.get("ok", false):
		if _sheet_feedback_action in ["j3_overlay", "j3_remove_trace", "j3_point", "j3_compare", "j3_pick_part", "j3_drop_part"]:
			var ids: Array = []
			if _sheet_feedback_action == "j3_overlay":
				ids.append("EP02_J3_UI_PLACE_TRACE")
				if not _sheet_feedback_local.get("j3_overlay_seen", false): ids.append("EP02_J3_FB_TRACING_FIRST")
			for descriptor in result.get("notebook_feedback", []):
				var row := NOTEBOOK_CONTENT.definition(descriptor.content_id, int(descriptor.content_version))
				if row.get("producer_id") == "EP02_SHEET": ids.append(row.source_symbol)
			if not ids.is_empty():
				if _sheet_feedback_action == "j3_overlay":
					var lines := []
					for identity in ids: lines.append(EP01.line(identity, session.snapshot(), TranslationServer.get_locale()))
					_show_dialogue(lines, _ep01_continue.bind({"start": "EP02_J3_001", "stops": [], "cases": {}, "ids": ids, "finish": {}}))
				else: _ep01_pages(ids)
				return
		if _sheet_feedback_action.is_empty():
			var source_ids: Array = []
			var descriptors: Array = result.get("notebook_feedback", [])
			for descriptor in descriptors:
				var definition := NOTEBOOK_CONTENT.definition(descriptor.content_id, int(descriptor.content_version))
				if definition.get("producer_id") != "EP02_SHEET": break
				var identity: String = definition.source_symbol
				if EP01.node(identity).is_empty(): break
				source_ids.append(identity)
			if not source_ids.is_empty() and source_ids.size() == descriptors.size():
				if source_ids.size() == 1 and EP01.node(source_ids[0]).get("next_type") == "choice": _ep01_play(source_ids[0])
				else: _ep01_pages(source_ids)
				return
		if _sheet_feedback_action == "c_reason":
			_ep01_pages(["EP02_C3_CARD_001", "EP02_C3_CARD_002", "EP02_C3_CARD_SUCCESS_001", "EP02_C3_CARD_SUCCESS_002"])
			return
		if _sheet_feedback_action == "c_test":
			var mix: Dictionary = _mirror().mirror_local().mixture
			var nonempty := int(mix.water) + int(mix.stabilizer) + int(mix.active) > 0
			_sheet_caption_pages(SHEET_FEEDBACK.test_pages(_mirror().mirror_local()), ["EP02_CAP_TEST_OK" if _mirror().mirror_local().cleaner_ready else "EP02_CAP_TEST_BAD"] if nonempty else [])
			return
		if _sheet_feedback_action == "c_discard_cancel":
			_ep01_pages(["EP02_C3_UI_DISCARD_CANCEL"])
			return
		if _sheet_feedback_action == "c_verify_plan":
			_ep01_pages(["EP02_C4_UI_PLAN_VERIFIED", "EP02_C4_UI_OVERLAY_SAVE"])
			return
		if _sheet_feedback_action == "c_discard":
			var previous_mix: Dictionary = _sheet_feedback_local.mixture
			var nonempty := int(previous_mix.water) + int(previous_mix.stabilizer) + int(previous_mix.active) > 0
			_ep01_pages(["EP02_C3_FAIL_002", "EP02_C3_UI_DISCARD_DONE"] if nonempty else ["EP02_C3_FB_EMPTY"])
			return
		if _sheet_feedback_action == "c_mix" and int(_mirror().mirror_local().mixture.water) + int(_mirror().mirror_local().mixture.stabilizer) + int(_mirror().mirror_local().mixture.active) > 0:
			_ep01_pages(SHEET_FEEDBACK.mixture_pages(_mirror().mirror_local()))
			return
		if _sheet_feedback_action == "c_disperse":
			var ids: Array = ["EP02_C3_UI_DIFFUSE_READY"]
			if _mirror().mirror_local().mixture.stabilizer == 1: ids.push_front("EP02_C3_STABILIZER_001")
			_sheet_caption_pages(ids, ["EP02_CAP_DIFFUSE"])
			return
		if _sheet_feedback_action == "c_settle" and _sheet_feedback_local.mixture.foamy and not _mirror().mirror_local().mixture.foamy:
			_ep01_pages(["EP02_C3_UI_TEST_READY"])
			return
		if _sheet_feedback_action == "c_inspect":
			_ep01_pages(preload("res://scripts/systems/ep02_object_surfaces.gd").pages(session.snapshot(), String(_sheet_feedback_value), _sheet_feedback_local))
			return
		if _sheet_feedback_action == "c_scan":
			var key := String(_sheet_feedback_value)
			if key == "SUBJECT":
				var suffix := "REPEAT" if DIAGNOSTIC_STATE.seen(_sheet_feedback_snapshot, key) else "FIRST"
				_ep01_pages(["EP02_C5_CH_SUBJECT_" + suffix, "EP02_C5_HOT_SUBJECT_CHANNEL"])
				return
			var diagnostic: bool = MIRROR_SESSION.DIAGNOSTICS.has(key)
			var repeated := DIAGNOSTIC_STATE.seen(_sheet_feedback_snapshot, key)
			var scan_id := "EP02_C5_HOT_%s_%s" % [key, "REPEAT" if repeated else "FIRST"] if diagnostic else "EP02_C5_CH_%s_%s" % [key, "REPEAT" if repeated else "FIRST"]
			var scan_ids: Array = [scan_id]
			if not diagnostic: scan_ids.append("EP02_C5_HOT_%s_CHANNEL" % key)
			elif not repeated and not EP01.node("EP02_C5_%s_001" % key).is_empty(): scan_ids.append("EP02_C5_%s_001" % key)
			var captions: Array = ["EP02_CAP_PURPLE"] if key == "MARA2" else []
			if not diagnostic and _mirror().mirror_local().channels_scanned.size() == 5: captions.append("EP02_CAP_FIVE")
			_sheet_caption_pages(scan_ids, captions)
			return
		var start: String = {"c_observe": "EP02_C0_001", "c_hypothesis": "EP02_C1_001", "c_read_cleaning": "EP02_C2_001", "c_read_chemicals": "EP02_C21_001", "c_prepare": "EP02_C3_MIX_001", "c_record": "EP02_C5_TRACE_001", "j3_overlay": "EP02_J3_001", "c_wet": "EP02_C4_ACTUAL_001"}.get(_sheet_feedback_action, "")
		if _sheet_feedback_action == "j3_restore": start = "EP02_J3_SUCCESS_001"
		if _sheet_feedback_action == "c_record": start = "EP02_C5_REQUIRED_001"
		if _sheet_feedback_action == "c_shortcut": start = "EP02_CSHORT_001"
		if _sheet_feedback_action == "c_test": start = "EP02_C3_SUCCESS_001" if _mirror().mirror_local().cleaner_ready else "EP02_C3_FAIL_001"
		if not start.is_empty():
			var finish := {"method": "_show_sheet_edgar_aside", "args": []} if _sheet_feedback_action == "c_observe" else {}
			if _sheet_feedback_action == "c_record": finish = {"method": "_show_sheet_trace_done", "args": []}
			if _sheet_feedback_action == "j3_restore": finish = {"method": "_show_sheet_j3_done", "args": []}
			if _sheet_feedback_action == "c_wet":
				var identities := _ep02_wet_feedback_ids()
				if not identities.is_empty():
					var lines := []
					for identity in identities: lines.append(EP01.line(identity, session.snapshot(), TranslationServer.get_locale()))
					_show_dialogue(lines, _ep01_continue.bind({"start": start, "finish": finish, "stops": [], "cases": {}, "ids": identities}))
					return
			_ep01_play(start, finish)
			return
	super._feedback(result)


func _show_sheet_edgar_aside() -> void:
	if session.snapshot().loop_state.location_id != "M1_MIRROR_GALLERY" or not _ep02_world_enabled(): return
	_sheet_caption_pages([preload("res://scripts/systems/ep02_short_reactions.gd").edgar_warning(session.snapshot())], ["EP02_CAP_EDGAR_LINE"])


func _show_sheet_trace_done() -> void:
	if session.known("c5_info_complete"): _sheet_caption_pages(["EP02_C5_CH_TRACE_DONE", "EP02_SYS_SAVE_C5"], ["EP02_CAP_TRACE"])


func _show_sheet_j3_done() -> void:
	var state := session.snapshot()
	if int(state.meta_progress.journal_stage) < 3: return
	if not state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0049", false):
		_ep01_play("EP02_J3_COMMIT_001", {"method": "_show_sheet_j3_done", "args": []})
		return
	_ep01_pages(["EP02_J3_FB_SUCCESS", "EP02_J3_UI_COMMIT_DONE", "EP02_SYS_SAVE_J3", "EP02_SYS_EXIT_EP02"])


func _confirm_sheet_j3_restore() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	var state := session.snapshot()
	if state.loop_state.location_id != "M1_LIBRARY_INNER" or session.stage() != "J3": return
	var local := _mirror().mirror_local()
	if not preload("res://scripts/systems/ep02_journal_reference.gd").ready(local) or local.j3_order != [0, 1, 2, 3]:
		_do("j3_restore")
		return
	var descriptor := MODAL_NOTES.options("EP02_J3_RESTORE")
	var row := NOTEBOOK_CONTENT.definition(descriptor.content_id, descriptor.content_version)
	var localized: Dictionary = row.locales["en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"]
	_show_recorded_choice(localized.header, localized.prompt, [{"label": localized.option_0, "action": _close_modal}, {"label": localized.option_1, "action": _modal_act.bind("j3_restore")}], descriptor)


func _sheet_caption_pages(ids: Array, captions: Array) -> void:
	var profile: Dictionary = AccessibilityProfileStore.new().load_profile().get("profile", {})
	_ep01_pages(preload("res://scripts/systems/ep02_sensory_captions.gd").decorate(ids, captions, profile))


func _confirm_sheet_trace() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	var state := session.snapshot()
	if state.loop_state.location_id != "M1_MIRROR_GALLERY" or not session.known("mirror_tracing_acquired"): return
	if session.known("c5_info_complete"):
		_ep01_pages(["EP02_C5_CH_TRACE_DONE"])
		return
	if DIAGNOSTIC_STATE.required_count(state) < 2:
		_do("c_record")
		return
	var descriptor := MODAL_NOTES.options("EP02_TRACE")
	var row := NOTEBOOK_CONTENT.definition(descriptor.content_id, descriptor.content_version)
	var localized: Dictionary = row.locales["en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"]
	_show_recorded_choice(localized.header, localized.prompt, [{"label": localized.option_0, "action": _close_modal}, {"label": localized.option_1, "action": _modal_act.bind("c_record")}], descriptor)


func _show_sheet_status(identity: String) -> void:
	var text := EP01.text(identity, TranslationServer.get_locale())
	if text.is_empty(): return
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_status_label, Rect2(500, 74, 920, 60))
	_set_status(text)
	if not _notebook_surface_enabled(): return
	var context := session.history_context()
	context.node_id = identity
	context.chapter_id = "CHAPTER_2"
	_notebook_surfaces.queue_descriptor(NOTEBOOK_CONTENT.descriptor("NB_" + identity, EP01.notebook_version("NB_" + identity), {"body": {}}), text, TranslationServer.get_locale(), context, true)
	_notebook_surface_allowed()


func _show_route_feedback(local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	var descriptor := MODAL_NOTES.route_options(local)
	var body := MODAL_NOTES.route_body(descriptor, locale)
	_show_recorded_choice(MIRROR_TEXTS.ui("route_title", locale), body, [
		{"label": MIRROR_TEXTS.ui("overlay_back", locale), "action": _stop_sheet_dry_feedback},
		{"label": MIRROR_TEXTS.ui("route_replay", locale), "action": _replay_route_feedback},
	], descriptor, {}, _mirror_modal_view("mirror_route", local))


func _show_sheet_dry_feedback() -> void:
	_show_route_feedback(_mirror().mirror_local())


func _stop_sheet_dry_feedback() -> void:
	if _close_recorded_presentation_choice(): _show_sheet_status("EP02_C4_UI_DRY_STOP")


func _show_sheet_c4_cancel() -> void:
	var local := _mirror().mirror_local()
	if not local.locked and not local.surface_open: _show_sheet_status("EP02_C4_UI_COMMIT_CANCEL")


func _mirror_modal_view(kind: String, local: Dictionary) -> Dictionary:
	return {"kind": kind, "local": {"rotation": local.rotation, "flipped": local.flipped, "anchored": local.anchored, "path": local.path.duplicate()}}


func _replay_route_feedback() -> void:
	var diagram := _modal_body.get_node_or_null("MirrorRouteFeedback")
	if diagram != null: diagram.replay()


func _restore_recorded_modal_extras(view: Dictionary) -> void:
	super._restore_recorded_modal_extras(view)
	if view.is_empty(): return
	var local: Dictionary = view.local
	if view.kind == "mirror_overlay":
		var overlay := OVERLAY_DIAGRAM.new()
		overlay.name = "MirrorOverlayDiagram"
		overlay.turn_degrees = int(local.rotation)
		overlay.mirrored = local.flipped
		overlay.fixed_anchor = local.anchored
		overlay.overlay_transparency = _mirror().mirror_local().get("overlay_transparency", "balanced")
		_modal_body.add_child(overlay)
		_modal_body.move_child(overlay, 3)
		return
	var diagram := ROUTE_FEEDBACK.new()
	diagram.name = "MirrorRouteFeedback"
	var mode := String(AccessibilityProfileStore.new().load_profile().get("profile", {}).get("motion_mode", "standard"))
	diagram.configure(local, mode)
	diagram.overlay_transparency = _mirror().mirror_local().get("overlay_transparency", "balanced")
	_place(_modal_panel, Rect2(300, 90, 1320, 900))
	_modal_body.add_child(diagram)
	_modal_body.move_child(diagram, 3)
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.size_flags_stretch_ratio = 1.5
	call_deferred("_fit_route_feedback")
	call_deferred("_focus_visible_control", weakref(_modal_body.get_child(4)))


func _fit_route_feedback() -> void:
	# Wrapped text updates its minimum size after the modal's first layout pass.
	await get_tree().process_frame
	if _modal_active and _modal_body.has_node("MirrorRouteFeedback"):
		_place(_modal_panel, Rect2(300, 90, 1320, 900))

func _make_session() -> ChapterOneSession:
	return MIRROR_SESSION.new(GameState, SaveManager, _slot_id)


func _supported_hint_stages() -> Array:
	return ["C3", "C4", "CF", "J3"]


func _notebook_tools() -> Array:
	var tools := super._notebook_tools()
	if not tools.is_empty() and session != null and not preload("res://scripts/systems/ep02_evidence_notes.gd").available(session.snapshot()).is_empty():
		tools.append({"id": "SheetEvidenceNotes", "label": "Investigation summary" if TranslationServer.get_locale().begins_with("en") else "조사 요약", "action": _open_sheet_evidence_notes})
	if not tools.is_empty() and session != null and session.stage() == "C3":
		tools.append({"id": "CleanerQuantityTable", "label": "Compare quantities" if TranslationServer.get_locale().begins_with("en") else "세정제 양 비교", "action": _open_cleaner_quantity_table})
	return tools


func _open_sheet_evidence_notes() -> void:
	if session == null or _interaction_blocked() or not _notebook_surface_allowed(): return
	var ids := preload("res://scripts/systems/ep02_evidence_notes.gd").available(session.snapshot())
	if not ids.is_empty(): _ep01_pages(ids)


func _open_legacy_notebook() -> void:
	if _interaction_blocked():
		return
	super._open_legacy_notebook()
	if session.stage() == "C3":
		var button := Button.new()
		button.name = "CleanerQuantityTable"
		button.text = "Compare quantities" if TranslationServer.get_locale().begins_with("en") else "수첩에서 양을 정리한다"
		button.custom_minimum_size.y = 58
		button.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
		button.pressed.connect(_open_cleaner_quantity_table)
		_modal_body.add_child(button)
		_cycle_modal_focus()


func _open_cleaner_quantity_table(saved_ratio: bool = false, saved_difference: bool = false) -> void:
	if session == null or session.stage() != "C3":
		return
	var english := TranslationServer.get_locale().begins_with("en")
	_show_utility_modal("Compare quantities" if english else "세정제 양 비교", "", [{"label": "Close" if english else "닫기", "action": _close_modal}], "quantities", 0, saved_ratio, saved_difference)
	var scroll := _modal_body.get_child(2) as ScrollContainer
	scroll.custom_minimum_size.y = 180
	var label := scroll.get_child(0) as Label
	var ratio := CheckButton.new()
	ratio.name = "QuantityRatio"
	ratio.text = "A = 2 × S" if english else "원액 A = 안정제 S의 두 배"
	ratio.custom_minimum_size.y = 58
	ratio.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	var difference := CheckButton.new()
	difference.name = "QuantityWaterDifference"
	difference.text = "W = S + A + 2" if english else "물 W = 안정제 S + 원액 A + 2"
	difference.custom_minimum_size.y = 58
	difference.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	_modal_body.add_child(ratio)
	_modal_body.add_child(difference)
	ratio.set_pressed_no_signal(saved_ratio)
	difference.set_pressed_no_signal(saved_difference)
	var previous := [saved_ratio, saved_difference]
	var request := _utility_request
	var refresh := func(_pressed: bool = false):
		if ratio.button_pressed != previous[0] or difference.button_pressed != previous[1]:
			if _update_quantity_view(ratio.button_pressed, difference.button_pressed, request):
				previous[0] = ratio.button_pressed
				previous[1] = difference.button_pressed
			else:
				ratio.set_pressed_no_signal(previous[0])
				difference.set_pressed_no_signal(previous[1])
		var table := preload("res://scripts/ui/cleaner_quantity_table.gd")
		label.text = table.describe(table.candidates(ratio.button_pressed, difference.button_pressed), TranslationServer.get_locale())
		scroll.scroll_vertical = 0
	ratio.toggled.connect(refresh)
	difference.toggled.connect(refresh)
	var review := Button.new()
	review.name = "QuantitySourceCards"
	review.text = "Review observation cards" if english else "관찰 카드의 정수 조합을 확인한다"
	review.custom_minimum_size.y = 58
	review.add_theme_font_size_override("font_size", int(round(21 * _reading_text_scale)))
	review.pressed.connect(func(): _review_c3_cards(ratio.button_pressed, difference.button_pressed))
	_modal_body.add_child(review)
	refresh.call()
	_cycle_modal_focus()


func _review_c3_cards(ratio: bool, difference: bool) -> void:
	if not ratio or not difference:
		_set_status("두 양의 관계를 함께 대조한다.")
		return
	_close_modal()
	if _modal_active: return
	_do("c_reason", {"ratio": ratio, "difference": difference})


func _puzzle_hint_text(level: int) -> String:
	var limit: int = {"C3": 5, "C4": 4, "CF": 4, "J3": 3}.get(session.stage(), 0)
	if level < 0 or level >= limit: return ""
	var shown := NOTEBOOK_CONTENT.presentation(NOTEBOOK_CONTENT.hint_descriptor(session.stage(), level), TranslationServer.get_locale())
	return String(shown.get("text", "")) if shown.get("ok", false) else ""


func _show_clock_hint_menu(level: int = 0) -> void:
	if session == null: return
	var limit: int = {"C3": 5, "C4": 4, "CF": 4, "J3": 3}.get(session.stage(), 0)
	if limit == 0:
		super._show_clock_hint_menu(level)
		return
	level = clampi(level, 0, limit)
	var english := TranslationServer.get_locale().begins_with("en")
	var actions: Array = [{"label": "Close" if english else "닫기", "action": _close_modal}]
	var body := "Hints organize observed information without changing puzzle inputs or relationships." if english else "도움말은 확인한 정보를 정리하며 퍼즐 입력과 관계를 바꾸지 않는다."
	if level < limit: actions.append({"label": ("Read hint H%d" if english else "H%d 힌트를 읽는다") % (level + 1), "action": _read_clock_hint.bind(level)})
	else: body = "You have read the available hints. Review them in the notebook." if english else "준비된 도움말을 모두 살펴봤다. 수첩에서 읽었던 내용을 다시 확인할 수 있다."
	_show_utility_modal(_puzzle_hint_title(), body, actions, "hints", level)
	_cycle_modal_focus()


func _puzzle_hint_title() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if session.stage() == "J3": return "Journal restoration hints" if english else "일지 복원 생각 정리"
	if session.stage() == "C3":
		return "Cleaning solution hints" if english else "세정제 생각 정리"
	return "Black mirror hints" if english else "검은 거울 생각 정리"


func _update_objective() -> void:
	if session != null:
		_objective_label.text = MIRROR_TEXTS.objective(session.stage(), TranslationServer.get_locale())


func _display_feedback(text: String) -> String:
	var displayed := MIRROR_TEXTS.feedback(text, TranslationServer.get_locale())
	return super._display_feedback(text) if displayed == text else displayed


func _localized_notebook_entry(entry: String) -> String:
	var displayed := MIRROR_TEXTS.feedback(entry, TranslationServer.get_locale())
	return super._localized_notebook_entry(entry) if displayed == entry else displayed


func _mirror() -> BlackMirrorSession:
	return session as BlackMirrorSession


func _render_room() -> void:
	super._render_room()
	if session == null: return
	var local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	match _current_room:
		"M1_CENTRAL_HALL":
			if _ep02_world_enabled() and session.known("c5_info_complete"):
				_action("GREENHOUSE_DOOR", "온실" if not locale.begins_with("en") else "Greenhouse", Rect2(610, 665, 650, 100), "move", "M1_GREENHOUSE", false)
		"M1_PARLOR":
			_action("MIRROR_DOOR", MIRROR_TEXTS.ui("mirror_door", locale), Rect2(340, 350, 770, 250), "move", "M1_MIRROR_GALLERY", false)
		"M1_SERVANT_COMMON":
			_action("TOOL_DOOR", MIRROR_TEXTS.ui("tool_door", locale), Rect2(300, 770, 570, 100), "move", "M1_TOOL_ROOM", false)
			_action("KITCHEN_DOOR", MIRROR_TEXTS.ui("kitchen_door", locale), Rect2(1030, 770, 570, 100), "move", "M1_KITCHEN", false)
		"M1_NORTH_ARCHIVE_HALL":
			_action("COLOR_DOOR", MIRROR_TEXTS.ui("color_door", locale), Rect2(420, 780, 850, 90), "move", "M1_COLOR_ROOM_ENTRY", false)
		"M1_TOOL_ROOM":
			_location_label.text = MIRROR_TEXTS.ui("location_tool", locale)
			_action("C2_RECORD", MIRROR_TEXTS.ui("cleaning_record", locale), Rect2(370, 270, 1120, 190), "c_read_cleaning")
			_puzzle_surface_board(PUZZLE_NOTES.surface("C_TOOL_ROOM_BOARD"), MIRROR_TEXTS.ui("tool_room_board", locale), Rect2(370, 500, 1120, 170))
			_replace_back("M1_SERVANT_COMMON", MIRROR_TEXTS.ui("back_common", locale))
		"M1_KITCHEN":
			_location_label.text = MIRROR_TEXTS.ui("location_kitchen", locale)
			_build_chemical_bench(local)
			_replace_back("M1_SERVANT_COMMON", MIRROR_TEXTS.ui("back_common", locale))
		"M1_MIRROR_GALLERY":
			_location_label.text = MIRROR_TEXTS.ui("location_mirror", locale)
			_build_black_mirror(local)
			_replace_back("M1_PARLOR", MIRROR_TEXTS.ui("back_parlor", locale))
		"M1_COLOR_ROOM_ENTRY":
			_location_label.text = MIRROR_TEXTS.ui("location_color", locale)
			var color_key := "color_open" if session.known("color_room_entry_inspectable") else "color_closed"
			_puzzle_surface_board(PUZZLE_NOTES.surface("C_" + color_key.to_upper()), MIRROR_TEXTS.ui(color_key, locale), Rect2(390, 350, 1120, 250))
			_replace_back("M1_NORTH_ARCHIVE_HALL", MIRROR_TEXTS.ui("back_north", locale))
		"M1_GREENHOUSE":
			if _ep02_world_enabled():
				_set_room_background("M1_GREENHOUSE_VESTIBULE")
				_room_art.set_room("M1_GREENHOUSE_VESTIBULE", {})
				_location_label.text = "온실" if not locale.begins_with("en") else "Greenhouse"
				_add_hotspot("GREENHOUSE_INNER_LOCK", "안쪽 설비실" if not locale.begins_with("en") else "Inner equipment room", Rect2(610, 495, 650, 100), _close_modal)
				_hotspot_layer.get_node("GREENHOUSE_INNER_LOCK").disabled = true
				_replace_back("M1_CENTRAL_HALL", "중앙홀로" if not locale.begins_with("en") else "Central hall")
	if _ep02_world_enabled():
		var reactions := _mirror().sheet_reactions()
		for event in reactions:
			var name_key := "LUKA" if reactions[event].owner == "LUCA" else String(reactions[event].owner)
			_add_hotspot("SHEET_REACTION_" + event, _dialogue_ui_text("UI_SPEAKER_" + name_key), Rect2(170, 80, 300, 55), _open_sheet_reaction.bind(event))
			_hotspot_layer.get_node("SHEET_REACTION_" + event).disabled = reactions[event].complete and not preload("res://scripts/systems/ep02_short_reactions.gd").available(session.snapshot()).has(reactions[event].owner)
	call_deferred("_restore_world_focus")
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and (not preload("res://scripts/systems/ep02_object_surfaces.gd").available(session.snapshot()).is_empty() or not preload("res://scripts/systems/ep02_short_reactions.gd").available(session.snapshot()).is_empty()):
		_add_hotspot("EP02_OBJECTS", "주변 살펴보기", Rect2(1460, 80, 280, 55), _open_sheet_objects)


func _ep02_world_enabled() -> bool:
	if session == null: return false
	var state := session.snapshot()
	return not state.fracture_state.broken_reset_triggered and state.fracture_state.camouflage_filter != "disabled"


func _open_sheet_reaction(event: String) -> void:
	if _interaction_blocked() or not _notebook_surface_allowed() or not _ep02_world_enabled(): return
	var reaction: Dictionary = _mirror().sheet_reactions().get(event, {})
	if reaction.is_empty(): return
	if reaction.complete or reaction.get("flavor_only", false):
		_open_sheet_short(reaction.owner)
		return
	var cases := {"EP02_ROUTER_C21_REACTION": "EP02_C21_LUCA_CH01"} if event == "LUCA_C21" else {}
	_ep01_play(reaction.start, {}, [], cases)


func _open_sheet_short(owner: String) -> void:
	if _interaction_blocked() or not _notebook_surface_allowed() or not _ep02_world_enabled(): return
	var available := preload("res://scripts/systems/ep02_short_reactions.gd").available(session.snapshot())
	if available.has(owner): _ep01_pages([available[owner]])


func _select_sheet_short(owner: String) -> void:
	_close_modal()
	if _modal_active: return
	_open_sheet_short(owner)


func _select_c5_guide() -> void:
	_close_modal()
	if _modal_active or _interaction_blocked() or not _notebook_surface_allowed(): return
	if session.snapshot().loop_state.location_id == "M1_MIRROR_GALLERY" and session.known("mirror_tracing_acquired"):
		var ids: Array = ["EP02_SYS_UI_C5_REQUIRED", "EP02_SYS_UI_C5_OPTIONAL", "EP02_SYS_A11Y_HINT"]
		var profile: Dictionary = AccessibilityProfileStore.new().load_profile().profile
		if profile.get("signature_mode", "color_pattern_label") != "label_only": ids.append("EP02_SYS_A11Y_COLOR")
		if profile.get("signature_mode", "color_pattern_label") != "label_only": ids.append("EP02_C5_CH_PATTERN_MODE")
		if profile.get("signature_mode") == "pattern_label": ids.append("EP02_C5_CH_MONO_MODE")
		if preload("res://scripts/chapters/mirror_channel_signature.gd").quiet_profile(profile): ids.append("EP02_C5_CH_AUDIO_REDUCED")
		if profile.get("captions_enabled", true): ids.append("EP02_SYS_A11Y_AUDIO")
		_ep01_pages(ids)


func _open_sheet_objects() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	var actions: Array = []
	if session.snapshot().loop_state.location_id == "M1_MIRROR_GALLERY" and session.known("mirror_tracing_acquired"):
		actions.append({"label": "Diagnostic guide" if TranslationServer.get_locale().begins_with("en") else "진단 안내", "action": _select_c5_guide})
	if _ep02_world_enabled():
		for owner in preload("res://scripts/systems/ep02_short_reactions.gd").available(session.snapshot()):
			var name_key: String = "LUKA" if owner == "LUCA" else owner
			actions.append({"label": _dialogue_ui_text("UI_SPEAKER_" + name_key), "action": _select_sheet_short.bind(owner)})
	var objects := preload("res://scripts/systems/ep02_object_surfaces.gd").available(session.snapshot())
	for object_id in objects:
		actions.append({"label": objects[object_id], "action": _modal_act.bind("c_inspect", object_id)})
	actions.append({"label": "돌아간다", "action": _close_modal})
	_show_modal("주변 살펴보기", "", actions)


func _replace_back(destination: String, label: String) -> void:
	var old := _hotspot_layer.get_node_or_null("BACK")
	if old != null:
		_hotspot_layer.remove_child(old)
		old.queue_free()
	_action("BACK", label, Rect2(700, 944, 400, 72), "move", destination, false)


func _build_loop_bedroom(local: Dictionary) -> void:
	super._build_loop_bedroom(local)
	if _mirror().can_prepare_mirror_shortcut():
		_action("CSHORT", MIRROR_TEXTS.ui("shortcut", TranslationServer.get_locale()), Rect2(340, 755, 1000, 90), "c_shortcut")


func _confirm_sleep() -> void:
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and session.stage() == "CF":
		_ep01_play("EP02_CF_SLEEP_001")
		return
	super._confirm_sleep()


func _finish_campaign_sleep(result: Dictionary) -> void:
	if get_script().resource_path.ends_with("/black_mirror_controller.gd") and result.get("ok", false) and not result.get("retired", false) and session.snapshot().loop_state.location_id == "M2_BEDROOM" and not session.snapshot().fracture_state.broken_reset_triggered:
		var profile: Dictionary = AccessibilityProfileStore.new().load_profile().get("profile", {})
		if profile.get("captions_enabled", true) and not result.get("presentation_after", Callable()).is_valid():
			result = result.duplicate(true)
			result.presentation_after = _ep01_continue.bind({"start": "EP02_CAP_RESET", "stops": [], "cases": {}, "ids": [], "finish": {}})
	super._finish_campaign_sleep(result)


func _build_great_clock(_local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	_puzzle_surface_board(PUZZLE_NOTES.surface("C_BELL_BOARD"), MIRROR_TEXTS.ui("bell_board", locale), Rect2(330, 300, 1250, 200))
	_action("C_BELL_REPLAY", MIRROR_TEXTS.ui("bell_replay", locale), Rect2(440, 600, 1030, 130), "c_bell")


func _build_chemical_bench(local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	_action("C21_LABELS", MIRROR_TEXTS.ui("chemical_record", locale), Rect2(240, 150, 720, 80), "c_read_chemicals")
	_action("C_PREPARE", MIRROR_TEXTS.ui("prepare", locale), Rect2(1050, 150, 600, 80), "c_prepare")
	var mix: Dictionary = local["mixture"]
	_puzzle_surface_board(PUZZLE_NOTES.mixture(mix), MIRROR_TEXTS.mixture_status(mix, locale), Rect2(310, 290, 1310, 140))
	for index in range(3):
		var material: String = MIRROR_RULES.MATERIALS[index]
		_action("POUR_" + material, ("Pour 1 unit of " if MIRROR_TEXTS.is_english(locale) else "") + MIRROR_TEXTS.material_name(material, locale) + ("" if MIRROR_TEXTS.is_english(locale) else " 1단위 붓기"), Rect2(270 + index * 490, 475, 430, 85), "c_pour", material, false)
	var actions := ["c_disperse", "c_mix", "c_settle", "c_test", "c_discard"]
	_action("POUR_WATER_FIVE", "Measure 5 units of water" if MIRROR_TEXTS.is_english(locale) else "증류수 5단위 계량", Rect2(270, 560, 430, 58), "c_pour_water_five", null, false)
	var labels := ["disperse", "mix", "settle", "test", "discard"]
	for index in range(actions.size()):
		var rect := Rect2(250 + (index % 3) * 510, 620 + (index / 3) * 115, 450, 85)
		if actions[index] == "c_discard": _add_hotspot("c_discard", MIRROR_TEXTS.ui(labels[index], locale), rect, _confirm_cleaner_discard)
		else: _action(actions[index], MIRROR_TEXTS.ui(labels[index], locale), rect, actions[index])
	if local["cleaner_ready"]:
		_puzzle_surface_board(PUZZLE_NOTES.surface("C_READY_" + ("SIGNAL" if local["signal_ready"] else "CLOCK")), MIRROR_TEXTS.ui("cleaner_ready", locale) + " · " + MIRROR_TEXTS.ui("cleaner_mirror" if local["signal_ready"] else "cleaner_clock", locale), Rect2(750, 850, 820, 62))


func _confirm_cleaner_discard() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	var local := _mirror().mirror_local()
	if not local.materials_ready or local.cleaner_ready:
		_do("c_discard")
		return
	var descriptor := MODAL_NOTES.options("EP02_DISCARD")
	var row := NOTEBOOK_CONTENT.definition(descriptor.content_id, descriptor.content_version)
	var language := "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	var localized: Dictionary = row.locales[language]
	var cancel: Callable = _modal_act.bind("c_discard_cancel") if MIRROR_RULES.order_locked(local.mixture) else _close_modal
	_show_recorded_choice(localized.header, localized.prompt, [{"label": localized.option_0, "action": cancel}, {"label": localized.option_1, "action": _modal_act.bind("c_discard")}], descriptor)


func _build_black_mirror(local: Dictionary) -> void:
	var locale := TranslationServer.get_locale()
	if not session.known("c0_mirror_seen"):
		_action("C0", MIRROR_TEXTS.ui("observe", locale), Rect2(470, 300, 1000, 280), "c_observe")
		return
	if not session.known("c1_cleaning_hypothesis"):
		_action("C1", MIRROR_TEXTS.ui("hypothesis", locale), Rect2(470, 300, 1000, 280), "c_hypothesis")
		return
	if local["locked"]:
		_puzzle_surface_board(PUZZLE_NOTES.surface("C_LOCKED_BOARD"), MIRROR_TEXTS.ui("locked_board", locale), Rect2(430, 340, 1070, 240))
		return
	if session.known("mirror_tracing_acquired"):
		var profile: Dictionary = AccessibilityProfileStore.new().load_profile().get("profile", {})
		if not local["surface_open"]:
			_location_label.text = MIRROR_TEXTS.ui("location_copy", locale)
		for index in range(MIRROR_SESSION.DIAGNOSTICS.size()):
			var diagnostic: String = MIRROR_SESSION.DIAGNOSTICS.keys()[index]
			var checked := DIAGNOSTIC_STATE.seen(session.snapshot(), diagnostic)
			_action("SCAN_" + diagnostic, MIRROR_SESSION.DIAGNOSTICS[diagnostic] + (MIRROR_TEXTS.ui("scan_done", locale) if checked else ""), Rect2(170 + (index % 3) * 530, 140 + (index / 3) * 125, 480, 100), "c_scan", diagnostic)
		for index in range(5):
			var owner: String = MIRROR_SESSION.CHANNELS.keys()[index]
			var text: String = MIRROR_TEXTS.channel(owner, locale)
			var checked := DIAGNOSTIC_STATE.seen(session.snapshot(), owner)
			var label := text + (MIRROR_TEXTS.ui("scan_done", locale) if checked else "")
			_action("SCAN_" + owner, label, Rect2(230 + (index % 2) * 780, 460 + (index / 2) * 110, 720, 85), "c_scan", owner)
			var signature := preload("res://scripts/chapters/mirror_channel_signature.gd").new()
			signature.name = "CHANNEL_SIGNATURE_" + owner
			signature.configure(owner, String(profile.get("signature_mode", "color_pattern_label")), preload("res://scripts/chapters/mirror_channel_signature.gd").quiet_profile(profile))
			_hotspot_layer.add_child(signature)
			_place(signature, Rect2(175 + (index % 2) * 780, 472 + (index / 2) * 110, 45, 60))
			var channel_index := Label.new()
			channel_index.name = "CHANNEL_INDEX_" + owner
			channel_index.text = str(index + 1)
			channel_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			channel_index.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hotspot_layer.add_child(channel_index)
			_place(channel_index, Rect2(175 + (index % 2) * 780, 445 + (index / 2) * 110, 45, 26))
			_queue_puzzle_surface(PUZZLE_NOTES.surface("C_CHANNEL_%s_%s" % [owner, "CHECKED" if checked else "UNCHECKED"]), label)
		var count := DIAGNOSTIC_STATE.required_count(session.snapshot())
		_action("SCAN_SUBJECT", "연필선과 종이 자국", Rect2(1010, 680, 720, 85), "c_scan", "SUBJECT")
		var progress_id := "EP02_C5_CH_SCAN_PROGRESS_DONE" if count == 2 else "EP02_C5_CH_SCAN_PROGRESS_%d" % (count + 1)
		_board_label(EP01.text(progress_id, locale), Rect2(230, 790, 1460, 55))
		_add_hotspot("C5_INFO", MIRROR_TEXTS.ui("record_channels", locale), Rect2(420, 850, 1110, 80), _confirm_sheet_trace)
		return
	_puzzle_surface_board(PUZZLE_NOTES.trace(local), MIRROR_TEXTS.trace_status(local, locale), Rect2(170, 140, 1580, 120))
	var english := MIRROR_TEXTS.is_english(locale)
	var transforms := ["c_rotate", "c_rotate_ccw", "c_flip", "c_anchor", "c_anchor_other", "c_clear_plan", "c_transparency", "c_transparency"]
	var transform_labels := [MIRROR_TEXTS.ui("rotate", locale), "Counterclockwise 90 degrees" if english else "반시계 90도", MIRROR_TEXTS.ui("flip", locale), MIRROR_TEXTS.ui("anchor", locale), "Other reference point" if english else "다른 기준점", MIRROR_TEXTS.ui("clear_plan", locale), "Low transparency" if english else "낮은 투명도", "High transparency" if english else "높은 투명도"]
	for index in range(transforms.size()):
		var value: Variant = "low" if index == 6 else ("high" if index == 7 else null)
		var id: String = ("C_ALPHA_LOW" if index == 6 else "C_ALPHA_HIGH") if index >= 6 else transforms[index]
		_action(id, transform_labels[index], Rect2(180 + (index % 4) * 430, 280 + (index / 4) * 68, 380, 58), transforms[index], value, false)
	for index in range(5):
		var segment: String = MIRROR_RULES.SEGMENTS[index]
		_action("SEG_" + segment, MIRROR_TEXTS.segment_name(segment, locale), Rect2(200 + (index % 3) * 530, 420 + (index / 3) * 100, 470, 78), "c_segment", segment, false)
	_add_hotspot("TRACE_COMPARE", MIRROR_TEXTS.ui("trace_compare", locale), Rect2(1260, 520, 470, 78), _open_trace_overlay)
	_action("C_DRY", MIRROR_TEXTS.ui("dry", locale), Rect2(220, 665, 500, 85), "c_dry")
	_action("C_VERIFY", MIRROR_TEXTS.ui("verify", locale), Rect2(770, 665, 430, 85), "c_verify_plan")
	_add_hotspot("C_WET", MIRROR_TEXTS.ui("wet", locale), Rect2(1250, 665, 480, 85), _confirm_wet_trace)
	_hotspot_layer.get_node("C_WET").tooltip_text = EP01.text("EP02_C4_FB_COMMIT_WARNING", locale)
	_add_hotspot("C_PATROL", MIRROR_TEXTS.ui("patrol", locale), Rect2(540, 810, 830, 80), _open_patrol)


func _open_trace_overlay() -> void:
	if not _notebook_surface_allowed(): return
	var local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	_show_recorded_choice(MIRROR_TEXTS.ui("overlay_title", locale), MIRROR_TEXTS.ui("overlay_body", locale) + "\n" + MIRROR_TEXTS.trace_status(local, locale), [{"label": MIRROR_TEXTS.ui("overlay_back", locale), "action": _close_modal}], PUZZLE_NOTES.trace(local, true), {}, _mirror_modal_view("mirror_overlay", local))


func _open_patrol() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd"):
		_ep01_play("EP02_C4_003")
		return
	var locale := TranslationServer.get_locale()
	_show_recorded_choice(MIRROR_TEXTS.ui("patrol_title", locale), MIRROR_TEXTS.ui("patrol_body", locale), [
		{"label": MIRROR_TEXTS.ui("patrol_wait", locale), "action": _modal_act.bind("c_handle_patrol", "wait")},
		{"label": MIRROR_TEXTS.ui("patrol_question", locale), "action": _modal_act.bind("c_handle_patrol", "question")},
		{"label": MIRROR_TEXTS.ui("patrol_cloth", locale), "action": _modal_act.bind("c_handle_patrol", "cloth")},
	], MODAL_NOTES.options("MIRROR_PATROL"))


func _confirm_wet_trace() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	if get_script().resource_path.ends_with("/black_mirror_controller.gd"):
		_ep01_play("EP02_C4_COMMIT_001")
		return
	var locale := TranslationServer.get_locale()
	_show_recorded_choice(MIRROR_TEXTS.ui("wet_title", locale), MIRROR_TEXTS.ui("wet_body", locale), [
		{"label": MIRROR_TEXTS.ui("wet_review", locale), "action": _close_modal},
		{"label": MIRROR_TEXTS.ui("wet_dry", locale), "action": _modal_act.bind("c_dry", null)},
		{"label": MIRROR_TEXTS.ui("wet_execute", locale), "action": _modal_act.bind("c_wet", true)},
	], MODAL_NOTES.options("MIRROR_WET"))


func _build_inner(local: Dictionary, journal: int) -> void:
	if not session.known("c5_info_complete") or journal >= 3:
		super._build_inner(local, journal)
		if journal == 2 and not session.known("c5_info_complete"):
			_add_hotspot("J3_LOCKED", "Inspect the next page" if TranslationServer.get_locale().begins_with("en") else "다음 페이지 살펴보기", Rect2(480, 660, 960, 70), _inspect_j3_locked)
		return
	var mirror_local := _mirror().mirror_local()
	var locale := TranslationServer.get_locale()
	var english := MIRROR_TEXTS.is_english(locale)
	_action("J3_OVERLAY", "Place tracing" if english else "탁본 놓기", Rect2(230, 125, 700, 60), "j3_overlay")
	_action("J3_REMOVE", "Lift tracing" if english else "탁본 들어 올리기", Rect2(990, 125, 700, 60), "j3_remove_trace")
	_hotspot_layer.get_node("J3_REMOVE").disabled = not mirror_local.j3_trace_placed
	if mirror_local.j3_reference_points.size() == 3 and session.snapshot().meta_progress.knowledge_entries.get("MEM_FATHER_TEA_HAND_FRAGMENT") == "sensory_fragment":
		_add_hotspot("J3_MEMORY", "Impression under the page" if english else "페이지 아래의 눌림", Rect2(230, 195, 1460, 40), _open_j3_memory)
	for index in range(3):
		var key: String = ["BED", "GREEN", "CLOCK"][index]
		var names: Array = ["Bedroom", "Greenhouse", "Great clock"] if english else ["침실", "온실", "대시계"]
		var label: String = names[index] + ((" · marked" if english else " · 표시됨") if key in mirror_local.j3_reference_points else "")
		_action("J3_POINT_" + key, label, Rect2(230 + index * 500, 245, 460, 58), "j3_point", key)
		_hotspot_layer.get_node("J3_POINT_" + key).disabled = not mirror_local.j3_trace_placed
	var flip_label := ("Inspect back" if english else "뒷면 확인") if mirror_local.j3_page_side == "front" else ("Inspect front" if english else "앞면 확인")
	_action("J3_FLIP", flip_label, Rect2(230, 315, 700, 58), "j3_flip_page", null, false)
	_action("J3_COMPARE", "Compare points and text" if english else "기준점과 문장 대조", Rect2(990, 315, 700, 58), "j3_compare")
	for id in ["J3_FLIP", "J3_COMPARE"]: _hotspot_layer.get_node(id).disabled = not mirror_local.j3_trace_placed
	for index in range(4):
		var part: int = [2, 0, 3, 1][index]
		_action("J3_PART_%d" % part, MIRROR_TEXTS.j3_part(part, locale), Rect2(170 + (index % 2) * 860, 395 + (index / 2) * 125, 790, 115), "j3_pick_part", part, false)
		var button: Button = _hotspot_layer.get_node("J3_PART_%d" % part)
		button.toggle_mode = true
		button.set_pressed_no_signal(int(mirror_local.j3_held_part) == part)
		_queue_puzzle_surface(PUZZLE_NOTES.surface("J3_PART_%d" % part), MIRROR_TEXTS.j3_part(part, locale))
	var order: Array[String] = []
	for part in mirror_local["j3_order"]: order.append(MIRROR_TEXTS.j3_part(part, locale).split("\n")[0])
	_puzzle_surface_board(PUZZLE_NOTES.j3_order(mirror_local["j3_order"]), (" -> " if english else " → ").join(order), Rect2(240, 650, 1430, 88))
	if not mirror_local.j3_order.is_empty() and mirror_local.j3_order != [0, 1, 2, 3].slice(0, mirror_local.j3_order.size()):
		var underline := HSeparator.new()
		underline.name = "J3_ORDER_CONFLICT"
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotspot_layer.add_child(underline)
		_place(underline, Rect2(240, 735, 1430, 2))
	if int(mirror_local.j3_held_part) >= 0:
		for index in range(mirror_local.j3_order.size() + 1):
			var label := ("Before %d" if english else "%d번 앞") % (index + 1) if index < mirror_local.j3_order.size() else ("At the end" if english else "맨 뒤")
			_action("J3_DROP_%d" % index, label, Rect2(230 + index * 280, 755, 260, 48), "j3_drop_part", index, false)
	_action("J3_CLEAR", MIRROR_TEXTS.ui("j3_clear", locale), Rect2(300, 825, 610, 80), "j3_clear", null, false)
	_add_hotspot("J3_RESTORE", MIRROR_TEXTS.ui("j3_restore", locale), Rect2(1020, 825, 610, 80), _confirm_sheet_j3_restore)


func _open_j3_memory() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	if not _j3_memory_available(): return
	var replay := _j3_memory_seen()
	var descriptor := MODAL_NOTES.options("EP02_J3_MEMORY_REPLAY" if replay else "EP02_J3_MEMORY")
	var row := NOTEBOOK_CONTENT.definition(descriptor.content_id, descriptor.content_version)
	var localized: Dictionary = row.locales["en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"]
	_show_recorded_choice(localized.header, localized.prompt, [{"label": localized.option_0, "action": _select_j3_memory.bind("skip")}, {"label": localized.option_1, "action": _select_j3_memory.bind("replay" if replay else "read")}], descriptor)


func _j3_memory_available() -> bool:
	return session.stage() == "J3" and session.snapshot().loop_state.location_id == "M1_LIBRARY_INNER" and session.snapshot().meta_progress.knowledge_entries.get("MEM_FATHER_TEA_HAND_FRAGMENT") == "sensory_fragment" and _mirror().mirror_local().j3_reference_points.size() == 3


func _j3_memory_seen() -> bool:
	if session.snapshot().meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0046", false): return true
	return session.snapshot().meta_progress.dialogue_history.entries.any(func(entry: Dictionary) -> bool: return entry.get("record_class") == "authored" and entry.get("observation", {}).get("content_id") == "NB_EP02_J3_MEMORY_003")


func _select_j3_memory(mode: String) -> void:
	if not _j3_memory_available() or not _close_recorded_presentation_choice(): return
	if mode == "skip": _show_sheet_status("EP02_J3_UI_MEMORY_SKIP")
	elif mode == "read": _ep01_play("EP02_J3_MEMORY_001")
	elif mode == "replay" and _j3_memory_seen(): _ep01_play("EP02_J3_MEMORY_001", {"method": "_show_sheet_memory_replay_done", "args": []})


func _show_sheet_memory_replay_done() -> void:
	if _j3_memory_available() and _j3_memory_seen(): _show_sheet_status("EP02_J3_UI_MEMORY_REPLAY")


func _inspect_j3_locked() -> void:
	if _interaction_blocked() or not _notebook_surface_allowed(): return
	if session.snapshot().loop_state.location_id == "M1_LIBRARY_INNER" and int(session.snapshot().meta_progress.journal_stage) == 2 and not session.known("c5_info_complete"):
		_ep01_pages(["EP02_J3_UI_PAGE_LOCKED"])
