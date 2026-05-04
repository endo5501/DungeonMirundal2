extends GutTest

const DEFAULT_FLOOR_COUNT := 3

func _create_dungeon_data(name: String = "テスト迷宮", base_seed: int = 42, size: int = 16, floor_count: int = DEFAULT_FLOOR_COUNT) -> DungeonData:
	return DungeonData.create(name, base_seed, size, floor_count)

# --- Basic identity ---

func test_stores_name():
	var dd := _create_dungeon_data("暗黒の迷宮", 99, 16, 3)
	assert_eq(dd.dungeon_name, "暗黒の迷宮")

func test_floors_array_has_specified_count():
	var dd := _create_dungeon_data("迷宮", 99, 16, 4)
	assert_eq(dd.floors.size(), 4)

func test_floors_have_specified_map_size():
	var dd := _create_dungeon_data("迷宮", 99, 16, 3)
	for fd in dd.floors:
		assert_eq(fd.map_size, 16)

func test_floors_have_distinct_seeds():
	var dd := _create_dungeon_data("迷宮", 99, 16, 3)
	var seen := {}
	for fd in dd.floors:
		assert_false(seen.has(fd.seed_value), "seed values must be distinct across floors")
		seen[fd.seed_value] = true

func test_floor_seeds_are_deterministic_from_base_seed():
	var dd1 := _create_dungeon_data("迷宮", 99, 16, 3)
	var dd2 := _create_dungeon_data("迷宮", 99, 16, 3)
	for i in range(3):
		assert_eq(dd1.floors[i].seed_value, dd2.floors[i].seed_value,
			"floor[%d] seed must be deterministically derived from base_seed" % i)

func test_floors_have_role_appropriate_tiles():
	var dd := _create_dungeon_data("迷宮", 99, 16, 3)
	# floor 0: START + STAIRS_DOWN
	assert_true(_has_tile(dd.floors[0].wiz_map, TileType.START))
	assert_true(_has_tile(dd.floors[0].wiz_map, TileType.STAIRS_DOWN))
	assert_false(_has_tile(dd.floors[0].wiz_map, TileType.GOAL))
	# floor 1 (middle): STAIRS_UP + STAIRS_DOWN
	assert_true(_has_tile(dd.floors[1].wiz_map, TileType.STAIRS_UP))
	assert_true(_has_tile(dd.floors[1].wiz_map, TileType.STAIRS_DOWN))
	# floor 2 (last): STAIRS_UP + GOAL
	assert_true(_has_tile(dd.floors[2].wiz_map, TileType.STAIRS_UP))
	assert_true(_has_tile(dd.floors[2].wiz_map, TileType.GOAL))

func test_single_floor_dungeon_uses_single_role():
	var dd := _create_dungeon_data("一階のみ", 42, 16, 1)
	assert_eq(dd.floors.size(), 1)
	assert_true(_has_tile(dd.floors[0].wiz_map, TileType.START))
	assert_true(_has_tile(dd.floors[0].wiz_map, TileType.GOAL))

func _has_tile(wiz_map: WizMap, tile: int) -> bool:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == tile:
				return true
	return false

# --- Player state ---

func test_player_state_starts_at_floor_0_start_tile():
	var dd := _create_dungeon_data()
	assert_eq(dd.player_state.current_floor, 0)
	var pos := dd.player_state.position
	assert_eq(dd.floors[0].wiz_map.cell(pos.x, pos.y).tile, TileType.START)

func test_player_state_faces_north():
	var dd := _create_dungeon_data()
	assert_eq(dd.player_state.facing, Direction.NORTH)

# --- current_wiz_map / current_explored_map accessors ---

func test_current_wiz_map_returns_floor_at_current_floor():
	var dd := _create_dungeon_data("迷宮", 42, 16, 3)
	dd.player_state.current_floor = 1
	assert_same(dd.current_wiz_map(), dd.floors[1].wiz_map)
	dd.player_state.current_floor = 2
	assert_same(dd.current_wiz_map(), dd.floors[2].wiz_map)

func test_current_explored_map_returns_floor_at_current_floor():
	var dd := _create_dungeon_data("迷宮", 42, 16, 3)
	dd.player_state.current_floor = 0
	assert_same(dd.current_explored_map(), dd.floors[0].explored_map)
	dd.player_state.current_floor = 2
	assert_same(dd.current_explored_map(), dd.floors[2].explored_map)

# --- Exploration rate ---

func test_exploration_rate_empty():
	var dd := _create_dungeon_data()
	assert_almost_eq(dd.get_exploration_rate(), 0.0, 0.001)

func test_exploration_rate_partial_across_floors():
	var dd := _create_dungeon_data("test", 42, 8, 2)
	# 8x8 = 64 per floor, total 128
	# visit 16 cells in floor 0, 0 in floor 1 => 16/128 = 0.125
	for y in range(4):
		for x in range(4):
			dd.floors[0].explored_map.mark_visited(Vector2i(x, y))
	assert_almost_eq(dd.get_exploration_rate(), 16.0 / 128.0, 0.001)

func test_exploration_rate_single_floor_matches_legacy():
	var dd := _create_dungeon_data("test", 42, 8, 1)
	for y in range(4):
		for x in range(4):
			dd.floors[0].explored_map.mark_visited(Vector2i(x, y))
	assert_almost_eq(dd.get_exploration_rate(), 16.0 / 64.0, 0.001)

