class_name FieldNotebook
extends RefCounted

const REQUIRED := ["FIELD_NOTEBOOK_COVER", "FIELD_NOTEBOOK_FIRST_72_HOURS"]
const NODES := ["EDR_FIELD_NOTEBOOK", "EDR_EXIT_PANEL"]
const PAGES := {
	"FIELD_NOTEBOOK_COVER":["표지 · 현장 인계 01", "기상자용 생존·시설 수첩. 방수 회색 표지와 교체 가능한 색인 탭. 시뮬레이션 수첩과는 별개의 물건이다.", "캡슐 아래 서랍에서 종이와 내습 필름을 묶은 수첩을 꺼낸다. 모서리가 손에 걸린다. 가상의 장정과 촉감만 희미하게 닮았다. 아버지가 이 표지의 스캔을 시뮬레이션 인터페이스 참고로 썼다는 제작 메모가 붙어 있다.\n다섯 연구원의 글씨가 서로 다른 굵기로 겹친다. 새로 출력된 얇은 필름은 뒤표지 포켓에 끼워져 있다. 수첩 전체가 현실로 옮겨 온 것은 아니다."],
	"FIELD_NOTEBOOK_FIRST_72_HOURS":["루카 · 첫 72시간", "호흡·수분·관절·음식·약품·위험 징후를 나눠 기록한다. 기상 성공이 회복 완료를 뜻하지는 않는다.", "호흡 표시기의 변화와 몸의 느낌을 따로 기록할 것. 갈증이 없다는 이유로 시설의 수분 회복 점검을 생략하지 말 것. 관절의 움직임과 통증을 같은 칸에 적지 말 것.\n식품과 약품은 이름보다 봉인·보관 상태·시설 진단을 먼저 확인한다. 훼손된 라벨이나 알 수 없는 약품을 추측으로 사용하지 않는다. 이 오래된 문서는 현재 몸의 상태를 대신 판정할 수 없다.\n여백: ‘글씨가 작으면... 다음 장에 다시 크게 적어 둘게요.’ 바로 다음 장에는 같은 제목이 두 배 크기로 쓰여 있다."],
	"FIELD_NOTEBOOK_PREFACE":["아버지 · 서문", "절차는 명령이 아니라 자료이며 마지막 판단은 읽는 사람에게 남는다.", "이 글을 읽고 있다면 내가 설명할 수 없는 시간이 지났을 것이다.\n여기의 절차는 명령이 아니다. 살아남기 위한 자료다.\n마지막 판단은 네가 한다.\n짧은 문장 아래 서명만 있다. 연구원들에게 한 일과 그 책임을 지우는 사과나 면죄 문구는 없다."],
	"FIELD_NOTEBOOK_MARA1":["마라 1 · 시설 살리기", "전력 우회·펌프·공구 규격과 임시 수리의 한계를 확인한다.", "장치 번호, 마지막 점검, 임시 수리 부위를 먼저 찾는다. 맞지 않는 공구로 억지로 돌린 흔적은 다음 점검자에게 표시한다. 전력 우회 도면에는 실제 배선과 대조하라는 큰 밑줄이 있다.\n한 규격 번호가 두 번 지워졌다. ‘이 숫자 아님다. 옆 장이 최신임다!’ 다음 장에는 ‘둘 다 챙겨 두십쇼’라는 정정이 있다. 손글씨를 따라가면 서류를 쓴 사람이 잠깐 가까워진다."],
	"FIELD_NOTEBOOK_IRIS":["이리스 · 외부 읽기", "공기·물·토양·빛·계절의 관측값과 모델을 구분한다.", "창밖이 밝다고 안전한 날은 아니다. 센서 위치와 관측 시각, 교정 이력을 함께 읽는다. 계절 모델의 색은 실제 공기와 물의 상태를 보증하지 않는다.\n투영된 정원 그림 옆에 실제 생장 실패 사진이 붙어 있다. 가장 예쁜 사진이 아니라 실패 사진의 날짜에 밑줄이 그어져 있다. ‘모델이 틀릴 때 사람을 고치지 말 것.’"],
	"FIELD_NOTEBOOK_EDGAR":["에드가 · 운영 우선순위", "생명 유지 → 통신 → 출입 → 보존. 빈 명령 칸은 기상자가 작성한다.", "우선순위는 위험 판단의 출발점이지 다른 장치를 방치하라는 명령이 아니다. 변경한 순서와 근거를 함께 기록한다. 생명 유지와 인격 보존은 공유 설비를 사용하므로 한쪽의 경고를 지우지 않는다.\n확인자 칸에는 에드가의 이름이 인쇄되어 있지 않다. 자를 댄 듯 반듯한 선 아래가 비어 있다. ‘최종 지시자를 대리 서명하지 마십시오.’"],
	"FIELD_NOTEBOOK_MARA2":["마라 2 · 사람과 기록", "다섯 인격의 색인과 체크섬. 기록의 무결성과 한 사람의 의식을 혼동하지 않는다.", "에드가, 마라 1, 루카, 이리스, 마라 2. 임시 명칭과 연구원 출처 인덱스가 함께 적혀 있다. 색인은 위치를 찾는 주소이며 체크섬은 손상 확인 수단이다. 그것만으로 독립된 의식을 복제하거나 새 신체를 만들 수는 없다.\n여백: ‘이 페이지 담당자가 제일 똑똑함!’ 아래에 다른 필체로 물음표가 다섯 개 있다. 작은 글씨가 다시 덧붙었다. ‘이름은 지우지 마.’"],
	"SUBJECT_HANDOFF_PAGE":["뒤표지 · SUBJECT 인계 출력물", "FINAL DECISION: REALITY. 연결 해제 직전의 저속 프린터 출력물이다.", "현재 몸의 생존 신호와 다섯 인격 보존은 확인되었다. 외부 장기 생존, 시설의 영속, 미래 신체 이전은 보장되지 않는다.\n기상 시각: 시설 시계 동기화 미검증. 캡슐: 수동 해제 가능. 원문 전체가 아니라 완료된 연구원 기록의 출처만 인계한다.\n확인 문장의 필압을 따라간 얇은 선이 필름에 남아 있다. 시뮬레이션 수첩 원본이 이 종이가 된 것은 아니다."],
	"FIELD_NOTEBOOK_BACK":["공동 · 뒤표지", "모르면 기록하고, 혼자 결정했다고 숨기지 말 것.", "다섯 사람의 수정 기호가 한 문장 주변에 남아 있다. 정답을 아는 사람 한 명이 아니라, 서로 다른 판단을 남길 자리가 필요했다.\n‘모르면 기록하고, 혼자 결정했다고 숨기지 말 것.’ 주인공이 새로 쓸 첫 칸은 비어 있다."]
}
const EXIT := {
	"EXIT_STATUS_POWER":["시설 전력", "제한 전력. 생명 유지와 인격 보존은 공유 설비를 사용한다. 통신 수신 신호는 없다."],
	"EXIT_STATUS_AIR":["외기", "호흡 가능 범위로 표시된다. 장기 노출은 미검증이며 센서값이 외부 생존을 보증하지 않는다."],
	"EXIT_STATUS_MANUAL_RELEASE":["수동 해제", "문 개방은 수동으로 가능하다. 해제 손잡이에 마지막 점검자의 표시가 남아 있다."]
}
const OWNERS := {"FIELD_NOTEBOOK_FIRST_72_HOURS":"luca", "FIELD_NOTEBOOK_MARA1":"mara1", "FIELD_NOTEBOOK_IRIS":"iris", "FIELD_NOTEBOOK_EDGAR":"edgar", "FIELD_NOTEBOOK_MARA2":"mara2"}
const WAKE := preload("res://scripts/systems/reality_wake.gd")

