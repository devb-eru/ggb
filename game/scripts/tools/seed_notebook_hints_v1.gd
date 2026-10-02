extends SceneTree

# One-time version seed. Existing semantic versions must never be regenerated in place.
const OUTPUT := "res://data/notebook/hints_v1.json"
const PROVIDERS := [
	preload("res://scripts/ui/clock_hint_texts.gd"),
	preload("res://scripts/ui/mirror_hint_texts.gd"),
	preload("res://scripts/ui/basement_hint_texts.gd"),
	preload("res://scripts/ui/core_hint_texts.gd"),
]
const TITLES := {
	"B3_A": ["시계망 배선", "Clock wiring"], "B3_B": ["시계 역할과 위상", "Clock roles and phase"],
	"C3": ["거울 세정제", "Mirror solution"], "C4": ["검은 거울", "Black mirror"],
	"D0_A": ["저택 도면", "Mansion plan"], "D1": ["지하창고 축", "Basement axes"], "D4": ["태엽 심장", "Clockwork heart"],
	"F0_A": ["깨진 방 연결", "Broken room connections"], "F0_B": ["유지 신호 표본", "Maintenance samples"],
	"F0_C": ["세 기록 중첩", "Three-record overlay"], "F0_D": ["기록의 역할", "Record roles"], "F0_E": ["과거와 현재 인증", "Past and present authentication"],
}
const EVENTS := {"B3_A": "B3", "B3_B": "B3", "D0_A": "D0", "F0_A": "F0", "F0_B": "F0", "F0_C": "F0", "F0_D": "F0", "F0_E": "F0"}
const ALIASES := {"B3_B": "BF", "C4": "CF", "D1": "DF"}


func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite a frozen notebook content version.")
		quit(1)
		return
	var document := {"format_version": 1, "contents": {}}
	for provider in PROVIDERS:
		for stage in provider.HINTS:
			for level in range(5):
				var id := "NB_HINT_%s_H%d" % [stage, level + 1]
				var nodes: Array = [stage]
				if ALIASES.has(stage): nodes.append(ALIASES[stage])
				var localized := {}
				for index in range(2):
					var locale: String = ["ko-KR", "en-US"][index]
					localized[locale] = {"title": TITLES[stage][index] + " · H%d" % (level + 1), "summary": "직접 요청한 도움말" if index == 0 else "A hint you requested", "speaker": "주인공" if index == 0 else "Protagonist", "body": provider.HINTS[stage][level][index]}
				document.contents[id] = {"1": {
					"producer_id": "NP20", "source_file": "scripts/chapters/chapter_one_controller.gd", "source_symbol": "_read_clock_hint",
					"text_source": provider.resource_path, "text_key": "%s:%d" % [stage, level],
					"event_id": EVENTS.get(stage, stage), "node_ids": nodes, "action_or_variant": "requested_H%d" % (level + 1),
					"speaker_id": "SUBJECT", "location_source": "session.history_context:loop_state.location_id",
					"entry_kind": "hint_revealed", "disclosure_owner": "_read_clock_hint:explicit_request_then_display",
					"visible_segment_ids": ["body"], "knowledge_ref": "", "protection_reasons": ["hint"],
					"localization_key": id + "_BODY", "mapping_status": "AUTHORED_ID", "owner": "development/content",
					"localization_keys": {"body": id + "_BODY"}, "variables": {"body": {}}, "locales": localized,
				}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create notebook seed.")
		quit(1)
		return
	file.store_string(JSON.stringify(document, "\t", true) + "\n")
	file.close()
	print("NOTEBOOK_HINT_SEED: ", document.contents.size(), " authored content IDs")
	quit()
