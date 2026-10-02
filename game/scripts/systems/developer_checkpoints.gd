extends RefCounted

const DATA := "res://data/development/checkpoints.json"
const SLOT := "__dev_checkpoint"
const META_ROOT := "user://development/profile"
const NAMES := {
	"P1":"기상과 인사", "P2":"창문 닦기", "P3":"책 정리와 일지", "P3B":"초상화 이름표", "P4":"차 준비", "P4_MEMORY":"찻잔 기억 닻·아버지 질문", "P5":"온실 날씨 모순", "P6":"첫 취침",
	"A1":"수첩 표시 작성", "AS":"표시 후 취침", "A2":"수첩 지속 확인", "B1":"사용인 시간표", "B2":"서재 접근", "J1":"일지 1단계", "B3_A":"시계망 배선", "B3_B":"시계 역할·신호 위상", "BF":"시계 실패 후 리셋", "B4":"파형 기록", "B5":"일지 2단계 복원",
	"C_SLEEP":"J2 이후 취침", "C0":"검은 거울 조사", "C1":"코팅 가설", "C2":"청소·약품 정보 조사", "C3":"세정제 조합", "C_BELL":"두 번째 신호 발송", "C4":"거울 분기·빛 경로 시험", "CF":"거울 실패 후 리셋", "C5_INFO":"다섯 채널 기록", "J3":"일지 3단계",
	"D_SLEEP":"J3 이후 취침", "D0":"서재 지하 단서", "D0_A":"저택 도면 중첩", "D1":"지하창고 축 퍼즐", "DF":"지하축 실패 후 리셋", "D2":"지하창고 조사", "D4":"태엽 심장", "D5":"세계의 파열", "D6":"파열 후 휴식",
	"E1_ENTRY":"다른 아침", "LUCA_GUIDE":"루카의 안내", "LUCA_S2":"루카의 짧은 반응", "E2_INTRO":"리셋 실패 보고", "E_HUB":"관계 이벤트 선택", "E3_1":"마라 1 배선 수리", "E3_2":"이리스 센서 교정", "E3_3":"루카 생명 유지", "E3_4":"에드가 권한 복원", "E3_5":"마라 2 인격 복원", "J4":"일지 4단계", "E3_4M":"최소 코어 접근", "E5":"마지막 정상 저녁", "E6":"코어 접근",
	"F0_A":"깨진 방 연결", "F0_B":"시스템 신호 표본", "F0_C":"투명지 중첩", "F0_D":"기록 역할 배열", "F0_E":"과거·현재 이중 인증", "F1":"아버지의 마지막 기록", "F2":"연구원 대면", "F3":"마지막 확인", "EDC":"현실·잔류 선택",
	"EDC_LOW":"엔딩 선택 · 관계 LOW", "EDC_MID":"엔딩 선택 · 관계 MID", "EDC_HIGH":"엔딩 선택 · 관계 HIGH", "EDC_ALL":"엔딩 선택 · 5인 ALL",
	"EDR_FIELD_NOTEBOOK":"현실 · 현장 인계 수첩", "EDR_EXIT_PANEL":"현실 · 출구 점검", "ED_ALL_CEREMONY":"5인 전원 · 정체성 의식",
	"EDR_ENTRY":"현실 · 기상 절차 시작", "EDR_ARCHIVE_STATUS":"현실 · 인격 보존 상태", "EDR_FAREWELL":"현실 · 사용인 인계", "EDR_DISCONNECT":"현실 · 연결 해제", "EDR_WAKE_BODY":"현실 · 육체 기상", "EDR_BODY_CHECK":"현실 · 몸 상태 확인", "EDR_FACILITY_FREE_LOOK":"현실 · 시설 자유 조사", "EDR_AIRLOCK_CONFIRM":"현실 · 에어록", "EDR_SURFACE_THRESHOLD":"현실 · 지표 경계", "EDR_FINAL_FRAME":"현실 · 마지막 장면", "CREDITS_REALITY":"현실 · 크레딧",
	"EDS_ENTRY":"잔류 · 안정화 절차 시작", "EDS_STABILIZE":"잔류 · 안정화", "EDS_MEMORY_CHARTER":"잔류 · 기억 원칙", "EDS_APPEARANCE_CONTROL":"잔류 · 외형 원칙", "EDS_AUTONOMY_CHARTER":"잔류 · 사용인 자율성", "EDS_CENTRAL_HALL":"잔류 · 중앙홀", "EDS_DINING_ROOM":"잔류 · 식당", "EDS_TABLE_OBJECTS":"잔류 · 식탁과 수첩", "EDS_FINAL_FRAME":"잔류 · 마지막 장면", "CREDITS_STAY":"잔류 · 크레딧",
}
var _document: Dictionary = {}
var error := ""


func entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not OS.is_debug_build(): return rows
	if _document.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("checkpoints") is Dictionary:
			error = "개발 시점 데이터가 없거나 형식이 잘못되었습니다."
			return rows
		if parsed.get("design_revision") != GameState.DESIGN_REVISION:
			error = "개발 시점 데이터의 설계 버전이 다릅니다. 재생성이 필요합니다."
			return rows
		_document = parsed
	var ordered: Array = NAMES.keys()
	for id in _document.checkpoints:
		if id not in ordered: ordered.append(id)
	for id in ordered:
		if not _document.checkpoints.has(id): continue
		var checkpoint: Dictionary = _document.checkpoints[id]
		var snapshot: Dictionary = checkpoint.snapshot
		rows.append({"id":id,"title":NAMES.get(id, id),"room":snapshot.loop_state.location_id,"day":int(snapshot.loop_state.day_index),"journal":int(snapshot.meta_progress.journal_stage),"tier":snapshot.meta_progress.event_history.get("E5", {}).get("variant_id", "미결산")})
	return rows


func snapshot_for(id: String) -> Dictionary:
	if entries().is_empty() or not _document.checkpoints.has(id):
		return {"ok":false,"error_ids":["DEV_CHECKPOINT_UNKNOWN"]}
	var adapted := preload("res://scripts/systems/notebook_migration.gd").adapt_verified(_document.checkpoints[id].snapshot, ("development:" + id + ":" + JSON.stringify(_document.checkpoints[id].snapshot, "", true)).sha256_text(), preload("res://scripts/systems/notebook_rollout.gd").enabled())
	if not adapted.ok: return adapted
	var snapshot: Dictionary = adapted.snapshot
	# A fixture starts a new developer run, not the generator's ending-reselect copy.
	snapshot.meta_progress.knowledge_entries.erase("reselect_source_slot_id")
	snapshot.meta_progress.knowledge_entries.erase("reselect_source_run_id")
	if snapshot.ending_run.has("reselect_used"): snapshot.ending_run.reselect_used = false
	var validated := StateSnapshotValidator.new().validate(snapshot)
	if not validated.ok: return validated
	return {"ok":true,"snapshot":snapshot}


func activate(id: String, game: Node, saves: Node) -> Dictionary:
	if not OS.is_debug_build(): return {"ok":false,"error_ids":["DEV_DISABLED"]}
	var loaded := snapshot_for(id)
	if not loaded.ok: return loaded
	loaded.snapshot.meta_progress.dialogue_history = preload("res://scripts/systems/notebook_rollout.gd").fork_history(loaded.snapshot.meta_progress.dialogue_history)
	var transaction := StringName("NEW_GAME_DEV_JUMP_%d" % (game.revision + 1))
	var installed := StateWriter.new(game).install_snapshot(loaded.snapshot, game.revision, transaction)
	if not installed.ok: return installed
	var journal := int(loaded.snapshot.meta_progress.journal_stage)
	var save_point := "SAVE_NEW_GAME"
	if journal >= 3:
		save_point = preload("res://scripts/systems/basement_session.gd").new(game, saves, SLOT)._save_point(loaded.snapshot)
	elif loaded.snapshot.meta_progress.knowledge_entries.get("PROLOGUE_COMPLETE", false):
		save_point = "SAVE_CAMPAIGN_PROGRESS"
	var saved: Dictionary = saves.save_snapshot(SLOT, save_point, game.get_snapshot(), game.revision, String(transaction))
	if not saved.get("ok", false):
		game.rollback_failed_persistence(installed.previous_snapshot, installed.revision, transaction, &"DEV_SAVE_FAILED")
		return saved
	return {"ok":true,"slot_id":SLOT}
