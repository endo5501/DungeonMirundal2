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

# --- ensure_valid_selection ---

func test_ensure_valid_selection_skips_disabled_initial_index():
	var menu := CursorMenu.new(["A", "B", "C"], [0])
	assert_eq(menu.selected_index, 0)
	menu.ensure_valid_selection()
	assert_eq(menu.selected_index, 1)

func test_ensure_valid_selection_skips_multiple_disabled():
	var menu := CursorMenu.new(["A", "B", "C", "D"], [0, 1])
	menu.ensure_valid_selection()
	assert_eq(menu.selected_index, 2)

func test_ensure_valid_selection_noop_when_already_enabled():
	var menu := CursorMenu.new(["A", "B", "C"], [2])
	menu.ensure_valid_selection()
	assert_eq(menu.selected_index, 0)

func test_ensure_valid_selection_all_disabled_stays_put():
	var menu := CursorMenu.new(["A", "B"], [0, 1])
	menu.selected_index = 0
	menu.ensure_valid_selection()
	assert_eq(menu.selected_index, 0)

func test_ensure_valid_selection_from_non_zero_start():
	var menu := CursorMenu.new(["A", "B", "C", "D"], [1, 2])
	menu.selected_index = 1
	menu.ensure_valid_selection()
	assert_eq(menu.selected_index, 3)
