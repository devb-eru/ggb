extends SceneTree


static func _text(key: String, locale: String) -> String:
	return TEXT.localized_text[locale][key]

const NOTES := preload("res://scripts/systems/notebook_chapter_surfaces.gd")
const TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const DISPLAY := preload("res://scripts/ui/chapter_one_display_texts.gd")
const CLOCK := preload("res://data/puzzles/puzzle_clock_network.tres")
var contents := {}


func _initialize() -> void:
	var path := "res://data/notebook/chapter_surfaces_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite frozen notebook content.")
		quit(1)
		return
	for key in ["DESK", "INDEX", "DRAWER", "ALCOVE", "GAP", "LINK"]:
		_add("INNER_"+key, _pair("CH1_INNER_LABEL_"+key), "B2", _pair("CH1_INNER_LABEL_"+key))
	for owner in ["EDGAR", "LUCA", "MARA1", "MARA2"]:
		for read in [false, true]:
			var texts := _pair("CH1_B1_DOC_"+owner)
			if read: texts = _join(texts, _pair("CH1_B1_READ"))
			_add("B1_DOC_%s_%s" % [owner, "READ" if read else "UNREAD"], texts, "B1", _pair("CH1_B1_DOC_"+owner))
	for key in ["inner_door", "north_known", "north_locked"]:
		var texts: Array = DISPLAY.UI_TEXT[key].duplicate()
		if key.begins_with("north_"): texts = _join(DISPLAY.UI_TEXT.north_link, texts, "\n")
		_add(key.to_upper(), texts, "B2", DISPLAY.UI_TEXT.inner_door if key == "inner_door" else DISPLAY.UI_TEXT.north_link)
	for key in ["HIDDEN_BOARD", "ENTRY"]:
		_add("B2_"+key, _pair("CH1_B2_"+key), "B2", ["기록 내실의 발소리", "Footsteps in the Inner Archive"])
	for id in range(3):
		for front in [false, true]:
			_add("J1_FRAGMENT_%d_%s" % [id, "FRONT" if front else "BACK"],
				_join(_pair("CH1_J1_FRAGMENT_%d" % id), _pair("CH1_J1_FRONT" if front else "CH1_J1_BACK"), "\n"),
				"J1", ["첫 일지의 조각", "First Journal Fragment"])
	var parts := {}
	for id in range(3):
		var pair := _pair("CH1_J1_FRAGMENT_%d" % id)
		parts[str(id)] = [pair[0].get_slice("\n",0), pair[1].get_slice("\n",0)]
	for length in range(4):
		var tokens := PackedStringArray()
		var specs := {}
		for index in range(length):
			tokens.append("{part%d}" % index)
			specs["part%d" % index] = "enum:fragment"
		_add("J1_ORDER_%d" % length, _join(_pair("CH1_J1_ORDER"), [" → ".join(tokens), " → ".join(tokens)]), "J1",
			["일지 조각의 현재 순서", "Current Journal Fragment Order"], specs, {} if length == 0 else {"fragment":_enum(parts)})
	var directions := {}
	for degrees in [0,90,180,270]: directions[str(degrees)] = _pair("CH1_CLOCK_DIR_%d" % degrees)
	_add("J2_BOARD", _join(_pair("CH1_J2_BOARD"),["{direction}","{direction}"]), "B5", ["일지와 파형의 방향", "Journal and Waveform Orientation"], {"direction":"enum:direction"}, {"direction":_enum(directions)})
	for key in ["LOCKED", "LAYOUT", "ROLES"]:
		_add("CLOCK_"+key, _pair("CH1_CLOCK_"+key), "BF" if key == "LOCKED" else ("B3_B" if key == "ROLES" else "B3_A"), ["시계망 점검함의 안내", "Clock Network Inspection Notice"])
	var collect := _pair("CH1_CLOCK_COLLECT")
	_add("CLOCK_COLLECT", [collect[0].replace("%d","{count}"),collect[1].replace("%d","{count}")], "B3_A", ["당일 시계 탁본", "Today's Clock Rubbings"], {"count":"int"})
	for id in ["bedroom","parlor","library_outer","great_clock","library_back"]:
		var name_id: String = "library_outer" if id == "library_back" else id
		var texts := []
		for locale in ["ko-KR","en-US"]:
			var template: String = _text("CH1_CLOCK_CARD",locale).replace("%d","{position}")
			texts.append(template % [_text("CH1_CLOCK_NAME_"+name_id.to_upper(),locale),"{direction}",
				_text("CH1_CLOCK_PATTERN_"+id.to_upper(),locale),_text("CH1_CLOCK_BACK" if id == "library_back" else "CH1_CLOCK_FRONT",locale)])
		_add("CLOCK_CARD_"+id.to_upper(), texts, "B3_A", _join(_pair("CH1_CLOCK_NAME_"+name_id.to_upper()),["의 탁본"," Rubbing"]), {"position":"int","direction":"enum:direction"}, {"direction":_enum(directions)})
	var clocks := {"unset":_pair("CH1_CLOCK_SELECT")}
	for id in CLOCK.CLOCKS: clocks[id] = _pair("CH1_CLOCK_NAME_"+String(id).to_upper())
	for role in CLOCK.ROLES:
		var label := _pair("CH1_CLOCK_ROLE_"+String(role).to_upper())
		_add("CLOCK_ROLE_"+String(role).to_upper(),_join(label,["{clock}","{clock}"]," · "),"B3_B",["시계망의 역할 배정","Clock Network Role Assignment"],{"clock":"enum:clock"},{"clock":_enum(clocks)})
		var row := _base("CLOCK_MENU_"+String(role).to_upper(),"B3_B",["표시된 역할 후보","Displayed Role Candidates"])
		_segment(row,"placeholder",_join(label,_pair("CH1_CLOCK_SELECT")," · "))
		for id in CLOCK.CLOCKS: _segment(row,String(id),_join(label,clocks[id]," · "))
		contents[NOTES.PREFIX+row.source_symbol] = {"1":row}
	for index in range(4):
		for selected in [false,true]:
			var texts := _pair("CH1_CLOCK_PHASE_%d" % index)
			if selected: texts = _join(texts,_pair("CH1_CLOCK_SELECTED"))
			_add("CLOCK_PHASE_%d_%s" % [index,"SELECTED" if selected else "UNSELECTED"],texts,"B3_B",["시계망의 전달 시점","Clock Network Transmission Timing"])
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not NOTES.CONTENT._valid_row(row):
			push_error("Invalid chapter surface: "+id)
			quit(1)
			return
		count += row.visible_segment_ids.size()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1,"contents":contents},"\t",true)+"\n")
	file.close()
	print("NOTEBOOK_CHAPTER_SURFACES_SEED: %d IDs / %d segments" % [contents.size(),count])
	quit()


