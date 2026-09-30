extends RefCounted

const RULES := preload("res://scripts/systems/field_notebook.gd")
const PAGES := {
	"FIELD_NOTEBOOK_COVER": ["Cover · Field Handoff 01", "A survival and facility notebook for the person waking up. A waterproof gray cover with replaceable index tabs. It is a separate object from the simulation notebook.", "You take a notebook bound from paper and moisture-resistant film from the drawer beneath the capsule. A corner catches against your hand. Only its binding and texture faintly resemble the virtual book. A production note says Father used a scan of this cover as a reference for the simulation interface.\nThe five researchers' handwriting overlaps in strokes of different thicknesses. Newly printed thin film sits in the back-cover pocket. The entire notebook has not crossed into reality."],
	"FIELD_NOTEBOOK_FIRST_72_HOURS": ["Luca · The first 72 hours", "Record breathing, hydration, joints, food, medicines, and warning signs separately. Waking successfully does not mean recovery is complete.", "Record changes in the breathing indicator separately from how your body feels. Do not skip the facility's hydration recovery checks just because you are not thirsty. Do not put joint movement and pain in the same box.\nFor food and medicines, check seals, storage conditions, and facility diagnostics before relying on names. Do not guess how to use unknown medicines or damaged labels. This old document cannot assess your body's present condition for you.\nIn the margin: 'If the writing is too small... I'll write it larger on the next page.' On the very next page, the same heading appears at twice the size."],
	"FIELD_NOTEBOOK_PREFACE": ["Father · Preface", "Procedures are information, not orders. Final judgment remains with the reader.", "If you are reading this, time has passed that I cannot explain.\nThe procedures here are not orders. They are information to help you survive.\nThe final judgment is yours.\nOnly a signature follows the short sentences. There is no apology or absolution that erases what he did to the researchers or his responsibility for it."],
	"FIELD_NOTEBOOK_MARA1": ["Mara 1 · Keeping the facility alive", "Check power bypasses, pumps, tool specifications, and the limits of temporary repairs.", "First locate the device number, last inspection, and temporary repairs. Mark any damage from forcing the wrong tool for the next inspector. The power bypass drawing has a thick underline: compare it with the actual wiring.\nOne specification number has been crossed out twice. 'Not this number! Next page is the latest!' On that page, a correction says, 'Keep both, would ya!' Following the handwriting brings the person who wrote it briefly closer."],
	"FIELD_NOTEBOOK_IRIS": ["Iris · Reading the outside", "Distinguish observations from models of air, water, soil, light, and seasons.", "A bright view outside does not make a day safe. Read the sensor location, observation time, and calibration history together. A seasonal model's colors do not guarantee the actual condition of the air and water.\nBeside a projected garden illustration is a photograph of failed growth. The underlined date belongs to the failure photograph, not the prettiest one. 'When the model is wrong, do not correct the person.'"],
	"FIELD_NOTEBOOK_EDGAR": ["Edgar · Operating priorities", "Life support → communications → access → preservation. The person waking up fills the empty instruction box.", "These priorities are a starting point for assessing risk, not orders to neglect other equipment. Record any change in order along with its reasons. Life support and personality preservation share equipment; do not erase warnings from either side.\nEdgar's name is not printed in the verifier box. Beneath a ruler-straight line, the space is empty. 'Do not sign on behalf of the final authority.'"],
	"FIELD_NOTEBOOK_MARA2": ["Mara 2 · People and records", "Indexes and checksums for the five personalities. Do not confuse record integrity with a person's consciousness.", "Edgar, Mara 1, Luca, Iris, Mara 2. Provisional names appear beside researcher-source indexes. An index is an address for locating a record; a checksum checks for damage. Neither alone can duplicate an independent consciousness or create a new body.\nIn the margin: 'This page's author is the smartest!' Below are five question marks in another hand. Small writing adds, 'Don't erase my name.'"],
	"SUBJECT_HANDOFF_PAGE": ["Back pocket · SUBJECT handoff printout", "FINAL DECISION: REALITY. A slow printer produced this just before disconnection.", "Your body's current signs of life and preservation of all five personalities have been verified. Long-term survival outside, the facility's permanence, and future transfer into new bodies are not guaranteed.\nWake time: facility clock synchronization unverified. Capsule: manual release available. Only the sources of completed researcher records are handed over, not their entire original texts.\nA thin line tracing the pressure of your confirmation remains on the film. The original simulation notebook did not become this paper."],
	"FIELD_NOTEBOOK_BACK": ["Shared · Back cover", "If you do not know, record it. Do not hide that you decided alone.", "Five people's correction marks remain around one sentence. They needed room for different judgments, not one person who knew the right answer.\n'If you do not know, record it. Do not hide that you decided alone.' The first box for your new writing is empty."],
}
const OVERLAYS := {
	"edgar": {"responsibility_recorded": "Edgar's audit signature remains in the shutdown log.", "authority_returned": "A SUBJECT signature remains beside the empty CUSTODIAN slot."},
	"mara1": {"original_attribution": "An audit copy retaining the responsible person's name is placed in preservation.", "protected_identifiers": "A copy with identifiers concealed is preserved together with the original hash."},
	"luca": {"full_disclosure": "The entire risk table is transferred to the physical notebook's handoff page.", "stabilize_first": "The same risk table is transferred in order after the stabilization completion time."},
	"iris": {"external_truth": "A note asks you to check the actual season first.", "shelter_projection": "Control of the switch that turns off the greenhouse projection passes to you."},
	"mara2": {"merged": "One voice closes the index. The final note trembles briefly.", "separated": "The original and the annotations speak in turn. 'Remember both.' The two indexes are preserved separately."},
}
const LABELS := {
	"location_exit": ["현실 · 시설 출구", "Reality · Facility exit"], "location_book": ["현실 · 냉각실", "Reality · Cooling chamber"],
	"objective_exit": ["출입 패널 점검", "Inspect the access panel"], "objective_book": ["현장 인계 01 · 물리 수첩", "Field Handoff 01 · Physical notebook"],
	"checked": [" · 확인함", " · Checked"], "read": [" · 읽음", " · Read"], "required": [" · 필수", " · Required"],
	"unlock": ["출구 잠금 해제", "Unlock the exit"], "finish": ["수첩을 들고 출입 패널로", "Take the notebook to the access panel"],
	"close": ["읽기 확인 후 닫기", "Confirm reading and close"], "summary": ["요약으로", "Show summary"], "expand": ["펼쳐 읽기", "Read in full"], "next": ["다음 색인: ", "Next index: "],
}
const EXIT := {
	"EXIT_STATUS_POWER": ["Facility power", "Limited power. Life support and personality preservation share equipment. No incoming communications signal."],
	"EXIT_STATUS_AIR": ["Outside air", "The display shows a breathable range. Long-term exposure is untested; sensor readings do not guarantee survival outside."],
	"EXIT_STATUS_MANUAL_RELEASE": ["Manual release", "The door can be opened manually. The last inspector's mark remains on the release handle."],
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func title(page: String, locale: String) -> String:
	return (PAGES if locale.begins_with("en") else RULES.PAGES)[page][0]

static func exit_text(id: String, index: int, locale: String) -> String:
	return (EXIT if locale.begins_with("en") else RULES.EXIT)[id][index]

static func page_text(state: Dictionary, page: String, expanded: bool, locale: String) -> String:
	if not locale.begins_with("en"):
		return RULES.page_text(state, page, expanded)
	var result: String = PAGES[page][2 if expanded else 1]
	if expanded and page in RULES.OWNERS:
		var owner: String = RULES.OWNERS[page]
		var event: Dictionary = state["meta_progress"]["event_history"].get(RULES.WAKE.EVENTS[owner], {})
		if state["meta_progress"]["servants"][owner]["core_event_complete"] and not RULES.WAKE.farewell(state, owner)["warning"]:
			result += "\nHandoff addendum: " + OVERLAYS[owner][event.get("outcome_id", "")]
	if expanded and page == "SUBJECT_HANDOFF_PAGE":
		var records: Array = []
		for owner in RULES.WAKE.OWNERS:
			if state["meta_progress"]["servants"][owner]["researcher_record_acquired"]:
				records.append("REC_" + owner.to_upper())
		result += "\nHandoff sources: " + (", ".join(records) if not records.is_empty() else "No separate original researcher records handed over. Basic operating information is retained.")
	return result
