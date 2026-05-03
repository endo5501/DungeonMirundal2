extends GutTest

func test_initial_position_and_direction():
	var ps = PlayerState.new(Vector2i(3, 4), Direction.NORTH)
	assert_eq(ps.position, Vector2i(3, 4))
	assert_eq(ps.facing, Direction.NORTH)

func test_initial_position_east():
	var ps = PlayerState.new(Vector2i(5, 5), Direction.EAST)
	assert_eq(ps.position, Vector2i(5, 5))
	assert_eq(ps.facing, Direction.EAST)

func test_turn_right_from_north():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	ps.turn_right()
	assert_eq(ps.facing, Direction.EAST)

func test_turn_right_from_east():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.EAST)
	ps.turn_right()
	assert_eq(ps.facing, Direction.SOUTH)

func test_turn_right_from_south():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.SOUTH)
	ps.turn_right()
	assert_eq(ps.facing, Direction.WEST)

func test_turn_right_from_west():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.WEST)
	ps.turn_right()
	assert_eq(ps.facing, Direction.NORTH)

func test_turn_left_from_north():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	ps.turn_left()
	assert_eq(ps.facing, Direction.WEST)

func test_turn_left_from_west():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.WEST)
	ps.turn_left()
	assert_eq(ps.facing, Direction.SOUTH)

func test_turn_left_from_south():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.SOUTH)
	ps.turn_left()
	assert_eq(ps.facing, Direction.EAST)

func test_turn_left_from_east():
	var ps = PlayerState.new(Vector2i(0, 0), Direction.EAST)
	ps.turn_left()
	assert_eq(ps.facing, Direction.NORTH)

func test_turn_does_not_change_position():
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	ps.turn_right()
	assert_eq(ps.position, Vector2i(5, 5))
	ps.turn_left()
	assert_eq(ps.position, Vector2i(5, 5))

# --- move_forward / move_backward ---

func _create_map_with_open_north(x: int, y: int) -> WizMap:
	var wm = WizMap.new(10)
	wm.set_edge(x, y, Direction.NORTH, EdgeType.OPEN)
	return wm

func test_move_forward_open_north():
	var wm = _create_map_with_open_north(5, 5)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.move_forward(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(5, 4))

func test_move_forward_blocked_by_wall():
	var wm = WizMap.new(10)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.move_forward(wm)
	assert_false(result)
	assert_eq(ps.position, Vector2i(5, 5))

func test_move_forward_through_door():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.NORTH, EdgeType.DOOR)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.move_forward(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(5, 4))

func test_move_forward_out_of_bounds():
	var wm = WizMap.new(10)
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var result = ps.move_forward(wm)
	assert_false(result)
	assert_eq(ps.position, Vector2i(0, 0))

func test_move_forward_facing_east():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.EAST, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.EAST)
	var result = ps.move_forward(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(6, 5))

func test_move_backward_open_south():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.SOUTH, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.move_backward(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(5, 6))
	assert_eq(ps.facing, Direction.NORTH)

func test_move_backward_blocked_by_wall():
	var wm = WizMap.new(10)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.move_backward(wm)
	assert_false(result)
	assert_eq(ps.position, Vector2i(5, 5))

func test_move_backward_does_not_change_facing():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.SOUTH, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	ps.move_backward(wm)
	assert_eq(ps.facing, Direction.NORTH)

# --- strafe_left / strafe_right ---

func test_strafe_left_facing_north_moves_west():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.WEST, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.strafe_left(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(4, 5))
	assert_eq(ps.facing, Direction.NORTH)

func test_strafe_right_facing_north_moves_east():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.EAST, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.strafe_right(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(6, 5))
	assert_eq(ps.facing, Direction.NORTH)

func test_strafe_left_facing_east_moves_north():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.NORTH, EdgeType.OPEN)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.EAST)
	var result = ps.strafe_left(wm)
	assert_true(result)
	assert_eq(ps.position, Vector2i(5, 4))
	assert_eq(ps.facing, Direction.EAST)

func test_strafe_blocked_by_wall():
	var wm = WizMap.new(10)
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var result = ps.strafe_left(wm)
	assert_false(result)
	assert_eq(ps.position, Vector2i(5, 5))
