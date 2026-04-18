class_name CombatTargetSelector
extends Control

signal target_selected(target: CombatActor)

var _title_label: Label
var _options_vbox: VBoxContainer
var _rows: Array[CursorMenuRow] = []
var _selected_index: int = 0
var _targets: Array = []  # Array[CombatActor] living


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
	_title_label.text = "対象を選択:"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)


func show_with(monsters: Array) -> void:
	_ensure_ready()
	_targets.clear()
	for m in monsters:
		if m != null and m.is_alive():
			_targets.append(m)
	_selected_index = 0
	visible = true
	_rebuild_rows()
	_refresh_label()


func hide_selector() -> void:
	visible = false


func move_up() -> void:
	if _targets.is_empty():
		return
	_selected_index = (_selected_index - 1 + _targets.size()) % _targets.size()
	_refresh_label()


func move_down() -> void:
	if _targets.is_empty():
		return
	_selected_index = (_selected_index + 1) % _targets.size()
	_refresh_label()


func confirm_current() -> void:
	if _targets.is_empty():
		return
	target_selected.emit(_targets[_selected_index])


func select_at(index: int) -> void:
	if index < 0 or index >= _targets.size():
		return
	_selected_index = index
	target_selected.emit(_targets[_selected_index])


func get_targets() -> Array:
	return _targets.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _ensure_ready() -> void:
	if _options_vbox == null:
		_build_ui()


func _rebuild_rows() -> void:
	_rows.clear()
	for child in _options_vbox.get_children():
		_options_vbox.remove_child(child)
		child.queue_free()
	for i in range(_targets.size()):
		_rows.append(CursorMenuRow.create(_options_vbox, _targets[i].actor_name, 16))


func _refresh_label() -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == _selected_index)
