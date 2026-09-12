extends SceneTree

const IRIS := preload("res://scripts/systems/iris_relationship.gd")
const F2 := preload("res://scripts/systems/researcher_confrontation.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	for bond in range(6):
		for alert in range(6):
			var expected := "direct_private" if bond >= 4 else ("indirect" if bond >= 2 else ("denied" if alert >= 4 else "withheld"))
			if IRIS.confession(bond, alert) != expected:
				failures.append("Private confession mismatch: %d/%d" % [bond, alert])
			var servants := {}
			for owner in ["edgar", "mara1", "luca", "iris", "mara2"]:
				servants[owner] = {"core_event_complete": false, "bond": bond, "alert": alert}
			var state := {"meta_progress": {"servants": servants}}
			if F2.iris_state(state) != "inferred_only":
				failures.append("Uncompleted Iris must not confess: %d/%d" % [bond, alert])
			servants["iris"]["core_event_complete"] = true
			if F2.iris_state(state) != expected:
				failures.append("F2 current relationship mismatch: %d/%d" % [bond, alert])
			for owner in servants: servants[owner]["core_event_complete"] = true
			var before := state.duplicate(true)
			if F2.iris_state(state) != "public":
				failures.append("All-complete public confession missing")
			if state != before: failures.append("Confession selection mutated state")
	if failures.is_empty(): print("IRIS_CONFESSION_SMOKE: PASS (36 relationship pairs; private, incomplete, completed, all-complete)")
	else: push_error("\n".join(failures))
	quit(0 if failures.is_empty() else 1)
