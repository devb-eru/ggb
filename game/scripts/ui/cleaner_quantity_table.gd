extends RefCounted

static func candidates(ratio: bool, water_difference: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for water in range(9):
		for stabilizer in range(9 - water):
			var active := 8 - water - stabilizer
			if ratio and active != 2 * stabilizer:
				continue
			if water_difference and water != stabilizer + active + 2:
				continue
			rows.append({"water": water, "stabilizer": stabilizer, "active": active})
	return rows


static func describe(rows: Array[Dictionary], locale: String) -> String:
	var english := locale.begins_with("en")
	var lines: Array[String] = [
		"W = water; S = stabilizer; A = active solution. All rows total 8 units." if english else "W=물 · S=안정제 · A=원액. 모든 행의 합은 8단위다.",
		("Candidates: %d" if english else "후보: %d개") % rows.size(),
		"This compares quantities only. Pouring order, dispersion, and mixing still matter." if english else "양만 비교하는 표다. 투입 순서·확산·혼합 조건은 별도로 확인해야 한다.",
		"",
	]
	for row in rows:
		lines.append("W %d   |   S %d   |   A %d" % [row.water, row.stabilizer, row.active])
	return "\n".join(lines)
