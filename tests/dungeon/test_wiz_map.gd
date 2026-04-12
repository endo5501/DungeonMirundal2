extends GutTest

func test_minimum_size_constraint():
	var map = WizMap.new(7)
	assert_false(map.is_valid(), "size 7 should not be valid")

func test_valid_size_creates_grid():
	var map = WizMap.new(8)
	assert_eq(map.map_size, 8)
	assert_true(map.is_valid())

func test_all_edges_are_walls_initially():
	var map = WizMap.new(8)
	for y in range(8):
		for x in range(8):
			var c = map.cell(x, y)
			for dir in Direction.ALL:
				assert_eq(c.get_edge(dir), EdgeType.WALL,
					"cell(%d,%d) dir %d should be WALL" % [x, y, dir])

func test_all_tiles_are_floor_initially():
	var map = WizMap.new(8)
	for y in range(8):
		for x in range(8):
			assert_eq(map.cell(x, y).tile, TileType.FLOOR)

func test_in_bounds():
	var map = WizMap.new(10)
	assert_true(map.in_bounds(0, 0))
	assert_true(map.in_bounds(9, 9))
	assert_false(map.in_bounds(-1, 0))
	assert_false(map.in_bounds(0, -1))
	assert_false(map.in_bounds(10, 0))
	assert_false(map.in_bounds(0, 10))

func test_get_and_set_edge():
	var map = WizMap.new(8)
	map.set_edge(2, 3, Direction.NORTH, EdgeType.OPEN)
	assert_eq(map.get_edge(2, 3, Direction.NORTH), EdgeType.OPEN)

# --- Edge bidirectional sync ---

func test_set_edge_syncs_neighbor_east():
	var map = WizMap.new(8)
	map.set_edge(2, 3, Direction.EAST, EdgeType.OPEN)
	assert_eq(map.get_edge(2, 3, Direction.EAST), EdgeType.OPEN)
	assert_eq(map.get_edge(3, 3, Direction.WEST), EdgeType.OPEN)

func test_set_edge_syncs_neighbor_south():
	var map = WizMap.new(8)
	map.set_edge(4, 4, Direction.SOUTH, EdgeType.DOOR)
	assert_eq(map.get_edge(4, 4, Direction.SOUTH), EdgeType.DOOR)
	assert_eq(map.get_edge(4, 5, Direction.NORTH), EdgeType.DOOR)

func test_open_between_horizontal():
	var map = WizMap.new(8)
	map.open_between(1, 1, 2, 1)
	assert_eq(map.get_edge(1, 1, Direction.EAST), EdgeType.OPEN)
	assert_eq(map.get_edge(2, 1, Direction.WEST), EdgeType.OPEN)

func test_open_between_vertical():
	var map = WizMap.new(8)
	map.open_between(3, 3, 3, 4)
	assert_eq(map.get_edge(3, 3, Direction.SOUTH), EdgeType.OPEN)
	assert_eq(map.get_edge(3, 4, Direction.NORTH), EdgeType.OPEN)

func test_set_edge_at_boundary_no_crash():
	var map = WizMap.new(8)
	map.set_edge(0, 0, Direction.NORTH, EdgeType.OPEN)
	assert_eq(map.get_edge(0, 0, Direction.NORTH), EdgeType.OPEN)

# --- can_move ---

func test_can_move_blocked_by_wall():
	var map = WizMap.new(8)
	assert_false(map.can_move(1, 1, Direction.NORTH), "wall blocks movement")

func test_can_move_through_open():
	var map = WizMap.new(8)
	map.set_edge(1, 1, Direction.EAST, EdgeType.OPEN)
	assert_true(map.can_move(1, 1, Direction.EAST), "OPEN allows movement")

func test_can_move_through_door():
	var map = WizMap.new(8)
	map.set_edge(1, 1, Direction.SOUTH, EdgeType.DOOR)
	assert_true(map.can_move(1, 1, Direction.SOUTH), "DOOR allows movement")

func test_can_move_out_of_bounds():
	var map = WizMap.new(8)
	assert_false(map.can_move(0, 0, Direction.NORTH), "cannot move out of bounds")

# --- carve_perfect_maze ---

