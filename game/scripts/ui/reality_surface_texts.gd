extends RefCounted

const RULES := preload("res://scripts/systems/reality_surface.gd")
const LABELS := {
	"R0_CRYO_CHAMBER": ["현실 · 냉각실", "Reality · Cryo chamber"],
	"R0_FACILITY_EXIT": ["현실 · 시설 출구", "Reality · Facility exit"],
	"R0_SURFACE_THRESHOLD": ["현실 · 지표 경계", "Reality · Surface threshold"],
	"objective": ["현실 · 선택 조사", "Reality · Optional investigation"],
	"final_objective": ["ED_A 현실 기상 · FINAL DECISION: REALITY", "ED_A Waking into reality · FINAL DECISION: REALITY"],
	"final_frame": ["한 손에 현실 수첩을 들고, 다른 손으로 시설 문틀을 잡는다.\n%s\n이 시선이 앞으로 갈 방향을 확정하지는 않는다.", "You hold the physical notebook in one hand and the facility doorframe with the other.\n%s\nWhere you look does not decide where you will go next."],
	"airlock_board": ["외기는 호흡 가능 범위로 표시되지만 장기 노출은 미검증이다.\n지표 경계로 나가도 다른 생존자가 있는지는 알 수 없다.", "The outside air is marked as breathable, but long-term exposure is unverified.\nStepping onto the surface will not tell you whether other survivors exist."],
	"cancel": ["시설을 조금 더 조사한다", "Explore the facility a little longer"],
	"enter": ["지표 경계로 나간다", "Step onto the surface threshold"],
	"checked": [" · 확인함", " · Checked"],
	"move_cryo": ["냉각실로", "Go to the cryo chamber"],
	"move_exit": ["시설 출구로", "Go to the facility exit"],
	"airlock": ["조사를 마치고 에어록으로", "Finish investigating and approach the airlock"],
	"outside": ["밖을 본다", "Look outside"],
}
const VIEWS := {
	"left": [["문틀 쪽", "Toward the doorframe"], ["문틀의 거친 면에 바람의 압력이 실린다.", "The wind presses against the rough surface of the doorframe."]],
	"center": [["지표 쪽", "Toward the ground"], ["회갈색 지표 위로 젖은 흑연선이 선명하다.", "Against the gray-brown ground, the wet graphite lines stand out clearly."]],
	"right": [["먼 빛 쪽", "Toward the distant light"], ["먼 빛이 보인다. 무엇인지 알 수 없다. 확대하지 않는다.", "A distant light is visible. You cannot tell what it is. The view does not zoom in."]],
}
const OBJECTS := {
	"glass": ["Capsule glass", "Handprints on the inside overlap maintenance marks on the outside. They were left at different times. You cannot tell which hand was there last."],
	"stand": ["Empty preservation stand", "It might have been someone else's place, or a spare stand. Its being empty proves neither possibility."],
	"tools": ["Toolbox", "The size numbers match those in Mara 1's notebook. Some compartments are empty. Only the outlines of tools remain in the dust."],
	"plant": ["Transparent planter", "A dried stem and growth records remain. They differ from the garden in Iris's seasonal model. Actual growth did not follow the records' predictions."],
	"names": ["Names on the wall", "The five researchers' names stand alongside some you cannot read. Unreadable names do not establish that someone is still alive."],
	"signal": ["Distant blinking light", "The light cuts out once, then returns. It could be a person, an automated device, or a sensor error. The view does not zoom in automatically."],
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func object_text(id: String, index: int, locale: String) -> String:
	return OBJECTS[id][index] if locale.begins_with("en") else RULES.OBJECTS[id][index+1]

static func view_text(direction: String, index: int, locale: String) -> String:
	return VIEWS[direction][index][1 if locale.begins_with("en") else 0]

static func final_frame(direction: String, locale: String) -> String:
	return text("final_frame", locale) % view_text(direction, 1, locale)
