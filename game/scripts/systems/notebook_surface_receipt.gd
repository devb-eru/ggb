extends RefCounted

const KEY := "NOTEBOOK_SURFACE_RECEIPT"
const MAX_RECEIPTS := 512


static func stable_scope(scope: Dictionary) -> Dictionary:
	var value := scope.duplicate(true)
	for field in ["session", "load_epoch", "view_slot"]: value.erase(field)
	return value


static func read(state: Dictionary, scope: Dictionary) -> Dictionary:
	var value: Variant = state.get("loop_state", {}).get("event_local_states", {}).get(KEY, {})
	if not valid(value) or JSON.stringify(_canonical(value.scope), "", true) != JSON.stringify(_canonical(stable_scope(scope)), "", true): return {}
	var archive: Dictionary = state.get("meta_progress", {}).get("dialogue_history", {})
	if value.scope.origin != archive.get("source_origin_id") or value.scope.branch != archive.get("branch_id"): return {}
	return value.duplicate(true)


static func fingerprint(request: Dictionary) -> String:
	var context: Dictionary = request.context
	var value := [context.notebook_content, request.text, request.locale, request.speaker,
		context.get("node_id"), context.get("chapter_id"), context.get("location_id")]
	return JSON.stringify(_canonical(value), "", true).sha256_text()


static func identity(context: Dictionary) -> Dictionary:
	return {"presentation_token": context.presentation_token, "event_occurrence_id": context.event_occurrence_id,
		"conversation_session_id": context.conversation_session_id}


static func install(state: Dictionary, receipt: Dictionary, context: Dictionary) -> bool:
	if not _keys(receipt, ["scope", "occurrence", "conversation", "key", "identity", "keep"]) or not _hex(receipt.key, 64): return false
	if not receipt.keep is Array or receipt.keep.size() > MAX_RECEIPTS or not receipt.keep.all(func(key: Variant) -> bool: return _hex(key, 64)): return false
	var value := {"schema_version": 1, "scope": receipt.scope, "occurrence": receipt.occurrence,
		"conversation": receipt.conversation, "receipts": {receipt.key: receipt.identity}}
	if not valid(value) or receipt.identity != identity(context): return false
	var archive: Dictionary = state.meta_progress.dialogue_history
	if receipt.scope.origin != archive.get("source_origin_id") or receipt.scope.branch != archive.get("branch_id"): return false
	var old := read(state, receipt.scope)
	if not old.is_empty() and old.occurrence == receipt.occurrence:
		value.receipts = old.receipts
	# Keep the visible batch, not every past value from this visit. Source observations remain intact.
	for key in value.receipts.keys():
		if key not in receipt.keep: value.receipts.erase(key)
	value.receipts.erase(receipt.key)
	value.receipts[receipt.key] = receipt.identity.duplicate(true)
	if value.receipts.size() > MAX_RECEIPTS: return false
	state.loop_state.event_local_states[KEY] = value
	return true


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, ["schema_version", "scope", "occurrence", "conversation", "receipts"]): return false
	if value.schema_version != 1 or value.schema_version is bool or not value.scope is Dictionary or not value.receipts is Dictionary: return false
	if not _hex(value.occurrence, 32) or not _hex(value.conversation, 32) or value.receipts.size() > MAX_RECEIPTS: return false
	var required := ["namespace", "slot", "origin", "branch", "location", "node", "day"]
	for field in required:
		if not value.scope.has(field): return false
	for field in value.scope:
		if field not in required and field != "ending_node": return false
		if field == "day":
			if not (value.scope[field] is int or value.scope[field] is float) or not is_finite(float(value.scope[field])) or value.scope[field] < 0 or value.scope[field] != floor(float(value.scope[field])): return false
		elif not value.scope[field] is String or value.scope[field].is_empty() or value.scope[field].length() > 256: return false
	for field in ["origin", "branch"]:
		if not _hex(value.scope[field], 32): return false
	for key in value.receipts:
		if not _hex(key, 64) or not value.receipts[key] is Dictionary or not _keys(value.receipts[key], ["presentation_token", "event_occurrence_id", "conversation_session_id"]): return false
		for token in value.receipts[key].values():
			if not _hex(token, 32): return false
	return true


static func _keys(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and fields.all(func(field: String) -> bool: return value.has(field))


static func _hex(value: Variant, length: int) -> bool:
	return value is String and value.length() == length and value.is_valid_hex_number(false)


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _canonical(value[key])
		return result
	if value is Array: return value.map(func(item: Variant) -> Variant: return _canonical(item))
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0: return int(value)
	return value
