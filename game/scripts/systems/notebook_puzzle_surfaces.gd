extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const OVERLAY := preload("res://scripts/ui/notebook_mirror_overlay_v1.gd")
const PREFIX := "NB_PUZZLE_"
const C_NODES := ["C_SLEEP", "C0", "C1", "C2", "C3", "C_BELL", "C4", "CF", "C5_INFO", "J3", "J3_COMPLETE"]
const D_NODES := ["D_SLEEP", "D0", "D0_A", "D1", "DF", "D2", "D4"]


static func surface(key: String, values: Dictionary = {}) -> Dictionary:
	var row := CONTENT.definition(PREFIX + key, 1)
	if row.is_empty(): return {}
	var segments := {}
	for segment in row.visible_segment_ids:
		var variables := {}
		for field in row.variables[segment]:
			if not values.has(field): return {}
			variables[field] = values[field]
		segments[segment] = variables
	return CONTENT.descriptor(PREFIX + key, 1, segments)


static func mixture(mix: Dictionary) -> Dictionary:
	return surface("MIXTURE", {"water":int(mix.water), "stabilizer":int(mix.stabilizer), "active":int(mix.active),
		"mixed":int(mix.mixed), "dispersed":"yes" if mix.dispersed else "no", "foam":"yes" if mix.foamy else "no"})


static func trace(local: Dictionary, overlay: bool = false) -> Dictionary:
	var values := {"rotation":int(local.rotation), "flipped":"yes" if local.flipped else "no", "anchored":"yes" if local.anchored else "no"}
	var route: Array = local.path
	for index in range(route.size()): values["route%d" % index] = route[index]
	return surface(("OVERLAY_" if overlay else "TRACE_") + str(route.size()), values)


static func j3_order(order: Array) -> Dictionary:
	if order.is_empty(): return {}
	var values := {}
	for index in range(order.size()): values["part%d" % index] = str(int(order[index]))
	return surface("J3_ORDER_" + str(order.size()), values)


static func floorplan(local: Dictionary) -> Dictionary:
	return surface("FLOORPLAN", {"rotation":int(local.rotation), "flipped":"yes" if local.flipped else "no", "anchor":"unset" if local.anchor == "" else local.anchor})


static func axis(id: String, axes: Dictionary) -> Dictionary:
	return surface("AXIS_%s_%s" % [id.to_upper(), "PUSHED" if id in axes.pushed else "DEPTH"], {} if id in axes.pushed else {"depth":int(axes.depths[id])})


static func heart(local: Dictionary) -> Dictionary:
	return surface("HEART", {"ring0":str(int(local.rings[0])), "ring1":str(int(local.rings[1])), "ring2":str(int(local.rings[2])), "wind":int(local.wind)})


static func replay_overlay(descriptor: Dictionary) -> Control:
	# Only an explicitly observed diagram segment can construct this versioned view.
	if descriptor.get("content_version") != 1: return null
	var id := String(descriptor.get("content_id", ""))
	if id not in [PREFIX+"OVERLAY_0", PREFIX+"OVERLAY_1", PREFIX+"OVERLAY_2", PREFIX+"OVERLAY_3", PREFIX+"OVERLAY_4"]: return null
	if not descriptor.get("segments", {}).has("state"): return null
	if not CONTENT.presentation(descriptor, "ko-KR").ok: return null
	var values: Dictionary = descriptor.segments.state
	if int(values.rotation) not in [0, 90, 180, 270]: return null
	var diagram := OVERLAY.new()
	diagram.turn_degrees = int(values.rotation)
	diagram.mirrored = values.flipped == "yes"
	diagram.fixed_anchor = values.anchored == "yes"
	diagram.focus_mode = Control.FOCUS_NONE
	return diagram
