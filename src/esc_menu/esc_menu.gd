class_name EscMenu
extends CanvasLayer

signal quit_to_title

enum View { MAIN_MENU, PARTY_MENU, STATUS, QUIT_DIALOG }

func is_menu_visible() -> bool:
	return false

func show_menu() -> void:
	pass

func hide_menu() -> void:
	pass

func get_current_view() -> View:
	return View.MAIN_MENU

func get_main_menu() -> CursorMenu:
	return null

func get_party_menu() -> CursorMenu:
	return null

func get_quit_menu() -> CursorMenu:
	return null

func select_current_item() -> void:
	pass

func go_back() -> void:
	pass

func handle_input(_event: InputEventKey) -> void:
	pass
