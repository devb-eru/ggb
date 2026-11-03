extends RefCounted

const ALLOWED := ["EP02_CAP_DIFFUSE", "EP02_CAP_TEST_BAD", "EP02_CAP_TEST_OK", "EP02_CAP_PURPLE", "EP02_CAP_TRACE", "EP02_CAP_HARDEN", "EP02_CAP_OPEN", "EP02_CAP_COLD", "EP02_CAP_TOOL_AMB", "EP02_CAP_J3_OPEN", "EP02_CAP_PENCIL", "EP02_CAP_MIRROR_ENTER", "EP02_CAP_CHEM_LOCK", "EP02_CAP_EDGAR_LINE", "EP02_CAP_WET_START", "EP02_CAP_RESET", "EP02_CAP_FIVE"]


static func decorate(ids: Array, captions: Array, profile: Dictionary) -> Array:
	var pages := ids.duplicate()
	if not profile.get("captions_enabled", true): return pages
	for identity in captions:
		if identity in ALLOWED and identity not in pages: pages.append(identity)
	return pages


static func wet(local: Dictionary) -> Array:
	if local.get("locked", false): return ["EP02_CAP_HARDEN"]
	if local.get("surface_open", false): return ["EP02_CAP_OPEN", "EP02_CAP_COLD"]
	return []
