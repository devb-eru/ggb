extends SceneTree

const NOTES := preload("res://scripts/systems/notebook_prologue_surfaces.gd")
const TEXT := preload("res://data/dialogue/prologue/prologue_text.tres")
const OWNERS := ["EDGAR","MARA1","LUCA","IRIS","MARA2"]
const BOOKS := ["BOOK_MECHANICAL","BOOK_FLORA","BOOK_LEDGER"]
const ITEMS := ["HOT_WATER","CUP","TEA_LEAVES","HOT_WATER","TIMER","TEAPOT"]
var contents := {}
var used_keys := {}


func _initialize() -> void:
	var path := "res://data/notebook/prologue_surfaces_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite frozen notebook content.")
		quit(1)
		return
	for key in NOTES.FIXED+NOTES.WINDOW_FEEDBACK:
		_add(key,_pair(key),_event(key),_title(key))
	var stages := {}
	for index in range(4): stages[str(index)] = _pair(["P2_STAGE_TOP","P2_STAGE_MIDDLE","P2_STAGE_BOTTOM","UI_DUTY_COMPLETE"][index])
	var label := _pair("P2_WINDOW_LABEL")
	_add("P2_WINDOW_LABEL",[label[0].replace("{state}","{stage}"),label[1].replace("{state}","{stage}")],"P2",["창문의 청소 상태","Window Cleaning State"],{"index":"int","stage":"enum:stage"},{"stage":_enum(stages)})
	for inline_labels in [false,true]:
		var key := "WINDOW_INSPECTION_"+("INLINE" if inline_labels else "MULTILINE")
		var row := _base(key,"P2",["확대해서 본 창문","Window in Close View"])
		var states := {}
		for id in ["P2_SPREAD","P2_DUST","P2_CLEAR","P2_STAIN","P2_WET","P2_DRY"]: states[id] = _pair(id)
		row["enums"] = {"stage":_enum(stages),"state":_enum(states)}
		var title := _pair("P2_TITLE")
		_segment(row,"header",[title[0].replace("{state}","{stage}"),title[1].replace("{state}","{stage}")],{"index":"int","stage":"enum:stage"})
		for zone in ["top","middle","bottom"]:
			var texts := _pair("P2_"+zone.to_upper())
			for language in range(2):
				texts[language] = texts[language].replace("{state}","{"+zone+"}")
				if inline_labels: texts[language] = texts[language].replace("\n"," · ")
			_segment(row,zone,texts,{zone:"enum:state"})
		contents[NOTES.PREFIX+key] = {"1":row}
	var books := {}
	for id in BOOKS: books[id] = _pair("P3_NAME_"+id)
	for shelf in ["CLOCK","FLOWER","CUP"]:
		_add("P3_PLACED_"+shelf,_pair("P3_PLACED"),"P3",_pair("P3_SHELF_"+shelf),{"book":"enum:book"},{"book":_enum(books)})
	var owners := {}
	for id in OWNERS: owners[id] = _pair("P3B_"+id)
	for id in OWNERS:
		var visual := _pair("P3B_V_"+id)
		_add("PORTRAIT_"+id+"_UNASSIGNED",visual,"P3B",["초상화의 외형 표식","Portrait Appearance Marks"])
		_add("PORTRAIT_"+id+"_ASSIGNED",[visual[0]+"\n[{owner}]",visual[1]+"\n[{owner}]"],"P3B",["초상화와 붙인 이름표","Portrait and Attached Nameplate"],{"owner":"enum:owner"},{"owner":_enum(owners)})
	var steps := {}
	var items := {}
	for index in range(6):
		steps[str(index)] = _pair("P4_TEA_STEP_%d" % index)
		items[str(index)] = _pair("P4_TEA_ITEM_"+String(ITEMS[index]))
		for done in [false,true]:
			# Step six transitions to the cup scene; no completed sixth tile is ever displayed.
			if done and index == 5: continue
			var texts := []
			for language in range(2): texts.append("%d. %s\n%s%s" % [index+1,steps[str(index)][language],items[str(index)][language]," · "+_pair("UI_DUTY_COMPLETE")[language] if done else ""])
			_add("P4_STEP_%d_%s" % [index,"DONE" if done else "PENDING"],texts,"P4",["차 준비 순서","Tea Preparation Steps"])
	for key in ["P4_TEA_ORDER","P4_TEA_DONE"]:
		_add(key,_pair(key),"P4",["차 준비의 순서와 결과","Tea Preparation Order and Result"],{"step":"enum:step"},{"step":_enum(steps)})
	_add("P4_TEA_REQUIRES",_pair("P4_TEA_REQUIRES"),"P4",["차 준비에 필요한 도구","Tea Preparation Tools"],{"step":"enum:step","item":"enum:item"},{"step":_enum(steps),"item":_enum(items)})
	var handle := _pair("P4_LINK_HANDLE")
	_add("P4_HANDLE_LEFT",handle,"P4",["찻잔 손잡이의 방향","Cup Handle Direction"])
	var returned := _pair("P4_LINK_RETURNED")
	_add("P4_HANDLE_RETURNED",[handle[0]+returned[0],handle[1]+returned[1]],"P4",["되돌아온 손잡이","The Returned Handle"])
	for key in ["P5_CORRIDOR_LABEL","P5_GLASS_LABEL","P5_THRESHOLD_LABEL"]:
		for checked in [false,true]:
			var texts := _pair(key)
			if checked:
				var suffix := _pair("UI_P_CHECKED")
				texts = [texts[0]+"\n["+suffix[0]+"]",texts[1]+"\n["+suffix[1]+"]"]
			_add(key+("_CHECKED" if checked else "_UNCHECKED"),texts,"P5",["온실 앞에서 보이는 날씨","Weather at the Greenhouse Entrance"])
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--compare-prologue-source="): continue
		var other = ResourceLoader.load(arg.trim_prefix("--compare-prologue-source="),"",ResourceLoader.CACHE_MODE_IGNORE)
		if other == null:
			quit(1)
			return
		for key in used_keys:
			for locale in ["ko-KR","en-US"]:
				if other.localized_text[locale].get(key) != TEXT.localized_text[locale][key]:
					push_error("Actual prologue source differs: "+key+":"+locale)
					quit(1)
					return
		print("PROLOGUE_SURFACE_SOURCE_MATCH: ",used_keys.size()," bilingual keys")
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not NOTES.CONTENT._valid_row(row):
			push_error("Invalid prologue surface: "+id)
			quit(1)
			return
		count += row.visible_segment_ids.size()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1,"contents":contents},"\t",true)+"\n")
	file.close()
	print("NOTEBOOK_PROLOGUE_SURFACES_SEED: %d IDs / %d segments" % [contents.size(),count])
	quit()


