class_name CursorMenuRow
extends HBoxContainer

const CURSOR_GLYPH := "▶"
const CURSOR_SLOT_WIDTH := 24.0

var _cursor_slot: Control
var _cursor_icon: Label
var _text_label: Label
var _extra_labels: Array[Label] = []
var _selected: bool = false
var _disabled: bool = false

func _init() -> void:
	add_theme_constant_override("separation", 4)

	_cursor_slot = Control.new()
	_cursor_slot.custom_minimum_size = Vector2(CURSOR_SLOT_WIDTH, 0)
	add_child(_cursor_slot)

	_cursor_icon = Label.new()
	_cursor_icon.text = CURSOR_GLYPH
	_cursor_icon.visible = false
	_cursor_slot.add_child(_cursor_icon)

	_text_label = Label.new()
	_text_label.add_theme_color_override("font_color", CursorMenu.ENABLED_COLOR)
	add_child(_text_label)

static func create(parent: Node, text: String, font_size: int) -> CursorMenuRow:
	var row := CursorMenuRow.new()
	row.set_text(text)
	row.set_text_font_size(font_size)
	parent.add_child(row)
	return row

func set_text(text: String) -> void:
	_text_label.text = text

func set_text_font_size(size: int) -> void:
	_text_label.add_theme_font_size_override("font_size", size)

func set_selected(selected: bool) -> void:
	if selected == _selected:
		return
	_selected = selected
	_cursor_icon.visible = selected

func is_selected() -> bool:
	return _selected

func set_disabled(disabled: bool) -> void:
	if disabled == _disabled:
		return
	_disabled = disabled
	var color: Color = CursorMenu.DISABLED_COLOR if disabled else CursorMenu.ENABLED_COLOR
	_apply_color_to_text_columns(color)

func add_extra_label(label: Label) -> void:
	add_child(label)
	_extra_labels.append(label)
	var color: Color = CursorMenu.DISABLED_COLOR if _disabled else CursorMenu.ENABLED_COLOR
	label.add_theme_color_override("font_color", color)

func get_cursor_slot() -> Control:
	return _cursor_slot

func get_cursor_icon() -> Label:
	return _cursor_icon

func get_text_label() -> Label:
	return _text_label

func get_extra_labels() -> Array[Label]:
	return _extra_labels

func _apply_color_to_text_columns(color: Color) -> void:
	_text_label.add_theme_color_override("font_color", color)
	for label in _extra_labels:
		label.add_theme_color_override("font_color", color)
