extends Control

signal confirm_requested(slot_id: String)
signal back_requested
signal selection_changed(slot_id: String)

@export_enum("new", "load") var mode := "new"
@onready var title_label: Label = $Content/Title
@onready var confirm_button: Button = $Content/Confirm
@onready var back_button: Button = $Content/Back
@onready var close_button: Button = $Content/Close
@onready var rows: Array[Button] = [$Content/RowsScroll/Rows/Slot1, $Content/RowsScroll/Rows/Slot2, $Content/RowsScroll/Rows/Slot3]
var selected_slot_id := ""
var _selected_row: Button
var _fonts: Dictionary = {}
var _heights: Dictionary = {}

func _ready() -> void:
	if mode == "load": rows.push_front($Content/RowsScroll/Rows/Autosave)
	for row in rows:
		row.pressed.connect(select_row.bind(row))
		row.focus_entered.connect(select_row.bind(row))
		_heights[row] = row.custom_minimum_size.y
	for control in find_children("*", "Control", true, false):
		if control is Label or control is Button: _fonts[control] = control.get_theme_font_size("font_size")
	confirm_button.pressed.connect(func():
		if not selected_slot_id.is_empty(): confirm_requested.emit(selected_slot_id)
	)
	back_button.pressed.connect(func(): back_requested.emit())
	close_button.pressed.connect(func(): back_requested.emit())

func present(summaries: Dictionary, latest: String, locale: String, text_scale: float, reset_selection: bool = true) -> void:
	var english := locale.begins_with("en")
	title_label.text = ("New Game" if mode == "new" else "Load Game") if english else ("새 게임" if mode == "new" else "불러오기")
	confirm_button.text = ("Start" if mode == "new" else "Load") if english else ("시작하기" if mode == "new" else "불러오기")
	back_button.text = "Back" if english else "뒤로"
	close_button.tooltip_text = "Close" if english else "닫기"
	for control in _fonts: control.add_theme_font_size_override("font_size", roundi(_fonts[control] * text_scale))
	title_label.add_theme_font_size_override("font_size", roundi(_fonts[title_label] * minf(text_scale, 1.3)))
	for row in rows:
		var id: String = latest if row.autosave else row.slot_id
		if row.autosave: row.slot_id = id
		var value: Dictionary = summaries.get(id, {})
		row.show_summary(value, locale)
		row.disabled = mode == "load" and not value.get("available", false)
		row.custom_minimum_size.y = _heights[row] + 180 * (text_scale - 1)
	if reset_selection or not is_instance_valid(_selected_row) or _selected_row.disabled:
		_selected_row = null
		for row in rows:
			if not row.disabled:
				select_row(row)
				break
	else: select_row(_selected_row)
	if _selected_row == null:
		selected_slot_id = ""
		confirm_button.disabled = true
		for row in rows: row.selected = false

func select_row(row: Button) -> void:
	if row.disabled: return
	_selected_row = row
	selected_slot_id = row.slot_id
	for item in rows: item.selected = item == row
	confirm_button.disabled = selected_slot_id.is_empty()
	selection_changed.emit(selected_slot_id)

func initial_focus() -> Control:
	return _selected_row if _selected_row != null else back_button
