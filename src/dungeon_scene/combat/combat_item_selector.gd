class_name CombatItemSelector
extends Control

signal item_selected(instance: ItemInstance)
signal cancelled

var _title_label: Label
var _options_vbox: VBoxContainer
var _message_label: Label
var _rows: Array[CursorMenuRow] = []
var _selected_index: int = 0
var _entries: Array = []  # Array[{instance: ItemInstance, usable: bool, reason: String}]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _options_vbox != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.text = "アイテム:"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 12)
	_message_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	_message_label.visible = false
	vbox.add_child(_message_label)


func show_with(inventory: Inventory, context: ItemUseContext) -> void:
	_ensure_ready()
	_entries.clear()
	if inventory != null:
		for inst in inventory.list():
			if inst.item == null or not inst.item.is_consumable():
				continue
			var reason := inst.item.get_context_failure_reason(context)
			_entries.append({"instance": inst, "usable": reason == "", "reason": reason})
	_selected_index = _first_usable_index()
	_message_label.visible = false
	visible = true
	_rebuild_rows()
	_refresh_rows()


func hide_selector() -> void:
	visible = false


func is_empty() -> bool:
	return _entries.is_empty()


func move_up() -> void:
	if _entries.is_empty():
		return
	_selected_index = (_selected_index - 1 + _entries.size()) % _entries.size()
	_refresh_rows()


func move_down() -> void:
	if _entries.is_empty():
		return
	_selected_index = (_selected_index + 1) % _entries.size()
	_refresh_rows()


func confirm_current() -> void:
	if _entries.is_empty():
		cancelled.emit()
		return
	var entry: Dictionary = _entries[_selected_index]
	if not entry.usable:
		_show_message(entry.reason)
		return
	item_selected.emit(entry.instance)


func get_entries() -> Array:
	return _entries.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _ensure_ready() -> void:
	if _options_vbox == null:
		_build_ui()


func _first_usable_index() -> int:
	for i in range(_entries.size()):
		if _entries[i].usable:
			return i
	return 0


func _show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.visible = true


func _rebuild_rows() -> void:
	_rows.clear()
	for child in _options_vbox.get_children():
		_options_vbox.remove_child(child)
		child.queue_free()
	for entry in _entries:
		var inst: ItemInstance = entry.instance
		var text: String = inst.item.item_name
		if not entry.usable:
			text = "%s  (%s)" % [text, entry.reason]
		var row := CursorMenuRow.create(_options_vbox, text, 14)
		if not entry.usable:
			row.set_disabled(true)
		_rows.append(row)


func _refresh_rows() -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == _selected_index)
