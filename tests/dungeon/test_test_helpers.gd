extends GutTest

# Verifies that the deterministic fixture builders in TestHelpers actually
# produce the topology they advertise. Without this, the fixture utilities
# could silently regress and quietly let callers fail in subtle ways.


# --- make_corridor_fixture ---

func test_make_corridor_fixture_opens_full_length():
	var wm := TestHelpers.make_corridor_fixture(Vector2i(3, 5), Direction.NORTH, 3)
	assert_eq(wm.map_size, 8)
	# Walking NORTH from (3,5) for 3 steps must succeed each time.
	var ps := PlayerState.new(Vector2i(3, 5), Direction.NORTH)
	for i in range(3):
		assert_true(ps.move_forward(wm), "step %d should succeed" % i)
	assert_eq(ps.position, Vector2i(3, 2))


func test_make_corridor_fixture_works_in_each_direction():
	var cases := [
		[Vector2i(3, 5), Direction.NORTH, Vector2i(3, 4)],
		[Vector2i(3, 3), Direction.SOUTH, Vector2i(3, 4)],
		[Vector2i(3, 3), Direction.EAST, Vector2i(4, 3)],
		[Vector2i(4, 3), Direction.WEST, Vector2i(3, 3)],
	]
	for c in cases:
		var wm := TestHelpers.make_corridor_fixture(c[0], c[1], 1)
		var ps := PlayerState.new(c[0], c[1])
		assert_true(ps.move_forward(wm), "dir %d should open" % c[1])
		assert_eq(ps.position, c[2])


func test_make_corridor_fixture_places_start():
	var wm := TestHelpers.make_corridor_fixture(Vector2i(3, 5), Direction.NORTH, 3)
	assert_eq(wm.cell(3, 5).tile, TileType.START)


# --- make_blocked_fixture ---

func test_make_blocked_fixture_blocks_all_directions():
	var wm := TestHelpers.make_blocked_fixture(Vector2i(3, 3))
	for dir in Direction.ALL:
		var ps := PlayerState.new(Vector2i(3, 3), dir)
		assert_false(ps.move_forward(wm),
			"dir %d should be walled in blocked fixture" % dir)


func test_make_blocked_fixture_places_start():
	var wm := TestHelpers.make_blocked_fixture(Vector2i(3, 3))
	assert_eq(wm.cell(3, 3).tile, TileType.START)


# --- make_neighbor_to_start_fixture ---

func test_make_neighbor_to_start_fixture_forward_lands_on_start():
	# start is at (4, 4); neighbor on the SOUTH side of start, facing NORTH,
	# should walk forward onto the start tile.
	var wm := TestHelpers.make_neighbor_to_start_fixture(Vector2i(4, 4), Direction.NORTH)
	# The neighbor cell is (4, 5) (south of start), facing NORTH.
	var ps := PlayerState.new(Vector2i(4, 5), Direction.NORTH)
	assert_true(ps.move_forward(wm))
	assert_eq(ps.position, Vector2i(4, 4))
	assert_eq(wm.cell(4, 4).tile, TileType.START)


func test_make_neighbor_to_start_fixture_each_direction():
	# For each cardinal direction, set up so that walking that direction lands
	# on the start tile.
	var cases := [
		[Direction.NORTH, Vector2i(4, 5)],
		[Direction.SOUTH, Vector2i(4, 3)],
		[Direction.EAST, Vector2i(3, 4)],
		[Direction.WEST, Vector2i(5, 4)],
	]
	for c in cases:
		var dir: int = c[0]
		var neighbor: Vector2i = c[1]
		var wm := TestHelpers.make_neighbor_to_start_fixture(Vector2i(4, 4), dir)
		var ps := PlayerState.new(neighbor, dir)
		assert_true(ps.move_forward(wm), "dir %d move should succeed" % dir)
		assert_eq(ps.position, Vector2i(4, 4))
