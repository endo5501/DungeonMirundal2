class_name ShopScreen
extends Control

signal back_requested

enum Mode { TOP_MENU, BUY, SELL }
enum Tab { EQUIPMENT, CONSUMABLE }

const TOP_MENU_ITEMS: Array[String] = ["購入する", "売却する", "出る"]
const TOP_IDX_BUY: int = 0
const TOP_IDX_SELL: int = 1
const TOP_IDX_EXIT: int = 2
const FONT_SIZE: int = 18
const TAB_LABELS: Array[String] = ["装備品", "消費アイテム"]

var _inventory: Inventory
var _guild: Guild
var _shop_inventory: ShopInventory

var _top_menu: CursorMenu
var _mode: Mode = Mode.TOP_MENU
var _tab: Tab = Tab.EQUIPMENT
var _selected_index: int = 0
var _last_message: String = ""

var _root: VBoxContainer


func _init() -> void:
	_top_menu = CursorMenu.new(TOP_MENU_ITEMS)


func setup(inventory: Inventory, guild: Guild, shop_inventory: ShopInventory) -> void:
	_inventory = inventory
	_guild = guild
	_shop_inventory = shop_inventory


func _ready() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 4)
	add_child(_root)
	_rebuild()


# ---- introspection API for tests ----

func get_top_menu_items() -> Array[String]:
	return TOP_MENU_ITEMS.duplicate()


func get_mode() -> Mode:
	return _mode


func get_selected_index() -> int:
	return _selected_index


func get_last_message() -> String:
	return _last_message


func get_active_tab() -> Tab:
	return _tab


func set_active_tab(tab: Tab) -> void:
	_tab = tab
	_selected_index = 0


func _item_matches_tab(item: Item, tab: Tab) -> bool:
	match tab:
		Tab.EQUIPMENT:
			return item.equip_slot != Item.EquipSlot.NONE
		Tab.CONSUMABLE:
			return item.category == Item.ItemCategory.CONSUMABLE
	return false


func get_buy_catalog() -> Array[Item]:
	var results: Array[Item] = []
	if _shop_inventory == null:
		return results
	for item in _shop_inventory.list():
		if _item_matches_tab(item, _tab):
			results.append(item)
	return results


func get_sell_candidates() -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	if _inventory == null:
		return results
	var equipped := _equipped_instance_set()
	for inst in _inventory.list():
		if not _item_matches_tab(inst.item, _tab):
			continue
		# Equipment-only: skip equipped items. Consumables are never equipped.
		if _tab == Tab.EQUIPMENT and equipped.has(inst):
			continue
		results.append(inst)
	return results


func _equipped_instance_set() -> Dictionary:
	if _guild == null:
		return {}
	return _guild.map_equipped_instances()


# ---- transactions ----

func buy(item: Item) -> bool:
	_last_message = ""
	if item == null or _inventory == null:
		return false
	if not _inventory.spend_gold(item.price):
		_last_message = "ゴールドが足りません"
		return false
	_inventory.add(_shop_inventory.purchase(item))
	_last_message = "%s を購入しました" % item.item_name
	return true


func sell(instance: ItemInstance) -> bool:
	_last_message = ""
	if instance == null or _inventory == null or instance.item == null:
		return false
	if _equipped_instance_set().has(instance):
		_last_message = "装備中のアイテムは売却できません"
		return false
	var proceeds: int = instance.item.price / 2
	if not _inventory.remove(instance):
		return false
	_inventory.add_gold(proceeds)
	_last_message = "%s を売却しました (+%d G)" % [instance.item.item_name, proceeds]
	return true


# ---- rendering ----

