extends SceneTree

const MISSING_CATALOG_PATH := "user://__test_missing_audio_registry.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := preload("res://scripts/systems/game_audio.gd").new()
	root.add_child(audio)
	assert(audio._catalog.has("AUD_SIG_LUCA"))
	assert(not audio.request_cue(&"AUD_SIG_LUCA"))
	assert(not audio.request_cue(&"UNKNOWN"))
	if FileAccess.file_exists(MISSING_CATALOG_PATH):
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(MISSING_CATALOG_PATH)) == OK)
	assert(not audio.load_catalog(MISSING_CATALOG_PATH))
	assert(audio._catalog.has("AUD_SIG_LUCA"))
	var stream := AudioStreamGenerator.new()
	assert(audio.play_cue(&"old_room", stream, &"AMB"))
	audio.enter_room("M1_KITCHEN")
	assert(audio._voices.is_empty())
	assert(audio.play_cue(&"current_room", stream, &"AMB"))
	audio.enter_room("M1_KITCHEN")
	assert(audio._voices.has(&"current_room"))
	audio.stop_all()
	assert(not audio.play_cue(&"missing", null, &"SFX"))
	assert(not audio.play_cue(&"invalid", stream, &"VOICE"))
	assert(audio.play_cue(&"room", stream, &"AMB"))
	assert(not audio.play_cue(&"room", stream, &"AMB"))
	assert(audio.play_cue(&"next_room", stream, &"AMB"))
	assert(audio._voices.size() == 1 and not audio._voices.has(&"room"))
	for i in range(26):
		assert(audio.play_cue(StringName("sfx_%d" % i), stream, &"SFX"))
	assert(not audio.play_cue(&"overflow", stream, &"SFX"))
	audio.set_pause_reason(&"menu", true)
	audio.set_pause_reason(&"focus", true)
	audio.set_pause_reason(&"focus", false)
	assert(audio._voices[&"next_room"].player.stream_paused)
	audio.set_pause_reason(&"menu", false)
	assert(not audio._voices[&"next_room"].player.stream_paused)
	assert(audio.set_levels(0.5, 1.0, 0.5, 1.0, false))
	assert(is_equal_approx(audio._voices[&"next_room"].player.volume_db, linear_to_db(0.25)))
	assert(not audio.set_levels(NAN, 1.0, 1.0, 1.0, false))
	assert(audio.set_levels(1.0, 1.0, 1.0, 1.0, true))
	assert(audio._voices[&"next_room"].player.volume_linear == 0.0)
	await create_timer(0.2).timeout
	audio.stop_all()
	assert(audio._voices.is_empty())
	await process_frame
	assert(audio.get_child_count() == 0)
	audio.queue_free()
	await create_timer(0.2).timeout
	print("GAME AUDIO SMOKE: PASS")
	quit()
