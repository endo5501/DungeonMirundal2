extends GutTest

func _create_dungeon_data(name: String = "テスト迷宮", seed_val: int = 42, size: int = 16) -> DungeonData:
	return DungeonData.create(name, seed_val, size)

func test_stores_name_seed_size():
	var dd := _create_dungeon_data("暗黒の迷宮", 99, 16)
	assert_eq(dd.dungeon_name, "暗黒の迷宮")
	assert_eq(dd.seed_value, 99)
	assert_eq(dd.map_size, 16)

func test_wiz_map_is_generated():
	var dd := _create_dungeon_data()
	assert_not_null(dd.wiz_map)
	assert_eq(dd.wiz_map.map_size, 16)

func test_explored_map_starts_empty():
	var dd := _create_dungeon_data()
	assert_eq(dd.explored_map.get_visited_cells().size(), 0)

func test_player_state_starts_at_start_tile():
	var dd := _create_dungeon_data()
	var pos := dd.player_state.position
	assert_eq(dd.wiz_map.cell(pos.x, pos.y).tile, TileType.START)

func test_player_state_faces_north():
	var dd := _create_dungeon_data()
	assert_eq(dd.player_state.facing, Direction.NORTH)

func test_exploration_rate_empty():
	var dd := _create_dungeon_data()
	assert_almost_eq(dd.get_exploration_rate(), 0.0, 0.001)

func test_exploration_rate_partial():
	var dd := _create_dungeon_data("test", 42, 8)
	# 8x8 = 64 cells, visit 16 => 25%
	for y in range(4):
		for x in range(4):
			dd.explored_map.mark_visited(Vector2i(x, y))
	assert_almost_eq(dd.get_exploration_rate(), 16.0 / 64.0, 0.001)

func test_exploration_rate_full():
	var dd := _create_dungeon_data("test", 42, 8)
	for y in range(8):
		for x in range(8):
			dd.explored_map.mark_visited(Vector2i(x, y))
	assert_almost_eq(dd.get_exploration_rate(), 1.0, 0.001)

# --- reset_to_start ---

func _start_tile_position(dd: DungeonData) -> Vector2i:
	for y in range(dd.wiz_map.map_size):
		for x in range(dd.wiz_map.map_size):
			if dd.wiz_map.cell(x, y).tile == TileType.START:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_reset_to_start_returns_player_to_start_tile():
	var dd := _create_dungeon_data()
	var start_pos := _start_tile_position(dd)
	# Move player elsewhere
	dd.player_state.position = start_pos + Vector2i(2, 3)
	dd.player_state.facing = Direction.SOUTH
	dd.reset_to_start()
	assert_eq(dd.player_state.position, start_pos)
	assert_eq(dd.player_state.facing, Direction.NORTH)

func test_reset_to_start_preserves_explored_map():
	var dd := _create_dungeon_data()
	dd.explored_map.mark_visited(Vector2i(1, 1))
	dd.explored_map.mark_visited(Vector2i(2, 2))
	var before_count := dd.explored_map.get_visited_count()
	var before_dict := dd.explored_map.to_dict()
	dd.reset_to_start()
	assert_eq(dd.explored_map.get_visited_count(), before_count)
	assert_eq(dd.explored_map.to_dict(), before_dict)

func test_reset_to_start_preserves_identity_fields():
	var dd := _create_dungeon_data("守護者の塔", 1234, 16)
	var before_wiz_map := dd.wiz_map
	dd.reset_to_start()
	assert_eq(dd.dungeon_name, "守護者の塔")
	assert_eq(dd.seed_value, 1234)
	assert_eq(dd.map_size, 16)
	assert_same(dd.wiz_map, before_wiz_map)

func test_reset_to_start_is_idempotent():
	var dd := _create_dungeon_data()
	var start_pos := _start_tile_position(dd)
	dd.player_state.position = start_pos + Vector2i(1, 0)
	dd.reset_to_start()
	var pos_after_first := dd.player_state.position
	var facing_after_first := dd.player_state.facing
	dd.reset_to_start()
	assert_eq(dd.player_state.position, pos_after_first)
	assert_eq(dd.player_state.facing, facing_after_first)
