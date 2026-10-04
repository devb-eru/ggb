extends RefCounted

const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")


static func create() -> Dictionary:
	var archive := ARCHIVE.create()
	archive.source_origin_id = "%032x" % 90001
	archive.branch_id = "%032x" % 90002
	# 2,001 ordinary entries and three protected entries. Only entry 0 is excess.
	for index in range(2004):
		var protected: bool = index in [1, 2, 3]
		var observed := {
			"producer_id":"TEST_ONLY", "event_id":"B4", "node_id":"B4_OBSERVE", "location_id":"M1_LIBRARY_INNER", "chapter_id":"CHAPTER_1",
			"event_occurrence_id":"%032x" % (index + 1), "conversation_session_id":"%032x" % (index + 1), "presentation_token":"%032x" % (index + 1),
			"entry_kind":"dialogue", "content_id":"TEST_RETENTION", "content_version":1, "variant_id":"observed", "speaker_id":"PROTAGONIST",
			"segments":[{"segment_id":"body", "disclosure":"displayed", "localization_key":"TEST_RETENTION_BODY", "safe_variables":{}, "captured_text":"Retained line %d" % index, "viewed_locale":"en-US"}],
			"content_protection":["journal"] if protected else [],
		}
		if index in [1, 2, 3, 4, 5]:
			observed.event_occurrence_id = "%032x" % (99 if index == 3 else 1)
			observed.conversation_session_id = "%032x" % (99 if index == 5 else 1)
		archive.entries.append({"entry_uid":"%032x" % (index + 1), "source_origin_id":"%032x" % (90003 if index == 2 else 90001), "sequence":index, "record_class":"authored", "observation":observed, "protection_reasons":["content:journal"] if protected else []})
	archive.next_sequence = archive.entries.size()
	return archive
