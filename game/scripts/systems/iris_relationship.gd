class_name IrisRelationship
extends RefCounted

const SOURCES := ["PROJECTION", "EXTERNAL", "MEMORY"]
const CHANNELS := {
	"temperature": ["MEMORY", "EXTERNAL", "PROJECTION"],
	"humidity": ["EXTERNAL", "PROJECTION", "MEMORY"],
	"light": ["PROJECTION", "MEMORY", "EXTERNAL"],
}
const CLUES := {
	"PROJECTION": "꽃잎 문양 · 매끄러운 반복 주기",
	"EXTERNAL": "유리 진동 · 불규칙 파형 · 일부 측정 결손",
	"MEMORY": "후광 문양 · 오래된 날짜 · 고정된 과거값",
}
const ORDER := ["warning", "command", "loss", "audit", "conversion"]
const LOGS := {
	"warning": "최초 경고 / 이리스: 두 시설을 함께 살릴 전력이 없다. 이 문서는 승인서가 아니다.",
	"command": "경고 접수 뒤 / 냉각 우선 명령. 실행자: 아버지. 사용 자격: 이리스 관리자. 경고 서명과 실행 승인 서명이 다르다.",
	"loss": "명령 실행 뒤 / 생태 샘플 보관고와 복구 온실 일부 정지. 전력은 주인공 냉각 장치로 이동.",
	"audit": "차단 결과 수신 뒤 / 자동 감사: 최종 승인 책임자 이리스. 명령 실행자와 책임자 필드가 일치하지 않는다.",
	"conversion": "감사 기록 뒤 / 이리스의 정정 요청 미처리. 인격 전환 시행. 승인 오류는 그대로 남음.",
}

static func progress(state: Dictionary) -> Dictionary:
	var local := {"panel": false, "channels": {}, "order": [], "power": false, "mismatch": false, "confronted": false}
	local.merge(state["loop_state"]["event_local_states"].get("E3_2", {}), true)
	return local

