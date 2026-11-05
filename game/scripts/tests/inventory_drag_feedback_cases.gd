extends RefCounted

const VIEW := preload("res://scenes/prologue/prologue.tscn")
const SLOT := "__test_inventory_drag_feedback"
var errors := PackedStringArray()
var checks := 0


func run(tree: SceneTree) -> Dictionary:
	var locale := TranslationServer.get_locale()
	for language in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(language)
		GameState.reset_for_test()
		var view = VIEW.instantiate()
		view.configure_session(SLOT, "P1_ENTRY", true)
		tree.current_scene.add_child(view)
		await tree.process_frame
		view._dismiss_dialogue_for_test()
		view._enter_room("M1_NORTH_ARCHIVE_HALL")
		view._dismiss_dialogue_for_test()
		_cancel_and_status_ownership(view)
		_portrait_drops(view)
		_tea_feedback(view)
		_window_feedback(view)
		view.queue_free()
		await tree.process_frame
	TranslationServer.set_locale(locale)
	return {
		"ok": errors.is_empty(), "checks": checks, "errors": errors,
		"coverage": "connected slot/target signals and synthetic DRAG_END, ko/en",
		"not_covered": ["OS_drag", "engine_drag_notification_delivery", "history_dispatch_wrapper", "async_save_cursor"],
	}


func _start(view: Node, item_id: String) -> Dictionary:
	for slot in view._inventory_slots:
		if String(slot.get_meta("item_id", "")) != item_id: continue
		# Same payload builder and drag_started signal as _get_drag_data, without a preview.
		var data: Dictionary = slot.get_drag_payload_for_test()
		_expect(data.get("item_id") == item_id, "slot produces requested item")
		_expect(view._selected_item == item_id, "connected start selects item")
		_expect(view._status_label.text == view._dialogue_ui_text("UI_INV_DRAGGING", {"item": slot.text.replace("\n", " ")}), "connected start shows localized drag feedback")
		return data
	_expect(false, "missing inventory source: " + item_id)
	return {}


func _end(view: Node) -> void:
	# Headless callback coverage only: not evidence of an OS drag or engine delivery.
	view.notification(Control.NOTIFICATION_DRAG_END)


func _cancel_and_status_ownership(view: Node) -> void:
	var before: Dictionary = view._progress.duplicate(true)
	view._set_status("idle feedback")
	_end(view)
	_expect(view._status_label.text == "idle feedback", "unowned end preserves idle status")
	_start(view, "LABEL_EDGAR")
	_end(view)
	_expect(view._status_label.text.is_empty(), "cancel clears owned drag status")
	_expect(view._selected_item == "LABEL_EDGAR", "cancel retains click-to-place selection")
	_expect(view._progress == before, "cancel does not change puzzle progress")
	for message in ["save error", "placement success", "save pending"]:
		_start(view, "LABEL_EDGAR")
		view._set_status(message)
		_end(view)
		_expect(view._status_label.text == message, "end preserves newer status: " + message)
		_end(view)
		_expect(view._status_label.text == message, "repeated end is harmless")
	_start(view, "LABEL_EDGAR")
	var same_text: String = view._status_label.text
	view._set_status(same_text)
	_end(view)
	_expect(view._status_label.text == same_text, "ownership is not inferred from string equality")
	_start(view, "LABEL_EDGAR")
	var target = view._hotspot_layer.get_node("PORTRAIT_0")
	var invalid := {"kind": "not_inventory", "item_id": "LABEL_EDGAR"}
	_expect(not target._can_drop_data(Vector2.ZERO, invalid), "target rejects malformed payload")
	target._drop_data(Vector2.ZERO, invalid)
	_end(view)
	_expect(view._status_label.text.is_empty() and view._progress == before, "rejected drop ends without placement or stale status")
	var valid := _start(view, "LABEL_EDGAR")
	target.set_drop_enabled(false)
	_expect(not target._can_drop_data(Vector2.ZERO, valid), "disabled target rejects valid payload")
	target._drop_data(Vector2.ZERO, valid)
	_end(view)
	_expect(view._status_label.text.is_empty() and view._progress == before, "disabled target does not leave drag feedback")
	target.set_drop_enabled(true)
	view._modal_active = true
	view._set_status("modal feedback")
	view._inventory_slots[0].get_drag_payload_for_test()
	_end(view)
	_expect(view._status_label.text == "modal feedback", "blocked start does not acquire status ownership")
	view._modal_active = false


