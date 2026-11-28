extends Node

const MAIN := preload("res://scenes/main/main.tscn")
var _errors: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	var menu: CanvasLayer = main._developer_panel
	var before := GameState.get_snapshot()
	var app_mode: int = main._start_screen.process_mode
	_key(KEY_F10)
	_expect(menu.panel.visible and main._start_screen.process_mode == Node.PROCESS_MODE_DISABLED, "F10 opens the real menu and suspends the current screen")
	menu._dialogue_preview_button.pressed.emit()
	var preview: Control = menu._dialogue_preview
	_expect(is_instance_valid(preview) and not menu.search.is_visible_in_tree(), "developer button opens the preview")
	await get_tree().process_frame
	var play: Button = preview.get_node("%Play")
	var sample: LineEdit = preview.get_node("%Sample")
	var text: OptionButton = preview.get_node("%TextEffect")
	var standing: OptionButton = preview.get_node("%StandingEffect")
	var screen: OptionButton = preview.get_node("%ScreenEffect")
	var motion: OptionButton = preview.get_node("%Motion")
	_expect(text.item_count == 5 and standing.item_count == 8 and screen.item_count == 6, "all text, standing and screen modes are available")

	sample.text = "잠깐… 지금 확인할 대사입니다."
	_select(standing, "bounce")
	_select(screen, "shake")
	play.pressed.emit()
	_expect(preview._body.text == sample.text and preview._body.visible_characters == 0 and preview._speaker.visible_characters == -1, "replay uses the real dialogue text animation")
	_expect(preview._background.material != null and preview._portrait.material != null, "screen shake is running in the preview")
	preview._hud.standing_effects._process(0.06)
	_expect(preview._portrait.position.y < 305.0, "standing effect can play alongside screen and text effects")

	_select(text, "emphasis")
	_select(standing, "expression")
	_select(screen, "flicker")
	_select(motion, "static")
	play.pressed.emit()
	_expect(preview._body.visible_characters == -1 and preview._portrait.texture != preview._base_texture, "static mode settles text and image swaps")
	_expect(preview._background.material == null and preview._hud.get_node("DialogueScreenOverlay").visible, "static mode clears shake and supports the protected local outline")
	preview.get_node("%Reset").pressed.emit()
	_expect(preview._portrait.texture == preview._base_texture and not preview._hud.get_node("DialogueScreenOverlay").visible, "reset restores the sample and clears screen treatment")

	_select(text, "pause")
	_select(standing, "focus")
	_select(screen, "vignette")
	_select(motion, "standard")
	sample.text_submitted.emit(sample.text)
	_expect(preview._speaker.text == "에드가" and preview._body.visible_characters == 0, "Enter replays and changes the speaker immediately")
	if "--capture-dialogue-preview" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.7).timeout
		preview._hud.text_effects.finish()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://dialogue-preview.png")

	preview.get_node("%Back").pressed.emit()
	_expect(menu._dialogue_preview == null and menu.search.is_visible_in_tree(), "back returns to the checkpoint list")
	_expect(main._start_screen.process_mode == Node.PROCESS_MODE_DISABLED, "the game remains suspended while the developer menu is open")
	menu._dialogue_preview_button.pressed.emit()
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	_expect(menu._dialogue_preview == null and not menu.panel.visible and main._start_screen.process_mode == app_mode, "Esc closes and resumes the previous screen")
	_expect(GameState.get_snapshot() == before, "preview does not change campaign state")
	print("DIALOGUE_PREVIEW_SMOKE: ", "PASS" if _errors.is_empty() else JSON.stringify(_errors))
	get_tree().quit(0 if _errors.is_empty() else 1)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)


func _select(button: OptionButton, key: String) -> void:
	for index in range(button.item_count):
		if button.get_item_metadata(index) == key:
			button.select(index)
			return
	_errors.append("Missing option: " + key)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
