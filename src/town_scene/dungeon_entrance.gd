class_name DungeonEntrance
extends Control

signal enter_dungeon(index: int)
signal back_requested

enum Mode { LIST, CREATE_DIALOG, DELETE_CONFIRM }
enum Focus { BUTTONS, LIST_FOR_ENTER, LIST_FOR_DELETE }

const BUTTON_ITEMS: Array[String] = ["潜入する", "新規生成", "破棄", "戻る"]
const FONT_SIZE := 18

var _registry: DungeonRegistry
var _has_party: bool
var selected_index: int = -1
var _mode: Mode = Mode.LIST
var _focus: Focus = Focus.BUTTONS

var _list_rows: Array[CursorMenuRow] = []
var _button_menu: CursorMenu
var _button_rows: Array[CursorMenuRow] = []
var _vbox: VBoxContainer
var _create_dialog: DungeonCreateDialog
var _delete_confirm_container: CenterContainer
var _delete_confirm_rows: Array[CursorMenuRow] = []
var _delete_confirm_selected: int = 1  # default to いいえ

func _init() -> void:
	_button_menu = CursorMenu.new(BUTTON_ITEMS)

func setup(registry: DungeonRegistry, has_party: bool) -> void:
	_registry = registry
	_has_party = has_party
	_focus = Focus.BUTTONS
	if _registry.size() > 0:
		selected_index = 0
		_button_menu.selected_index = 0
	else:
		selected_index = -1
		# Skip disabled 潜入する (index 0) and 破棄 (index 2); land on 新規生成 instead.
		_button_menu.selected_index = 1

func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	_build_ui()

func _build_ui() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_list_rows.clear()
	_button_rows.clear()

	var title := Label.new()
	title.text = "ダンジョン入口"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 12
	_vbox.add_child(spacer1)

	if _registry and _registry.size() > 0:
		for i in range(_registry.size()):
			var dd := _registry.get_dungeon(i)
			var row := CursorMenuRow.create(_vbox, dd.dungeon_name, FONT_SIZE)
			var size_label := Label.new()
			size_label.text = "%dx%d" % [dd.map_size, dd.map_size]
			size_label.add_theme_font_size_override("font_size", FONT_SIZE)
			row.add_extra_label(size_label)
			var rate_label := Label.new()
			rate_label.text = "探索%d%%" % int(dd.get_exploration_rate() * 100)
			rate_label.add_theme_font_size_override("font_size", FONT_SIZE)
			row.add_extra_label(rate_label)
			_list_rows.append(row)
	else:
		var empty := Label.new()
		empty.text = "まず「新規生成」でダンジョンを作成してください"
		empty.add_theme_font_size_override("font_size", FONT_SIZE)
		_vbox.add_child(empty)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 16
	_vbox.add_child(spacer2)

	for i in range(BUTTON_ITEMS.size()):
		_button_rows.append(CursorMenuRow.create(_vbox, BUTTON_ITEMS[i], FONT_SIZE))

	_add_hint("[↑↓] 選択  [Enter] 決定  [Esc] 戻る")

	_update_button_disabled()
	_update_rows()

