class_name EndingCredits
extends RefCounted

const PAGES := [
	["개발용 크레딧", "GGB · 가칭\n기획·아트·사운드·개발의 최종 표기 명단은 확인 중입니다.\n현재 화면은 배포용 최종 제작진 명단이 아닙니다."],
	["제작 도구와 리소스", "게임 엔진: Godot\n개별 폰트·이미지·사운드의 배포용 저작권 및 라이선스 표기는 리소스 확정 뒤 정리합니다.\n확인되지 않은 제작자 이름이나 권리 표기를 임의로 넣지 않습니다."],
	["끝난 장면, 남은 기록", "선택한 엔딩은 유지됩니다. 크레딧 도중 종료하면 이 페이지부터 이어집니다.\n엔딩 감상 기록은 크레딧 완료와 별개로 프로필에 보관됩니다.\n크레딧 뒤 별도 사본에서 다른 선택을 확인할 수 있습니다. 갤러리는 후속 구현 중입니다."]
]

static func page(state: Dictionary) -> int:
	return int(state["loop_state"]["event_local_states"].get("ENDING_CREDITS",{}).get("page",0))

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var run: Dictionary = source["ending_run"]
	var branch: String = run.get("branch_id","")
	var expected := "CREDITS_REALITY" if branch == "reality" else "CREDITS_STAY"
	var final_frame := "EDR_FINAL_FRAME" if branch == "reality" else "EDS_FINAL_FRAME"
	if not run.get("branch_committed",false) or branch not in ["reality","stay"] or run.get("current_node_id") != expected or final_frame not in run.get("completed_nodes",[]): return {"ok":false,"text":"마지막 장면을 마친 뒤 크레딧을 확인한다."}
	var state := source.duplicate(true)
	var ending: Dictionary = state["ending_run"]
	var index := page(state)
	match action:
		"start":
			if ending.get("credits_started",false): return {"ok":false,"text":"크레딧은 현재 페이지에서 이어진다."}
			ending["credits_started"] = true
			ending["credits_completed"] = false
		"next":
			if not ending.get("credits_started",false) or value != index or index >= PAGES.size()-1: return {"ok":false,"text":"현재 크레딧 페이지를 확인한다."}
			index += 1
		"finish":
			if not ending.get("credits_started",false) or index != PAGES.size()-1: return {"ok":false,"text":"마지막 크레딧 페이지를 확인한다."}
			ending["credits_completed"] = true
			if expected not in ending["completed_nodes"]: ending["completed_nodes"].append(expected)
			ending["completed_nodes"].sort()
			ending["current_node_id"] = "ENDING_POST_CREDITS"
		_: return {"ok":false,"text":"정의되지 않은 크레딧 행동이다."}
	state["loop_state"]["event_local_states"]["ENDING_CREDITS"] = {"page":index}
	return {"ok":true,"state":state,"text":""}
