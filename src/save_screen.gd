class_name SaveScreen
extends Control

signal save_completed
signal back_requested

const NEW_SAVE_LABEL := "新規保存"
const OVERWRITE_MESSAGE := "上書きしますか？"

const SAVE_FAILURE_MESSAGE := "保存に失敗しました"

var _save_manager: SaveManager
var _slots: Array[Dictionary] = []  # [{slot_number, ...}], first entry is "new save"
var _menu: CursorMenu
var _menu_rows: Array[CursorMenuRow] = []
var _title_label: Label
var _container: VBoxContainer
var _status_label: Label

var _overwrite_slot: int = -1
var _overwrite_dialog: ConfirmDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overwrite_dialog = ConfirmDialog.new()
	add_child(_overwrite_dialog)
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)

func setup(save_manager: SaveManager) -> void:
	_save_manager = save_manager
	_build_ui()

func get_slot_count() -> int:
	return _slots.size()

func is_overwrite_dialog_visible() -> bool:
	return _overwrite_dialog.visible

func _build_ui() -> void:
	_slots.clear()
	_slots.append({"slot_number": -1, "label": NEW_SAVE_LABEL})
	var saves := _save_manager.list_saves()
	for s in saves:
		_slots.append({
			"slot_number": s["slot_number"],
			"label": _format_slot_label(s),
		})

	var items: Array[String] = []
	for s in _slots:
		items.append(s["label"])
	_menu = CursorMenu.new(items)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 300)
	center.add_child(panel)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	panel.add_child(_container)

	_title_label = Label.new()
	_title_label.text = "セーブ"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_container.add_child(spacer)

	_menu_rows.clear()
	for i in range(_menu.size()):
		_menu_rows.append(CursorMenuRow.create(_container, _menu.items[i], 18))
	_menu.update_rows(_menu_rows)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = ""
	_container.add_child(_status_label)

func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""

func _unhandled_input(event: InputEvent) -> void:
	# ConfirmDialog handles its own input while visible.
	if is_overwrite_dialog_visible():
		return
	if MenuController.route(event, _menu, _menu_rows, _on_slot_selected, back_requested.emit):
		get_viewport().set_input_as_handled()

func _on_slot_selected() -> void:
	var selected := _slots[_menu.selected_index]
	if selected["slot_number"] == -1:
		# New save
		var slot := _save_manager.get_next_slot_number()
		if _save_manager.save(slot):
			_status_label.text = ""
			save_completed.emit()
		else:
			_status_label.text = SAVE_FAILURE_MESSAGE
	else:
		# Show overwrite dialog
		_overwrite_slot = selected["slot_number"]
		_overwrite_dialog.setup(OVERWRITE_MESSAGE, ConfirmDialog.DEFAULT_NO_INDEX)

func _on_overwrite_confirmed() -> void:
	var ok := _save_manager.save(_overwrite_slot)
	if ok:
		_status_label.text = ""
		save_completed.emit()
	else:
		_status_label.text = SAVE_FAILURE_MESSAGE

static func _format_slot_label(s: Dictionary) -> String:
	var loc: String
	if s.get("game_location", "") == GameState.LOCATION_TOWN:
		loc = "町"
	else:
		var dn: String = s.get("dungeon_name", "")
		loc = dn if dn != "" else str(s.get("game_location", ""))
	var party: String = s.get("party_name", "")
	var lv: int = s.get("max_level", 0)
	var parts: Array[String] = ["No.%d" % s.get("slot_number", 0)]
	parts.append(s.get("last_saved", ""))
	if party != "":
		parts.append(party)
	if lv > 0:
		parts.append("Lv.%d" % lv)
	parts.append(loc)
	return "  ".join(parts)
