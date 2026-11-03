extends "res://scripts/tests/notebook_prologue_presentation_smoke.gd"

const SHEET := preload("res://scripts/systems/prologue_sheet_script.gd")


func _drain(view: Node) -> void:
	for index in range(40):
		if not view._dialogue_active: return
		view._advance_dialogue()
	var line: Dictionary = view._dialogue_lines[view._dialogue_index]
	var published := CONTENT.presentation(line.get("notebook_content", {}), TranslationServer.get_locale())
	_expect(false, "dialogue did not terminate; status=%s speaker=%s text=%s published=%s" % [view._status_label.text, str(line.get("speaker")), str(line.get("text")), str(published)])


func run(tree: SceneTree) -> Dictionary:
	var previous_locale := TranslationServer.get_locale()
	var previous_flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		var view = _fresh(tree, SLOT)
		_expect(view._dialogue_texts.is_ready(), "all registered localized texts are ready: " + str(view._dialogue_texts.get_errors()))
		_drain(view)
		_prepare(view, "P3")
		view._show_p3_journal_choices()
		_pick(view, "author")
		_expect(view._dialogue_active and view._dialogue_lines.size() == 7, "P3 author answer includes all seven official rows")
		if view._dialogue_lines.size() != 7:
			view.queue_free()
			await tree.process_frame
			continue
		for index in range(view._dialogue_lines.size()):
			var identity: String = SHEET.response_ids("P3_A_AUTHOR")[index]
			var row := SHEET.node(identity)
			var line: Dictionary = view._dialogue_lines[index]
			_expect(line.text == view._dialogue_ui_text(identity) and line.portrait_position == row.portrait_position, "source text and portrait side match: " + identity)
			_expect(line.notebook_content.content_id == "NB_PR_" + identity, "new answer row has its own authored identity")
		_expect(view._dialogue_lines[1].speaker == "주인공" and view._dialogue_lines[1].portrait.is_empty(), "subject reply does not inherit Edgar's portrait")
		view._advance_dialogue()
		view = await _reload(tree, view)
		_expect(view._dialogue_active and view._dialogue_index == 1 and view._dialogue_lines.size() == 7, "expanded answer resumes the actual interrupted row")
		_drain(view)
		_expect(view._dialogue_choice_active and not view._progress.P3_complete, "P3 returns to its original question menu without completing the duty")
		_pick(view, "locked")
		_expect(view._dialogue_active and view._dialogue_lines.size() == 4 and view._dialogue_lines[3].speaker == "주인공", "locked-record answer includes the four-row exchange")
		_drain(view)
		_expect(_has_content("NB_PR_P3_A_AUTHOR_007") and _has_content("NB_PR_P3_A_LOCKED_004"), "last rows are actually observed, not just registered")
		view.queue_free()
		await tree.process_frame
		view = _fresh(tree, SLOT)
		_drain(view)
		_prepare(view, "P4")
		view._show_p4_father_choices()
		_pick(view, "father_tea")
		_expect(view._dialogue_active and view._dialogue_lines.size() == 6, "father-tea answer includes all six rows")
		_expect(not view._progress.P4_complete, "first answer row cannot prematurely complete tea duty")
		view._advance_dialogue()
		view = await _reload(tree, view)
		_expect(view._dialogue_active and view._dialogue_index == 1 and view._dialogue_lines.size() == 6 and not view._progress.P4_complete, "tea response resumes before completing unread added rows")
		_drain(view)
		_expect(view._progress.P4_complete and view._progress.p4_father_question == "father_tea", "full expanded tea response completes the original selected branch once")
		_expect(_has_content("NB_PR_P4_A_FATHER_TEA_006"), "final subject thought is actually observed")
		view.queue_free()
		await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(previous_locale)
	ProjectSettings.set_setting("ggb/build_flavor", previous_flavor)
	return {"ok": errors.is_empty(), "errors": errors, "checks": checks, "scope": "latest P3/P4 official response sequences, portrait metadata and interrupted saves in two locales"}
