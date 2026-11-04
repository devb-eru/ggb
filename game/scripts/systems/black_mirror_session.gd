class_name BlackMirrorSession
extends ChapterOneSession

const MIRROR := preload("res://data/puzzles/puzzle_black_mirror.tres")
const MIRROR_NOTES := preload("res://scripts/systems/mirror_notebook.gd")
const MIRROR_KEY := "BLACK_MIRROR"
const DIAGNOSTIC_STATE := preload("res://scripts/systems/ep02_diagnostic_state.gd")
const JOURNAL_REFERENCE := preload("res://scripts/systems/ep02_journal_reference.gd")
const EXTRA_ROOMS := ["M1_MIRROR_GALLERY", "M1_TOOL_ROOM", "M1_KITCHEN", "M1_COLOR_ROOM_ENTRY"]
const CHANNELS := {"EDGAR": "에드가 · 수직 잠금선 · 낮은 시계음", "MARA1": "마라 1 · 대각 닦임 · 마른 솔", "LUCA": "루카 · 이중 맥박 · 생체음", "IRIS": "이리스 · 꽃잎 · 유리와 바람", "MARA2": "마라 2 · 이중 액자 · 빠른 세 음"}
const DIAGNOSTICS := {"BODY": "대상 신체", "PERSONALITY": "인격 채널", "EXTERNAL": "외부 환경", "LIFE": "생명 유지", "WAKE": "기상 절차", "MASK": "위장 필터"}
const J3_PARTS := [
	"거울은 네가 건넨 방향을 그대로 돌려주지 않는다.\n보이는 길을 집 위에 놓기 전에, 어느 쪽이 네 손에서 시작됐는지 먼저 되짚어라.",
	"집의 심장은 가장 낮은 곳에서 뛴다.\n하지만 아래로 내려가는 것만으로는 닿지 못한다.",
	"침실의 고요한 점, 온실의 계절이 멈추는 점,\n종이 없는데도 울리는 큰 시계를 한 장 위에 맞춰라.",
	"세 점이 모두 맞는 방향에서만\n입구는 집의 일부였다고 인정할 것이다.",
]

func mirror_local(state: Dictionary = {}) -> Dictionary:
	var source := snapshot() if state.is_empty() else state
	var local := {"materials_ready": false, "mixture": MIRROR.empty_mixture(), "cleaner_ready": false, "locked": false, "rotation": 0, "flipped": false, "anchored": false, "path": [], "dry_passed": false, "intervention_handled": false, "signal_ready": false, "surface_open": false, "channels_scanned": [], "diagnostics_scanned": [], "j3_overlay_seen": false, "j3_order": []}
	local.merge(JOURNAL_REFERENCE.defaults())
	local.merge(source["loop_state"]["event_local_states"].get(MIRROR_KEY, {}), true)
	if local.j3_order is Array:
		local.j3_order = local.j3_order.map(func(part: Variant) -> Variant:
			if typeof(part) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(part)) and float(part) == floorf(float(part)) and int(part) in range(4): return int(part)
			return part)
	return local


func can_prepare_mirror_shortcut() -> bool:
	var state := snapshot()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var local := mirror_local(state)
	return state["loop_state"]["location_id"] == "M2_BEDROOM" \
		and int(meta["journal_stage"]) == 2 \
		and knowledge.get("c2_cleaning_record", false) \
		and knowledge.get("c21_chemical_record", false) \
		and meta["failure_knowledge"].get("C4", {}).get("status", "") == "active" \
		and not local["locked"] \
		and not local["surface_open"] \
		and not knowledge.get("mirror_tracing_acquired", false)


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
	return _commit_feedback(state, String(initialized.get("text", "")), String(initialized.get("speaker", "주인공")), String(initialized.get("text_id", "")), initialized.get("history_context", {}), initialized.get("notebook_feedback", []), initialized.get(LEGACY_FEEDBACK.ORIGIN, {}), int(initialized.get("feedback_contract_version", LEGACY_FEEDBACK.VERSION)))


func stage(state: Dictionary = {}) -> String:
	if state.is_empty(): state = snapshot()
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
	var rooms := super.available_rooms() + EXTRA_ROOMS
	if known("c5_info_complete"): rooms.append("M1_GREENHOUSE")
	return rooms


