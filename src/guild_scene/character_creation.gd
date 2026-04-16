class_name CharacterCreation
extends Control

signal back_requested
signal character_created

const FONT_SIZE := 18
const TITLE_SIZE := 24
const CURSOR := "> "

var current_step: int = 1
var total_steps: int = 5

var _guild: Guild
var _races: Array[RaceData]
var _jobs: Array[JobData]

var _name_input: String = ""
var _selected_race_index: int = -1
var _selected_job_index: int = -1

var _bonus_total: int = 0
var _allocation: Dictionary = {}
var _bonus_generator: BonusPointGenerator
var _cached_character: Character

var _content: VBoxContainer
var _name_edit: LineEdit
var _step_label: Label
var _cursor_index: int = 0
var _step_changed_frame: int = -1

func setup(guild: Guild, races: Array[RaceData], jobs: Array[JobData]) -> void:
	_guild = guild
	_races = races
	_jobs = jobs
	_bonus_generator = BonusPointGenerator.new(randi())

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	center.add_child(root)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_step_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	root.add_child(spacer)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	root.add_child(_content)

	_build_step_ui()

func _build_step_ui() -> void:
	_step_changed_frame = Engine.get_process_frames()
	while _content.get_child_count() > 0:
		var child := _content.get_child(0)
		_content.remove_child(child)
		child.queue_free()
	_cursor_index = 0

	match current_step:
		1: _build_step1()
		2: _build_step2()
		3: _build_step3()
		4: _build_step4()
		5: _build_step5()

func _build_step1() -> void:
	_step_label.text = "Step %d/%d - 名前入力" % [current_step, total_steps]
	_add_label("名前を入力してください:")
	_name_edit = LineEdit.new()
	_name_edit.text = _name_input
	_name_edit.custom_minimum_size.x = 200
	_name_edit.text_changed.connect(func(t: String): set_name_input(t))
	_name_edit.text_submitted.connect(_on_name_submitted)
	_content.add_child(_name_edit)
	_name_edit.grab_focus()
	_add_nav_hint("[Enter] 次へ  [Esc] やめる")

func _build_step2() -> void:
	_step_label.text = "Step %d/%d - 種族選択" % [current_step, total_steps]
	for i in range(_races.size()):
		var race := _races[i]
		var stats := race.get_base_stats()
		var text := "%s  STR:%d INT:%d PIE:%d VIT:%d AGI:%d LUC:%d" % [
			race.race_name, stats[&"STR"], stats[&"INT"], stats[&"PIE"],
			stats[&"VIT"], stats[&"AGI"], stats[&"LUC"]]
		_add_label(text)
	if _selected_race_index >= 0:
		_cursor_index = _selected_race_index
	_update_list_cursor(_races.size())
	_add_nav_hint("[↑↓] 選択  [Enter] 次へ  [Backspace] 戻る  [Esc] やめる")

func _build_step3() -> void:
	_step_label.text = "Step %d/%d - ボーナスポイント配分" % [current_step, total_steps]
	_add_label("ボーナスポイント: %d  残り: %d" % [_bonus_total, get_remaining_points()])
	_add_label("")
	for key in Character.STAT_KEYS:
		_add_label("  %s: %d" % [key, get_stat_value(key)])
	_update_list_cursor(Character.STAT_KEYS.size(), 2)  # offset by 2 for header labels
	_add_nav_hint("[↑↓] 選択  [→] +1  [←] -1  [R] 振り直し  [Enter] 次へ  [Backspace] 戻る  [Esc] やめる")

func _build_step4() -> void:
	_step_label.text = "Step %d/%d - 職業選択" % [current_step, total_steps]
	var qualified := get_qualified_jobs()
	for i in range(_jobs.size()):
		var job := _jobs[i]
		var suffix := ""
		if job.has_magic:
			suffix = "  HP:%d  MP:%d" % [job.base_hp, job.base_mp]
		else:
			suffix = "  HP:%d" % job.base_hp
		var text := job.job_name + suffix
		if not qualified.get(i, false):
			text += "  (条件未達)"
		_add_label(text)
	if _selected_job_index >= 0:
		_cursor_index = _selected_job_index
	_update_list_cursor(_jobs.size())
	_add_nav_hint("[↑↓] 選択  [Enter] 決定  [Backspace] 戻る  [Esc] やめる")

