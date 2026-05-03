extends GutTest


# --- step_taken signal on position change ---

func test_forward_move_emits_step_taken():
	var wiz_map := TestHelpers.make_corridor_fixture(Vector2i(3, 5), Direction.NORTH, 3)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 5), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_signal_emitted(screen, "step_taken")


func test_blocked_move_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_blocked_fixture(Vector2i(3, 3))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_signal_not_emitted(screen, "step_taken")


func test_turn_left_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"turn_left"))
	assert_signal_not_emitted(screen, "step_taken")


func test_turn_right_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"turn_right"))
	assert_signal_not_emitted(screen, "step_taken")


# --- encounter_active blocks input ---

func test_movement_blocked_when_encounter_active():
	var wiz_map := TestHelpers.make_corridor_fixture(Vector2i(3, 5), Direction.NORTH, 3)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 5), Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	watch_signals(screen)
	var starting_pos := ps.position
	screen._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_eq(ps.position, starting_pos, "position must not change while encounter is active")
	assert_signal_not_emitted(screen, "step_taken")


func test_rotation_blocked_when_encounter_active():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	screen._unhandled_input(TestHelpers.make_action_event(&"turn_left"))
	assert_eq(ps.facing, Direction.NORTH, "facing must not change while encounter is active")


func test_encounter_active_clears_back_to_normal_movement():
	var wiz_map := TestHelpers.make_corridor_fixture(Vector2i(3, 5), Direction.NORTH, 3)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 5), Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	screen.set_encounter_active(false)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_signal_emitted(screen, "step_taken")


# --- start tile priority with encounter ---

func test_start_tile_return_dialog_suppressed_when_encounter_activates_during_step():
	# Simulate: stepping onto start tile AND encounter triggers on same step.
	# Coordinator reacts to step_taken by calling set_encounter_active(true) before
	# DungeonScreen has a chance to show the return dialog.
	var wiz_map := TestHelpers.make_neighbor_to_start_fixture(Vector2i(4, 4), Direction.NORTH)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(4, 5), Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.step_taken.connect(func(_pos: Vector2i) -> void:
		screen.set_encounter_active(true))
	screen._unhandled_input(TestHelpers.make_action_event(&"move_forward"))
	assert_true(screen.is_on_start_tile())
	assert_false(screen.is_showing_return_dialog(),
		"return dialog must be suppressed while encounter is active")


func test_check_start_tile_return_shows_dialog_after_encounter_resolves():
	var wiz_map := TestHelpers.make_test_map(Vector2i(4, 4))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	screen.setup(wiz_map, ps)
	assert_true(screen.is_on_start_tile())
	screen.set_encounter_active(false)
	screen.check_start_tile_return()
	assert_true(screen.is_showing_return_dialog())
