class_name BlackMirrorSession
extends ChapterOneSession

const MIRROR := preload("res://data/puzzles/puzzle_black_mirror.tres")
const MIRROR_KEY := "BLACK_MIRROR"
const EXTRA_ROOMS := ["M1_MIRROR_GALLERY", "M1_TOOL_ROOM", "M1_KITCHEN", "M1_COLOR_ROOM_ENTRY"]
const CHANNELS := {"EDGAR": "에드가 · 수직 잠금선 · 낮은 시계음", "MARA1": "마라 1 · 대각 닦임 · 마른 솔", "LUCA": "루카 · 이중 맥박 · 생체음", "IRIS": "이리스 · 꽃잎 · 유리와 바람", "MARA2": "마라 2 · 이중 액자 · 빠른 세 음"}
const J3_PARTS := [
	"거울은 네가 건넨 방향을 그대로 돌려주지 않는다.\n보이는 길을 집 위에 놓기 전에, 어느 쪽이 네 손에서 시작됐는지 먼저 되짚어라.",
	"집의 심장은 가장 낮은 곳에서 뛴다.\n하지만 아래로 내려가는 것만으로는 닿지 못한다.",
	"침실의 고요한 점, 온실의 계절이 멈추는 점,\n종이 없는데도 울리는 큰 시계를 한 장 위에 맞춰라.",
	"세 점이 모두 맞는 방향에서만\n입구는 집의 일부였다고 인정할 것이다.",
]

func mirror_local(state: Dictionary = {}) -> Dictionary:
	var source := snapshot() if state.is_empty() else state
	var local := {"materials_ready": false, "mixture": MIRROR.empty_mixture(), "cleaner_ready": false, "locked": false, "rotation": 0, "flipped": false, "anchored": false, "path": [], "dry_passed": false, "intervention_handled": false, "signal_ready": false, "surface_open": false, "channels_scanned": [], "j3_overlay_seen": false, "j3_order": []}
	local.merge(source["loop_state"]["event_local_states"].get(MIRROR_KEY, {}), true)
	return local


func initialize() -> Dictionary:
	if int(snapshot()["meta_progress"]["journal_stage"]) < 2:
		return _reject("일지 2단계를 먼저 복원한다.")
	var initialized := super.initialize()
	if not initialized.get("ok", false):
		return initialized
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	if not knowledge.has("j2_restored_day"):
		knowledge["j2_restored_day"] = int(state["loop_state"]["day_index"])
	state["loop_state"]["event_local_states"][MIRROR_KEY] = mirror_local(state)
	return _commit(state, String(initialized.get("text", "")), String(initialized.get("speaker", "주인공")))


func stage() -> String:
	var state := snapshot()
	var knowledge: Dictionary = state["meta_progress"]["knowledge_entries"]
	var local := mirror_local(state)
	if int(state["meta_progress"]["journal_stage"]) >= 3: return "J3_COMPLETE"
	if knowledge.get("c5_info_complete", false): return "J3"
	if local["surface_open"] or knowledge.get("mirror_tracing_acquired", false): return "C5_INFO"
	if local["locked"]: return "CF"
	if int(state["loop_state"]["day_index"]) <= int(knowledge.get("j2_restored_day", state["loop_state"]["day_index"])): return "C_SLEEP"
	if not knowledge.get("c0_mirror_seen", false): return "C0"
	if not knowledge.get("c1_cleaning_hypothesis", false): return "C1"
	if not knowledge.get("c2_cleaning_record", false) or not knowledge.get("c21_chemical_record", false): return "C2"
	if not local["cleaner_ready"]: return "C3"
	if not local["signal_ready"]: return "C_BELL"
	return "C4"


func available_rooms() -> Array:
	return super.available_rooms() + EXTRA_ROOMS


