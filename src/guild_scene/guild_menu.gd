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

func get_menu_items() -> Array[String]:
	return MENU_ITEMS

func select_item(index: int) -> void:
	match index:
		0: create_character_selected.emit()
		1: party_formation_selected.emit()
		2: character_list_selected.emit()
		3: leave_selected.emit()
