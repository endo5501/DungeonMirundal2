class_name SaveScreen
extends Control

signal save_completed
signal back_requested

const NEW_SAVE_LABEL := "新規保存"
const OVERWRITE_OPTIONS: Array[String] = ["はい", "いいえ"]

var _save_manager: SaveManager
var _slots: Array[Dictionary] = []  # [{slot_number, ...}], first entry is "new save"
var _menu: CursorMenu
var _menu_rows: Array[CursorMenuRow] = []
var _title_label: Label
var _container: VBoxContainer

var _overwrite_visible := false
var _overwrite_slot: int = -1
var _overwrite_menu: CursorMenu
var _overwrite_rows: Array[CursorMenuRow] = []
var _overwrite_container: CenterContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func setup(save_manager: SaveManager) -> void:
	_save_manager = save_manager
	_build_ui()

func get_slot_count() -> int:
	return _slots.size()

func is_overwrite_dialog_visible() -> bool:
	return _overwrite_visible

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

func _build_overwrite_dialog() -> void:
	_overwrite_menu = CursorMenu.new(OVERWRITE_OPTIONS)
	_overwrite_menu.selected_index = 1  # default to いいえ

	_overwrite_container = CenterContainer.new()
	_overwrite_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_overwrite_container)

	var overwrite_panel := PanelContainer.new()
	overwrite_panel.custom_minimum_size = Vector2(300, 120)
	_overwrite_container.add_child(overwrite_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	overwrite_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "上書きしますか？"
	msg.add_theme_font_size_override("font_size", 20)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	_overwrite_rows.clear()
	for i in range(_overwrite_menu.size()):
		_overwrite_rows.append(CursorMenuRow.create(vbox, _overwrite_menu.items[i], 18))
	_overwrite_menu.update_rows(_overwrite_rows)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if _overwrite_visible:
		_handle_overwrite_input(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return

	match (event as InputEventKey).keycode:
		KEY_UP, KEY_W:
			_menu.move_cursor(-1)
			_menu.update_rows(_menu_rows)
		KEY_DOWN, KEY_S:
			_menu.move_cursor(1)
			_menu.update_rows(_menu_rows)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_slot_selected()
		KEY_ESCAPE:
			back_requested.emit()
	get_viewport().set_input_as_handled()

func _on_slot_selected() -> void:
	var selected := _slots[_menu.selected_index]
	if selected["slot_number"] == -1:
		# New save
		var slot := _save_manager.get_next_slot_number()
		_save_manager.save(slot)
		save_completed.emit()
	else:
		# Show overwrite dialog
		_overwrite_slot = selected["slot_number"]
		_overwrite_visible = true
		_build_overwrite_dialog()

func _handle_overwrite_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:
			_overwrite_menu.move_cursor(-1)
			_overwrite_menu.update_rows(_overwrite_rows)
		KEY_DOWN, KEY_S:
			_overwrite_menu.move_cursor(1)
			_overwrite_menu.update_rows(_overwrite_rows)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _overwrite_menu.selected_index == 0:  # はい
				_save_manager.save(_overwrite_slot)
				_overwrite_visible = false
				if _overwrite_container:
					_overwrite_container.queue_free()
					_overwrite_container = null
				save_completed.emit()
			else:  # いいえ
				cancel_overwrite()
		KEY_ESCAPE:
			cancel_overwrite()

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

func cancel_overwrite() -> void:
	_overwrite_visible = false
	if _overwrite_container:
		_overwrite_container.queue_free()
		_overwrite_container = null
