extends Node

const VIEW := preload("res://scripts/prologue/prologue_controller.gd")
const ACTIONS := ["live", "generation", "close", "free", "queued", "detach", "reenter", "replacement", "hidden", "scroll_free"]
var errors: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value: errors.append(message)


func _fixture() -> Control:
	var view := VIEW.new()
	view.configure_session("__test_scroll_lifetime", "P1_ENTRY", true)
	get_tree().root.add_child(view)
	view._dismiss_dialogue_for_test()
	view._show_modal("fixture", "", [])
	var scroll := ScrollContainer.new()
	scroll.name = "HistoryTranscriptScroll"
	scroll.custom_minimum_size = Vector2(300, 80)
	view._modal_body.add_child(scroll)
	var label := Label.new()
	label.text = "fixture\n".repeat(100)
	label.custom_minimum_size.y = 2000
	scroll.add_child(label)
	view._history_selected = "ALL"
	view._history_scroll_positions["ALL"] = 42
	return view


func _run() -> void:
	await get_tree().process_frame
	for action in ACTIONS:
		var view := _fixture()
		await get_tree().process_frame
		await get_tree().process_frame
		var scroll: ScrollContainer = view._history_modal_scroll()
		_expect(scroll != null, "actual history scroll exists: " + action)
		view._restore_history_scroll(weakref(scroll), "ALL", view._history_generation)
		match action:
			"generation": view._history_generation += 1
			"close": view._close_modal()
			"free": view.free()
			"queued": view.queue_free()
			"detach": get_tree().root.remove_child(view)
			"reenter":
				get_tree().root.remove_child(view)
				get_tree().root.add_child(view)
			"replacement":
				view._modal_body.remove_child(scroll)
				var replacement := ScrollContainer.new()
				replacement.name = "HistoryTranscriptScroll"
				view._modal_body.add_child(replacement)
			"hidden": view.hide()
			"scroll_free": scroll.free()
		await get_tree().process_frame
		await get_tree().process_frame
		if action not in ["free", "queued"]:
			if action == "live": _expect(scroll.scroll_vertical == 42, "live history restores saved position")
			elif action not in ["close", "scroll_free"]: _expect(scroll.scroll_vertical == 0, "stale history does not change scroll: " + action)
			if action == "detach": get_tree().root.add_child(view)
			if action == "replacement": scroll.free()
			view.queue_free()
			await get_tree().process_frame
	print("LEGACY_SCROLL_LIFETIME: ", JSON.stringify({"ok": errors.is_empty(), "checks": checks, "errors": errors, "cases": ACTIONS.size()}))
	get_tree().quit(0 if errors.is_empty() else 1)
