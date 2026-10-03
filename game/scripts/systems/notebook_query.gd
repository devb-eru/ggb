extends RefCounted

# Owns a frozen read model, never a live GameState or a persistence service.
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const REPOSITORY := preload("res://scripts/systems/dialogue_repository.gd")
const LABELS := preload("res://scripts/systems/notebook_browse_labels.gd")
const VISUALS := preload("res://scripts/systems/notebook_visuals.gd")
const INVESTIGATION := preload("res://scripts/systems/notebook_investigation.gd")
const PAGE_SIZE := 50
const POLICY_VERSION := 7
const SEARCH_FIELDS := ["text", "title", "summary", "speaker", "location_label", "source_label"]
const TABS := ["clues", "dialogue", "records", "people"]
const PERSON_IDS := ["EDGAR", "MARA1", "MARA", "MARA2", "LUCA", "IRIS"]
const FILTER_FIELDS := ["chapters", "locations", "speakers", "categories", "epistemic", "provenance", "sources", "people", "sessions"]
const FIELD_MAP := {"chapters": "chapter", "locations": "location", "speakers": "speaker_id", "categories": "category", "epistemic": "epistemic", "provenance": "provenance", "sources": "source_kind", "people": "people", "sessions": "session"}

var _archive: Dictionary = {}
var _scope: Dictionary = {}
var _locale := "ko-KR"
var _entries: Dictionary = {}
var _rows: Dictionary = {}
var _order: Array = []
var _search: Dictionary = {}
var _search_cursor := 0
var _errors: Dictionary = {}
var _ready := false
var _generation := 0
var _render_count := 0
var _repository
var _result_cache: Dictionary = {}
var _legacy_note_count := 0
var _legacy_digest := ""
var _knowledge_revision := 0
var _related: Dictionary = {}
var _public_speakers: Dictionary = {}
var _public_values: Dictionary = {}
var _person_first: Dictionary = {}
var _investigation := ""
var _investigation_keys: Array = []


