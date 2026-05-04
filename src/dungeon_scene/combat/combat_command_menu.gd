class_name CombatCommandMenu
extends Control

# Stable semantic IDs (NOT slot positions). The numeric values 0..3 are
# preserved for combat tests that pass `command_menu_select(int)`. The
# displayed slot order is rebuilt per actor by `_build_option_ids_for`, so
# CAST_MAGE / CAST_PRIEST may appear between DEFEND and ITEM in the UI.
const OPT_ATTACK: int = 0
const OPT_DEFEND: int = 1
const OPT_ITEM: int = 2
const OPT_ESCAPE: int = 3
const OPT_CAST_MAGE: int = 4
const OPT_CAST_PRIEST: int = 5

const _LABELS: Dictionary = {
	OPT_ATTACK: "こうげき",
	OPT_DEFEND: "ぼうぎょ",
	OPT_ITEM: "アイテム",
	OPT_ESCAPE: "にげる",
	OPT_CAST_MAGE: "魔術",
	OPT_CAST_PRIEST: "祈り",
}

signal command_selected(option_id: int)

var _rows: Array[CursorMenuRow] = []
var _option_ids: Array[int] = []
var _title_label: Label
var _options_vbox: VBoxContainer
var _selected_index: int = 0
var _current_actor: CombatActor


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
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)


func show_for(actor: CombatActor) -> void:
	_current_actor = actor
	_option_ids = _build_option_ids_for(actor)
	_selected_index = 0
	visible = true
	_ensure_ready()
	if _title_label != null:
		_title_label.text = "%s のコマンド:" % (actor.actor_name if actor != null else "")
	_rebuild_rows()
	_refresh_rows()


func hide_menu() -> void:
	visible = false


func move_up() -> void:
	if _option_ids.is_empty():
		return
	_selected_index = (_selected_index - 1 + _option_ids.size()) % _option_ids.size()
	_refresh_rows()


func move_down() -> void:
	if _option_ids.is_empty():
		return
	_selected_index = (_selected_index + 1) % _option_ids.size()
	_refresh_rows()


# Programmatic selection by semantic OPT_* id. The id need not be present in
# the currently-displayed option list (tests sometimes drive the engine without
# refreshing UI for the matching actor), so we emit the id directly.
func select_at(option_id: int) -> void:
	command_selected.emit(option_id)


func confirm_current() -> void:
	if _option_ids.is_empty():
		return
	command_selected.emit(_option_ids[_selected_index])


func get_options() -> Array[String]:
	var labels: Array[String] = []
	for id in _option_ids:
		labels.append(String(_LABELS.get(id, "")))
	return labels


func get_option_ids() -> Array[int]:
	return _option_ids.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _build_option_ids_for(actor: CombatActor) -> Array[int]:
	var ids: Array[int] = [OPT_ATTACK, OPT_DEFEND]
	var ch: Character = null
	if actor is PartyCombatant:
		ch = (actor as PartyCombatant).character
	if ch != null and ch.job != null:
		if ch.job.mage_school:
			ids.append(OPT_CAST_MAGE)
		if ch.job.priest_school:
			ids.append(OPT_CAST_PRIEST)
	ids.append(OPT_ITEM)
	ids.append(OPT_ESCAPE)
	return ids


func _ensure_ready() -> void:
	if _options_vbox == null:
		_build_ui()


func _rebuild_rows() -> void:
	if _options_vbox == null:
		return
	_rows.clear()
	for child in _options_vbox.get_children():
		_options_vbox.remove_child(child)
		child.queue_free()
	for id in _option_ids:
		_rows.append(CursorMenuRow.create(_options_vbox, String(_LABELS.get(id, "")), 16))


func _refresh_rows() -> void:
	if _rows.is_empty():
		return
	for i in range(_rows.size()):
		_rows[i].set_selected(i == _selected_index)
