extends Node
## Optional display data. Never changes, blocks or repairs gameplay saves.
var _saves: Node
var _view: WeakRef
var _slot := ""
var _root := ""
var _run_id := ""
var _seconds := 0.0
var _pending: Dictionary = {}

func configure(saves: Node) -> void:
	_saves = saves
	saves.save_completed.connect(_on_saved)
	RenderingServer.frame_post_draw.connect(_capture_pending)

func begin_session(slot: String, view: Control) -> void:
	var summary: Dictionary = _saves.inspect_slot(slot)
	var same_run: bool = _slot == slot and _root == _saves.get_save_root() and _run_id == summary.get("run_id", "")
	_slot = slot
	_root = _saves.get_save_root()
	_run_id = summary.get("run_id", "")
	_view = weakref(view)
	if not same_run: _seconds = float(read(_root, summary).get("play_seconds", 0.0))
	_on_saved(slot, "")

func end_session() -> void:
	_slot = ""
	_run_id = ""
	_view = null
	_pending.clear()

func _process(delta: float) -> void:
	var view = _view.get_ref() if _view != null else null
	if is_instance_valid(view) and view.is_visible_in_tree() and get_window().has_focus() and not get_tree().paused:
		_seconds += delta

func _on_saved(slot: StringName, _point: StringName) -> void:
	if String(slot) != _slot or _root != _saves.get_save_root(): return
	var summary: Dictionary = _saves.inspect_slot(_slot)
	if not summary.get("available", false): return
	write(_root, summary, _seconds)
	_pending = summary

func _capture_pending() -> void:
	if _pending.is_empty(): return
	var summary := _pending
	_pending = {}
	var view = _view.get_ref() if _view != null else null
	if not is_instance_valid(view) or not view.is_visible_in_tree() or _root != _saves.get_save_root(): return
	var current: Dictionary = _saves.inspect_slot(_slot)
	if current.get("save_identity") != summary.get("save_identity"): return
	var image: Image = view.get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): return
	# Framebuffer is copied after the committed state has rendered, never from title UI.
	var crop := Vector2(image.get_size())
	var aspect := 560.0 / 252.0
	if crop.x / crop.y > aspect: crop.x = crop.y * aspect
	else: crop.y = crop.x / aspect
	image = image.get_region(Rect2i((Vector2(image.get_size()) - crop) * 0.5, crop))
	image.resize(560, 252, Image.INTERPOLATE_LANCZOS)
	write(_root, summary, _seconds, image)

static func _valid(summary: Dictionary) -> bool:
	var slot: String = summary.get("slot_id", "")
	var identity: String = summary.get("save_identity", "")
	return summary.get("available", false) and slot.is_valid_filename() and not slot.contains("/") and not slot.contains("\\") and identity.length() == 64 and identity.is_valid_hex_number()

static func read(root: String, summary: Dictionary) -> Dictionary:
	if not _valid(summary): return {}
	var folder := root.path_join(summary.slot_id)
	var path := folder.path_join("presentation.json")
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096: return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("save_identity") != summary.save_identity or data.get("run_id") != summary.get("run_id"): return {}
	var seconds: Variant = data.get("play_seconds")
	if not (seconds is int or seconds is float) or not is_finite(seconds) or seconds < 0: return {}
	var result := {"play_seconds": seconds}
	var thumbnail := folder.path_join("thumbnail_" + String(summary.save_identity).left(16) + ".png")
	if FileAccess.file_exists(thumbnail):
		var image := Image.load_from_file(thumbnail)
		if image != null and not image.is_empty(): result.thumbnail = ImageTexture.create_from_image(image)
	return result

static func write(root: String, summary: Dictionary, seconds: float, image: Image = null) -> bool:
	if not _valid(summary) or not is_finite(seconds) or seconds < 0: return false
	var folder := root.path_join(summary.slot_id)
	# A presentation record may only accompany an already committed slot.
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)): return false
	var image_name := "thumbnail_" + String(summary.save_identity).left(16) + ".png"
	if image != null and image.save_png(folder.path_join(image_name)) != OK: return false
	var data := {"save_identity": summary.save_identity, "run_id": summary.get("run_id", ""), "play_seconds": seconds}
	var path := folder.path_join("presentation.json")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK: return false
	if image != null:
		# Bound optional image storage to the current committed thumbnail.
		for name in DirAccess.get_files_at(folder):
			if name.begins_with("thumbnail_") and name.ends_with(".png") and name != image_name and name.length() == image_name.length():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	return true
