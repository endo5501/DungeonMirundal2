class_name StatusView
extends Control

signal back_requested

const EMPTY_PARTY_MESSAGE := "パーティが編成されていません"
const STATUS_LINE_NORMAL := "状態: 通常"
const SPELL_NONE := "(未習得)"
const EQUIPMENT_NONE := "(なし)"
const PORTRAIT_SIZE := Vector2(96, 96)
# Indexed by Equipment.ALL_SLOTS order
# (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY).
const SLOT_LABELS_JP: Array[String] = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]

var _members: Array[Character] = []
var _slot_indices: Array[int] = []
var _menu: CursorMenu
var _spell_repo: SpellRepository = null

var _root_hbox: HBoxContainer
var _left_pane: VBoxContainer
var _right_scroll: ScrollContainer
var _right_pane: VBoxContainer
var _empty_label: Label
var _member_rows: Array[CursorMenuRow] = []

# Right-pane labels held as fields for direct read-back from tests.
var _portrait_rect: TextureRect
var _header_label: Label
var _hp_label: Label
var _mp_label: Label
var _exp_label: Label
var _stats_label: Label
var _equipment_labels: Array[Label] = []
var _spell_labels: Array[Label] = []
var _status_label: Label


func _ready() -> void:
	_ensure_ui_built()


func setup(party: Array[Character]) -> void:
	_members = _filter_non_null(party)
	_ensure_ui_built()
	_rebuild()


# --- public test API ---

func get_member_count() -> int:
	return _members.size()


func get_selected_character() -> Character:
	if _members.is_empty() or _menu == null:
		return null
	var idx := _menu.selected_index
	if idx < 0 or idx >= _members.size():
		return null
	return _members[idx]


func is_empty_message_visible() -> bool:
	return _empty_label != null and _empty_label.visible


func get_portrait_texture() -> Texture2D:
	return _portrait_rect.texture if _portrait_rect != null else null


func get_header_line() -> String:
	return _header_label.text if _header_label != null else ""


func get_hp_line() -> String:
	return _hp_label.text if _hp_label != null else ""


func get_mp_line() -> String:
	return _mp_label.text if _mp_label != null else ""


func get_exp_line() -> String:
	return _exp_label.text if _exp_label != null else ""


func get_stats_line() -> String:
	return _stats_label.text if _stats_label != null else ""


func get_equipment_lines() -> Array[String]:
	var out: Array[String] = []
	for label in _equipment_labels:
		out.append(label.text)
	return out


func get_spell_lines() -> Array[String]:
	var out: Array[String] = []
	for label in _spell_labels:
		out.append(label.text)
	return out


func get_status_line_text() -> String:
	return _status_label.text if _status_label != null else ""


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(1)
		return true
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		return true
	if event.is_action_pressed("ui_accept"):
		# Status view is read-only; consume but do nothing so the parent
		# EscMenu's handle_input does not interpret accept on this view.
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


func _move_cursor(direction: int) -> void:
	if _menu == null:
		return
	_menu.move_cursor(direction)
	_menu.update_rows(_member_rows)
	_refresh_detail_pane()


func set_spell_repo(repo: SpellRepository) -> void:
	_spell_repo = repo


func refresh_detail() -> void:
	_refresh_detail_pane()


# --- internal ---

func _ensure_ui_built() -> void:
	if _root_hbox != null:
		return
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_root_hbox = HBoxContainer.new()
	_root_hbox.add_theme_constant_override("separation", 12)
	add_child(_root_hbox)

	_left_pane = VBoxContainer.new()
	_left_pane.custom_minimum_size = Vector2(180, 0)
	_left_pane.add_theme_constant_override("separation", 2)
	_root_hbox.add_child(_left_pane)

	_right_scroll = ScrollContainer.new()
	_right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_scroll.focus_mode = Control.FOCUS_NONE
	_root_hbox.add_child(_right_scroll)

	_right_pane = VBoxContainer.new()
	_right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_pane.add_theme_constant_override("separation", 4)
	_right_scroll.add_child(_right_pane)

	_empty_label = Label.new()
	_empty_label.text = EMPTY_PARTY_MESSAGE
	_empty_label.add_theme_font_size_override("font_size", 16)
	_empty_label.visible = false
	add_child(_empty_label)


func _rebuild() -> void:
	_clear_left_pane()
	_clear_right_pane()

	if _members.is_empty():
		_empty_label.visible = true
		_root_hbox.visible = false
		return

	_empty_label.visible = false
	_root_hbox.visible = true

	_menu = CursorMenu.new(_member_labels())
	for i in range(_members.size()):
		_member_rows.append(CursorMenuRow.create(_left_pane, _menu.items[i], 18))
	_menu.update_rows(_member_rows)

	_refresh_detail_pane()


