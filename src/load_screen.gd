class_name LoadScreen
extends Control

signal load_requested(slot_number: int)
signal back_requested

const _FAILURE_MESSAGES := {
	SaveManager.LoadResult.FILE_NOT_FOUND: "セーブファイルが見つかりません",
	SaveManager.LoadResult.PARSE_ERROR: "セーブデータが破損しています",
	SaveManager.LoadResult.VERSION_TOO_NEW: "未対応のセーブデータです(新しいバージョン)",
	SaveManager.LoadResult.RESTORE_FAILED: "ロードに失敗しました",
}

var _save_manager: SaveManager
var _slots: Array[Dictionary] = []
var _menu: CursorMenu
var _menu_rows: Array[CursorMenuRow] = []
var _no_saves: bool = false
var _container: VBoxContainer
var _status_label: Label

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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 300)
	center.add_child(panel)

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
	else:
		_no_saves = false
		for s in saves:
			_slots.append({
				"slot_number": s["slot_number"],
				"label": SaveScreen._format_slot_label(s),
			})

		var items: Array[String] = []
		for s in _slots:
			items.append(s["label"])
		_menu = CursorMenu.new(items)

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

func show_load_failure(result: SaveManager.LoadResult) -> void:
	if _status_label == null:
		return
	_status_label.text = _FAILURE_MESSAGES.get(result, "ロードに失敗しました")

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
				_menu.update_rows(_menu_rows)
		KEY_DOWN, KEY_S:
			if _menu:
				_menu.move_cursor(1)
				_menu.update_rows(_menu_rows)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _menu and _slots.size() > 0:
				var slot: int = _slots[_menu.selected_index]["slot_number"]
				load_requested.emit(slot)
		KEY_ESCAPE:
			back_requested.emit()
	get_viewport().set_input_as_handled()