func test_exploration_rate_full():
	var dd := _create_dungeon_data("test", 42, 8, 2)
	for fd in dd.floors:
		for y in range(8):
			for x in range(8):
				fd.explored_map.mark_visited(Vector2i(x, y))
	assert_almost_eq(dd.get_exploration_rate(), 1.0, 0.001)

# --- reset_to_start ---

func test_reset_to_start_returns_player_to_floor_0_start():
	var dd := _create_dungeon_data()
	dd.player_state.current_floor = 1
	dd.player_state.position = Vector2i(0, 0)
	dd.player_state.facing = Direction.SOUTH
	dd.reset_to_start()
	assert_eq(dd.player_state.current_floor, 0)
	var pos := dd.player_state.position
	assert_eq(dd.floors[0].wiz_map.cell(pos.x, pos.y).tile, TileType.START)
	assert_eq(dd.player_state.facing, Direction.NORTH)

func test_reset_to_start_preserves_explored_maps():
	var dd := _create_dungeon_data("迷宮", 42, 16, 2)
	dd.floors[0].explored_map.mark_visited(Vector2i(1, 1))
	dd.floors[1].explored_map.mark_visited(Vector2i(2, 2))
	var before_floor0 := dd.floors[0].explored_map.to_dict()
	var before_floor1 := dd.floors[1].explored_map.to_dict()
	dd.reset_to_start()
	assert_eq(dd.floors[0].explored_map.to_dict(), before_floor0)
	assert_eq(dd.floors[1].explored_map.to_dict(), before_floor1)

func test_reset_to_start_preserves_dungeon_identity():
	var dd := _create_dungeon_data("守護者の塔", 1234, 16, 3)
	var floors_ref := dd.floors
	dd.reset_to_start()
	assert_eq(dd.dungeon_name, "守護者の塔")
	assert_same(dd.floors, floors_ref)
	assert_eq(dd.floors.size(), 3)

func test_reset_to_start_is_idempotent():
	var dd := _create_dungeon_data()
	dd.player_state.position = Vector2i(0, 0)
	dd.reset_to_start()
	var pos_after_first := dd.player_state.position
	var floor_after_first := dd.player_state.current_floor
	dd.reset_to_start()
	assert_eq(dd.player_state.position, pos_after_first)
	assert_eq(dd.player_state.current_floor, floor_after_first)

# --- to_dict / from_dict ---

func test_to_dict_contains_floors_and_player_state():
	var dd := _create_dungeon_data("迷宮", 42, 16, 2)
	var d := dd.to_dict()
	assert_eq(d.get("dungeon_name", ""), "迷宮")
	assert_true(d.has("floors"), "to_dict has floors array")
	assert_eq((d.get("floors", []) as Array).size(), 2)
	assert_true(d.has("player_state"), "to_dict has player_state")

func test_to_dict_has_no_legacy_seed_or_map_size():
	var dd := _create_dungeon_data("迷宮", 42, 16, 2)
	var d := dd.to_dict()
	assert_false(d.has("seed_value"), "legacy seed_value must not appear at top level")
	assert_false(d.has("map_size"), "legacy map_size must not appear at top level")
	assert_false(d.has("explored_map"), "legacy explored_map must not appear at top level")

func test_from_dict_round_trip_multi_floor():
	var src := _create_dungeon_data("迷宮", 42, 16, 3)
	src.floors[0].explored_map.mark_visited(Vector2i(1, 2))
	src.floors[1].explored_map.mark_visited(Vector2i(3, 4))
	src.player_state.current_floor = 2
	src.player_state.position = Vector2i(5, 6)
	src.player_state.facing = Direction.EAST
	var restored := DungeonData.from_dict(src.to_dict())
	assert_eq(restored.dungeon_name, "迷宮")
	assert_eq(restored.floors.size(), 3)
	for i in range(3):
		assert_eq(restored.floors[i].seed_value, src.floors[i].seed_value)
		assert_eq(restored.floors[i].map_size, src.floors[i].map_size)
	assert_true(restored.floors[0].explored_map.is_visited(Vector2i(1, 2)))
	assert_true(restored.floors[1].explored_map.is_visited(Vector2i(3, 4)))
	assert_eq(restored.player_state.position, Vector2i(5, 6))
	assert_eq(restored.player_state.facing, Direction.EAST)
	assert_eq(restored.player_state.current_floor, 2)

func test_from_dict_restores_role_correct_tiles():
	var src := _create_dungeon_data("迷宮", 42, 16, 3)
	var restored := DungeonData.from_dict(src.to_dict())
	assert_true(_has_tile(restored.floors[0].wiz_map, TileType.START))
	assert_true(_has_tile(restored.floors[0].wiz_map, TileType.STAIRS_DOWN))
	assert_true(_has_tile(restored.floors[1].wiz_map, TileType.STAIRS_UP))
	assert_true(_has_tile(restored.floors[1].wiz_map, TileType.STAIRS_DOWN))
	assert_true(_has_tile(restored.floors[2].wiz_map, TileType.STAIRS_UP))
	assert_true(_has_tile(restored.floors[2].wiz_map, TileType.GOAL))
