class_name TownScreen
extends Control

signal open_guild
signal open_shop
signal open_temple
signal open_dungeon_entrance

const MAIN_IDX_GUILD := 0
const MAIN_IDX_SHOP := 1
const MAIN_IDX_TEMPLE := 2
const MAIN_IDX_DUNGEON_ENTRANCE := 3

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

const DEFAULT_FACILITY_IMAGES: Array[String] = [
	"res://assets/images/facilities/guild.png",
	"res://assets/images/facilities/shop.png",
	"res://assets/images/facilities/church.png",
	"res://assets/images/facilities/dungeon.png",
]

const LABEL_OVERLAY_HEIGHT_RATIO := 0.15
const LABEL_OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.5)

var facility_image_paths: Array[String] = DEFAULT_FACILITY_IMAGES.duplicate()

var selected_index: int:
	get: return _menu.selected_index
	set(v): _menu.selected_index = v

var _menu: CursorMenu
var _rows: Array[CursorMenuRow] = []
var _illustration_rect: ColorRect
var _illustration_texture: TextureRect
var _illustration_overlay: ColorRect
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
		_rows.append(CursorMenuRow.create(left, MENU_ITEMS[i], 20))

	var right := PanelContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.add_child(right)

	_illustration_rect = ColorRect.new()
	_illustration_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_illustration_rect.visible = false
	right.add_child(_illustration_rect)

	_illustration_texture = TextureRect.new()
	_illustration_texture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_illustration_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	right.add_child(_illustration_texture)

	_illustration_overlay = ColorRect.new()
	_illustration_overlay.color = LABEL_OVERLAY_COLOR
	_illustration_overlay.anchor_left = 0.0
	_illustration_overlay.anchor_right = 1.0
	_illustration_overlay.anchor_top = 1.0 - LABEL_OVERLAY_HEIGHT_RATIO
	_illustration_overlay.anchor_bottom = 1.0
	_illustration_overlay.offset_left = 0
	_illustration_overlay.offset_top = 0
	_illustration_overlay.offset_right = 0
	_illustration_overlay.offset_bottom = 0
	right.add_child(_illustration_overlay)

	_illustration_label = Label.new()
	_illustration_label.add_theme_font_size_override("font_size", 32)
	_illustration_label.add_theme_color_override("font_color", Color.WHITE)
	_illustration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_illustration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_illustration_label.anchor_left = 0.0
	_illustration_label.anchor_right = 1.0
	_illustration_label.anchor_top = 1.0 - LABEL_OVERLAY_HEIGHT_RATIO
	_illustration_label.anchor_bottom = 1.0
	_illustration_label.offset_left = 0
	_illustration_label.offset_top = 0
	_illustration_label.offset_right = 0
	_illustration_label.offset_bottom = 0
	right.add_child(_illustration_label)

	_menu.update_rows(_rows)
	_update_illustration()

func _update_illustration() -> void:
	var index := _menu.selected_index
	var tex: Texture2D = _load_facility_image(index)
	if tex != null and _illustration_texture != null:
		_illustration_texture.texture = tex
		_illustration_texture.visible = true
		if _illustration_rect != null:
			_illustration_rect.visible = false
	else:
		if _illustration_texture != null:
			_illustration_texture.texture = null
			_illustration_texture.visible = false
		if _illustration_rect != null:
			_illustration_rect.color = get_facility_color(index)
			_illustration_rect.visible = true
	if _illustration_label != null:
		_illustration_label.text = MENU_ITEMS[index]

func _load_facility_image(index: int) -> Texture2D:
	if index < 0 or index >= facility_image_paths.size():
		return null
	var path := facility_image_paths[index]
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is Texture2D:
		return res
	return null

func _unhandled_input(event: InputEvent) -> void:
	if MenuController.route(
		event, _menu, _rows, confirm_selection,
		Callable(), _update_illustration
	):
		get_viewport().set_input_as_handled()

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func is_item_disabled(index: int) -> bool:
	return _menu.is_disabled(index)

func get_facility_color(index: int) -> Color:
	return FACILITY_COLORS[index]

func get_illustration_texture() -> Texture2D:
	if _illustration_texture == null:
		return null
	return _illustration_texture.texture

func get_illustration_label_text() -> String:
	if _illustration_label == null:
		return ""
	return _illustration_label.text

func is_texture_visible() -> bool:
	return _illustration_texture != null and _illustration_texture.visible

func is_fallback_visible() -> bool:
	return _illustration_rect != null and _illustration_rect.visible

func move_cursor(direction: int) -> void:
	_menu.move_cursor(direction)

func confirm_selection() -> void:
	select_item(_menu.selected_index)

func select_item(index: int) -> void:
	if _menu.is_disabled(index):
		return
	match index:
		MAIN_IDX_GUILD: open_guild.emit()
		MAIN_IDX_SHOP: open_shop.emit()
		MAIN_IDX_TEMPLE: open_temple.emit()
		MAIN_IDX_DUNGEON_ENTRANCE: open_dungeon_entrance.emit()
