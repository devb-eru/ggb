extends SceneTree

const NOTES := preload("res://scripts/systems/stay_notebook.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const CHARTER := preload("res://scripts/ui/stay_charter_texts.gd")
const STORY := preload("res://scripts/ui/stay_story_texts.gd")
const COMMON := preload("res://data/dialogue/prologue/prologue_text.tres")
const CH1 := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const SYSTEM := preload("res://data/dialogue/system/foundation_text_catalog.tres")
var contents := {}
var failed := false


func _initialize() -> void:
	var path := "res://data/notebook/stay_v1.json"
	if FileAccess.file_exists(path):
		push_error("Refusing to overwrite frozen notebook content.")
		quit(1)
		return
	for index in range(3):
		_add("MEMORY_%d" % index, [CHARTER.principle(index,"ko-KR"), CHARTER.principle(index,"en-US")], ["EDS_MEMORY_CHARTER"], "dialogue")
		for checked in [false,true]:
			_add("MEMORY_LABEL_%d_%s" % [index,"CHECKED" if checked else "UNCHECKED"], [CHARTER.text("principle","ko-KR") % [index+1,CHARTER.text("checked","ko-KR") if checked else ""], CHARTER.text("principle","en-US") % [index+1,CHARTER.text("checked","en-US") if checked else ""]], ["EDS_MEMORY_CHARTER"])
	_choices("MEMORY_FINISH", [_charter("memory_finish")], ["EDS_MEMORY_CHARTER"])
	_choices("APPEARANCE", [[CHARTER.mode("layered","ko-KR"),CHARTER.mode("layered","en-US")], [CHARTER.mode("contextual","ko-KR"),CHARTER.mode("contextual","en-US")]], ["EDS_APPEARANCE_CONTROL"])
	_choices("APPEARANCE_FINISH", [_charter("appearance_finish")], ["EDS_APPEARANCE_CONTROL"])
	_add("AUTONOMY", _charter("autonomy"), ["EDS_AUTONOMY_CHARTER"])
	for owner in CHARTER.OWNERS:
		for proposed in [false,true]:
			_choices("ROLE_%s_%s" % [String(owner).to_upper(),"PROPOSED" if proposed else "FIXED"], [[CHARTER.owner(owner,"ko-KR")+CHARTER.text("proposed" if proposed else "fixed","ko-KR"),CHARTER.owner(owner,"en-US")+CHARTER.text("proposed" if proposed else "fixed","en-US")]], ["EDS_AUTONOMY_CHARTER"])
	_choices("AUTONOMY_FINISH", [_charter("autonomy_finish")], ["EDS_AUTONOMY_CHARTER"])
	var settings_nodes := NOTES.NODES.duplicate()
	settings_nodes.erase("EDS_APPEARANCE_CONTROL")
	settings_nodes.push_front("EDS_APPEARANCE_CONTROL")
	_choices("MODE_SETTINGS", [_charter("keep"), _charter("layered_button"), _charter("contextual_button")], settings_nodes, [_charter("settings_title"),_charter("settings_body")])
	var channel_options := [_story("close")]
	for owner in CHARTER.OWNERS:
		channel_options.append([CHARTER.owner(owner,"ko-KR"),CHARTER.owner(owner,"en-US")])
		_add("CHANNEL_" + String(owner).to_upper(), [STORY.text("channel_selected","ko-KR") % CHARTER.owner(owner,"ko-KR"), STORY.text("channel_selected","en-US") % CHARTER.owner(owner,"en-US")], ["EDS_CENTRAL_HALL"])
	_choices("CHANNEL", channel_options, ["EDS_CENTRAL_HALL"], [_story("channel_title"),_story("channel_body")])
	for id in STORY.HALL:
		_add("HALL_LABEL_" + String(id).to_upper(), [STORY.hall(id,0,"ko-KR"),STORY.hall(id,0,"en-US")], ["EDS_CENTRAL_HALL"])
		if id != "cord": _add("HALL_READ_" + String(id).to_upper(), [STORY.hall(id,1,"ko-KR"),STORY.hall(id,1,"en-US")], ["EDS_CENTRAL_HALL"], "dialogue")
	for owner in STORY.TABLE:
		_add("TABLE_LABEL_" + String(owner).to_upper(), [STORY.table_title(owner,"ko-KR"),STORY.table_title(owner,"en-US")], ["EDS_TABLE_OBJECTS"])
		for complete in [false,true]:
			var index := 1 if complete else 2
			_add("TABLE_%s_%s" % [String(owner).to_upper(),"COMPLETE" if complete else "INCOMPLETE"], [STORY.RULES.TABLE[owner][index],STORY.TABLE[owner][index]], ["EDS_TABLE_OBJECTS"], "dialogue", [CHARTER.owner(owner,"ko-KR"),CHARTER.owner(owner,"en-US")] if complete else ["SYSTEM","SYSTEM"], String(owner).to_upper() if complete else "SYSTEM")
	for outcome in STORY.OVERLAYS:
		_add("OVERLAY_" + String(outcome).to_upper(), [STORY.RULES.OVERLAYS[outcome],STORY.OVERLAYS[outcome]], ["EDS_TABLE_OBJECTS"], "dialogue")
	for mode in ["public","direct_private","indirect","denied","withheld","inferred_only"]:
		var state := _state()
		for servant in state.meta_progress.servants.values(): servant.core_event_complete = mode == "public"
		state.meta_progress.servants.iris.core_event_complete = mode != "inferred_only"
		state.meta_progress.servants.iris.bond = 4 if mode == "direct_private" else 2 if mode == "indirect" else 0
		state.meta_progress.servants.iris.alert = 4 if mode == "denied" else 0
		_add("IRIS_" + String(mode).to_upper(), [STORY.table_lines(state,"iris","ko-KR").back().text,STORY.table_lines(state,"iris","en-US").back().text], ["EDS_TABLE_OBJECTS"], "dialogue", ["이리스","Iris"], "IRIS")
	for key in ["SEATING_SCREEN","SEATING_READ","FINAL_SEATING"]: _seating(key)
	_add("FINAL_OPENING", [NOTES.OPENING[0]+"\n"+NOTES.SENSORY[0],NOTES.OPENING[1]+"\n"+NOTES.SENSORY[1]], ["EDS_FINAL_FRAME"])
	for index in range(2):
		for written in [false,true]:
			var group := "WRITE_%d_%s" % [index,"WRITTEN" if written else "NEW"]
			_choices(group, [[STORY.text("written" if written else "write","ko-KR")+STORY.sentence(index,"ko-KR"),STORY.text("written" if written else "write","en-US")+STORY.sentence(index,"en-US")]], ["EDS_TABLE_OBJECTS"])
		var key := "NOTE_%d" % index
		_add(key, [STORY.sentence(index,"ko-KR"),STORY.sentence(index,"en-US")], ["EDS_TABLE_OBJECTS"], "document_segment", ["주인공","Protagonist"], "SUBJECT")
		var row: Dictionary = contents[NOTES.PREFIX + key]["1"]
		row.disclosure_owner = "event_note_commit"
		row.protection_reasons = ["knowledge"]
		row.knowledge = {"knowledge_id":"STAY_SENTENCE_%d" % index,"category":"document","epistemic_state":"observed","provenance_state":"identified","lifetime":"persistent"}
		row.source_knowledge_ids = []
		row.source_content_ids = []
		for state in ["NEW","WRITTEN"]:
			for suffix in ["OPTIONS","SELECT_0"]: row.source_content_ids.append(NOTES.PREFIX + "WRITE_%d_%s_%s" % [index,state,suffix])
	for tea in ["usual","warm","hot"]:
		_choices("TEA_" + tea.to_upper(), [[STORY.text("warm","ko-KR")+(STORY.text("selected","ko-KR") if tea == "warm" else ""),STORY.text("warm","en-US")+(STORY.text("selected","en-US") if tea == "warm" else "")], [STORY.text("hot","ko-KR")+(STORY.text("selected","ko-KR") if tea == "hot" else ""),STORY.text("hot","en-US")+(STORY.text("selected","en-US") if tea == "hot" else "")]], ["EDS_TABLE_OBJECTS"])
	var count := 0
	for id in contents:
		var row: Dictionary = contents[id]["1"]
		if not CONTENT._valid_row(row):
			failed = true
			push_error("Invalid stay row: " + id)
		for segment in row.visible_segment_ids:
			if RegEx.create_from_string("[가-힣]").search(row.locales["en-US"][segment]) != null: failed = true
		count += row.visible_segment_ids.size()
	if failed:
		quit(1)
		return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"format_version":1,"contents":contents},"\t",true)+"\n")
	file.close()
	print("NOTEBOOK_STAY_SEED: %d IDs / %d segments" % [contents.size(),count])
	quit()