func _rooms_connected(from: String, to: String, knowledge: Dictionary) -> bool:
	var links := {"M1_MIRROR_GALLERY": "M1_PARLOR", "M1_TOOL_ROOM": "M1_SERVANT_COMMON", "M1_KITCHEN": "M1_SERVANT_COMMON", "M1_COLOR_ROOM_ENTRY": "M1_NORTH_ARCHIVE_HALL"}
	for destination in links:
		if from == destination or to == destination:
			return from == to or from == links[destination] or to == links[destination]
	return super._rooms_connected(from, to, knowledge)


func act(action: String, value: Variant = null) -> Dictionary:
	if not action.begins_with("c_") and not action.begins_with("j3_"):
		return super.act(action, value)
	var state := snapshot()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var loop: Dictionary = state["loop_state"]
	var local := mirror_local(state)
	loop["event_local_states"][MIRROR_KEY] = local
	var room := String(loop["location_id"])
	if stage() == "C_SLEEP": return _reject("일지의 두 번째 페이지를 기억한 채 잠들고, 다음 아침의 거울을 확인한다.")
	var text := ""
	var speaker := "주인공"
	match action:
		"c_observe":
			if room != "M1_MIRROR_GALLERY": return _reject("대응접실 남쪽의 거울 회랑에서 조사한다.")
			knowledge["c0_mirror_seen"] = true
			if "C0_WARNING_GIVEN" not in meta["servants"]["edgar"]["residual_memory"]:
				meta["servants"]["edgar"]["residual_memory"].append("C0_WARNING_GIVEN")
			speaker = "에드가"
			text = "그 표면은 닦는 대상이 아닙니다. 보존 처리가 되어 있습니다."
			if int(meta["servants"]["edgar"]["alert"]) >= 4:
				text += "\n지난번 조사와 연결해서 생각하고 계십니까? 손에 드는 물건부터 확인하겠습니다."
			_note(knowledge, "C0", "거울이 호흡보다 조금 늦게 흐려진다. 에드가는 청소가 아니라 보존이라는 말을 썼다.")
		"c_hypothesis":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("c0_mirror_seen", false): return _reject("먼저 거울과 금지 이유를 확인한다.")
			knowledge["c1_cleaning_hypothesis"] = true
			text = "얼룩이 아니라 코팅일지도 모른다. 일지의 신호와 청소 기록, 약품 라벨을 비교해 보자."
			_note(knowledge, "C1", text)
		"c_read_cleaning", "c_read_chemicals":
			if not knowledge.get("c1_cleaning_hypothesis", false): return _reject("무엇을 닦으려는지부터 확인한다.")
			if action == "c_read_cleaning":
				if room != "M1_TOOL_ROOM": return _reject("청소도구실의 기록을 확인한다.")
				knowledge["c2_cleaning_record"] = true
				text = "청소 기록: 강한 용제는 코팅을 굳힌다. 중성 세정과 부드러운 천을 사용할 것.\n물의 양은 두 첨가제를 합친 양보다 2단위 많게 한다.\n마라 1의 추기: 물때랑 코팅을 헷갈리면 안 됨다. 제가 한 번 크게 배웠슴다."
			else:
				if room != "M1_KITCHEN": return _reject("주방 약품장의 라벨을 확인한다.")
				knowledge["c21_chemical_record"] = true
				text = "라벨: 전체 8단위. 원액은 안정제의 두 배.\n마른 병에 활성 성분을 넣지 말 것. 물에 안정제가 퍼진 뒤 원액을 넣을 것.\n접힌 메모: 손이 떨릴 때도 읽을 수 있게... 큰 글씨로 다시 써 뒀어요."
			_note(knowledge, action, text)
		"c_prepare", "c_shortcut":
			if not knowledge.get("c2_cleaning_record", false) or not knowledge.get("c21_chemical_record", false): return _reject("청소 기록과 약품 라벨이 모두 필요하다.")
			if local["locked"]: return _reject("오늘의 거울 표면은 돌아오지 않는다. 먼저 잠든다.")
			if action == "c_shortcut":
				if room != "M2_BEDROOM" or not meta["failure_knowledge"].has("C4"): return _reject("실패 뒤 같은 침실에서 기록한 준비 동선을 사용한다.")
				loop["location_id"] = "M1_KITCHEN"
				loop["event_local_states"][LOCAL_KEY] = local_state(state)
				loop["event_local_states"][LOCAL_KEY]["routine_done"] = true
				local["path"] = meta["failure_knowledge"]["C4"].get("verified_prefix", []).duplicate()
			elif room != "M1_KITCHEN": return _reject("주방 조합대에서 재료를 준비한다.")
			local["materials_ready"] = true
			text = "빈 눈금병, 물, 안정제와 원액, 부드러운 천을 새로 준비했다. 공식은 남아 있어도 세정액은 직접 다시 만든다."
		"c_pour", "c_disperse", "c_mix", "c_settle", "c_discard", "c_test":
			if room != "M1_KITCHEN" or not local["materials_ready"]: return _reject("주방에서 재료를 먼저 준비한다.")
			if local["cleaner_ready"]: return _reject("검증한 세정액은 밀봉해 두었다. 거울을 준비한다.")
			var mix: Dictionary = local["mixture"]
			if action == "c_discard":
				local["mixture"] = MIRROR.empty_mixture()
				text = "폐기 쟁반에 용액을 비우고 병을 헹군다. 같은 날 다시 계량할 수 있다."
			elif action == "c_pour":
				var material := String(value)
				if material not in MIRROR.MATERIALS: return _reject("표시된 재료를 선택한다.")
				if material != "water" and mix["water"] == 0: return _reject("안전 라벨: 마른 병에는 첨가하지 않는다. 물이 먼저 필요하다.")
				if material == "active" and (mix["stabilizer"] == 0 or not mix["dispersed"]): return _reject("원액은 물속에서 안정제가 확산된 뒤에 넣는다.")
				if int(mix["water"]) + int(mix["stabilizer"]) + int(mix["active"]) >= 8: return _reject("병의 최대 눈금이다. 넘치기 전에 멈추고 폐기 쟁반을 사용한다.")
				if mix["order"].is_empty() or mix["order"].back() != material: mix["order"].append(material)
				mix[material] = int(mix[material]) + 1
				if material == "stabilizer": mix["dispersed"] = false
				mix["mixed"] = 0
			elif action == "c_disperse":
				if mix["stabilizer"] == 0: return _reject("아직 확산시킬 안정제가 없다.")
				mix["dispersed"] = true
				text = "물 표면이 숨을 고르듯 내려앉는다. 안정제가 퍼졌다."
			elif action == "c_mix":
				mix["mixed"] = int(mix["mixed"]) + 1
				mix["foamy"] = int(mix["mixed"]) > 1
			elif action == "c_settle":
				mix["foamy"] = false
				text = "병을 내려놓고 기다리자 거품이 가라앉는다."
			else:
				var tested: Dictionary = MIRROR.test_mixture(mix)
				text = tested["text"]
				if tested["ok"]:
					local["cleaner_ready"] = true
					knowledge["c3_formula_verified"] = true
					_note(knowledge, "C3", "검증한 공식: 물 5, 안정제 1, 원액 2. 물 → 안정제 확산 → 원액, 천천히 혼합.")
		"c_bell":
			if room != "M1_GREAT_CLOCK" or not local["cleaner_ready"]: return _reject("검증한 세정액을 준비한 뒤 대시계의 신호를 다시 보낸다.")
			local["signal_ready"] = true
			loop["time_block"] = "evening_free"
			text = "수첩에 검증한 시계망 설정을 다시 놓는다. 정상 종이 끝난 뒤 한 칸, 열세 번째 떨림이 벽을 지난다."
		"c_handle_patrol":
			if room != "M1_MIRROR_GALLERY" or String(value) not in ["wait", "question", "cloth"]: return _reject("회랑에서 순찰을 확인한다.")
			local["intervention_handled"] = true
			text = {"wait": "순찰이 지나갈 때까지 기다린다. 에드가의 발소리가 멀어진다.", "question": "일지 문장에 관해 묻자 에드가가 복도 쪽에서 보존 원칙을 설명한다. 점검은 끝났다.", "cloth": "일반 천을 앞에 두자 에드가가 그 천을 점검하고 나간다."}[String(value)]
		"c_rotate", "c_flip", "c_anchor", "c_segment", "c_clear_plan", "c_dry", "c_verify_plan", "c_wet":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("c1_cleaning_hypothesis", false): return _reject("거울 앞에서 일지의 가설을 확인한다.")
			if local["locked"]: return _reject("코팅이 굳었다. 기록을 챙기고 같은 침실에서 잠든다.")
			if local["surface_open"] or knowledge.get("mirror_tracing_acquired", false): return _reject("진단면이 이미 드러났다. 회로를 기록한다.")
			if action in ["c_rotate", "c_flip", "c_anchor", "c_segment", "c_clear_plan"]:
				local["dry_passed"] = false
				if action == "c_rotate": local["rotation"] = (int(local["rotation"]) + 90) % 360
				elif action == "c_flip": local["flipped"] = not local["flipped"]
				elif action == "c_anchor": local["anchored"] = not local["anchored"]
				elif action == "c_clear_plan": local["path"] = []
				elif String(value) in MIRROR.SEGMENTS and local["path"].size() < 4: local["path"].append(String(value))
				else: return _reject("경로는 네 구간까지 놓는다. 수정하려면 계획을 다시 펼친다.")
			else:
				if not local["signal_ready"]: return _reject("아직 진동이 닿지 않았다. 세정액을 준비하고 대시계에서 신호를 보낸다.")
				var trace: Dictionary = MIRROR.inspect_trace(local["rotation"], local["flipped"], local["anchored"], local["path"])
				if action == "c_verify_plan":
					if not local["dry_passed"]: return _reject("마른 천으로 전체 경로를 시험한 뒤 계획을 확정한다.")
					knowledge["mirror_verified_plan"] = local["path"].duplicate()
					text = "마른 시험에서 확인한 계획을 수첩에 확정했다. 아직 코팅에는 손대지 않았다."
				elif action == "c_dry":
					local["dry_passed"] = trace["ok"]
					text = "마른 천 시험: " + String(trace["text"])
				else:
					if value != true or not local["cleaner_ready"]: return _reject("검증한 세정액과 되돌릴 수 없는 실행에 대한 확인이 필요하다.")
					if int(meta["servants"]["edgar"]["alert"]) >= 4 and int(meta["servants"]["edgar"]["bond"]) < 4 and not local["intervention_handled"]:
						trace = {"ok": false, "category": "tool_confiscated", "verified_prefix": [], "text": "에드가가 젖은 천을 거둔다. 아직 점검을 마치지 않았다는 말만 남긴다."}
						if "C4_TOOL_CONFISCATED" not in meta["servants"]["edgar"]["residual_memory"]:
							meta["servants"]["edgar"]["residual_memory"].append("C4_TOOL_CONFISCATED")
					local["cleaner_ready"] = false
					text = trace["text"]
					if trace["ok"]:
						local["surface_open"] = true
						knowledge["mirror_tracing_acquired"] = true
						knowledge["c5_raw_capture"] = CHANNELS.duplicate(true)
						if state["fracture_state"]["world_phase"] in ["S0", "S1"]:
							state["fracture_state"]["world_phase"] = "S2"
						text += "\n검은 표면 아래 진단 패널과 냉각 장치 같은 긴 윤곽이 드러난다. 거울 속 호흡만 한 박자 늦다.\n드러난 원도를 우선 수첩에 옮겼다. 다섯 문양의 해석과 대조는 아직 남아 있다."
					else:
						local["locked"] = true
						var old: Dictionary = meta["failure_knowledge"].get("C4", {})
						meta["failure_knowledge"]["C4"] = {"source_event_id": "C4", "status": "active", "attempts": int(old.get("attempts", 0)) + 1, "category": trace["category"], "verified_prefix": trace["verified_prefix"], "text": text}
						_note(knowledge, "CF", text + "\n오늘은 다시 닦을 수 없다. 잠든 뒤 기록으로 준비를 줄인다.")
		"c_scan", "c_record":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("mirror_tracing_acquired", false): return _reject("거울의 진단면을 먼저 드러낸다.")
			if action == "c_scan":
				if not CHANNELS.has(String(value)): return _reject("표시된 채널을 선택한다.")
				if value not in local["channels_scanned"]: local["channels_scanned"].append(value)
				text = ("진단면: " if local["surface_open"] else "수첩의 진단면 사본: ") + CHANNELS[value] + "\n서로 다른 문양이 같은 면 아래에서 겹친다. 이것이 무엇인지는 아직 단정할 수 없다."
			else:
				if local["channels_scanned"].size() != 5: return _reject("색 대신 문양과 이름으로 다섯 출처를 모두 대조한다.")
				knowledge["c5_info_complete"] = true
				knowledge["color_room_entry_inspectable"] = true
				knowledge["C5_MIRROR_TRACING"] = true
				if meta["failure_knowledge"].has("C4"): meta["failure_knowledge"]["C4"]["status"] = "resolved"
				text = "직선·분기·고리의 반사 원도, 침실 창·온실 유리·대시계 기준점과 지하 좌표를 수첩에 고정했다."
				_note(knowledge, "C5_INFO", text + "\n" + "\n".join(CHANNELS.values()))
		"j3_overlay", "j3_piece", "j3_clear", "j3_restore":
			if room != "M1_LIBRARY_INNER" or not knowledge.get("c5_info_complete", false) or local_state(state)["edgar_state"] != "absent": return _reject("자료를 기록한 뒤 조용한 기록 내실에서 일지를 펼친다.")
			if int(meta["journal_stage"]) >= 3: return _reject("세 번째 페이지는 복원되어 있다.")
			if action == "j3_overlay":
				local["j3_overlay_seen"] = true
				text = "탁본을 그대로 놓으면 세 점이 동시에 맞지 않는다. 거울의 방향과 집의 방향을 아직 같은 것으로 믿을 수 없다."
			elif action == "j3_clear": local["j3_order"] = []
			elif action == "j3_piece":
				if int(value) not in range(4): return _reject("문장 조각을 선택한다.")
				if value not in local["j3_order"]: local["j3_order"].append(value)
			else:
				if not local["j3_overlay_seen"] or local["j3_order"] != [0, 1, 2, 3]: return _reject("눌림 자국과 문장이 이어지지 않는다. 탁본의 모순을 확인하고 다시 배열한다.")
				meta["journal_stage"] = 3
				knowledge["j3_restored_day"] = int(loop["day_index"])
				for key in ["KN_J3_TRACING_DIRECTION_UNTRUSTED", "KN_J3_THREE_REFERENCE_POINTS", "KN_J3_MAP_REQUIRED", "KN_J3_BASEMENT_HEART"]: knowledge[key] = true
				text = "\n\n".join(J3_PARTS)
				if knowledge.get("MEM_FATHER_TEA_HAND_FRAGMENT", "") == "sensory_fragment":
					knowledge["MEM_FATHER_DRAWN_DOOR_FRAGMENT"] = "episodic_fragment"
					text += "\n짧은 연필이 종이 가루를 밀어 낸다. 더 큰 손이 외벽을 짚자 없던 문 윤곽이 생긴다. '문은 네가 고르는 곳에...' 기억은 거기서 끊긴다."
				_note(knowledge, "J3", text)
		_:
			return _reject("아직 정의되지 않은 조사다.")
	return _commit(state, text, speaker)


func _commit(state: Dictionary, text: String, speaker: String = "주인공") -> Dictionary:
	var local := mirror_local(state)
	state["loop_state"]["event_local_states"][MIRROR_KEY] = local
	var inventory: Array = state["loop_state"]["inventory"]
	inventory.erase("NEUTRAL_CLEANER")
	if local["cleaner_ready"]: inventory.append("NEUTRAL_CLEANER")
	return super._commit(state, text, speaker)
