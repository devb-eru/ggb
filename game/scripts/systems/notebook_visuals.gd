extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ORIGINALS := {"NB_CH1_NOTE_B4": "wave", "NB_MIRROR_NOTE_C5_INFO": "circuit", "NB_BASEMENT_NOTE_D4": "ports"}
const SELF_MARKS := ["NB_CH1_NOTE_A1_SENTENCE", "NB_CH1_NOTE_A1_HOUSE_GLYPH", "NB_CH1_NOTE_A1_INK_CORNER"]
const CORE := ["NB_CORE_SCREEN_C_LAYER_B4", "NB_CORE_SCREEN_C_LAYER_C5", "NB_CORE_SCREEN_C_LAYER_D4"]
const OVERLAYS := ["NB_PUZZLE_OVERLAY_0", "NB_PUZZLE_OVERLAY_1", "NB_PUZZLE_OVERLAY_2", "NB_PUZZLE_OVERLAY_3", "NB_PUZZLE_OVERLAY_4"]
const BRANCHES := [[[0, 1], [0, -0.1]], [[0, -0.1], [-0.6, -0.45]], [[0, -0.1], [1, -0.55]]]


static func supports(entry: Dictionary, segment: String) -> bool:
	if entry.get("record_class") != "authored": return false
	var observed: Dictionary = entry.observation
	if not observed.segments.any(func(part: Dictionary) -> bool: return part.segment_id == segment): return false
	if observed.content_id in SELF_MARKS: return int(observed.content_version) == 2 and segment == "body"
	if int(observed.content_version) != 1: return false
	return (segment == "body" and (ORIGINALS.has(observed.content_id) or observed.content_id in CORE)) or (segment == "state" and observed.content_id in OVERLAYS)


static func material(entry: Dictionary, segment: String, locale: String) -> Dictionary:
	if not supports(entry, segment): return {}
	var observed: Dictionary = entry.observation
	var metadata := CONTENT.review_metadata(observed, locale)
	var rendered := CONTENT.render_segment(entry, segment, locale)
	if not metadata.ok or metadata.fallback or not rendered.ok: return {}
	var part: Dictionary = observed.segments.filter(func(value: Dictionary) -> bool: return value.segment_id == segment)[0]
	var en := locale.begins_with("en")
	var result := {"paths": [], "circles": [], "squares": [], "title": "", "description": "", "version": 1}
	if observed.content_id in SELF_MARKS:
		if not _self_mark(result, CONTENT.definition(observed.content_id, 2).get("visual", {}), part.viewed_locale, en): return {}
	elif ORIGINALS.has(observed.content_id):
		_original(result, ORIGINALS[observed.content_id], en)
	elif observed.content_id in CORE:
		if not _core(result, CONTENT.definition(observed.content_id, 1).get("visual", {}), part.safe_variables, en): return {}
	else:
		if not _overlay(result, part.safe_variables, en): return {}
	return result


static func _self_mark(result: Dictionary, visual: Dictionary, original_locale: String, en: bool) -> bool:
	if visual.get("kind") != "self_mark_v2" or not visual.has_all(["paths", "circles", "squares", "text_runs", "description"]): return false
	for field in ["paths", "circles", "squares"]: result[field] = visual[field].duplicate(true)
	var language := "en-US" if original_locale.begins_with("en") else "ko-KR"
	result.text_runs = visual.text_runs[language].duplicate(true)
	result.title = "The mark I wrote" if en else "직접 남긴 표식"
	result.version = 2
	result.description = visual.description["en-US" if en else "ko-KR"]
	if visual.mark_type == "sentence":
		result.description += "\n" + ("The image keeps the language used when writing. The record text supplies the current-language reading; type outlines are not a measured handwriting facsimile." if en else "그림은 작성 당시 언어를 유지합니다. 현재 언어의 내용은 기록 원문에서 읽을 수 있으며, 글자 윤곽은 실제 필체를 측정한 복제본이 아닙니다.")
	result.description += "\n" + ("Inspecting this record does not change what was written or confirm that it survives the following morning." if en else "이 기록을 살펴보는 것만으로 원래 표시가 바뀌거나 다음 아침의 유지가 확정되지는 않습니다.")
	return true


