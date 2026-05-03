class_name ItemUseFlow
extends Control

signal flow_completed(message: String)
signal town_return_requested
signal combat_item_selected(instance: ItemInstance, target: Character)

enum SubView { SELECT_ITEM, SELECT_TARGET, CONFIRM, RESULT }

var _sub_view: int = SubView.SELECT_ITEM
var _context: ItemUseContext
var _inventory: Inventory
var _party: Array[Character] = []
var _combat_command_mode: bool = false

var _items_index: int = 0
var _target_index: int = 0
var _confirm_index: int = 0
var _selected_item: ItemInstance = null
var _selected_target: Character = null
var _result_message: String = ""

var _select_item_container: VBoxContainer
var _select_target_container: VBoxContainer
var _confirm_container: VBoxContainer
var _result_container: VBoxContainer


func _ready() -> void:
	_ensure_ui_built()
	_apply_visibility()


func setup(p_context: ItemUseContext, p_inventory: Inventory, p_party: Array[Character]) -> void:
	_setup(p_context, p_inventory, p_party, false)


func setup_for_combat(p_context: ItemUseContext, p_inventory: Inventory, p_party: Array[Character]) -> void:
	_setup(p_context, p_inventory, p_party, true)


func _setup(
	p_context: ItemUseContext,
	p_inventory: Inventory,
	p_party: Array[Character],
	p_combat_command_mode: bool
) -> void:
	_context = p_context
	_inventory = p_inventory
	_party = p_party
	_combat_command_mode = p_combat_command_mode
	_items_index = 0
	_target_index = 0
	_confirm_index = 0
	_selected_item = null
	_selected_target = null
	_result_message = ""
	_ensure_ui_built()
	_switch_sub_view(SubView.SELECT_ITEM)


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
	if _select_item_container != null:
		return
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_select_item_container = TitledView.build("アイテム", 4)
	root.add_child(_select_item_container)
	_select_target_container = TitledView.build("対象を選択", 4)
	root.add_child(_select_target_container)
	_confirm_container = TitledView.build("アイテム使用", 6)
	root.add_child(_confirm_container)
	_result_container = TitledView.build("結果", 6)
	root.add_child(_result_container)


# --- sub-view dispatch ---

func _switch_sub_view(view: int) -> void:
	_sub_view = view
	match view:
		SubView.SELECT_ITEM:
			_refresh_select_item()
		SubView.SELECT_TARGET:
			_target_index = _first_valid_target_index()
			_refresh_select_target()
		SubView.CONFIRM:
			_confirm_index = 0
			_refresh_confirm()
		SubView.RESULT:
			_refresh_result()
	_apply_visibility()


func _apply_visibility() -> void:
	if _select_item_container == null:
		return
	_select_item_container.visible = (_sub_view == SubView.SELECT_ITEM)
	_select_target_container.visible = (_sub_view == SubView.SELECT_TARGET)
	_confirm_container.visible = (_sub_view == SubView.CONFIRM)
	_result_container.visible = (_sub_view == SubView.RESULT)


func _move_cursor(direction: int) -> void:
	match _sub_view:
		SubView.SELECT_ITEM:
			var count := _list_items().size()
			if count == 0:
				return
			_items_index = (_items_index + direction + count) % count
			_refresh_select_item()
		SubView.SELECT_TARGET:
			var pcount := _list_targets().size()
			if pcount == 0:
				return
			_target_index = (_target_index + direction + pcount) % pcount
			_refresh_select_target()
		SubView.CONFIRM:
			_confirm_index = (_confirm_index + direction + 2) % 2
			_refresh_confirm()


func _handle_accept() -> void:
	match _sub_view:
		SubView.SELECT_ITEM:
			_on_select_item_accept()
		SubView.SELECT_TARGET:
			_on_select_target_accept()
		SubView.CONFIRM:
			_on_confirm_accept()
		SubView.RESULT:
			flow_completed.emit(_result_message)


func _handle_cancel() -> void:
	match _sub_view:
		SubView.SELECT_ITEM:
			flow_completed.emit("")
		SubView.SELECT_TARGET:
			_selected_item = null
			_switch_sub_view(SubView.SELECT_ITEM)
		SubView.CONFIRM:
			if _has_targets():
				_switch_sub_view(SubView.SELECT_TARGET)
			else:
				_selected_item = null
				_switch_sub_view(SubView.SELECT_ITEM)
		SubView.RESULT:
			flow_completed.emit(_result_message)


# --- accept handlers ---

func _on_select_item_accept() -> void:
	var items := _list_items()
	if _items_index < 0 or _items_index >= items.size():
		return
	var inst: ItemInstance = items[_items_index]
	if not inst.item.is_consumable():
		return
	if inst.item.get_context_failure_reason(_context) != "":
		return
	_selected_item = inst
	if _has_targets():
		if _combat_command_mode and _list_targets().is_empty():
			_selected_item = null
			return
		_switch_sub_view(SubView.SELECT_TARGET)
	else:
		_switch_sub_view(SubView.CONFIRM)


