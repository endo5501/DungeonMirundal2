class_name TitleScreen
extends Control

signal start_new_game
signal continue_game
signal load_game
signal quit_game

const MENU_ITEMS: Array[String] = [
	"前回から",
	"新規ゲーム",
	"ロード",
	"ゲーム終了",
]

var _disabled_indices: Array[int] = [0, 2]

var selected_index: int:
	get: return _menu.selected_index
	set(v): _menu.selected_index = v

var _menu: CursorMenu
var _rows: Array[CursorMenuRow] = []

func _init() -> void:
	_menu = CursorMenu.new(MENU_ITEMS, _disabled_indices)
	_menu.ensure_valid_selection()

func setup_save_state(save_manager: SaveManager) -> void:
	_disabled_indices = []
	if save_manager.get_last_slot() < 0:
		_disabled_indices.append(0)
	if not save_manager.has_saves():
		_disabled_indices.append(2)
	_menu = CursorMenu.new(MENU_ITEMS, _disabled_indices)
	_menu.ensure_valid_selection()
	if _rows.size() > 0:
		_menu.update_rows(_rows)

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Dungeon Mirundal"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 32
	vbox.add_child(spacer)

	for i in range(MENU_ITEMS.size()):
		_rows.append(CursorMenuRow.create(vbox, MENU_ITEMS[i], 20))

	_menu.update_rows(_rows)

func _unhandled_input(event: InputEvent) -> void:
	# ESC is intentionally ignored on the title screen: there is no parent screen
	# to return to. We deliberately omit on_back so MenuController.route returns
	# false for ui_cancel, leaving set_input_as_handled uncalled.
	if MenuController.route(event, _menu, _rows, confirm_selection):
		get_viewport().set_input_as_handled()

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func is_item_disabled(index: int) -> bool:
	return _menu.is_disabled(index)

func move_cursor(direction: int) -> void:
	_menu.move_cursor(direction)

func confirm_selection() -> void:
	select_item(_menu.selected_index)

func select_item(index: int) -> void:
	if _menu.is_disabled(index):
		return
	match index:
		0: continue_game.emit()
		1: start_new_game.emit()
		2: load_game.emit()
		3: quit_game.emit()
