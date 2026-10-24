extends RefCounted

static func location(id: String, locale: String) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/discovered_map.json"))
	var room: Dictionary = data.rooms.get(id, {})
	if not room.is_empty(): return room.get("en" if locale.begins_with("en") else "ko", id)
	return "Saved progress" if locale.begins_with("en") else "저장된 진행"

static func date(timestamp: int) -> String:
	if timestamp <= 0: return ""
	var local := Time.get_datetime_dict_from_unix_time(timestamp + int(Time.get_time_zone_from_system().bias) * 60)
	return "%04d.%02d.%02d · %02d:%02d" % [local.year, local.month, local.day, local.hour, local.minute]

static func duration(seconds: Variant) -> String:
	if not seconds is int and not seconds is float: return ""
	if seconds < 0: return ""
	var total := int(seconds)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
