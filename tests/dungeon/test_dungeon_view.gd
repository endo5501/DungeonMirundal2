extends GutTest

func _create_open_map(size: int) -> WizMap:
	var wm = WizMap.new(size)
	for y in range(size):
		for x in range(size):
			if x < size - 1:
				wm.set_edge(x, y, Direction.EAST, EdgeType.OPEN)
			if y < size - 1:
				wm.set_edge(x, y, Direction.SOUTH, EdgeType.OPEN)
	return wm

func test_forward_view_open_corridor():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	# player cell + 4 forward rows * 3 wide (center + left + right)
	assert_true(cells.has(Vector2i(5, 5)), "player cell")
	assert_true(cells.has(Vector2i(5, 4)), "1 ahead center")
	assert_true(cells.has(Vector2i(4, 4)), "1 ahead left")
	assert_true(cells.has(Vector2i(6, 4)), "1 ahead right")
	assert_true(cells.has(Vector2i(5, 3)), "2 ahead center")
	assert_true(cells.has(Vector2i(5, 2)), "3 ahead center")
	assert_true(cells.has(Vector2i(5, 1)), "4 ahead center")

func test_wall_blocks_forward_view():
	var wm = _create_open_map(10)
	wm.set_edge(5, 3, Direction.NORTH, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_true(cells.has(Vector2i(5, 3)), "cell before wall is visible")
	assert_false(cells.has(Vector2i(5, 2)), "cell behind wall is not visible")
	assert_false(cells.has(Vector2i(5, 1)), "far cell behind wall is not visible")

func test_lateral_wall_blocks_side_view():
	var wm = _create_open_map(10)
	wm.set_edge(5, 4, Direction.WEST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(4, 4)), "left cell blocked by wall")
	assert_true(cells.has(Vector2i(6, 4)), "right cell still visible")

func test_map_boundary_limits_view():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 1), Direction.NORTH)
	assert_true(cells.has(Vector2i(5, 0)), "cell at boundary visible")
	for c in cells:
		assert_true(c.y >= 0, "no cell beyond boundary y=%d" % c.y)

func test_facing_east():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(3, 5), Direction.EAST)
	assert_true(cells.has(Vector2i(3, 5)), "player cell")
	assert_true(cells.has(Vector2i(4, 5)), "1 ahead east")
	assert_true(cells.has(Vector2i(5, 5)), "2 ahead east")
	assert_true(cells.has(Vector2i(6, 5)), "3 ahead east")
	assert_true(cells.has(Vector2i(7, 5)), "4 ahead east")
	# lateral cells (north/south when facing east)
	assert_true(cells.has(Vector2i(4, 4)), "1 ahead left (north)")
	assert_true(cells.has(Vector2i(4, 6)), "1 ahead right (south)")

func test_facing_south():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 3), Direction.SOUTH)
	assert_true(cells.has(Vector2i(5, 4)), "1 ahead south")
	assert_true(cells.has(Vector2i(5, 7)), "4 ahead south")

func test_facing_west():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.WEST)
	assert_true(cells.has(Vector2i(4, 5)), "1 ahead west")
	assert_true(cells.has(Vector2i(1, 5)), "4 ahead west")

func test_all_walls_only_player_cell():
	var wm = WizMap.new(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_eq(cells.size(), 1, "only player cell visible")
	assert_true(cells.has(Vector2i(5, 5)))

func test_door_does_not_block_view():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.NORTH, EdgeType.DOOR)
	wm.set_edge(5, 4, Direction.NORTH, EdgeType.OPEN)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_true(cells.has(Vector2i(5, 4)), "cell through door visible")
	assert_true(cells.has(Vector2i(5, 3)), "cell beyond door visible")

func test_near_side_wall_occludes_deeper_side_cells():
	var wm = _create_open_map(10)
	# wall on left at depth 1 should block left at depth 2+
	wm.set_edge(5, 4, Direction.WEST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(4, 4)), "depth 1 left blocked")
	assert_false(cells.has(Vector2i(4, 3)), "depth 2 left also blocked by nearer wall")
	assert_false(cells.has(Vector2i(4, 2)), "depth 3 left also blocked")
	# right side unaffected
	assert_true(cells.has(Vector2i(6, 4)), "depth 1 right still visible")
	assert_true(cells.has(Vector2i(6, 3)), "depth 2 right still visible")

func test_near_right_wall_occludes_deeper_right_cells():
	var wm = _create_open_map(10)
	wm.set_edge(5, 4, Direction.EAST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(6, 4)), "depth 1 right blocked")
	assert_false(cells.has(Vector2i(6, 3)), "depth 2 right also blocked")
	assert_true(cells.has(Vector2i(4, 4)), "depth 1 left still visible")
