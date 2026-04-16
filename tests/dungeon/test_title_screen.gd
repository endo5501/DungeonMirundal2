extends GutTest

var _screen: TitleScreen

func before_each():
	_screen = TitleScreen.new()

# --- Menu items ---

func test_menu_has_four_items():
	assert_eq(_screen.get_menu_items().size(), 4)

func test_menu_items_in_order():
	var items := _screen.get_menu_items()
	assert_eq(items[0], "新規ゲーム")
	assert_eq(items[1], "前回から")
	assert_eq(items[2], "ロード")
	assert_eq(items[3], "ゲーム終了")

# --- Cursor ---

func test_cursor_starts_at_first_item():
	assert_eq(_screen.selected_index, 0)

func test_cursor_moves_down():
	# From 0 (新規ゲーム), skips disabled 1,2 to 3 (ゲーム終了)
	_screen.move_cursor(1)
	assert_eq(_screen.selected_index, 3)

func test_cursor_wraps_from_bottom_to_top():
	_screen.selected_index = 3
	_screen.move_cursor(1)
	assert_eq(_screen.selected_index, 0)

func test_cursor_wraps_from_top_to_bottom():
	_screen.move_cursor(-1)
	assert_eq(_screen.selected_index, 3)

# --- Disabled items ---

func test_continue_is_disabled():
	assert_true(_screen.is_item_disabled(1))

func test_load_is_disabled():
	assert_true(_screen.is_item_disabled(2))

func test_new_game_is_not_disabled():
	assert_false(_screen.is_item_disabled(0))

func test_quit_is_not_disabled():
	assert_false(_screen.is_item_disabled(3))

# --- Signals ---

func test_new_game_emits_signal():
	watch_signals(_screen)
	_screen.select_item(0)
	assert_signal_emitted(_screen, "start_new_game")

func test_disabled_item_does_not_emit_signal():
	watch_signals(_screen)
	_screen.select_item(1)  # "前回から" is disabled
	assert_signal_not_emitted(_screen, "continue_game")

func test_quit_emits_signal():
	watch_signals(_screen)
	_screen.select_item(3)
	assert_signal_emitted(_screen, "quit_game")

# --- Cursor skip disabled ---

func test_cursor_down_skips_disabled():
	_screen.move_cursor(1)  # From 0 (新規ゲーム) should skip 1,2 to 3 (ゲーム終了)
	assert_eq(_screen.selected_index, 3)

func test_cursor_up_skips_disabled():
	_screen.selected_index = 3
	_screen.move_cursor(-1)  # From 3 should skip 2,1 to 0
	assert_eq(_screen.selected_index, 0)

# --- Layout centering ---

func _find_center_container(node: Node) -> CenterContainer:
	for child in node.get_children():
		if child is CenterContainer:
			return child as CenterContainer
	return null

func test_uses_center_container_for_layout():
	var screen := TitleScreen.new()
	add_child_autofree(screen)
	assert_not_null(_find_center_container(screen), "TitleScreen should use CenterContainer for centering")

func test_center_container_covers_full_rect():
	var screen := TitleScreen.new()
	add_child_autofree(screen)
	var center := _find_center_container(screen)
	assert_not_null(center)
	assert_eq(center.anchor_right, 1.0, "CenterContainer should span full width")
	assert_eq(center.anchor_bottom, 1.0, "CenterContainer should span full height")
