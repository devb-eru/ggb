extends RefCounted

# Deterministic, test-only workloads. They are never installed as player saves.
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const SEED := "ggb-notebook-perf-v1"
const IDS := ["NB-PERF-N2000", "NB-PERF-L10000", "NB-PERF-P2001", "NB-PERF-LONG"]
const NORMAL := ["NB_PR_P1_INSPECT_BED", "NB_PR_P1_INSPECT_WINDOW"]
const EXTRAS := ["NB_MODAL_CH1_MARK_OPTIONS", "NB_MODAL_CH1_MARK_SELECT_0", "NB_HINT_B3_A_H1",
	"NB_CH1_NOTE_B4", "NB_MIRROR_NOTE_C5_INFO", "NB_BASEMENT_NOTE_D4"]
const LONG_ID := "TEST_NOTEBOOK_PERF_LONG_V1"
const HIDDEN := "UNSEEN_BACKPAGE_PERF_SENTINEL"
const LONG_BYTES := 32768


static func uid(label: String) -> String:
	return (SEED + ":" + label).sha256_text().left(32)


static func _sized(prefix: String, bytes: int) -> String:
	var remainder := bytes - prefix.to_utf8_buffer().size()
	return prefix + "x".repeat(remainder)


static func install_content() -> void:
	CONTENT.diagnostics()
	var row := CONTENT.definition(NORMAL[0], 1)
	row.entry_kind = "document_segment"
	row.action_or_variant = "perf_public_pages"
	row.protection_reasons = ["document"]
	row.visible_segment_ids = ["front", "back", "hidden"]
	row.variables = {"front":{}, "back":{}, "hidden":{}}
	row.localization_keys = {"front":LONG_ID + ":front", "back":LONG_ID + ":back", "hidden":LONG_ID + ":hidden"}
	for locale in ["ko-KR", "en-US"]:
		var ko: bool = locale == "ko-KR"
		row.locales[locale].title = "계측용 긴 문서" if ko else "Benchmark long document"
		row.locales[locale].summary = "실제 이야기 원고가 아닌 시험 부하" if ko else "Test workload, not story content"
		row.locales[locale].front = _sized("공개 앞면 진동 기록\n" if ko else "Public front vibration record\n", LONG_BYTES / 2)
		row.locales[locale].back = _sized("공개 뒷면 기억 기록\n" if ko else "Public back memory record\n", LONG_BYTES / 2)
		row.locales[locale].hidden = HIDDEN
		row.locales[locale].erase("body")
	CONTENT._contents[LONG_ID] = {"1":row}


static func _entry(id: String, index: int, origin: String, fixture_id: String) -> Dictionary:
	var row := CONTENT.definition(id, 1)
	var segments := {}
	for part in row.visible_segment_ids:
		if part != "hidden": segments[part] = {}
	var locale := "ko-KR" if index % 2 == 0 else "en-US"
	var descriptor := CONTENT.descriptor(id, 1, segments)
	var shown := CONTENT.presentation(descriptor, locale)
	var context := {"node_id":row.node_ids[0], "location_id":"M1_LIBRARY_OUTER", "chapter_id":"CHAPTER_1",
		"event_occurrence_id":uid(fixture_id + ":occurrence:%d" % (index / 10)),
		"conversation_session_id":uid(fixture_id + ":session:%d" % (index / 10)),
		"presentation_token":uid(fixture_id + ":presentation:%d" % index)}
	var observed := CONTENT.observe(descriptor, context, shown.speaker, shown.text, locale)
	assert(observed.ok, str(observed))
	return {"entry_uid":uid(fixture_id + ":entry:%d" % index), "source_origin_id":origin,
		"sequence":index, "record_class":"authored", "observation":observed.observation, "protection_reasons":[]}


