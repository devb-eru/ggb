extends Control

var production_host: Control
var _reset_owner_generation := 0
var _reset_coordinator: ResetCoordinator

func request_sleep_transition(slot: String) -> Dictionary:
	return production_host.request_sleep_transition(slot)

func _ready() -> void:
	production_host = preload("res://scripts/systems/bootstrap.gd").new()
	_reset_coordinator = ResetCoordinator.new(GameState, SaveManager)
	production_host._reset_coordinator = _reset_coordinator
	call_deferred("run")

func run() -> void:
	var failed := false
	var suites: Array = ["full_campaign_smoke"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sheet-regression="): suites = [argument.trim_prefix("--sheet-regression=")]
	for path in suites:
		var test: RefCounted = load("res://scripts/tests/" + path + ".gd").new()
		var result: Dictionary = await test.run(get_tree())
		print("SHEET_REGRESSION ", path, " ", result)
		if not result.get("ok", false): failed = true
	print("SHEET_REGRESSION ", "FAIL" if failed else "PASS")
	production_host._audio.free()
	production_host._save_presentation.free()
	production_host.free()
	get_tree().quit(1 if failed else 0)
