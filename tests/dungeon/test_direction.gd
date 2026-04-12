extends GutTest

func test_direction_values():
	assert_eq(Direction.NORTH, 0)
	assert_eq(Direction.EAST, 1)
	assert_eq(Direction.SOUTH, 2)
	assert_eq(Direction.WEST, 3)

func test_dx_dy():
	assert_eq(Direction.dx(Direction.NORTH), 0)
	assert_eq(Direction.dy(Direction.NORTH), -1)
	assert_eq(Direction.dx(Direction.EAST), 1)
	assert_eq(Direction.dy(Direction.EAST), 0)
	assert_eq(Direction.dx(Direction.SOUTH), 0)
	assert_eq(Direction.dy(Direction.SOUTH), 1)
	assert_eq(Direction.dx(Direction.WEST), -1)
	assert_eq(Direction.dy(Direction.WEST), 0)

func test_opposite():
	assert_eq(Direction.opposite(Direction.NORTH), Direction.SOUTH)
	assert_eq(Direction.opposite(Direction.SOUTH), Direction.NORTH)
	assert_eq(Direction.opposite(Direction.EAST), Direction.WEST)
	assert_eq(Direction.opposite(Direction.WEST), Direction.EAST)

func test_offset():
	assert_eq(Direction.offset(Direction.NORTH), Vector2i(0, -1))
	assert_eq(Direction.offset(Direction.EAST), Vector2i(1, 0))
	assert_eq(Direction.offset(Direction.SOUTH), Vector2i(0, 1))
	assert_eq(Direction.offset(Direction.WEST), Vector2i(-1, 0))

func test_all_directions():
	var dirs = Direction.ALL
	assert_eq(dirs.size(), 4)
	assert_has(dirs, Direction.NORTH)
	assert_has(dirs, Direction.EAST)
	assert_has(dirs, Direction.SOUTH)
	assert_has(dirs, Direction.WEST)

func test_turn_right():
	assert_eq(Direction.turn_right(Direction.NORTH), Direction.EAST)
	assert_eq(Direction.turn_right(Direction.EAST), Direction.SOUTH)
	assert_eq(Direction.turn_right(Direction.SOUTH), Direction.WEST)
	assert_eq(Direction.turn_right(Direction.WEST), Direction.NORTH)

func test_turn_left():
	assert_eq(Direction.turn_left(Direction.NORTH), Direction.WEST)
	assert_eq(Direction.turn_left(Direction.EAST), Direction.NORTH)
	assert_eq(Direction.turn_left(Direction.SOUTH), Direction.EAST)
	assert_eq(Direction.turn_left(Direction.WEST), Direction.SOUTH)
