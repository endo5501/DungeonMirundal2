extends GutTest

var _screen: TownScreen

func before_each():
	_screen = TownScreen.new()

# --- Menu items ---

func test_menu_has_four_facilities():
	assert_eq(_screen.get_menu_items().size(), 4)

func test_facilities_in_order():
	var items := _screen.get_menu_items()
	assert_eq(items[0], "冒険者ギルド")
	assert_eq(items[1], "商店")
	assert_eq(items[2], "教会")
	assert_eq(items[3], "ダンジョン入口")

# --- Enabled items (all four enabled after items-and-economy) ---

func test_shop_is_enabled():
	assert_false(_screen.is_item_disabled(1))

func test_church_is_enabled():
	assert_false(_screen.is_item_disabled(2))

func test_guild_is_not_disabled():
	assert_false(_screen.is_item_disabled(0))

func test_dungeon_entrance_is_not_disabled():
	assert_false(_screen.is_item_disabled(3))

# --- Cursor moves through all entries ---

func test_cursor_starts_at_guild():
	assert_eq(_screen.selected_index, 0)

func test_cursor_down_moves_to_shop():
	_screen.move_cursor(1)
	assert_eq(_screen.selected_index, 1)

func test_cursor_up_wraps_to_dungeon_entrance():
	_screen.selected_index = 0
	_screen.move_cursor(-1)
	assert_eq(_screen.selected_index, 3)

func test_cursor_wraps_down():
	_screen.selected_index = 3
	_screen.move_cursor(1)
	assert_eq(_screen.selected_index, 0)

func test_cursor_wraps_up():
	_screen.move_cursor(-1)
	assert_eq(_screen.selected_index, 3)

# --- Signals ---

func test_guild_emits_open_guild():
	watch_signals(_screen)
	_screen.select_item(0)
	assert_signal_emitted(_screen, "open_guild")

func test_dungeon_entrance_emits_signal():
	watch_signals(_screen)
	_screen.select_item(3)
	assert_signal_emitted(_screen, "open_dungeon_entrance")

func test_shop_emits_open_shop():
	watch_signals(_screen)
	_screen.select_item(1)
	assert_signal_emitted(_screen, "open_shop")

func test_temple_emits_open_temple():
	watch_signals(_screen)
	_screen.select_item(2)
	assert_signal_emitted(_screen, "open_temple")

# --- Illustration data ---

func test_get_facility_color_returns_color():
	var color := _screen.get_facility_color(0)
	assert_typeof(color, TYPE_COLOR)

func test_different_facilities_have_different_colors():
	var c0 := _screen.get_facility_color(0)
	var c3 := _screen.get_facility_color(3)
	assert_ne(c0, c3)
