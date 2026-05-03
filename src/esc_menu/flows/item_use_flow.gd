class_name ItemUseFlow
extends Control

signal flow_completed(message: String)
signal town_return_requested

enum SubView { SELECT_ITEM, SELECT_TARGET, CONFIRM, RESULT }

const _HEADER_CHILD_COUNT: int = 2  # title + spacer; see _build_titled_view

var _sub_view: int = SubView.SELECT_ITEM
var _context: ItemUseContext
var _inventory: Inventory
var _party: Array[Character] = []

var _items_index: int = 0
var _target_index: int = 0
var _confirm_index: int = 0  # 0 = はい, 1 = いいえ
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
	_context = p_context
	_inventory = p_inventory
	_party = p_party
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
	_select_item_container = _build_titled_view("アイテム", 4)
	root.add_child(_select_item_container)
	_select_target_container = _build_titled_view("対象を選択", 4)
	root.add_child(_select_target_container)
	_confirm_container = _build_titled_view("アイテム使用", 6)
	root.add_child(_confirm_container)
	_result_container = _build_titled_view("結果", 6)
	root.add_child(_result_container)


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
			var pcount := _party.size()
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
		_switch_sub_view(SubView.SELECT_TARGET)
	else:
		_switch_sub_view(SubView.CONFIRM)


func _on_select_target_accept() -> void:
	if _selected_item == null or _party.is_empty():
		return
	if _target_index < 0 or _target_index >= _party.size():
		return
	var target: Character = _party[_target_index]
	if _selected_item.item.get_target_failure_reason(target, _context) != "":
		return
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
	return _inventory.list()


func _first_valid_target_index() -> int:
	if _selected_item == null:
		return 0
	for i in range(_party.size()):
		if _selected_item.item.get_target_failure_reason(_party[i], _context) == "":
			return i
	return 0


# --- refresh views ---

func _refresh_select_item() -> void:
	_clear_extra_children(_select_item_container)
	if _inventory == null:
		return
	var instances := _inventory.list()
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
		var context_failure := ""
		if usable:
			context_failure = inst.item.get_context_failure_reason(_context)
		var text: String
		if usable and context_failure == "":
			text = "  %s" % display_name
		elif usable:
			text = "  %s  (%s)" % [display_name, context_failure]
		else:
			text = "  %s" % display_name
		var row := CursorMenuRow.create(_select_item_container, text, 14)
		row.set_selected(i == _items_index)
		if not usable or context_failure != "":
			row.set_disabled(true)


func _refresh_select_target() -> void:
	_clear_extra_children(_select_target_container)
	if _selected_item == null:
		return
	var item_label := Label.new()
	item_label.text = "使用: %s" % _selected_item.item.item_name
	item_label.add_theme_font_size_override("font_size", 16)
	_select_target_container.add_child(item_label)
	for i in range(_party.size()):
		var ch: Character = _party[i]
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
	_clear_extra_children(_confirm_container)
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
	_clear_extra_children(_result_container)
	var label := Label.new()
	label.text = _result_message
	label.add_theme_font_size_override("font_size", 16)
	_result_container.add_child(label)


func _clear_extra_children(container: VBoxContainer) -> void:
	while container.get_child_count() > _HEADER_CHILD_COUNT:
		var child := container.get_child(container.get_child_count() - 1)
		container.remove_child(child)
		child.queue_free()
