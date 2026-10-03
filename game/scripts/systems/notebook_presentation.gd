extends RefCounted

# Pending presentation is gameplay-local state, never a source of notebook disclosure.
const KEY := "NOTEBOOK_PRESENTATION"
const VERSION := 4
const FAMILIES := ["chapter_one_controller", "black_mirror_controller", "basement_controller", "prologue_controller"]
const PROLOGUE_ROUTES := ["_show_p1_objective", "_return_to_hall_after_dialogue", "_resume_p3_journal_choice", "_show_p3_journal_choices", "_complete_p4_life_support_foreshadow", "_finish_p4_memory_anchor", "_finish_p4_after_question", "_complete_p4_iris_greeting", "_perform_normal_reset", "_finish_prologue_handoff"]
const PROLOGUE_CHOICES := {"p3_journal": ["author", "locked", "silent"], "p4_father": ["father_tea", "mansion_age", "luca_tenure"], "P1_EXIT": ["confirm", "cancel"], "P6_SLEEP": ["confirm", "cancel"]}
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const MODAL := preload("res://scripts/systems/notebook_modal_presentation.gd")
const LINE_KEYS := ["speaker", "text", "portrait", "history_context", "presentation_token", "notebook_content", "observed_fact_ids", "audio_cue", "d5_focus_allowed", "d4_reaction_owner", "cup_pose", "p4_pulse"]


static func read(state: Dictionary) -> Dictionary:
	var loop: Variant = state.get("loop_state")
	if not loop is Dictionary or not loop.get("event_local_states") is Dictionary: return {}
	var value: Variant = loop.event_local_states.get(KEY, {})
	return value.duplicate(true) if value is Dictionary else {}


static func family(owner: Object) -> String:
	return owner.get_script().resource_path.get_file().get_basename()


static func resume_family(state: Dictionary) -> String:
	var value := read(state)
	return value.family if matches(value, state) and observed(value, state) and value.phase != "completed" else ""


static func completed_handoff(state: Dictionary, target: String) -> bool:
	var value := read(state)
	if not matches(value, state) or not observed(value, state) or value.phase != "completed": return false
	return (value.family == "chapter_one_controller" and target == "black_mirror_controller" and int(state.meta_progress.journal_stage) == 2) or (value.family == "black_mirror_controller" and target == "basement_controller" and int(state.meta_progress.journal_stage) == 3)


static func completion_for_action(state: Dictionary, owner_family: String, action: String, argument: Variant) -> Dictionary:
	var value := read(state)
	if not matches(value, state) or not observed(value, state) or value.family != owner_family or value.phase != "finish_pending": return {}
	var expected := {"method": "_do", "args": [action, argument, false]}
	var same_route := JSON.stringify(_canonical(value.after), "", true) == JSON.stringify(_canonical(expected), "", true)
	var fade_route: bool = value.after == {"method": "_reality_fade", "args": []} and action == "reality_continue" and argument == "EDR_DISCONNECT"
	if not same_route and not fade_route: return {}
	value.phase = "completed"
	value.after = {}
	return value


static func route(owner: Object, action: Callable) -> Dictionary:
	if action.is_null(): return {"ok": true, "value": {}}
	if not action.is_valid() or action.get_object() != owner: return {"ok": false}
	var value := {"method": String(action.get_method()), "args": action.get_bound_arguments()}
	return {"ok": valid_route(value), "value": value}


