extends RefCounted

const A := preload("res://scripts/systems/core_room_network.gd")
const B := preload("res://scripts/systems/core_samples.gd")
const C := preload("res://scripts/systems/core_overlay.gd")
const D := preload("res://scripts/systems/core_record_roles.gd")
const E := preload("res://scripts/systems/core_self_authority.gd")
const DISPLAY := preload("res://scripts/ui/core_story_texts.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const PUBLIC_LABELS := preload("res://scripts/systems/notebook_puzzle_labels.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const MARK_SOURCE := preload("res://scripts/systems/chapter_one_session.gd")
const MARK_TEXT := preload("res://data/dialogue/chapter_one/chapter_one_text.tres")
const PREFIX := "NB_CORE_"
const OWNERS := ["father", "system", "subject", "servant"]
const INTENTS := ["reality", "stay", "undecided"]
const TEXT := {
	"A_SIGNAL_HEADER": "약한 신호 경로",
	"A_SIGNAL_BROKEN": "끊긴 포트",
	"A_SIGNAL_COMPLETE": "물질 공급과 데이터 피드백이 한 회로로 돌아온다. 중앙 요청 포트까지 연결되었다.",
	"A_SIGNAL_NORTH": "북쪽 외부 대기 입력: 환경 제어 수신 불일치",
	"A_SIGNAL_WEST": "서쪽 중앙 코어 요청: 관리 인덱스 응답 없음",
	"B_RETRY": "표본과 다른 검증 채널은 손상되지 않았다. 연결 끝을 다시 조사할 수 있다.",
	"B_HINT": "주인공: 몸을 유지하는 것과 저택을 연출하는 것을 나눠 봐야 해.",
	"B_COMPLETE": "4 CHANNELS VERIFIED / ACCESS DENIED\n네 유지 채널 검증 완료 / 접근 권한 없음\n낮은 맥박은 안정되었지만 문은 열리지 않는다. 네 개의 연결선 옆에 이름 없는 빈자리가 남는다.",
	"C_VERIFY_0": "세 자료의 진동 주기가 다르다.",
	"C_VERIFY_1": "중심은 맞지만 분기선이 끊긴다.",
	"C_VERIFY_2": "빈 포트 외곽 일부가 나타난다.",
	"C_VERIFY_3": "완전 중첩. PATH·SPLIT·AUTH 조사점이 드러난다.",
	"C_INSPECT_PATH": "PATH 조사 완료", "C_INSPECT_SPLIT": "SPLIT 조사 완료", "C_INSPECT_AUTH": "이름 없는 포트가 열린다.",
	"D_ANONYMOUS": "익명 인덱스: 기능 정보는 보존되어 있다. 개인 음성과 감정 주석은 없다.",
	"D_COMPLETE": "SUBJECT RECORD FOUND / CONTINUITY VERIFIED / CURRENT AUTHORITY REQUIRED\n주인공 기록 발견 · 과거 연속성 확인 · 현재 권한 확인 필요\n다섯 역할이 구분되었다. 주인공 수첩에만 현재의 응답을 요구한다.",
	"D_LOCK_OFFER": "현재 올바르게 놓인 슬롯 하나를 선택해 고정할 수 있다.",
	"D_LOCK": "올바른 역할 슬롯 하나를 고정했다. 다른 슬롯은 계속 바꿀 수 있다.",
	"E_PAST": "PAST SELF / CONTINUITY VERIFIED\n과거 자기 기록의 연속성이 확인되었다. 현재의 빈 줄은 아직 쓰이지 않았다.",
	"E_AUTHOR": "주인공이 빈 줄에 직접 쓴다.\n이 문장은 지금의 내가 쓴다.\nCURRENT AUTHOR: SUBJECT / AUTHORITY RESTORED\n현재 작성자: 주인공 · 권한 복원. 아직 현실이나 잔류를 고른 것은 아니다.",
}
const STATUS := {
	"C_SEQUENCE": "경로를 따라 분기를 확인하고 인증 고리를 조사한다.",
	"D_LOCK": "이 슬롯은 아직 검증되지 않았다.",
	"E_PAST": "이전 표시와 순서가 다르다. 수첩의 원래 표시를 다시 확인한다.",
	"E_AUTHOR": "문장 내용이 아니라 작성 주체가 다르다. 현재의 주인공이 직접 작성해야 한다.",
}


static func descriptor(key: String, values: Dictionary = {}) -> Dictionary:
	var id := PREFIX + key
	var version := PUBLIC_LABELS.version(id)
	var row := CONTENT.definition(id, version)
	var segments := {}
	for segment in row.get("visible_segment_ids", []):
		var variables := {}
		for name in row.variables[segment]:
			if values.has(name): variables[name] = values[name]
		segments[segment] = variables
	return CONTENT.descriptor(id, version, segments)


static func paragraphs(evidence: Array) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for item in evidence:
		var full := descriptor(item.key, item.get("vars", {}))
		for segment in CONTENT.definition(full.content_id, int(full.content_version)).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(full.content_id, int(full.content_version), {segment: full.segments[segment]}))
	return result


