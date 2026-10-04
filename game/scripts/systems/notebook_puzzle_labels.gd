extends RefCounted

# Only these live producers opt into the new wording; archived versions stay explicit.
const VERSION_TWO := [
	"NB_BASEMENT_FLOORPLAN",
	"NB_BASEMENT_NOTE_FLOORPLAN",
	"NB_CORE_A_NOTES",
	"NB_CORE_D_RECORD_COMMAND",
	"NB_CORE_SCREEN_C_GUIDE",
	"NB_CORE_SCREEN_C_LAYER_B4",
	"NB_CORE_SCREEN_C_LAYER_C5",
	"NB_CORE_SCREEN_C_LAYER_D4",
	"NB_CORE_SCREEN_D_CARD_NO",
	"NB_CORE_SCREEN_D_CARD_NO_ANON",
	"NB_CORE_SCREEN_D_CARD_YES",
	"NB_CORE_SCREEN_D_CARD_YES_ANON",
	"NB_CORE_SCREEN_D_SLOT_NO",
	"NB_CORE_SCREEN_D_SLOT_YES",
	"NB_CORE_SCREEN_E_MARK_HOUSE_GLYPH",
	"NB_CORE_SCREEN_E_MARK_HOUSE_GLYPH_EMPTY",
	"NB_CORE_SCREEN_E_MARK_INK_CORNER",
	"NB_CORE_SCREEN_E_MARK_INK_CORNER_EMPTY",
	"NB_CORE_SCREEN_E_MARK_SENTENCE",
	"NB_CORE_SCREEN_E_MARK_SENTENCE_EMPTY",
	"NB_FINAL_F1_INSPECT",
	"NB_HINT_D0_A_H1",
	"NB_HINT_C4_H1",
	"NB_HINT_F0_A_H1",
	"NB_HINT_F0_C_H1",
	"NB_HINT_F0_C_H2",
	"NB_HINT_F0_C_H3",
	"NB_HINT_F0_C_H4",
	"NB_HINT_F0_C_H5",
	"NB_HINT_F0_D_H3",
	"NB_HINT_F0_D_H5",
	"NB_HINT_F0_E_H2",
	"NB_PUZZLE_D_DRAWER_BOARD",
	"NB_PUZZLE_HEART",
	"NB_PUZZLE_FLOORPLAN"
]
const LAYERS := {
	"B4": ["종 파형", "Bell waveform"],
	"C5": ["거울 회로", "Mirror circuit"],
	"D4": ["태엽 심장 포트 잔상", "Heart-port afterimage"],
}
const STAGES := {
	"F0_A": ["네 방의 피드백 회로", "Four-room feedback circuit"],
	"F0_B": ["시스템 신호 표본", "System signal samples"],
	"F0_C": ["세 자료 중첩", "Three-record overlay"],
	"F0_D": ["기록 역할 분류", "Record roles"],
	"F0_E": ["과거 연속성과 현재 작성자", "Past continuity and present author"],
}


static func version(id: String) -> int:
	return 2 if id in VERSION_TWO else 1


static func layer_name(id: String, locale: String) -> String:
	return LAYERS[id][1 if locale.begins_with("en") else 0]


static func hint_title(stage: String, locale: String) -> String:
	var english := locale.begins_with("en")
	return ("Hints · " if english else "생각 정리 · ") + STAGES[stage][1 if english else 0]
