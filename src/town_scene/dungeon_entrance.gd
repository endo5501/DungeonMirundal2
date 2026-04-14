class_name DungeonEntrance
extends Control

signal enter_dungeon(index: int)
signal back_requested

var _registry: DungeonRegistry
var _has_party: bool
var selected_index: int = -1
var _mode: int = 0  # 0=list, 1=create_dialog, 2=delete_confirm

var _list_labels: Array[Label] = []
var _button_labels: Array[Label] = []
var _vbox: VBoxContainer
var _create_dialog: DungeonCreateDialog

const FONT_SIZE := 18
const CURSOR := "> "
const BUTTON_ITEMS := ["潜入する", "新規生成", "破棄", "戻る"]

var _button_index: int = 0
var _focus: int = 0  # 0=list, 1=buttons

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

	# Dungeon list
	if _registry and _registry.size() > 0:
		for i in range(_registry.size()):
			var dd := _registry.get_dungeon(i)
			var label := Label.new()
			label.add_theme_font_size_override("font_size", FONT_SIZE)
			_vbox.add_child(label)
			_list_labels.append(label)
	else:
		var empty := Label.new()
		empty.text = "  (ダンジョンがありません)"
		empty.add_theme_font_size_override("font_size", FONT_SIZE)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_vbox.add_child(empty)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 16
	_vbox.add_child(spacer2)

	# Action buttons
	for i in range(BUTTON_ITEMS.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		_vbox.add_child(label)
		_button_labels.append(label)

	_update_labels()

func _update_labels() -> void:
	for i in range(_list_labels.size()):
		var dd := _registry.get_dungeon(i)
		var prefix := CURSOR if _focus == 0 and i == selected_index else "  "
		var rate := int(dd.get_exploration_rate() * 100)
		_list_labels[i].text = "%s%s  %dx%d  探索%d%%" % [prefix, dd.dungeon_name, dd.map_size, dd.map_size, rate]

	for i in range(_button_labels.size()):
		var prefix := CURSOR if _focus == 1 and i == _button_index else "  "
		var disabled := _is_button_disabled(i)
		_button_labels[i].text = prefix + BUTTON_ITEMS[i]
		_button_labels[i].add_theme_color_override(
			"font_color",
			Color(0.5, 0.5, 0.5) if disabled else Color(1.0, 1.0, 1.0)
		)

func _is_button_disabled(index: int) -> bool:
	match index:
		0: return is_enter_disabled()  # 潜入する
		2: return is_delete_disabled()  # 破棄
		_: return false

func _unhandled_input(event: InputEvent) -> void:
	if _mode == 2:
		_handle_delete_confirm_input(event)
		return

	if event.is_action_pressed("ui_down"):
		if _focus == 0 and _registry.size() > 0:
			move_list_cursor(1)
		elif _focus == 1:
			_move_button_cursor(1)
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		if _focus == 0 and _registry.size() > 0:
			move_list_cursor(-1)
		elif _focus == 1:
			_move_button_cursor(-1)
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focus == 1:
			_activate_button()
		else:
			_focus = 1
			_button_index = 0
			_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _focus == 1:
			_focus = 0
			_update_labels()
		else:
			do_back()
		get_viewport().set_input_as_handled()

func _handle_delete_confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_confirm_delete()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_mode = 0
		get_viewport().set_input_as_handled()

func _move_button_cursor(direction: int) -> void:
	var count := BUTTON_ITEMS.size()
	for _i in range(count):
		_button_index = (_button_index + direction) % count
		if _button_index < 0:
			_button_index += count
		if not _is_button_disabled(_button_index):
			return

func _activate_button() -> void:
	if _is_button_disabled(_button_index):
		return
	match _button_index:
		0: do_enter()
		1: _open_create_dialog()
		2: _mode = 2  # delete confirm
		3: do_back()

func _open_create_dialog() -> void:
	_create_dialog = DungeonCreateDialog.new()
	_create_dialog.confirmed.connect(_on_create_confirmed)
	_create_dialog.cancelled.connect(_on_create_cancelled)
	add_child(_create_dialog)
	_mode = 1

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
	_mode = 0

func _confirm_delete() -> void:
	if selected_index >= 0 and selected_index < _registry.size():
		_registry.remove(selected_index)
		if selected_index >= _registry.size():
			selected_index = _registry.size() - 1
		_build_ui()
	_mode = 0

# --- Public API for testing ---

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
