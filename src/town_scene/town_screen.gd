class_name TownScreen
extends Control

signal open_guild
signal open_shop
signal open_temple
signal open_dungeon_entrance

const MENU_ITEMS: Array[String] = [
	"冒険者ギルド",
	"商店",
	"教会",
	"ダンジョン入口",
]

const DISABLED_INDICES: Array[int] = []

const FACILITY_COLORS: Array[Color] = [
	Color(0.2, 0.3, 0.5),
	Color(0.5, 0.4, 0.2),
	Color(0.5, 0.5, 0.3),
	Color(0.3, 0.2, 0.2),
]

var selected_index: int:
	get: return _menu.selected_index
	set(v): _menu.selected_index = v

var _menu: CursorMenu
var _labels: Array[Label] = []
var _illustration_rect: ColorRect
var _illustration_label: Label

func _init() -> void:
	_menu = CursorMenu.new(MENU_ITEMS, DISABLED_INDICES)

func _ready() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.size_flags_vertical = SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "地上"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	left.add_child(spacer)

	for i in range(MENU_ITEMS.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		left.add_child(label)
		_labels.append(label)

	var right := PanelContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.add_child(right)

	_illustration_rect = ColorRect.new()
	_illustration_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	right.add_child(_illustration_rect)

	_illustration_label = Label.new()
	_illustration_label.add_theme_font_size_override("font_size", 32)
	_illustration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_illustration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_illustration_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	right.add_child(_illustration_label)

	_menu.update_labels(_labels)
	_update_illustration()

func _update_illustration() -> void:
	if _illustration_rect:
		_illustration_rect.color = get_facility_color(_menu.selected_index)
	if _illustration_label:
		_illustration_label.text = MENU_ITEMS[_menu.selected_index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_menu.move_cursor(1)
		_menu.update_labels(_labels)
		_update_illustration()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_menu.move_cursor(-1)
		_menu.update_labels(_labels)
		_update_illustration()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		confirm_selection()
		get_viewport().set_input_as_handled()

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func is_item_disabled(index: int) -> bool:
	return _menu.is_disabled(index)

func get_facility_color(index: int) -> Color:
	return FACILITY_COLORS[index]

func move_cursor(direction: int) -> void:
	_menu.move_cursor(direction)

func confirm_selection() -> void:
	select_item(_menu.selected_index)

func select_item(index: int) -> void:
	if _menu.is_disabled(index):
		return
	match index:
		0: open_guild.emit()
		1: open_shop.emit()
		2: open_temple.emit()
		3: open_dungeon_entrance.emit()
