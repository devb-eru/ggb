extends Node

var observations: Array = []

func _ready() -> void:
	child_entered_tree.connect(_watch_panel)
	_run.call_deferred()

func _watch_panel(node: Node) -> void:
	if not node.has_signal("view_changed"): return
	node.view_changed.connect(func() -> void:
		if not node._comparison_mode: return
		var left: Label = node._pair_panels[0].find_child("NotebookRetentionNotice", true, false)
		var right: Label = node._pair_panels[1].find_child("NotebookRetentionNotice", true, false)
		observations.append({"locale":node._locale, "left_exists":left != null, "left_visible":left != null and left.visible, "left_text":left.text if left != null else "", "right_exists":right != null, "right_visible":right != null and right.visible, "right_text":right.text if right != null else ""}))

func _run() -> void:
	var runner = preload("res://scripts/tests/notebook_browse_smoke.gd").new()
	await runner._test_retention_notice(get_tree())
	var locales: Array = observations.map(func(value: Dictionary) -> String: return value.locale)
	var actual_ok: bool = observations.size() >= 2 and "ko-KR" in locales and "en-US" in locales and observations.all(func(value: Dictionary) -> bool: return value.left_exists and value.left_visible and not value.left_text.is_empty() and value.right_exists and not value.right_visible and value.right_text.is_empty())
	var report := {"ok":runner.errors.is_empty() and actual_ok, "checks":runner.checks, "errors":Array(runner.errors), "observations":observations}
	var output := FileAccess.open("user://notebook_retention_scene_audit.json", FileAccess.WRITE)
	if output == null:
		push_error("Could not write the notebook retention audit report.")
		get_tree().quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("NOTEBOOK_RETENTION_SCENE_AUDIT: ", JSON.stringify(report))
	get_tree().quit(0 if report.ok else 1)