func open(archive: Dictionary, ledger: Dictionary, scope: Dictionary, locale: String, legacy_knowledge: Dictionary = {}, current_node: String = "") -> Dictionary:
	close()
	if not _valid_scope(scope, archive): return _error("NB_QUERY_SCOPE")
	var checked := KNOWLEDGE.validate(ledger, archive)
	if not checked.ok: return checked
	_archive = archive.duplicate(true)
	_scope = scope.duplicate(true)
	_locale = "en-US" if locale.begins_with("en") else "ko-KR"
	_investigation = INVESTIGATION.topic(current_node)
	_knowledge_revision = int(ledger.revision)
	var revisions := {}
	var latest := {}
	for revision in ledger.revisions:
		revisions[revision.observation_ref.uid] = revision
		latest[revision.knowledge_uid] = revision.revision_uid
	var session_ends := {}
	for entry in _archive.entries:
		_entries[entry.entry_uid] = entry
		if entry.record_class == "authored":
			var session := _session_key(entry)
			session_ends[session] = maxi(session_ends.get(session, -1), int(entry.sequence))
	for entry in _archive.entries:
		if entry.record_class != "authored":
			if entry.has(ARCHIVE.LEGACY_NOTES.MARKER): _add_legacy_note(entry, true)
			else: _add_legacy(entry)
			continue
		var observed: Dictionary = entry.observation
		var metadata := CONTENT.review_metadata(observed, _locale)
		if not metadata.ok:
			_errors[entry.entry_uid] = metadata.error_id
			continue
		var revision: Dictionary = revisions.get(entry.entry_uid, {})
		var knowledge: Dictionary = revision.get("metadata", {})
		var kind: String = observed.entry_kind
		var tab := "dialogue"
		if kind == "document_segment": tab = "records"
		if kind == "hint_revealed": tab = "clues"
		if knowledge.get("category") in ["observation", "hypothesis", "failure"]: tab = "clues"
		if knowledge.get("category") == "person": tab = "people"
		var previous: bool = not revision.is_empty() and latest[revision.knowledge_uid] != revision.revision_uid
		var session := _session_key(entry)
		var people: Array = []
		var speaker_person := LABELS.person(metadata.speaker_id)
		if not speaker_person.is_empty(): people.append(speaker_person)
		var record_person: String = LABELS.PERSON_RECORDS.get(knowledge.get("knowledge_id", ""), "") if not metadata.fallback else ""
		if not record_person.is_empty() and record_person not in people: people.append(record_person)
		if knowledge.get("category") == "person" and people.is_empty(): people.append("unidentified")
		for index in range(observed.segments.size()):
			var segment: Dictionary = observed.segments[index]
			var ref := ARCHIVE.make_reference(entry, segment.segment_id)
			var key := reference_key(ref)
			var person: bool = not people.is_empty()
			_rows[key] = {
				"key": key, "reference": ref, "tab": tab, "sequence": int(entry.sequence), "segment_order": index,
				"session": session, "session_end": session_ends[session],
				"chapter": observed.chapter_id, "location": observed.location_id,
				"speaker_id": metadata.speaker_id if not String(metadata.speaker).is_empty() else "", "speaker": metadata.speaker,
				"title": metadata.title, "summary": metadata.summary, "kind": kind,
				"category": knowledge.get("category", ""), "epistemic": knowledge.get("epistemic_state", ""),
				"provenance": knowledge.get("provenance_state", ""), "previous": previous,
				"revision_uid": revision.get("revision_uid", ""), "sources": revision.get("source_refs", []).duplicate(true),
				"legacy": false, "person": person, "fallback": metadata.fallback,
				"bookmarked": ref in _archive.bookmarks,
				"review_group": JSON.stringify([revision.get("knowledge_uid", entry.entry_uid), segment.segment_id]).sha256_text(),
				"people": people.duplicate(), "source_kind": _source_kind(kind, knowledge.get("category", "")),
			}
			_order.append(key)
	var projected := ARCHIVE.LEGACY_NOTES.project(legacy_knowledge, _archive.source_origin_id)
	_legacy_digest = JSON.stringify([projected.entries.map(func(entry: Dictionary) -> String: return entry.entry_uid), projected.errors]).sha256_text()
	for entry in projected.entries:
		if _entries.has(entry.entry_uid): continue
		_entries[entry.entry_uid] = entry
		_add_legacy_note(entry, false)
	for index in range(projected.errors.size()): _errors["legacy-note-%d" % index] = projected.errors[index]
	for key in _order:
		var row: Dictionary = _rows[key]
		for person in row.people:
			_person_first[person] = mini(_person_first.get(person, row.sequence), row.sequence)
		for field in FILTER_FIELDS:
			if not _public_values.has(field): _public_values[field] = {}
			for value in _field_values(row, field):
				if not value.is_empty(): _public_values[field][value] = true
		if not String(row.speaker).is_empty():
			if not _public_speakers.has(row.speaker_id): _public_speakers[row.speaker_id] = []
			if row.speaker not in _public_speakers[row.speaker_id]: _public_speakers[row.speaker_id].append(row.speaker)
		if row.revision_uid.is_empty(): continue
		for ref in row.sources:
			var source := reference_key(ref)
			if source == key or not _rows.has(source): continue
			if not _related.has(source): _related[source] = []
			_related[source].append({"key": key, "title": row.title})
	var relevant := {}
	for key in _order:
		var row: Dictionary = _rows[key]
		if not INVESTIGATION.includes(_investigation, _entries[row.reference.uid]): continue
		relevant[key] = true
		for ref in row.sources:
			var source := reference_key(ref)
			if _rows.has(source): relevant[source] = true
	_investigation_keys = relevant.keys()
	_investigation_keys.sort_custom(func(a: String, b: String) -> bool: return _less(_sort_key(_rows[a], {}), _sort_key(_rows[b], {})))
	_ready = true
	return {"ok": true, "key": cache_key(), "diagnostics": diagnostics()}


