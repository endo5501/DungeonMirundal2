class_name PartyFormation
extends Control

signal back_requested

const FONT_SIZE := 18
const GRID_CURSOR_SLOT_WIDTH := 20.0

var _guild: Guild
var _party_slots: Array = []
var _waiting: Array[Character] = []

var _mode: int = 0  # 0=party grid, 1=waiting list
var _grid_index: int = 0  # 0-5
var _wait_index: int = 0
var _editing_name: bool = false

var _content: VBoxContainer
var _name_edit: LineEdit

func setup(guild: Guild) -> void:
	_guild = guild
	refresh()

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	center.add_child(root)

	var name_row := HBoxContainer.new()
	root.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "パーティ名: "
	name_label.add_theme_font_size_override("font_size", 20)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = get_party_name()
	_name_edit.custom_minimum_size.x = 200
	_name_edit.text_changed.connect(func(t: String): set_party_name(t))
	name_row.add_child(_name_edit)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	root.add_child(spacer)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	root.add_child(_content)

	_rebuild_display()

func _rebuild_display() -> void:
	while _content.get_child_count() > 0:
		var child := _content.get_child(0)
		_content.remove_child(child)
		child.queue_free()

	_add_section_label("パーティ")
	var row_names := ["前列", "後列"]
	for row in range(2):
		_build_grid_row(row, row_names[row])

	_add_label("")
	_add_section_label("待機中キャラクター")
	if _waiting.size() == 0:
		_add_label("  (なし)")
	else:
		for i in range(_waiting.size()):
			var ch := _waiting[i]
			var row := CursorMenuRow.create(
				_content,
				"%s  LV:%d  %s  %s" % [ch.character_name, ch.level, ch.race.race_name, ch.job.job_name],
				FONT_SIZE)
			row.set_selected(_mode == 1 and _wait_index == i)

	_add_label("")
	_add_hint("[↑↓←→] 選択  [Tab] パーティ/待機切替  [Enter] 追加/外す  [N] パーティ名変更  [Esc] 戻る")

func _build_grid_row(row: int, row_name: String) -> void:
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 0)
	_content.add_child(row_box)

	var header := Label.new()
	header.text = "  %s: " % row_name
	header.add_theme_font_size_override("font_size", FONT_SIZE)
	row_box.add_child(header)

	for pos in range(3):
		var slot_idx := row * 3 + pos
		_build_grid_slot(row_box, slot_idx)
		if pos < 2:
			var sep := Label.new()
			sep.text = "  "
			sep.add_theme_font_size_override("font_size", FONT_SIZE)
			row_box.add_child(sep)

func _build_grid_slot(parent: Control, slot_idx: int) -> void:
	var slot := HBoxContainer.new()
	slot.add_theme_constant_override("separation", 0)
	slot.set_meta("grid_slot_idx", slot_idx)
	parent.add_child(slot)

	var open := Label.new()
	open.text = "["
	open.add_theme_font_size_override("font_size", FONT_SIZE)
	slot.add_child(open)

	var cursor_slot := Control.new()
	cursor_slot.custom_minimum_size = Vector2(GRID_CURSOR_SLOT_WIDTH, 0)
	slot.add_child(cursor_slot)

	var cursor_label := Label.new()
	cursor_label.text = CursorMenuRow.CURSOR_GLYPH
	cursor_label.add_theme_font_size_override("font_size", FONT_SIZE)
	cursor_label.visible = _mode == 0 and _grid_index == slot_idx
	cursor_slot.add_child(cursor_label)

	slot.set_meta("cursor_slot", cursor_slot)
	slot.set_meta("cursor_label", cursor_label)

	var ch = _party_slots[slot_idx]
	var name_label := Label.new()
	name_label.text = ch.character_name if ch != null else "---"
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	slot.add_child(name_label)

	var close := Label.new()
	close.text = "]"
	close.add_theme_font_size_override("font_size", FONT_SIZE)
	slot.add_child(close)

func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	_content.add_child(label)

func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	_content.add_child(label)

func _add_hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if _editing_name:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_editing_name = false
			_name_edit.release_focus()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		_editing_name = true
		_name_edit.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_mode = 1 - _mode
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif _mode == 0:
		_input_grid(event)
	elif _mode == 1:
		_input_waiting(event)

func _input_grid(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		if _grid_index % 3 < 2:
			_grid_index += 1
			_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		if _grid_index % 3 > 0:
			_grid_index -= 1
			_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		if _grid_index < 3:
			_grid_index += 3
			_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		if _grid_index >= 3:
			_grid_index -= 3
			_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var row := _grid_index / 3
		var pos := _grid_index % 3
		if _party_slots[_grid_index] != null:
			remove_from_slot(row, pos)
			refresh()
			_rebuild_display()
		elif _waiting.size() > 0:
			_mode = 1
			_wait_index = 0
			_rebuild_display()
		get_viewport().set_input_as_handled()

func _input_waiting(event: InputEvent) -> void:
	if _waiting.size() == 0:
		return
	if event.is_action_pressed("ui_down"):
		_wait_index = (_wait_index + 1) % _waiting.size()
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_wait_index = (_wait_index - 1 + _waiting.size()) % _waiting.size()
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var row := _grid_index / 3
		var pos := _grid_index % 3
		add_to_slot(row, pos, _wait_index)
		refresh()
		_mode = 0
		_rebuild_display()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	_waiting = _guild.get_unassigned()
	_party_slots.resize(6)
	for i in range(3):
		_party_slots[i] = _guild.get_character_at(0, i)
		_party_slots[i + 3] = _guild.get_character_at(1, i)

func get_party_slots() -> Array:
	return _party_slots.duplicate()

func get_waiting_characters() -> Array[Character]:
	return _waiting

func add_to_slot(row: int, position: int, waiting_index: int) -> void:
	if waiting_index < 0 or waiting_index >= _waiting.size():
		return
	var ch := _waiting[waiting_index]
	_guild.assign_to_party(ch, row, position)

func remove_from_slot(row: int, position: int) -> void:
	_guild.remove_from_party(row, position)

func get_party_name() -> String:
	return _guild.party_name

func set_party_name(value: String) -> void:
	_guild.party_name = value

func go_back() -> void:
	back_requested.emit()
