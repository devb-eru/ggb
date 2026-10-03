extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const PREFIX := "NB_PROLOGUE_SURFACE_"
const NODES := ["P1", "P2", "P3", "P3B", "P4", "PF", "P5", "P6"]
const FIXED := [
	"P1_LABEL_BED", "P1_LABEL_WINDOW", "P1_LABEL_PHOTO", "P1_LABEL_NOTEBOOK", "PF_PARLOR", "PF_LIBRARY", "P6_NIGHT_WINDOW",
	"P2_TOOL_CLOTH", "P2_TOOL_BRUSH", "P2_TOOL_WATER", "P2_TOOL_SPANNER", "P2_CLOCK_LABEL",
	"P3_NAME_BOOK_MECHANICAL", "P3_NAME_BOOK_FLORA", "P3_NAME_BOOK_LEDGER", "P3_SHELF_CLOCK", "P3_SHELF_FLOWER", "P3_SHELF_CUP", "P3_INNER_DOOR", "P3_WRONG", "P3_SILENT_STATUS",
	"P3B_EDGAR", "P3B_MARA1", "P3B_LUCA", "P3B_IRIS", "P3B_MARA2",
	"P4_TEA_ITEM_CUP", "P4_TEA_ITEM_HOT_WATER", "P4_TEA_ITEM_TEA_LEAVES", "P4_TEA_ITEM_SPOON", "P4_TEA_ITEM_TIMER", "P4_TEA_ITEM_TEAPOT",
]
# BOTTOM_ALREADY is unreachable: the clean-window guard returns ALREADY first.
const WINDOW_FEEDBACK := ["P2_TOOL_ALREADY", "P2_TOOL_SPANNER_FEEDBACK", "P2_TOOL_BRUSH_FEEDBACK", "P2_TOOL_WATER_STAIN", "P2_TOOL_WATER_BOTTOM", "P2_TOOL_WATER_WRONG", "P2_TOOL_TOP_CLEAN", "P2_TOOL_MIDDLE_ORDER", "P2_TOOL_MIDDLE_CLEAN", "P2_TOOL_MIDDLE_ALREADY", "P2_TOOL_BOTTOM_ORDER", "P2_TOOL_BOTTOM_CLEAN"]


static func surface(key: String, values: Dictionary = {}) -> Dictionary:
	var row := CONTENT.definition(PREFIX+key,1)
	if row.is_empty(): return {}
	var segments := {}
	for segment in row.visible_segment_ids:
		var variables := {}
		for field in row.variables[segment]:
			if not values.has(field): return {}
			variables[field] = values[field]
		segments[segment] = variables
	return CONTENT.descriptor(PREFIX+key,1,segments)


static func window(index: int, stage: int, state: Dictionary, inline_labels: bool) -> Dictionary:
	return surface("WINDOW_INSPECTION_"+("INLINE" if inline_labels else "MULTILINE"),
		{"index":index+1,"stage":str(stage),
		"top":"P2_SPREAD" if state.dust_spread else ("P2_DUST" if state.top_dust else "P2_CLEAR"),
		"middle":"P2_STAIN" if state.middle_stain else "P2_CLEAR",
		"bottom":"P2_WET" if state.bottom_wet else "P2_DRY"})
