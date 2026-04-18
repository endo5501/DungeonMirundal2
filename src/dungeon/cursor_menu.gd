class_name CursorMenu
extends RefCounted

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

func ensure_valid_selection() -> void:
	if items.is_empty():
		return
	if not is_disabled(selected_index):
		return
	var start := selected_index
	var count := items.size()
	for i in range(count):
		var candidate := (start + i + 1) % count
		if not is_disabled(candidate):
			selected_index = candidate
			return

func update_rows(rows: Array[CursorMenuRow]) -> void:
	for i in range(rows.size()):
		rows[i].set_selected(i == selected_index)
		rows[i].set_disabled(is_disabled(i))
