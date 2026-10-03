extends RefCounted

# Surface names only; availability is always decided by the frozen public query.
const LOCATIONS := {
	"M2_BEDROOM": ["주인공의 침실", "Protagonist's bedroom"],
	"M2_UPPER_HALL": ["위층 복도", "Upper hall"],
	"M2_STAIR_LANDING": ["계단참", "Stair landing"],
	"M1_CENTRAL_HALL": ["중앙홀", "Central hall"],
	"M1_SERVANT_COMMON": ["사용인 공용실", "Servants' common room"],
	"M1_PARLOR": ["대응접실", "Parlor"],
	"M1_LIBRARY_OUTER": ["외부 서고", "Outer library"],
	"M1_LIBRARY_INNER": ["기록 내실", "Inner archive"],
	"M1_GREAT_CLOCK": ["서쪽 대시계", "West great clock"],
	"M1_NORTH_ARCHIVE_HALL": ["북쪽 기록 회랑", "North archive hall"],
	"M1_PORTRAIT_STORAGE": ["초상화 보관실", "Portrait storage"],
	"M1_KITCHEN": ["주방", "Kitchen"],
	"M1_GREENHOUSE_VESTIBULE": ["온실 앞", "Greenhouse entrance"],
	"M1_GREENHOUSE": ["온실", "Greenhouse"],
	"M1_MIRROR_GALLERY": ["거울 회랑", "Mirror gallery"],
	"M1_TOOL_ROOM": ["청소도구실", "Cleaning tool room"],
	"M1_COLOR_ROOM_ENTRY": ["색분해실 외부", "Color-separation room entrance"],
	"M1_BASEMENT_ENTRY": ["서쪽 지하 계단문", "West basement stair door"],
	"B1_BASEMENT_STAIR": ["지하 계단", "Basement stairs"],
	"B1_AXIS_CHAMBER": ["세 축 장치실", "Three-axis mechanism room"],
	"B1_STORAGE": ["지하창고", "Basement storage"],
	"B1_CLOCKWORK_HEART": ["태엽 심장실", "Clockwork heart room"],
	"H0_SERVICE_SPINE": ["드러난 서비스 통로", "Exposed service passage"],
	"H0_CLIMATE_CONTROL": ["계절 제어실", "Climate control room"],
	"H0_LIFE_SUPPORT": ["생명 유지실", "Life-support room"],
	"H0_CLOCK_MACHINE": ["보안 기계실", "Security machine room"],
	"H0_COLOR_SEPARATION": ["색분해실", "Color-separation room"],
	"H0_PERSONALITY_ARCHIVE": ["인격 아카이브", "Personality archive"],
	"H0_CORE_PATH": ["코어로 가는 길", "Path to the core"],
	"H0_CORE": ["코어실", "Core room"],
	"R0_CRYO_CHAMBER": ["현실의 냉각실", "Cryo chamber outside the simulation"],
	"R0_FACILITY_EXIT": ["시설 출구", "Facility exit"],
	"R0_SURFACE_THRESHOLD": ["지표 경계", "Surface threshold"],
}
const PEOPLE := {"EDGAR": ["에드가", "Edgar"], "MARA1": ["마라 1", "Mara 1"], "MARA2": ["마라 2", "Mara 2"], "LUCA": ["루카", "Luca"], "IRIS": ["이리스", "Iris"]}
const PERSON_RECORDS := {"REC_EDGAR": "EDGAR", "REC_MARA1": "MARA1", "REC_MARA2": "MARA2", "REC_LUCA": "LUCA", "REC_IRIS": "IRIS", "MARA2_NAME": "MARA2"}
const FIELDS := {"chapters": ["장", "Chapter"], "locations": ["장소", "Location"], "speakers": ["화자", "Speaker"], "people": ["관련 인물", "Related person"], "sources": ["자료 출처", "Material source"], "categories": ["분류", "Category"], "epistemic": ["내용 확인 상태", "Content status"], "provenance": ["출처 확인 상태", "Source status"]}
const VALUES := {
	"chapters": {"PROLOGUE": ["프롤로그", "Prologue"], "CHAPTER_1": ["1장", "Chapter 1"], "CHAPTER_2": ["2장", "Chapter 2"], "CHAPTER_3": ["3장", "Chapter 3"], "CHAPTER_4": ["4장", "Chapter 4"], "LEGACY": ["이전·미분류", "Earlier / unclassified"]},
	"sources": {"spoken": ["발언·질문·선택", "Speech, questions and choices"], "document": ["읽은 문서", "Read document"], "journal": ["복원한 일지", "Restored journal"], "hint": ["공개된 도움 기록", "Revealed hint"], "note": ["수첩에 작성한 내용", "Written notebook entry"], "legacy": ["이전·미분류 원문", "Earlier / unclassified original"]},
	"categories": {"observation": ["관찰", "Observation"], "hypothesis": ["가설", "Hypothesis"], "failure": ["실패 관찰", "Failure observation"], "document": ["문서", "Document"], "journal": ["일지", "Journal"], "person": ["인물 기록", "Person record"]},
	"epistemic": {"observed": ["관찰", "Observed"], "hypothesis": ["가설", "Hypothesis"], "verified": ["검증됨", "Verified"], "refuted": ["반박됨", "Refuted"]},
	"provenance": {"unverified": ["미확인", "Unverified"], "identified": ["식별됨", "Identified"], "authenticated": ["인증됨", "Authenticated"]},
}


static func person(id: String) -> String:
	if id == "MARA": return "MARA1"
	return id if PEOPLE.has(id) else ""


static func location(id: String, locale: String) -> String:
	return pair(LOCATIONS.get(id, ["장소 미확인", "Location unconfirmed"]), locale)


static func value(field: String, id: String, locale: String) -> String:
	if field == "locations": return location(id, locale)
	if field in ["speakers", "people"]: return pair(PEOPLE.get(person(id), ["이름 미확인 기록", "Unidentified person records"]), locale)
	return pair(VALUES.get(field, {}).get(id, ["분류 미확인", "Classification unconfirmed"]), locale)


static func pair(labels: Array, locale: String) -> String:
	return labels[1 if locale.begins_with("en") else 0]
