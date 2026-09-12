class_name LucaRelationship
extends RefCounted

const PHASES := ["main_1", "main_2", "aux_1", "safety"]
const PHASE_LABELS := {"main_1": "주관 맥박 1", "main_2": "주관 맥박 2", "aux_1": "보조관 응답 1", "safety": "안전 밸브 확인"}
const LOGS := {
	"preservation": "냉각 유지 목적: 멸망기의 독성 대기와 방사선 위험이 낮아질 때까지 신체를 보존한다.",
	"approval": "기상 안전 판정: 환경 담당과 운영 책임자의 공동 승인 필요. 생존 신호 유지와 기상 안전 승인은 서로 다르다.",
	"blank": "아버지 사후 공동 승인 기준: 공란. 최종 해제 날짜: 공란. 연장 사유: 안전 확인 대기. 같은 문장이 반복되어 있다.",
}
const RECORD := "주인공의 외부 신체는 멸망기의 독성 대기·방사선 위험이 낮아질 때까지 냉각 보존되었다. 루카는 보존에 동의했지만 장기 시뮬레이션 감금은 예상하지 못했다. 아버지 사후 기상 기준과 최종 해제 날짜가 확정되지 않았다. 사용인들은 안전을 이유로 각성 결정을 반복 유예했다. 현재 생존 신호는 유지되지만 외부 대기·방사선·신경계 위험이 남아 현실의 안전은 보장할 수 없다."

static func progress(state: Dictionary) -> Dictionary:
	var local := {"panel": false, "pipes": [], "matched": false, "slots": {}, "stable": false, "pressure": 0, "logs": [], "confessed": false}
	local.merge(state["loop_state"]["event_local_states"].get("E3_3", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("relationship_hub_open", false) or state["loop_state"]["location_id"] != "H0_LIFE_SUPPORT":
		return {"ok": false, "text": "합의 뒤 생명 유지실에서 조사한다."}
	if knowledge.get("E3_3_complete", false): return {"ok": false, "text": "같이 읽은 기록은 남아 있다. 선택을 다시 적용하지 않는다."}
	var local := progress(state)
	var text := ""
	match action:
		"panel":
			local["panel"] = true
			text = "혀끝에 금속 맛이 돈다. 손목과 배관의 맥박이 한 번 어긋난다. 굵은 이중 맥박은 BIO MAIN, 점선 응답은 AUX다. 장식 매듭에는 맥박이 없다."
			if knowledge.get("LUCA_S2_complete", false): text += "\n아까 차갑다고 한 건 손이 아니라 바깥쪽 신호였어요."
		"pipe":
			if not local["panel"] or str(value) not in ["main", "aux", "decoration"]: return {"ok": false, "text": "먼저 진단 패널을 조사한다."}
			if str(value) in local["pipes"]: local["pipes"].erase(str(value))
			else: local["pipes"].append(str(value))
			text = "선택한 관을 진단 패널에서 대조한다."
		"match":
			if local["pipes"].size() != 2 or "main" not in local["pipes"] or "aux" not in local["pipes"]: return {"ok": false, "text": "맥박이 없는 장식관은 진단 신호가 아니다. 두 생체 신호를 다시 확인한다."}
			local["matched"] = true
			knowledge["luca_bio_sources_matched"] = true
			text = "현재 아바타와 외부 신체의 신호를 대조한다. 두 번의 주관 맥박 뒤에 보조관 응답, 마지막은 안전 밸브 확인이다."
		"slot":
			if not local["matched"] or not value is Array or value.size() != 2: return {"ok": false, "text": "생체 신호를 먼저 연결한다."}
			var index := int(value[0])
			if index < 0 or index > 3 or str(value[1]) not in PHASES: return {"ok": false, "text": "확인할 위상 슬롯을 선택한다."}
			local["slots"][str(index)] = str(value[1])
			text = "밸브의 위상을 놓는다. 시험은 언제든 미리 재생할 수 있다."
		"preview", "run":
			if not local["matched"]: return {"ok": false, "text": "생체 신호를 먼저 확인한다."}
			var labels: PackedStringArray = []
			var correct := true
			for index in range(4):
				var phase := str(local["slots"].get(str(index), ""))
				labels.append(PHASE_LABELS.get(phase, "미배치"))
				correct = correct and phase == PHASES[index]
			text = " → ".join(labels)
			if action == "run":
				if correct:
					local["stable"] = true
					local["pressure"] = 1
					knowledge["luca_pressure_phase_stable"] = true
					text += "\n주기가 맞았다. 안전 밸브를 확인하고 기록 잠금을 해제한다."
				else:
					local["pressure"] = 0
					text += "\n안전 밸브가 열려 압력이 0으로 돌아간다. 생존 신호는 유지된다. 같은 단계에서 다시 배치할 수 있다."
		"log":
			if not local["stable"] or not LOGS.has(str(value)): return {"ok": false, "text": "압력 위상을 먼저 안정시킨다."}
			if str(value) not in local["logs"]: local["logs"].append(str(value))
			if local["logs"].size() == 3: knowledge["luca_wake_criteria_read"] = true
			text = LOGS[str(value)]
		"confess":
			if local["logs"].size() != 3: return {"ok": false, "text": "세 기상 문서를 함께 확인한다."}
			local["confessed"] = true
			text = "냉각 보존에는 동의했어요... 살릴 수 있다고 믿었어요. 이렇게 오래 접속시키고 결정을 미루게 될 줄은 몰랐어요.\n위험을 말하면 아가씨가 떠날까 봐... 돌려 말했어요. 살려 둔 것과 결정을 미룬 건 같은 일이 아닌데요.\n바깥 몸은 살아 있어요. 깨어난 뒤의 안전은 보장할 수 없어요. 이번엔... 어떤 순서로 확인할지 아가씨가 정해 주세요."
		"choose":
			if not local["confessed"] or str(value) not in ["full_disclosure", "stabilize_first"]: return {"ok": false, "text": "기록과 루카의 말을 먼저 듣는다."}
			var first := str(value) == "stabilize_first"
			var luca: Dictionary = meta["servants"]["luca"]
			luca["bond"] = clampi(int(luca["bond"]) + (1 if first else 2), 0, 5)
			luca["alert"] = clampi(int(luca["alert"]) + (-1 if first else 1), 0, 5)
			luca["core_event_complete"] = true
			luca["researcher_record_acquired"] = true
			for flag in ["E3_3_complete", "REC_LUCA", "protagonist_body_preserved", "wake_criteria_missing"]: knowledge[flag] = true
			meta["event_history"]["E3_3"] = {"event_id": "E3_3", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "E3_3_COMPLETION", "relationship_delta_applied": true, "completed_at_story_phase": "BROKEN_RESET"}
			var risk := "대기 독성·방사선·장기 냉각 이후 신경계 위험은 남아 있어요. 안전 판정은 확정되지 않았어요."
			var stable := "안전 밸브와 생존 신호를 다시 확인한다. 현재 순환은 유지된다."
			text = stable + "\n" + risk if first else risk + "\n" + stable
			var notes: Dictionary = knowledge.get("chapter_notebook", {})
			notes["REC_LUCA"] = RECORD
			knowledge["chapter_notebook"] = notes
		_:
			return {"ok": false, "text": "정의되지 않은 생명 유지 조사다."}
	state["loop_state"]["event_local_states"]["E3_3"] = local
	return {"ok": true, "state": state, "text": text}
