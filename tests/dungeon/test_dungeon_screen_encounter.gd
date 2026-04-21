extends GutTest


func _find_open_forward_position(wiz_map: WizMap) -> Vector2i:
	# Scan for a cell where NORTH edge is open (so forward move is possible)
	for y in range(1, wiz_map.map_size - 1):
		for x in range(1, wiz_map.map_size - 1):
			var ps := PlayerState.new(Vector2i(x, y), Direction.NORTH)
			if ps.move_forward(wiz_map):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _find_blocked_forward_position(wiz_map: WizMap) -> Vector2i:
	# Scan for a cell where NORTH edge is blocked
	for y in range(1, wiz_map.map_size - 1):
		for x in range(1, wiz_map.map_size - 1):
			var ps := PlayerState.new(Vector2i(x, y), Direction.NORTH)
			if not ps.move_forward(wiz_map):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# --- step_taken signal on position change ---

func test_forward_move_emits_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))  # start far from test position
	var open_pos := _find_open_forward_position(wiz_map)
	if open_pos == Vector2i(-1, -1):
		pending("no open forward position in generated map; rerun with different seed")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(open_pos, Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_signal_emitted(screen, "step_taken")


func test_blocked_move_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var blocked_pos := _find_blocked_forward_position(wiz_map)
	if blocked_pos == Vector2i(-1, -1):
		pending("no blocked position in generated map; rerun with different seed")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(blocked_pos, Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_signal_not_emitted(screen, "step_taken")


func test_turn_left_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_LEFT))
	assert_signal_not_emitted(screen, "step_taken")


func test_turn_right_does_not_emit_step_taken():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_RIGHT))
	assert_signal_not_emitted(screen, "step_taken")


# --- encounter_active blocks input ---

func test_movement_blocked_when_encounter_active():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var open_pos := _find_open_forward_position(wiz_map)
	if open_pos == Vector2i(-1, -1):
		pending("no open forward position")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(open_pos, Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	watch_signals(screen)
	var starting_pos := ps.position
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_eq(ps.position, starting_pos, "position must not change while encounter is active")
	assert_signal_not_emitted(screen, "step_taken")


func test_rotation_blocked_when_encounter_active():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_LEFT))
	assert_eq(ps.facing, Direction.NORTH, "facing must not change while encounter is active")


func test_encounter_active_clears_back_to_normal_movement():
	var wiz_map := TestHelpers.make_test_map(Vector2i(7, 7))
	var open_pos := _find_open_forward_position(wiz_map)
	if open_pos == Vector2i(-1, -1):
		pending("no open forward position")
		return
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var ps := PlayerState.new(open_pos, Direction.NORTH)
	screen.setup(wiz_map, ps)
	screen.set_encounter_active(true)
	screen.set_encounter_active(false)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
	assert_signal_emitted(screen, "step_taken")


# --- start tile priority with encounter ---

func test_start_tile_return_dialog_suppressed_when_encounter_activates_during_step():
	# Simulate: stepping onto start tile AND encounter triggers on same step.
	# Coordinator reacts to step_taken by calling set_encounter_active(true) before
	# DungeonScreen has a chance to show the return dialog.
	var wiz_map := TestHelpers.make_test_map(Vector2i(4, 4))
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	# Place player adjacent to start, facing toward it, so forward move lands on start
	# We find a cell where moving forward lands on (4, 4)
	var start_pos := Vector2i(4, 4)
	var ps: PlayerState = null
	# Try each neighbor with corresponding facing
	var candidates := [
		[Vector2i(4, 5), Direction.NORTH],
		[Vector2i(4, 3), Direction.SOUTH],
		[Vector2i(3, 4), Direction.EAST],
		[Vector2i(5, 4), Direction.WEST],
	]
	for c in candidates:
		var cand_ps := PlayerState.new(c[0], c[1])
		if cand_ps.move_forward(wiz_map) and cand_ps.position == start_pos:
			ps = PlayerState.new(c[0], c[1])
			break
	if ps == null:
		pending("could not place player adjacent to start tile")
		return
	screen.setup(wiz_map, ps)
	screen.step_taken.connect(func(_pos: Vector2i) -> void:
		screen.set_encounter_active(true))
	screen._unhandled_input(TestHelpers.make_key_event(KEY_UP))
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
