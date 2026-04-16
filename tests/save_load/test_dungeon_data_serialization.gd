extends GutTest

func test_to_dict():
	var dd := DungeonData.create("テストダンジョン", 42, 8)
	dd.explored_map.mark_visited(Vector2i(1, 1))
	dd.explored_map.mark_visited(Vector2i(2, 2))
	var d := dd.to_dict()
	assert_eq(d["dungeon_name"], "テストダンジョン")
	assert_eq(d["seed_value"], 42)
	assert_eq(d["map_size"], 8)
	assert_true(d.has("explored_map"))
	assert_true(d.has("player_state"))

func test_to_dict_no_grid_data():
	var dd := DungeonData.create("ダンジョン", 42, 8)
	var d := dd.to_dict()
	assert_false(d.has("grid"))
	assert_false(d.has("_grid"))
	assert_false(d.has("cells"))

func test_from_dict_regenerates_map():
	var dd := DungeonData.create("再生成テスト", 42, 8)
	var d := dd.to_dict()
	var restored := DungeonData.from_dict(d)
	assert_eq(restored.dungeon_name, "再生成テスト")
	assert_eq(restored.seed_value, 42)
	assert_eq(restored.map_size, 8)
	assert_not_null(restored.wiz_map)
	assert_eq(restored.wiz_map.map_size, 8)

func test_from_dict_restores_explored_map():
	var dd := DungeonData.create("探索テスト", 100, 8)
	dd.explored_map.mark_visited(Vector2i(3, 3))
	var d := dd.to_dict()
	var restored := DungeonData.from_dict(d)
	assert_true(restored.explored_map.is_visited(Vector2i(3, 3)))

func test_from_dict_restores_player_state():
	var dd := DungeonData.create("位置テスト", 100, 8)
	var original_pos := dd.player_state.position
	var original_facing := dd.player_state.facing
	var d := dd.to_dict()
	var restored := DungeonData.from_dict(d)
	assert_eq(restored.player_state.position, original_pos)
	assert_eq(restored.player_state.facing, original_facing)

func test_roundtrip_map_is_identical():
	var dd := DungeonData.create("同一性テスト", 42, 10)
	var d := dd.to_dict()
	var restored := DungeonData.from_dict(d)
	# Same seed and size should produce identical maps
	for y in range(dd.map_size):
		for x in range(dd.map_size):
			assert_eq(
				restored.wiz_map.cell(x, y).tile,
				dd.wiz_map.cell(x, y).tile,
				"Cell tile mismatch at (%d, %d)" % [x, y]
			)
