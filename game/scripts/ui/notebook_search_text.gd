extends RichTextLabel

var source_text := ""
var matches: Array = []


func configure(value: String, ranges: Array) -> void:
	source_text = value
	matches = ranges.duplicate(true)
	bbcode_enabled = false
	fit_content = true
	scroll_active = false
	threaded = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark(-1, 0)


func mark(offset: int, length: int) -> void:
	text = ""
	var cursor := 0
	for item in matches:
		add_text(source_text.substr(cursor, item.offset - cursor))
		push_underline()
		var active: bool = item.offset == offset and item.length == length
		if active:
			push_bgcolor(Color.WHITE)
			push_color(Color.BLACK)
		add_text(source_text.substr(item.offset, item.length))
		if active:
			pop()
			pop()
		pop()
		cursor = item.offset + item.length
	add_text(source_text.substr(cursor))