static func valid_route(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not _keys(value, ["method", "args"]) or not value.method is String or not value.args is Array: return false
	if value.method in PROLOGUE_ROUTES: return value.args.is_empty()
	match value.method:
		"_do":
			return value.args.size() == 3 and value.args[0] is String and not value.args[0].is_empty() and value.args[0].length() <= 80 and _json(value.args[1]) and value.args[2] is bool and not value.args[2]
		"_show_clock_hint_menu":
			return value.args.size() == 1 and _integer(value.args[0]) and value.args[0] >= 1 and value.args[0] <= 5
		"_offer_clock_failure_support", "_reality_fade":
			return value.args.is_empty()
	return false


static func callable_for(owner: Object, value: Dictionary) -> Callable:
	if value.is_empty() or not valid_route(value) or not owner.has_method(value.method): return Callable()
	return Callable(owner, value.method).bindv(value.args)


static func create(state: Dictionary, owner_family: String, lines: Array, index: int, locale: String, after: Dictionary, phase: String = "reading") -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	var value := {"schema_version": VERSION, "kind": "dialogue", "family": owner_family,
		"source_origin_id": archive.get("source_origin_id", ""), "branch_id": archive.get("branch_id", ""), "anchor": anchor(state),
		"phase": phase, "index": index, "locale": "en-US" if locale.begins_with("en") else "ko-KR", "lines": lines.duplicate(true), "after": after.duplicate(true)}
	return {"ok": valid(value), "value": value}


static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	var fields := ["schema_version", "kind", "family", "source_origin_id", "branch_id", "anchor", "phase", "index", "locale", "lines", "after"]
	if value.get("kind") == "choice": fields.append("choice")
	if value.get("kind") == "modal": fields.append("modal")
	if value.get("kind") == "utility": fields.append("utility")
	if not _keys(value, fields): return false
	if not _integer(value.schema_version) or int(value.schema_version) not in [1, 2, 3, VERSION] or value.kind not in ["dialogue", "choice", "modal", "utility"] or value.family not in FAMILIES: return false
	if value.kind == "modal" and (value.schema_version < 3 or value.family == "prologue_controller" or value.phase not in ["choosing", "selection_pending", "completed"] or not MODAL.valid(value.modal)): return false
	if value.schema_version == 1 and (value.family == "prologue_controller" or value.kind != "dialogue"): return false
	if not _hex(value.source_origin_id, 32) or not _hex(value.branch_id, 32) or not _hex(value.anchor, 64): return false
	if value.locale not in ["ko-KR", "en-US"]: return false
	if value.kind == "utility":
		return value.schema_version == VERSION and value.family != "prologue_controller" and value.phase in ["viewing", "completed"] and value.lines is Array and value.lines.is_empty() and _integer(value.index) and value.index == 0 and value.after is Dictionary and value.after.is_empty() and valid_utility(value.utility)
	if value.kind == "dialogue" and value.phase not in ["reading", "finish_pending", "completed"]: return false
	if value.kind == "choice" and (value.family != "prologue_controller" or value.phase not in ["choosing", "selection_pending", "completed"] or not valid_prologue_choice(value.choice)): return false
	if not value.lines is Array or value.lines.is_empty() or value.lines.size() > 128 or not _integer(value.index) or value.index < 0 or value.index >= value.lines.size(): return false
	if value.phase != "reading" and value.index != value.lines.size() - 1: return false
	if not valid_route(value.after): return false
	if value.kind == "choice":
		if value.lines.size() != 1 or not value.after.is_empty(): return false
		if value.phase == "selection_pending" and value.choice.last_selected.is_empty(): return false
	if value.kind == "modal":
		if not _json(value.modal): return false
		if value.lines.size() != 1 or not value.after.is_empty(): return false
		if value.phase == "selection_pending" and value.modal.selection_token.is_empty(): return false
	if value.phase == "completed" and not value.after.is_empty(): return false
	if not value.after.is_empty() and (value.after.method in PROLOGUE_ROUTES) != (value.family == "prologue_controller"): return false
	var tokens := {}
	for line in value.lines:
		if not line is Dictionary or not _json(line): return false
		for key in line:
			if key not in LINE_KEYS: return false
		if not line.get("speaker") is String or not line.get("text") is String or not _hex(line.get("presentation_token"), 32): return false
		for field in ["portrait", "audio_cue", "d4_reaction_owner", "cup_pose", "p4_pulse"]:
			if line.has(field) and not line[field] is String: return false
		if line.has("d5_focus_allowed") and not line.d5_focus_allowed is bool: return false
		if line.has("observed_fact_ids") and (not line.observed_fact_ids is Array or not line.observed_fact_ids.all(func(id: Variant) -> bool: return id is String)): return false
		if line.text.is_empty() or tokens.has(line.presentation_token): return false
		tokens[line.presentation_token] = true
		var context: Variant = line.get("history_context")
		if not context is Dictionary or context.get("presentation_token") != line.presentation_token: return false
		for field in ["node_id", "chapter_id", "location_id"]:
			if not context.get(field) is String or context[field].is_empty(): return false
		for field in ["event_occurrence_id", "conversation_session_id"]:
			if not _hex(context.get(field), 32): return false
		if line.has("notebook_content") and not line.notebook_content is Dictionary: return false
	return JSON.stringify(value).to_utf8_buffer().size() <= 1048576


static func valid_prologue_choice(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["mode", "header", "prompt", "speaker", "portrait", "order", "labels", "tokens", "last_selected", "focus"]): return false
	if not _json(value) or not value.mode is String or not PROLOGUE_CHOICES.has(value.mode): return false
	if not value.order is Array or value.order.is_empty() or not value.labels is Dictionary or not value.tokens is Dictionary: return false
	if value.mode in ["P1_EXIT", "P6_SLEEP"] and value.order != PROLOGUE_CHOICES[value.mode]: return false
	var previous := -1
	for id in value.order:
		var index: int = PROLOGUE_CHOICES[value.mode].find(id)
		if index <= previous: return false
		previous = index
	for field in ["header", "prompt", "speaker", "portrait", "last_selected"]:
		if not value[field] is String: return false
	if not _keys(value.labels, value.order) or not _integer(value.focus) or value.focus < 0 or value.focus >= value.order.size(): return false
	for id in value.order:
		if not value.labels[id] is String: return false
	for id in value.tokens:
		if id not in value.order or not _hex(value.tokens[id], 32): return false
	return value.last_selected.is_empty() or value.tokens.has(value.last_selected)


static func create_prologue_choice(state: Dictionary, line: Dictionary, choice: Dictionary, locale: String, phase: String = "choosing") -> Dictionary:
	var value: Dictionary = create(state, "prologue_controller", [line], 0, locale, {}).value
	value.kind = "choice"
	value.phase = phase
	value.choice = choice.duplicate(true)
	return {"ok": valid(value), "value": value}


static func localized_choice(value: Dictionary, locale: String) -> Dictionary:
	var choice: Dictionary = value.choice.duplicate(true)
	var shown := CONTENT.presentation(value.lines[0].get("notebook_content", {}), locale)
	if shown.ok:
		for segment in shown.segments:
			if segment.segment_id in ["header", "prompt"]: choice[segment.segment_id] = segment.text
			elif choice.labels.has(segment.segment_id): choice.labels[segment.segment_id] = segment.text
	return choice


static func matches(value: Dictionary, state: Dictionary) -> bool:
	if not valid(value): return false
	var archive: Dictionary = state.meta_progress.dialogue_history
	return value.source_origin_id == archive.get("source_origin_id") and value.branch_id == archive.get("branch_id") and value.anchor == anchor(state)


static func observed(value: Dictionary, state: Dictionary) -> bool:
	if not valid(value): return false
	if value.kind == "utility":
		# These menus contain no observation. A resumed hint level still needs its original disclosure.
		if value.utility.type != "hints" or value.utility.level == 0: return true
		var descriptor := CONTENT.hint_descriptor(value.utility.stage, int(value.utility.level) - 1)
		for entry in state.meta_progress.dialogue_history.get("entries", []):
			var observation: Dictionary = entry.get("observation", {})
			if not descriptor.is_empty() and observation.get("content_id") == descriptor.content_id: return true
		return false
	var required: Array = [value.lines[int(value.index)].presentation_token]
	if value.kind == "choice" and not value.choice.last_selected.is_empty(): required.append(value.choice.tokens[value.choice.last_selected])
	if value.kind == "modal" and not value.modal.selection_token.is_empty(): required.append(value.modal.selection_token)
	for entry in state.meta_progress.dialogue_history.get("entries", []):
		var context: Dictionary = entry.get("observation", entry.get("snapshot_context", {}))
		required.erase(context.get("presentation_token"))
		if required.is_empty(): return true
	return false


static func valid_utility(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["type", "stage", "level", "ratio", "difference"]): return false
	if not value.stage is String or value.stage.is_empty() or value.stage.length() > 32 or not _integer(value.level): return false
	if not value.ratio is bool or not value.difference is bool: return false
	match value.type:
		"hints": return value.level >= 0 and value.level <= 5 and not value.ratio and not value.difference
		"failure": return value.stage == "BF" and value.level == 0 and not value.ratio and not value.difference
		"quantities": return value.stage == "C3" and value.level == 0
	return false


static func create_utility(state: Dictionary, owner_family: String, utility: Dictionary, locale: String, phase: String = "viewing") -> Dictionary:
	var archive: Dictionary = state.meta_progress.dialogue_history
	var value := {"schema_version": VERSION, "kind": "utility", "family": owner_family,
		"source_origin_id": archive.get("source_origin_id", ""), "branch_id": archive.get("branch_id", ""), "anchor": anchor(state),
		"phase": phase, "index": 0, "locale": "en-US" if locale.begins_with("en") else "ko-KR", "lines": [], "after": {}, "utility": utility.duplicate(true)}
	return {"ok": valid(value), "value": value}


static func install(state: Dictionary, value: Dictionary) -> void:
	var updated := value.duplicate(true)
	updated.anchor = anchor(state)
	updated.source_origin_id = state.meta_progress.dialogue_history.source_origin_id
	updated.branch_id = state.meta_progress.dialogue_history.branch_id
	state.loop_state.event_local_states[KEY] = updated


static func carry(state: Dictionary, previous: Dictionary) -> void:
	var value := read(previous)
	if matches(value, previous): install(state, value)


static func localized_lines(value: Dictionary, locale: String) -> Array:
	var lines: Array = value.lines.duplicate(true)
	for line in lines:
		if not line.has("notebook_content"): continue
		var shown := CONTENT.presentation(line.notebook_content, locale)
		if shown.ok:
			line.text = shown.text
			line.speaker = shown.speaker
	return lines


static func anchor(state: Dictionary) -> String:
	var world := {}
	for root in state:
		if root == "meta_progress":
			var meta := {}
			for key in state[root]:
				if key != "dialogue_history": meta[key] = state[root][key]
			world[root] = meta
		elif root == "loop_state":
			var loop: Dictionary = state[root].duplicate()
			loop.event_local_states = loop.event_local_states.duplicate()
			loop.event_local_states.erase(KEY)
			world[root] = loop
		else: world[root] = state[root]
	return JSON.stringify(_canonical(world), "", true, true).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _canonical(value[key])
		return result
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _canonical(item))
	if value is float and _integer(value) and absf(value) < 9007199254740992.0: return int(value)
	return value


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value))


static func _hex(value: Variant, count: int) -> bool:
	return value is String and value.length() == count and value.is_valid_hex_number(false)


static func _keys(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and fields.all(func(field: String) -> bool: return value.has(field))


static func _json(value: Variant, depth: int = 0) -> bool:
	if depth > 12: return false
	if value == null or value is bool: return true
	if value is int or value is float: return is_finite(float(value))
	if value is String: return value.length() <= 16384
	if value is Array: return value.size() <= 256 and value.all(func(item: Variant) -> bool: return _json(item, depth + 1))
	if value is Dictionary:
		if value.size() > 256: return false
		for key in value:
			if not (key is String or key is StringName) or not _json(value[key], depth + 1): return false
		return true
	return false