func close() -> void:
	_generation += 1
	_ready = false
	_archive = {}
	_scope = {}
	_entries.clear()
	_rows.clear()
	_order.clear()
	_search.clear()
	_errors.clear()
	_result_cache.clear()
	_search_cursor = 0
	_render_count = 0
	_repository = null
	_legacy_note_count = 0
	_legacy_digest = ""
	_knowledge_revision = 0
	_related.clear()
	_public_speakers.clear()
	_public_values.clear()
	_person_first.clear()
	_investigation = ""
	_investigation_keys.clear()


func cache_key() -> String:
	return JSON.stringify([_scope, _archive.get("revision", -1), _legacy_digest, _locale, _investigation, POLICY_VERSION, _generation], "", true).sha256_text()


func investigation_available() -> bool:
	return _ready and not _investigation.is_empty()


func investigation_page(page_index: int, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	var last := maxi(0, ceili(float(_investigation_keys.size()) / PAGE_SIZE) - 1)
	var current := clampi(page_index, 0, last)
	var items: Array = []
	for key in _investigation_keys.slice(current * PAGE_SIZE, (current + 1) * PAGE_SIZE):
		var row: Dictionary = _rows[key]
		items.append({"key": key, "title": row.title, "speaker": row.speaker, "previous": row.previous, "epistemic": row.epistemic, "location_label": public_label("locations", row.location)})
	return {"ok": true, "items": items, "page": current, "pages": last + 1, "count": _investigation_keys.size()}


func matches_scope(scope: Dictionary) -> bool:
	return _ready and _scope == scope


func diagnostics() -> Dictionary:
	return {"ready": _ready, "error_count": _errors.size(), "error_ids": _errors.values(), "indexed": _search_cursor, "index_total": _order.size(), "render_count": _render_count}


func index_step(expected_key: String, limit: int = 20) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	var stop := mini(_order.size(), _search_cursor + clampi(limit, 1, PAGE_SIZE))
	while _search_cursor < stop:
		var key: String = _order[_search_cursor]
		var result := detail(key, expected_key)
		if result.ok:
			_search[key] = SEARCH_FIELDS.map(func(field: String) -> String: return String(result[field]).to_lower())
		_search_cursor += 1
	_result_cache.clear()
	return {"ok": true, "complete": _search_cursor == _order.size(), "indexed": _search_cursor}


func page(filters: Dictionary, page_index: int, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if not valid_filters(filters): return _error("NB_QUERY_FILTER")
	var keys := _matching(filters)
	var count := keys.size()
	var last := maxi(0, ceili(float(count) / PAGE_SIZE) - 1)
	var current := clampi(page_index, 0, last)
	var selected: Array = keys.slice(current * PAGE_SIZE, (current + 1) * PAGE_SIZE)
	var items: Array = []
	for key in selected:
		var row: Dictionary = _rows[key]
		# No body rendering or hidden content lookup is needed for list labels.
		items.append({"key": key, "reference": row.reference.duplicate(true), "title": row.title, "speaker": row.speaker, "kind": row.kind, "chapter": row.chapter, "legacy": row.legacy, "previous": row.previous, "epistemic": row.epistemic, "bookmarked": row.bookmarked})
	var complete: bool = String(filters.get("needle", "")).strip_edges().is_empty() or _search_cursor == _order.size()
	return {"ok": true, "items": items, "page": current, "pages": last + 1, "count": count, "complete": complete, "error_count": _errors.size(), "key": expected_key}


func detail(key: String, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if not _rows.has(key): return _error("NB_QUERY_UNAVAILABLE")
	var row: Dictionary = _rows[key]
	var entry: Dictionary = _entries[row.reference.uid]
	_render_count += 1
	var text := ""
	var fallback: bool = row.fallback
	var viewed_locale := ""
	if row.kind == "legacy_note":
		text = entry.legacy_payload.variables.text
	elif row.legacy:
		if _repository == null: _repository = REPOSITORY.new()
		# The compatibility renderer receives one entry, never the full history.
		var projected := entry.duplicate(false)
		projected.sequence = int(entry.sequence)
		var rendered: Dictionary = _repository.render_history({"entries": [projected]}, _locale)
		if rendered.entries.is_empty():
			_errors[key] = "NB_QUERY_LEGACY_RENDER"
			return _error("NB_QUERY_LEGACY_RENDER")
		text = rendered.entries[0].text
	else:
		var rendered := CONTENT.render_segment(entry, row.reference.segment_id, _locale)
		if not rendered.ok:
			_errors[key] = rendered.error_id
			return rendered
		var segment: Dictionary = rendered.entry.segments[0]
		text = segment.text
		fallback = segment.fallback
		viewed_locale = segment.viewed_locale
	var links: Array = []
	for ref in row.sources:
		var target := reference_key(ref)
		if _rows.has(target) and target != key and target not in links: links.append(target)
	return {"ok": true, "key": key, "reference": row.reference.duplicate(true), "title": row.title, "summary": row.summary, "speaker": row.speaker, "kind": row.kind, "text": text, "legacy": row.legacy, "note_snapshot": row.get("note_snapshot", false), "fallback": fallback, "viewed_locale": viewed_locale, "epistemic": row.epistemic, "provenance": row.provenance, "previous": row.previous, "sources": links, "location_label": public_label("locations", row.location), "source_label": public_label("sources", row.source_kind), "related": related_to(key), "session": row.session, "has_visual": not fallback and VISUALS.supports(entry, row.reference.segment_id)}


func visual(key: String, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if not _rows.has(key): return _error("NB_QUERY_UNAVAILABLE")
	var row: Dictionary = _rows[key]
	var entry: Dictionary = _entries[row.reference.uid]
	var material := VISUALS.material(entry, row.reference.segment_id, _locale)
	if material.is_empty() and VISUALS.supports(entry, row.reference.segment_id):
		_errors[key] = "NB_QUERY_VISUAL_UNAVAILABLE"
		return _error("NB_QUERY_VISUAL_UNAVAILABLE")
	return {"ok": true, "material": material}


func search_matches(key: String, needle: String, expected_key: String) -> Dictionary:
	var result := detail(key, expected_key)
	if not result.ok: return result
	return {"ok": true, "matches": match_ranges(result, needle)}


static func match_ranges(detail_result: Dictionary, needle: String) -> Array:
	var matches: Array = []
	var term := needle.strip_edges().to_lower()
	if term.is_empty(): return matches
	for field in SEARCH_FIELDS:
		var text := String(detail_result.get(field, "")).to_lower()
		var offset := text.find(term)
		while offset >= 0:
			matches.append({"field": field, "offset": offset, "length": term.length()})
			offset = text.find(term, offset + term.length())
	return matches


func facets(filters: Dictionary, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if not valid_filters(filters): return _error("NB_QUERY_FILTER")
	var values := {}
	for field in FILTER_FIELDS: values[field] = []
	for key in _matching(filters):
		for field in FILTER_FIELDS:
			for value in _field_values(_rows[key], field):
				if not value.is_empty() and value not in values[field]: values[field].append(value)
	return {"ok": true, "values": values}


func anchor_page(filters: Dictionary, anchor: Dictionary, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if not valid_filters(filters): return _error("NB_QUERY_FILTER")
	var keys := _matching(filters)
	var index := keys.find(anchor.get("key", ""))
	if index < 0 and not keys.is_empty():
		index = 0
		if anchor.get("sort") is Array and anchor.sort.size() == 3:
			index = keys.size() - 1
			for candidate in range(keys.size()):
				if not _less(_sort_key(_rows[keys[candidate]], filters), anchor.sort):
					index = candidate
					break
	return {"ok": true, "key": keys[index] if index >= 0 else "", "page": floori(float(maxi(index, 0)) / PAGE_SIZE)}


func anchor_for(key: String, filters: Dictionary) -> Dictionary:
	if not _ready or not _rows.has(key) or not valid_filters(filters): return {}
	return {"key": key, "sort": _sort_key(_rows[key], filters), "fraction": 0.0}


func review_catalog() -> Dictionary:
	var catalog := {}
	if _ready:
		for key in _order: catalog[key] = _rows[key].review_group
	return catalog


func review_group(key: String) -> String:
	return _rows[key].review_group if _ready and _rows.has(key) else ""


func view_frontier() -> Dictionary:
	if not _ready: return {}
	return {"archive_revision": int(_archive.revision), "next_sequence": int(_archive.next_sequence), "last_uid": "" if _archive.entries.is_empty() else _archive.entries.back().entry_uid, "knowledge_revision": _knowledge_revision, "legacy_digest": _legacy_digest}


func latest_dialogue_key() -> String:
	if not _ready: return ""
	var keys := _matching({"tab": "dialogue"})
	if keys.is_empty(): return ""
	var selected: String = keys[0]
	var last_line := ""
	var end: int = _rows[selected].session_end
	for key in keys:
		if _rows[key].session_end != end: break
		selected = key
		if _rows[key].kind == "dialogue": last_line = key
	return last_line if not last_line.is_empty() else selected


func visible_filters(filters: Dictionary) -> Dictionary:
	if not _ready or not valid_filters(filters): return {"tab": "clues"}
	var result := filters.duplicate(true)
	result.tab = result.get("tab", "clues")
	var allowed := facets({"tab": result.get("tab", "clues"), "include_previous": true, "include_refuted": true, "all_sections": result.get("all_sections", false)}, cache_key())
	for field in FILTER_FIELDS:
		if result.has(field): result[field] = result[field].filter(func(value: String) -> bool: return value in allowed.values[field])
	return result


func comparison(expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	var items: Array = []
	for ref in _archive.comparison:
		var key := reference_key(ref)
		if _rows.has(key): items.append({"key": key, "title": _rows[key].title})
	return {"ok": true, "items": items}


func public_label(field: String, id: String) -> String:
	if not _ready or not _public_values.get(field, {}).has(id): return "표시명 미확인" if _locale == "ko-KR" else "Display name unconfirmed"
	if field == "speakers":
		var names: Array = _public_speakers.get(id, [])
		if not names.is_empty(): return " / ".join(names)
	return LABELS.value(field, id, _locale)


func related_to(key: String) -> Array:
	return _related.get(key, []).duplicate(true)


func dialogue_neighbors(key: String, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key() or not _rows.has(key): return _error("NB_QUERY_STALE")
	var row: Dictionary = _rows[key]
	var lines: Array = []
	for candidate in _order:
		if _rows[candidate].session == row.session and _rows[candidate].kind == "dialogue": lines.append(candidate)
	var previous := ""
	var next := ""
	for candidate in lines:
		if _less([_rows[candidate].sequence, _rows[candidate].segment_order], [row.sequence, row.segment_order]): previous = candidate
		elif candidate != key and next.is_empty(): next = candidate
	return {"ok": true, "previous": previous, "next": next, "last": lines.back() if not lines.is_empty() else ""}


func groups(mode: String, filters: Dictionary, page_index: int, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key(): return _error("NB_QUERY_STALE")
	if mode not in ["people", "sessions"] or not valid_filters(filters): return _error("NB_QUERY_FILTER")
	var browsing := filters.duplicate(true)
	browsing.tab = "people" if mode == "people" else "dialogue"
	browsing.erase("all_sections")
	browsing.erase(mode)
	var grouped := {}
	for key in _matching(browsing):
		var row: Dictionary = _rows[key]
		var ids: Array = row.people if mode == "people" else [row.session]
		for id in ids:
			if not grouped.has(id):
				grouped[id] = {"id": id, "title": public_label("people", id) if mode == "people" else row.title, "count": 0, "spoken": 0, "documents": 0, "locations": [], "names": [], "last": key, "last_line": "", "sequence": row.sequence, "legacy": row.legacy}
			var group: Dictionary = grouped[id]
			group.count += 1
			if row.kind == "dialogue":
				group.spoken += 1
				if group.last_line.is_empty() or row.sequence >= _rows[group.last_line].sequence: group.last_line = key
			else: group.documents += 1
			if row.sequence >= group.sequence:
				group.last = key
				group.sequence = row.sequence
			var location := public_label("locations", row.location)
			if location not in group.locations: group.locations.append(location)
			if not String(row.speaker).is_empty() and row.speaker not in group.names: group.names.append(row.speaker)
	var groups_list: Array = grouped.values()
	if mode == "people":
		# Use all available observations, not just those surviving the active filter.
		groups_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if _person_first[a.id] == _person_first[b.id]: return a.id < b.id
			return _person_first[a.id] < _person_first[b.id])
	else: groups_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.sequence > b.sequence)
	var last := maxi(0, ceili(float(groups_list.size()) / PAGE_SIZE) - 1)
	var current := clampi(page_index, 0, last)
	return {"ok": true, "items": groups_list.slice(current * PAGE_SIZE, (current + 1) * PAGE_SIZE), "page": current, "pages": last + 1, "count": groups_list.size(), "complete": String(browsing.get("needle", "")).strip_edges().is_empty() or _search_cursor == _order.size()}


func reference_state(key: String, expected_key: String) -> Dictionary:
	if not _ready or expected_key != cache_key() or not _rows.has(key): return _error("NB_QUERY_STALE")
	var ref: Dictionary = _rows[key].reference
	return {"ok": true, "reference": ref.duplicate(true), "bookmarks": ref in _archive.bookmarks, "comparison": ref in _archive.comparison}


func _matching(filters: Dictionary) -> Array:
	var signature := JSON.stringify(filters, "", true)
	if _result_cache.has(signature): return _result_cache[signature]
	var keys: Array = []
	var tab: String = filters.get("tab", "clues")
	var needle := String(filters.get("needle", "")).strip_edges().to_lower()
	for key in _order:
		var row: Dictionary = _rows[key]
		if not filters.get("all_sections", false) and row.tab != tab and not (tab == "people" and row.person): continue
		if row.previous and not filters.get("include_previous", false): continue
		if row.epistemic == "refuted" and not filters.get("include_refuted", false): continue
		if filters.get("bookmarks_only", false) and not row.bookmarked: continue
		if not needle.is_empty() and (not _search.has(key) or not _search[key].any(func(text: String) -> bool: return text.contains(needle))): continue
		var matches := true
		for field in FILTER_FIELDS:
			var allowed: Array = filters.get(field, [])
			if not allowed.is_empty() and not _field_values(row, field).any(func(value: String) -> bool: return value in allowed): matches = false
		if matches: keys.append(key)
	keys.sort_custom(func(left: String, right: String) -> bool: return _less(_sort_key(_rows[left], filters), _sort_key(_rows[right], filters)))
	if _result_cache.size() >= 8: _result_cache.clear()
	_result_cache[signature] = keys
	return keys


func _sort_key(row: Dictionary, filters: Dictionary) -> Array:
	if filters.get("tab", "clues") == "dialogue": return [-int(row.session_end), int(row.sequence), int(row.segment_order)]
	if filters.get("tab", "clues") == "people": return [int(row.sequence), int(row.segment_order), 0]
	return [-int(row.sequence), int(row.segment_order), 0]


func _less(left: Array, right: Array) -> bool:
	for index in range(left.size()):
		if left[index] != right[index]: return left[index] < right[index]
	return false


func _add_legacy(entry: Dictionary) -> void:
	var ref := ARCHIVE.make_reference(entry, "legacy")
	var key := reference_key(ref)
	_rows[key] = {
		"key": key, "reference": ref, "tab": "dialogue", "sequence": int(entry.sequence), "segment_order": 0,
		"session": entry.entry_uid, "session_end": int(entry.sequence), "chapter": entry.get("chapter_id", "LEGACY"), "location": "", "speaker_id": "", "speaker": "",
		"title": "이전·미분류 기록" if _locale == "ko-KR" else "Earlier / unclassified record", "summary": "", "kind": "legacy",
		"category": "", "epistemic": "", "provenance": "", "previous": false, "revision_uid": "", "sources": [],
		"legacy": true, "person": false, "fallback": true, "bookmarked": ref in _archive.bookmarks,
		"review_group": JSON.stringify([entry.entry_uid, "legacy"]).sha256_text(),
		"people": [], "source_kind": "legacy",
	}
	_order.append(key)


func _add_legacy_note(entry: Dictionary, captured: bool) -> void:
	_add_legacy(entry)
	var key := reference_key(ARCHIVE.make_reference(entry, "legacy"))
	var row: Dictionary = _rows[key]
	_legacy_note_count += 1
	row.tab = "clues"
	row.kind = "legacy_note"
	row.title = "이전 수첩 원문" if _locale == "ko-KR" else "Earlier notebook text"
	# A pin's archive sequence is not the unknown acquisition time of the note.
	row.sequence = -_legacy_note_count
	row.note_snapshot = captured
	var source: Dictionary = entry[ARCHIVE.LEGACY_NOTES.MARKER]
	row.review_group = JSON.stringify([entry.source_origin_id, source.container, source.locator]).sha256_text()


static func valid_filters(filters: Dictionary) -> bool:
	var allowed := ["tab", "needle", "bookmarks_only", "include_previous", "include_refuted", "all_sections"] + FILTER_FIELDS
	for key in filters:
		if key not in allowed: return false
	if filters.get("tab", "clues") not in TABS or not filters.get("needle", "") is String: return false
	for field in ["bookmarks_only", "include_previous", "include_refuted", "all_sections"]:
		if not filters.get(field, false) is bool: return false
	for field in FILTER_FIELDS:
		if not filters.get(field, []) is Array: return false
		for item in filters.get(field, []):
			if not item is String: return false
	return true


static func reference_key(reference: Dictionary) -> String:
	return JSON.stringify(reference, "", true)


static func _field_values(row: Dictionary, field: String) -> Array:
	var value: Variant = row[FIELD_MAP[field]]
	return value if value is Array else [value]


static func _session_key(entry: Dictionary) -> String:
	var observed: Dictionary = entry.observation
	return JSON.stringify([entry.source_origin_id, observed.event_occurrence_id, observed.conversation_session_id]).sha256_text()


static func _source_kind(kind: String, category: String) -> String:
	if kind == "hint_revealed": return "hint"
	if category == "journal": return "journal"
	if category in ["observation", "hypothesis", "failure", "person"]: return "note"
	if kind == "document_segment": return "document"
	return "spoken"


static func _valid_scope(scope: Dictionary, archive: Dictionary) -> bool:
	for key in ["namespace", "slot", "run_id", "source_origin_id", "branch_id"]:
		if not scope.get(key) is String or scope[key].is_empty(): return false
	if not scope.get("load_epoch") is int or scope.load_epoch < 0: return false
	return scope.source_origin_id == archive.get("source_origin_id") and scope.branch_id == archive.get("branch_id")


static func _error(id: String) -> Dictionary:
	return {"ok": false, "error_id": id}
