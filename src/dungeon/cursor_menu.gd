class_name CursorMenu
extends RefCounted

const CURSOR_PREFIX := "> "
const NO_CURSOR_PREFIX := "  "
const DISABLED_COLOR := Color(0.5, 0.5, 0.5)
const ENABLED_COLOR := Color(1.0, 1.0, 1.0)

var items: Array[String]
var disabled_indices: Array[int]
var selected_index: int = 0

func _init(p_items: Array[String], p_disabled: Array[int] = []) -> void:
	items = p_items
	disabled_indices = p_disabled

func size() -> int:
	return items.size()

func is_disabled(index: int) -> bool:
	return index in disabled_indices

func move_cursor(direction: int) -> void:
	var start := selected_index
	var count := items.size()
	for _i in range(count):
		selected_index = (selected_index + direction) % count
		if selected_index < 0:
			selected_index += count
		if not is_disabled(selected_index):
			return
	selected_index = start

func update_labels(labels: Array[Label]) -> void:
	for i in range(labels.size()):
		var prefix := CURSOR_PREFIX if i == selected_index else NO_CURSOR_PREFIX
		labels[i].text = prefix + items[i]
		labels[i].add_theme_color_override(
			"font_color",
			DISABLED_COLOR if is_disabled(i) else ENABLED_COLOR
		)
