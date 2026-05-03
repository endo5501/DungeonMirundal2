class_name EquipmentFlow
extends Control

signal flow_completed

enum SubView { CHARACTER, SLOT, CANDIDATE }

const _HEADER_CHILD_COUNT: int = 2  # title + spacer; see _build_titled_view

const SLOT_LABELS: Array[String] = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]

var _sub_view: int = SubView.CHARACTER
var _party: Array[Character] = []
var _inventory: Inventory
var _character_index: int = 0
var _slot_index: int = 0
var _candidate_index: int = 0

var _character_container: VBoxContainer
var _slot_container: VBoxContainer
var _candidate_container: VBoxContainer


func _ready() -> void:
	_ensure_ui_built()
	_apply_visibility()


func setup(p_party: Array[Character], p_inventory: Inventory) -> void:
	_party = p_party
	_inventory = p_inventory
	_character_index = 0
	_slot_index = 0
	_candidate_index = 0
	_ensure_ui_built()
	_switch_sub_view(SubView.CHARACTER)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(1)
		return true
	if event.is_action_pressed("ui_accept"):
		_handle_accept()
		return true
	if event.is_action_pressed("ui_cancel"):
		_handle_cancel()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


# --- UI construction ---

func _ensure_ui_built() -> void:
	if _character_container != null:
		return
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_character_container = _build_titled_view("装備 - キャラクター選択", 4)
	root.add_child(_character_container)
	_slot_container = _build_titled_view("装備 - スロット選択", 4)
	root.add_child(_slot_container)
	_candidate_container = _build_titled_view("装備 - 候補", 4)
	root.add_child(_candidate_container)


func _build_titled_view(title_text: String, separation: int = 6) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)
	return vbox


# --- sub-view dispatch ---

func _switch_sub_view(view: int) -> void:
	_sub_view = view
	match view:
		SubView.CHARACTER:
			_refresh_character()
		SubView.SLOT:
			_slot_index = 0
			_refresh_slot()
		SubView.CANDIDATE:
			_candidate_index = 0
			_refresh_candidate()
	_apply_visibility()


func _apply_visibility() -> void:
	if _character_container == null:
		return
	_character_container.visible = (_sub_view == SubView.CHARACTER)
	_slot_container.visible = (_sub_view == SubView.SLOT)
	_candidate_container.visible = (_sub_view == SubView.CANDIDATE)


func _move_cursor(direction: int) -> void:
	match _sub_view:
		SubView.CHARACTER:
			if _party.is_empty():
				return
			_character_index = (_character_index + direction + _party.size()) % _party.size()
			_refresh_character()
		SubView.SLOT:
			_slot_index = (_slot_index + direction + Equipment.ALL_SLOTS.size()) % Equipment.ALL_SLOTS.size()
			_refresh_slot()
		SubView.CANDIDATE:
			var rows := get_equipment_candidates().size() + 1
			_candidate_index = (_candidate_index + direction + rows) % rows
			_refresh_candidate()


func _handle_accept() -> void:
	match _sub_view:
		SubView.CHARACTER:
			_switch_sub_view(SubView.SLOT)
		SubView.SLOT:
			_switch_sub_view(SubView.CANDIDATE)
		SubView.CANDIDATE:
			_confirm_candidate()


func _handle_cancel() -> void:
	match _sub_view:
		SubView.CHARACTER:
			flow_completed.emit()
		SubView.SLOT:
			_switch_sub_view(SubView.CHARACTER)
		SubView.CANDIDATE:
			_switch_sub_view(SubView.SLOT)


# --- candidate confirm ---

func _confirm_candidate() -> void:
	var ch := _get_selected_character()
	if ch == null:
		return
	var slot_value := Equipment.ALL_SLOTS[_slot_index]
	if _candidate_index == 0:
		ch.equipment.unequip(slot_value)
	else:
		var candidates := get_equipment_candidates()
		var idx := _candidate_index - 1
		if idx >= 0 and idx < candidates.size():
			var instance: ItemInstance = candidates[idx]
			_unequip_from_other_holders(instance, ch)
			ch.equipment.equip(slot_value, instance, ch)
	_switch_sub_view(SubView.SLOT)


func _unequip_from_other_holders(instance: ItemInstance, exclude: Character) -> void:
	# If another character currently has this ItemInstance equipped, unequip it
	# there first so two characters don't share the same instance.
	for other in _party:
		if other == exclude or other == null or other.equipment == null:
			continue
		for slot in Equipment.ALL_SLOTS:
			if other.equipment.get_equipped(slot) == instance:
				other.equipment.unequip(slot)


# --- helpers ---

func _get_selected_character() -> Character:
	if _character_index < 0 or _character_index >= _party.size():
		return null
	return _party[_character_index]


func get_equipment_candidates() -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	var ch := _get_selected_character()
	if ch == null or _inventory == null:
		return results
	if _slot_index < 0 or _slot_index >= Equipment.ALL_SLOTS.size():
		return results
	var slot_value := Equipment.ALL_SLOTS[_slot_index]
	for inst in _inventory.list():
		if inst.item != null and Equipment.can_equip(inst.item, slot_value, ch):
			results.append(inst)
	return results


func _map_equipped_to_character_names() -> Dictionary:
	var result: Dictionary = {}
	for ch in _party:
		if ch == null or ch.equipment == null:
			continue
		for inst in ch.equipment.all_equipped():
			result[inst] = ch.character_name
	return result


# --- refresh views ---

func _refresh_character() -> void:
	_clear_extra_children(_character_container)
	if _party.is_empty():
		var empty := Label.new()
		empty.text = "  (パーティが編成されていません)"
		_character_container.add_child(empty)
		return
	for i in range(_party.size()):
		var ch: Character = _party[i]
		var row := CursorMenuRow.create(_character_container,
			"%s (Lv%d %s)" % [ch.character_name, ch.level, ch.job.job_name], 16)
		row.set_selected(i == _character_index)


func _refresh_slot() -> void:
	_clear_extra_children(_slot_container)
	var ch := _get_selected_character()
	if ch == null:
		return
	for i in range(SLOT_LABELS.size()):
		var slot_value := Equipment.ALL_SLOTS[i]
		var equipped := ch.equipment.get_equipped(slot_value)
		var equipped_name := "なし"
		if equipped != null and equipped.item != null:
			equipped_name = equipped.item.item_name
		var row := CursorMenuRow.create(_slot_container,
			"%s: %s" % [SLOT_LABELS[i], equipped_name], 16)
		row.set_selected(i == _slot_index)


func _refresh_candidate() -> void:
	_clear_extra_children(_candidate_container)
	var candidates := get_equipment_candidates()
	var unequip_row := CursorMenuRow.create(_candidate_container, "[はずす]", 16)
	unequip_row.set_selected(_candidate_index == 0)
	var equipped_by := _map_equipped_to_character_names()
	var self_ch := _get_selected_character()
	for i in range(candidates.size()):
		var inst: ItemInstance = candidates[i]
		var marker := ""
		if equipped_by.has(inst):
			var holder: String = equipped_by[inst]
			if self_ch != null and holder == self_ch.character_name:
				marker = " [装備中]"
			else:
				marker = " [装備中: %s]" % holder
		var row := CursorMenuRow.create(_candidate_container,
			"%s%s" % [inst.item.item_name, marker], 16)
		row.set_selected((i + 1) == _candidate_index)


func _clear_extra_children(container: VBoxContainer) -> void:
	while container.get_child_count() > _HEADER_CHILD_COUNT:
		var child := container.get_child(container.get_child_count() - 1)
		container.remove_child(child)
		child.queue_free()
