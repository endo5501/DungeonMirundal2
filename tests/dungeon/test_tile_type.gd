extends GutTest

func test_tile_type_values():
	assert_eq(TileType.FLOOR, 0)
	assert_eq(TileType.START, 1)
	assert_eq(TileType.GOAL, 2)