func _portrait_drops(view: Node) -> void:
	var wrong := _start(view, "LABEL_EDGAR")
	view._hotspot_layer.get_node("PORTRAIT_1")._drop_data(Vector2.ZERO, wrong)
	_end(view)
	_expect(view._progress.p3b_placed.is_empty(), "wrong owner is not placed")
	_expect(view._dialogue_active and view._status_label.text.is_empty(), "wrong-owner dialogue survives end without stale drag status")
	view._dismiss_dialogue_for_test()
	for index in range(view.P3B_OWNERS.size()):
		var owner: String = view.P3B_OWNERS[index]
		var data := _start(view, "LABEL_" + owner)
		var target = view._hotspot_layer.get_node("PORTRAIT_%d" % index)
		_expect(target._can_drop_data(Vector2.ZERO, data), "portrait accepts inventory payload")
		target._drop_data(Vector2.ZERO, data)
		_expect(view._owner_at_portrait(index) == owner, "connected drop places owner " + owner)
		_end(view)
		_expect(view._status_label.text.is_empty(), "successful drop clears drag status " + owner)
		for slot in view._inventory_slots:
			_expect(slot.get_meta("item_id", "") != "LABEL_" + owner, "placed item removed from inventory")
	_expect(view._progress.P3B_complete, "all portrait placements complete")
	_expect(view._dialogue_active, "final completion dialogue remains active after drag end")
	_end(view)
	_expect(view._status_label.text.is_empty(), "final MARA2 drag status cannot leak into completion dialogue")
	view._dismiss_dialogue_for_test()


func _tea_feedback(view: Node) -> void:
	view._enter_room("M1_KITCHEN")
	view._dismiss_dialogue_for_test()
	var data := _start(view, "SPOON")
	view._hotspot_layer.get_node("TEA_0")._drop_data(Vector2.ZERO, data)
	var feedback: String = view._status_label.text
	_expect(not feedback.is_empty() and view.get("_inventory_drag_owns_status") != true, "wrong tea drop supplies its own feedback")
	_end(view)
	_expect(view._status_label.text == feedback, "drag end preserves actual wrong-tea feedback")
	data = _start(view, String(view.TEA_STEP_ITEMS[0]))
	view._hotspot_layer.get_node("TEA_0")._drop_data(Vector2.ZERO, data)
	feedback = view._status_label.text
	_expect(view._progress.tea_step == 1 and view.get("_inventory_drag_owns_status") != true, "correct tea drop supplies success feedback")
	_end(view)
	_expect(view._status_label.text == feedback and not feedback.is_empty(), "drag end preserves actual tea success feedback")


func _window_feedback(view: Node) -> void:
	view._enter_room("M1_PARLOR")
	view._dismiss_dialogue_for_test()
	view._on_window_pressed(0)
	var data := _start(view, "COARSE_BRUSH")
	view._window_drop_targets["TOP"]._drop_data(Vector2.ZERO, data)
	var feedback: String = view._window_feedback_label.text
	_expect(not feedback.is_empty(), "connected window drop supplies tool feedback")
	_end(view)
	_expect(view._window_feedback_label.text == feedback, "drag end preserves window feedback")
	_expect(view._status_label.text == feedback, "drag end preserves mirrored window status")
	_expect(view.get("_inventory_drag_owns_status") != true, "window drop releases drag status ownership")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: errors.append(TranslationServer.get_locale() + ": " + message)
