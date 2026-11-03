extends RefCounted

const POINTS := {"BED": "EP02_J3_UI_POINT_BED", "GREEN": "EP02_J3_UI_POINT_GREEN", "CLOCK": "EP02_J3_UI_POINT_CLOCK"}


static func defaults() -> Dictionary:
	return {"j3_trace_placed": false, "j3_page_side": "front", "j3_reference_points": [], "j3_false_alignment_seen": false, "j3_sides_compared": false, "j3_held_part": -1}


static func ready(local: Dictionary) -> bool:
	var points: Variant = local.get("j3_reference_points", [])
	return points is Array and points.size() == 3 and POINTS.keys().all(func(key: String) -> bool: return key in points) and local.get("j3_trace_placed", false) == true and local.get("j3_false_alignment_seen", false) == true and local.get("j3_sides_compared", false) == true


static func act(local: Dictionary, action: String, value: Variant) -> Dictionary:
	var ids: Array = []
	match action:
		"j3_overlay":
			ids.append("EP02_J3_UI_PLACE_TRACE")
			if not local.j3_overlay_seen: ids.append("EP02_J3_FB_TRACING_FIRST")
			local.j3_trace_placed = true
			local.j3_overlay_seen = true
		"j3_remove_trace":
			if not local.j3_trace_placed: return {"ok": false, "text": "탁본을 먼저 놓는다."}
			local.j3_trace_placed = false
			ids.append("EP02_J3_UI_REMOVE_TRACE")
		"j3_point":
			if not local.j3_trace_placed: return {"ok": false, "text": "탁본을 먼저 놓는다."}
			if not value is String or not POINTS.has(value): return {"ok": false, "text": "페이지에 그려진 기준점을 고른다."}
			if value in local.j3_reference_points: return {"ok": false, "id": "EP02_J3_UI_POINT_DUP"}
			local.j3_reference_points.append(value)
			ids.append(POINTS[value])
		"j3_flip_page":
			if not local.j3_trace_placed: return {"ok": false, "text": "탁본을 먼저 놓는다."}
			local.j3_page_side = "back" if local.j3_page_side == "front" else "front"
		"j3_compare":
			if not local.j3_trace_placed: return {"ok": false, "text": "탁본을 먼저 놓는다."}
			match local.j3_reference_points.size():
				0: ids.append("EP02_J3_FB_TRACING_FIRST")
				1: ids.append("EP02_J3_FB_ONE_POINT")
				2: ids.append("EP02_J3_FB_TWO_POINTS")
				3:
					if local.j3_page_side == "front":
						local.j3_false_alignment_seen = true
						ids.append("EP02_J3_FB_ALL_FALSE")
					elif local.j3_false_alignment_seen:
						local.j3_sides_compared = true
						ids.append_array(["EP02_J3_UI_MAP_REQUIRED", "EP02_SYS_UI_J3_LIMIT"])
					else: return {"ok": false, "text": "먼저 앞면의 기준점과 문장을 대조한다."}
		"j3_pick_part":
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) != floorf(float(value)) or int(value) not in range(4): return {"ok": false, "text": "문장 조각을 선택한다."}
			local.j3_held_part = int(value)
			ids.append("EP02_J3_UI_SENTENCE_PICK")
		"j3_drop_part":
			if int(local.j3_held_part) not in range(4): return {"ok": false, "text": "문장 조각을 먼저 집어 든다."}
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) != floorf(float(value)) or int(value) < 0 or int(value) > local.j3_order.size(): return {"ok": false, "text": "문장 사이의 자리를 선택한다."}
			var part := int(local.j3_held_part)
			local.j3_order.erase(part)
			local.j3_order.insert(mini(int(value), local.j3_order.size()), part)
			local.j3_held_part = -1
			ids.append("EP02_J3_UI_SENTENCE_DROP")
	return {"ok": true, "ids": ids}