func _refresh_detail_pane() -> void:
	_clear_right_pane()
	var ch := get_selected_character()
	if ch == null:
		return

	# Header row: portrait on the left, name/race/job/level stacked on right.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	_right_pane.add_child(header_row)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = PORTRAIT_SIZE
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture = _resolve_portrait_texture(ch)
	header_row.add_child(_portrait_rect)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_vbox)

	_header_label = Label.new()
	_header_label.text = _format_header(ch)
	_header_label.add_theme_font_size_override("font_size", 18)
	header_vbox.add_child(_header_label)

	_status_label = Label.new()
	_status_label.text = _format_status_line(ch)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	header_vbox.add_child(_status_label)

	_hp_label = _add_text_label("HP: %d/%d" % [ch.current_hp, ch.max_hp], 16)
	_mp_label = _add_text_label("MP: %d/%d" % [ch.current_mp, ch.max_mp], 16)
	_exp_label = _add_text_label(_format_exp(ch), 14)
	_stats_label = _add_text_label(_format_stats(ch), 14)

	_add_section_separator("装備")
	_equipment_labels.clear()
	for slot_index in range(Equipment.ALL_SLOTS.size()):
		var line := _format_equipment_line(ch, slot_index)
		_equipment_labels.append(_add_text_label(line, 14))

	_add_section_separator("じゅもん")
	_spell_labels.clear()
	for line in _format_spell_lines(ch):
		_spell_labels.append(_add_text_label(line, 14))


func _add_text_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	_right_pane.add_child(label)
	return label


func _add_section_separator(title: String) -> void:
	var sep := HSeparator.new()
	_right_pane.add_child(sep)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_right_pane.add_child(head)


func _resolve_portrait_texture(ch: Character) -> Texture2D:
	if ch == null:
		return null
	var data := ch.to_party_member_data()
	return JobPortrait.texture_for(data.job_id)


func _format_header(ch: Character) -> String:
	var race_name := ch.race.race_name if ch.race != null else ""
	var job_name := ch.job.job_name if ch.job != null else ""
	return "%s  %s / %s  Lv.%d" % [ch.character_name, race_name, job_name, ch.level]


func _format_status_line(ch: Character) -> String:
	if ch == null or ch.persistent_statuses.is_empty():
		return STATUS_LINE_NORMAL
	var repo := StatusRepoLocator.resolve(null)
	var names: Array[String] = []
	for sid in ch.persistent_statuses:
		names.append(repo.get_display_name(sid))
	return "状態: " + ", ".join(names)


func _format_exp(ch: Character) -> String:
	if ch.job == null:
		return "EXP: %d" % ch.accumulated_exp
	var max_level := ch.job.exp_table.size() + 1
	if ch.level >= max_level:
		return "EXP: %d (MAX)" % ch.accumulated_exp
	var next_threshold := ch.job.exp_to_reach_level(ch.level + 1)
	return "EXP: %d / %d" % [ch.accumulated_exp, next_threshold]


func _format_stats(ch: Character) -> String:
	var parts: Array[String] = []
	for key in Character.STAT_KEYS:
		parts.append("%s:%d" % [String(key), ch.base_stats.get(key, 0)])
	return " ".join(parts)


func _format_equipment_line(ch: Character, slot_index: int) -> String:
	var slot: int = Equipment.ALL_SLOTS[slot_index]
	var label: String = SLOT_LABELS_JP[slot_index]
	var inst: ItemInstance = ch.equipment.get_equipped(slot)
	if inst == null or inst.item == null:
		return "%s: %s" % [label, EQUIPMENT_NONE]
	var name_str: String = inst.item.item_name if inst.identified else inst.item.unidentified_name
	return "%s: %s" % [label, name_str]


func _format_spell_lines(ch: Character) -> Array[String]:
	if ch.known_spells.is_empty():
		return [SPELL_NONE]
	var out: Array[String] = []
	var repo := _get_spell_repo()
	for sid in ch.known_spells:
		var data: SpellData = repo.find(sid) if repo != null else null
		if data != null and data.display_name != "":
			out.append(data.display_name)
		else:
			out.append(String(sid))
	return out


func _member_labels() -> Array[String]:
	var labels: Array[String] = []
	for i in range(_members.size()):
		var ch: Character = _members[i]
		var slot_index: int = _slot_indices[i] if i < _slot_indices.size() else i
		labels.append("%d. %s" % [slot_index + 1, ch.character_name])
	return labels


func _filter_non_null(party: Array[Character]) -> Array[Character]:
	var out: Array[Character] = []
	_slot_indices.clear()
	for i in range(party.size()):
		var ch: Character = party[i]
		if ch != null:
			out.append(ch)
			_slot_indices.append(i)
	return out


func _clear_left_pane() -> void:
	for row in _member_rows:
		row.queue_free()
	_member_rows.clear()
	_menu = null


func _clear_right_pane() -> void:
	for child in _right_pane.get_children():
		child.queue_free()
	_portrait_rect = null
	_header_label = null
	_hp_label = null
	_mp_label = null
	_exp_label = null
	_stats_label = null
	_equipment_labels.clear()
	_spell_labels.clear()
	_status_label = null


func _get_spell_repo() -> SpellRepository:
	if _spell_repo == null:
		var loader := DataLoader.new()
		_spell_repo = loader.load_spell_repository()
	return _spell_repo
