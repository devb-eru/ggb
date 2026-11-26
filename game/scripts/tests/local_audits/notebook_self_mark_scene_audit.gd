extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var runner = preload("res://scripts/tests/notebook_self_mark_smoke.gd").new()
	var result: Dictionary = await runner.run(get_tree())
	var report := {"ok":result.ok, "checks":runner.checks, "errors":Array(runner.errors)}
	var output := FileAccess.open("user://notebook_self_mark_scene_audit.json", FileAccess.WRITE)
	if output == null:
		push_error("Could not write the notebook self-mark audit report.")
		get_tree().quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("NOTEBOOK_SELF_MARK_SCENE_AUDIT: ", JSON.stringify(report))
	get_tree().quit(0 if report.ok else 1)
