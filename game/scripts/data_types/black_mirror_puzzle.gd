class_name BlackMirrorPuzzle
extends Resource

const MATERIALS := ["water", "stabilizer", "active"]
const MATERIAL_NAMES := {"water": "증류수", "stabilizer": "안정제", "active": "원액"}
const PATH := ["entry", "short_branch", "long_branch", "clockwise_ring"]
const SEGMENTS := ["entry", "short_branch", "long_branch", "clockwise_ring", "counterclockwise_ring"]
const SEGMENT_NAMES := {"entry": "직선 진입", "short_branch": "짧은 분기", "long_branch": "긴 분기", "clockwise_ring": "고리 시계 방향", "counterclockwise_ring": "고리 반시계 방향"}

func empty_mixture() -> Dictionary:
	return {"water": 0, "stabilizer": 0, "active": 0, "order": [], "dispersed": false, "mixed": 0, "foamy": false}


func test_mixture(mix: Dictionary) -> Dictionary:
	var total := int(mix["water"]) + int(mix["stabilizer"]) + int(mix["active"])
	if total != 8:
		return {"ok": false, "text": "눈금이 8단위에 맞지 않는다. 폐기 쟁반에서 비우고 다시 계량한다."}
	if mix["water"] != 5 or mix["stabilizer"] != 1 or mix["active"] != 2:
		return {"ok": false, "text": "시험지: 중성 아님 · 빗금 문양. 첨가제 사이의 비율과 물의 양을 다시 비교한다."}
	if mix["order"] != MATERIALS or not mix["dispersed"]:
		return {"ok": false, "text": "작은 결정이 남는다. 물에서 안정제를 확산시킨 뒤 원액을 넣어야 한다."}
	if int(mix["mixed"]) == 0 or mix["foamy"]:
		return {"ok": false, "text": "혼합 상태가 고르지 않다. 천천히 섞고 거품이 가라앉는지 확인한다."}
	return {"ok": true, "text": "시험지: 중성 · 평행선 문양. 무색의 세정액이 천에 고르게 스며든다."}


func inspect_trace(rotation: int, flipped: bool, anchored: bool, path: Array) -> Dictionary:
	if rotation != 90 or flipped or not anchored:
		return {"ok": false, "category": "anchor_missing", "verified_prefix": [], "text": "큰 파동과 거울 하단 진동점이 겹치지 않는다. 기준점을 먼저 맞춘다."}
	var prefix: Array = []
	for index in range(mini(PATH.size(), path.size())):
		if path[index] != PATH[index]:
			break
		prefix.append(path[index])
	if path == PATH:
		return {"ok": true, "category": "", "verified_prefix": prefix, "text": "긴 진입 진동, 두 갈래 반사, 마지막 잔류파가 끊김 없이 이어진다."}
	var category := "branch_incomplete"
	var text := "분기 한쪽의 반응이 없다. 두 반사 구간을 비교한다."
	if path.is_empty() or path[0] != "entry":
		category = "entry_missing"
		text = "시작 압력이 만들어지지 않는다. 파형의 진입부를 찾는다."
	elif "counterclockwise_ring" in path:
		category = "ring_direction_wrong"
		text = "가장자리의 닫힌 홈이 역방향으로 눌린다."
	elif path.size() >= 3 and (path[1] != "short_branch" or path[2] != "long_branch"):
		category = "branch_order_wrong"
		text = "두 반사압이 역순으로 겹친다."
	return {"ok": false, "category": category, "verified_prefix": prefix, "text": text}