func sheet_reactions(state: Dictionary = {}) -> Dictionary:
	if state.is_empty(): state = snapshot()
	var known: Dictionary = state.meta_progress.knowledge_entries
	var room: String = state.loop_state.location_id
	var effects := preload("res://scripts/systems/sheet_dialogue_effects.gd")
	var reactions := {}
	if room == "M1_MIRROR_GALLERY" and known.get("c2_cleaning_record", false):
		reactions.MARA1_S2 = {"owner": "MARA1", "start": "EP02_MARA1_S2_001", "complete": effects.event_seen(state, "MARA1_S2")}
	if room == "M1_KITCHEN" and known.get("c21_chemical_record", false):
		reactions.LUCA_C21 = {"owner": "LUCA", "start": "EP02_ROUTER_C21_REACTION", "complete": state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).has("EFF_EP02_0013")}
	if room == "M1_COLOR_ROOM_ENTRY":
		reactions.MARA2_S2 = {"owner": "MARA2", "start": "EP02_MARA2_S2_001", "complete": effects.event_seen(state, "MARA2_S2"), "flavor_only": not known.get("c5_info_complete", false)}
	if room == "M1_GREENHOUSE" and known.get("c5_info_complete", false):
		reactions.IRIS_S2 = {"owner": "IRIS", "start": "EP02_IRIS_S2_001", "complete": effects.event_seen(state, "IRIS_S2")}
	return reactions


func _rooms_connected(from: String, to: String, knowledge: Dictionary) -> bool:
	var links := {"M1_MIRROR_GALLERY": "M1_PARLOR", "M1_TOOL_ROOM": "M1_SERVANT_COMMON", "M1_KITCHEN": "M1_SERVANT_COMMON", "M1_COLOR_ROOM_ENTRY": "M1_NORTH_ARCHIVE_HALL", "M1_GREENHOUSE": "M1_CENTRAL_HALL"}
	if to == "M1_GREENHOUSE" and not knowledge.get("c5_info_complete", false): return false
	for destination in links:
		if from == destination or to == destination:
			return from == to or from == links[destination] or to == links[destination]
	return super._rooms_connected(from, to, knowledge)