static func _original(result: Dictionary, kind: String, en: bool) -> void:
	# Version-one recorded shapes; no current puzzle solver or hidden target markers.
	if kind in ["wave", "circuit"]:
		var wave := kind == "wave"
		for branch in BRANCHES:
			var points: Array = []
			for raw in branch:
				var point := Vector2(raw[0], raw[1]).rotated(-PI / 2.0) if wave else Vector2(raw[0], raw[1])
				points.append([point.x * 2, point.y * 2])
			_path(result, points, 2 if wave else 4, wave)
		var center := Vector2(0.72, -0.55).rotated(-PI / 2.0) if wave else Vector2(0.72, -0.55)
		result.circles.append({"point": [center.x * 2, center.y * 2], "radius": 0.56, "width": 2 if wave else 4, "dashed": wave})
		if wave:
			result.squares.append([2, 0])
			result.title = "Recorded waveform" if en else "기록한 파형"
			result.description = "Dashes and square: the recorded entry, two unequal reflections and residual loop. Original orientation; no solution overlay." if en else "점선·사각: 기록한 진입부, 길이가 다른 두 반사부와 잔류 고리입니다. 원래 방향이며 정답 중첩은 표시하지 않습니다."
		else:
			result.circles.append({"point": [0, 2], "radius": 0.12, "width": 2, "dashed": false})
			result.title = "Recorded mirror circuit" if en else "기록한 거울 회로"
			result.description = "Thick solid branches and a loop; circle at the lower reference point. Source signatures and landmarks remain in the recorded text below. This is not the floorplan or its solution." if en else "굵은 실선의 비대칭 분기·고리와 하단 원형 기준점입니다. 출처 서명과 장소 기준은 아래 기록 원문을 함께 읽습니다. 평면도나 검증된 정답 배치가 아닙니다."
	else:
		for end in [[3, 0], [0, 3], [-3, 0], [0, -3]]: _path(result, [[0, 0], end], 2, false)
		for point in [[0, 0], [3, 0], [0, 3], [-3, 0], [0, -3]]:
			result.circles.append({"point": point, "radius": 0.13, "width": 2, "dashed": false})
		result.title = "Recorded port afterimage" if en else "기록한 포트 잔상"
		result.description = "Thin solid lines join the central port and four surrounding ports. No ownership, authority or aligned fifth-port solution is assigned." if en else "가는 실선으로 중앙 포트와 주변 네 포트가 연결됩니다. 소유자·권한이나 중첩 뒤의 정답 위치를 지정하지 않습니다."


static func _core(result: Dictionary, visual: Dictionary, values: Dictionary, en: bool) -> bool:
	if visual.get("kind") != "core_overlay_v1" or not values.has_all(["degrees", "flipped", "anchor", "opacity"]): return false
	if int(values.degrees) not in [0, 90, 180, 270] or int(values.opacity) < 20 or int(values.opacity) > 100: return false
	if not visual.anchor_offsets.has(values.anchor): return false
	var points: Array = []
	for raw in visual.path: points.append(_core_point(raw, values, visual.anchor_offsets))
	_path(result, points, float(visual.stroke_width), visual.pattern == "dashed")
	for point in visual.markers: result.circles.append({"point": point, "radius": 0.12, "width": 1, "dashed": false})
	if not visual.ring_center.is_empty():
		result.circles.append({"point": _core_point(visual.ring_center, values, visual.anchor_offsets), "radius": visual.ring_radius, "width": 3, "dashed": false})
	result.title = "Previously viewed layer" if en else "당시 본 자료층"
	result.description = ("Only this observed layer, its original markers and the saved orientation are replayed. Zoom/pan do not change its rotation or alignment. Recorded opacity: %d%%; monochrome strokes stay readable." if en else "당시 본 한 자료층과 기준점·저장된 방향만 재현합니다. 확대·이동은 회전·정렬을 바꾸지 않습니다. 당시 투명도: %d%%이며 단색 선은 읽을 수 있게 유지합니다.") % int(values.opacity)
	return true


static func _core_point(raw: Array, values: Dictionary, offsets: Dictionary) -> Array:
	var point := Vector2(raw[0], raw[1])
	if values.flipped == "yes": point.x = -point.x
	point = point.rotated(deg_to_rad(float(values.degrees)))
	var offset: Array = offsets[values.anchor]
	point += Vector2(offset[0], offset[1])
	return [point.x, point.y]


static func _overlay(result: Dictionary, values: Dictionary, en: bool) -> bool:
	if not values.has_all(["rotation", "flipped", "anchored"]) or int(values.rotation) not in [0, 90, 180, 270]: return false
	for branch in BRANCHES:
		_path(result, branch.map(func(raw: Array) -> Array: return [raw[0] * 2, raw[1] * 2]), 4, false)
		_path(result, branch.map(func(raw: Array) -> Array: return _overlay_point(raw, values)), 2, true)
	result.circles.append({"point": [1.44, -1.1], "radius": 0.56, "width": 4, "dashed": false})
	result.circles.append({"point": _overlay_point([0.72, -0.55], values), "radius": 0.56, "width": 2, "dashed": true})
	result.circles.append({"point": [0, 2], "radius": 0.12, "width": 2, "dashed": false})
	result.squares.append(_overlay_point([0, 1], values))
	result.title = "Previously viewed mirror comparison" if en else "당시 본 거울 대조"
	result.description = "Solid line/circle: mirror. Dashes/square: tracing. The saved position is shown without correcting or judging it." if en else "실선·원은 거울, 점선·사각은 투명지입니다. 당시의 배치를 수정하거나 판정하지 않고 그대로 표시합니다."
	return true


static func _overlay_point(raw: Array, values: Dictionary) -> Array:
	var point := Vector2(raw[0], raw[1]).rotated(-PI / 2.0)
	if values.flipped == "yes": point.x = -point.x
	point = point.rotated(deg_to_rad(float(values.rotation)))
	if values.anchored != "yes": point += Vector2(0.18, -0.16)
	return [point.x * 2, point.y * 2]


static func _path(result: Dictionary, points: Array, width: float, dashed: bool) -> void:
	result.paths.append({"points": points, "width": width, "dashed": dashed})


static func valid_view(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not value.has_all(["zoom", "x", "y"]): return false
	for field in ["zoom", "x", "y"]:
		if typeof(value[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value[field]): return false
	return value.zoom >= 1 and value.zoom <= 4 and abs(value.x) <= 1 and abs(value.y) <= 1