static func build(id: String) -> Dictionary:
	if id not in IDS: return {"ok":false, "error":"unknown fixture"}
	install_content()
	var archive := ARCHIVE.create()
	archive.source_origin_id = uid(id + ":origin")
	archive.branch_id = uid(id + ":branch")
	var normal_count := 2001 if id == "NB-PERF-P2001" else (1980 if id == "NB-PERF-LONG" else 2000)
	var protected_count := 2001 if id == "NB-PERF-P2001" else EXTRAS.size()
	var legacy_count := 10000 if id == "NB-PERF-L10000" else 0
	for index in range(normal_count):
		archive.entries.append(_entry(NORMAL[index % NORMAL.size()], archive.entries.size(), archive.source_origin_id, id))
	for index in range(protected_count):
		archive.entries.append(_entry(EXTRAS[index] if index < EXTRAS.size() else "NB_HINT_B3_A_H1", archive.entries.size(), archive.source_origin_id, id))
	if id == "NB-PERF-LONG":
		for index in range(20): archive.entries.append(_entry(LONG_ID, archive.entries.size(), archive.source_origin_id, id))
	for index in range(legacy_count):
		var sequence: int = archive.entries.size()
		var raw := {"sequence":sequence, "line_id":"CH1_HISTORY_TRANSCRIPT", "speaker_id":"SYSTEM",
			"variables":{"speaker":"이전 화자" if index % 2 == 0 else "Earlier speaker", "text":"이전 기록의 진동 %05d" % index if index % 2 == 0 else "Earlier vibration record %05d" % index}}
		archive.entries.append({"entry_uid":uid(id + ":entry:%d" % sequence), "source_origin_id":archive.source_origin_id,
			"sequence":sequence, "record_class":"legacy", "chapter_id":"LEGACY", "legacy_payload":raw, "protection_reasons":[]})
	if id == "NB-PERF-P2001":
		for index in range(50): archive.bookmarks.append(ARCHIVE.make_reference(archive.entries[normal_count + index], "body" if index >= 2 else archive.entries[normal_count + index].observation.segments[0].segment_id))
		for index in range(12): archive.comparison.append(ARCHIVE.make_reference(archive.entries[normal_count + index], archive.entries[normal_count + index].observation.segments[0].segment_id))
	else:
		for index in range(3, 6): archive.comparison.append(ARCHIVE.make_reference(archive.entries[normal_count + index], "body"))
	ARCHIVE._protect_first_people(archive)
	for entry in archive.entries: entry.protection_reasons = ARCHIVE._reasons(archive, entry)
	archive.next_sequence = archive.entries.size()
	var ledger := KNOWLEDGE.create()
	var checked := KNOWLEDGE.validate(ledger, archive)
	if not checked.ok: return checked
	var canonical := JSON.stringify({"archive":archive, "ledger":ledger}, "", true)
	var body_bytes := {"ko-KR":0, "en-US":0, "legacy":0}
	var counts := {"normal":0, "protected":0, "legacy":0}
	for entry in archive.entries:
		if entry.record_class == "legacy":
			counts.legacy += 1
			body_bytes.legacy += String(entry.legacy_payload.variables.text).to_utf8_buffer().size()
		else:
			counts["normal" if entry.protection_reasons.is_empty() else "protected"] += 1
			for part in entry.observation.segments: body_bytes[part.viewed_locale] += String(part.captured_text).to_utf8_buffer().size()
	return {"ok":true, "archive":archive, "ledger":ledger, "manifest":{"fixture_id":id, "seed":SEED,
		"sha256":canonical.sha256_text(), "utf8_bytes":canonical.to_utf8_buffer().size(), "body_bytes":body_bytes, "counts":counts,
		"bookmarks":archive.bookmarks.size(), "comparison":archive.comparison.size(), "long_documents":20 if id == "NB-PERF-LONG" else 0,
		"long_document_utf8_bytes":LONG_BYTES if id == "NB-PERF-LONG" else 0}}


static func append_observation(fixture: Dictionary) -> Dictionary:
	return _entry(NORMAL[0], fixture.archive.next_sequence, fixture.archive.source_origin_id, fixture.manifest.fixture_id).observation
