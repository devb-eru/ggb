extends CanvasLayer

# Hosts own the open session. This layer keeps only the mounted controls.
const OVERLAY := preload("res://scenes/ui/notebook/notebook_overlay.tscn")
const NODE_NAME := &"NotebookScreen"

var overlay: Control
var panel: Control
var loading: VBoxContainer
var _host: Node
var _connections: Array = []
var _loading_theme: Theme
var _loading_font_sizes: Dictionary = {}


static func for_owner(owner: Control) -> CanvasLayer:
	var shared := owner.get_parent().get_node_or_null(NodePath(NODE_NAME))
	if shared != null:
		return shared
	var local := owner.get_node_or_null(NodePath(NODE_NAME))
	if local != null:
		return local
	# Standalone controllers have no bootstrap to mount the screen for them.
	var screen: CanvasLayer = load("res://scripts/ui/notebook_screen.gd").new()
	owner.add_child(screen)
	return screen


func _ready() -> void:
	name = NODE_NAME
	layer = 40
	process_mode = Node.PROCESS_MODE_DISABLED
	overlay = OVERLAY.instantiate()
	overlay.hide()
	add_child(overlay)
	panel = overlay.get_node("Margin/IntegratedNotebook")
	loading = overlay.get_node("Margin/NotebookLoading")
	_loading_theme = loading.theme
	for child in loading.get_children():
		if child is Control:
			_loading_font_sizes[child] = {
				"size": child.get_theme_font_size("font_size"),
				"override": child.has_theme_font_size_override("font_size"),
			}


func acquire(host: Node) -> bool:
	if is_instance_valid(_host):
		return false
	_host = host
	process_mode = Node.PROCESS_MODE_PAUSABLE
	panel.hide()
	loading.hide()
	loading.get_node("NotebookLoadingRetry").hide()
	return true


func connect_for_host(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append([event, callback])


func loading_font_size(control: Control) -> int:
	return _loading_font_sizes[control].size


func release(host: Node) -> void:
	if _host != host:
		return
	for binding in _connections:
		binding[0].disconnect(binding[1])
	_connections.clear()
	overlay.hide()
	panel.dismiss()
	loading.hide()
	loading.theme = _loading_theme
	for child in _loading_font_sizes:
		var font: Dictionary = _loading_font_sizes[child]
		if font.override:
			child.add_theme_font_size_override("font_size", font.size)
		elif child.has_theme_font_size_override("font_size"):
			child.remove_theme_font_size_override("font_size")
	process_mode = Node.PROCESS_MODE_DISABLED
	_host = null
