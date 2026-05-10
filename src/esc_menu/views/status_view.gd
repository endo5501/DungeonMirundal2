class_name StatusView
extends Control

signal back_requested

const EMPTY_PARTY_MESSAGE := "パーティが編成されていません"
const STATUS_LINE_NORMAL := "状態: 通常"

var _members: Array[Character] = []
var _menu: CursorMenu
var _spell_repo: SpellRepository = null

var _root_hbox: HBoxContainer
var _left_pane: VBoxContainer
var _right_scroll: ScrollContainer
var _right_pane: VBoxContainer
var _empty_label: Label
var _member_rows: Array[CursorMenuRow] = []
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
	if _members.is_empty():
		return null
	if _menu == null:
		return null
	var idx := _menu.selected_index
	if idx < 0 or idx >= _members.size():
		return null
	return _members[idx]


func is_empty_message_visible() -> bool:
	return _empty_label != null and _empty_label.visible


func get_status_line_text() -> String:
	if _status_label == null:
		return ""
	return _status_label.text


func handle_input(_event: InputEvent) -> bool:
	# Wired in Step 4 (cursor navigation).
	return false


func set_spell_repo(repo: SpellRepository) -> void:
	_spell_repo = repo


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
	_status_label = _build_status_label(ch)
	_right_pane.add_child(_status_label)


func _build_status_label(ch: Character) -> Label:
	var label := Label.new()
	label.text = _format_status_line(ch)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	return label


func _format_status_line(ch: Character) -> String:
	if ch == null or ch.persistent_statuses.is_empty():
		return STATUS_LINE_NORMAL
	var repo := StatusRepoLocator.resolve(null)
	var names: Array[String] = []
	for sid in ch.persistent_statuses:
		names.append(repo.get_display_name(sid))
	return "状態: " + ", ".join(names)


func _member_labels() -> Array[String]:
	var labels: Array[String] = []
	for i in range(_members.size()):
		var ch: Character = _members[i]
		var slot_index := _slot_index_for_member(i)
		labels.append("%d. %s" % [slot_index + 1, ch.character_name])
	return labels


# Each entry in _members corresponds to a guild slot (front 0..2 then back
# 0..2). Returns the original 0..5 slot index for the i-th non-null member.
func _slot_index_for_member(i: int) -> int:
	if i < 0 or i >= _members.size():
		return i
	# _members preserves insertion order; rebuild the original 0..5 mapping.
	# We tracked that during _filter_non_null; recover it from _slot_indices.
	return _slot_indices[i]


var _slot_indices: Array[int] = []


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
	_status_label = null


func _get_spell_repo() -> SpellRepository:
	if _spell_repo == null:
		var loader := DataLoader.new()
		_spell_repo = loader.load_spell_repository()
	return _spell_repo