func _pair(key: String) -> Array:
	used_keys[key] = true
	return [TEXT.localized_text["ko-KR"][key],TEXT.localized_text["en-US"][key]]


func _enum(pairs: Dictionary) -> Dictionary:
	var result := {"ko-KR":{},"en-US":{}}
	for key in pairs:
		result["ko-KR"][key] = pairs[key][0]
		result["en-US"][key] = pairs[key][1]
	return result


func _base(key: String, event: String, title: Array) -> Dictionary:
	return {"producer_id":"NP21","source_file":"scripts/prologue/prologue_controller.gd","source_symbol":key,"event_id":event,
		"node_ids":NOTES.NODES.duplicate(),"action_or_variant":key,"speaker_id":"SYSTEM","location_source":"actual_display_before_action",
		"entry_kind":"document_segment","disclosure_owner":"actual_display","mapping_status":"AUTHORED_ID","owner":"planning/engineering",
		"visible_segment_ids":[],"variables":{},"localization_keys":{},"protection_reasons":["clue_source"],
		"locales":{"ko-KR":{"speaker":"장면","title":title[0],"summary":"당시 화면에서 확인한 표식과 상태"},"en-US":{"speaker":"Scene","title":title[1],"summary":"Marks and conditions displayed at that time"}}}


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


func _event(key: String) -> String:
	return key.get_slice("_",0)


func _title(key: String) -> Array:
	if key in NOTES.WINDOW_FEEDBACK: return ["창문 청소 결과","Window Cleaning Result"]
	if key in ["P3_WRONG","P3_SILENT_STATUS"]: return ["서재에서 확인한 일","An Observation in the Library"]
	return _pair(key)