static func confession(bond: int, alert: int) -> String:
	if bond >= 4: return "direct_private"
	if bond >= 2: return "indirect"
	return "denied" if alert >= 4 else "withheld"

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	if not knowledge.get("relationship_hub_open", false) or state["loop_state"]["location_id"] != "H0_CLIMATE_CONTROL":
		return {"ok": false, "text": "합의 뒤 계절 제어실에서 조사한다."}
	if knowledge.get("E3_2_complete", false): return {"ok": false, "text": "기록과 선택은 보존되어 있다. 다시 적용하지 않는다."}
	var local := progress(state)
	var text := ""
	match action:
		"panel":
			local["panel"] = true
			text = "따뜻한 빛 아래 공기는 차갑다. 흙은 젖은 냄새만 난다. 온도·습도·광량마다 세 입력이 겹쳐 있다. 꽃잎은 투사, 유리 진동은 외부 측정, 오래된 후광은 기억 모델이다. 어느 계절인지 맞히는 것이 아니라 출처를 분리해야 한다."
		"source":
			if not local["panel"] or not value is Array or value.size() != 3: return {"ok": false, "text": "먼저 계기판을 조사한다."}
			var gauge := str(value[0])
			var index := int(value[1])
			if not CHANNELS.has(gauge) or index < 0 or index > 2 or str(value[2]) not in SOURCES: return {"ok": false, "text": "확인할 입력을 선택한다."}
			if CHANNELS[gauge][index] != str(value[2]):
				text = "출처가 일치하지 않는다. 과거 날짜와 반복 문양, 결손된 유리 파형을 다시 대조한다."
			else:
				local["channels"]["%s_%d" % [gauge, index]] = str(value[2])
				text = "입력을 분리했다. 외부값의 빈칸은 계절 영상으로 채우지 않는다."
				if local["channels"].size() == 9: knowledge["iris_sensor_sources_separated"] = true
		"log":
			if local["channels"].size() != 9 or not LOGS.has(str(value)): return {"ok": false, "text": "세 계기의 출처를 모두 분리한다."}
			if str(value) not in local["order"]: local["order"].append(str(value))
			text = LOGS[str(value)]
		"clear":
			local["order"] = []
			text = "시각과 참조 문장을 다시 대조한다. 분리한 센서값은 유지된다."
		"restore":
			if local["order"] != ORDER: return {"ok": false, "text": "차단 전에 차단 결과가 기록될 수는 없다. 경고는 승인과 다르다. 순서를 다시 확인한다."}
			local["power"] = true
			knowledge["iris_power_route_restored"] = true
			text = "경고, 권한 사용, 설비 손실, 자동 감사, 인격 전환이 이어진다. 이리스가 정정할 기회는 없었다."
		"audit":
			if not local["power"]: return {"ok": false, "text": "먼저 전력 기록을 복원한다."}
			if str(value) != "credential_owner_not_executor": return {"ok": false, "text": "경고 제출자나 자격 소유자가 실제 명령 실행자와 같지는 않다."}
			local["mismatch"] = true
			knowledge["iris_authorization_mismatch_verified"] = true
			text = "자격 소유자는 이리스, 실제 실행자는 아버지다. 자동 감사는 자격 이름을 책임자로 적었다. 경고는 동의가 아니었다."
		"confront":
			if not local["mismatch"]: return {"ok": false, "text": "승인 권한과 실행자의 차이를 먼저 확인한다."}
			local["confronted"] = true
			text = "제 이름을 쓰고, 제게 책임을 남겼어요. 잃어버린 샘플도 복구 가능성도 돌아오지 않아요.\n이리스는 웃지만 날개 관절이 닫힌다.\n아가씨를 아끼는 마음까지 거짓이었던 건 아니에요."
		"choose":
			if not local["confronted"] or str(value) not in ["external_truth", "shelter_projection"]: return {"ok": false, "text": "기록과 이리스의 말을 먼저 확인한다."}
			var shelter := str(value) == "shelter_projection"
			var iris: Dictionary = meta["servants"]["iris"]
			iris["bond"] = clampi(int(iris["bond"]) + (0 if shelter else 2), 0, 5)
			iris["alert"] = clampi(int(iris["alert"]) + (1 if shelter else 0), 0, 5)
			iris["core_event_complete"] = true
			iris["researcher_record_acquired"] = true
			knowledge["E3_2_complete"] = true
			knowledge["REC_IRIS"] = true
			knowledge["iris_power_diversion_known"] = true
			meta["event_history"]["E3_2"] = {"event_id": "E3_2", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "E3_2_COMPLETION", "relationship_delta_applied": true, "completed_at_story_phase": "BROKEN_RESET"}
			text = "외부값과 책임 기록은 남겨 두고, 지금의 온실 모습은 유지할게요." if shelter else "불완전한 외부값과 책임 기록을 그대로 남겨 둘게요."
			match confession(int(iris["bond"]), int(iris["alert"])):
				"direct_private": text += "\n아가씨가 죽기를 바랐어요. 자리가 비면 모든 것이 돌아올 거라고... 하지만 제 분노는 해결책이 아니었어요. 고통을 둘 곳을 찾았던 거예요."
				"indirect": text += "\n아가씨가 사라지면 끝날 거라고 생각했어요. 돌아오지 않는 것에, 돌아올 수 없는 답을 바랐어요."
				"denied": text += "\n그 기록으로 제 마음까지 알 수는 없어요. 제 이름이 도용됐다는 사실만은 남겨 주세요."
				_: text += "\n제 이름으로 잃어버린 것들이 너무 많아요. 화가 났다는 것까지는 말할 수 있어요. 그 다음은... 아직요."
			if int(iris["alert"]) >= 4: text += "\n이리스의 목소리가 가늘고 날카로워진다. 날개는 더 다가오지 않는다."
			var notes: Dictionary = knowledge.get("chapter_notebook", {})
			notes["REC_IRIS"] = "이리스는 생태 복구와 환경 시설 담당이었다. 샘플 보관고와 냉각 장치는 같은 비상 전력망이었다. 이리스는 냉각 우선에 동의하지 않았다. 아버지가 이리스 자격으로 실행했고 감사는 이리스를 책임자로 남겼다. 외부가 안전하다는 확정 보고는 없다. 자원 손실과 책임 전가는 적의의 배경이지 해결책이 아니다."
			knowledge["chapter_notebook"] = notes
		_:
			return {"ok": false, "text": "정의되지 않은 환경 조사다."}
	state["loop_state"]["event_local_states"]["E3_2"] = local
	return {"ok": true, "state": state, "text": text}
