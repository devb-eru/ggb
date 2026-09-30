class_name Mara2Relationship
extends RefCounted

# Deterministic temporary portrait data; replace the presentation, not the rules.
const OWNERS := ["EDGAR", "MARA1", "LUCA", "IRIS", "MARA2"]
const SIGNS := {"EDGAR": "수직선 · 낮은 시계음", "MARA1": "대각선 · 솔 소리", "LUCA": "이중 맥박", "IRIS": "꽃잎 · 유리와 바람", "MARA2": "이중 액자 · 빠른 3음"}
const PORTRAITS := {"A": {"wear": 2, "start": 1, "outline": 2}, "B": {"wear": 3, "start": 2, "outline": 0}, "C": {"wear": 1, "start": 0, "outline": 1}}
const ORDER := ["C", "A", "B"]
const CHECKSUM := ["선", "점", "호", "점", "선", "호", "선", "점", "호", "선", "점", "호"]
const GAPS := [2, 6, 10]
const BACKUPS := {"EDGAR": {2: "호"}, "MARA1": {6: "선"}, "LUCA": {10: "점"}, "IRIS": {2: "호", 10: "점"}}
const RECORD := "마라 2는 인격 아카이브·기억 체크섬 담당이었다. 다른 네 인격의 감정 주석과 장기 기억이 손상되자 자기 감정 주석 영역을 몰래 보조 저장소로 양도했다. 그 결과 자기 이름의 원형·사적 기억·도움 요청 방식부터 잃었다. 이름표 반복 확인은 자기 식별 검사였다. 원본과 감정 주석은 모두 보존했으나 완전한 회복을 보장하지 않는다."

static func progress(state: Dictionary) -> Dictionary:
	var local := {"sources": {}, "order": [], "starts": {}, "outlines": {}, "overlay": false, "backups": [], "cells": {}, "solved": false, "confessed": false}
	local.merge(state["loop_state"]["event_local_states"].get("E3_5", {}), true)
	return local

