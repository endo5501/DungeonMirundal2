extends GutTest

# --- FloorData.create ---

func test_create_stores_seed_and_size():
	var fd := FloorData.create(42, 16, FloorRole.SINGLE)
	assert_eq(fd.seed_value, 42)
	assert_eq(fd.map_size, 16)

func test_create_generates_wiz_map_of_size():
	var fd := FloorData.create(42, 16, FloorRole.SINGLE)
	assert_not_null(fd.wiz_map)
	assert_eq(fd.wiz_map.map_size, 16)

func test_create_starts_with_empty_explored_map():
	var fd := FloorData.create(42, 16, FloorRole.SINGLE)
	assert_not_null(fd.explored_map)
	assert_eq(fd.explored_map.get_visited_count(), 0)

# --- Role-based tile placement ---

func _count_tiles(wiz_map: WizMap, tile: int) -> int:
	var count := 0
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == tile:
				count += 1
	return count

func test_single_floor_has_start_and_goal():
	var fd := FloorData.create(42, 16, FloorRole.SINGLE)
	assert_eq(_count_tiles(fd.wiz_map, TileType.START), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.GOAL), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_DOWN), 0)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_UP), 0)

func test_first_floor_has_start_and_stairs_down():
	var fd := FloorData.create(42, 16, FloorRole.FIRST)
	assert_eq(_count_tiles(fd.wiz_map, TileType.START), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_DOWN), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.GOAL), 0)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_UP), 0)

func test_middle_floor_has_stairs_up_and_stairs_down():
	var fd := FloorData.create(42, 16, FloorRole.MIDDLE)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_UP), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_DOWN), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.START), 0)
	assert_eq(_count_tiles(fd.wiz_map, TileType.GOAL), 0)

func test_last_floor_has_stairs_up_and_goal():
	var fd := FloorData.create(42, 16, FloorRole.LAST)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_UP), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.GOAL), 1)
	assert_eq(_count_tiles(fd.wiz_map, TileType.START), 0)
	assert_eq(_count_tiles(fd.wiz_map, TileType.STAIRS_DOWN), 0)

# --- to_dict / from_dict ---

func test_to_dict_contains_seed_size_explored_only():
	var fd := FloorData.create(42, 16, FloorRole.SINGLE)
	fd.explored_map.mark_visited(Vector2i(2, 3))
	var d := fd.to_dict()
	assert_eq(int(d.get("seed_value", -1)), 42)
	assert_eq(int(d.get("map_size", -1)), 16)
	assert_true(d.has("explored_map"), "to_dict includes explored_map")
	assert_false(d.has("wiz_map"), "to_dict must NOT include wiz_map cell data")

func test_from_dict_restores_seed_size_and_explored_map():
	var src := FloorData.create(42, 16, FloorRole.SINGLE)
	src.explored_map.mark_visited(Vector2i(2, 3))
	src.explored_map.mark_visited(Vector2i(4, 5))
	var d := src.to_dict()
	var restored := FloorData.from_dict(d, FloorRole.SINGLE)
	assert_eq(restored.seed_value, 42)
	assert_eq(restored.map_size, 16)
	assert_true(restored.explored_map.is_visited(Vector2i(2, 3)))
	assert_true(restored.explored_map.is_visited(Vector2i(4, 5)))
	assert_eq(restored.explored_map.get_visited_count(), 2)

func test_from_dict_regenerates_identical_wiz_map_for_same_seed_and_role():
	var fd1 := FloorData.create(42, 16, FloorRole.MIDDLE)
	var d := fd1.to_dict()
	var fd2 := FloorData.from_dict(d, FloorRole.MIDDLE)
	for y in range(16):
		for x in range(16):
			assert_eq(fd1.wiz_map.cell(x, y).tile, fd2.wiz_map.cell(x, y).tile,
				"tile at (%d,%d) differs" % [x, y])
			for dir in Direction.ALL:
				assert_eq(fd1.wiz_map.get_edge(x, y, dir), fd2.wiz_map.get_edge(x, y, dir),
					"edge at (%d,%d) dir %d differs" % [x, y, dir])

func test_round_trip_preserves_data():
	var src := FloorData.create(99, 12, FloorRole.LAST)
	src.explored_map.mark_visible([Vector2i(1, 1), Vector2i(1, 2)])
	var restored := FloorData.from_dict(src.to_dict(), FloorRole.LAST)
	assert_eq(restored.seed_value, 99)
	assert_eq(restored.map_size, 12)
	assert_eq(restored.explored_map.get_visited_count(), 2)
