extends GutTest

func test_default_tile_is_floor():
	var cell = Cell.new()
	assert_eq(cell.tile, TileType.FLOOR)

func test_default_edges_are_walls():
	var cell = Cell.new()
	for dir in Direction.ALL:
		assert_eq(cell.get_edge(dir), EdgeType.WALL,
			"direction %d should be WALL" % dir)

func test_set_and_get_edge():
	var cell = Cell.new()
	cell.set_edge(Direction.NORTH, EdgeType.OPEN)
	assert_eq(cell.get_edge(Direction.NORTH), EdgeType.OPEN)
	assert_eq(cell.get_edge(Direction.EAST), EdgeType.WALL)

func test_set_tile():
	var cell = Cell.new()
	cell.tile = TileType.START
	assert_eq(cell.tile, TileType.START)