func _build_step5() -> void:
	_step_label.text = "Step %d/%d - 確認" % [current_step, total_steps]
	var s := get_summary()
	if s.is_empty():
		_add_label("エラー: キャラクターを作成できません")
		return
	_add_label("名前: %s" % s["name"])
	_add_label("種族: %s    職業: %s" % [s["race"].race_name, s["job"].job_name])
	_add_label("LV: %d    HP: %d    MP: %d" % [s["level"], s["hp"], s["mp"]])
	_add_label("")
	var st: Dictionary = s["stats"]
	_add_label("STR:%d  INT:%d  PIE:%d" % [st[&"STR"], st[&"INT"], st[&"PIE"]])
	_add_label("VIT:%d  AGI:%d  LUC:%d" % [st[&"VIT"], st[&"AGI"], st[&"LUC"]])
	_add_label("")
	_add_label("この内容で作成しますか？")
	_add_nav_hint("[Enter] 作成  [Backspace] 戻る  [Esc] やめる")

func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	_content.add_child(label)
	return label

func _add_nav_hint(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_content.add_child(spacer)
	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content.add_child(hint)

func _update_list_cursor(count: int, offset: int = 0) -> void:
	var children := _content.get_children()
	for i in range(count):
		var idx := i + offset
		if idx < children.size() and children[idx] is Label:
			var label := children[idx] as Label
			var raw := label.text
			if raw.begins_with(CURSOR) or raw.begins_with("  "):
				raw = raw.substr(2)
			var prefix := CURSOR if i == _cursor_index else "  "
			label.text = prefix + raw

func _unhandled_input(event: InputEvent) -> void:
	if _step_changed_frame == Engine.get_process_frames():
		return
	match current_step:
		1: _input_step1(event)
		2: _input_step2(event)
		3: _input_step3(event)
		4: _input_step4(event)
		5: _input_step5(event)

func _input_step1(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _name_edit and not _name_edit.has_focus():
		_name_edit.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func _input_step2(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_cursor_index = (_cursor_index + 1) % _races.size()
		_update_list_cursor(_races.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_cursor_index = (_cursor_index - 1 + _races.size()) % _races.size()
		_update_list_cursor(_races.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		select_race(_cursor_index)
		advance()
		if current_step == 3:
			_build_step_ui()
		get_viewport().set_input_as_handled()
	elif _is_back_pressed(event):
		go_back()
		_build_step_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func _input_step3(event: InputEvent) -> void:
	var stat_count := Character.STAT_KEYS.size()
	if event.is_action_pressed("ui_down"):
		_cursor_index = (_cursor_index + 1) % stat_count
		_update_list_cursor(stat_count, 2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_cursor_index = (_cursor_index - 1 + stat_count) % stat_count
		_update_list_cursor(stat_count, 2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		increment_stat(Character.STAT_KEYS[_cursor_index])
		_rebuild_step3_values()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		decrement_stat(Character.STAT_KEYS[_cursor_index])
		_rebuild_step3_values()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reroll_bonus()
		_rebuild_step3_values()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		advance()
		if current_step == 4:
			_build_step_ui()
		get_viewport().set_input_as_handled()
	elif _is_back_pressed(event):
		go_back()
		_build_step_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func _rebuild_step3_values() -> void:
	var children := _content.get_children()
	if children.size() > 0 and children[0] is Label:
		(children[0] as Label).text = "ボーナスポイント: %d  残り: %d" % [_bonus_total, get_remaining_points()]
	for i in range(Character.STAT_KEYS.size()):
		var idx := i + 2
		if idx < children.size() and children[idx] is Label:
			var key := Character.STAT_KEYS[i]
			var prefix := CURSOR if i == _cursor_index else "  "
			(children[idx] as Label).text = "%s%s: %d" % [prefix, key, get_stat_value(key)]

func _input_step4(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_cursor_index = (_cursor_index + 1) % _jobs.size()
		_update_list_cursor(_jobs.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_cursor_index = (_cursor_index - 1 + _jobs.size()) % _jobs.size()
		_update_list_cursor(_jobs.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var qualified := get_qualified_jobs()
		if qualified.get(_cursor_index, false):
			select_job(_cursor_index)
			advance()
			if current_step == 5:
				_build_step_ui()
		get_viewport().set_input_as_handled()
	elif _is_back_pressed(event):
		go_back()
		_build_step_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func _input_step5(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		confirm_creation()
		get_viewport().set_input_as_handled()
	elif _is_back_pressed(event):
		go_back()
		_build_step_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()

func _is_back_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE

func _on_name_submitted(_text: String) -> void:
	_name_input = _name_edit.text
	advance()
	if current_step == 2:
		_build_step_ui()

func set_name_input(value: String) -> void:
	_name_input = value

func get_available_races() -> Array[RaceData]:
	return _races

func select_race(index: int) -> void:
	_selected_race_index = index

func select_job(index: int) -> void:
	_selected_job_index = index

func get_bonus_total() -> int:
	return _bonus_total

func get_remaining_points() -> int:
	var used := 0
	for key in _allocation:
		used += _allocation[key]
	return _bonus_total - used

func get_stat_value(stat: StringName) -> int:
	if _selected_race_index < 0:
		return 0
	var base_stats := _races[_selected_race_index].get_base_stats()
	return base_stats.get(stat, 0) + _allocation.get(stat, 0)

func increment_stat(stat: StringName) -> void:
	if get_remaining_points() <= 0:
		return
	_allocation[stat] = _allocation.get(stat, 0) + 1

func decrement_stat(stat: StringName) -> void:
	if _allocation.get(stat, 0) <= 0:
		return
	_allocation[stat] = _allocation[stat] - 1

func reroll_bonus() -> void:
	_bonus_total = _bonus_generator.generate()
	_reset_allocation()

func get_qualified_jobs() -> Dictionary:
	var result := {}
	var stats := _build_current_stats()
	for i in range(_jobs.size()):
		result[i] = _jobs[i].can_qualify(stats)
	return result

func get_summary() -> Dictionary:
	var race := _races[_selected_race_index]
	var job := _jobs[_selected_job_index]
	_cached_character = Character.create(_name_input, race, job, _allocation, _bonus_total)
	if _cached_character == null:
		return {}
	return {
		"name": _cached_character.character_name,
		"race": race,
		"job": job,
		"level": _cached_character.level,
		"hp": _cached_character.max_hp,
		"mp": _cached_character.max_mp,
		"stats": _cached_character.base_stats.duplicate(),
	}

func advance() -> void:
	match current_step:
		1:
			if _name_input.strip_edges() == "":
				return
			current_step = 2
		2:
			if _selected_race_index < 0:
				return
			_bonus_total = _bonus_generator.generate()
			_reset_allocation()
			current_step = 3
		3:
			if get_remaining_points() != 0:
				return
			current_step = 4
		4:
			if _selected_job_index < 0:
				return
			var stats := _build_current_stats()
			if not _jobs[_selected_job_index].can_qualify(stats):
				return
			current_step = 5
		5:
			pass

func go_back() -> void:
	match current_step:
		1:
			return
		3:
			_reset_allocation()
			_selected_race_index = -1
			current_step = 2
		4:
			_selected_job_index = -1
			current_step = 3
		_:
			current_step -= 1

func cancel() -> void:
	back_requested.emit()

func confirm_creation() -> void:
	if _cached_character == null:
		var race := _races[_selected_race_index]
		var job := _jobs[_selected_job_index]
		_cached_character = Character.create(_name_input, race, job, _allocation, _bonus_total)
	if _cached_character != null:
		_guild.register(_cached_character)
		character_created.emit()
	back_requested.emit()

func _reset_allocation() -> void:
	_allocation = {}
	for key in Character.STAT_KEYS:
		_allocation[key] = 0

func _build_current_stats() -> Dictionary:
	var stats := {}
	for key in Character.STAT_KEYS:
		stats[key] = get_stat_value(key)
	return stats
