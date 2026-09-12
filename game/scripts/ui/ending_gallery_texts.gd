extends RefCounted

const ENTRY := preload("res://scripts/systems/ending_entry.gd")
const WAKE := preload("res://scripts/ui/reality_wake_texts.gd")
const FIELD := preload("res://scripts/ui/field_notebook_texts.gd")
const SURFACE := preload("res://scripts/ui/reality_surface_texts.gd")
const CHARTER := preload("res://scripts/ui/stay_charter_texts.gd")
const STORY := preload("res://scripts/ui/stay_story_texts.gd")
const LABELS := {
	"title": ["감상 기록", "Viewing records"],
	"empty": ["보존된 엔딩 감상 기록이 없습니다. 미감상 장면은 표시하지 않습니다.", "No preserved ending records are available. Unseen scenes are not displayed."],
	"description": ["보존된 마지막 장면과 확인한 조사만 열람합니다. 전체 엔딩·ALL 전용 장면 재생은 아직 준비 중입니다.\n본편 상태와 저장 파일은 바뀌지 않습니다.", "Read only preserved final scenes and observations you have seen. Full ending and ALL-scene playback is still in preparation.\nYour game state and save files remain unchanged."],
	"close": ["닫기", "Close"], "back": ["목록으로", "Back to list"],
	"previous": ["이전", "Previous"], "next": ["다음", "Next"],
	"previous_list": ["이전 목록", "Previous list"], "next_list": ["다음 목록", "Next list"],
	"previous_record": ["이전 기록", "Previous record"], "next_record": ["다음 기록", "Next record"],
	"record": ["%s · 기록 %d", "%s · Record %d"],
	"reality": ["현실 기상", "Waking into reality"], "stay": ["안정화 잔류", "Remaining in the stabilized mansion"],
	"identity": ["전원 인증 · %s", "All-personality verification · %s"],
	"authority_title": ["전원 인증 · 권한 확인", "All-personality verification · Authority"],
	"authority": ["주인공의 SUBJECT 권한이 관리자의 CUSTODIAN 권한보다 우선합니다. 이 서명은 허가 요청이 아닙니다. 이미 내리신 선택을 기록합니다.", "Your SUBJECT authority takes precedence over the administrator's CUSTODIAN authority. This signature is not a request for permission. It records the choice you have already made."],
	"entry": ["엔딩 도입 · %s", "Ending introduction · %s"],
	"farewell": ["작별 · %s", "Farewell · %s"], "body": ["신체 확인 · %s", "Body check · %s"],
	"notebook": ["현장 수첩 · %s", "Field notebook · %s"], "exit": ["출입 점검 · %s", "Exit check · %s"],
	"reality_final": ["현실 기상 · 마지막 시선", "Waking into reality · Final view"],
	"memory": ["잔류 합의 · 기억 원칙", "Stay charter · Memory principles"],
	"appearance": ["잔류 합의 · 외형 표시", "Stay charter · Appearance display"],
	"autonomy": ["잔류 합의 · 자율성", "Stay charter · Autonomy"],
	"proposed": ["%s의 역할을 강제가 아닌 제안으로 전환했다.", "%s's role was changed from an assignment to a proposal."],
	"written": ["주인공 수첩", "Protagonist's notebook"],
	"stay_final": ["안정화 잔류 · 마지막 자리", "Remaining in the stabilized mansion · Final seating"],
}
const IDENTITIES := [
	"I am Edgar. Vertical locking lines, a low clock tone. I confirm that I am the subject of the administrative records.",
	"It's Mara! Diagonal cleaning marks, a dry brush sound. Those maintenance records are mine, all right! Got the nameplate right this time?",
	"I'm... Luca. A double pulse and a vital-sign tone... I'm the personality responsible for the life-support records... I'm here.",
	"I am Iris. Petals and a halo, the sounds of glass and wind. The environmental records are mine. Heehee... the name remains.",
	"Mara 2! Stacked frames, double outlines, three quick notes! Archive original personality verified! All five records' distributed backup checksums match! Don't leave my name out!",
]
const ENTRIES := {
	"EDR_ENTRY": "The waking procedure is confirmed.\nThe core does not ask you to choose again. Beneath your palm, the last stroke is still pressed into the paper.",
	"EDR_ARCHIVE_STATUS": "RESIDENT personality archive: switching to low-power preservation\nPersonality composition: biological neural core + personality process\nFive channels preserved · No immediate deletion\nConservative estimate without maintenance: 18 months\nEstimate with regular maintenance: 12–20 years / Not a guarantee\nPhysical transfer: currently unavailable\nEveryday conversation cannot continue in low-power mode. Short maintenance outputs are not a substitute for conversation.",
	"EDS_ENTRY": "Restoration of the stabilization loop is confirmed.\nThe facility frame remains beneath the mansion's outline. Neither is treated as though it never existed.",
	"EDS_STABILIZE": "World state: S5 STABILIZED FRACTURE\nMemory of the truth: retained\nYour waking authority: retained\nEnforced servant roles: relaxed\nExternal sensor connection: retained, read-only\nFive personalities: active consciousness retained\nNext sleep: requires your confirmation\nThis does not return to a normal reset. No subsequent sleep is carried out now.",
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func identity(index: int, locale: String) -> String:
	return IDENTITIES[index] if locale.begins_with("en") else ENTRY.IDENTITIES[index]["text"]

static func entry(id: String, locale: String) -> String:
	return ENTRIES[id] if locale.begins_with("en") else ENTRY.TEXT[id]
