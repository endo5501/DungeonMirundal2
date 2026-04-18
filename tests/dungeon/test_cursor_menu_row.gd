extends GutTest

var _row: CursorMenuRow

func before_each():
	_row = CursorMenuRow.new()
	add_child_autofree(_row)

# --- Construction ---

func test_has_cursor_slot_at_index_zero():
	assert_true(_row.get_child_count() >= 2, "row should have cursor slot + text label")
	var first: Node = _row.get_child(0)
	assert_true(first is Control, "first child should be the cursor slot Control")

func test_has_text_label_at_index_one():
	var second: Node = _row.get_child(1)
	assert_true(second is Label, "second child should be the text Label")

func test_initial_state_unselected():
	assert_false(_row.is_selected(), "row should start unselected")

# --- set_selected ---

func test_set_selected_true_shows_indicator():
	_row.set_selected(true)
	assert_true(_row.is_selected())
	var icon: CanvasItem = _row.get_cursor_icon()
	assert_true(icon.visible, "cursor icon should be visible when selected")

func test_set_selected_false_hides_indicator():
	_row.set_selected(true)
	_row.set_selected(false)
	var icon: CanvasItem = _row.get_cursor_icon()
	assert_false(icon.visible, "cursor icon should be hidden when unselected")

func test_cursor_slot_width_is_constant_across_states():
	var slot: Control = _row.get_cursor_slot()
	_row.set_selected(false)
	var w_unselected: float = slot.custom_minimum_size.x
	_row.set_selected(true)
	var w_selected: float = slot.custom_minimum_size.x
	assert_eq(w_selected, w_unselected, "cursor slot width should not depend on selection")
	assert_gt(w_unselected, 0.0, "cursor slot should have a fixed width > 0")

# --- set_text ---

func test_set_text_updates_text_label():
	_row.set_text("ヘルロー")
	assert_eq(_row.get_text_label().text, "ヘルロー")

# --- set_disabled ---

func test_set_disabled_true_uses_disabled_color():
	_row.set_text("X")
	_row.set_disabled(true)
	var color: Color = _row.get_text_label().get_theme_color("font_color")
	assert_eq(color, CursorMenu.DISABLED_COLOR)

func test_set_disabled_false_uses_enabled_color():
	_row.set_text("X")
	_row.set_disabled(true)
	_row.set_disabled(false)
	var color: Color = _row.get_text_label().get_theme_color("font_color")
	assert_eq(color, CursorMenu.ENABLED_COLOR)

# --- add_extra_label ---

func test_add_extra_label_appends_to_right():
	var extra := Label.new()
	extra.text = "16x16"
	_row.add_extra_label(extra)
	var last: Node = _row.get_child(_row.get_child_count() - 1)
	assert_eq(last, extra, "extra label should be the rightmost child")

func test_cursor_slot_width_unchanged_after_extra_label():
	var slot: Control = _row.get_cursor_slot()
	var w_before: float = slot.custom_minimum_size.x
	var extra := Label.new()
	extra.text = "extra"
	_row.add_extra_label(extra)
	var w_after: float = slot.custom_minimum_size.x
	assert_eq(w_after, w_before, "adding extra label should not change cursor slot width")

func test_extra_labels_use_disabled_color_when_disabled():
	var extra := Label.new()
	extra.text = "extra"
	_row.add_extra_label(extra)
	_row.set_disabled(true)
	var color: Color = extra.get_theme_color("font_color")
	assert_eq(color, CursorMenu.DISABLED_COLOR)

func test_set_text_font_size_applies_to_text_label():
	_row.set_text_font_size(20)
	var size: int = _row.get_text_label().get_theme_font_size("font_size")
	assert_eq(size, 20)
