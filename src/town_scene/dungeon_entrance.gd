class_name DungeonEntrance
extends Control

signal enter_dungeon(index: int)
signal back_requested

enum Mode { LIST, CREATE_DIALOG, DELETE_CONFIRM }
enum Focus { DUNGEON_LIST, BUTTONS }

const BUTTON_ITEMS: Array[String] = ["潜入する", "新規生成", "破棄", "戻る"]
const FONT_SIZE := 18

var _registry: DungeonRegistry
var _has_party: bool
var selected_index: int = -1
var _mode: Mode = Mode.LIST
var _focus: Focus = Focus.DUNGEON_LIST

var _list_labels: Array[Label] = []
var _button_menu: CursorMenu
var _button_labels: Array[Label] = []
var _vbox: VBoxContainer
var _create_dialog: DungeonCreateDialog
var _delete_confirm_container: PanelContainer
var _delete_confirm_labels: Array[Label] = []
var _delete_confirm_selected: int = 1  # default to いいえ

func _init() -> void:
	_button_menu = CursorMenu.new(BUTTON_ITEMS)

func setup(registry: DungeonRegistry, has_party: bool) -> void:
	_registry = registry
	_has_party = has_party
	if _registry.size() > 0:
		selected_index = 0

func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	_build_ui()

func _build_ui() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_list_labels.clear()
	_button_labels.clear()

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
			var label := Label.new()
			label.add_theme_font_size_override("font_size", FONT_SIZE)
			_vbox.add_child(label)
			_list_labels.append(label)
	else:
		var empty := Label.new()
		empty.text = "  (ダンジョンがありません)"
		empty.add_theme_font_size_override("font_size", FONT_SIZE)
		empty.add_theme_color_override("font_color", CursorMenu.DISABLED_COLOR)
		_vbox.add_child(empty)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 16
	_vbox.add_child(spacer2)

	for i in range(BUTTON_ITEMS.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		_vbox.add_child(label)
		_button_labels.append(label)

	_update_button_disabled()
	_update_labels()

func _update_button_disabled() -> void:
	var disabled: Array[int] = []
	if is_enter_disabled():
		disabled.append(0)
	if is_delete_disabled():
		disabled.append(2)
	_button_menu.disabled_indices = disabled

func _update_labels() -> void:
	for i in range(_list_labels.size()):
		var dd := _registry.get_dungeon(i)
		var prefix := CursorMenu.CURSOR_PREFIX if _focus == Focus.DUNGEON_LIST and i == selected_index else CursorMenu.NO_CURSOR_PREFIX
		var rate := int(dd.get_exploration_rate() * 100)
		_list_labels[i].text = "%s%s  %dx%d  探索%d%%" % [prefix, dd.dungeon_name, dd.map_size, dd.map_size, rate]

	_button_menu.update_labels(_button_labels)

func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.LIST:
		if _mode == Mode.DELETE_CONFIRM:
			_handle_delete_confirm_input(event)
		return

	if event.is_action_pressed("ui_down"):
		if _focus == Focus.DUNGEON_LIST and _registry.size() > 0:
			move_list_cursor(1)
		elif _focus == Focus.BUTTONS:
			_button_menu.move_cursor(1)
		_update_button_disabled()
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		if _focus == Focus.DUNGEON_LIST and _registry.size() > 0:
			move_list_cursor(-1)
		elif _focus == Focus.BUTTONS:
			_button_menu.move_cursor(-1)
		_update_button_disabled()
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focus == Focus.BUTTONS:
			_activate_button()
		else:
			_focus = Focus.BUTTONS
			_button_menu.selected_index = 0
			_update_button_disabled()
			_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _focus == Focus.BUTTONS:
			_focus = Focus.DUNGEON_LIST
			_update_labels()
		else:
			do_back()
		get_viewport().set_input_as_handled()

func _show_delete_confirm() -> void:
	_mode = Mode.DELETE_CONFIRM
	_delete_confirm_selected = 1  # default to いいえ
	_delete_confirm_labels.clear()

	_delete_confirm_container = PanelContainer.new()
	_delete_confirm_container.set_anchors_and_offsets_preset(PRESET_CENTER)
	_delete_confirm_container.custom_minimum_size = Vector2(350, 140)
	add_child(_delete_confirm_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_delete_confirm_container.add_child(vbox)

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
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		vbox.add_child(label)
		_delete_confirm_labels.append(label)
	_update_delete_confirm_labels()

func _update_delete_confirm_labels() -> void:
	var options := ["はい", "いいえ"]
	for i in range(_delete_confirm_labels.size()):
		var prefix := CursorMenu.CURSOR_PREFIX if i == _delete_confirm_selected else CursorMenu.NO_CURSOR_PREFIX
		_delete_confirm_labels[i].text = prefix + options[i]

func _close_delete_confirm() -> void:
	if _delete_confirm_container:
		_delete_confirm_container.queue_free()
		_delete_confirm_container = null
	_delete_confirm_labels.clear()
	_mode = Mode.LIST

func _handle_delete_confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_delete_confirm_selected = 1 - _delete_confirm_selected
		_update_delete_confirm_labels()
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
		0: do_enter()
		1: _open_create_dialog()
		2: _show_delete_confirm()
		3: do_back()

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
	return selected_index < 0 or not _has_party

func is_delete_disabled() -> bool:
	return selected_index < 0

func move_list_cursor(direction: int) -> void:
	if _registry.size() == 0:
		return
	selected_index = clampi(selected_index + direction, 0, _registry.size() - 1)

func do_enter() -> void:
	if not is_enter_disabled():
		enter_dungeon.emit(selected_index)

func do_back() -> void:
	back_requested.emit()
