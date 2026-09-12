class_name BasementSession
extends BlackMirrorSession

const BASEMENT := preload("res://data/puzzles/puzzle_basement.tres")
const BASEMENT_KEY := "BASEMENT"
const MARA1_RELATIONSHIP := preload("res://scripts/systems/mara1_relationship.gd")
const IRIS_RELATIONSHIP := preload("res://scripts/systems/iris_relationship.gd")
const LUCA_RELATIONSHIP := preload("res://scripts/systems/luca_relationship.gd")
const EDGAR_RELATIONSHIP := preload("res://scripts/systems/edgar_relationship.gd")
const MARA2_RELATIONSHIP := preload("res://scripts/systems/mara2_relationship.gd")
const JOURNAL_FOUR := preload("res://scripts/systems/journal_four.gd")
const LAST_EVENING := preload("res://scripts/systems/last_evening.gd")
const CORE_APPROACH := preload("res://scripts/systems/core_approach.gd")
const CORE_ROOMS := preload("res://scripts/systems/core_room_network.gd")
const CORE_SAMPLES := preload("res://scripts/systems/core_samples.gd")
const CORE_OVERLAY := preload("res://scripts/systems/core_overlay.gd")
const CORE_ROLES := preload("res://scripts/systems/core_record_roles.gd")
const CORE_SELF := preload("res://scripts/systems/core_self_authority.gd")
const FATHER_RECORD := preload("res://scripts/systems/father_final_record.gd")
const CONFRONTATION := preload("res://scripts/systems/researcher_confrontation.gd")
const FINAL_INSPECTION := preload("res://scripts/systems/final_inspection.gd")
const ENDING_DECISION := preload("res://scripts/systems/ending_decision.gd")
const ENDING_ENTRY := preload("res://scripts/systems/ending_entry.gd")
const REALITY_WAKE := preload("res://scripts/systems/reality_wake.gd")
const FIELD_NOTEBOOK := preload("res://scripts/systems/field_notebook.gd")
const REALITY_SURFACE := preload("res://scripts/systems/reality_surface.gd")
const STAY_CHARTER := preload("res://scripts/systems/stay_charter.gd")
const STAY_STORY := preload("res://scripts/systems/stay_story.gd")
const ENDING_CREDITS := preload("res://scripts/systems/ending_credits.gd")
var ending_meta_store = preload("res://scripts/systems/ending_meta_store.gd").new()

func ensure_ending_meta() -> Dictionary:
	var meta: Dictionary = ending_meta_store.commit_completed(snapshot())
	if not meta.get("ok", false): return meta
	var archive = preload("res://scripts/systems/ending_gallery_store.gd").new(ending_meta_store.root_path.path_join("ending_gallery"))
	return archive.capture(snapshot())

const E2_ANSWERS := {
	"house": "위장 필터가 해제되었습니다. 수면으로 정상 리셋을 복구할 수는 없습니다. 눈앞의 장치가 사라진 저택을 대신하는 것이 아니라, 줄곧 그 아래에 있었습니다.",
	"body": "아가씨의 바깥 몸은... 냉각 장치에 있어요. 생존 신호는 유지되고 있어요. 하지만 깨어나도 안전한지는... 아직 보장할 수 없어요.",
	"memory": "저희의 생체 신경 코어와 인격 프로세스는 물리 리셋 대상이 아니었습니다. 귀하가 잊었다고 생각한 어제도 기억합니다. 오래 숨겼습니다.",
}
const E1_OBJECTS := {
	"bed": "매트리스의 푹신함 아래 둥근 캡슐 곡면이 만져진다. 손목의 고정구가 미세하게 떨린다. 귀를 대면 내 심장보다 느린 냉각 펌프음이 들린다. 같은 침대가 아니라, 같은 장치를 침대로 보았던 걸까.",
	"window": "겨울 아침인데 유리는 차갑지 않다. 체온보다 조금 낮을 뿐이다. 새 한 마리가 같은 궤도를 반복하다 중간에서 사라진다. [동일 궤도 반복 00:04] 바깥 풍경은 방 안에 그림자를 만들지 않는다.",
	"mirror": "내가 숨을 내쉰 뒤에 거울 속 가슴이 내려간다. 반 박자 늦다. 손끝을 대자 유리 대신 얇은 막이 밀린다. 검은 거울 아래에서 보았던 진단 패널과 같은 감촉이다.",
	"call_cord": "천 끈 안에서 광섬유 다발이 꺾인다. 종 대신 루카의 생체 신호음과 빠른 세 음이 겹친다. 아래층은 조용하다. 주방 방향에 연두 보조등이 켜지고 이중 맥박 문양이 떠오른다.",
}
const BASEMENT_LINKS := {"M1_BASEMENT_ENTRY": "M1_GREAT_CLOCK", "B1_BASEMENT_STAIR": "M1_BASEMENT_ENTRY", "B1_AXIS_CHAMBER": "B1_BASEMENT_STAIR", "B1_STORAGE": "B1_AXIS_CHAMBER", "B1_CLOCKWORK_HEART": "B1_STORAGE"}


