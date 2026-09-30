extends Node

# Streams are supplied by the asset intake layer; missing audio never gates play.
const CHANNELS := [&"BGM", &"AMB", &"SFX"]
const MAX_EFFECTS := 26
var _voices: Dictionary = {}
var _levels := {&"BGM": 1.0, &"AMB": 1.0, &"SFX": 1.0}
var _pause_reasons: Dictionary = {}
var _master := 1.0
var _muted := false
var _catalog: Dictionary = {}
var _room_id := ""
const CATALOG_PATH := "res://data/registries/audio_cue_registry.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_catalog(CATALOG_PATH)


func load_catalog(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema_version") != 1 or not value.get("cues") is Array:
		return false
	var next: Dictionary = {}
	for entry: Variant in value.cues:
		if not entry is Dictionary:
			return false
		var id: Variant = entry.get("asset_id")
		if not id is String or id.is_empty() or next.has(id):
			return false
		if entry.get("channel") not in ["BGM", "AMB", "SFX"] or not entry.get("resource_path") is String:
			return false
		if entry.get("status") not in ["PLANNED", "APPROVED"]:
			return false
		next[id] = entry.duplicate(true)
	_catalog = next
	return true


func request_cue(cue_id: StringName) -> bool:
	var entry: Dictionary = _catalog.get(String(cue_id), {})
	if entry.get("status") != "APPROVED":
		return false
	var path: String = entry.get("resource_path", "")
	if not path.begins_with("res://assets/") or not ResourceLoader.exists(path, "AudioStream"):
		return false
	var stream := ResourceLoader.load(path) as AudioStream
	return play_cue(cue_id, stream, StringName(entry.channel))


func enter_room(room_id: String) -> void:
	if room_id == _room_id:
		return
	_room_id = room_id
	# Never carry the previous room's ambience into an unvoiced room.
	for id: StringName in _voices.keys():
		if _voices[id].channel == &"AMB":
			stop_cue(id)
	request_cue(StringName("AUD_AMB_" + room_id))


func play_cue(cue_id: StringName, stream: AudioStream, channel: StringName) -> bool:
	if cue_id == &"" or stream == null or channel not in CHANNELS:
		return false
	if _voices.has(cue_id):
		return false
	if channel == &"SFX":
		var count := 0
		for voice: Dictionary in _voices.values():
			if voice.channel == &"SFX":
				count += 1
		if count >= MAX_EFFECTS:
			return false
	else:
		for id: StringName in _voices.keys():
			if _voices[id].channel == channel:
				stop_cue(id)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _volume_db(channel)
	add_child(player)
	_voices[cue_id] = {"player": player, "channel": channel}
	player.finished.connect(stop_cue.bind(cue_id), CONNECT_ONE_SHOT)
	player.play()
	player.stream_paused = not _pause_reasons.is_empty()
	return true


func stop_cue(cue_id: StringName) -> void:
	if not _voices.has(cue_id):
		return
	var player: AudioStreamPlayer = _voices[cue_id].player
	_voices.erase(cue_id)
	player.stop()
	player.queue_free()


func stop_all() -> void:
	_room_id = ""
	for id: StringName in _voices.keys():
		stop_cue(id)


func set_pause_reason(reason: StringName, paused: bool) -> void:
	if paused:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	for voice: Dictionary in _voices.values():
		voice.player.stream_paused = not _pause_reasons.is_empty()


func set_levels(master: float, bgm: float, ambience: float, effects: float, muted: bool) -> bool:
	for value: float in [master, bgm, ambience, effects]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return false
	_master = master
	_levels = {&"BGM": bgm, &"AMB": ambience, &"SFX": effects}
	_muted = muted
	for voice: Dictionary in _voices.values():
		voice.player.volume_db = _volume_db(voice.channel)
	return true


func _volume_db(channel: StringName) -> float:
	var level: float = 0.0 if _muted else _master * float(_levels[channel])
	return linear_to_db(level) if level > 0.0 else -INF
