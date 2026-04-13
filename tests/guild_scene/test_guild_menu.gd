extends GutTest

var _menu

func before_each():
	_menu = GuildMenu.new()
	add_child_autofree(_menu)

# --- Signals ---

func test_has_create_character_signal():
	assert_has_signal(_menu, "create_character_selected")

func test_has_party_formation_signal():
	assert_has_signal(_menu, "party_formation_selected")

func test_has_character_list_signal():
	assert_has_signal(_menu, "character_list_selected")

func test_has_leave_signal():
	assert_has_signal(_menu, "leave_selected")

# --- Menu items ---

func test_has_four_menu_items():
	assert_eq(_menu.get_menu_items().size(), 4)

func test_menu_item_labels():
	var items = _menu.get_menu_items()
	assert_eq(items[0], "キャラクターを作成する")
	assert_eq(items[1], "パーティ編成")
	assert_eq(items[2], "キャラクター一覧")
	assert_eq(items[3], "立ち去る")

# --- Selection emits signals ---

func test_select_create_character_emits_signal():
	watch_signals(_menu)
	_menu.select_item(0)
	assert_signal_emitted(_menu, "create_character_selected")

func test_select_party_formation_emits_signal():
	watch_signals(_menu)
	_menu.select_item(1)
	assert_signal_emitted(_menu, "party_formation_selected")

func test_select_character_list_emits_signal():
	watch_signals(_menu)
	_menu.select_item(2)
	assert_signal_emitted(_menu, "character_list_selected")

func test_select_leave_emits_signal():
	watch_signals(_menu)
	_menu.select_item(3)
	assert_signal_emitted(_menu, "leave_selected")