static func apply(source: Dictionary, action: String, value: Variant) -> Dictionary:
	var state := source.duplicate(true)
	var meta: Dictionary = state["meta_progress"]
	var knowledge: Dictionary = meta["knowledge_entries"]
	var room := str(state["loop_state"]["location_id"])
	if not knowledge.get("relationship_hub_open", false) or room not in ["H0_COLOR_SEPARATION", "H0_PERSONALITY_ARCHIVE"]: return {"ok": false, "text": "합의 뒤 색분해실과 인격 아카이브에서 조사한다."}
	if knowledge.get("E3_5_complete", false): return {"ok": false, "text": "두 기록은 이미 보존했다. 선택을 재적용하지 않는다."}
	var local := progress(state)
	var text := ""
	if action in ["backup", "cell", "checksum", "confess", "choose"] and room != "H0_PERSONALITY_ARCHIVE": return {"ok": false, "text": "겹친 기록의 안쪽, 인격 아카이브에서 확인한다."}
	match action:
		"source":
			if not value is Array or value.size() != 3 or not PORTRAITS.has(str(value[0])) or str(value[1]) not in OWNERS: return {"ok": false, "text": "초상화와 채널 문양을 확인한다."}
			if str(value[1]) != str(value[2]): return {"ok": false, "text": "문양 주기가 일치하지 않는다. 다른 소유자 신호가 섞였다."}
			local["sources"][str(value[0]) + "_" + str(value[1])] = true
			text = "세 시점에서 같은 인격의 신호를 분리한다. 내 채널은... 장식용 잡음이라고 해도 되는데!"
		"portrait":
			if local["sources"].size() != 15 or not PORTRAITS.has(str(value)): return {"ok": false, "text": "세 초상화의 다섯 소유자를 먼저 모두 분리한다."}
			if str(value) not in local["order"]: local["order"].append(str(value))
			text = "보라 이중 액자 조각을 열화 순서에 놓는다."
		"clear":
			local["order"] = []
			text = "초상화 순서를 다시 비교한다. 분리한 출처는 유지된다."
		"align":
			if local["sources"].size() != 15 or not value is Array or value.size() != 3 or not PORTRAITS.has(str(value[0])) or str(value[1]) not in ["start", "outline"]: return {"ok": false, "text": "분리한 이중 액자 조각을 확인한다."}
			if int(value[2]) not in [0, 1, 2]: return {"ok": false, "text": "세 기준점 중 하나를 선택한다."}
			local["starts" if str(value[1]) == "start" else "outlines"][str(value[0])] = int(value[2])
			text = "3음 시작점과 이중 윤곽의 기준선을 맞춘다."
		"overlay":
			if local["order"] != ORDER: return {"ok": false, "text": "열화가 회복됐다 다시 악화된다. 손상이 적은 시점부터 대조한다."}
			for portrait in PORTRAITS:
				if local["starts"].get(portrait, -1) != PORTRAITS[portrait]["start"]: return {"ok": false, "text": "3음이 2음과 잡음으로 갈라진다. 시작 표식을 다시 확인한다."}
				if local["outlines"].get(portrait, -1) != PORTRAITS[portrait]["outline"]: return {"ok": false, "text": "이중 윤곽이 한 인물로 겹치지 않는다. 액자 기준선을 확인한다."}
			local["overlay"] = true
			for index in range(12):
				if index not in GAPS: local["cells"][str(index)] = CHECKSUM[index]
			text = "세 시점 모두 3·7·11칸이 비어 있다. 우연한 손상이 아니다. 마라 2의 말끝에서 느낌표가 사라진다."
		"backup":
			if not local["overlay"] or not BACKUPS.has(str(value)): return {"ok": false, "text": "공통 결손을 먼저 확인한다."}
			if str(value) not in local["backups"]: local["backups"].append(str(value))
			var pieces: PackedStringArray = []
			for index in BACKUPS[str(value)]: pieces.append("%d칸: %s" % [index + 1, BACKUPS[str(value)][index]])
			text = str(value) + " 보조 영역 / " + ", ".join(pieces) + "\n소유자 서명은 달라도 원본 참조는 마라 2의 이중 액자다."
		"cell":
			if not value is Array or value.size() != 2 or int(value[0]) not in GAPS or str(value[1]) not in ["선", "점", "호"]: return {"ok": false, "text": "결손 칸에 기록 조각을 놓는다."}
			if local["backups"].size() != 4: return {"ok": false, "text": "다른 네 기록의 보조 영역을 먼저 확인한다."}
			local["cells"][str(int(value[0]))] = str(value[1])
			text = "결손 칸에 사본 조각을 놓는다."
		"checksum":
			var matches := 0
			for index in range(12):
				if local["cells"].get(str(index), "") == CHECKSUM[index]: matches += 1
			text = "체크섬 일치: %d / 12" % matches
			if matches == 12 and local["backups"].size() == 4:
				local["solved"] = true
				knowledge["E3_5_puzzle_solved"] = true
				text += "\n분산된 주석의 원본을 찾았다. 아직 보존 방식은 정하지 않았다."
		"confess":
			if not local["solved"]: return {"ok": false, "text": "분산된 원본 조각을 먼저 확인한다."}
			local["confessed"] = true
			text = "용량이 줄어들자 다른 네 사람의 감정 주석부터 망가졌어요. 내 영역을 나눠 주면 된다고 계산했어요. 아무한테도 안 물었죠.\n이름의 원형, 사적인 기억, 도와 달라는 말부터 사라졌어요. 이름표를 보는 건... 아직 내가 있는지 확인하는 거예요.\n내가 제일 빨리 계산했고, 그래서 내가 제일 먼저 망가졌어요."
			var bond := int(meta["servants"]["mara2"]["bond"])
			if bond >= 4: text += "\n나를 기억해 줘."
			elif bond >= 2: text += "\n다음에는 이름 칸도 비어 있을까 봐."
			if int(meta["servants"]["mara2"]["alert"]) >= 4: text += "\n방금 말은... 천재의 농담이라고 해두죠!"
		"choose":
			if not local["confessed"] or str(value) not in ["merged", "separated"]: return {"ok": false, "text": "복원한 원본과 마라 2의 말을 먼저 확인한다."}
			var merged := str(value) == "merged"
			var mara: Dictionary = meta["servants"]["mara2"]
			mara["bond"] = clampi(int(mara["bond"]) + (2 if merged else 1), 0, 5)
			mara["alert"] = clampi(int(mara["alert"]) + (1 if merged else -1), 0, 5)
			mara["core_event_complete"] = true
			mara["researcher_record_acquired"] = true
			for flag in ["E3_5_complete", "REC_MARA2", "mara2_self_sacrifice_known", "mara2_archive_index_known"]: knowledge[flag] = true
			meta["event_history"]["E3_5"] = {"event_id": "E3_5", "lifecycle": "completed", "outcome_id": str(value), "completion_transaction_id": "E3_5_COMPLETION", "relationship_delta_applied": true, "completed_at_story_phase": "BROKEN_RESET"}
			var notes: Dictionary = knowledge.get("chapter_notebook", {})
			notes["REC_MARA2"] = RECORD
			knowledge["chapter_notebook"] = notes
			text = "두 윤곽이 겹친다. '이제 틀려도 제 기억이 틀린 거네요!' 웃음 뒤 숨이 가빠져 주인공이 출력을 낮춘다. 완전한 이름은 아직 떠오르지 않는다." if merged else "두 윤곽 사이에 가는 참조선이 놓인다. '둘 다 나라고 우기면 천재가 두 명인 셈이죠!' 주인공이 놓은 이름표를 마라 2는 고치지 않는다."
		_:
			return {"ok": false, "text": "정의되지 않은 아카이브 조사다."}
	state["loop_state"]["event_local_states"]["E3_5"] = local
	return {"ok": true, "state": state, "text": text}
