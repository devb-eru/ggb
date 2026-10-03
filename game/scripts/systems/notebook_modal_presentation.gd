extends RefCounted

# Only controller-owned presentation actions may cross a process boundary.
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROUTES := {"_close_modal": [0], "_modal_act": [1, 2], "_sleep_now": [0], "_start_d6_rest": [1],
	"_open_field_page": [2], "_advance_field_page": [3], "_confirmation_notebook": [0], "_replay_route_feedback": [0]}


static func route(owner: Object, action: Callable) -> Dictionary:
	if not action.is_valid() or action.get_object() != owner: return {}
	var value := {"method": String(action.get_method()), "args": action.get_bound_arguments()}
	return value if valid_route(value) else {}


static func valid_route(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.get("method") is String or not value.get("args") is Array: return false
	if not ROUTES.has(value.method) or value.args.size() not in ROUTES[value.method]: return false
	match value.method:
		"_modal_act":
			return value.args[0] is String and not value.args[0].is_empty() and value.args[0].length() <= 80
		"_start_d6_rest": return value.args[0] in ["bedroom", "capsule", "emergency_capsule"]
		"_open_field_page", "_advance_field_page":
			return value.args[0] is String and value.args[1] is bool and (value.args.size() == 2 or value.args[2] is String)
	return true


static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	var fields := ["title", "body", "labels", "routes", "view", "pending_index", "selection_token", "focus"]
	if value.size() != fields.size() or not fields.all(func(key: String) -> bool: return value.has(key)): return false
	if not value.title is String or not value.body is String or not value.labels is Array or not value.routes is Array: return false
	if value.labels.is_empty() or value.labels.size() > 32 or value.labels.size() != value.routes.size(): return false
	if not value.labels.all(func(label: Variant) -> bool: return label is String) or not value.routes.all(valid_route): return false
	for key in ["focus", "pending_index"]:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) or value[key] != floor(float(value[key])): return false
	if value.focus < 0 or value.focus >= value.labels.size() or value.pending_index < -1 or value.pending_index >= value.labels.size(): return false
	if not value.selection_token is String: return false
	if not value.selection_token.is_empty() and (value.pending_index < 0 or value.selection_token.length() != 32 or not value.selection_token.is_valid_hex_number(false)): return false
	if not value.view is Dictionary: return false
	if value.view.is_empty(): return true
	if value.view.size() != 2 or value.view.get("kind") not in ["mirror_route", "mirror_overlay"] or not value.view.get("local") is Dictionary: return false
	var local: Dictionary = value.view.local
	var rotation: Variant = local.get("rotation")
	if not (rotation is int or rotation is float) or not is_finite(float(rotation)) or rotation != floor(float(rotation)): return false
	return local.size() == 4 and int(rotation) in [0, 90, 180, 270] and local.get("flipped") is bool and local.get("anchored") is bool and local.get("path") is Array and local.path.size() <= 64 and local.path.all(func(id: Variant) -> bool: return id is String)


static func capture(owner: Object, context: Dictionary) -> Dictionary:
	var routes: Array = []
	var labels: Array = []
	for action in context.actions:
		var item := route(owner, action.action)
		if item.is_empty(): return {}
		routes.append(item)
		labels.append(action.label)
	return {"title": context.title, "body": context.body, "labels": labels, "routes": routes, "view": context.view.duplicate(true),
		"pending_index": context.pending_index if context.selection_recorded else -1,
		"selection_token": context.get("selection_token", "") if context.selection_recorded else "", "focus": context.get("focus", 0)}


static func localized(value: Dictionary, descriptor: Dictionary, locale: String) -> Dictionary:
	var result := value.duplicate(true)
	var shown := CONTENT.presentation(descriptor, locale)
	if not shown.ok: return result
	var body := PackedStringArray()
	for segment in shown.segments:
		if segment.segment_id == "header": result.title = segment.text
		elif String(segment.segment_id).begins_with("option_"):
			var index := String(segment.segment_id).trim_prefix("option_").to_int()
			if index in range(result.labels.size()): result.labels[index] = segment.text
		else: body.append(segment.text)
	result.body = "\n".join(body)
	return result
