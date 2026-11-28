extends Node

var _errors: Array[String] = []


class RecordedChoiceView extends ChapterOneController:
	var selected := -1

	func _ready() -> void:
		_build_ui()

	func _recorded_choice_pressed(_context: Dictionary, index: int) -> void:
		selected = index


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TranslationServer.set_locale("ko-KR")
	var view := preload("res://scripts/prologue/prologue_controller.gd").new()
	view._test_mode = true
	add_child(view)
	view._dialogue_motion_mode = "standard"
	var line := "한글 é와 🇰🇷를 한 글자씩 표시합니다."
	view._show_dialogue([
		{"speaker": "주인공", "text": line, "screen_fx": {"kind": "shake"}, "standing_fx": {"kind": "bounce"}},
		{"speaker": "에드가", "text": "첫 구절 … 다음 구절", "text_fx": {"kind": "chunks", "chunk_words": 2, "pause_after": {"…": 0.4}, "emphasis": "다음"}},
		{"speaker": "에드가", "text": "즉시 표시", "text_fx": {"kind": "instant"}}
	])
	var text_label := view._dialogue_label
	var presenter = view._dialogue_layer.text_effects
	_check(text_label.text == line and text_label.visible_characters == 0, "default typewriter preserves full source and starts hidden")
	_check(view._speaker_label.text == "나" and view._speaker_label.visible_characters == -1, "speaker name is visible while dialogue starts typing")
	var boundaries: PackedInt32Array = presenter._reveals[text_label].characters
	_check(boundaries[3] == 5 and not 4 in boundaries, "combining glyphs reveal as a single character")
	_check(view._background.material != null and view._portrait.material != null, "screen shake reaches art on the normal path")
	var standing = view._dialogue_layer.standing_effects
	standing._process(0.06)
	var reaction = standing._animations.get(view._portrait.get_instance_id())
	_check(reaction != null and reaction.offset.y < 0.0, "standing reaction plays with screen shake")
	await get_tree().process_frame
	await get_tree().process_frame
	var input_rect := view._dialogue_next.get_global_rect()
	var rail_rect := view._inventory_panel.get_global_rect()
	await get_tree().create_timer(0.12).timeout
	_check(text_label.visible_characters > 0 and text_label.visible_characters < line.length(), "typewriter reveals progressively")
	_check(view._dialogue_next.get_global_rect() == input_rect and view._inventory_panel.get_global_rect() == rail_rect, "screen effects leave input and inventory fixed")
	view._open_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var before := text_label.visible_characters
	var paused_position := view._portrait.position
	await get_tree().create_timer(0.15).timeout
	_check(text_label.visible_characters == before and view._portrait.position == paused_position, "modal pauses text and standing")
	view._close_modal()
	view._dialogue_next.pressed.emit()
	_check(view._dialogue_index == 0 and text_label.visible_characters == -1, "first advance reveals full text")
	view._dialogue_next.pressed.emit()
	_check(view._dialogue_index == 1 and view._background.material == null, "next line clears old screen effect")
	_check(view._speaker_label.text == "에드가" and view._speaker_label.visible_characters == -1, "speaker changes are visible immediately")
	_check(text_label.self_modulate.a == 0.0, "emphasis renders via alternate styled text")
	var plan: Dictionary = presenter._reveals[text_label]
	_check(plan.characters.size() < text_label.text.length() and plan.times[-1] - plan.times[-2] >= 0.4, "chunk boundary and authored pause are scheduled: %s" % [Array(plan.times)])
	view._dialogue_next.pressed.emit()
	view._dialogue_next.pressed.emit()
	_check(view._dialogue_index == 2 and text_label.visible_characters == -1 and text_label.self_modulate.a == 1.0, "instant line clears emphasis")
	view._dialogue_next.pressed.emit()
	_check(not view._dialogue_active, "instant line closes on one advance")
	view._show_dialogue([{"speaker": "에드가", "text": "대사 본문이 아직 타이핑 중입니다."}])
	view._show_dialogue_choice_set("ep01_sleep", "", "에드가", "선택지 안내 문장입니다.", "EDGAR", ["confirm", "cancel"], {"confirm": {"label": "잠든다."}, "cancel": {"label": "아직 할 일이 있다."}})
	var button := view._dialogue_choice_buttons[1]
	_check(text_label.text == "선택지 안내 문장입니다." and text_label.visible_characters == -1, "choice prompt is fully shown after replacing a line mid-typing")
	_check(view._speaker_label.visible_characters == -1 and button.text == "아직 할 일이 있다." and button.get_child_count(true) == 0, "choice name and caption are fully shown")
	button.pressed.emit()
	_check(not view._dialogue_choice_active and not view._dialogue_layer.visible, "first choice press confirms the selection")
	view._dialogue_motion_mode = "static"
	view._show_dialogue([{"speaker": "주인공", "text": "정적 모드", "screen_fx": {"kind": "shake"}, "standing_fx": {"kind": "flinch"}}])
	_check(text_label.visible_characters == -1 and view._background.material == null, "static mode shows full text and suppresses shake")
	view.queue_free()
	await get_tree().process_frame
	_check_recorded_choice()
	await get_tree().process_frame
	print("DIALOGUE_EFFECTS_SMOKE: ", "PASS" if _errors.is_empty() else JSON.stringify(_errors))
	get_tree().quit(0 if _errors.is_empty() else 1)


func _check_recorded_choice() -> void:
	var view := RecordedChoiceView.new()
	view._test_mode = true
	add_child(view)
	view._present_recorded_modal({"title": "기록 확인", "body": "항목을 고르세요.", "actions": [{"label": "확인"}], "view": {}, "focus": 0})
	var button := view._modal_buttons[0]
	_check(view._modal_title.text == "기록 확인" and view._modal_title.visible_characters == -1, "chapter choice title is fully shown")
	_check(view._modal_text.text == "항목을 고르세요." and view._modal_text.visible_characters == -1, "chapter choice prompt is fully shown")
	_check(button.text == "확인" and button.get_child_count(true) == 0, "chapter choice caption is fully shown")
	button.pressed.emit()
	_check(view.selected == 0, "chapter choice confirms on the first press")
	view.queue_free()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_errors.append(description)
