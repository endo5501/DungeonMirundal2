class_name CombatSpellSelector
extends Control

signal spell_selected(spell: SpellData)
signal cancelled

var _title_label: Label
var _options_vbox: VBoxContainer
var _empty_label: Label
var _rows: Array[CursorMenuRow] = []
var _selected_index: int = 0
var _entries: Array = []  # Array[{spell: SpellData, usable: bool}]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _options_vbox != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.text = "呪文:"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)
	_empty_label = Label.new()
	_empty_label.text = "  (詠唱できる呪文がありません)"
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.visible = false
	vbox.add_child(_empty_label)


# Display the caster's spells for the chosen school, with rows disabled when
# their mp_cost exceeds the caster's current MP. `outside_battle = true` (ESC
# menu flow) further restricts the list to scope == OUTSIDE_OK.
func show_with(
	caster: Character,
	school: StringName,
	repo: SpellRepository,
	outside_battle: bool = false
) -> void:
	_ensure_ready()
	_entries.clear()
	if caster != null and repo != null:
		for sid in caster.known_spells:
			var spell: SpellData = repo.find(sid)
			if spell == null:
				continue
			if spell.school != school:
				continue
			if outside_battle and spell.scope != SpellData.Scope.OUTSIDE_OK:
				continue
			_entries.append({
				"spell": spell,
				"usable": caster.current_mp >= spell.mp_cost,
			})
	if _title_label != null:
		var caster_name: String = caster.character_name if caster != null else ""
		var current_mp: int = caster.current_mp if caster != null else 0
		_title_label.text = "%s の呪文 (MP %d):" % [caster_name, current_mp]
	_selected_index = _first_usable_index()
	visible = true
	_rebuild_rows()
	_refresh_rows()
	_empty_label.visible = _entries.is_empty()


func hide_selector() -> void:
	visible = false


func is_empty() -> bool:
	return _entries.is_empty()


func move_up() -> void:
	if _entries.is_empty():
		return
	_selected_index = (_selected_index - 1 + _entries.size()) % _entries.size()
	_refresh_rows()


func move_down() -> void:
	if _entries.is_empty():
		return
	_selected_index = (_selected_index + 1) % _entries.size()
	_refresh_rows()


func confirm_current() -> void:
	if _entries.is_empty():
		cancelled.emit()
		return
	var entry: Dictionary = _entries[_selected_index]
	if not entry.get("usable", false):
		return
	spell_selected.emit(entry.get("spell"))


func get_entries() -> Array:
	return _entries.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _ensure_ready() -> void:
	if _options_vbox == null:
		_build_ui()


func _first_usable_index() -> int:
	for i in range(_entries.size()):
		if _entries[i].get("usable", false):
			return i
	return 0


func _rebuild_rows() -> void:
	_rows.clear()
	for child in _options_vbox.get_children():
		_options_vbox.remove_child(child)
		child.queue_free()
	for entry in _entries:
		var spell: SpellData = entry.get("spell")
		var text := "%s  (MP %d)" % [spell.display_name, spell.mp_cost]
		var row := CursorMenuRow.create(_options_vbox, text, 14)
		if not entry.get("usable", false):
			row.set_disabled(true)
		_rows.append(row)


func _refresh_rows() -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == _selected_index)