static func write(state: Dictionary, evidence: Array, context: Dictionary, locale: String) -> Dictionary:
	if not state.meta_progress.dialogue_history.has("schema_version"): return {"ok": true}
	for item in evidence:
		var key: String = item.key
		var note := ""
		if key == "D_ANONYMOUS": note = "D_INDEX_RECORD"
		elif key == "E_AUTHOR": note = "E_AUTHOR_RECORD"
		elif key.begins_with("E_INTENT_"): note = key + "_RECORD"
		if note.is_empty(): continue
		var row := CONTENT.definition(PREFIX + note, 1)
		if row.is_empty(): return {"ok": false, "error_ids": ["NB_CORE_NOTE_UNMAPPED"]}
		var written := EVENT_NOTES.write(state, PREFIX + note, row.locales["ko-KR"].body, context, locale)
		if not written.ok: return written
	return {"ok": true}


static func event_for(key: String) -> String:
	return "F0_" + key.trim_prefix("SCREEN_").trim_prefix("STATUS_").left(1)


static func rows() -> Dictionary:
	var result := {}
	for key in TEXT: result[key] = fixed(TEXT[key])
	for key in STATUS: result["STATUS_" + key] = fixed(STATUS[key], false)
	result.A_NOTES = fixed(A.NOTES)
	result.A_SIGNAL_PATH = dynamic("{direction} {room} → {target_direction} {target_room}", "{direction} {room} → {target_direction} {target_room}", {"direction":"direction", "room":"room", "target_direction":"direction", "target_room":"room"})
	result.A_SIGNAL_RECEIVER = dynamic("{direction} 출력: {room}의 수신 기능과 맞지 않음", "{direction} output: incompatible with {room}'s receiving function", {"direction":"direction", "room":"room"})
	result.A_SIGNAL_CORRIDOR = dynamic("{direction} 회랑 연결: 출력이 다음 실물 포트에 닿지 않음", "{direction} corridor connection: output does not reach the next physical port", {"direction":"direction"})
	result.B_MAINTENANCE = dynamic("{room}: MAINTENANCE DATA · 실제 유지 데이터", "{room}: MAINTENANCE DATA · sustaining data", {"room":"room"})
	result.B_PRESENTATION = dynamic("{room}: PRESENTATION DATA · 표현용 데이터 반환", "{room}: PRESENTATION DATA · presentation sample returned", {"room":"room"})
	result.B_COUNT = dynamic("검증된 채널 {count} / 4", "Verified channels: {count} / 4", {"count":"int"})
	result.D_COUNT = dynamic("일치한 역할 {count} / 5", "Roles matched: {count} / 5", {"count":"int"})
	for room in B.ROOMS:
		for index in range(2): result["B_SAMPLE_%s_%d" % [String(room).to_upper(), index]] = fixed(B.NAMES[room] + " · " + B.SAMPLES[room][index].label + "\n" + B.SAMPLES[room][index].trace)
	for record in D.RECORDS: result["D_RECORD_" + String(record).to_upper()] = fixed(D.NAMES[record] + "\n" + D.FACTS[record])
	for index in range(5): result["D_HINT_%d" % index] = fixed(D.LABELS[index] + " : " + D.SENTENCES[index])
	for intent in INTENTS:
		result["E_INTENT_" + intent.to_upper()] = fixed("주인공: " + E.REACTIONS[intent] + "\n비공개 임시 의향 기록 · 구속력 없음\n주인공 권한 복원 · 최종 결정 미정\n이 기록은 사용인에게 전달되지 않는다. 마지막 선택에서 다시 결정할 수 있다.")
		var note := fixed(E.INTENTS[intent], false)
		note.en = DISPLAY.INTENTS_EN[intent]
		note.knowledge_id = "F0_PROVISIONAL_INTENT"
		note.source_knowledge_ids = ["F0_CURRENT_AUTHOR"]
		note.source_content_ids = [PREFIX + "E_INTENT_OPTIONS", PREFIX + "E_INTENT_SELECT_%d" % INTENTS.find(intent)]
		result["E_INTENT_" + intent.to_upper() + "_RECORD"] = note
	result.D_INDEX_RECORD = fixed(TEXT.D_ANONYMOUS, false)
	result.D_INDEX_RECORD.knowledge_id = "ANON_PURPLE_RESIDENT_INDEX"
	result.D_INDEX_RECORD.source_knowledge_ids = ["J4"]
	result.D_INDEX_RECORD.source_content_ids = []
	result.E_AUTHOR_RECORD = fixed("이 문장은 지금의 내가 쓴다.", false)
	result.E_AUTHOR_RECORD.knowledge_id = "F0_CURRENT_AUTHOR"
	result.E_AUTHOR_RECORD.source_knowledge_ids = ["A1"]
	result.E_AUTHOR_RECORD.source_content_ids = [PREFIX + "E_PAST", PREFIX + "E_AUTHOR_OPTIONS", PREFIX + "E_AUTHOR_SELECT_2"]
	for stage in ["a", "b", "c", "d"]: result["SCREEN_" + stage.to_upper() + "_GUIDE"] = ui("f0" + stage + "_board")
	for kind in ["author", "intent"]: result["SCREEN_E_" + kind.to_upper()] = ui("f0e_" + kind + "_board")
	for selected in [false, true]:
		var suffix := "_YES" if selected else "_NO"
		var ko := " [선택]" if selected else ""
		var en := " [Selected]" if selected else ""
		result["SCREEN_A_TILE" + suffix] = dynamic("{direction} · {room}" + ko + "\n{port}\n출력 → {output}", "{direction} · {room}" + en + "\n{port}\nOutput → {output}", {"direction":"direction", "room":"room", "port":"port", "output":"direction"}, false)
		result["SCREEN_B_ROOM" + suffix] = dynamic("{room}" + (" · 검증 완료" if selected else ""), "{room}" + (" · Verified" if selected else ""), {"room":"room"}, false)
		for room in B.ROOMS:
			for index in range(2): result["SCREEN_B_SAMPLE_%s_%d" % [String(room).to_upper(), index] + suffix] = dynamic(B.SAMPLES[room][index].label + ko, DISPLAY.SAMPLE_LABELS_EN[room][index] + en, {}, false)
		for anonymous in [false, true]:
			result["SCREEN_D_CARD" + suffix + ("_ANON" if anonymous else "")] = dynamic("{record}" + (" · 익명 인덱스" if anonymous else "") + ko, "{record}" + (" · Anonymous index" if anonymous else "") + en, {"record":"record"}, false)
		result["SCREEN_D_SLOT" + suffix] = dynamic("{role}\n{record}" + (" [고정]" if selected else ""), "{role}\n{record}" + (" [Locked]" if selected else ""), {"role":"role", "record":"record_or_empty"}, false)
	for layer in C.LAYERS:
		result["SCREEN_C_LAYER_" + layer] = dynamic(PUBLIC_LABELS.layer_name(layer, "ko-KR") + " · {degrees}° · {flipped} · {anchor}\n투명도 {opacity}", PUBLIC_LABELS.layer_name(layer, "en-US") + " · {degrees}° · {flipped} · {anchor}\nOpacity {opacity}", {"degrees":"int", "flipped":"flipped", "anchor":"anchor", "opacity":"int"}, false)
		result["SCREEN_C_LAYER_" + layer].visual = preload("res://scripts/chapters/core_overlay_board.gd").visual_manifest(layer)
	for point in C.INVESTIGATION: result["SCREEN_C_" + point] = ui(String(point).to_lower())
	for type in E.MARKS:
		var ko: String = MARK_SOURCE.MARKS[type]
		var en: String = MARK_TEXT.localized_text["en-US"]["CH1_MARK_" + String(type).to_upper()]
		for empty in [false, true]:
			result["SCREEN_E_MARK_" + String(type).to_upper() + ("_EMPTY" if empty else "")] = dynamic("처음 직접 남긴 표시: " + ko + "\n현재 배열: " + ("" if empty else "{sequence}"), "Original self-authored mark: " + en + "\nCurrent sequence: " + ("" if empty else "{sequence}"), {} if empty else {"sequence":"mark_" + type}, false)
		for index in range(3): result["SCREEN_E_PIECE_%s_%d" % [String(type).to_upper(), index]] = dynamic(E.MARKS[type][index], DISPLAY.MARKS_EN[type][index], {}, false)
	result.SCREEN_E_MARK_ORIGINAL = {"ko":"{original_text}", "en":"{original_text}", "vars":{"original_text":"string"}, "spoken":false, "original_only":true}
	return result


