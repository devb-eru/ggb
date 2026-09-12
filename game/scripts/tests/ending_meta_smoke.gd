extends SceneTree

const Store = preload("res://scripts/systems/ending_meta_store.gd")
var errors: Array[String] = []

func _initialize() -> void:
	var path := "user://__test_ending_meta_%s" % Time.get_ticks_usec()
	var store = Store.new(path)
	check(not store.commit_completed({})["ok"], "incomplete rejected")
	var reality := {"ending_run":{"branch_committed":true,"branch_id":"reality","completed_nodes":["EDR_FINAL_FRAME"],"all_ceremony_seen":true}}
	check(store.commit_completed(reality)["ok"], "reality commit")
	check(store.commit_completed(reality)["ok"], "idempotent")
	var stay := {"ending_run":{"branch_committed":true,"branch_id":"stay","completed_nodes":["EDS_FINAL_FRAME"]}}
	check(store.commit_completed(stay)["ok"], "stay commit")
	var file := FileAccess.open(path.path_join("ending_meta.json"), FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var meta: Dictionary = store.load_profile()["profile"]["ending_meta"]
	check(meta["reality_seen"] and meta["stay_seen"] and meta["reality_all_seen"] and not meta["stay_all_seen"], "recovery preserves union")
	check(store.commit_completed(stay)["ok"], "repair corrupt primary")
	file = FileAccess.open(path.path_join("ending_meta.json"), FileAccess.WRITE)
	file.store_string('{"ending_meta_profile_version":2}')
	file.close()
	check(not store.commit_completed(reality)["ok"], "future blocked")
	check(FileAccess.get_file_as_string(path.path_join("ending_meta.json")) == '{"ending_meta_profile_version":2}', "future preserved")
	for name in Store.FILES: DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if errors.is_empty(): print("ENDING_META_SMOKE: PASS")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
