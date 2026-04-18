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

# --- update_rows ---

func _make_rows(n: int) -> Array[CursorMenuRow]:
	var rows: Array[CursorMenuRow] = []
	for i in range(n):
		var r := CursorMenuRow.new()
		r.set_text("item_%d" % i)
		add_child_autofree(r)
		rows.append(r)
	return rows

func test_update_rows_marks_selected_row_only():
	var menu := CursorMenu.new(["A", "B", "C"])
	menu.selected_index = 1
	var rows := _make_rows(3)
	menu.update_rows(rows)
	assert_false(rows[0].is_selected())
	assert_true(rows[1].is_selected())
	assert_false(rows[2].is_selected())

func test_update_rows_reflects_cursor_movement():
	var menu := CursorMenu.new(["A", "B", "C"])
	var rows := _make_rows(3)
	menu.update_rows(rows)
	assert_true(rows[0].is_selected())
	menu.move_cursor(1)
	menu.update_rows(rows)
	assert_false(rows[0].is_selected())
	assert_true(rows[1].is_selected())

func test_update_rows_applies_disabled_color():
	var menu := CursorMenu.new(["A", "B", "C"], [0, 2])
	var rows := _make_rows(3)
	menu.update_rows(rows)
	var c0: Color = rows[0].get_text_label().get_theme_color("font_color")
	var c1: Color = rows[1].get_text_label().get_theme_color("font_color")
	var c2: Color = rows[2].get_text_label().get_theme_color("font_color")
	assert_eq(c0, CursorMenu.DISABLED_COLOR)
	assert_eq(c1, CursorMenu.ENABLED_COLOR)
	assert_eq(c2, CursorMenu.DISABLED_COLOR)

func test_update_rows_with_empty_array_does_not_crash():
	var menu := CursorMenu.new([])
	var rows: Array[CursorMenuRow] = []
	menu.update_rows(rows)
	pass_test("did not crash")
