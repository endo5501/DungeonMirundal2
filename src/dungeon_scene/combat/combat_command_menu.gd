class_name CombatCommandMenu
extends Control

const OPTIONS: Array[String] = ["こうげき", "ぼうぎょ", "にげる"]

signal command_selected(index: int)

var _label: Label
var _title_label: Label
var _selected_index: int = 0
var _current_actor: CombatActor


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _label != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_label)
	_refresh_label()


func show_for(actor: CombatActor) -> void:
	_current_actor = actor
	_selected_index = 0
	visible = true
	_ensure_ready()
	if _title_label != null:
		_title_label.text = "%s のコマンド:" % (actor.actor_name if actor != null else "")
	_refresh_label()


func hide_menu() -> void:
	visible = false


func move_up() -> void:
	_selected_index = (_selected_index - 1 + OPTIONS.size()) % OPTIONS.size()
	_refresh_label()


func move_down() -> void:
	_selected_index = (_selected_index + 1) % OPTIONS.size()
	_refresh_label()


func select_at(index: int) -> void:
	if index < 0 or index >= OPTIONS.size():
		return
	_selected_index = index
	command_selected.emit(_selected_index)


func confirm_current() -> void:
	command_selected.emit(_selected_index)


func get_options() -> Array[String]:
	return OPTIONS.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _ensure_ready() -> void:
	if _label == null:
		_build_ui()


func _refresh_label() -> void:
	if _label == null:
		return
	var lines: Array = []
	for i in range(OPTIONS.size()):
		var prefix: String = "> " if i == _selected_index else "  "
		lines.append(prefix + OPTIONS[i])
	_label.text = "\n".join(lines)
