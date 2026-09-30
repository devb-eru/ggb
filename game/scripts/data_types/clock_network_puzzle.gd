class_name ClockNetworkPuzzle
extends Resource

const CLOCKS := ["bedroom", "parlor", "library_outer", "great_clock"]
const ROLES := ["reference", "relay", "output", "excluded"]
const SOLUTION := {"reference": "parlor", "relay": "library_outer", "output": "great_clock", "excluded": "bedroom"}
const PHASES := ["-1", "0", "+1", "HALF"]
const NAMES := {"bedroom": "침실", "parlor": "대응접실", "library_outer": "외부 서고", "great_clock": "서쪽 대시계"}
const ROLE_NAMES := {"reference": "기준", "relay": "중계", "output": "출력", "excluded": "제외"}
const CLUES := {
	"bedroom": "선들은 종이 가장자리에 닿기 전에 모두 끊긴다. 이 시계는 느리지만, 더 큰 시계망에는 연결되지 않았다.",
	"parlor": "가운데 선이 다른 시계보다 굵다. 진동은 이곳에서 바깥으로 퍼진다. 열두 번이 끝난 뒤에도 배선에 짧은 떨림이 남는다.",
	"library_outer": "바늘은 멈췄는데 벽 안의 진동은 지나간다. 흑연이 종이 뒷면까지 번졌다. 앞면의 선은 동쪽으로 향한다.",
	"great_clock": "종 대신 빈 공명통으로 선이 모인다. XII 뒤 이름 없는 홈이 한 칸 더 있다. 점검 쪽지에는 '본 종이 끝난 뒤 점검'이라고 적혀 있다.",
}


func default_board() -> Dictionary:
	return {"pieces": ["great_clock", "bedroom", "parlor", "library_outer"], "rotations": [90, 180, 270, 0], "library_back": false}


func inspect_layout(board: Dictionary) -> Dictionary:
	var pieces: Array = board.get("pieces", [])
	var rotations: Array = board.get("rotations", [])
	if pieces.size() != 4 or rotations.size() != 4:
		return {"ok": false, "matched": 0, "reason": "네 탁본과 방향을 모두 확인해야 한다."}
	var matched := 0
	var faults: Array[String] = []
	for index in range(4):
		if String(pieces[index]) != String(SOLUTION[ROLES[index]]):
			faults.append("%d번 자리의 배선이 옆 조각과 이어지지 않는다." % (index + 1))
		elif int(rotations[index]) != 0:
			faults.append("%d번 자리의 모서리 홈과 나사 구멍이 어긋난다." % (index + 1))
		elif pieces[index] == "library_outer" and not bool(board.get("library_back", false)):
			faults.append("외부 서고의 선이 서쪽 공명통이 아닌 동쪽으로 향한다. 뒷면에도 흑연이 묻어 있다.")
		else:
			matched += 1
	return {"ok": matched == 4, "matched": matched, "reason": "\n".join(faults)}


func inspect_roles(roles: Dictionary) -> Dictionary:
	var verified := {}
	var first_error := ""
	for role in ROLES:
		if roles.get(role, "") == SOLUTION[role]:
			verified[role] = roles[role]
		elif first_error.is_empty():
			first_error = role
	var feedback := {
		"reference": "시작 진동이 만들어지지 않는다. 기준 시계의 진동선을 다시 확인한다.",
		"relay": "벽 중간에서 진동이 끊긴다. 바늘의 움직임과 신호 전달은 같은 기능이 아니다.",
		"output": "공명통 대신 종이 울린다. 신호를 만드는 곳과 받아 울리는 곳을 구별한다.",
		"excluded": "연결하지 않아야 할 선이 시계망에 들어가 있다.",
		"": "대시계까지 약한 진동이 도달한다. 이 시험으로 전달 시점은 확인할 수 없다.",
	}
	return {"ok": first_error.is_empty(), "verified": verified, "category": first_error, "text": feedback[first_error]}


func activate(roles: Dictionary, phase: String) -> Dictionary:
	var result := inspect_roles(roles)
	if not bool(result["ok"]):
		return result
	var phases := {
		"-1": ["phase_too_early", "너무 이른 금속음. 정상 종이 끝나기 전에 전달이 시작됐다."],
		"0": ["phase_simultaneous", "열두 번째 종과 겹쳤다. 끝난 뒤의 빈 칸은 울리지 않았다."],
		"HALF": ["phase_between", "종 사이로 불완전한 진동이 새어 나왔다."],
	}
	if phase != "+1":
		var failure: Array = phases.get(phase, ["phase_unset", "전달 시점을 설정하지 않았다."])
		result.merge({"ok": false, "category": failure[0], "text": failure[1]}, true)
	else:
		result["text"] = "대응접실의 열두 번이 끝난다. 외부 서고 벽을 지난 진동이 한 칸 늦게 도착하고, 서쪽 공명통에서 열세 번째 금속음이 울린다."
	return result