func basement_local(state: Dictionary = {}) -> Dictionary:
	var source := snapshot() if state.is_empty() else state
	var result := {"drawer_points": [], "floorplan_ready": false, "rotation": 0, "flipped": false, "anchor": "", "axes": BASEMENT.axis_default(), "storage_seen": [], "heart": BASEMENT.heart_default()}
	result.merge(source["loop_state"]["event_local_states"].get(BASEMENT_KEY, {}), true)
	return result


func initialize() -> Dictionary:
	if int(snapshot()["meta_progress"]["journal_stage"]) < 3: return _reject("일지 3단계를 먼저 복원한다.")
	var result := super.initialize()
	if not result.get("ok", false): return result
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if not knowledge.has("j3_restored_day"):
		knowledge["j3_restored_day"] = int(state["loop_state"]["day_index"])
	state["loop_state"]["event_local_states"][BASEMENT_KEY] = basement_local(state)
	if state["fracture_state"]["broken_reset_triggered"] and not knowledge.get("E1_wake_seen", false):
		knowledge["E1_wake_seen"] = true
		_note(knowledge, "NOTE_E1_WAKE", "같은 아침이어야 한다.")
		return _commit(state, "종도 새소리도 없다. 냉각 팬이 느려진다. 이불은 어제와 같은 무게인데, 그 아래 금속 고정구가 손목을 따라 떨린다. 커튼 사이 아침빛은 그림자를 만들지 않는다.\n수첩에 흑연 글씨가 남아 있다. '같은 아침이어야 한다.' 마지막 획이 떨린다.")
	return _commit(state, String(result.get("text", "")), String(result.get("speaker", "주인공")))


func stage() -> String:
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	var local := basement_local(state)
	if state["ending_run"].get("branch_committed", false):
		if state["ending_run"].get("credits_completed",false): return "POST_CREDITS"
		if state["ending_run"]["current_node_id"] in ["CREDITS_REALITY","CREDITS_STAY"]: return "ENDING_CREDITS"
		if state["ending_run"]["current_node_id"] in STAY_STORY.NODES: return "STAY_STORY"
		if state["ending_run"]["current_node_id"] in STAY_CHARTER.NODES: return "STAY_CHARTER"
		if state["ending_run"]["current_node_id"] in REALITY_SURFACE.NODES: return "REALITY_SURFACE"
		if state["ending_run"]["current_node_id"] in FIELD_NOTEBOOK.NODES: return "FIELD_NOTEBOOK"
		if state["ending_run"]["current_node_id"] in REALITY_WAKE.NODES: return "REALITY_WAKE"
		return "ENDING_SEQUENCE" if state["ending_run"]["current_node_id"] in ENDING_ENTRY.NODES else "ENDING_BODY_PENDING"
	if knowledge.get("j4_confirmed", false):
		if int(state["meta_progress"]["journal_stage"]) < 4: return "J4"
		if not state["meta_progress"]["servants"]["edgar"]["core_event_complete"] and not knowledge.get("edgar_minimum_access", false): return "E3_4M"
		if knowledge.get("f0_entered", false):
			if knowledge.get("F2_complete", false): return "EDC" if FINAL_INSPECTION.progress(state)["choice_open"] else "F3"
			if knowledge.get("J5_complete", false): return "F2"
			if knowledge.get("F0_E_complete", false): return "F1"
			if knowledge.get("f0_record_roles_solved", false): return "F0_E"
			if knowledge.get("f0_overlay_complete", false): return "F0_D"
			if knowledge.get("f0_system_samples_verified", false): return "F0_C"
			return "F0_B" if knowledge.get("f0_room_feedback_loop_solved", false) else "F0_A"
		return "E6" if knowledge.get("e5_locked_in", false) else "E5"
	if state["fracture_state"]["broken_reset_triggered"]:
		if state["loop_state"]["location_id"] in ["M1_NORTH_ARCHIVE_HALL", "M1_COLOR_ROOM_ENTRY", "H0_COLOR_SEPARATION", "H0_PERSONALITY_ARCHIVE"]: return "E3_5"
		if state["loop_state"]["location_id"] in ["M1_GREAT_CLOCK", "H0_CLOCK_MACHINE"]: return "E3_4"
		if knowledge.get("relationship_hub_open", false) and state["loop_state"]["location_id"] in ["M1_KITCHEN", "H0_LIFE_SUPPORT"]: return "E3_3"
		if state["loop_state"]["location_id"] in ["M1_GREENHOUSE", "H0_CLIMATE_CONTROL"]: return "E3_2"
		if state["loop_state"]["location_id"] in ["M1_SERVICE_HALL", "M1_WIRING_ROOM"]: return "E3_1"
		if state["loop_state"]["location_id"] == "M2_BEDROOM": return "E1_ENTRY"
		if knowledge.get("relationship_hub_open", false): return "E_HUB"
		if luca_s2_pending(): return "LUCA_S2" if state["loop_state"]["location_id"] == "M1_KITCHEN" else "LUCA_GUIDE"
		return "E2_INTRO"
	if knowledge.get("d5_complete", false): return "DEMO_END" if _save.get_build_flavor() == "demo" else "D6"
	if state["fracture_state"]["camouflage_filter"] == "disabled": return "D5"
	if int(state["loop_state"]["day_index"]) <= int(knowledge.get("j3_restored_day", state["loop_state"]["day_index"])): return "D_SLEEP"
	if local["axes"]["locked"]: return "DF"
	if local["axes"]["open"]: return "D4" if local["storage_seen"].size() >= 2 else "D2"
	if knowledge.get("basement_overlay_solved", false): return "D1"
	if local["floorplan_ready"]: return "D0_A"
	return "D0"


