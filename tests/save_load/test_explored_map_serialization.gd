extends GutTest

func test_to_dict_empty():
	var em := ExploredMap.new()
	var d := em.to_dict()
	assert_eq(d["visited"], [])

func test_to_dict_with_cells():
	var em := ExploredMap.new()
	em.mark_visited(Vector2i(2, 3))
	em.mark_visited(Vector2i(4, 5))
	var d := em.to_dict()
	assert_eq(d["visited"].size(), 2)
	assert_has(d["visited"], [2, 3])
	assert_has(d["visited"], [4, 5])

func test_from_dict_empty():
	var d := {"visited": []}
	var em := ExploredMap.from_dict(d)
	assert_eq(em.get_visited_count(), 0)

func test_from_dict_with_cells():
	var d := {"visited": [[2, 3], [4, 5]]}
	var em := ExploredMap.from_dict(d)
	assert_true(em.is_visited(Vector2i(2, 3)))
	assert_true(em.is_visited(Vector2i(4, 5)))
	assert_false(em.is_visited(Vector2i(0, 0)))
	assert_eq(em.get_visited_count(), 2)

func test_roundtrip():
	var original := ExploredMap.new()
	original.mark_visited(Vector2i(1, 1))
	original.mark_visited(Vector2i(7, 3))
	original.mark_visited(Vector2i(5, 9))
	var restored := ExploredMap.from_dict(original.to_dict())
	assert_eq(restored.get_visited_count(), original.get_visited_count())
	for cell in original.get_visited_cells():
		assert_true(restored.is_visited(cell))
