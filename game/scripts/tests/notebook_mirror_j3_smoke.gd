extends "res://scripts/tests/notebook_mirror_smoke.gd"


func run(tree: SceneTree) -> Dictionary:
	var previous_locale := TranslationServer.get_locale()
	_seed("J3")
	view = VIEW.new()
	view.configure_session(SLOT, "MORNING_ROUTE")
	tree.current_scene.add_child(view)
	await tree.process_frame
	view._dismiss_dialogue_for_test()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for memory in [false, true]:
			var state := _seed("J3")
			state.loop_state.location_id = "M1_LIBRARY_INNER"
			if memory: state.meta_progress.knowledge_entries.MEM_FATHER_TEA_HAND_FRAGMENT = "sensory_fragment"
			else: state.meta_progress.knowledge_entries.erase("MEM_FATHER_TEA_HAND_FRAGMENT")
			_install(state)
			_restore_j3(memory)
			_collect()
	view.queue_free()
	await tree.process_frame
	SaveManager.delete_test_slot(SLOT)
	TranslationServer.set_locale(previous_locale)
	return {"ok": errors.is_empty(), "errors": errors, "scope": "J3 authored notebook compatibility; two locales and both memory variants", "not_covered": ["choice_recovery_32_cases", "full_campaign", "OS_input"]}