func _on_select_target_accept() -> void:
	var targets := _list_targets()
	if _selected_item == null or targets.is_empty():
		return
	if _target_index < 0 or _target_index >= targets.size():
		return
	var target: Character = targets[_target_index]
	_selected_target = target
	_switch_sub_view(SubView.CONFIRM)


func _on_confirm_accept() -> void:
	if _confirm_index == 1:
		_selected_item = null
		_selected_target = null
		_switch_sub_view(SubView.SELECT_ITEM)
		return
	if _selected_item == null or _inventory == null:
		_switch_sub_view(SubView.SELECT_ITEM)
		return
	var targets: Array = []
	if _selected_target != null:
		targets.append(_selected_target)
	var used_inst := _selected_item
	if _combat_command_mode:
		var used_target := _selected_target
		_selected_item = null
		_selected_target = null
		combat_item_selected.emit(used_inst, used_target)
		return
	var result: ItemEffectResult = _inventory.use_item(_selected_item, targets, _context)
	_selected_item = null
	_selected_target = null
	if result != null and result.success:
		_result_message = "%s を使った" % used_inst.item.item_name
		if result.request_town_return:
			town_return_requested.emit()
	else:
		var msg := result.message if result != null else "使用失敗"
		_result_message = "使用失敗: %s" % msg
	_switch_sub_view(SubView.RESULT)


# --- helpers ---

func _has_targets() -> bool:
	return _selected_item != null and not _selected_item.item.target_conditions.is_empty()


func _list_items() -> Array[ItemInstance]:
	if _inventory == null:
		return [] as Array[ItemInstance]
	var result: Array[ItemInstance] = []
	for inst in _inventory.list():
		if inst != null and inst.item != null and inst.item.is_consumable():
			result.append(inst)
	return result


func _list_targets() -> Array[Character]:
	if not _combat_command_mode:
		return _party
	var result: Array[Character] = []
	if _selected_item == null:
		return result
	for ch in _party:
		if _selected_item.item.get_target_failure_reason(ch, _context) == "":
			result.append(ch)
	return result


func _first_valid_target_index() -> int:
	if _selected_item == null:
		return 0
	return 0


# --- refresh views ---

func _refresh_select_item() -> void:
	TitledView.clear_extras(_select_item_container)
	if _inventory == null:
		return
	var instances := _list_items()
	if instances.is_empty():
		var empty := Label.new()
		empty.text = "  (アイテムなし)"
		empty.add_theme_font_size_override("font_size", 14)
		_select_item_container.add_child(empty)
		return
	if _items_index >= instances.size():
		_items_index = maxi(0, instances.size() - 1)
	for i in range(instances.size()):
		var inst: ItemInstance = instances[i]
		var display_name: String = inst.item.item_name if inst.identified else inst.item.unidentified_name
		var usable: bool = inst.item.is_consumable()
		var context_failure: String = inst.item.get_context_failure_reason(_context) if usable else ""
		var text: String = "  %s" % display_name
		if usable and context_failure != "":
			text = "  %s  (%s)" % [display_name, context_failure]
		var row := CursorMenuRow.create(_select_item_container, text, 14)
		row.set_selected(i == _items_index)
		if not usable or context_failure != "":
			row.set_disabled(true)


func _refresh_select_target() -> void:
	TitledView.clear_extras(_select_target_container)
	if _selected_item == null:
		return
	var item_label := Label.new()
	item_label.text = "使用: %s" % _selected_item.item.item_name
	item_label.add_theme_font_size_override("font_size", 16)
	_select_target_container.add_child(item_label)
	var targets := _list_targets()
	for i in range(targets.size()):
		var ch: Character = targets[i]
		var reason := _selected_item.item.get_target_failure_reason(ch, _context)
		var valid := reason == ""
		var line: String
		if valid:
			line = "  %s  HP:%d/%d MP:%d/%d" % [ch.character_name, ch.current_hp, ch.max_hp, ch.current_mp, ch.max_mp]
		else:
			line = "  %s  (%s)" % [ch.character_name, reason]
		var row := CursorMenuRow.create(_select_target_container, line, 14)
		row.set_selected(i == _target_index)
		if not valid:
			row.set_disabled(true)


func _refresh_confirm() -> void:
	TitledView.clear_extras(_confirm_container)
	if _selected_item == null:
		return
	var label := Label.new()
	label.text = "%s を使いますか？" % _selected_item.item.item_name
	label.add_theme_font_size_override("font_size", 16)
	_confirm_container.add_child(label)
	var options := ["はい", "いいえ"]
	for i in range(options.size()):
		var row := CursorMenuRow.create(_confirm_container, options[i], 16)
		row.set_selected(i == _confirm_index)


func _refresh_result() -> void:
	TitledView.clear_extras(_result_container)
	var label := Label.new()
	label.text = _result_message
	label.add_theme_font_size_override("font_size", 16)
	_result_container.add_child(label)
