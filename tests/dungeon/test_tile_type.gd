extends GutTest

func test_tile_type_values():
	assert_eq(TileType.FLOOR, 0)
	assert_eq(TileType.START, 1)
	assert_eq(TileType.GOAL, 2)
	assert_eq(TileType.STAIRS_DOWN, 3)
	assert_eq(TileType.STAIRS_UP, 4)

func test_tile_type_stairs_down_defined():
	assert_true(TileType.STAIRS_DOWN >= 0, "STAIRS_DOWN must be a defined enum value")

func test_tile_type_stairs_up_defined():
	assert_true(TileType.STAIRS_UP >= 0, "STAIRS_UP must be a defined enum value")