func _count_open_edges(map: WizMap) -> int:
	var count := 0
	for y in range(map.map_size):
		for x in range(map.map_size):
			if x < map.map_size - 1 and map.get_edge(x, y, Direction.EAST) == EdgeType.OPEN:
				count += 1
			if y < map.map_size - 1 and map.get_edge(x, y, Direction.SOUTH) == EdgeType.OPEN:
				count += 1
	return count

func test_carve_perfect_maze_all_connected():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	assert_eq(map.bfs(Vector2i(0, 0)).size(), 100, "all 10x10=100 cells should be reachable")

func test_carve_perfect_maze_spanning_tree_edges():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	var open_count := _count_open_edges(map)
	assert_eq(open_count, 99, "spanning tree has N-1 edges (100-1=99)")

# --- generate_rooms ---

func test_generate_rooms_size_constraints():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.generate_rooms(rng, 50, 2, 5)
	assert_true(map.rooms.size() > 0, "should generate at least one room")
	for room in map.rooms:
		assert_true(room.w >= 2 and room.w <= 5, "room width in range")
		assert_true(room.h >= 2 and room.h <= 5, "room height in range")
		assert_true(room.x >= 1, "room not at left edge")
		assert_true(room.y >= 1, "room not at top edge")
		assert_true(room.x + room.w - 1 < map.map_size, "room not at right edge")
		assert_true(room.y + room.h - 1 < map.map_size, "room not at bottom edge")

func test_generate_rooms_no_overlap():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.generate_rooms(rng, 50, 2, 5)
	for i in range(map.rooms.size()):
		for j in range(i + 1, map.rooms.size()):
			assert_false(map.rooms[i].intersects(map.rooms[j], 1),
				"rooms %d and %d should not overlap with margin" % [i, j])

# --- carve_room / carve_rooms ---

func test_carve_room_opens_interior():
	var map = WizMap.new(10)
	var room = MapRect.new(2, 2, 3, 3)
	map.rooms.append(room)
	map.carve_room(room)
	for y in range(2, 5):
		for x in range(2, 4):
			assert_eq(map.get_edge(x, y, Direction.EAST), EdgeType.OPEN,
				"interior east edge at (%d,%d)" % [x, y])
	for y in range(2, 4):
		for x in range(2, 5):
			assert_eq(map.get_edge(x, y, Direction.SOUTH), EdgeType.OPEN,
				"interior south edge at (%d,%d)" % [x, y])

func test_carve_rooms_all_rooms():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	map.generate_rooms(rng, 50, 2, 5)
	map.carve_rooms()
	for room in map.rooms:
		for y in range(room.y, room.y + room.h):
			for x in range(room.x, room.x + room.w):
				if x < room.x2():
					assert_eq(map.get_edge(x, y, Direction.EAST), EdgeType.OPEN)
				if y < room.y2():
					assert_eq(map.get_edge(x, y, Direction.SOUTH), EdgeType.OPEN)

# --- add_extra_links ---

func test_add_extra_links_opens_walls():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	var before := _count_open_edges(map)
	map.add_extra_links(rng, 3)
	var after := _count_open_edges(map)
	assert_true(after > before, "extra links should open additional walls")
	assert_true(after <= before + 3, "at most 3 extra links")

func test_add_extra_links_maintains_connectivity():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	map.add_extra_links(rng, 5)
	assert_true(map.is_fully_connected(), "still fully connected")

# --- add_doors_between_room_and_nonroom ---

func test_doors_only_at_room_boundaries():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	map.generate_rooms(rng, 50, 2, 5)
	map.carve_rooms()
	map.add_doors_between_room_and_nonroom(rng, 1.0)
	for y in range(map.map_size):
		for x in range(map.map_size):
			for dir in [Direction.EAST, Direction.SOUTH]:
				if map.get_edge(x, y, dir) == EdgeType.DOOR:
					var n := Vector2i(x, y) + Direction.offset(dir)
					if map.in_bounds(n.x, n.y):
						var a_in := map.in_any_room(x, y)
						var b_in := map.in_any_room(n.x, n.y)
						assert_true(a_in != b_in,
							"DOOR at (%d,%d)->(%d,%d) should be at room boundary" % [x, y, n.x, n.y])

# --- BFS ---

