extends SceneTree

const OUTPUT := "res://data/notebook/fracture_surfaces_v1.json"
const TEXTS := preload("res://scripts/ui/fracture_surface_texts.gd")


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var contents := {}
	var sources := TEXTS.authored_rows()
	for key in sources:
		var source: Dictionary = sources[key]
		var options: bool = source.kind == "options_presented"
		var choice: bool = source.kind == "choice_confirmed"
		var row := {"producer_id": "NP09", "source_file": "scripts/ui/fracture_surface_texts.gd", "source_symbol": key, "event_id": "E2" if source.stage == "E2_INTRO" else source.stage,
			"node_ids": [source.stage], "action_or_variant": "selected" if choice else "displayed", "speaker_id": "SUBJECT" if choice else "SYSTEM",
			"location_source": "captured_at_actual_surface_display", "entry_kind": source.kind, "disclosure_owner": "actual_surface_or_choice_press", "mapping_status": "AUTHORED_ID", "owner": "planning/engineering",
			"visible_segment_ids": ["body"], "protection_reasons": ["choice" if choice else "choice_context" if options else "clue_source"], "localization_keys": {"body": key + ":body"}, "variables": {"body": {}},
			"locales": {"ko-KR": {"title": source.title[0], "summary": source.title[0], "speaker": "선택" if choice else "선택지" if options else "장면", "body": source.ko},
				"en-US": {"title": source.title[1], "summary": source.title[1], "speaker": "Selected" if choice else "Options" if options else "Scene", "body": source.en}}}
		contents[TEXTS.PREFIX + key] = {"1": row}
	if contents.size() != 50:
		push_error("Unexpected fracture surface count: " + str(contents.size()))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version": 1, "contents": contents}, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_FRACTURE_SURFACES_SEED: ", contents.size())
	quit()
