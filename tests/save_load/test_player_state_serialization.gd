extends GutTest

func test_to_dict():
	var ps := PlayerState.new(Vector2i(5, 7), Direction.NORTH)
	var d := ps.to_dict()
	assert_eq(d["position"], [5, 7])
	assert_eq(d["facing"], Direction.NORTH)

func test_to_dict_facing_east():
	var ps := PlayerState.new(Vector2i(3, 4), Direction.EAST)
	var d := ps.to_dict()
	assert_eq(d["position"], [3, 4])
	assert_eq(d["facing"], Direction.EAST)

func test_from_dict():
	var d := {"position": [5, 7], "facing": Direction.NORTH}
	var ps := PlayerState.from_dict(d)
	assert_eq(ps.position, Vector2i(5, 7))
	assert_eq(ps.facing, Direction.NORTH)

func test_from_dict_south():
	var d := {"position": [2, 8], "facing": Direction.SOUTH}
	var ps := PlayerState.from_dict(d)
	assert_eq(ps.position, Vector2i(2, 8))
	assert_eq(ps.facing, Direction.SOUTH)

func test_roundtrip():
	var original := PlayerState.new(Vector2i(10, 20), Direction.WEST)
	var restored := PlayerState.from_dict(original.to_dict())
	assert_eq(restored.position, original.position)
	assert_eq(restored.facing, original.facing)
