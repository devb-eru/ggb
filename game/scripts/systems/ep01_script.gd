class_name Ep01Script
extends RefCounted

const SOURCE := "res://data/dialogue/chapter_one/ep01_runtime.json"
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
static var _source: Dictionary = {}
static var _nodes: Dictionary = {}
static var _routes: Dictionary = {}
static var _predicates: Dictionary = {}
static var _ep02_source: Dictionary = {}
static var _ep02_nodes: Dictionary = {}
static var _ep02_routes: Dictionary = {}
static var _ep02_predicates: Dictionary = {}


static func source(package: String = "EP01") -> Dictionary:
	if package == "EP02":
		if _ep02_source.is_empty():
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/sheets/ep02_runtime.json"))
			if not parsed is Dictionary or parsed.get("schema_version") != 1: return {}
			_ep02_source = parsed
			for row in parsed.nodes: _ep02_nodes[row.node_id] = row
			for row in parsed.predicates: _ep02_predicates[row.predicate_id] = row
			for row in parsed.edges:
				if not _ep02_routes.has(row.route_id): _ep02_routes[row.route_id] = []
				_ep02_routes[row.route_id].append(row)
			for route in _ep02_routes: _ep02_routes[route].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.edge_order) < int(b.edge_order))
		return _ep02_source
	if _source.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if not parsed is Dictionary or parsed.get("schema_version") != 1: return {}
		_source = parsed
		for row in _source.nodes: _nodes[row.node_id] = row
		for row in _source.predicates: _predicates[row.predicate_id] = row
		for row in _source.edges:
			if not _routes.has(row.route_id): _routes[row.route_id] = []
			_routes[row.route_id].append(row)
		for route in _routes: _routes[route].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.edge_order) < int(b.edge_order))
	return _source


static func node(id: String) -> Dictionary:
	if id.begins_with("EP02_"):
		source("EP02")
		return _ep02_nodes.get(id, {}).duplicate(true)
	source()
	return _nodes.get(id, {}).duplicate(true)


static func edges(route: String) -> Array:
	if route.begins_with("EP02_"):
		source("EP02")
		return _ep02_routes.get(route, []).duplicate(true)
	source()
	return _routes.get(route, []).duplicate(true)


static func text(id: String, locale: String = "ko-KR", variables: Dictionary = {}) -> String:
	var row := node(id)
	if row.is_empty(): return ""
	if id.begins_with("EP02_"):
		var descriptor := CONTENT.descriptor("NB_" + id, notebook_version("NB_" + id), {"body": variables})
		var shown := CONTENT.presentation(descriptor, locale)
		return String(shown.get("text", "")) if shown.get("ok", false) else ""
	var result: String = row.en_US if locale.begins_with("en") and not row.en_US.is_empty() else row.ko_KR
	for key in variables: result = result.replace("{" + str(key) + "}", str(variables[key]))
	return result


static func line(id: String, state: Dictionary, locale: String = "ko-KR", variables: Dictionary = {}) -> Dictionary:
	var row := node(id)
	if row.is_empty(): return {}
	var descriptor := CONTENT.descriptor("NB_" + id, notebook_version("NB_" + id), {"body": variables})
	var shown := CONTENT.presentation(descriptor, locale)
	if not shown.ok: return {}
	return {"speaker": shown.speaker, "text": shown.text,
		"portrait": "" if row.character_art == "NONE" else row.character_art,
		"portrait_position": row.portrait_position, "portrait_state": row.portrait_state,
		"history_context": {"node_id": id, "chapter_id": "CHAPTER_2" if id.begins_with("EP02_") else "CHAPTER_1", "location_id": state.loop_state.location_id},
		"notebook_content": descriptor}


static func notebook_version(content_id: String) -> int:
	var ep02 := content_id.begins_with("NB_EP02_")
	var version := int(source("EP02" if ep02 else "EP01").get("notebook_versions", {}).get(content_id, 1))
	return CONTENT.latest_version(content_id, version) if ep02 else version


static func scene_entry(scene: String, package: String = "EP01") -> String:
	for row in source(package).get("nodes", []):
		if row.scene_id == scene: return row.node_id
	return ""


static func _path(state: Dictionary, path: String) -> Variant:
	var value: Variant = state
	for part in path.split("."):
		if not value is Dictionary or not value.has(part): return null
		value = value[part]
	return value


