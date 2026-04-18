class_name GuildMenu
extends Control

signal create_character_selected
signal party_formation_selected
signal character_list_selected
signal leave_selected

const MENU_ITEMS: Array[String] = [
	"キャラクターを作成する",
	"パーティ編成",
	"キャラクター一覧",
	"立ち去る",
]

const FONT_SIZE := 20

var selected_index: int = 0
var _rows: Array[CursorMenuRow] = []

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "冒険者ギルド"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	for i in range(MENU_ITEMS.size()):
		var row := CursorMenuRow.new()
		row.set_text(MENU_ITEMS[i])
		row.set_text_font_size(FONT_SIZE)
		vbox.add_child(row)
		_rows.append(row)

	_update_labels()

func _update_labels() -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == selected_index)

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

func move_cursor(direction: int) -> void:
	selected_index = (selected_index + direction) % MENU_ITEMS.size()
	if selected_index < 0:
		selected_index += MENU_ITEMS.size()

func confirm_selection() -> void:
	select_item(selected_index)

func select_item(index: int) -> void:
	match index:
		0: create_character_selected.emit()
		1: party_formation_selected.emit()
		2: character_list_selected.emit()
		3: leave_selected.emit()