func act(action: String, value: Variant = null) -> Dictionary:
	if not action.begins_with("c_") and not action.begins_with("j3_"):
		return super.act(action, value)
	var state := snapshot()
	var event_context := history_context()
	if state.meta_progress.dialogue_history.has("schema_version"):
		event_context.event_occurrence_id = preload("res://scripts/systems/notebook_archive.gd").new_uid()
		event_context.conversation_session_id = preload("res://scripts/systems/notebook_archive.gd").new_uid()
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var loop: Dictionary = state["loop_state"]
	var local := mirror_local(state)
	loop["event_local_states"][MIRROR_KEY] = local
	var room := String(loop["location_id"])
	if stage() == "C_SLEEP": return _reject("일지의 두 번째 페이지를 기억한 채 잠들고, 다음 아침의 거울을 확인한다.")
	var text := ""
	var authored_feedback: Array = []
	var speaker := "주인공"
	var notes: Array = []
	var feedback_key: String = {"c_hypothesis": "HYPOTHESIS", "c_read_cleaning": "CLEANING", "c_read_chemicals": "CHEMICALS", "c_prepare": "PREPARE", "c_shortcut": "SHORTCUT", "c_discard": "DISCARD", "c_disperse": "DISPERSE", "c_settle": "SETTLE", "c_bell": "BELL", "c_verify_plan": "PLAN", "c_record": "RECORD", "j3_overlay": "OVERLAY"}.get(action, "")
	match action:
		"c_reason":
			if not knowledge.get("c2_cleaning_record", false) or not knowledge.get("c21_chemical_record", false): return _reject("두 기록을 먼저 확인한다.")
			if not value is Dictionary or value.get("ratio") != true or value.get("difference") != true: return _reject("수첩에서 두 양의 관계를 함께 대조한다.")
			knowledge["c3_ratio_reviewed"] = true
			var ids := ["EP02_C3_CARD_001", "EP02_C3_CARD_002", "EP02_C3_CARD_SUCCESS_001", "EP02_C3_CARD_SUCCESS_002"]
			var paragraphs: Array[String] = []
			for id in ids:
				paragraphs.append(preload("res://scripts/systems/ep01_script.gd").text(id))
				authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_" + id, preload("res://scripts/systems/ep01_script.gd").notebook_version("NB_" + id), {"body": {}}))
			text = "\n\n".join(paragraphs)
		"c_inspect":
			var ids := preload("res://scripts/systems/ep02_object_surfaces.gd").pages(state, String(value))
			if ids.is_empty(): return _reject("지금 조사할 수 없는 대상이다.")
			var seen: Array = local.get("objects_seen", []).duplicate()
			if value not in seen: seen.append(value)
			local["objects_seen"] = seen
			if value == "OBJ_CHEM_CABINET" and local.get("materials_ready", false): local["cabinet_acquisition_seen"] = true
			var paragraphs: Array[String] = []
			for id in ids:
				paragraphs.append(preload("res://scripts/systems/ep01_script.gd").text(id))
				authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_" + id, preload("res://scripts/systems/ep01_script.gd").notebook_version("NB_" + id), {"body": {}}))
			text = "\n\n".join(paragraphs)
		"c_observe":
			if room != "M1_MIRROR_GALLERY": return _reject("대응접실 남쪽의 거울 회랑에서 조사한다.")
			knowledge["c0_mirror_seen"] = true
			if "C0_WARNING_GIVEN" not in meta["servants"]["edgar"]["residual_memory"]:
				meta["servants"]["edgar"]["residual_memory"].append("C0_WARNING_GIVEN")
			speaker = "에드가"
			text = MIRROR_NOTES.FIXED.OBSERVE
			feedback_key = "OBSERVE"
			if int(meta["servants"]["edgar"]["alert"]) >= 4:
				text += "\n" + MIRROR_NOTES.FIXED.WARNING
				feedback_key = "OBSERVE_WARNING"
			notes.append(["C0", "C0", MIRROR_NOTES.FIXED.C0_NOTE])
		"c_hypothesis":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("c0_mirror_seen", false): return _reject("먼저 거울과 금지 이유를 확인한다.")
			knowledge["c1_cleaning_hypothesis"] = true
			text = MIRROR_NOTES.FIXED.HYPOTHESIS
			notes.append(["C1", "C1", text])
		"c_read_cleaning", "c_read_chemicals":
			if not knowledge.get("c1_cleaning_hypothesis", false): return _reject("무엇을 닦으려는지부터 확인한다.")
			if action == "c_read_cleaning":
				if room != "M1_TOOL_ROOM": return _reject("청소도구실의 기록을 확인한다.")
				knowledge["c2_cleaning_record"] = true
				text = MIRROR_NOTES.FIXED.CLEANING
			else:
				if room != "M1_KITCHEN": return _reject("주방 약품장의 라벨을 확인한다.")
				knowledge["c21_chemical_record"] = true
				text = MIRROR_NOTES.FIXED.CHEMICALS
			notes.append([action, feedback_key, text])
		"c_prepare", "c_shortcut":
			if not knowledge.get("c2_cleaning_record", false) or not knowledge.get("c21_chemical_record", false): return _reject("청소 기록과 약품 라벨이 모두 필요하다.")
			if local["locked"]: return _reject("오늘의 거울 표면은 돌아오지 않는다. 먼저 잠든다.")
			if action == "c_shortcut":
				if not can_prepare_mirror_shortcut(): return _reject("실패 뒤 같은 침실에서 기록한 준비 동선을 사용한다. 이미 확보한 거울 회로는 수첩에서 이어서 조사한다.")
				loop["location_id"] = "M1_KITCHEN"
				loop["event_local_states"][LOCAL_KEY] = local_state(state)
				loop["event_local_states"][LOCAL_KEY]["routine_done"] = true
				local["path"] = meta["failure_knowledge"]["C4"].get("verified_prefix", []).duplicate()
			elif room != "M1_KITCHEN": return _reject("주방 조합대에서 재료를 준비한다.")
			local["materials_ready"] = true
			text = MIRROR_NOTES.FIXED.PREPARE
		"c_pour", "c_pour_water_five", "c_disperse", "c_mix", "c_settle", "c_discard", "c_discard_cancel", "c_test":
			if room != "M1_KITCHEN" or not local["materials_ready"]: return _reject("주방에서 재료를 먼저 준비한다.")
			if local["cleaner_ready"]: return _reject("검증한 세정액은 밀봉해 두었다. 거울을 준비한다.")
			var mix: Dictionary = local["mixture"]
			if action not in ["c_discard", "c_discard_cancel", "c_test"] and MIRROR.order_locked(mix):
				return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_C3_UI_POUR_DISABLED"))
			if action == "c_discard_cancel":
				if not MIRROR.order_locked(mix): return _reject("폐기를 취소했다.")
				text = preload("res://scripts/systems/ep01_script.gd").text("EP02_C3_UI_DISCARD_CANCEL")
				authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_EP02_C3_UI_DISCARD_CANCEL", 1, {"body": {}}))
			elif action == "c_discard":
				local["mixture"] = MIRROR.empty_mixture()
				local["mixture_test_failed"] = false
				text = MIRROR_NOTES.FIXED.DISCARD
			elif action in ["c_pour", "c_pour_water_five"]:
				var material := "water" if action == "c_pour_water_five" else String(value)
				var amount := 5 if action == "c_pour_water_five" else 1
				if material not in MIRROR.MATERIALS: return _reject("표시된 재료를 선택한다.")
				if material != "water" and mix["water"] == 0:
					return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_C3_FB_ACTIVE_FIRST_BLOCK" if material == "active" else "EP02_C3_FB_STABILIZER_FIRST_BLOCK"))
				if material == "active" and (mix["stabilizer"] == 0 or not mix["dispersed"]):
					return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_C3_FB_ACTIVE_EARLY"))
				if int(mix["water"]) + int(mix["stabilizer"]) + int(mix["active"]) + amount > 8: return _reject("병의 최대 눈금이다. 넘치기 전에 멈추고 폐기 쟁반을 사용한다.")
				if mix["order"].is_empty() or mix["order"].back() != material: mix["order"].append(material)
				mix[material] = int(mix[material]) + amount
				if material == "stabilizer": mix["dispersed"] = false
				mix["mixed"] = 0
			elif action == "c_disperse":
				if mix["stabilizer"] == 0: return _reject("아직 확산시킬 안정제가 없다.")
				mix["dispersed"] = true
				text = MIRROR_NOTES.FIXED.DISPERSE
			elif action == "c_mix":
				mix["mixed"] = int(mix["mixed"]) + 1
				mix["foamy"] = int(mix["mixed"]) > 1
			elif action == "c_settle":
				mix["foamy"] = false
				text = MIRROR_NOTES.FIXED.SETTLE
			else:
				var tested: Dictionary = MIRROR.test_mixture(mix)
				local["mixture_test_failed"] = not tested.ok
				text = tested["text"]
				feedback_key = "MIXTURE_" + String(tested.category).to_upper()
				if tested["ok"]:
					local["cleaner_ready"] = true
					knowledge["c3_formula_verified"] = true
					notes.append(["C3", "FORMULA", MIRROR_NOTES.FIXED.FORMULA])
		"c_bell":
			if room != "M1_GREAT_CLOCK" or not local["cleaner_ready"]: return _reject("검증한 세정액을 준비한 뒤 대시계의 신호를 다시 보낸다.")
			local["signal_ready"] = true
			loop["time_block"] = "evening_free"
			text = MIRROR_NOTES.FIXED.BELL
		"c_handle_patrol":
			if room != "M1_MIRROR_GALLERY" or String(value) not in ["wait", "question", "cloth"]: return _reject("회랑에서 순찰을 확인한다.")
			if int(meta.servants.edgar.alert) >= 4 and int(meta.servants.edgar.bond) < 4:
				local["witnesses"] = ["EDGAR"]
			local["intervention_handled"] = true
			feedback_key = "PATROL_" + String(value).to_upper()
			text = MIRROR_NOTES.FIXED[feedback_key]
		"c_rotate", "c_rotate_ccw", "c_transparency", "c_flip", "c_anchor", "c_anchor_other", "c_segment", "c_clear_plan", "c_dry", "c_verify_plan", "c_wet":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("c1_cleaning_hypothesis", false): return _reject("거울 앞에서 일지의 가설을 확인한다.")
			if local["locked"]: return _reject("코팅이 굳었다. 기록을 챙기고 같은 침실에서 잠든다.")
			if local["surface_open"] or knowledge.get("mirror_tracing_acquired", false): return _reject("진단면이 이미 드러났다. 회로를 기록한다.")
			if action == "c_transparency":
				if value not in ["low", "high"]: return _reject("표시된 투명도를 선택한다.")
				local["overlay_transparency"] = String(value)
			elif action in ["c_rotate", "c_rotate_ccw", "c_flip", "c_anchor", "c_anchor_other", "c_segment", "c_clear_plan"]:
				local["dry_passed"] = false
				if action in ["c_rotate", "c_rotate_ccw"]: local["rotation"] = (int(local["rotation"]) + (270 if action == "c_rotate_ccw" else 90)) % 360
				elif action == "c_flip": local["flipped"] = not local["flipped"]
				elif action == "c_anchor":
					local["anchored"] = not local["anchored"]
					local["anchor_choice"] = "lower" if local["anchored"] else "none"
				elif action == "c_anchor_other":
					local["anchored"] = false
					local["anchor_choice"] = "other"
				elif action == "c_clear_plan": local["path"] = []
				elif String(value) in MIRROR.SEGMENTS and local["path"].size() < 4: local["path"].append(String(value))
				else: return _reject("경로는 네 구간까지 놓는다. 수정하려면 계획을 다시 펼친다.")
			else:
				if not local["signal_ready"]: return _reject("아직 진동이 닿지 않았다. 세정액을 준비하고 대시계에서 신호를 보낸다.")
				var trace: Dictionary = MIRROR.inspect_trace(local["rotation"], local["flipped"], local["anchored"], local["path"])
				if action == "c_verify_plan":
					if not local["dry_passed"]: return _reject("마른 천으로 전체 경로를 시험한 뒤 계획을 확정한다.")
					knowledge["mirror_verified_plan"] = local["path"].duplicate()
					text = MIRROR_NOTES.FIXED.PLAN
					notes.append(["", "PLAN", text])
				elif action == "c_dry":
					local["dry_passed"] = trace["ok"]
					text = "마른 천 시험: " + String(trace["text"])
					feedback_key = "DRY_" + ("SUCCESS" if trace.ok else String(trace.category).to_upper())
				else:
					if value != true or not local["cleaner_ready"]: return _reject("검증한 세정액과 되돌릴 수 없는 실행에 대한 확인이 필요하다.")
					var witnesses: Array = local.get("witnesses", []).duplicate()
					if sheet_reactions(state).has("MARA1_S2") and "MARA1" not in witnesses: witnesses.append("MARA1")
					local["witnesses"] = witnesses
					if int(meta["servants"]["edgar"]["alert"]) >= 4 and int(meta["servants"]["edgar"]["bond"]) < 4 and not local["intervention_handled"]:
						if "EDGAR" not in local["witnesses"]: local["witnesses"].append("EDGAR")
						trace = {"ok": false, "category": "tool_confiscated", "verified_prefix": [], "text": MIRROR_NOTES.FIXED.CONFISCATED}
						if "C4_TOOL_CONFISCATED" not in meta["servants"]["edgar"]["residual_memory"]:
							meta["servants"]["edgar"]["residual_memory"].append("C4_TOOL_CONFISCATED")
					local["cleaner_ready"] = false
					text = trace["text"]
					feedback_key = "WET_" + ("SUCCESS" if trace.ok else String(trace.category).to_upper())
					if trace["ok"]:
						local["surface_open"] = true
						knowledge["mirror_tracing_acquired"] = true
						knowledge["c5_raw_capture"] = CHANNELS.duplicate(true)
						if state["fracture_state"]["world_phase"] in ["S0", "S1"]:
							state["fracture_state"]["world_phase"] = "S2"
						text += "\n" + MIRROR_NOTES.FIXED.RAW
						notes.append(["", "RAW", MIRROR_NOTES.FIXED.RAW])
					else:
						local["locked"] = true
						var old: Dictionary = meta["failure_knowledge"].get("C4", {})
						meta["failure_knowledge"]["C4"] = {"source_event_id": "C4", "status": "active", "attempts": int(old.get("attempts", 0)) + 1, "category": trace["category"], "verified_prefix": trace["verified_prefix"], "text": text}
						notes.append(["CF", "CF_" + String(trace.category).to_upper(), text + "\n" + MIRROR_NOTES.FIXED.FAILURE_SUFFIX])
		"c_scan", "c_record":
			if room != "M1_MIRROR_GALLERY" or not knowledge.get("mirror_tracing_acquired", false): return _reject("거울의 진단면을 먼저 드러낸다.")
			if action == "c_scan":
				if DIAGNOSTICS.has(String(value)):
					var repeated := DIAGNOSTIC_STATE.seen(state, String(value))
					if value not in local["diagnostics_scanned"]: local["diagnostics_scanned"].append(value)
					text = preload("res://scripts/systems/ep01_script.gd").text("EP02_C5_HOT_%s_%s" % [value, "REPEAT" if repeated else "FIRST"])
					authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_EP02_C5_HOT_%s_%s" % [value, "REPEAT" if repeated else "FIRST"], 1, {"body": {}}))
					var knowledge_id: String = preload("res://scripts/systems/ep01_script.gd").node("EP02_C5_HOT_%s_FIRST" % value).get("knowledge_id", "NONE")
					if knowledge_id != "NONE": knowledge[knowledge_id] = true
				elif value == "SUBJECT":
					local["subject_scanned"] = true
					text = preload("res://scripts/systems/ep01_script.gd").text("EP02_C5_HOT_SUBJECT_CHANNEL")
					authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_EP02_C5_HOT_SUBJECT_CHANNEL", 1, {"body": {}}))
				elif CHANNELS.has(String(value)):
					if value not in local["channels_scanned"]: local["channels_scanned"].append(value)
					text = ("진단면: " if local["surface_open"] else "수첩의 진단면 사본: ") + CHANNELS[value] + "\n" + MIRROR_NOTES.FIXED.SCAN_SUFFIX
					feedback_key = ("SCAN_SURFACE_" if local.surface_open else "SCAN_COPY_") + String(value)
				else: return _reject("표시된 진단 항목을 선택한다.")
				DIAGNOSTIC_STATE.remember(state, String(value))
			else:
				var required_count := DIAGNOSTIC_STATE.required_count(state)
				if not knowledge.get("c5_info_complete", false) and required_count < 2: return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_C5_CH_SCAN_PROGRESS_%d" % (required_count + 1)))
				knowledge["c5_info_complete"] = true
				knowledge["color_room_entry_inspectable"] = true
				knowledge["C5_MIRROR_TRACING"] = true
				if meta["failure_knowledge"].has("C4"): meta["failure_knowledge"]["C4"]["status"] = "resolved"
				text = MIRROR_NOTES.FIXED.RECORD
				notes.append(["C5_INFO", "C5_INFO", text + "\n" + "\n".join(CHANNELS.values())])
				if meta.failure_knowledge.has("C4"): notes.append(["", "CF_RESOLVED", MIRROR_NOTES.FAILURE_RESOLVED])
		"j3_overlay", "j3_remove_trace", "j3_point", "j3_flip_page", "j3_compare", "j3_pick_part", "j3_drop_part", "j3_piece", "j3_clear", "j3_restore":
			if room == "M1_LIBRARY_INNER" and not knowledge.get("c5_info_complete", false): return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_J3_UI_PAGE_LOCKED"))
			if room != "M1_LIBRARY_INNER" or not knowledge.get("c5_info_complete", false) or local_state(state)["edgar_state"] != "absent": return _reject("자료를 기록한 뒤 조용한 서재 내실에서 일지를 펼친다.")
			if int(meta["journal_stage"]) >= 3: return _reject("세 번째 페이지는 복원되어 있다.")
			if action in ["j3_overlay", "j3_remove_trace", "j3_point", "j3_flip_page", "j3_compare", "j3_pick_part", "j3_drop_part"]:
				var applied := JOURNAL_REFERENCE.act(local, action, value)
				if not applied.ok: return _reject(preload("res://scripts/systems/ep01_script.gd").text(applied.id) if applied.has("id") else applied.text)
				var paragraphs: Array[String] = []
				for identity in applied.ids:
					paragraphs.append(preload("res://scripts/systems/ep01_script.gd").text(identity))
					authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_" + identity, preload("res://scripts/systems/ep01_script.gd").notebook_version("NB_" + identity), {"body": {}}))
				text = "\n\n".join(paragraphs)
				if action == "j3_flip_page":
					var identity := "EP02_SYS_UI_J3_LIMIT"
					text = preload("res://scripts/systems/ep01_script.gd").text(identity)
					authored_feedback.append(preload("res://scripts/systems/notebook_content.gd").descriptor("NB_" + identity, preload("res://scripts/systems/ep01_script.gd").notebook_version("NB_" + identity), {"body": {}}))
				feedback_key = ""
				if action == "j3_overlay":
					authored_feedback.clear()
					text = MIRROR_NOTES.FIXED.OVERLAY
					feedback_key = "OVERLAY"
			elif action == "j3_clear":
				local["j3_order"] = []
				local.j3_held_part = -1
			elif action == "j3_piece":
				if int(value) not in range(4): return _reject("문장 조각을 선택한다.")
				if value not in local["j3_order"]: local["j3_order"].append(value)
			else:
				if not JOURNAL_REFERENCE.ready(local): return _reject("세 기준점과 페이지 앞뒤를 먼저 대조한다. 정확한 방향은 아직 평면도와 확인하지 않았다.")
				if local.j3_order.size() == 4 and local.j3_order != [0, 1, 2, 3]: return _reject(preload("res://scripts/systems/ep01_script.gd").text("EP02_J3_FB_ORDER_BAD"))
				if not local["j3_overlay_seen"] or local["j3_order"] != [0, 1, 2, 3]: return _reject("눌림 자국과 문장이 이어지지 않는다. 탁본의 모순을 확인하고 다시 배열한다.")
				meta["journal_stage"] = 3
				knowledge["j3_restored_day"] = int(loop["day_index"])
				for key in ["KN_J3_TRACING_DIRECTION_UNTRUSTED", "KN_J3_THREE_REFERENCE_POINTS", "KN_J3_MAP_REQUIRED", "KN_J3_BASEMENT_HEART"]: knowledge[key] = true
				text = "\n\n".join(J3_PARTS)
				feedback_key = "J3"
				if knowledge.get("MEM_FATHER_TEA_HAND_FRAGMENT", "") == "sensory_fragment" and preload("res://scripts/systems/sheet_dialogue_effects.gd").j3_memory_seen(state):
					knowledge["MEM_FATHER_DRAWN_DOOR_FRAGMENT"] = "episodic_fragment"
					text += "\n" + MIRROR_NOTES.FIXED.MEMORY
					feedback_key = "J3_MEMORY"
				notes.append(["J3", feedback_key, text])
		_:
			return _reject("아직 정의되지 않은 조사다.")
	for note in notes:
		if not String(note[0]).is_empty(): _note(knowledge, note[0], note[2])
		var written := MIRROR_NOTES.write(state, note[1], note[2], event_context, TranslationServer.get_locale())
		if not written.ok: return written
	event_context.erase("conversation_session_id")
	return _commit_feedback(state, text, speaker, "", event_context, authored_feedback if not authored_feedback.is_empty() else (MIRROR_NOTES.paragraphs(feedback_key) if not feedback_key.is_empty() else []))


func _save_point(state: Dictionary) -> String:
	if get_script().resource_path.ends_with("/black_mirror_session.gd") and int(state.meta_progress.journal_stage) >= 3 and state.meta_progress.event_history.get("EP02_DIALOGUE_EFFECTS", {}).get("EFF_EP02_0049", false):
		return "SAVE_J3_COMPLETE"
	return super._save_point(state)


func _commit(state: Dictionary, text: String, speaker: String = "주인공") -> Dictionary:
	var local := mirror_local(state)
	state["loop_state"]["event_local_states"][MIRROR_KEY] = local
	var inventory: Array = state["loop_state"]["inventory"]
	inventory.erase("NEUTRAL_CLEANER")
	if local["cleaner_ready"]: inventory.append("NEUTRAL_CLEANER")
	return super._commit(state, text, speaker)