static func fixed(ko: String, spoken: bool = true) -> Dictionary:
	return {"ko": ko, "en": DISPLAY.feedback(ko, "en-US"), "vars": {}, "spoken": spoken}


static func ui(key: String) -> Dictionary:
	return {"ko":DISPLAY.UI[key][0], "en":DISPLAY.UI[key][1], "vars":{}, "spoken":false}


static func orders(prefix: Array = []) -> Array:
	var result: Array = [prefix.duplicate()]
	for index in range(3):
		if index not in prefix: result.append_array(orders(prefix + [index]))
	return result


static func mark_surface(mark: Dictionary, sequence: Array, locale: String) -> Dictionary:
	var type: String = mark.type
	var order := PackedStringArray()
	var shown := PackedStringArray()
	for piece in sequence:
		order.append(str(E.MARKS[type].find(piece)))
		shown.append(DISPLAY.mark_piece(type, piece, locale))
	if str(mark.get("text", "")) == MARK_SOURCE.MARKS[type]:
		return descriptor("SCREEN_E_MARK_" + type.to_upper() + ("_EMPTY" if sequence.is_empty() else ""), {} if sequence.is_empty() else {"sequence":"_".join(order)})
	var original := DISPLAY.text("f0e_mark", locale) % [str(mark.get("text", "")), " → ".join(shown)]
	return descriptor("SCREEN_E_MARK_ORIGINAL", {"original_text":original})


