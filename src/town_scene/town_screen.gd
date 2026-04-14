class_name TownScreen
extends Control

signal open_guild
signal open_dungeon_entrance

const MENU_ITEMS: Array[String] = [
	"冒険者ギルド",
	"商店",
	"教会",
	"ダンジョン入口",
]

const DISABLED_INDICES: Array[int] = [1, 2]

const FACILITY_COLORS: Array[Color] = [
	Color(0.2, 0.3, 0.5),   # ギルド: 落ち着いた青
	Color(0.5, 0.4, 0.2),   # 商店: 暖かい茶
	Color(0.5, 0.5, 0.3),   # 教会: 柔らかい黄
	Color(0.3, 0.2, 0.2),   # ダンジョン入口: 暗い赤
]

const FONT_SIZE := 20
const CURSOR := "> "
const DISABLED_COLOR := Color(0.5, 0.5, 0.5)
const ENABLED_COLOR := Color(1.0, 1.0, 1.0)

var selected_index: int = 0
var _labels: Array[Label] = []
var _illustration_rect: ColorRect
var _illustration_label: Label

func _ready() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	# Left column: facility menu
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
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		left.add_child(label)
		_labels.append(label)

	# Right column: illustration placeholder
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

	_update_labels()
	_update_illustration()

func _update_labels() -> void:
	for i in range(_labels.size()):
		var prefix := CURSOR if i == selected_index else "  "
		_labels[i].text = prefix + MENU_ITEMS[i]
		_labels[i].add_theme_color_override(
			"font_color",
			DISABLED_COLOR if is_item_disabled(i) else ENABLED_COLOR
		)

func _update_illustration() -> void:
	if _illustration_rect:
		_illustration_rect.color = get_facility_color(selected_index)
	if _illustration_label:
		_illustration_label.text = MENU_ITEMS[selected_index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		move_cursor(1)
		_update_labels()
		_update_illustration()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		move_cursor(-1)
		_update_labels()
		_update_illustration()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		confirm_selection()
		get_viewport().set_input_as_handled()

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func is_item_disabled(index: int) -> bool:
	return index in DISABLED_INDICES

func get_facility_color(index: int) -> Color:
	return FACILITY_COLORS[index]

func move_cursor(direction: int) -> void:
	var start := selected_index
	var count := MENU_ITEMS.size()
	for _i in range(count):
		selected_index = (selected_index + direction) % count
		if selected_index < 0:
			selected_index += count
		if not is_item_disabled(selected_index):
			return
	selected_index = start

func confirm_selection() -> void:
	select_item(selected_index)

func select_item(index: int) -> void:
	if is_item_disabled(index):
		return
	match index:
		0: open_guild.emit()
		3: open_dungeon_entrance.emit()