static func page_text(state: Dictionary, page: String, expanded: bool) -> String:
	var text: String = PAGES[page][2 if expanded else 1]
	if expanded and page in OWNERS:
		var owner: String = OWNERS[page]
		var event: Dictionary = state["meta_progress"]["event_history"].get(WAKE.EVENTS[owner], {})
		var outcome: String = event.get("outcome_id", "")
		if state["meta_progress"]["servants"][owner]["core_event_complete"] and not WAKE.farewell(state,owner)["warning"]: text += "\n인계 부기: " + WAKE.OVERLAYS[owner][outcome]
	if expanded and page == "SUBJECT_HANDOFF_PAGE":
		var records: Array = []
		for owner in WAKE.OWNERS:
			if state["meta_progress"]["servants"][owner]["researcher_record_acquired"]: records.append("REC_" + owner.to_upper())
		text += "\n인계 출처: " + (", ".join(records) if not records.is_empty() else "별도 연구원 원문 인계 없음. 기본 운용 자료는 유지.")
	return text

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var node: String = run.get("current_node_id", "")
	var rereading: bool = action == "read" and "EDR_FIELD_NOTEBOOK" in run.get("completed_nodes",[])
	if not run.get("branch_committed",false) or run.get("branch_id") != "reality" or (node not in NODES and not rereading): return {"ok":false,"text":"현실 수첩과 출구 점검 단계에서 확인한다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var seen: Array = ending.get("required_interactions_seen", []).duplicate()
	var local: Dictionary = state["loop_state"]["event_local_states"].get("FIELD_NOTEBOOK", {"pages":[]}).duplicate(true)
	var next := node
	match action:
		"read":
			var page: String = str(value.get("page", "")) if value is Dictionary else str(value)
			var expanded := false
			if value is Dictionary:
				if not value.get("expanded") is bool: return {"ok":false,"text":"수첩의 펼침 상태를 확인한다."}
				expanded = value["expanded"]
			if page not in PAGES: return {"ok":false,"text":"수첩의 색인 탭을 고른다."}
			if page not in local["pages"]: local["pages"].append(page)
			if page in REQUIRED and page not in seen: seen.append(page)
			if expanded:
				var expanded_pages: Array = local.get("expanded_pages", []).duplicate()
				if page not in expanded_pages: expanded_pages.append(page)
				expanded_pages.sort()
				local["expanded_pages"] = expanded_pages
		"finish":
			if node != "EDR_FIELD_NOTEBOOK" or not seen.has(REQUIRED[0]) or not seen.has(REQUIRED[1]): return {"ok":false,"text":"표지와 첫 72시간을 먼저 확인한다."}
			next = "EDR_EXIT_PANEL"
			state["loop_state"]["location_id"] = "R0_FACILITY_EXIT"
		"inspect":
			if node != "EDR_EXIT_PANEL" or str(value) not in EXIT: return {"ok":false,"text":"출입 패널의 상태를 확인한다."}
			if value not in seen: seen.append(value)
		"unlock":
			if node != "EDR_EXIT_PANEL": return {"ok":false,"text":"출입 패널에서 해제한다."}
			for id in EXIT:
				if id not in seen: return {"ok":false,"text":"전력·외기·수동 해제를 모두 확인한다."}
			next = "EDR_FACILITY_FREE_LOOK"
		_: return {"ok":false,"text":"정의되지 않은 현장 수첩 행동이다."}
	seen.sort()
	local["pages"].sort()
	ending["required_interactions_seen"] = seen
	state["loop_state"]["event_local_states"]["FIELD_NOTEBOOK"] = local
	if next != node:
		if node not in ending["completed_nodes"]: ending["completed_nodes"].append(node)
		ending["completed_nodes"].sort()
		ending["current_node_id"] = next
	return {"ok":true,"state":state,"text":""}