func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match _mode:
		Mode.TOP_MENU: title.text = "商店"
		Mode.BUY: title.text = "購入"
		Mode.SELL: title.text = "売却"
	_root.add_child(title)

	var gold_label := Label.new()
	gold_label.add_theme_font_size_override("font_size", FONT_SIZE)
	gold_label.text = "所持ゴールド: %d" % (_inventory.gold if _inventory != null else 0)
	_root.add_child(gold_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	_root.add_child(spacer)

	if _mode == Mode.BUY or _mode == Mode.SELL:
		_render_tab_bar()

	match _mode:
		Mode.TOP_MENU: _render_top_menu()
		Mode.BUY: _render_buy()
		Mode.SELL: _render_sell()

	if _last_message != "":
		var msg := Label.new()
		msg.text = _last_message
		msg.add_theme_font_size_override("font_size", 14)
		msg.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
		_root.add_child(msg)


func _render_tab_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	for i in range(TAB_LABELS.size()):
		var tab_label := Label.new()
		tab_label.add_theme_font_size_override("font_size", FONT_SIZE)
		var is_active: bool = (i == int(_tab))
		var text := TAB_LABELS[i]
		tab_label.text = "[%s]" % text if is_active else " %s " % text
		if is_active:
			tab_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		else:
			tab_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		bar.add_child(tab_label)
	_root.add_child(bar)
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 12)
	hint.text = "←/→ でタブ切替"
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_root.add_child(hint)


func _render_top_menu() -> void:
	var rows: Array[CursorMenuRow] = []
	for i in range(TOP_MENU_ITEMS.size()):
		rows.append(CursorMenuRow.create(_root, TOP_MENU_ITEMS[i], FONT_SIZE))
	_top_menu.update_rows(rows)


func _render_buy() -> void:
	var items := get_buy_catalog()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "  (在庫なし)"
		_root.add_child(empty)
		return
	for i in range(items.size()):
		var affordable: bool = _inventory != null and _inventory.gold >= items[i].price
		var row := CursorMenuRow.create(_root,
			"%s    %d G" % [items[i].item_name, items[i].price], FONT_SIZE)
		row.set_selected(i == _selected_index)
		if not affordable:
			row.set_disabled(true)


func _render_sell() -> void:
	var instances := get_sell_candidates()
	if instances.is_empty():
		var empty := Label.new()
		empty.text = "  (売却可能なアイテムがありません)"
		_root.add_child(empty)
		return
	for i in range(instances.size()):
		var price: int = instances[i].item.price / 2
		var row := CursorMenuRow.create(_root,
			"%s    %d G" % [instances[i].item.item_name, price], FONT_SIZE)
		row.set_selected(i == _selected_index)


# ---- input ----

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match _mode:
		Mode.TOP_MENU: _input_top(event)
		Mode.BUY: _input_buy(event)
		Mode.SELL: _input_sell(event)


func _input_top(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_down"):
		_top_menu.move_cursor(1)
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_top_menu.move_cursor(-1)
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		match _top_menu.selected_index:
			TOP_IDX_BUY: enter_buy()
			TOP_IDX_SELL: enter_sell()
			TOP_IDX_EXIT: back_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _toggle_tab() -> void:
	_tab = Tab.CONSUMABLE if _tab == Tab.EQUIPMENT else Tab.EQUIPMENT
	_selected_index = 0


func _input_buy(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_toggle_tab()
		_rebuild()
		get_viewport().set_input_as_handled()
		return
	var count := get_buy_catalog().size()
	if event.is_action_pressed("ui_down") and count > 0:
		_selected_index = (_selected_index + 1) % count
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") and count > 0:
		_selected_index = (_selected_index - 1 + count) % count
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and count > 0:
		var catalog := get_buy_catalog()
		buy(catalog[_selected_index])
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_mode = Mode.TOP_MENU
		_selected_index = 0
		_rebuild()
		get_viewport().set_input_as_handled()


func _input_sell(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_toggle_tab()
		_rebuild()
		get_viewport().set_input_as_handled()
		return
	var candidates := get_sell_candidates()
	var count := candidates.size()
	if event.is_action_pressed("ui_down") and count > 0:
		_selected_index = (_selected_index + 1) % count
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") and count > 0:
		_selected_index = (_selected_index - 1 + count) % count
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and count > 0:
		sell(candidates[_selected_index])
		if _selected_index >= get_sell_candidates().size():
			_selected_index = maxi(0, get_sell_candidates().size() - 1)
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_mode = Mode.TOP_MENU
		_selected_index = 0
		_rebuild()
		get_viewport().set_input_as_handled()


func enter_buy() -> void:
	_mode = Mode.BUY
	_tab = Tab.EQUIPMENT
	_selected_index = 0
	_rebuild()


func enter_sell() -> void:
	_mode = Mode.SELL
	_tab = Tab.EQUIPMENT
	_selected_index = 0
	_rebuild()