func _state() -> Dictionary:
	var servants := {}
	for owner in STORY.RULES.OWNERS: servants[owner] = {"core_event_complete":false,"researcher_record_acquired":false,"bond":0,"alert":0}
	return {"meta_progress":{"servants":servants,"event_history":{},"knowledge_entries":{}}}


func _seating(key: String) -> void:
	var row := _base(key, ["EDS_FINAL_FRAME" if key == "FINAL_SEATING" else "EDS_DINING_ROOM"], "dialogue" if key == "SEATING_READ" else "document_segment", [])
	for count in [0,2,4,5]:
		var state := _state()
		for index in range(count): state.meta_progress.servants[STORY.RULES.OWNERS.keys()[index]].core_event_complete = true
		_segment(row,"intro_" + ("low" if count == 0 else "mid" if count == 2 else "four" if count == 4 else "all"), [STORY.seating(state,"ko-KR").get_slice("\n",0),STORY.seating(state,"en-US").get_slice("\n",0)])
	for owner in STORY.RULES.OWNERS:
		for sit in [false,true]:
			_segment(row,owner + ("_sit" if sit else "_stand"), [CHARTER.owner(owner,"ko-KR") + (": 앉을 자리를 직접 고른다." if sit else ": 서 있거나 이동할 자리를 직접 고른다."), CHARTER.owner(owner,"en-US") + (": chooses where to sit." if sit else ": chooses where to stand or move.")])
	if key == "FINAL_SEATING": _segment(row,"sensory", NOTES.SENSORY)
	contents[NOTES.PREFIX + key] = {"1":row}


