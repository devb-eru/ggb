extends SceneTree

const RULES := preload("res://scripts/systems/core_overlay.gd")

func _initialize() -> void:
	var failures: Array = []
	var solutions := 0
	for b in range(8):
		for c in range(8):
			var state := RULES.initial()
			for layer in RULES.LAYERS: state[layer]["anchor"] = 0
			state["B4"]["turn"] = b % 4
			state["B4"]["flip"] = b >= 4
			state["C5"]["turn"] = c % 4
			state["C5"]["flip"] = c >= 4
			if RULES.evaluate(state)["aligned"]:
				solutions += 1
				if b != 2 or c != 7: failures.append("Unexpected solution")
	if solutions != 1: failures.append("Expected unique transform among 64 combinations")
	var state := RULES.initial()
	var before := state.duplicate(true)
	RULES.act(state, "rotate", "B4")
	if state != before: failures.append("Mutated input snapshot")
	if RULES.act(state, "rotate", "D4")["ok"]: failures.append("D4 must stay fixed")
	for layer in RULES.LAYERS: state = RULES.act(state, "anchor", layer, 0)["state"]
	if RULES.evaluate(state)["aligned"]: failures.append("Anchors alone must not solve")
	for i in range(2): state = RULES.act(state, "rotate", "B4")["state"]
	state = RULES.act(state, "flip", "C5")["state"]
	for i in range(3): state = RULES.act(state, "rotate", "C5")["state"]
	state = RULES.act(state, "verify")["state"]
	if not state["locked"] or state["complete"]: failures.append("Alignment must lock but require investigation")
	if RULES.act(state, "inspect", "", "AUTH")["ok"]: failures.append("Investigation order bypass")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	for point in RULES.INVESTIGATION: restored = RULES.act(restored, "inspect", "", point)["state"]
	if not restored["complete"]: failures.append("Investigation did not complete after serialization")
	if failures.is_empty(): print("CORE_OVERLAY_SMOKE: PASS")
	else: push_error(str(failures))
	quit(0 if failures.is_empty() else 1)
