extends GutTest

# Multi-floor DungeonData round-trip: post-load wiz_map (tile placement)
# and explored_map for every floor must match the original exactly.

func test_multi_floor_round_trip_wiz_map_identical():
	var dd := DungeonData.create("多階層テスト", 12345, 10, 3)
	var d := dd.to_dict()
	var restored := DungeonData.from_dict(d)
	assert_eq(restored.floors.size(), 3)
	for i in range(3):
		var src_wm := dd.floors[i].wiz_map
		var dst_wm := restored.floors[i].wiz_map
		assert_eq(dst_wm.map_size, src_wm.map_size, "floor %d map_size" % i)
		for y in range(src_wm.map_size):
			for x in range(src_wm.map_size):
				assert_eq(dst_wm.cell(x, y).tile, src_wm.cell(x, y).tile,
					"floor %d tile (%d,%d)" % [i, x, y])
				for dir in Direction.ALL:
					assert_eq(dst_wm.get_edge(x, y, dir), src_wm.get_edge(x, y, dir),
						"floor %d edge (%d,%d) dir %d" % [i, x, y, dir])

func test_multi_floor_round_trip_explored_map_identical():
	var dd := DungeonData.create("探索テスト", 99, 10, 3)
	dd.floors[0].explored_map.mark_visited(Vector2i(1, 2))
	dd.floors[1].explored_map.mark_visited(Vector2i(3, 4))
	dd.floors[1].explored_map.mark_visited(Vector2i(5, 6))
	dd.floors[2].explored_map.mark_visited(Vector2i(7, 8))
	var restored := DungeonData.from_dict(dd.to_dict())
	for i in range(3):
		assert_eq(restored.floors[i].explored_map.to_dict(),
			dd.floors[i].explored_map.to_dict(), "floor %d explored_map" % i)

func test_multi_floor_round_trip_player_position_and_floor():
	var dd := DungeonData.create("位置テスト", 42, 10, 4)
	dd.player_state.current_floor = 2
	dd.player_state.position = Vector2i(5, 7)
	dd.player_state.facing = Direction.WEST
	var restored := DungeonData.from_dict(dd.to_dict())
	assert_eq(restored.player_state.current_floor, 2)
	assert_eq(restored.player_state.position, Vector2i(5, 7))
	assert_eq(restored.player_state.facing, Direction.WEST)

func test_multi_floor_round_trip_each_floor_has_role_correct_tiles():
	var dd := DungeonData.create("役割テスト", 7, 10, 4)
	var restored := DungeonData.from_dict(dd.to_dict())
	# floor 0 (FIRST): START + STAIRS_DOWN
	assert_true(_has_tile(restored.floors[0].wiz_map, TileType.START))
	assert_true(_has_tile(restored.floors[0].wiz_map, TileType.STAIRS_DOWN))
	# floors 1, 2 (MIDDLE): STAIRS_UP + STAIRS_DOWN
	for i in [1, 2]:
		assert_true(_has_tile(restored.floors[i].wiz_map, TileType.STAIRS_UP), "floor %d STAIRS_UP" % i)
		assert_true(_has_tile(restored.floors[i].wiz_map, TileType.STAIRS_DOWN), "floor %d STAIRS_DOWN" % i)
	# floor 3 (LAST): STAIRS_UP + GOAL
	assert_true(_has_tile(restored.floors[3].wiz_map, TileType.STAIRS_UP))
	assert_true(_has_tile(restored.floors[3].wiz_map, TileType.GOAL))

func _has_tile(wiz_map: WizMap, tile: int) -> bool:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == tile:
				return true
	return false
