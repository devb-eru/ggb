extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const QUERY := preload("res://scripts/systems/notebook_query.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
var errors := PackedStringArray()
var checks := 0
var covered := {}
var producers := {}
var catalogs := {}
var definitions := 0
var partial_cases := 0
var withheld_fields := 0
var identifier := RegEx.new()


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)


func run() -> Dictionary:
	identifier.compile("(?<![A-Za-z0-9_])(?:NB_[A-Z0-9_]+|REC_[A-Z0-9_]+|[A-FJP][0-9]+(?:[_-][A-Z0-9]+)*)(?![A-Za-z0-9_])")
	var game_before := GameState.get_snapshot()
	var seen := {}
	for path in CONTENT.CATALOGS:
		var text := FileAccess.get_file_as_string(path)
		catalogs[path] = text.sha256_text()
		var document: Variant = JSON.parse_string(text)
		_expect(document is Dictionary and document.get("contents") is Dictionary, "read product catalog: " + path)
		if not document is Dictionary or not document.get("contents") is Dictionary: continue
		for id in document.contents:
			for version in document.contents[id]:
				var key := "%s:%s" % [id, version]
				_expect(not seen.has(key), "unique authored version: " + key)
				seen[key] = true
				var row: Dictionary = document.contents[id][version]
				_expect(CONTENT.definition(id, int(version)) == row, "loaded definition matches product file: " + key)
				definitions += 1
				producers[row.producer_id] = int(producers.get(row.producer_id, 0)) + 1
				_test_definition(id, int(version), row)
	for index in range(1, 22):
		_expect(producers.has("NP%02d" % index), "registered story producer included: NP%02d" % index)
	_expect(not producers.has("NP22"), "gallery and developer consumers do not create story definitions")
	_expect(covered.size() == definitions * 2, "every registered meaning version reaches both locale checks")
	for path in catalogs:
		_expect(FileAccess.get_file_as_string(path).sha256_text() == catalogs[path], "catalog is never rewritten: " + path)
	_expect(GameState.get_snapshot() == game_before, "catalog audit never changes live gameplay")
	print("NOTEBOOK_METADATA_AUDIT: ", JSON.stringify({"catalogs":catalogs, "definitions":definitions,
		"definition_locale_pairs":covered.size(), "proper_subset_locale_cases":partial_cases,
		"withheld_internal_metadata_fields":withheld_fields,
		"producer_definitions":producers, "checks":checks, "errors":errors,
		"scope":"CATALOG_METADATA_AND_QUERY_FIXTURES_NOT_CONTROLLER_BRANCH_COVERAGE"}))
	print("NOTEBOOK_METADATA_CHECKS: ", checks)
	return {"ok":errors.is_empty(), "errors":errors}


func _sample_parts(row: Dictionary) -> Dictionary:
	var result := {}
	for segment in row.visible_segment_ids:
		var values := {}
		for name in row.variables[segment]:
			var type: String = row.variables[segment][name]
			if type.begins_with("enum:"):
				var options: Array = row.enums[type.trim_prefix("enum:")]["ko-KR"].keys()
				options.sort()
				values[name] = options[0]
			elif type == "int": values[name] = 2
			elif type == "float": values[name] = 0.5
			elif type == "bool": values[name] = true
			else: values[name] = "Archived fixture quotation"
		result[segment] = values
	return result


func _test_definition(id: String, version: int, row: Dictionary) -> void:
	var descriptor := CONTENT.descriptor(id, version, _sample_parts(row))
	var context := {"node_id":row.node_ids[0], "location_id":"M1_LIBRARY_OUTER", "chapter_id":"PROLOGUE",
		"event_occurrence_id":ARCHIVE.new_uid(), "conversation_session_id":ARCHIVE.new_uid(), "presentation_token":ARCHIVE.new_uid()}
	var shown := CONTENT.presentation(descriptor, "ko-KR")
	_expect(shown.ok, "representative authored presentation: %s:%d" % [id, version])
	if not shown.ok: return
	var captured := CONTENT.observe(descriptor, context, shown.speaker, shown.text, "ko-KR")
	_expect(captured.ok, "valid catalog observation: %s:%d" % [id, version])
	if not captured.ok: return
	var observation: Dictionary = JSON.parse_string(JSON.stringify(captured.observation))
	var original: Dictionary = observation.duplicate(true)
	var isolated := CONTENT.definition(id, version)
	isolated.locales["ko-KR"].title = "MUTATED_COPY_SENTINEL"
	_expect(CONTENT.definition(id, version) == row, "public definition remains an isolated copy: %s:%d" % [id, version])
	for locale in ["ko-KR", "en-US"]:
		var label := "%s:%d:%s" % [id, version, locale]
		var metadata := CONTENT.review_metadata(observation, locale)
		_expect(metadata.ok and not metadata.get("fallback", true), "available version metadata: " + label)
		if not metadata.ok: continue
		for field in ["title", "summary", "speaker"]:
			_expect(identifier.search(metadata[field]) == null, "no internal identifier in public " + field + ": " + label)
			var original_value: String = row.locales[locale][field]
			if identifier.search(original_value) == null:
				_expect(metadata[field] == original_value, "public authored metadata is not erased: " + label + ":" + field)
			else:
				withheld_fields += 1
		var replay := CONTENT.render_entry({"record_class":"authored", "observation":observation}, locale)
		var expected := CONTENT.presentation(descriptor, locale)
		_expect(replay.ok and expected.ok, "old and current meanings remain renderable: " + label)
		if replay.ok and expected.ok:
			_expect(replay.entry.segments.size() == expected.segments.size(), "same visible segment count: " + label)
			for index in range(expected.segments.size()):
				_expect(replay.entry.segments[index].text == expected.segments[index].text, "original version text preserved: " + label)
				var selected := CONTENT.render_segment({"record_class":"authored", "observation":observation}, expected.segments[index].segment_id, locale)
				_expect(selected.ok and selected.entry.segments == [replay.entry.segments[index]], "single segment equals full render without sibling disclosure: " + label)
		_expect(CONTENT.definition(id, version) == row, "rendering never mutates shared catalog: " + label)
		_test_query(observation, locale, metadata, label)
		covered[label] = true
		if observation.segments.size() > 1:
			for index in range(observation.segments.size()):
				var partial: Dictionary = observation.duplicate(true)
				partial.segments = [observation.segments[index].duplicate(true)]
				_test_partial(partial, locale, label + ":single:%d" % index)
				if observation.segments.size() > 2:
					partial = observation.duplicate(true)
					partial.segments.remove_at(index)
					_test_partial(partial, locale, label + ":missing:%d" % index)
	_expect(observation == original, "language and metadata queries preserve captured observation: %s:%d" % [id, version])
	if definitions == 1: _test_rejection_and_fallback(observation)


