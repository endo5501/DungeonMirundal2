class_name TitleScreen
extends Control

signal start_new_game
signal continue_game
signal load_game
signal quit_game

const MENU_ITEMS: Array[String] = [
	"新規ゲーム",
	"前回から",
	"ロード",
	"ゲーム終了",
]

const DISABLED_INDICES: Array[int] = [1, 2]
const FONT_SIZE := 20
const CURSOR := "> "
const DISABLED_COLOR := Color(0.5, 0.5, 0.5)
const ENABLED_COLOR := Color(1.0, 1.0, 1.0)

var selected_index: int = 0
var _labels: Array[Label] = []

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "Dungeon Mirundal"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 32
	vbox.add_child(spacer)

	for i in range(MENU_ITEMS.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		vbox.add_child(label)
		_labels.append(label)

	_update_labels()

func _update_labels() -> void:
	for i in range(_labels.size()):
		var prefix := CURSOR if i == selected_index else "  "
		_labels[i].text = prefix + MENU_ITEMS[i]
		_labels[i].add_theme_color_override(
			"font_color",
			DISABLED_COLOR if is_item_disabled(i) else ENABLED_COLOR
		)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		move_cursor(1)
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		move_cursor(-1)
		_update_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		confirm_selection()
		get_viewport().set_input_as_handled()

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func is_item_disabled(index: int) -> bool:
	return index in DISABLED_INDICES

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
		0: start_new_game.emit()
		1: continue_game.emit()
		2: load_game.emit()
		3: quit_game.emit()