func available_rooms() -> Array:
	return super.available_rooms() + BASEMENT_LINKS.keys() + ["M1_SERVICE_HALL", "M1_WIRING_ROOM", "M1_GREENHOUSE", "M1_DINING_ROOM", "H0_CLIMATE_CONTROL", "H0_LIFE_SUPPORT", "H0_CLOCK_MACHINE", "H0_COLOR_SEPARATION", "H0_PERSONALITY_ARCHIVE", "H0_CORE_PATH", "H0_CORE_RECORDS", "H0_CORE_CHAMBER", "R0_CRYO_CHAMBER", "R0_FACILITY_EXIT", "R0_SURFACE_THRESHOLD"]


func _rooms_connected(from: String, to: String, knowledge: Dictionary) -> bool:
	if from == to: return true
	if from in BASEMENT_LINKS or to in BASEMENT_LINKS:
		return BASEMENT_LINKS.get(from, "") == to or BASEMENT_LINKS.get(to, "") == from
	return super._rooms_connected(from, to, knowledge)


func can_use_basement_shortcut(fast_path: bool = false) -> bool:
	var state := snapshot()
	var local := basement_local(state)
	if state["loop_state"]["location_id"] != "M2_BEDROOM" or local["axes"]["locked"] or local["axes"]["open"]:
		return false
	if state["fracture_state"]["camouflage_filter"] == "disabled" or state["fracture_state"]["broken_reset_triggered"] or stage() == "D_SLEEP":
		return false
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if fast_path:
		return knowledge.get("basement_access_fast_path", false)
	return knowledge.get("basement_overlay_solved", false) \
		and not knowledge.get("basement_access_fast_path", false) \
		and state["meta_progress"]["failure_knowledge"].get("D1", {}).get("status", "") == "active"


