extends GutTest

func test_initially_no_cells_explored():
	var em = ExploredMap.new()
	assert_eq(em.get_visited_cells().size(), 0)

func test_mark_visited_single_cell():
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	assert_true(em.is_visited(Vector2i(3, 4)))

func test_unvisited_cell_returns_false():
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	assert_false(em.is_visited(Vector2i(5, 5)))

func test_mark_visible_multiple_cells():
	var em = ExploredMap.new()
	em.mark_visible([Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)])
	assert_true(em.is_visited(Vector2i(1, 1)))
	assert_true(em.is_visited(Vector2i(1, 2)))
	assert_true(em.is_visited(Vector2i(2, 1)))

func test_duplicate_marking_is_idempotent():
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	em.mark_visited(Vector2i(3, 4))
	var cells = em.get_visited_cells()
	var count = 0
	for c in cells:
		if c == Vector2i(3, 4):
			count += 1
	assert_eq(count, 1)

func test_clear_resets_all_state():
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	em.clear()
	assert_false(em.is_visited(Vector2i(3, 4)))
	assert_eq(em.get_visited_cells().size(), 0)

func test_get_visited_cells_returns_all():
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(1, 1))
	em.mark_visited(Vector2i(2, 3))
	var cells = em.get_visited_cells()
	assert_eq(cells.size(), 2)
	assert_has(cells, Vector2i(1, 1))
	assert_has(cells, Vector2i(2, 3))
