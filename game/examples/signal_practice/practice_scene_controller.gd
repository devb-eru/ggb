extends Node2D

@export_node_path("Button") var next_button_path: NodePath
@export_node_path("Button") var previous_button_path: NodePath
@export_node_path("Sprite2D") var background_path: NodePath
@export_node_path("Node") var inventory_path: NodePath
@export_node_path("Button") var drawer_path: NodePath
@export_node_path("Button") var key_path: NodePath
@export_node_path("Sprite2D") var lock_path: NodePath

@onready var _next_button: Button = get_node(next_button_path)
@onready var _previous_button: Button = get_node(previous_button_path)
@onready var _background: PracticeBackground = get_node(background_path)
@onready var _inventory: PracticeInventory = get_node(inventory_path)
@onready var _drawer: PracticeDrawer = get_node(drawer_path)
@onready var _key: PracticeKey = get_node(key_path)
@onready var _lock: PracticeLock = get_node(lock_path)


func _ready() -> void:
	_next_button.pressed.connect(_background.next_page)
	_previous_button.pressed.connect(_background.previous_page)
	_background.background_number.connect(_apply_background_snapshot)
	_drawer.pressed.connect(_on_drawer_pressed)
	_drawer.drawer_state_changed.connect(_on_drawer_state_changed)
	_key.pressed.connect(_on_key_pressed)
	_apply_background_snapshot(_background.background_index)


func _apply_background_snapshot(background_index: int) -> void:
	_drawer.apply_background(background_index)
	_key.apply_snapshot(background_index, _drawer.is_open())
	_lock.apply_background(background_index)


func _on_drawer_pressed() -> void:
	_drawer.toggle()


func _on_drawer_state_changed(is_open: bool) -> void:
	_key.set_drawer_open(is_open)


func _on_key_pressed() -> void:
	_key.acquire(_inventory)
