extends GutTest


func _find_open_forward_position(wm: WizMap) -> Vector2i:
	for y in range(1, wm.map_size - 1):
		for x in range(1, wm.map_size - 1):
			var ps := PlayerState.new(Vector2i(x, y), Direction.NORTH)
			if ps.move_forward(wm):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# --- M key opens / closes overlay ---

func test_m_key_opens_overlay():
	var wm := TestHelpers.make_test_map()
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))
	assert_true(screen.is_full_map_open(),
		"M key should open the full map overlay")


func test_m_key_closes_overlay_when_open():
	var wm := TestHelpers.make_test_map()
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # open
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # close
	assert_false(screen.is_full_map_open(),
		"second M press should close the overlay")


# --- M key suppressed during encounter / return dialog ---

func test_m_key_ignored_during_encounter():
	var wm := TestHelpers.make_test_map()
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wm, ps)
	screen.set_encounter_active(true)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))
	assert_false(screen.is_full_map_open(),
		"M must be ignored while encounter is active")


func test_m_key_ignored_during_return_dialog():
	var wm := TestHelpers.make_test_map(Vector2i(4, 4))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	screen.setup(wm, ps)
	screen.check_start_tile_return()
	assert_true(screen.is_showing_return_dialog(), "return dialog should be up")
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))
	assert_false(screen.is_full_map_open(),
		"M must be ignored while return dialog is showing")


# --- Movement locked while overlay visible ---

func test_forward_move_blocked_while_overlay_visible():
	var wm := TestHelpers.make_test_map()
	var open_pos := _find_open_forward_position(wm)
	if open_pos == Vector2i(-1, -1):
		pending("no open forward position in generated map; rerun with different seed")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(open_pos, Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # open overlay
	var starting_pos := ps.position
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_eq(ps.position, starting_pos,
		"position must not change while full map overlay is visible")


func test_turn_blocked_while_overlay_visible():
	var wm := TestHelpers.make_test_map()
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # open overlay
	screen._unhandled_input(TestHelpers.make_key_event(KEY_LEFT))
	assert_eq(ps.facing, Direction.NORTH,
		"facing must not change while full map overlay is visible")


func test_movement_resumes_after_overlay_closes():
	var wm := TestHelpers.make_test_map()
	var open_pos := _find_open_forward_position(wm)
	if open_pos == Vector2i(-1, -1):
		pending("no open forward position")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(open_pos, Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # open
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M))  # close
	var starting_pos := ps.position
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_ne(ps.position, starting_pos,
		"player should move forward after overlay closed")


# --- M key echo is ignored ---

func test_m_key_echo_ignored():
	var wm := TestHelpers.make_test_map()
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wm, ps)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_M, true, true))
	assert_false(screen.is_full_map_open(),
		"echo M events must not toggle the overlay")
