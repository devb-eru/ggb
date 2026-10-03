extends SceneTree

const NOTES := preload("res://scripts/systems/notebook_puzzle_surfaces.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const MIRROR := preload("res://scripts/ui/black_mirror_display_texts.gd")
const BASEMENT := preload("res://scripts/ui/basement_display_texts.gd")
const CHAPTER_TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
var contents := {}


func _initialize() -> void:
	var path := "res://data/notebook/puzzle_surfaces_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite frozen notebook content.")
		quit(1)
		return
	for key in ["tool_room_board", "color_open", "color_closed", "bell_board", "locked_board"]:
		_add("C_" + key.to_upper(), MIRROR.UI[key], NOTES.C_NODES)
	for signal_ready in [false, true]:
		_add("C_READY_" + ("SIGNAL" if signal_ready else "CLOCK"), [MIRROR.ui("cleaner_ready","ko-KR")+" · "+MIRROR.ui("cleaner_mirror" if signal_ready else "cleaner_clock","ko-KR"), MIRROR.ui("cleaner_ready","en-US")+" · "+MIRROR.ui("cleaner_mirror" if signal_ready else "cleaner_clock","en-US")], NOTES.C_NODES)
	for owner in MIRROR.CHANNELS:
		for checked in [false,true]:
			_add("C_CHANNEL_%s_%s" % [owner, "CHECKED" if checked else "UNCHECKED"], [MIRROR.channel(owner,"ko-KR")+(MIRROR.ui("scan_done","ko-KR") if checked else ""), MIRROR.channel(owner,"en-US")+(MIRROR.ui("scan_done","en-US") if checked else "")], NOTES.C_NODES)
	for index in range(4): _add("J3_PART_%d" % index, MIRROR.J3_PARTS[index], NOTES.C_NODES)
	_add("MIXTURE", ["8단위 병: 물 {water} / 안정제 {stabilizer} / 원액 {active}\n확산: {dispersed} · 혼합: {mixed}회 · {foam}", "8-unit bottle: Water {water} / Stabilizer {stabilizer} / Active {active}\nDispersion: {dispersed} · Mixed: {mixed} time(s) · {foam}"], NOTES.C_NODES,
		{"water":"int","stabilizer":"int","active":"int","mixed":"int","dispersed":"enum:dispersion","foam":"enum:foam"},
		{"dispersion":_enum({"yes":["완료","Complete"],"no":["미확인","Unverified"]}), "foam":_enum({"yes":["거품 있음","Foamy"],"no":["거품 없음","No foam"]})})
	for length in range(5): _trace(length)
	for length in range(1,5):
		var ko := PackedStringArray()
		var vars := {}
		for index in range(length):
			ko.append("{part%d}" % index)
			vars["part%d" % index] = "enum:part"
		var parts := {}
		for index in range(4): parts[str(index)] = [MIRROR.j3_part(index,"ko-KR").get_slice("\n",0),MIRROR.j3_part(index,"en-US").get_slice("\n",0)]
		_add("J3_ORDER_%d" % length, [" → ".join(ko)," -> ".join(ko)], NOTES.C_NODES, vars, {"part":_enum(parts)})
	for key in ["drawer_board", "axis_locked", "point_bedroom", "point_greenhouse", "point_great_clock"]:
		_add("D_" + key.to_upper(), BASEMENT.UI[key], NOTES.D_NODES)
	for key in BASEMENT.STORAGE: _add("D_STORAGE_" + String(key).to_upper(), BASEMENT.STORAGE[key], NOTES.D_NODES)
	var anchors := BASEMENT.ANCHORS.duplicate(true)
	anchors["unset"] = anchors[""]
	anchors.erase("")
	_add("FLOORPLAN", ["평면도와 C5 투명지\n회전 {rotation}° · {flipped} · 고정점 {anchor}\n세 기준점뿐 아니라 거울에 뒤집힌 글자의 방향도 확인한다.", "Floorplan and C5 transparency\nRotation {rotation}° · {flipped} · Anchor: {anchor}\nCheck both the three landmarks and the direction of the mirror-reversed lettering."], NOTES.D_NODES, {"rotation":"int","flipped":"enum:flipped","anchor":"enum:anchor"},
		{"flipped":_enum({"yes":["좌우 반전","Horizontally mirrored"],"no":["반전 없음","Not mirrored"]}),"anchor":_enum(anchors)})
	for id in BASEMENT.AXES:
		_add("AXIS_" + String(id).to_upper() + "_PUSHED", [BASEMENT.axis_name(id,"ko-KR")+" · 밀기 완료",BASEMENT.axis_name(id,"en-US")+" · Pushed"], NOTES.D_NODES)
		_add("AXIS_" + String(id).to_upper() + "_DEPTH", [BASEMENT.axis_name(id,"ko-KR")+" · 깊이 {depth}",BASEMENT.axis_name(id,"en-US")+" · Depth {depth}"], NOTES.D_NODES, {"depth":"int"})
	var enums := {}
	for ring in range(3):
		var glyphs := {}
		for position in range(4): glyphs[str(position)] = BASEMENT.GLYPHS[ring][position]
		enums["ring%d" % ring] = _enum(glyphs)
	_add("HEART", ["외곽 · 중간 · 안쪽\n{ring0} / {ring1} / {ring2}\n정상 레버: {wind} / XII", "Outer · Middle · Inner\n{ring0} / {ring1} / {ring2}\nNormal Lever: {wind} / XII"], NOTES.D_NODES, {"ring0":"enum:ring0","ring1":"enum:ring1","ring2":"enum:ring2","wind":"int"}, enums)
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		var title := _title(row.source_symbol)
		row.locales["ko-KR"].title = title[0]
		row.locales["en-US"].title = title[1]
		if not CONTENT._valid_row(row):
			push_error("Invalid puzzle row: " + id)
			quit(1)
			return
		count += row.visible_segment_ids.size()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1,"contents":contents},"\t",true)+"\n")
	file.close()
	print("NOTEBOOK_PUZZLE_SURFACES_SEED: %d IDs / %d segments" % [contents.size(),count])
	quit()