func _pair(key: String) -> Array:
	return [_text(key,"ko-KR"),_text(key,"en-US")]


func _join(left: Array, right: Array, separator: String = "") -> Array:
	return [left[0]+separator+right[0],left[1]+separator+right[1]]


func _enum(pairs: Dictionary) -> Dictionary:
	var result := {"ko-KR":{},"en-US":{}}
	for key in pairs:
		result["ko-KR"][key] = pairs[key][0]
		result["en-US"][key] = pairs[key][1]
	return result


func _base(key: String, event: String, title: Array) -> Dictionary:
	return {"producer_id":"NP21","source_file":"scripts/chapters/chapter_one_controller.gd","source_symbol":key,
		"event_id":event,"node_ids":NOTES.NODES.duplicate(),"action_or_variant":key,"speaker_id":"SYSTEM",
		"location_source":"actual_display_before_action","entry_kind":"document_segment","disclosure_owner":"actual_display",
		"mapping_status":"AUTHORED_ID","owner":"planning/engineering","visible_segment_ids":[],"variables":{},"localization_keys":{},
		"protection_reasons":["clue_source"],"locales":{"ko-KR":{"speaker":"장면","title":title[0],"summary":"당시 화면에 표시된 자료"},
		"en-US":{"speaker":"Scene","title":title[1],"summary":"Material displayed at that time"}}}


func _segment(row: Dictionary, id: String, texts: Array, specs: Dictionary = {}) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = specs
	row.localization_keys[id] = row.source_symbol+":"+id
	row.locales["ko-KR"][id] = texts[0]
	row.locales["en-US"][id] = texts[1]


func _add(key: String, texts: Array, event: String, title: Array, specs: Dictionary = {}, enums: Dictionary = {}) -> void:
	var row := _base(key,event,title)
	if not enums.is_empty(): row["enums"] = enums
	_segment(row,"body",texts,specs)
	contents[NOTES.PREFIX+key] = {"1":row}
