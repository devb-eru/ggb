extends Node
## Optional display data. Never changes, blocks or repairs gameplay saves.
const PREVIEW_SIZE := Vector2i(560, 252)
const CAPTURE_QUIET_MS := 1200
const PREVIEW_CHECKPOINTS := ["SAVE_NORMAL_RESET_COMPLETE", "SAVE_BROKEN_RESET_COMPLETE", "SAVE_ENDING_COMPLETE"]

var _saves: Node
var _view: WeakRef
var _slot := ""
var _root := ""
var _run_id := ""
var _seconds := 0.0
var _summary: Dictionary = {}
var _committed_seconds := 0.0
var _metadata_dirty := false
var _thumbnail_identity := ""
var _capture_requested := false
var _capture_after := 0
var _session := 0
var _image_worker: Thread
var _image_session := -1
var _image_identity := ""

func configure(saves: Node) -> void:
	_saves = saves
	saves.save_display_committed.connect(_on_committed)
	RenderingServer.frame_post_draw.connect(_capture_pending)

func begin_session(slot: String, view: Control) -> void:
	_flush_metadata()
	var summary: Dictionary = _saves.inspect_slot(slot)
	var save_root: String = _saves.get_save_root()
	var same_run: bool = _slot == slot and _root == save_root and _run_id == summary.get("run_id", "")
	var handoff: bool = same_run and _view != null and _view.get_ref() != view
	var previous := _read_metadata(save_root, summary)
	_session += 1
	_slot = slot
	_root = save_root
	_run_id = summary.get("run_id", "")
	_view = weakref(view)
	if not same_run: _seconds = float(previous.get("play_seconds", 0.0))
	_summary = summary if _valid(summary) else {}
	_thumbnail_identity = previous.get("thumbnail_identity", "")
	if not _thumbnail_identity.is_empty() and not FileAccess.file_exists(_thumbnail_path(_root.path_join(_slot), _thumbnail_identity)):
		_thumbnail_identity = ""
	_committed_seconds = _seconds
	_metadata_dirty = not _summary.is_empty()
	_capture_requested = false
	if not _summary.is_empty() and (_thumbnail_identity.is_empty() or handoff):
		_request_capture()

func end_session() -> void:
	_flush_metadata()
	_session += 1
	_slot = ""
	_run_id = ""
	_view = null
	_summary = {}
	_thumbnail_identity = ""
	_capture_requested = false

func _process(delta: float) -> void:
	_collect_image()
	_flush_metadata()
	var view = _view.get_ref() if _view != null else null
	if is_instance_valid(view) and view.is_visible_in_tree() and get_window().has_focus() and not get_tree().paused:
		_seconds += delta

func _on_committed(root: String, summary: Dictionary) -> void:
	if summary.get("slot_id") != _slot or root != _root or _view == null or not _valid(summary): return
	if summary.get("run_id", "") != _run_id:
		# An overwrite retires the previous session before the new scene is ready.
		_summary = {}
		_metadata_dirty = false
		_capture_requested = false
		_session += 1
		return
	var point: String = summary.get("save_point_id", "")
	if point in PREVIEW_CHECKPOINTS and (point != _summary.get("save_point_id") or summary.get("day_index") != _summary.get("day_index")):
		_request_capture()
	_summary = summary
	_committed_seconds = _seconds
	_metadata_dirty = true
	if _capture_requested:
		_capture_after = Time.get_ticks_msec() + CAPTURE_QUIET_MS

func _request_capture() -> void:
	_capture_requested = true
	_capture_after = Time.get_ticks_msec() + CAPTURE_QUIET_MS

func _flush_metadata() -> void:
	if not _metadata_dirty: return
	_metadata_dirty = false
	if is_instance_valid(_saves) and _root == _saves.get_save_root():
		_write_metadata(_root, _summary, _committed_seconds, _thumbnail_identity)

func _capture_pending() -> void:
	if not _capture_requested or _image_worker != null or _summary.is_empty() or Time.get_ticks_msec() < _capture_after: return
	var view = _view.get_ref() if _view != null else null
	if not is_instance_valid(view) or view.is_queued_for_deletion() or not view.is_visible_in_tree() or _root != _saves.get_save_root(): return
	if get_tree().paused or not get_window().has_focus() or (view.has_method("can_capture_save_preview") and not view.can_capture_save_preview()): return
	# Only the occasional framebuffer readback needs the rendering thread.
	_capture_requested = false
	var image: Image = view.get_viewport().get_texture().get_image()
	if image == null or image.is_empty(): return
	var worker := Thread.new()
	if worker.start(_encode_preview.bind(image), Thread.PRIORITY_LOW) != OK: return
	_image_worker = worker
	_image_identity = _summary.save_identity
	_image_session = _session

