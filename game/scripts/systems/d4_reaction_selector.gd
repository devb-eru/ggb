class_name D4ReactionSelector
extends RefCounted

const OTHER_PRIORITY := ["mara1", "luca", "iris", "mara2"]
const HIGH_THRESHOLD := 4


static func none() -> Dictionary:
	return {"owner": "", "mode": "none", "bond": 0, "alert": 0}


static func select(state: Dictionary) -> Dictionary:
	var servants: Dictionary = state.get("meta_progress", {}).get("servants", {})
	var edgar: Dictionary = servants.get("edgar", {})
	if int(edgar.get("bond", 0)) >= HIGH_THRESHOLD:
		return _result("edgar", edgar, "bond")

	var selected := none()
	var selected_strength := HIGH_THRESHOLD - 1
	var selected_bond := -1
	for owner in OTHER_PRIORITY:
		var servant: Dictionary = servants.get(owner, {})
		var bond := int(servant.get("bond", 0))
		var alert := int(servant.get("alert", 0))
		var strength := maxi(bond, alert)
		if strength < HIGH_THRESHOLD:
			continue
		if strength > selected_strength or (strength == selected_strength and bond > selected_bond):
			selected = _result(owner, servant, "bond" if bond >= alert else "alert")
			selected_strength = strength
			selected_bond = bond
	return selected


static func _result(owner: String, servant: Dictionary, mode: String) -> Dictionary:
	return {
		"owner": owner.to_upper(),
		"mode": mode,
		"bond": int(servant.get("bond", 0)),
		"alert": int(servant.get("alert", 0)),
	}