static func resolve(route: String, state: Dictionary, cases: Dictionary = {}) -> Dictionary:
	var fallback := {}
	var selected := String(cases.get(route, ""))
	var servants: Dictionary = state.meta_progress.servants
	if selected.is_empty():
		var mirror: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
		if route == "EP02_ROUTER_C4_ACTUAL_RESULT" and mirror.get("locked", false): selected = "EP02_CF_001"
		elif route == "EP02_ROUTER_C4_EDGAR" and int(servants.edgar.alert) >= 4 and int(servants.edgar.bond) < 4 and not mirror.get("intervention_handled", false): selected = "EP02_C4_EDGAR_001"
		elif route == "EP02_ROUTER_C4_WITNESS":
			for owner in ["EDGAR", "MARA1", "LUCA"]:
				if owner not in mirror.get("witnesses", []): continue
				var servant: Dictionary = servants[owner.to_lower()]
				if owner == "EDGAR" or (int(servant.bond) >= 4 and int(servant.alert) < 4):
					selected = "EP02_C4_WITNESS_%s_001" % owner
					break
		elif route == "EP02_ROUTER_CSHORT_SUPPORT":
			for owner in ["MARA1", "LUCA"]:
				var servant: Dictionary = servants[owner.to_lower()]
				if int(servant.bond) >= 4 and int(servant.alert) < 4:
					selected = "EP02_CSHORT_%s_001" % owner
					break
		if route == "EP02_ROUTER_C2_REACTION" and state.loop_state.location_id == "M1_MIRROR_GALLERY" and not preload("res://scripts/systems/sheet_dialogue_effects.gd").event_seen(state, "MARA1_S2"):
			selected = "EP02_MARA1_S2_001"
		elif route == "EP02_ROUTER_C5_REACTION":
			var effects := preload("res://scripts/systems/sheet_dialogue_effects.gd")
			if state.loop_state.location_id == "M1_COLOR_ROOM_ENTRY" and not effects.event_seen(state, "MARA2_S2"): selected = "EP02_MARA2_S2_001"
			elif state.loop_state.location_id == "M1_GREENHOUSE" and not effects.event_seen(state, "IRIS_S2"): selected = "EP02_IRIS_S2_001"
		if route in ["EP01_ROUTER_A2_EDGAR_ALERT", "EP01_ROUTER_B1_EDGAR"]:
			var tier := 1 + mini(2, int(servants.edgar.alert) / 2)
			selected = ("EP01_A2_EDGAR_" if route.contains("A2_") else "EP01_B1_EDGAR_") + "%03d" % tier
		elif route.begins_with("EP01_ROUTER_B1_") and not route.ends_with("_REPEAT"):
			var owner := route.trim_prefix("EP01_ROUTER_B1_").to_lower()
			if servants.has(owner):
				var tier := 1 + mini(1 if owner == "iris" else 2, int(servants[owner].bond) / 2)
				selected = "EP01_B1_" + owner.to_upper() + "_%03d" % tier
		elif route == "EP01_ROUTER_B2_HIDE_ALERT":
			selected = "EP01_B2_HIDE_" + ["LOW", "MID", "HIGH"][mini(2, int(servants.edgar.alert) / 2)] + "_001"
		elif route == "EP01_ROUTER_B2_CAUGHT_ALERT" and int(servants.edgar.alert) >= 4:
			selected = "EP01_B2_CAUGHT_HIGH_001"
		elif route == "EP01_ROUTER_AS_SERVANT":
			selected = "EP01_AS_" + String(cases.get("servant", "EDGAR")).to_upper() + "_001"
	for edge in edges(route):
		if String(edge.is_fallback) == "TRUE":
			fallback = edge
			continue
		var predicate: Dictionary = (_ep02_predicates if route.begins_with("EP02_") else _predicates).get(edge.predicate_id, {})
		if predicate.get("comparator") == "contains":
			var value: Variant = _path(state, predicate.state_path)
			if (value is Dictionary or value is Array) and value.has(predicate.typed_value): return edge
		elif selected != "" and (edge.predicate_expression == "route_case == " + selected or edge.predicate_expression == "selection == " + selected):
			return edge
	return fallback