func _trace(length: int) -> void:
	var route := PackedStringArray()
	var specs := {"rotation":"int","flipped":"enum:flip","anchored":"enum:anchor"}
	for index in range(length):
		route.append("{route%d}" % index)
		specs["route%d" % index] = "enum:route"
	var enums := {"flip":_enum({"yes":["반전","Mirrored"],"no":["반전 없음","Not mirrored"]}), "anchor":_enum({"yes":["고정","Anchored"],"no":["미고정","Not anchored"]}), "route":_enum(MIRROR.SEGMENTS)}
	var texts := ["투명지 {rotation}° · {flipped} · 하단 기준점 {anchored}\n계획: " + " → ".join(route), "Tracing {rotation}° · {flipped} · Lower reference {anchored}\nRoute: " + " -> ".join(route)]
	_add("TRACE_%d" % length, texts, NOTES.C_NODES, specs, enums)
	var row := _base("OVERLAY_%d" % length, NOTES.C_NODES)
	row.enums = enums
	for locale in ["ko-KR", "en-US"]: row.locales[locale].speaker = CHAPTER_TEXT.localized_text[locale].HISTORY_OPTIONS
	row.choices = [{"kind":"ui"}]
	row.cancel_index = 0
	_segment(row,"header",MIRROR.UI.overlay_title)
	_segment(row,"body",MIRROR.UI.overlay_body)
	_segment(row,"state",texts,specs)
	_segment(row,"option_0",MIRROR.UI.overlay_back)
	contents[NOTES.PREFIX + "OVERLAY_%d" % length] = {"1":row}


func _add(key: String, texts: Array, nodes: Array, specs: Dictionary = {}, enums: Dictionary = {}) -> void:
	var row := _base(key,nodes)
	if not enums.is_empty(): row.enums = enums
	_segment(row,"body",texts,specs)
	contents[NOTES.PREFIX+key] = {"1":row}


func _base(key: String, nodes: Array) -> Dictionary:
	return {"producer_id":"NP07" if nodes == NOTES.C_NODES else "NP08",
		"source_file":"scripts/chapters/black_mirror_controller.gd" if nodes == NOTES.C_NODES else "scripts/chapters/basement_controller.gd",
		"source_symbol":key,"event_id":_event(key),"node_ids":nodes.duplicate(),"action_or_variant":key,"speaker_id":"SYSTEM",
		"location_source":"actual_display_before_action","entry_kind":"document_segment","disclosure_owner":"actual_display",
		"mapping_status":"AUTHORED_ID","owner":"planning/engineering","visible_segment_ids":[],"variables":{},"localization_keys":{},
		"protection_reasons":["clue_source"],"locales":{"ko-KR":{"speaker":"장면","title":"퍼즐에서 확인한 자료","summary":"당시 화면에서 확인한 배치와 표시"},"en-US":{"speaker":"Scene","title":"Observed Puzzle Material","summary":"The arrangement and labels displayed at that time"}}}


