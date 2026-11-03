extends RefCounted

const RULES := preload("res://data/puzzles/puzzle_black_mirror.tres")


static func wet_failure(category: String) -> String:
	return {"anchor_missing": "EP02_C4_FB_FAIL_ANCHOR", "entry_missing": "EP02_C4_FB_FAIL_ENTRY", "branch_incomplete": "EP02_C4_FB_FAIL_BRANCH", "branch_order_wrong": "EP02_C4_FB_FAIL_ORDER", "ring_direction_wrong": "EP02_C4_FB_FAIL_RING", "tool_confiscated": "EP02_C4_FB_FAIL_TOOL"}.get(category, "")

static func status(action: String, value: Variant, before: Dictionary, after: Dictionary) -> String:
	if action == "j3_pick_part" and after.get("j3_held_part", -1) != before.get("j3_held_part", -1): return "EP02_J3_UI_SENTENCE_PICK"
	if action == "j3_drop_part" and int(before.get("j3_held_part", -1)) >= 0 and int(after.get("j3_held_part", -1)) == -1: return "EP02_J3_UI_SENTENCE_DROP"
	if action == "c_pour_water_five":
		if int(after.mixture.water) == int(before.mixture.water) + 5 and after.mixture.water == 5 and after.mixture.stabilizer == 0 and after.mixture.active == 0:
			return "EP02_C3_UI_WATER_ADD_5"
		return ""
	if action == "c_pour" and value in RULES.MATERIALS:
		var old: Dictionary = before.mixture
		var mix: Dictionary = after.mixture
		if int(mix[value]) != int(old[value]) + 1: return ""
		var amount := int(mix[value])
		if value == "water" and mix.stabilizer == 0 and mix.active == 0 and amount <= 6: return "EP02_C3_UI_WATER_ADD_%d" % amount
		if value == "stabilizer" and amount <= 2 and (amount == 1 or mix.water >= 3): return "EP02_C3_UI_STAB_ADD_%d" % amount
		if value == "active" and amount <= 3 and (amount != 2 or mix.stabilizer == 1): return "EP02_C3_UI_ACTIVE_ADD_%d" % amount
	elif action == "c_rotate" and after.rotation != before.rotation:
		return "EP02_C4_UI_ROTATE_CW"
	elif action == "c_rotate_ccw" and after.rotation != before.rotation:
		return "EP02_C4_UI_ROTATE_CCW"
	elif action == "c_transparency" and after.get("overlay_transparency", "balanced") != before.get("overlay_transparency", "balanced"):
		return "EP02_C4_UI_ALPHA_LOW" if value == "low" else "EP02_C4_UI_ALPHA_HIGH"
	elif action == "c_anchor_other" and after.get("anchor_choice", "none") != before.get("anchor_choice", "none"):
		return "EP02_C4_UI_ANCHOR_OTHER"
	elif action == "c_flip" and after.flipped != before.flipped:
		return "EP02_C4_UI_FLIP_ON" if after.flipped else "EP02_C4_UI_FLIP_OFF"
	elif action == "c_anchor" and after.anchored and not before.anchored:
		return "EP02_C4_UI_ANCHOR_BOTTOM"
	elif action == "c_clear_plan" and not before.path.is_empty() and after.path.is_empty() and before.dry_passed:
		return "EP02_C4_UI_ROUTE_CLEAR"
	elif action == "c_segment" and after.path.size() == before.path.size() + 1:
		if value == "entry" and after.path.size() != 1: return ""
		return {"entry": "EP02_C4_UI_ROUTE_ENTRY", "short_branch": "EP02_C4_UI_ROUTE_SHORT", "long_branch": "EP02_C4_UI_ROUTE_LONG", "clockwise_ring": "EP02_C4_UI_ROUTE_RING_CW", "counterclockwise_ring": "EP02_C4_UI_ROUTE_RING_CCW"}.get(value, "")
	return ""

static func mixture_pages(local: Dictionary) -> Array:
	var mix: Dictionary = local.mixture
	if local.cleaner_ready: return ["EP02_C3_TEST_001"]
	if mix.foamy: return ["EP02_C3_FB_OVERMIX"]
	if mix.stabilizer > 0 and mix.active == 0 and not mix.dispersed: return ["EP02_C3_FB_DIFFUSION_WAIT"]
	if mix.mixed > 0: return ["EP02_C3_MIX_002"]
	if mix.water == 5 and mix.stabilizer == 1 and mix.active == 2 and mix.dispersed: return ["EP02_C3_ACTIVE_001"]
	if mix.stabilizer == 1 and mix.active == 0 and mix.dispersed: return ["EP02_C3_STABILIZER_001"]
	if mix.water == 5 and mix.stabilizer == 0 and mix.active == 0: return ["EP02_C3_WATER_001"]
	return ["EP02_C3_MIX_001"]

static func test_pages(local: Dictionary) -> Array:
	var mix: Dictionary = local.mixture
	var verdict: Dictionary = RULES.test_mixture(mix)
	if verdict.ok: return ["EP02_C3_TEST_001", "EP02_C3_FB_SUCCESS", "EP02_C3_SUCCESS_001"]
	var total := int(mix.water) + int(mix.stabilizer) + int(mix.active)
	if total == 0: return ["EP02_C3_FB_EMPTY"]
	if mix.stabilizer == 0 and mix.active == 0 and mix.water < 5: return ["EP02_C3_FB_WATER_LOW"]
	if mix.stabilizer == 0 and mix.active == 0 and mix.water > 5: return ["EP02_C3_FB_WATER_HIGH"]
	if verdict.category == "volume": return ["EP02_C3_FB_TOTAL_LOW" if total < 8 else "EP02_C3_FB_TOTAL_HIGH"]
	if verdict.category == "mixing": return ["EP02_C3_FB_OVERMIX" if mix.foamy else "EP02_C3_UI_MIX_READY"]
	if verdict.category == "order": return ["EP02_DOC_DISPOSE_003"]
	if verdict.category == "ratio":
		if mix.active > 2 and mix.stabilizer <= 1: return ["EP02_C3_FB_RATIO_ACID"]
		if mix.stabilizer > 1 and mix.active <= 2: return ["EP02_C3_FB_RATIO_BASE"]
	return ["EP02_C3_FAIL_001"]
