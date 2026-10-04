extends RefCounted

const COVERAGE := preload("res://scripts/tests/notebook_puzzle_coverage.gd")
const SUITES := {
	"mirror": preload("res://scripts/tests/notebook_mirror_smoke.gd"),
	"basement": preload("res://scripts/tests/notebook_basement_smoke.gd"),
	"puzzle-surfaces": preload("res://scripts/tests/notebook_puzzle_surfaces_smoke.gd"),
}


func run(tree: SceneTree) -> Dictionary:
	var coverage := COVERAGE.new()
	var errors := PackedStringArray()
	var reports := {}
	var counts := {}
	for owner in SUITES:
		print("PUZZLE_AUDIT_PHASE: ", owner)
		var suite = SUITES[owner].new()
		var result: Dictionary = await suite.run(tree)
		errors.append_array(result.get("errors", []))
		if not result.get("ok", false): errors.append("failed suite: " + owner)
		errors.append_array(suite.coverage.errors)
		reports[owner] = suite.coverage.seen.duplicate()
		counts[owner] = reports[owner].size()
		print("PUZZLE_AUDIT_SUITE: ", owner, " ok=", result.get("ok", false), " observed tuples=", counts[owner])
	reports.historical = coverage.historical_report()
	var historical_count: int = reports.historical.size()
	errors.append_array(coverage.errors)
	errors.append_array(coverage.missing(reports))
	var guards := 0
	if errors.is_empty():
		for owner in reports:
			var key: String = reports[owner].keys()[0]
			var omitted := reports.duplicate(true)
			omitted[owner].erase(key)
			if coverage.missing(omitted).is_empty(): errors.append("missing segment accepted: " + owner)
			else: guards += 1
			var reassigned := omitted.duplicate(true)
			var other := "mirror" if owner != "mirror" else "basement"
			reassigned[other][key] = true
			if coverage.missing(reassigned).is_empty(): errors.append("wrong owner accepted: " + owner)
			else: guards += 1
	return {"ok": errors.is_empty(), "errors": errors, "catalog_version_variant_segment_locale_tuples": coverage.required.size(),
		"actual_owned_tuples": counts, "historical_fixture_tuples": historical_count, "rejected_coverage_mutations": guards,
		"not_covered": ["full_campaign_v2_regression", "OS_input", "visual_assets", "all_dynamic_combinations_as_actual_input"]}