static func dynamic(ko: String, en: String, variables: Dictionary, spoken: bool = true) -> Dictionary:
	var types := {}
	for key in variables: types[key] = "int" if variables[key] == "int" else "enum:" + variables[key]
	return {"ko": ko, "en": en, "vars": types, "spoken": spoken}


static func enums() -> Dictionary:
	var ko := {"direction":{}, "room":A.NAMES, "port":A.PORTS, "record":D.NAMES, "record_or_empty":D.NAMES.duplicate(), "role":{}, "layer":{}, "flipped":{"no":"없음", "yes":"있음"}, "anchor":{}}
	var en := {"direction":{}, "room":DISPLAY.ROOM_NAMES_EN, "port":DISPLAY.PORTS_EN, "record":DISPLAY.RECORD_NAMES_EN, "record_or_empty":DISPLAY.RECORD_NAMES_EN.duplicate(), "role":{}, "layer":{}, "flipped":{"no":"No", "yes":"Yes"}, "anchor":{}}
	for index in range(4):
		ko.direction[str(index)] = A.DIRECTIONS[index]
		en.direction[str(index)] = DISPLAY.DIRECTIONS_EN[index]
		var key: String = ["anchor_unset", "anchor_origin", "anchor_right", "anchor_down"][index]
		ko.anchor[str(index - 1)] = DISPLAY.UI[key][0]
		en.anchor[str(index - 1)] = DISPLAY.UI[key][1]
	for index in range(5):
		ko.role[str(index)] = D.LABELS[index]
		en.role[str(index)] = D.LABELS[index]
	for layer in C.LAYERS:
		ko.layer[layer] = PUBLIC_LABELS.layer_name(layer, "ko-KR")
		en.layer[layer] = PUBLIC_LABELS.layer_name(layer, "en-US")
	ko.record_or_empty["empty"] = DISPLAY.UI.empty_slot[0]
	en.record_or_empty["empty"] = DISPLAY.UI.empty_slot[1]
	for type in E.MARKS:
		ko["mark_" + type] = {}
		en["mark_" + type] = {}
		for order in orders():
			if order.is_empty(): continue
			var key := PackedStringArray()
			var left := PackedStringArray()
			var right := PackedStringArray()
			for index in order:
				key.append(str(index))
				left.append(E.MARKS[type][index])
				right.append(DISPLAY.MARKS_EN[type][index])
			ko["mark_" + type]["_".join(key)] = " → ".join(left)
			en["mark_" + type]["_".join(key)] = " → ".join(right)
	var result := {}
	for key in ko: result[key] = {"ko-KR": ko[key], "en-US": en[key]}
	return result
