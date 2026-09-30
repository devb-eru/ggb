extends SceneTree

const IRIS := preload("res://scripts/systems/iris_relationship.gd")
const F2 := preload("res://scripts/systems/researcher_confrontation.gd")
const WAKE := preload("res://scripts/systems/reality_wake.gd")
const STAY := preload("res://scripts/systems/stay_story.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	for bond in range(6):
		for alert in range(6):
			var expected := "direct_private" if bond >= 4 else ("indirect" if bond >= 2 else ("denied" if alert >= 4 else "withheld"))
			if IRIS.confession(bond, alert) != expected:
				failures.append("Private confession mismatch: %d/%d" % [bond, alert])
			var servants := {}
			for owner in ["edgar", "mara1", "luca", "iris", "mara2"]:
				servants[owner] = {"core_event_complete": false, "researcher_record_acquired": false, "bond": bond, "alert": alert}
			var state := {"meta_progress": {"servants": servants, "event_history": {}, "knowledge_entries": {}}}
			_check_ending_lines(state, "inferred_only", failures)
			if F2.iris_state(state) != "inferred_only":
				failures.append("Uncompleted Iris must not confess: %d/%d" % [bond, alert])
			servants["iris"]["core_event_complete"] = true
			_check_ending_lines(state, expected, failures)
			if F2.iris_state(state) != expected:
				failures.append("F2 current relationship mismatch: %d/%d" % [bond, alert])
			for owner in servants: servants[owner]["core_event_complete"] = true
			_check_ending_lines(state, "public", failures)
			var before := state.duplicate(true)
			if F2.iris_state(state) != "public":
				failures.append("All-complete public confession missing")
			if state != before: failures.append("Confession selection mutated state")
	if failures.is_empty(): print("IRIS_CONFESSION_SMOKE: PASS (36 relationship pairs; private, incomplete, completed, all-complete)")
	else: push_error("\n".join(failures))
	quit(0 if failures.is_empty() else 1)

func _check_ending_lines(state: Dictionary, expected: String, failures: Array[String]) -> void:
	var before := state.duplicate(true)
	var farewell: Dictionary = WAKE.farewell(state, "iris")
	var found := false
	for line in farewell["lines"]:
		if line["text"] == WAKE.IRIS[expected]: found = true
	if not found: failures.append("Reality farewell lost confession variant: " + expected)
	var stay: Array = STAY.table_lines(state, "iris")
	var markers := {"inferred_only":"외부 센서값", "denied":"동의하지", "withheld":"말하지 못한", "indirect":"멈출 권한", "direct_private":"둘이 나눈", "public":"모두 앞에서"}
	if markers[expected] not in stay.back()["text"]:
		failures.append("Stay table lost confession variant: " + expected)
	if state != before: failures.append("Ending text generation changed relationships")
