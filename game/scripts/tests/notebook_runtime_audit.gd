extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const FIELDS := ["producer", "content", "version", "node", "variant", "segment", "locale"]
var enabled := OS.is_debug_build() and "--notebook-producer-trace" in OS.get_cmdline_user_args()
var errors: Array[String] = []
var tuples := {}
var sampled := {}
var class_counts := {"authored":0,"legacy":0,"unmapped":0}


func capture(archive: Dictionary) -> void:
	if not enabled: return
	if not ARCHIVE.validate(archive).ok:
		errors.append("INVALID_SAMPLED_ARCHIVE")
		return
	for entry in archive.entries:
		var identity: String = JSON.stringify([entry.source_origin_id, entry.entry_uid], "", true)
		var immutable: Dictionary = entry.duplicate(true)
		immutable.erase("protection_reasons")
		var digest := JSON.stringify(preload("res://scripts/systems/notebook_surface_receipt.gd")._canonical(immutable), "", true, true).sha256_text()
		if sampled.has(identity):
			if sampled[identity] != digest: errors.append("CONFLICTING_SAMPLED_ENTRY")
			continue
		sampled[identity] = digest
		class_counts[entry.record_class] += 1
		if entry.record_class != "authored": continue
		if not CONTENT.render_entry(entry, "ko-KR").ok:
			errors.append("INVALID_AUTHORED_IDENTITY")
			continue
		var observation: Dictionary = entry.observation
		for segment in observation.segments:
			var tuple := [observation.producer_id, observation.content_id, int(observation.content_version), observation.node_id,
				observation.variant_id, segment.segment_id, segment.viewed_locale]
			tuples[JSON.stringify(tuple)] = true


func emit(suite: String, suite_ok: bool) -> Dictionary:
	if not enabled: return {"ok":true,"enabled":false}
	var keys := tuples.keys()
	keys.sort()
	var fingerprints := {}
	for path in CONTENT.CATALOGS:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty(): errors.append("MISSING_CATALOG_FINGERPRINT")
		fingerprints[path] = digest.to_lower()
	var result := {"schema_version":1,"suite_id":suite,"suite_ok":suite_ok,"ok":errors.is_empty(),"errors":errors,
		"tuple_fields":FIELDS,"tuples":preload("res://scripts/systems/notebook_surface_receipt.gd")._canonical(keys.map(func(key: String) -> Array: return JSON.parse_string(key))),
		"catalog_fingerprints":fingerprints,"sampled_entry_classes":class_counts,
		"source_corpus":_source_corpus(),
		"sample_basis":"unique entries in sampled committed archives, including prefilled fixtures",
		"new_unmapped_count":null,"excluded_ui_count":null,"required_branch_coverage":"NOT_AUDITED"}
	print("NOTEBOOK_RUNTIME_AUDIT: " + JSON.stringify(result))
	return result


func _source_corpus() -> Dictionary:
	var files: Array[String] = []
	_script_files("res://scripts", files)
	files.sort()
	var rows := PackedStringArray()
	for path in files: rows.append(path + "\t" + FileAccess.get_sha256(path).to_lower())
	return {"basis":"res://scripts/**/*.gd","file_count":files.size(),"sha256":"\n".join(rows).sha256_text()}


func _script_files(root: String, files: Array[String]) -> void:
	for name in DirAccess.get_files_at(root):
		if name.ends_with(".gd"): files.append(root.path_join(name))
	for name in DirAccess.get_directories_at(root): _script_files(root.path_join(name), files)
