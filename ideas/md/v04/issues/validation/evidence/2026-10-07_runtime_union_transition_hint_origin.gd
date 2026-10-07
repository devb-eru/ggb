extends Node

const TEST := preload("res://scripts/tests/notebook_content_smoke.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
var failures: Array = []
var cases: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("ggb/build_flavor", "full")
	var test := TEST.new()
	for locale in ["ko-KR", "en-US"]:
		TranslationServer.set_locale(locale)
		for stage in TEST.LIVE_STAGES:
			var fixture := CHECKPOINTS.new().snapshot_for(stage)
			if not fixture.ok:
				failures.append(stage)
				continue
			var originals: Array = fixture.snapshot.meta_progress.dialogue_history.entries
			var fixture_unmapped: Array = originals.filter(func(entry: Dictionary) -> bool: return entry.record_class == "unmapped")
			var fixture_legacy: Array = originals.filter(func(entry: Dictionary) -> bool: return entry.record_class == "legacy")
			var old_feedback: Dictionary = fixture.snapshot.loop_state.event_local_states.CHAPTER_ONE.last_feedback
			var view: Node = test._new_view(get_tree(), stage)
			if view == null:
				failures.append(stage)
				continue
			await get_tree().process_frame
			var entries: Array = GameState.get_snapshot().meta_progress.dialogue_history.entries
			var unmapped := []
			for entry in entries:
				if entry.get("record_class") != "unmapped": continue
				unmapped.append({"payload":entry.legacy_payload,"context":entry.snapshot_context})
			var valid: bool = fixture_unmapped.is_empty() and fixture_legacy.size() == 51 \
				and old_feedback.get("notebook_feedback", []).is_empty() and unmapped.size() == 1
			if valid:
				valid = unmapped[0].context.node_id == stage \
					and unmapped[0].payload.line_id == "CH1_HISTORY_TRANSCRIPT" \
					and int(unmapped[0].payload.sequence) == 51
			if not valid: failures.append("LEGACY_STARTUP_ORIGIN:" + stage + ":" + locale)
			var row := {"stage":stage,"locale":locale,"fixture_unmapped":fixture_unmapped.size(),
				"fixture_legacy":fixture_legacy.size(),"has_authored_feedback":not old_feedback.get("notebook_feedback", []).is_empty(),
				"unmapped":unmapped,"ok":valid}
			cases.append(row)
			print("HINT_ORIGIN: " + JSON.stringify(row))
			view.queue_free()
			await get_tree().process_frame
	failures.append_array(test.errors)
	if cases.size() != 30: failures.append("CASE_COUNT")
	SaveManager.delete_test_slot(TEST.SLOT)
	print("HINT_ORIGIN_DIAGNOSTIC: " + JSON.stringify({"ok":failures.is_empty(),"errors":failures,"case_count":cases.size(),
		"scope":"LEGACY_CHECKPOINT_STARTUP_NOT_NP20_NEW_HINT_OR_FULL_PRODUCER_ACCEPTANCE"}))
	get_tree().quit(0 if failures.is_empty() else 1)