func _choices(group: String, options: Array, nodes: Array, modal: Array = []) -> void:
	var row := _base(group + "_OPTIONS",nodes,"options_presented",[_common("HISTORY_OPTIONS","ko-KR"),_common("HISTORY_OPTIONS","en-US")])
	row.protection_reasons = ["choice_context"]
	if not modal.is_empty():
		_segment(row,"header",modal[0])
		_segment(row,"body",modal[1])
		row.choices = []
		row.cancel_index = 0
	for index in range(options.size()):
		_segment(row,"option_%d" % index,options[index])
		var key := "%s_SELECT_%d" % [group,index]
		var kind := "choice_cancelled" if not modal.is_empty() and index == 0 else "choice_confirmed"
		_add(key,options[index],nodes,kind,[_common("HISTORY_SELECTED","ko-KR"),_common("HISTORY_SELECTED","en-US")])
		contents[NOTES.PREFIX + key]["1"].protection_reasons = ["choice"]
		if not modal.is_empty(): row.choices.append({"kind":kind,"content_id":NOTES.PREFIX + key})
	contents[NOTES.PREFIX + group + "_OPTIONS"] = {"1":row}


func _add(key: String, texts: Array, nodes: Array, kind: String = "document_segment", speakers: Array = [], speaker_id: String = "SYSTEM") -> void:
	var row := _base(key,nodes,kind,speakers,speaker_id)
	_segment(row,"body",texts)
	contents[NOTES.PREFIX + key] = {"1":row}


func _base(key: String, nodes: Array, kind: String, speakers: Array, speaker_id: String = "SYSTEM") -> Dictionary:
	if speakers.is_empty(): speakers = ["SYSTEM","SYSTEM"] if kind == "dialogue" else ["장면","Scene"]
	return {"producer_id":"NP19","source_file":"scripts/chapters/basement_controller.gd","source_symbol":key,
		"event_id":nodes[0],"node_ids":nodes.duplicate(),"action_or_variant":key,"speaker_id":speaker_id,
		"location_source":"actual_ending_node_before_commit_or_display","entry_kind":kind,"disclosure_owner":"actual_display",
		"mapping_status":"AUTHORED_ID","owner":"planning/engineering","visible_segment_ids":[],"variables":{},"localization_keys":{},
		"protection_reasons":["clue_source"],"locales":{"ko-KR":{"speaker":speakers[0],"title":"잔류의 원칙과 저녁","summary":"당시 확인하거나 선택한 내용"},"en-US":{"speaker":speakers[1],"title":"Principles and an Evening of Staying","summary":"Only what was observed or selected at that time"}}}


func _segment(row: Dictionary, id: String, texts: Array) -> void:
	row.visible_segment_ids.append(id)
	row.variables[id] = {}
	row.localization_keys[id] = row.source_symbol + ":" + id
	row.locales["ko-KR"][id] = texts[0]
	row.locales["en-US"][id] = texts[1]


func _charter(id: String) -> Array: return [CHARTER.text(id,"ko-KR"),CHARTER.text(id,"en-US")]
func _story(id: String) -> Array: return [STORY.text(id,"ko-KR"),STORY.text(id,"en-US")]
func _common(id: String, locale: String) -> String:
	for resource in [COMMON,CH1,SYSTEM]:
		if resource.localized_text[locale].has(id): return resource.localized_text[locale][id]
	failed = true
	return ""
