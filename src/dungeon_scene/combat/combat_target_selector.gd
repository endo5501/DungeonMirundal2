class_name CombatTargetSelector
extends Control

signal target_selected(target: CombatActor)
signal cancelled

var _title_label: Label
var _options_vbox: VBoxContainer
var _rows: Array[CursorMenuRow] = []
var _selected_index: int = 0
var _targets: Array = []  # Array[CombatActor] of cursor entries


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
	_title_label.text = "対象を選択:"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)


# Default mode (used by AttackCommand): cursor over each living monster individually.
func show_with(monsters: Array) -> void:
	_ensure_ready()
	_targets.clear()
	for m in monsters:
		if m != null and m.is_alive():
			_targets.append(m)
	_selected_index = 0
	visible = true
	_rebuild_rows()
	_refresh_rows()


# Spell-aware mode: build the cursor list per `spell.target_type`. For
# `ALLY_ALL`, no prompt is shown — the selector stays hidden and immediately
# emits a single confirmation; the receiver's CastCommand should pass `null`
# as `target` and the engine will fan out to all living party members.
func show_for_spell(spell: SpellData, party: Array, monsters: Array) -> void:
	_ensure_ready()
	_targets.clear()
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			for m in monsters:
				if m != null and m.is_alive():
					_targets.append(m)
		SpellData.TargetType.ENEMY_GROUP:
			# One representative living monster per species id.
			var seen: Dictionary = {}
			for m in monsters:
				if m == null or not m.is_alive():
					continue
				var sid: StringName = m.get_species_id()
				if seen.has(sid):
					continue
				seen[sid] = true
				_targets.append(m)
		SpellData.TargetType.ALLY_ONE:
			for p in party:
				if p != null and p.is_alive():
					_targets.append(p)
		SpellData.TargetType.ALLY_ALL:
			# No interactive prompt; immediately confirm with a null target.
			visible = false
			target_selected.emit(null)
			return
	_selected_index = 0
	visible = true
	_rebuild_rows()
	_refresh_rows()


func hide_selector() -> void:
	visible = false


func move_up() -> void:
	if _targets.is_empty():
		return
	_selected_index = (_selected_index - 1 + _targets.size()) % _targets.size()
	_refresh_rows()


func move_down() -> void:
	if _targets.is_empty():
		return
	_selected_index = (_selected_index + 1) % _targets.size()
	_refresh_rows()


func confirm_current() -> void:
	if _targets.is_empty():
		return
	target_selected.emit(_targets[_selected_index])


# Hook for the input router: emits `cancelled` so the CombatOverlay can revert
# the spell-cast flow to the SpellSelector without submitting a Cast command.
func request_cancel() -> void:
	cancelled.emit()


func select_at(index: int) -> void:
	if index < 0 or index >= _targets.size():
		return
	_selected_index = index
	target_selected.emit(_targets[_selected_index])


func get_targets() -> Array:
	return _targets.duplicate()


func get_selected_index() -> int:
	return _selected_index


func _ensure_ready() -> void:
	if _options_vbox == null:
		_build_ui()


func _rebuild_rows() -> void:
	_rows.clear()
	for child in _options_vbox.get_children():
		_options_vbox.remove_child(child)
		child.queue_free()
	for i in range(_targets.size()):
		_rows.append(CursorMenuRow.create(_options_vbox, _targets[i].actor_name, 16))


func _refresh_rows() -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == _selected_index)
