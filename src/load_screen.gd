class_name LoadScreen
extends Control

signal load_requested(slot_number: int)
signal back_requested

var _save_manager: SaveManager
var _slots: Array[Dictionary] = []
var _menu: CursorMenu
var _menu_labels: Array[Label] = []
var _no_saves: bool = false
var _container: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func setup(save_manager: SaveManager) -> void:
	_save_manager = save_manager
	_build_ui()

func get_slot_count() -> int:
	return _slots.size()

func has_no_saves_message() -> bool:
	return _no_saves

func _build_ui() -> void:
	_slots.clear()
	var saves := _save_manager.list_saves()

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 300)
	add_child(panel)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	panel.add_child(_container)

	var title := Label.new()
	title.text = "ロード"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_container.add_child(spacer)

	if saves.size() == 0:
		_no_saves = true
		var msg := Label.new()
		msg.text = "セーブデータがありません"
		msg.add_theme_font_size_override("font_size", 18)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_container.add_child(msg)
		return

	_no_saves = false
	for s in saves:
		var loc_text: String = "町" if s.get("game_location", "") == "town" else str(s.get("game_location", ""))
		_slots.append({
			"slot_number": s["slot_number"],
			"label": "No.%d  %s  %s" % [s["slot_number"], s.get("last_saved", ""), loc_text],
		})

	var items: Array[String] = []
	for s in _slots:
		items.append(s["label"])
	_menu = CursorMenu.new(items)

	_menu_labels.clear()
	for i in range(_menu.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		_container.add_child(label)
		_menu_labels.append(label)
	_menu.update_labels(_menu_labels)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if _no_saves:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			back_requested.emit()
		get_viewport().set_input_as_handled()
		return

	match (event as InputEventKey).keycode:
		KEY_UP, KEY_W:
			if _menu:
				_menu.move_cursor(-1)
				_menu.update_labels(_menu_labels)
		KEY_DOWN, KEY_S:
			if _menu:
				_menu.move_cursor(1)
				_menu.update_labels(_menu_labels)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _menu and _slots.size() > 0:
				var slot: int = _slots[_menu.selected_index]["slot_number"]
				load_requested.emit(slot)
		KEY_ESCAPE:
			back_requested.emit()
	get_viewport().set_input_as_handled()
