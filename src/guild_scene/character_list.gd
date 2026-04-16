class_name CharacterList
extends Control

signal back_requested

const FONT_SIZE := 18
const CURSOR := "> "

var _guild: Guild
var _characters: Array[Character] = []
var _pending_delete_index: int = -1

var _view_mode: int = 0  # 0=list, 1=detail, 2=delete confirm
var _cursor_index: int = 0
var _confirm_cursor: int = 0  # 0=いいえ, 1=はい

var _content: VBoxContainer
var _title_label: Label

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

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_label)

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

	match _view_mode:
		0: _build_list_view()
		1: _build_detail_view()
		2: _build_delete_confirm()

func _build_list_view() -> void:
	_title_label.text = "キャラクター一覧"
	if _characters.size() == 0:
		_add_label("  登録されたキャラクターはいません")
	else:
		for i in range(_characters.size()):
			var ch := _characters[i]
			var status := _get_status(ch)
			var prefix := CURSOR if i == _cursor_index else "  "
			_add_label("%s%s  LV:%d  %s  %s  [%s]" % [
				prefix, ch.character_name, ch.level,
				ch.race.race_name, ch.job.job_name, status])
	_add_label("")
	_add_hint("[↑↓] 選択  [Enter] 詳細  [D] 削除  [Esc] 戻る")

func _build_detail_view() -> void:
	if _cursor_index >= _characters.size():
		return
	var detail := get_character_detail(_cursor_index)
	_title_label.text = "%s の詳細" % detail.character_name
	_add_label("名前: %s     種族: %s    職業: %s" % [detail.character_name, detail.race_name, detail.job_name])
	_add_label("LV: %d       HP: %d/%d   MP: %d/%d" % [detail.level, detail.current_hp, detail.max_hp, detail.current_mp, detail.max_mp])
	_add_label("")
	var st: Dictionary = detail.stats
	_add_label("STR:%d  INT:%d  PIE:%d" % [st[&"STR"], st[&"INT"], st[&"PIE"]])
	_add_label("VIT:%d  AGI:%d  LUC:%d" % [st[&"VIT"], st[&"AGI"], st[&"LUC"]])
	_add_label("")
	_add_label("状態: %s" % detail.status)
	_add_label("")
	_add_hint("[Esc/Backspace] 戻る")

func _build_delete_confirm() -> void:
	if _pending_delete_index < 0:
		return
	var ch := _characters[_pending_delete_index]
	_title_label.text = "削除確認"
	_add_label("%s を削除しますか？" % ch.character_name)
	_add_label("")
	var no_prefix := CURSOR if _confirm_cursor == 0 else "  "
	var yes_prefix := CURSOR if _confirm_cursor == 1 else "  "
	_add_label("%sいいえ" % no_prefix)
	_add_label("%sはい" % yes_prefix)
	_add_label("")
	_add_hint("[↑↓] 選択  [Enter] 決定")

func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	_content.add_child(label)

func _add_hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	match _view_mode:
		0: _input_list(event)
		1: _input_detail(event)
		2: _input_delete_confirm(event)

func _input_list(event: InputEvent) -> void:
	if _characters.size() == 0:
		if event.is_action_pressed("ui_cancel"):
			go_back()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_cursor_index = (_cursor_index + 1) % _characters.size()
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_cursor_index = (_cursor_index - 1 + _characters.size()) % _characters.size()
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_view_mode = 1
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_D:
		if can_delete(_cursor_index):
			request_delete(_cursor_index)
			_confirm_cursor = 0
			_view_mode = 2
			_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func _input_detail(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or _is_back_pressed(event):
		_view_mode = 0
		_rebuild_display()
		get_viewport().set_input_as_handled()

func _input_delete_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		_confirm_cursor = 1 - _confirm_cursor
		_rebuild_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _confirm_cursor == 1:
			confirm_delete()
			refresh()
		else:
			cancel_delete()
		_view_mode = 0
		if _cursor_index >= _characters.size():
			_cursor_index = maxi(0, _characters.size() - 1)
		_rebuild_display()
		get_viewport().set_input_as_handled()

func _is_back_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE

func refresh() -> void:
	_characters = _guild.get_all_characters()

func get_character_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for ch in _characters:
		entries.append({
			"character_name": ch.character_name,
			"level": ch.level,
			"race_name": ch.race.race_name,
			"job_name": ch.job.job_name,
			"status": _get_status(ch),
		})
	return entries

func get_character_detail(index: int) -> Dictionary:
	var ch := _characters[index]
	return {
		"character_name": ch.character_name,
		"race_name": ch.race.race_name,
		"job_name": ch.job.job_name,
		"level": ch.level,
		"current_hp": ch.current_hp,
		"max_hp": ch.max_hp,
		"current_mp": ch.current_mp,
		"max_mp": ch.max_mp,
		"stats": ch.base_stats.duplicate(),
		"status": _get_status(ch),
	}

func can_delete(index: int) -> bool:
	var ch := _characters[index]
	return not _guild.is_in_party(ch)

func delete_character(index: int) -> void:
	var ch := _characters[index]
	_guild.remove(ch)

func request_delete(index: int) -> void:
	if can_delete(index):
		_pending_delete_index = index

func confirm_delete() -> void:
	if _pending_delete_index < 0:
		return
	delete_character(_pending_delete_index)
	_pending_delete_index = -1

func cancel_delete() -> void:
	_pending_delete_index = -1

func get_pending_delete_index() -> int:
	return _pending_delete_index

func go_back() -> void:
	back_requested.emit()

func _get_status(ch: Character) -> String:
	if _guild.is_in_party(ch):
		return "パーティ"
	return "待機中"