func test_bfs_distances():
	var map = WizMap.new(8)
	map.open_between(0, 0, 1, 0)
	map.open_between(1, 0, 2, 0)
	var dist := map.bfs(Vector2i(0, 0))
	assert_eq(dist[Vector2i(0, 0)], 0)
	assert_eq(dist[Vector2i(1, 0)], 1)
	assert_eq(dist[Vector2i(2, 0)], 2)
	assert_false(dist.has(Vector2i(3, 0)), "unreachable cell not in result")

func test_bfs_full_maze():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	var dist := map.bfs(Vector2i(0, 0))
	assert_eq(dist.size(), 100, "all cells reachable in maze")

# --- is_fully_connected ---

func test_is_fully_connected_after_maze():
	var map = WizMap.new(10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	assert_true(map.is_fully_connected())

func test_is_not_fully_connected_initial():
	var map = WizMap.new(8)
	assert_false(map.is_fully_connected(), "all walls = not connected")

# --- place_start_and_goal ---

func test_place_start_and_goal():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	map.generate_rooms(rng, 50, 2, 5)
	map.carve_rooms()
	map.place_start_and_goal(rng)
	var start_count := 0
	var goal_count := 0
	var start_pos := Vector2i(-1, -1)
	var goal_pos := Vector2i(-1, -1)
	for y in range(map.map_size):
		for x in range(map.map_size):
			if map.cell(x, y).tile == TileType.START:
				start_count += 1
				start_pos = Vector2i(x, y)
			elif map.cell(x, y).tile == TileType.GOAL:
				goal_count += 1
				goal_pos = Vector2i(x, y)
	assert_eq(start_count, 1, "exactly one START")
	assert_eq(goal_count, 1, "exactly one GOAL")
	var dist := map.bfs(start_pos)
	var max_dist := 0
	for d in dist.values():
		if d > max_dist:
			max_dist = d
	assert_eq(dist[goal_pos], max_dist, "GOAL is at maximum BFS distance")

func test_place_start_in_room():
	var map = WizMap.new(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	map.carve_perfect_maze(rng)
	map.generate_rooms(rng, 50, 2, 5)
	map.carve_rooms()
	map.place_start_and_goal(rng)
	var start_pos := Vector2i(-1, -1)
	for y in range(map.map_size):
		for x in range(map.map_size):
			if map.cell(x, y).tile == TileType.START:
				start_pos = Vector2i(x, y)
	assert_true(map.in_any_room(start_pos.x, start_pos.y), "START should be inside a room")

# --- generate (integration) ---

func test_generate_default_params():
	var map = WizMap.new(20)
	map.generate(42)
	assert_true(map.is_fully_connected(), "generated map is fully connected")
	var start_count := 0
	var goal_count := 0
	for y in range(map.map_size):
		for x in range(map.map_size):
			if map.cell(x, y).tile == TileType.START:
				start_count += 1
			elif map.cell(x, y).tile == TileType.GOAL:
				goal_count += 1
	assert_eq(start_count, 1, "one START")
	assert_eq(goal_count, 1, "one GOAL")

func test_generate_custom_params():
	var map = WizMap.new(15)
	map.generate(99, 30, 2, 5, 3, 0.55)
	assert_true(map.is_fully_connected(), "custom params: fully connected")
	assert_true(map.rooms.size() > 0, "custom params: has rooms")

func test_generate_seed_reproducibility():
	var map1 = WizMap.new(10)
	map1.generate(42)
	var map2 = WizMap.new(10)
	map2.generate(42)
	var identical := true
	for y in range(10):
		for x in range(10):
			if map1.cell(x, y).tile != map2.cell(x, y).tile:
				identical = false
			for dir in Direction.ALL:
				if map1.get_edge(x, y, dir) != map2.get_edge(x, y, dir):
					identical = false
	assert_true(identical, "same seed produces identical map")

func test_generate_different_seeds_differ():
	var map1 = WizMap.new(10)
	map1.generate(42)
	var map2 = WizMap.new(10)
	map2.generate(99)
	var identical := true
	for y in range(10):
		for x in range(10):
			for dir in Direction.ALL:
				if map1.get_edge(x, y, dir) != map2.get_edge(x, y, dir):
					identical = false
					break
			if not identical:
				break
		if not identical:
			break
	assert_false(identical, "different seeds produce different maps")