func _add_hint(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_vbox.add_child(spacer)

	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(hint)

func _update_button_disabled() -> void:
	var disabled: Array[int] = []
	if is_enter_disabled():
		disabled.append(0)
	if is_delete_disabled():
		disabled.append(2)
	_button_menu.disabled_indices = disabled

func _update_rows() -> void:
	var list_focused := _focus == Focus.LIST_FOR_ENTER or _focus == Focus.LIST_FOR_DELETE
	for i in range(_list_rows.size()):
		_list_rows[i].set_selected(list_focused and i == selected_index)

	_button_menu.update_rows(_button_rows)

func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.LIST:
		if _mode == Mode.DELETE_CONFIRM:
			_handle_delete_confirm_input(event)
		return

	if _focus == Focus.BUTTONS:
		_input_buttons(event)
	else:
		_input_list(event)

func _input_buttons(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_button_menu.move_cursor(1)
		_update_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_button_menu.move_cursor(-1)
		_update_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate_button()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		do_back()
		get_viewport().set_input_as_handled()

func _input_list(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		move_list_cursor(1)
		_update_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		move_list_cursor(-1)
		_update_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_commit_list_action()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_return_to_buttons()
		get_viewport().set_input_as_handled()

func _commit_list_action() -> void:
	match _focus:
		Focus.LIST_FOR_ENTER:
			do_enter()
			_return_to_buttons()
		Focus.LIST_FOR_DELETE:
			_show_delete_confirm()

func _return_to_buttons() -> void:
	_focus = Focus.BUTTONS
	_update_rows()

func _show_delete_confirm() -> void:
	_mode = Mode.DELETE_CONFIRM
	_delete_confirm_selected = 1  # default to いいえ
	_delete_confirm_rows.clear()

	_delete_confirm_container = CenterContainer.new()
	_delete_confirm_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_delete_confirm_container)

	var confirm_panel := PanelContainer.new()
	confirm_panel.custom_minimum_size = Vector2(350, 140)
	_delete_confirm_container.add_child(confirm_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	confirm_panel.add_child(vbox)

	var dd := _registry.get_dungeon(selected_index)
	var msg := Label.new()
	msg.text = "「%s」を破棄しますか？" % dd.dungeon_name
	msg.add_theme_font_size_override("font_size", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	for option in ["はい", "いいえ"]:
		_delete_confirm_rows.append(CursorMenuRow.create(vbox, option, FONT_SIZE))
	_update_delete_confirm_rows()

func _update_delete_confirm_rows() -> void:
	for i in range(_delete_confirm_rows.size()):
		_delete_confirm_rows[i].set_selected(i == _delete_confirm_selected)

func _close_delete_confirm() -> void:
	if _delete_confirm_container:
		_delete_confirm_container.queue_free()
		_delete_confirm_container = null
	_delete_confirm_rows.clear()
	_mode = Mode.LIST

func _handle_delete_confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_delete_confirm_selected = 1 - _delete_confirm_selected
		_update_delete_confirm_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _delete_confirm_selected == 0:
			_confirm_delete()
		_close_delete_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close_delete_confirm()
		get_viewport().set_input_as_handled()

func _activate_button() -> void:
	if _button_menu.is_disabled(_button_menu.selected_index):
		return
	match _button_menu.selected_index:
		0: _begin_list_selection(Focus.LIST_FOR_ENTER)
		1: _open_create_dialog()
		2: _begin_list_selection(Focus.LIST_FOR_DELETE)
		3: do_back()

func _begin_list_selection(target_focus: Focus) -> void:
	if _registry.size() == 0:
		return
	if selected_index < 0 or selected_index >= _registry.size():
		selected_index = 0
	_focus = target_focus
	_update_rows()

func _open_create_dialog() -> void:
	_create_dialog = DungeonCreateDialog.new()
	_create_dialog.confirmed.connect(_on_create_confirmed)
	_create_dialog.cancelled.connect(_on_create_cancelled)
	add_child(_create_dialog)
	_mode = Mode.CREATE_DIALOG

func _on_create_confirmed(dungeon_name: String, size_category: int) -> void:
	_registry.create(dungeon_name, size_category)
	if selected_index < 0:
		selected_index = 0
	_close_create_dialog()
	_build_ui()

func _on_create_cancelled() -> void:
	_close_create_dialog()

func _close_create_dialog() -> void:
	if _create_dialog:
		_create_dialog.queue_free()
		_create_dialog = null
	_mode = Mode.LIST

func _confirm_delete() -> void:
	if selected_index >= 0 and selected_index < _registry.size():
		_registry.remove(selected_index)
		if selected_index >= _registry.size():
			selected_index = _registry.size() - 1
		_build_ui()

func get_dungeon_count() -> int:
	if _registry == null:
		return 0
	return _registry.size()

func is_enter_disabled() -> bool:
	return _registry == null or _registry.size() == 0 or not _has_party

func is_delete_disabled() -> bool:
	return _registry == null or _registry.size() == 0

func move_list_cursor(direction: int) -> void:
	if _registry.size() == 0:
		return
	selected_index = clampi(selected_index + direction, 0, _registry.size() - 1)

func do_enter() -> void:
	if not is_enter_disabled():
		enter_dungeon.emit(selected_index)

func do_back() -> void:
	back_requested.emit()
