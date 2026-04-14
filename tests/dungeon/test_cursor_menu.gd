extends GutTest

func test_initial_index_is_zero():
	var menu := CursorMenu.new(["A", "B", "C"])
	assert_eq(menu.selected_index, 0)

func test_move_cursor_down():
	var menu := CursorMenu.new(["A", "B", "C"])
	menu.move_cursor(1)
	assert_eq(menu.selected_index, 1)

func test_move_cursor_wraps():
	var menu := CursorMenu.new(["A", "B", "C"])
	menu.selected_index = 2
	menu.move_cursor(1)
	assert_eq(menu.selected_index, 0)

func test_move_cursor_up_wraps():
	var menu := CursorMenu.new(["A", "B", "C"])
	menu.move_cursor(-1)
	assert_eq(menu.selected_index, 2)

func test_is_disabled():
	var menu := CursorMenu.new(["A", "B", "C"], [1])
	assert_false(menu.is_disabled(0))
	assert_true(menu.is_disabled(1))
	assert_false(menu.is_disabled(2))

func test_skip_disabled_down():
	var menu := CursorMenu.new(["A", "B", "C", "D"], [1, 2])
	menu.move_cursor(1)
	assert_eq(menu.selected_index, 3)

func test_skip_disabled_up():
	var menu := CursorMenu.new(["A", "B", "C", "D"], [1, 2])
	menu.selected_index = 3
	menu.move_cursor(-1)
	assert_eq(menu.selected_index, 0)

func test_all_disabled_stays_put():
	var menu := CursorMenu.new(["A", "B"], [0, 1])
	menu.move_cursor(1)
	assert_eq(menu.selected_index, 0)

func test_size():
	var menu := CursorMenu.new(["A", "B", "C"])
	assert_eq(menu.size(), 3)
