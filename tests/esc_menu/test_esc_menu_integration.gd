extends GutTest

const MainScript = preload("res://src/main.gd")

func _make_esc_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event

func test_main_has_esc_menu():
	var main := MainScript.new()
	add_child_autofree(main)
	assert_not_null(main._esc_menu)

func test_main_esc_menu_is_esc_menu_type():
	var main := MainScript.new()
	add_child_autofree(main)
	assert_is(main._esc_menu, EscMenu)

func test_main_esc_key_opens_menu_on_town_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	GameState.new_game()
	main._show_town_screen()
	main._on_esc_key_pressed()
	assert_true(main._esc_menu.is_menu_visible())

func test_main_esc_key_does_not_open_on_title_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	main._unhandled_input(_make_esc_event())
	assert_false(main._esc_menu.is_menu_visible())

func test_main_quit_to_title_shows_title_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	GameState.new_game()
	main._show_town_screen()
	main._on_quit_to_title()
	assert_is(main._current_screen, TitleScreen)
