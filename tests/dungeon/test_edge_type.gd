extends GutTest

func test_edge_type_values():
	assert_eq(EdgeType.WALL, 0)
	assert_eq(EdgeType.OPEN, 1)
	assert_eq(EdgeType.DOOR, 2)
