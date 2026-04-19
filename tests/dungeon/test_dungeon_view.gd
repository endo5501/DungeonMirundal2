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

func test_door_blocks_view_when_block_doors():
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.NORTH, EdgeType.DOOR)
	wm.set_edge(5, 4, Direction.NORTH, EdgeType.OPEN)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, true)
	assert_false(cells.has(Vector2i(5, 4)), "cell through door not visible with block_doors")
	assert_false(cells.has(Vector2i(5, 3)), "cell beyond door not visible with block_doors")

func test_door_blocks_lateral_when_block_doors():
	var wm = _create_open_map(10)
	wm.set_edge(5, 5, Direction.WEST, EdgeType.DOOR)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, true)
	assert_false(cells.has(Vector2i(4, 5)), "lateral cell through door blocked")
	assert_true(cells.has(Vector2i(6, 5)), "other side still visible")

func test_lateral_cells_at_player_position():
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	# player cell laterals should be included when edges are open
	assert_true(cells.has(Vector2i(4, 5)), "left cell at player depth")
	assert_true(cells.has(Vector2i(6, 5)), "right cell at player depth")

func test_lateral_cells_at_player_blocked_by_wall():
	var wm = _create_open_map(10)
	wm.set_edge(5, 5, Direction.WEST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(4, 5)), "left blocked at player depth")
	assert_true(cells.has(Vector2i(6, 5)), "right still open at player depth")

func test_near_side_wall_blocks_only_its_own_lateral():
	var wm = _create_open_map(10)
	# A wall on the west edge of the cell at depth 1 hides that particular
	# left cell, but lateral openings at deeper cells are checked per-depth
	# and so remain visible (the depth buffer handles the actual occlusion).
	wm.set_edge(5, 4, Direction.WEST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(4, 4)), "depth 1 left blocked by its own wall")
	assert_true(cells.has(Vector2i(4, 3)), "depth 2 left visible via opening at its own depth")
	assert_true(cells.has(Vector2i(4, 2)), "depth 3 left visible via opening at its own depth")
	# right side unaffected
	assert_true(cells.has(Vector2i(6, 4)), "depth 1 right still visible")
	assert_true(cells.has(Vector2i(6, 3)), "depth 2 right still visible")

func test_near_right_wall_blocks_only_its_own_lateral():
	var wm = _create_open_map(10)
	wm.set_edge(5, 4, Direction.EAST, EdgeType.WALL)
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(6, 4)), "depth 1 right blocked by its own wall")
	assert_true(cells.has(Vector2i(6, 3)), "depth 2 right visible via opening at its own depth")
	assert_true(cells.has(Vector2i(6, 2)), "depth 3 right visible via opening at its own depth")
	assert_true(cells.has(Vector2i(4, 4)), "depth 1 left still visible")

func test_lateral_blocks_only_at_its_own_depth():
	# Explicit coverage of the "branch becomes visible via opening" case.
	var wm = _create_open_map(10)
	wm.set_edge(5, 4, Direction.WEST, EdgeType.WALL)   # blocks (4, 4)
	wm.set_edge(5, 3, Direction.WEST, EdgeType.WALL)   # blocks (4, 3)
	# (5, 2) keeps its OPEN west edge from the default map
	var dv = DungeonView.new()
	var cells = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH)
	assert_false(cells.has(Vector2i(4, 4)))
	assert_false(cells.has(Vector2i(4, 3)))
	assert_true(cells.has(Vector2i(4, 2)), "branch at depth 3 visible again")


# --- fill_openings (used for rendering to prevent pitch-black voids) ---

func test_fill_openings_adds_one_hop_through_open_edges():
	# Player at (5, 5) facing N in a fully-open map. Without fill_openings,
	# the far lateral column (3, 5), (7, 5) stays out of the view. With
	# fill_openings, those become visible as renderable filler.
	var wm = _create_open_map(10)
	var dv = DungeonView.new()
	var strict = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, false, false)
	var filled = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, false, true)
	assert_false(strict.has(Vector2i(3, 5)), "strict view stops at 1 cell lateral")
	assert_true(filled.has(Vector2i(3, 5)), "fill_openings reaches +2 lateral via open hop")
	assert_true(filled.has(Vector2i(7, 5)), "fill_openings reaches -2 lateral via open hop")


func test_fill_openings_does_not_cross_walls():
	# A wall should still block the flood.
	var wm = WizMap.new(10)  # all walls by default
	var dv = DungeonView.new()
	var filled = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, false, true)
	assert_eq(filled.size(), 1, "no flood across walls; only the player cell")


func test_fill_openings_flood_only_follows_open_edges():
	# Doors are handled by the main pass (can_move sees through them when
	# block_doors is false); the flood itself uses only OPEN edges so it
	# does not expand the render set further through a door chain.
	var wm = WizMap.new(10)
	wm.set_edge(5, 5, Direction.NORTH, EdgeType.DOOR)
	wm.set_edge(5, 4, Direction.WEST, EdgeType.DOOR)
	var dv = DungeonView.new()
	var filled = dv.get_visible_cells(wm, Vector2i(5, 5), Direction.NORTH, false, true)
	# (5, 4) is added by the main pass through the forward DOOR.
	assert_true(filled.has(Vector2i(5, 4)))
	# (4, 4) reached only via a lateral DOOR from (5, 4): depth-1 lateral
	# uses can_move which traverses doors, so it IS included.
	assert_true(filled.has(Vector2i(4, 4)))
	# However a farther cell reachable only through another door from
	# (4, 4) should NOT be flood-added because flood requires OPEN.
	# Here (3, 4) is walled off from (4, 4), so it stays out.
	assert_false(filled.has(Vector2i(3, 4)))
