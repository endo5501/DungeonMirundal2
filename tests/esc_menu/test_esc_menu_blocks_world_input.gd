extends GutTest

# Verifies that EscMenu, while visible, consumes every InputEventAction
# via set_input_as_handled() so that DungeonScreen / FullMapOverlay /
# other world-level handlers cannot react to dungeon-movement keys.
#
# Implementation contract: EscMenu._unhandled_input always calls
# get_viewport().set_input_as_handled() after delegating to handle_input,
# regardless of whether handle_input itself acted on the event.

const WORLD_ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"strafe_left",
	&"strafe_right",
	&"turn_left",
	&"turn_right",
	&"toggle_full_map",
]


func _make_menu_visible() -> EscMenu:
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	return menu


func _make_menu_hidden() -> EscMenu:
	var menu := EscMenu.new()
	add_child_autofree(menu)
	# show_menu() not called; menu starts hidden after _ready.
	return menu


func test_visible_menu_consumes_move_forward():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_true(menu.get_viewport().is_input_handled(),
		"move_forward must be consumed while EscMenu is visible")


func test_visible_menu_consumes_move_back():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"move_back"))
	assert_true(menu.get_viewport().is_input_handled())


func test_visible_menu_consumes_strafe_left():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"strafe_left"))
	assert_true(menu.get_viewport().is_input_handled())


func test_visible_menu_consumes_strafe_right():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"strafe_right"))
	assert_true(menu.get_viewport().is_input_handled())


func test_visible_menu_consumes_turn_left():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"turn_left"))
	assert_true(menu.get_viewport().is_input_handled())


func test_visible_menu_consumes_turn_right():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"turn_right"))
	assert_true(menu.get_viewport().is_input_handled())


func test_visible_menu_consumes_toggle_full_map():
	var menu := _make_menu_visible()
	menu._unhandled_input(TestHelpers.make_action_event(&"toggle_full_map"))
	assert_true(menu.get_viewport().is_input_handled())


func test_hidden_menu_does_not_change_input_handled_flag():
	var menu := _make_menu_hidden()
	var before: bool = menu.get_viewport().is_input_handled()
	menu._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	# Hidden menu must early-return without touching the flag. We compare
	# against the pre-call value so this works whether or not earlier tests
	# left the viewport flag set.
	assert_eq(menu.get_viewport().is_input_handled(), before,
		"hidden menu must not modify is_input_handled")