func _segment(row: Dictionary, id: String, texts: Array, specs: Dictionary = {}) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = specs
	row.localization_keys[id] = row.source_symbol+":"+id
	row.locales["ko-KR"][id] = texts[0]
	row.locales["en-US"][id] = texts[1]


func _enum(pairs: Dictionary) -> Dictionary:
	var result := {"ko-KR":{},"en-US":{}}
	for key in pairs:
		result["ko-KR"][key] = pairs[key][0]
		result["en-US"][key] = pairs[key][1]
	return result


func _title(key: String) -> Array:
	if key.begins_with("C_CHANNEL_"):
		var owner := key.trim_prefix("C_CHANNEL_").get_slice("_",0)
		return [MIRROR.channel(owner,"ko-KR").get_slice(" · ",0)+"의 진단면 서명", MIRROR.channel(owner,"en-US").get_slice(" · ",0)+" Diagnostic Signature"]
	if key.begins_with("J3_PART_"): return ["세 번째 일지의 문장 조각","A Sentence Fragment of the Third Journal"]
	if key.begins_with("J3_ORDER_"): return ["일지 조각의 현재 배치","Current Journal Fragment Order"]
	if key.begins_with("TRACE_"): return ["투명지 방향과 선택 경로","Tracing Orientation and Selected Route"]
	if key.begins_with("OVERLAY_"): return MIRROR.UI.overlay_title
	if key.begins_with("C_READY_"): return ["준비된 세정제","Prepared Cleaning Solution"]
	if key.begins_with("D_POINT_"): return BASEMENT.UI["point_"+key.trim_prefix("D_POINT_").to_lower()]
	if key.begins_with("D_STORAGE_"): return BASEMENT.STORAGE[key.trim_prefix("D_STORAGE_").to_lower()]
	if key.begins_with("AXIS_"):
		var axis := key.trim_prefix("AXIS_").get_slice("_",0).to_lower()
		return [BASEMENT.axis_name(axis,"ko-KR")+"의 표시", BASEMENT.axis_name(axis,"en-US")+" Display"]
	return {
		"C_TOOL_ROOM_BOARD":["도구실의 청소 안내","Tool Room Cleaning Notice"],
		"C_COLOR_OPEN":["색분해실 입구","Color Separation Room Entrance"],
		"C_COLOR_CLOSED":["색분해실 입구","Color Separation Room Entrance"],
		"C_BELL_BOARD":["대시계의 신호","The Great Clock Signal"],
		"C_LOCKED_BOARD":["거울 조사 잠금","Mirror Inspection Lock"],
		"MIXTURE":["세정제의 현재 배합","Current Cleaning Mixture"],
		"D_DRAWER_BOARD":["서재 책상의 눌림점","Impressions on the Archive Desk"],
		"D_AXIS_LOCKED":["지하 축 장치의 잠금","Basement Axis Lock"],
		"FLOORPLAN":["평면도와 투명지","Floorplan and Transparency"],
		"HEART":["태엽 심장의 문양과 레버","Clockwork Heart Glyphs and Lever"],
	}[key]


func _event(key: String) -> String:
	if key.begins_with("C_CHANNEL_") or key.begins_with("C_COLOR_"): return "C5_INFO"
	if key.begins_with("J3_"): return "J3"
	if key.begins_with("TRACE_") or key.begins_with("OVERLAY_"): return "C4"
	if key.begins_with("C_READY_") or key == "MIXTURE": return "C3"
	if key.begins_with("D_POINT_") or key == "D_DRAWER_BOARD": return "D0"
	if key.begins_with("D_STORAGE_"): return "D2"
	if key.begins_with("AXIS_") or key == "D_AXIS_LOCKED": return "D1"
	return {"C_TOOL_ROOM_BOARD":"C2", "C_BELL_BOARD":"C_BELL", "C_LOCKED_BOARD":"CF", "FLOORPLAN":"D0_A", "HEART":"D4"}[key]
