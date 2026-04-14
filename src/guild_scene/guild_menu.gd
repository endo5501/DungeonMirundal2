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
const CURSOR := "> "

var selected_index: int = 0
var _labels: Array[Label] = []

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "冒険者ギルド"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
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
