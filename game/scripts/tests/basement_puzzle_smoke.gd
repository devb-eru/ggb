extends SceneTree

const RULES := preload("res://data/puzzles/puzzle_basement.tres")
var errors := PackedStringArray()

func _initialize() -> void:
	var overlay_solutions := 0
	for rotation in [0, 90, 180, 270]:
		for flipped in [true, false]:
			for anchor in ["bedroom", "greenhouse", "great_clock"]:
				if RULES.inspect_overlay(rotation, flipped, anchor)["ok"]: overlay_solutions += 1
	_expect(overlay_solutions == 1, "D0-A unique overlay")
	var original := RULES.axis_default()
	var untouched := original.duplicate(true)
	var result := RULES.axis_action(original, "push", "line", false)
	_expect(not result["ok"] and result["state"] == original, "D1 push requires explicit confirmation")
	result = RULES.axis_action(original, "push", "line", true)
	_expect(result["hard_failure"] and result["state"]["failure"]["category"] == "depth_wrong", "D1 wrong depth locks device")
	_expect(original == untouched, "resource never mutates caller snapshot")
	_expect(not RULES.axis_action(result["state"], "depth", ["line", 2])["ok"], "locked device cannot be repaired locally")
	var state := RULES.axis_default()
	state = RULES.axis_action(state, "depth", ["line", 2])["state"]
	state = RULES.axis_action(state, "push", "line", true)["state"]
	result = RULES.axis_action(state, "push", "ring", true)
	_expect(result["state"]["failure"]["verified_depths"] == {"line": 2}, "failure retains only verified prior axes")
	state = RULES.axis_action(state, "push", "branch", true)["state"]
	state = RULES.axis_action(state, "depth", ["ring", 3])["state"]
	state = RULES.axis_action(state, "push", "ring", true)["state"]
	result = RULES.axis_action(state, "central", "counterclockwise", true)
	_expect(not result["hard_failure"] and not result["state"]["open"], "first reverse input warns even if confirmed")
	state = result["state"]
	_expect(RULES.axis_action(state, "central", "counterclockwise", true)["hard_failure"], "reverse insistence locks device")
	_expect(RULES.axis_action(state, "central", "clockwise", true)["state"]["open"], "reverse warning still permits correct direction")
	var successes := 0
	for a in range(4):
		for b in range(4):
			for c in range(4):
				var heart := RULES.heart_default()
				for index in range(a): heart = RULES.heart_action(heart, "turn", "A")["state"]
				for index in range(b): heart = RULES.heart_action(heart, "turn", "B")["state"]
				for index in range(c): heart = RULES.heart_action(heart, "turn", "C")["state"]
				if RULES.heart_action(heart, "fix")["ok"]: successes += 1
	_expect(successes == 1, "D4 unique ring state from modular handle counts")
	var heart := RULES.heart_default()
	_expect(not RULES.heart_action(heart, "wind")["ok"], "unaligned heart cannot power on")
	for handle in ["A", "B", "C", "C", "A", "A", "A", "A"]:
		heart = RULES.heart_action(heart, "turn", handle)["state"]
	_expect(heart["rings"] == [1, 2, 3], "longer equivalent solution allowed")
	heart = RULES.heart_action(heart, "fix")["state"]
	heart = RULES.heart_action(heart, "unfix")["state"]
	heart = RULES.heart_action(heart, "fix")["state"]
	_expect(not RULES.heart_action(heart, "unfix")["ok"], "only one pre-power unlock")
	for index in range(12): heart = RULES.heart_action(heart, "wind")["state"]
	_expect(not heart["filter_off"], "XII alone cannot trigger D5")
	heart = RULES.heart_action(heart, "stabilize")["state"]
	_expect(not heart["filter_off"], "normal stabilization is not filter release")
	heart = RULES.heart_action(heart, "inspect_auxiliary")["state"]
	_expect(not RULES.heart_action(heart, "pull_auxiliary", null, false)["ok"], "auxiliary input remains cancelable")
	heart = RULES.heart_action(heart, "pull_auxiliary", null, true)["state"]
	_expect(heart["filter_off"], "XII plus explicit auxiliary releases filter")
	_expect(not RULES.heart_action(heart, "reset")["ok"], "filter release is terminal for heart puzzle")
	if errors.is_empty():
		print("BASEMENT_PUZZLE_SMOKE: PASS")
		quit(0)
	else:
		push_error("BASEMENT_PUZZLE_SMOKE: FAIL " + str(errors))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