func _test_rejection_and_fallback(observation: Dictionary) -> void:
	for locale in ["ko-KR", "en-US"]:
		var unknown: Dictionary = observation.duplicate(true)
		unknown.content_version = 999
		var before: Dictionary = unknown.duplicate(true)
		var metadata := CONTENT.review_metadata(unknown, locale)
		_expect(metadata.ok and metadata.get("fallback", false) and metadata.get("summary") == "" and metadata.get("speaker") == "", "unavailable meaning cannot borrow current metadata")
		var replay := CONTENT.render_entry({"record_class":"authored", "observation":unknown}, locale)
		_expect(replay.ok and replay.entry.fallback, "unavailable meaning preserves recorded fallback")
		if replay.ok:
			for index in range(unknown.segments.size()):
				_expect(replay.entry.segments[index].text == unknown.segments[index].captured_text, "fallback does not reconstruct from present-day state")
				var selected := CONTENT.render_segment({"record_class":"authored", "observation":unknown}, unknown.segments[index].segment_id, locale)
				_expect(selected.ok and selected.entry.segments == [replay.entry.segments[index]], "single unavailable version preserves exact captured fallback")
		_expect(unknown == before, "fallback leaves captured meaning and source unchanged")
		var duplicate: Dictionary = observation.duplicate(true)
		duplicate.segments.append(duplicate.segments[0].duplicate(true))
		_expect(not CONTENT.review_metadata(duplicate, locale).ok, "duplicate segments cannot pretend complete disclosure")
		_expect(not CONTENT.render_segment({"record_class":"authored", "observation":duplicate}, observation.segments[0].segment_id, locale).ok, "single render rejects duplicate siblings before selection")
		var malformed := observation.duplicate(true)
		malformed.segments.append({"segment_id":"BROKEN_SIBLING"})
		_expect(not CONTENT.render_segment({"record_class":"authored", "observation":malformed}, observation.segments[0].segment_id, locale).ok, "single render validates unselected sibling schema")
		_expect(not CONTENT.render_segment({"record_class":"authored", "observation":observation}, "NOT_DISCLOSED", locale).ok, "single render cannot reconstruct undisclosed segment")
		var wrong_owner: Dictionary = observation.duplicate(true)
		wrong_owner.producer_id = "OTHER_PRODUCER"
		_expect(not CONTENT.review_metadata(wrong_owner, locale).ok, "metadata cannot borrow another producer identity")


func _test_partial(observation: Dictionary, locale: String, label: String) -> void:
	var metadata := CONTENT.review_metadata(observation, locale)
	var generic := "보관된 기록" if locale == "ko-KR" else "Archived record"
	_expect(metadata.ok and metadata.get("title") == generic and metadata.get("summary") == "", "partial disclosure cannot expose whole-document metadata: " + label)
	partial_cases += 1


func _test_query(observation: Dictionary, locale: String, metadata: Dictionary, label: String) -> void:
	var appended := ARCHIVE.append_observation(ARCHIVE.create(), observation, 0)
	_expect(appended.ok, "single-observation archive: " + label)
	if not appended.ok: return
	var archive: Dictionary = appended.archive
	var before := JSON.stringify(archive)
	var query := QUERY.new()
	var scope := {"namespace":"test", "slot":"__test_metadata", "run_id":"metadata-audit", "source_origin_id":archive.source_origin_id,
		"branch_id":archive.branch_id, "load_epoch":1}
	var opened: Dictionary = query.open(archive, KNOWLEDGE.create(), scope, locale)
	_expect(opened.ok, "real read model: " + label)
	if opened.ok:
		for segment in observation.segments:
			var key: String = query.reference_key(ARCHIVE.make_reference(archive.entries[0], segment.segment_id))
			var detail: Dictionary = query.detail(key, query.cache_key())
			_expect(detail.ok and detail.get("title") == metadata.title and detail.get("summary") == metadata.summary, "query uses reviewed metadata, not raw catalog title: " + label)
	query.close()
	_expect(JSON.stringify(archive) == before, "query leaves archive and source references unchanged: " + label)
