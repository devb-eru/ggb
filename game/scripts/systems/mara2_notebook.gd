extends RefCounted

const RULES := preload("res://scripts/systems/mara2_relationship.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const EVENT_NOTES := preload("res://scripts/systems/notebook_event_notes.gd")
const PREFIX := "NB_MARA2_"
const SCREEN := {
	"ENTRY": "마라 2가 이중 윤곽의 이름표를 바로 세운다.\n'천재의 작업실에 온 걸 환영해요! 손대다 망가뜨려도 제 탓은 아니고요!'",
	"OVERLAY": "세 시점 모두 같은 3·7·11칸이 비어 있다.\n마라 2가 먼저 문을 연다. 뒤돌아보지 않는다.",
	"COMPLETE": "원본과 감정 주석을 보존했다.\n수첩에서 REC_MARA2를 확인할 수 있다.",
}
const SOURCE_LABELS := ["문양을 다시 본다", "EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
const ALIGN_LABELS := ["표식을 다시 본다", "기준점 1", "기준점 2", "기준점 3"]
const CELL_LABELS := ["보조 기록을 다시 본다", "선", "점", "호"]
const ALIGN_BODY := "3음 시작 표식과 이중 윤곽 기준선을 맞춘다."
const CELL_BODY := "원본 참조가 같은 조각을 대조한다."
const COUNT_TEMPLATE := "체크섬 일치: {matches} / 12"
const GLYPHS := {"결손": "MISSING", "선": "LINE", "점": "DOT", "호": "ARC"}
const TITLES := {
	"SOURCE": ["세 시점의 인격 신호", "Personality Signals Across Three Moments"],
	"PORTRAIT": ["열화 순서에 놓은 조각", "Fragments Placed in Degradation Order"],
	"CLEAR": ["다시 비교하는 초상화", "Comparing the Portraits Again"],
	"ALIGN": ["시작점과 윤곽의 기준선", "Start Marks and Outline References"],
	"OVERLAY": ["세 시점의 공통 결손", "Shared Gaps Across Three Moments"],
	"CELL": ["결손 칸에 놓은 사본", "A Copy Placed in a Missing Cell"],
	"CHECKSUM_COUNT": ["확인한 체크섬 일치 수", "The Observed Checksum Match Count"],
	"CHECKSUM_SOLVED": ["분산된 주석의 원본", "The Original Distributed Annotations"],
	"CONFESS": ["마라 2의 이야기", "Mara 2's Account"],
	"CHOOSE_MERGED": ["다시 합친 원본과 주석", "Rejoining the Original and Annotations"],
	"CHOOSE_SEPARATED": ["분리한 두 기록의 참조선", "References Between Two Separate Records"],
	"ENTRY": ["천재의 작업실", "The Genius's Workshop"],
	"COMPLETE": ["보존된 마라 2의 기록", "Mara 2's Preserved Record"],
	"SOURCE_MISMATCH": ["서로 다른 소유자 신호", "Mismatched Owner Signals"],
	"OVERLAY_ORDER": ["이어지지 않는 열화", "Discontinuous Degradation"],
	"OVERLAY_START": ["갈라진 세 음", "The Three Tones Split Apart"],
	"OVERLAY_OUTLINE": ["겹쳐지지 않는 윤곽", "Outlines That Do Not Converge"],
}


static func paragraphs(keys: Array, variables: Dictionary = {}) -> Array:
	if not ROLLOUT.enabled(): return []
	var result: Array = []
	for key in keys:
		var id: String = PREFIX + key
		for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []):
			result.append(CONTENT.descriptor(id, 1, {segment: variables.duplicate(true) if key == "CHECKSUM_COUNT" else {}}))
	return result


static func options(key: String) -> Dictionary:
	var segments := {}
	var id := PREFIX + key + "_OPTIONS"
	for segment in CONTENT.definition(id, 1).get("visible_segment_ids", []): segments[segment] = {}
	return CONTENT.descriptor(id, 1, segments)


static func write(state: Dictionary, context: Dictionary, locale: String) -> Dictionary:
	return EVENT_NOTES.write(state, PREFIX + "RECORD", RULES.RECORD, context, locale)


static func portrait_text(id: String) -> String:
	var data: Dictionary = RULES.PORTRAITS[id]
	return "초상화 %s\n열화 단계 %d\n3음 시작 표식 %d · 윤곽 기준선 %d" % [id, data.wear, data.start + 1, data.outline + 1]


static func cell_key(index: int, glyph: String) -> String:
	return "SCREEN_CELL_%d_%s" % [index + 1, GLYPHS.get(glyph, "MISSING")]


static func authored_rows() -> Dictionary:
	var rows := {}
	for key in RULES.TEXT:
		rows[key] = _row(RULES.TEXT[key], TITLES.get(key, ["마라 2의 응답", "Mara 2's Response"]), "dialogue", "feedback")
	rows.CHECKSUM_COUNT = _row(COUNT_TEMPLATE, TITLES.CHECKSUM_COUNT, "dialogue", "feedback")
	rows.CHECKSUM_COUNT.variables = {"line_01": {"matches": "int"}}
	for owner in RULES.BACKUPS:
		rows["BACKUP_" + owner] = _row(RULES.backup_text(owner), [owner + " 보조 기록", owner + " Backup Record"], "dialogue", "feedback")
	for key in SCREEN: rows["SCREEN_" + key] = _row(SCREEN[key], TITLES[key], "document_segment", "displayed")
	for portrait in RULES.PORTRAITS:
		for owner in RULES.OWNERS:
			rows["SCREEN_SOURCE_" + portrait + "_" + owner] = _row(RULES.SIGNS[owner], ["초상화 " + portrait + "의 문양", "Portrait " + portrait + "'s Glyph"], "document_segment", "displayed")
		rows["SCREEN_PORTRAIT_" + portrait] = _row(portrait_text(portrait), ["초상화 " + portrait + "의 표식", "Portrait " + portrait + "'s Marks"], "document_segment", "displayed")
	for index in range(12):
		var glyphs: Array = GLYPHS.keys() if index in RULES.GAPS else [RULES.CHECKSUM[index]]
		for glyph in glyphs:
			rows[cell_key(index, glyph)] = _row("%d · %s" % [index + 1, glyph], ["체크섬 %d칸" % [index + 1], "Checksum Cell %d" % [index + 1]], "document_segment", "displayed")
	for key in RULES.STATUS: rows["STATUS_" + key] = _row(RULES.STATUS[key], TITLES[key], "document_segment", "displayed")
	rows.RECORD = _row(RULES.RECORD, ["마라 2의 연구 기록", "Mara 2's Research Record"], "document_segment", "recorded")
	return rows


static func modal_rows() -> Dictionary:
	var rows := {}
	for portrait in RULES.PORTRAITS:
		for owner in RULES.OWNERS:
			rows["SOURCE_" + portrait + "_" + owner] = {"title": "초상화 " + portrait, "body": RULES.SIGNS[owner], "labels": SOURCE_LABELS, "choice_group": "SOURCE", "titles": ["초상화의 신호 출처", "The Source of a Portrait's Signal"]}
		for kind in ["start", "outline"]:
			rows["ALIGN_" + portrait + "_" + kind.to_upper()] = {"title": "초상화 " + portrait, "body": ALIGN_BODY, "labels": ALIGN_LABELS, "choice_group": "ALIGN", "titles": ["초상화의 기준점 선택", "Choosing a Portrait's Reference Point"]}
	for index in RULES.GAPS:
		rows["CELL_%d" % (index + 1)] = {"title": "결손 %d칸" % (index + 1), "body": CELL_BODY, "labels": CELL_LABELS, "choice_group": "CELL", "titles": ["결손 칸의 조각 선택", "Choosing a Missing Cell's Fragment"]}
	return rows


static func source_ids() -> Array:
	var ids: Array = ["NB_MARA2_OVERLAY", "NB_MARA2_CHECKSUM_SOLVED", "NB_MARA2_CONFESS", "NB_MODAL_MARA2_SELECT_1", "NB_MODAL_MARA2_SELECT_2"]
	for owner in RULES.BACKUPS: ids.append(PREFIX + "BACKUP_" + owner)
	for portrait in RULES.PORTRAITS: ids.append(PREFIX + "SCREEN_PORTRAIT_" + portrait)
	return ids


static func _row(text: String, titles: Array, kind: String, variant: String) -> Dictionary:
	return {"text": text, "titles": titles, "kind": kind, "variant": variant}
