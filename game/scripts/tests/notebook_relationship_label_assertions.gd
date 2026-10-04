extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const DISPLAY := preload("res://scripts/ui/relationship_display_texts.gd")
const NOTES := {
	"mara1": preload("res://scripts/systems/mara1_notebook.gd"),
	"iris": preload("res://scripts/systems/iris_notebook.gd"),
	"luca": preload("res://scripts/systems/luca_notebook.gd"),
	"edgar": preload("res://scripts/systems/edgar_notebook.gd"),
	"mara2": preload("res://scripts/systems/mara2_notebook.gd"),
}


static func catalog(owners: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	for owner in owners:
		var id: String = NOTES[owner].PREFIX + "SCREEN_COMPLETE"
		var original: String = NOTES[owner].SCREEN.COMPLETE
		for locale in ["ko-KR", "en-US"]:
			var current := CONTENT.presentation(CONTENT.descriptor(id, 2, {"body": {}}), locale)
			if not current.get("ok", false) or current.text != DISPLAY.text(original, locale) or current.text.contains("REC_"):
				errors.append("current completion must match public UI: " + id + ":" + locale)
			var legacy := CONTENT.presentation(CONTENT.descriptor(id, 1, {"body": {}}), locale)
			if not legacy.get("ok", false) or not legacy.text.contains("REC_" + String(owner).to_upper()):
				errors.append("version 1 completion must remain available: " + id + ":" + locale)
			var row := CONTENT.definition(id, 1)
			var context := {"node_id": row.node_ids[0], "chapter_id": "CHAPTER_3", "location_id": "M1_CENTRAL_HALL",
				"event_occurrence_id": ARCHIVE.new_uid(), "conversation_session_id": ARCHIVE.new_uid(), "presentation_token": ARCHIVE.new_uid()}
			var old := CONTENT.observe(CONTENT.descriptor(id, 1, {"body": {}}), context, legacy.speaker, legacy.text, locale)
			if not old.get("ok", false):
				errors.append("old completion fixture must be valid: " + id)
				continue
			var entry: Dictionary = JSON.parse_string(JSON.stringify({"record_class": "authored", "observation": old.observation}))
			var frozen := entry.duplicate(true)
			for target in ["ko-KR", "en-US"]:
				var shown := CONTENT.render_entry(entry, target)
				var expected := CONTENT.presentation(CONTENT.descriptor(id, 1, {"body": {}}), target)
				if not shown.get("ok", false) or shown.entry.fallback or shown.entry.text != expected.speaker + ": " + expected.text:
					errors.append("historical completion cannot be upgraded during replay: " + id + ":" + target)
			if entry != frozen: errors.append("replay mutated the historical observation: " + id)
			if CONTENT.observe(CONTENT.descriptor(id, 1, {"body": {}}), context, current.speaker, current.text, locale).get("ok", false):
				errors.append("new wording must not be recorded as version 1: " + id)
			if live(entry):
				errors.append("current-route assertion accepted a historical completion: " + id)
	return errors


static func live(entry: Dictionary) -> bool:
	var observed: Dictionary = entry.get("observation", {})
	if int(observed.get("content_version", 0)) != 2 or observed.get("segments", []).size() != 1: return false
	for locale in ["ko-KR", "en-US"]:
		var rendered := CONTENT.render_entry(entry, locale)
		if not rendered.get("ok", false) or rendered.entry.fallback or rendered.entry.text.contains("REC_"): return false
	var segment: Dictionary = observed.segments[0]
	var expected := CONTENT.presentation(CONTENT.descriptor(observed.content_id, 2, {"body": {}}), segment.viewed_locale)
	return expected.get("ok", false) and segment.captured_text == expected.text