static func segment(start: String, state: Dictionary, locale: String = "ko-KR", stops: Array = [], cases: Dictionary = {}) -> Dictionary:
	var lines: Array = []
	var ids: Array = []
	var current := start
	var seen := {}
	for _step in range(128):
		if current.is_empty() or current == "NONE" or current in stops: return {"ok": true, "lines": lines, "ids": ids, "next": current, "kind": "stop"}
		if seen.has(current): return {"ok": false, "error_id": "EP01_SCRIPT_CYCLE", "node_id": current}
		seen[current] = true
		var ep02_choice: bool = current.begins_with("EP02_") and current in source("EP02").get("choice_routes", [])
		if current.begins_with("EP01_CHOICE_") or current == "EP01_HUB_DAILY_HALL" or ep02_choice: return {"ok": true, "lines": lines, "ids": ids, "next": current, "kind": "choice"}
		var row := node(current)
		if row.is_empty():
			var edge := resolve(current, state, cases)
			if edge.is_empty(): return {"ok": false, "error_id": "EP01_SCRIPT_ROUTE", "node_id": current}
			if current in source("EP02").get("conditional_choice_routes", []) and edge.target_type == "node":
				return {"ok": true, "lines": lines, "ids": ids, "next": current, "kind": "choice"}
			if edge.target_type != "node" and edge.target_type != "route": return {"ok": true, "lines": lines, "ids": ids, "next": edge.target_id, "kind": "stop"}
			current = edge.target_id
			continue
		if current == "EP02_C4_ACTUAL_002":
			var mirror: Dictionary = state.loop_state.event_local_states.get("BLACK_MIRROR", {})
			var prefix: Array = state.meta_progress.failure_knowledge.get("C4", {}).get("verified_prefix", [])
			var current_prefix_valid: bool = mirror.get("locked", false) and prefix.slice(0, 3) == ["entry", "short_branch", "long_branch"]
			if not mirror.get("surface_open", false) and not current_prefix_valid:
				current = row.next_id
				continue
		var variables := {}
		if row.ko_KR.contains("{knowledge_count}"): variables.knowledge_count = state.meta_progress.knowledge_entries.size()
		var shown := line(current, state, locale, variables)
		if shown.is_empty(): return {"ok": false, "error_id": "EP01_SCRIPT_CONTENT", "node_id": current}
		lines.append(shown)
		ids.append(current)
		if current.begins_with("EP02_"):
			var extras := preload("res://scripts/systems/ep02_disclosure_notices.gd").after(current, state, AccessibilityProfileStore.new().load_profile().get("profile", {}))
			for identity in extras:
				if identity not in ids:
					lines.append(line(identity, state, locale))
					ids.append(identity)
		if row.next_type in ["scene", "hub", "episode_exit", "end"]: return {"ok": true, "lines": lines, "ids": ids, "next": row.next_id, "kind": "stop"}
		current = row.next_id
	return {"ok": false, "error_id": "EP01_SCRIPT_LIMIT"}


static func completed_flags(ids: Array) -> Dictionary:
	var flags := {}
	for effect in source().get("effects", []):
		# Gameplay progression stays with ChapterOneSession/ResetCoordinator.
		# Only the six authored conversation-completion receipts are presentation effects.
		if effect.node_id in ids and effect.event_id == "B1" and effect.state_path == "loop_state.event_local_states" and effect.operation == "add":
			var value: Variant = JSON.parse_string(effect.typed_value)
			if value is Dictionary:
				for key in value:
					if key.ends_with("_seen") and value[key] == true: flags[key] = true
	return flags


static func completed_persistent_flags(ids: Array) -> Dictionary:
	var flags := {}
	for effect in source().get("effects", []):
		if effect.node_id not in ids or effect.state_path != "meta_progress.flags" or effect.operation != "add": continue
		if effect.event_id not in ["EP01_DLG_EDGAR_001", "EP01_DLG_EDGAR_002"]: continue
		var expected: String = effect.event_id + "_complete"
		var value: Variant = JSON.parse_string(effect.typed_value)
		if value is Dictionary and value.size() == 1 and value.get(expected) == true:
			flags[expected] = true
	return flags


static func visible_choice_edges(route: String, state: Dictionary) -> Array:
	var result: Array = []
	for edge in edges(route):
		if edge.target_type != "node": continue
		if route == "EP01_CHOICE_EDGAR_HALL":
			var event: String = {"EP01_DLG_EDGAR_001_CH01": "EP01_DLG_EDGAR_001", "EP01_DLG_EDGAR_002_CH01": "EP01_DLG_EDGAR_002"}.get(edge.target_id, "")
			if not event.is_empty() and state.meta_progress.get("flags", {}).get(event + "_complete", false): continue
		result.append(edge)
	return result


static func options_content_id(route: String, state: Dictionary) -> String:
	if route != "EP01_CHOICE_EDGAR_HALL": return "NB_" + route
	var mask := 0
	for index in range(2):
		if not state.meta_progress.get("flags", {}).get("EP01_DLG_EDGAR_%03d_complete" % (index + 1), false): mask |= 1 << index
	return "NB_" + route + "_VISIBLE_" + str(mask)


static func valid_context(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	if not value.get("start") is String or not value.get("stops") is Array or not value.get("cases") is Dictionary or not value.get("ids") is Array or not value.get("finish") is Dictionary: return false
	if value.stops.size() > 32 or value.cases.size() > 32 or value.ids.size() > 128: return false
	if not value.stops.all(func(id: Variant) -> bool: return id is String) or not value.ids.all(func(id: Variant) -> bool: return id is String and not node(id).is_empty()): return false
	for key in value.cases:
		if not key is String or not value.cases[key] is String: return false
	var finish: Dictionary = value.finish
	if finish.is_empty(): return true
	if finish.size() != 2 or not finish.get("method") is String or not finish.get("args") is Array: return false
	if finish.method in ["_open_mark_choices", "_open_schedule_board", "_confirm_sleep", "_offer_clock_failure_support", "_sleep_now", "_show_sheet_dry_feedback", "_show_sheet_edgar_aside", "_show_sheet_trace_done", "_show_sheet_j3_done", "_show_sheet_c4_cancel", "_show_sheet_memory_replay_done"]: return finish.args.is_empty()
	return finish.method == "_do" and finish.args.size() == 3 and finish.args[0] in ["edgar_leave", "routine", "confirm_mark", "c_dry"] and finish.args[2] == false