func act(action: String, value: Variant = null) -> Dictionary:
	if stage() == "D6":
		return _d6_action(action, str(value))
	if _save.get_build_flavor() == "demo":
		var demo_stage := stage()
		if demo_stage == "DEMO_END" or (demo_stage == "D5" and action != "d_fracture"):
			return _reject("데모 종료 연출 중에는 저택 행동을 진행하지 않는다.")
	if action.begins_with("credits_"):
		var result: Dictionary = ENDING_CREDITS.apply(snapshot(), action.trim_prefix("credits_"), value)
		if result.get("ok", false):
			var meta: Dictionary = ensure_ending_meta()
			if not meta.get("ok", false):
				return _reject("엔딩 감상 기록을 저장하지 못했습니다. 현재 진행은 유지됩니다. 저장 공간을 확인한 뒤 다시 시도해 주세요. (%s)" % meta.get("error", "unknown"))
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("story_"):
		var result: Dictionary = STAY_STORY.apply(snapshot(), action.trim_prefix("story_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("stay_"):
		var result: Dictionary = STAY_CHARTER.apply(snapshot(), action.trim_prefix("stay_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("surface_"):
		var result: Dictionary = REALITY_SURFACE.apply(snapshot(), action.trim_prefix("surface_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("field_"):
		var result: Dictionary = FIELD_NOTEBOOK.apply(snapshot(), action.trim_prefix("field_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("reality_"):
		var result: Dictionary = REALITY_WAKE.apply(snapshot(), action.trim_prefix("reality_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("ending_"):
		var result: Dictionary = ENDING_ENTRY.apply(snapshot(), action.trim_prefix("ending_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if snapshot()["ending_run"].get("branch_committed", false): return _reject("최종 결정은 저장되었다. 확정된 엔딩에서 이어진다.")
	if action == "edc_commit":
		var result: Dictionary = ENDING_DECISION.commit(snapshot(), str(value))
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result["text"])
	if action.begins_with("f3_"):
		var result: Dictionary = FINAL_INSPECTION.apply(snapshot(), action.trim_prefix("f3_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "장치를 확인한다."))
	if action.begins_with("f2_"):
		var result: Dictionary = CONFRONTATION.apply(snapshot(), action.trim_prefix("f2_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "대면 기록을 확인한다."))
	if action.begins_with("f1_"):
		var result: Dictionary = FATHER_RECORD.apply(snapshot(), action.trim_prefix("f1_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "원본 기록을 확인한다."))
	if action.begins_with("f0e_"):
		var result: Dictionary = CORE_SELF.apply(snapshot(), action.trim_prefix("f0e_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "작성자를 확인한다."))
	if action.begins_with("f0d_"):
		var result: Dictionary = CORE_ROLES.apply(snapshot(), action.trim_prefix("f0d_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록 역할을 확인한다."))
	if action == "f0c":
		if not known("f0_system_samples_verified") or known("f0_overlay_complete") or snapshot()["loop_state"]["location_id"] != "H0_CORE_PATH": return _reject("표본을 검증한 뒤 중첩 자료를 조사한다.")
		if not value is Dictionary: return _reject("자료 조작을 선택한다.")
		var state := snapshot()
		var local: Dictionary = state["loop_state"]["event_local_states"].get("F0_C", CORE_OVERLAY.initial())
		var result: Dictionary = CORE_OVERLAY.act(local, str(value.get("action", "")), str(value.get("layer", "")), value.get("value"))
		if not result.get("ok", false): return _reject(result.get("text", "자료를 확인한다."))
		state["loop_state"]["event_local_states"]["F0_C"] = result["state"]
		if result["state"]["complete"]:
			state["meta_progress"]["knowledge_entries"]["f0_overlay_complete"] = true
			state["meta_progress"]["event_history"]["F0_C"] = {"event_id": "F0_C", "lifecycle": "completed"}
		return _commit(state, result["text"])
	if action.begins_with("f0b_"):
		var result: Dictionary = CORE_SAMPLES.apply(snapshot(), action.trim_prefix("f0b_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "표본을 확인한다."))
	if action.begins_with("f0a_"):
		var result: Dictionary = CORE_ROOMS.apply(snapshot(), action.trim_prefix("f0a_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "회로를 확인한다."))
	if action.begins_with("e6_"):
		var result: Dictionary = CORE_APPROACH.apply(snapshot(), action.trim_prefix("e6_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "코어 경로를 확인한다."))
	if action.begins_with("e5_"):
		var result: Dictionary = LAST_EVENING.apply(snapshot(), action.trim_prefix("e5_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "저녁 자리를 확인한다."))
	if action.begins_with("j4_"):
		var result: Dictionary = JOURNAL_FOUR.apply(snapshot(), action.trim_prefix("j4_"), value)
		return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
	if known("j4_confirmed"): return _reject("사용인 조사 단계가 종료되었다. 기록 정리와 다음 저녁으로 이어진다.")
	if snapshot()["fracture_state"]["broken_reset_triggered"]:
		if action.begins_with("mara2_"):
			var result: Dictionary = MARA2_RELATIONSHIP.apply(snapshot(), action.trim_prefix("mara2_"), value)
			return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
		if action.begins_with("edgar_"):
			var result: Dictionary = EDGAR_RELATIONSHIP.apply(snapshot(), action.trim_prefix("edgar_"), value)
			return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
		if action.begins_with("luca_"):
			var result: Dictionary = LUCA_RELATIONSHIP.apply(snapshot(), action.trim_prefix("luca_"), value)
			return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
		if action.begins_with("iris_"):
			var result: Dictionary = IRIS_RELATIONSHIP.apply(snapshot(), action.trim_prefix("iris_"), value)
			return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
		if action.begins_with("mara1_"):
			var result: Dictionary = MARA1_RELATIONSHIP.apply(snapshot(), action.trim_prefix("mara1_"), value)
			return _commit(result["state"], result["text"]) if result.get("ok", false) else _reject(result.get("text", "기록을 확인한다."))
		if action == "e1_inspect": return _inspect_e1(String(value))
		if action.begins_with("e2_"): return _intro_action(action, "" if value == null else str(value))
		if action != "move": return _reject("어제의 일과와 장치 조작은 끝났다. 달라진 아침을 확인한다.")
		if not known("E1_complete"): return _reject("같은 아침이 아니다. 방 안의 서로 다른 세 곳을 확인한다.")
		var state := snapshot()
		var source := String(state["loop_state"]["location_id"])
		var target := String(value)
		var links := {"M2_BEDROOM": "M1_CENTRAL_HALL", "M1_KITCHEN": "M1_CENTRAL_HALL"}
		if known("relationship_hub_open"):
			links["M1_NORTH_ARCHIVE_HALL"] = "M1_CENTRAL_HALL"
			links["M1_COLOR_ROOM_ENTRY"] = "M1_NORTH_ARCHIVE_HALL"
			links["H0_COLOR_SEPARATION"] = "M1_COLOR_ROOM_ENTRY"
			links["H0_PERSONALITY_ARCHIVE"] = "H0_COLOR_SEPARATION"
			links["M1_GREAT_CLOCK"] = "M1_CENTRAL_HALL"
			links["H0_CLOCK_MACHINE"] = "M1_GREAT_CLOCK"
			links["H0_LIFE_SUPPORT"] = "M1_KITCHEN"
			links["M1_GREENHOUSE"] = "M1_CENTRAL_HALL"
			links["H0_CLIMATE_CONTROL"] = "M1_GREENHOUSE"
			links["M1_SERVICE_HALL"] = "M1_CENTRAL_HALL"
			links["M1_WIRING_ROOM"] = "M1_SERVICE_HALL"
		if target == "H0_PERSONALITY_ARCHIVE" and not MARA2_RELATIONSHIP.progress(state)["overlay"]: return _reject("세 초상화의 공통 결손을 먼저 확인한다.")
		if links.get(source, "") != target and links.get(target, "") != source: return _reject("모두 중앙홀에 모이고 있다.")
		state["loop_state"]["location_id"] = target
		return _commit(state, "이중 맥박 표식을 따라 사용인 통로를 지나 주방으로 간다." if target == "M1_KITCHEN" else "조용한 복도를 지나간다.")
	if action == "move":
		var target := String(value)
		var local := basement_local()
		if target in BASEMENT_LINKS and not known("basement_overlay_solved"): return _reject("기록 내실에서 평면도와 지하 좌표를 먼저 검증한다.")
		if target in ["B1_STORAGE", "B1_CLOCKWORK_HEART"] and not local["axes"]["open"]: return _reject("세 축 장치 뒤의 지하창고 문이 잠겨 있다.")
		if target == "B1_CLOCKWORK_HEART" and local["storage_seen"].size() < 2: return _reject("반복되는 선반 사이에서 같은 부품의 방향을 비교한다.")
	if not action.begins_with("d_"): return super.act(action, value)
	if stage() == "D_SLEEP": return _reject("복원한 세 번째 일지를 기억한 채 잠들고 다음 아침에 조사한다.")
	if stage() in ["DEMO_END", "E1_ENTRY"]: return _reject("이전 지하 장치 절차는 끝났다.")
	var state := snapshot()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var loop: Dictionary = state["loop_state"]
	var local := basement_local(state)
	loop["event_local_states"][BASEMENT_KEY] = local
	var room := String(loop["location_id"])
	var text := ""
	match action:
		"d_drawer_point":
			if room != "M1_LIBRARY_INNER" or String(value) not in ["bedroom", "greenhouse", "great_clock"]: return _reject("기록 내실 책상의 세 눌림점을 확인한다.")
			if not known("C5_MIRROR_TRACING"): return _reject("거울 회로 투명지를 먼저 수첩에 기록한다.")
			if value not in local["drawer_points"]: local["drawer_points"].append(value)
			if local["drawer_points"].size() == 3:
				local["floorplan_ready"] = true
				text = "이중 바닥에서 평면도를 꺼내 C5 투명지와 일지 좌표를 함께 펼쳤다. 자료는 모였지만 방향은 아직 검증하지 않았다."
		"d_rotate", "d_flip", "d_anchor", "d_overlay":
			if room != "M1_LIBRARY_INNER" or not local["floorplan_ready"]: return _reject("서재 작업대에 세 자료를 준비한다.")
			if action == "d_rotate": local["rotation"] = (int(local["rotation"]) + 90) % 360
			elif action == "d_flip": local["flipped"] = not local["flipped"]
			elif action == "d_anchor":
				if String(value) not in ["bedroom", "greenhouse", "great_clock"]: return _reject("세 기준점 중 하나를 고정한다.")
				local["anchor"] = String(value)
			else:
				var checked: Dictionary = BASEMENT.inspect_overlay(local["rotation"], local["flipped"], local["anchor"])
				text = checked["text"]
				if checked["ok"]:
					knowledge["basement_overlay_solved"] = true
					knowledge["basement_axis_depths"] = checked["depths"]
					_note(knowledge, "D0_A", text)
		"d_axis_depth", "d_axis_push", "d_axis_central":
			if room != "B1_AXIS_CHAMBER" or not known("basement_overlay_solved"): return _reject("지하의 세 축 장치에서 도면을 적용한다.")
			var confirmed := false
			var input: Variant = value
			if action != "d_axis_depth":
				if not value is Dictionary: return _reject("조작 대상과 비가역 확인이 필요하다.")
				input = value.get("value", "")
				confirmed = bool(value.get("confirmed", false))
			var verb: String = {"d_axis_depth": "depth", "d_axis_push": "push", "d_axis_central": "central"}[action]
			var result: Dictionary = BASEMENT.axis_action(local["axes"], verb, input, confirmed)
			if not result["ok"]: return _reject(result["text"])
			local["axes"] = result["state"]
			text = result["text"]
			if result["hard_failure"]:
				var old: Dictionary = meta["failure_knowledge"].get("D1", {})
				var record: Dictionary = local["axes"]["failure"].duplicate(true)
				record["status"] = "active"
				record["attempts"] = int(old.get("attempts", 0)) + 1
				meta["failure_knowledge"]["D1"] = record
				_note(knowledge, "DF", text + "\n당일 입력 잠김. 잠든 뒤 도면과 검증한 깊이는 남는다.")
			elif local["axes"]["open"]:
				knowledge["basement_access_fast_path"] = true
				if meta["failure_knowledge"].has("D1"): meta["failure_knowledge"]["D1"]["status"] = "resolved"
				_note(knowledge, "D2", "세 축과 중앙 반 바퀴로 지하창고 접근 경로를 검증했다.")
		"d_shortcut", "d_fastpath":
			if not can_use_basement_shortcut(action == "d_fastpath"): return _reject("수면 뒤 닫힌 지하창고를 다시 준비할 때 사용하는 동선이다. 이미 열린 문이나 파열 이후에는 이전 절차를 반복하지 않는다.")
			if room != "M2_BEDROOM" or local["axes"]["locked"]: return _reject("리셋 뒤 같은 침실에서 준비 동선을 시작한다.")
			if action == "d_shortcut" and not meta["failure_knowledge"].has("D1"): return _reject("실패 뒤 확인한 축 기록이 필요하다.")
			if action == "d_fastpath" and not known("basement_access_fast_path"): return _reject("지하창고를 한 번 직접 열어야 한다.")
			local["floorplan_ready"] = true
			var chapter_local := local_state(state)
			chapter_local["routine_done"] = true
			loop["event_local_states"][LOCAL_KEY] = chapter_local
			loop["time_block"] = "evening_free"
			loop["location_id"] = "B1_AXIS_CHAMBER"
			if action == "d_shortcut":
				local["axes"]["depths"].merge(meta["failure_knowledge"]["D1"].get("verified_depths", {}), true)
				text = "일과를 마치고 평면도를 다시 꺼냈다. 검증한 깊이만 미리 맞췄다. 축을 미는 것은 직접 결정한다."
			else:
				local["axes"]["open"] = true
				local["axes"]["pushed"] = BASEMENT.AXES.duplicate()
				local["axes"]["depths"] = BASEMENT.DEPTHS.duplicate()
				text = "기록한 순서로 물리 장치를 다시 작동했다. 지하창고 문이 열린다."
		"d_storage":
			if room != "B1_STORAGE" or String(value) not in ["barrel", "cable", "filter", "drawing"]: return _reject("지하창고의 선반을 조사한다.")
			if value not in local["storage_seen"]: local["storage_seen"].append(value)
			text = {"barrel": "빈 와인통 안쪽에 같은 나사 간격이 반복된다.", "cable": "케이블 릴의 선이 선반 뒤로 모인다. 먼지 아래 방향이 하나로 이어진다.", "filter": "장식 테두리와 닮은 부품. 안쪽에는 위장 필터라는 표식이 있다.", "drawing": "찢어진 낙서 조각의 중심과 선반의 빈자리가 겹친다."}[String(value)]
			if local["storage_seen"].size() >= 2: text += "\n반복 구조의 중심에 태엽 심장실 문이 드러난다."
		"d_heart":
			if room != "B1_CLOCKWORK_HEART" or not value is Dictionary: return _reject("태엽 심장실에서 조작한다.")
			var result: Dictionary = BASEMENT.heart_action(local["heart"], String(value.get("action", "")), value.get("value"), bool(value.get("confirmed", false)))
			if not result["ok"]: return _reject(result["text"])
			local["heart"] = result["state"]
			text = result["text"]
			if result["filter_off"]:
				state["fracture_state"]["camouflage_filter"] = "disabled"
				knowledge["d4_filter_release"] = true
				_note(knowledge, "D4", "XII 뒤 보조 입력을 실행했다. 위장 필터 해제. 정상 안정화만으로는 닿지 않는 공간이었다.")
		"d_fracture":
			if stage() != "D5": return _reject("위장 필터를 해제한 뒤 확인한다.")
			knowledge["d5_complete"] = true
			text = "시계는 잠깐 정상적으로 움직인다. 벽지의 무늬가 벗겨지며 배선과 진단 문자가 드러난다. 사용인의 윤곽에서 서로 다른 서명이 조금씩 어긋난다."
			_note(knowledge, "D5", text)
		_:
			return _reject("정의되지 않은 지하 조사다.")
	return _commit(state, text)


func luca_s2_pending() -> bool:
	return not known("LUCA_S2_complete") and not snapshot()["meta_progress"]["servants"]["luca"]["core_event_complete"]


func _intro_action(action: String, value: String) -> Dictionary:
	if not known("E1_complete"): return _reject("먼저 달라진 아침을 확인한다.")
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if action == "e2_luca":
		if stage() != "LUCA_S2": return _reject("루카와의 첫 만남은 이미 지나갔다.")
		if value == "ask": return _commit(state, "괜찮아요... 아직은요. 이 소리가 빨라지면, 제가 먼저 말할게요. 그건... 꼭 말할게요.", "루카")
		if value not in ["hold", "withdraw"]: return _reject("손을 잡거나 물러날 수 있다.")
		knowledge["LUCA_S2_complete"] = true
		knowledge["LUCA_S2_choice"] = value
		if value == "hold":
			var luca: Dictionary = state["meta_progress"]["servants"]["luca"]
			luca["bond"] = mini(5, int(luca["bond"]) + 1)
		state["meta_progress"]["event_history"]["LUCA_S2"] = {"lifecycle": "completed", "outcome_id": value, "relationship_delta_applied": true}
		state["loop_state"]["location_id"] = "M1_CENTRAL_HALL"
		return _commit(state, "따뜻한 쪽이 어느 쪽인지 헷갈렸어요... 같이 돌아가요." if value == "hold" else "괜찮아요... 천천히 오세요. 같이 돌아가요.", "루카")
	if stage() != "E2_INTRO": return _reject("중앙홀의 보고를 먼저 확인한다.")
	if action == "e2_report":
		knowledge["E2_report_seen"] = true
		return _commit(state, "보고드리겠습니다. 정상 리셋 복구가 불가능합니다.\n마라 1의 웃음이 두 번 재생되고 멎는다. 루카는 손목과 진단 신호를 번갈아 본다. 이리스의 미소 아래 플라스틱 날개가 닫힌다.\n마라 2가 겹친 이름표를 붙든다. '너무 오래 쓴 표지야! 이제 안쪽 기능실이 보이는 거지.'")
	if not knowledge.get("E2_report_seen", false): return _reject("에드가의 보고를 먼저 듣는다.")
	if action == "e2_question" and E2_ANSWERS.has(value):
		var asked: Array = knowledge.get("E2_questions_seen", []).duplicate()
		if value not in asked: asked.append(value)
		knowledge["E2_questions_seen"] = asked
		return _commit(state, E2_ANSWERS[value], "루카" if value == "body" else "에드가")
	if action == "e2_finish":
		knowledge["E2_INTRO_complete"] = true
		knowledge["relationship_hub_open"] = true
		knowledge["E_HUB_destinations"] = ["E3_1", "E3_2", "E3_3", "E3_4", "E3_5"]
		_note(knowledge, "NOTE_E2_REPORT", "위장 필터는 복구되지 않는다. 바깥 신체의 생존 신호는 유지되지만 기상 안전은 미확정이다. 사용인의 기억은 물리 리셋에서 제외되어 있었다.")
		_note(knowledge, "NOTE_ARCHIVE_INDEX", "ARCHIVE / MARA2" if knowledge.get("mara2_archive_index_known", false) else "ARCHIVE / 소유자 미확인 · 겹친 액자 · 이중 윤곽")
		return _commit(state, "위장 필터는 돌아오지 않습니다. 외부 신체의 생존 신호는 있으나 기상의 안전을 보장하지 못합니다. 저희 기억은 물리 리셋 대상이 아니었습니다.\n각 장치를 조사할지, 바로 기록 결산으로 갈지는 귀하가 결정합니다. 더는 그 선택을 잠그지 않겠습니다.", "에드가")
	return _reject("확인할 질문을 선택한다.")


func _inspect_e1(object_id: String) -> Dictionary:
	if not E1_OBJECTS.has(object_id) or snapshot()["loop_state"]["location_id"] != "M2_BEDROOM":
		return _reject("침실에서 확인할 수 있는 대상이 아니다.")
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	var seen: Array = knowledge.get("E1_objects_seen", []).duplicate()
	if object_id in seen:
		return _commit(state, "천은 부드럽다. 그 아래가 무엇인지는 이제 안다." if object_id == "bed" else String(E1_OBJECTS[object_id]))
	seen.append(object_id)
	knowledge["E1_objects_seen"] = seen
	var text := String(E1_OBJECTS[object_id])
	if seen.size() >= 3 and not knowledge.get("E1_complete", false):
		knowledge["E1_complete"] = true
		knowledge["KN_E1_RESET_DID_NOT_RESTORE"] = true
		_note(knowledge, "NOTE_E1_DIFFERENT_MORNING", "잠들었지만 세계는 복구되지 않았다.")
		text += "\n침실 문 걸쇠가 풀린다. 잠들었는데도, 돌아오지 않았다."
	if seen.size() == 4:
		knowledge["E1_all_objects_seen"] = true
		text += "\n달라진 것이 네 개가 아니었다. 달라지지 않은 척하는 방법이 네 군데에서 끝난 것이다."
	return _commit(state, text)


func _d6_action(action: String, value: String) -> Dictionary:
	var state := snapshot()
	var room := String(state["loop_state"]["location_id"])
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if action == "d6_move":
		if value not in ["H0_SERVICE_SPINE", "M2_BEDROOM"]:
			return _reject("표시된 휴식 경로를 따른다.")
		if value == "M2_BEDROOM" and room != "H0_SERVICE_SPINE":
			return _reject("드러난 서비스 통로를 지나 침실로 간다.")
		state["loop_state"]["location_id"] = value
		return _commit(state, "익숙한 복도의 외피 아래로 휴식 경로가 이어진다.")
	if action == "d6_inspect" and room == "H0_SERVICE_SPINE":
		var descriptions := {
			"wall": "벗겨진 벽지 뒤 금속 격자는 기억하는 방보다 좁다. 손끝에는 종이와 금속의 경계가 동시에 닿는다.",
			"sign": "서비스 척추 표지의 다섯 기능실 방향과 SUBJECT 방향이 갈라져 있다. 아직 기능실로 들어갈 수는 없다.",
			"trace": "몸은 없는데 문양만 일정한 간격으로 지나간다. 잠금선, 닦임 자국, 이중 맥박, 꽃잎, 겹친 액자. 알아보는 것은 색만이 아니다.",
			"capsule": "비상 캡슐 표면에 침실 침대와 같은 직물 무늬가 투사된다. 가까이서는 천의 결 아래 매끄러운 곡면이 느껴진다."
		}
		if not descriptions.has(value): return _reject("통로에서 조사할 대상을 확인한다.")
		var seen: Array = knowledge.get("D6_objects_seen", []).duplicate()
		if value not in seen: seen.append(value)
		knowledge["D6_objects_seen"] = seen
		_note(knowledge, "D6_" + value, descriptions[value])
		return _commit(state, descriptions[value])
	if action == "d6_rest":
		if not ((value == "bedroom" and room == "M2_BEDROOM") or (value == "capsule" and room == "H0_SERVICE_SPINE")):
			return _reject("현재 위치의 휴식 장치를 확인한다.")
		knowledge["D6_rest_route"] = value
		return _commit(state, "조금 눈을 감는다. 이번에는 무엇이 돌아올지 알 수 없다.")
	return _reject("이전 일과와 장치 조작은 끝났다. 드러난 통로와 휴식 경로를 확인한다.")


func sleep() -> Dictionary:
	if snapshot()["fracture_state"].get("final_sleep_lock", false): return _reject("최종 확인 중에는 세계 내 수면을 하지 않는다. 저장과 불러오기는 가능하다.")
	if stage() == "DEMO_END": return _reject("데모 공개 범위는 여기까지다. 본편에서 이어진다.")
	var capsule_ready: bool = stage() == "D6" and snapshot()["loop_state"]["location_id"] == "H0_SERVICE_SPINE" and snapshot()["meta_progress"]["knowledge_entries"].get("D6_rest_route", "") == "capsule"
	if snapshot()["loop_state"]["location_id"] != "M2_BEDROOM" and not capsule_ready: return _reject("휴식할 침실이나 확인한 비상 캡슐에서 잠든다.")
	var reset := ResetCoordinator.new(_game, _save)
	match reset.resolve_sleep_route():
		&"NORMAL_RESET": return super.sleep()
		&"BROKEN_RESET":
			if not known("d5_complete"): return _reject("파열된 공간을 먼저 확인한다.")
			var result := reset.request_broken_reset(slot_id)
			return initialize() if result.get("ok", false) else result
		&"RESUME_PENDING_RESET":
			var result := reset.resume_pending_reset(slot_id)
			return initialize() if result.get("ok", false) else result
		&"POST_BROKEN_REST":
			return _commit(snapshot(), "잠깐 쉬어도 균열과 수리한 곳은 돌아가지 않는다.")
	return _reject("현재 수면 경로를 확인할 수 없다.")


func _save_point(state: Dictionary) -> String:
	if state["ending_run"].get("credits_completed",false): return "SAVE_ENDING_COMPLETE"
	if state["ending_run"].get("branch_committed", false) and state["ending_run"].has("completed_nodes"): return "SAVE_ENDING_NODE"
	if state["ending_run"].get("branch_committed", false): return "SAVE_ENDING_BRANCH"
	if state["meta_progress"]["knowledge_entries"].get("F3_complete", false): return "SAVE_F3_COMPLETE"
	if state["meta_progress"]["knowledge_entries"].get("F2_complete", false): return "SAVE_F2_COMPLETE"
	if state["meta_progress"]["knowledge_entries"].get("f0_entered", false): return "SAVE_CAMPAIGN_PROGRESS"
	if state["meta_progress"]["knowledge_entries"].get("e5_locked_in", false): return "SAVE_E5_COMPLETE"
	if state["meta_progress"]["knowledge_entries"].get("J4_complete", false): return "SAVE_J4_COMPLETE"
	if state["fracture_state"]["broken_reset_triggered"]:
		return "SAVE_BROKEN_RESET_COMPLETE"
	if state["meta_progress"]["knowledge_entries"].get("d5_complete", false):
		return "SAVE_D5_COMPLETE" if _save.get_build_flavor() == "demo" else "SAVE_FRACTURE_CONFIRMED"
	if state["fracture_state"]["camouflage_filter"] == "disabled": return "SAVE_D4_COMPLETE"
	return super._save_point(state)


func _commit(state: Dictionary, text: String, speaker: String = "주인공") -> Dictionary:
	var local := basement_local(state)
	state["loop_state"]["event_local_states"][BASEMENT_KEY] = local
	var inventory: Array = state["loop_state"]["inventory"]
	inventory.erase("MANSION_FLOORPLAN")
	if local["floorplan_ready"]: inventory.append("MANSION_FLOORPLAN")
	var result: Dictionary = super._commit(state, text, speaker)
	if result.get("ok", false) and _save_point(state) == "SAVE_F3_COMPLETE":
		var copy: Dictionary = _save.capture_f3_reselect(slot_id)
		if not copy.get("ok", false):
			result["text"] = "현재 진행은 저장되었습니다. 다른 선택 확인용 사본은 저장하지 못했습니다."
	if result.get("ok", false) and state["ending_run"].get("current_node_id", "") in ["CREDITS_REALITY", "CREDITS_STAY"]:
		var meta := ensure_ending_meta()
		if not meta.get("ok", false):
			result["text"] = "마지막 장면은 저장되었습니다. 감상 기록 저장은 재시도가 필요합니다."
	return result
