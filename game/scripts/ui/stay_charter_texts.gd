extends RefCounted

const RULES := preload("res://scripts/systems/stay_charter.gd")
const PRINCIPLES := [
	"You remember that the mansion is a simulation. Choosing familiarity does not erase the truth you have verified.",
	"The servants do not erase their researcher personalities or responsibility for the confinement. Living under the same names does not make that responsibility disappear.",
	"No subsequent sleep, waking, or memory change is carried out without your explicit confirmation. This scene does not actually begin the next sleep.",
]
const OWNERS := {"edgar": "Edgar", "mara1": "Mara 1", "luca": "Luca", "iris": "Iris", "mara2": "Mara 2"}
const MODES := {"layered": "Show both the Gothic exterior and facility structure", "contextual": "Show the exterior normally; reveal the structure when inspecting"}
const LABELS := {
	"display_status": ["표시만 변경 · %s", "Display only · %s"],
	"mode_layered": ["외피와 시설 골격 함께 표시", "Exterior and facility structure together"],
	"mode_contextual": ["조사할 때 시설 골격 표시", "Facility structure shown when inspecting"],
	"location": ["저택 코어 · S5 안정화", "Mansion core · S5 stabilization"],
	"EDS_MEMORY_CHARTER": ["기억 원칙", "Memory principles"],
	"EDS_APPEARANCE_CONTROL": ["외형 표시 방식", "Appearance display mode"],
	"EDS_AUTONOMY_CHARTER": ["사용인 자율성", "Servant autonomy"],
	"structure": ["시설 골격 · 배선 / 문양·출처: 에드가 · 마라 1 · 루카 · 이리스 · 마라 2", "Facility structure · Wiring / glyph sources: Edgar · Mara 1 · Luca · Iris · Mara 2"],
	"changeable": [" · 언제든 바꿀 수 있다", " · Can be changed at any time"],
	"inspect": ["시설 골격 조사 표시 전환", "Toggle the facility inspection view"],
	"settings": ["외형 표시 다시 선택", "Choose the appearance display again"],
	"principle": ["기억 원칙 %d%s", "Memory principle %d%s"],
	"checked": [" · 확인함", " · Reviewed"],
	"memory_finish": ["세 원칙을 유지한다", "Retain all three principles"],
	"neutral": ["표시만 바뀐다 · 기억과 결정을 바꾸지 않는다", "Only the display changes · Memories and decisions stay intact"],
	"neutral_detail": ["어느 표시든 S5의 진실과 현재 기억은 유지된다.", "Both displays retain the truth of S5 and your current memories."],
	"appearance_finish": ["이 표시로 계속한다", "Continue with this display"],
	"autonomy": ["주 공간·휴식 시간은 각자 선택한다. 경고는 제공하되 이동을 자동 봉쇄하지 않는다.\n에드가는 일정표를 제안만 한다. 누구도 다른 인격의 기억·이름을 단독 삭제하지 못한다.", "Each person chooses their own space and rest periods. Warnings are provided without automatically blocking movement.\nEdgar may only propose a schedule. No one may unilaterally erase another personality's memories or name."],
	"proposed": [" · 제안", " · Proposed"],
	"fixed": [" · 고정 → 제안", " · Assigned → Proposed"],
	"autonomy_finish": ["다섯 사용인의 자율성을 확인한다", "Affirm the autonomy of all five servants"],
	"settings_title": ["외형 표시", "Appearance display"],
	"settings_body": ["표시는 가역적이며 기억·관계·엔딩을 바꾸지 않는다.", "The display is reversible. It does not change memories, relationships, or the ending."],
	"keep": ["현재 표시 유지", "Keep the current display"],
	"layered_button": ["외피와 시설 골격 동시 표시", "Show exterior and facility structure together"],
	"contextual_button": ["조사 시 시설 골격 표시", "Show the facility structure when inspecting"],
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func principle(index: int, locale: String) -> String:
	return (PRINCIPLES if locale.begins_with("en") else RULES.PRINCIPLES)[index]

static func owner(id: String, locale: String) -> String:
	return (OWNERS if locale.begins_with("en") else RULES.OWNERS)[id]

static func mode(id: String, locale: String) -> String:
	return (MODES if locale.begins_with("en") else RULES.MODES)[id]