func _collect_image() -> void:
	if _image_worker == null or _image_worker.is_alive(): return
	var png: PackedByteArray = _image_worker.wait_to_finish()
	_image_worker = null
	if png.is_empty() or _image_session != _session or _summary.is_empty() or _root != _saves.get_save_root(): return
	# Recheck the slot before publishing an image prepared across frames.
	var current: Dictionary = _saves.inspect_slot(_slot)
	if current.get("save_identity") != _summary.save_identity or current.get("run_id") != _run_id: return
	var folder := _root.path_join(_slot)
	if not _write_file(_thumbnail_path(folder, _image_identity), png): return
	if not _write_metadata(_root, _summary, _committed_seconds, _image_identity): return
	_thumbnail_identity = _image_identity
	_metadata_dirty = false
	var kept := _thumbnail_path(folder, _image_identity).get_file()
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("thumbnail_") and name.ends_with(".png") and name != kept and name.length() == kept.length():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))

func _exit_tree() -> void:
	_flush_metadata()
	if _image_worker != null:
		_image_worker.wait_to_finish()
		_image_worker = null

static func _encode_preview(image: Image) -> PackedByteArray:
	var crop := Vector2(image.get_size())
	var aspect := float(PREVIEW_SIZE.x) / PREVIEW_SIZE.y
	if crop.x / crop.y > aspect: crop.x = crop.y * aspect
	else: crop.y = crop.x / aspect
	image = image.get_region(Rect2i((Vector2(image.get_size()) - crop) * 0.5, crop))
	image.resize(PREVIEW_SIZE.x, PREVIEW_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return image.save_png_to_buffer()

static func _valid(summary: Dictionary) -> bool:
	var slot: String = summary.get("slot_id", "")
	var identity: String = summary.get("save_identity", "")
	return summary.get("available", false) and slot.is_valid_filename() and not slot.contains("/") and not slot.contains("\\") and _valid_identity(identity)

static func _valid_identity(identity: String) -> bool:
	return identity.length() == 64 and identity.is_valid_hex_number()

static func _thumbnail_path(folder: String, identity: String) -> String:
	return folder.path_join("thumbnail_" + identity.left(16) + ".png")

static func _read_metadata(root: String, summary: Dictionary) -> Dictionary:
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
	# Older sidecars used the current save identity for both files.
	var identity: Variant = data.get("thumbnail_identity", summary.save_identity)
	return {"play_seconds": seconds, "thumbnail_identity": identity if identity is String and _valid_identity(identity) else ""}

static func read(root: String, summary: Dictionary) -> Dictionary:
	var metadata := _read_metadata(root, summary)
	if metadata.is_empty(): return {}
	var result := {"play_seconds": metadata.play_seconds}
	if not String(metadata.thumbnail_identity).is_empty():
		var thumbnail := _thumbnail_path(root.path_join(summary.slot_id), metadata.thumbnail_identity)
		if FileAccess.file_exists(thumbnail):
			var image := Image.load_from_file(thumbnail)
			if image != null and not image.is_empty(): result.thumbnail = ImageTexture.create_from_image(image)
	return result

static func write(root: String, summary: Dictionary, seconds: float) -> bool:
	return _write_metadata(root, summary, seconds, _read_metadata(root, summary).get("thumbnail_identity", ""))

static func _write_metadata(root: String, summary: Dictionary, seconds: float, thumbnail_identity: String) -> bool:
	if not _valid(summary) or not is_finite(seconds) or seconds < 0: return false
	var folder := root.path_join(summary.slot_id)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)): return false
	var data := {"save_identity": summary.save_identity, "run_id": summary.get("run_id", ""), "play_seconds": seconds, "thumbnail_identity": thumbnail_identity}
	return _write_file(folder.path_join("presentation.json"), JSON.stringify(data).to_utf8_buffer())

static func _write_file(path: String, bytes: PackedByteArray) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	var temporary_path := ProjectSettings.globalize_path(temporary)
	if error == OK and DirAccess.rename_absolute(temporary_path, ProjectSettings.globalize_path(path)) == OK: return true
	DirAccess.remove_absolute(temporary_path)
	return false
