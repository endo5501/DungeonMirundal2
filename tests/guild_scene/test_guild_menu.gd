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

# --- Cursor selection ---

func test_initial_selected_index_is_zero():
	assert_eq(_menu.selected_index, 0)

func test_move_cursor_down():
	_menu.move_cursor(1)
	assert_eq(_menu.selected_index, 1)

func test_move_cursor_up():
	_menu.move_cursor(1)
	_menu.move_cursor(-1)
	assert_eq(_menu.selected_index, 0)

func test_cursor_wraps_down():
	_menu.move_cursor(1)
	_menu.move_cursor(1)
	_menu.move_cursor(1)
	_menu.move_cursor(1)  # past end
	assert_eq(_menu.selected_index, 0)

func test_cursor_wraps_up():
	_menu.move_cursor(-1)  # from 0, wrap to 3
	assert_eq(_menu.selected_index, 3)

func test_confirm_emits_selected_signal():
	watch_signals(_menu)
	_menu.move_cursor(1)  # -> index 1 (party formation)
	_menu.confirm_selection()
	assert_signal_emitted(_menu, "party_formation_selected")

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

# --- Layout centering ---

func _find_center_container(node: Node) -> CenterContainer:
	for child in node.get_children():
		if child is CenterContainer:
			return child as CenterContainer
	return null

func test_menu_uses_center_container_for_layout():
	assert_not_null(_find_center_container(_menu), "GuildMenu should use CenterContainer for centering")

func test_center_container_covers_full_rect():
	var center := _find_center_container(_menu)
	assert_not_null(center)
	assert_eq(center.anchor_right, 1.0, "CenterContainer should span full width")
	assert_eq(center.anchor_bottom, 1.0, "CenterContainer should span full height")
