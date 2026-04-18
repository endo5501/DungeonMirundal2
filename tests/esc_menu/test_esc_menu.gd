extends GutTest

# --- 1. Basic structure ---

func test_esc_menu_is_canvas_layer():
	var menu := EscMenu.new()
	assert_is(menu, CanvasLayer)
	menu.free()

func test_esc_menu_layer_is_10():
	var menu := EscMenu.new()
	assert_eq(menu.layer, 10)
	menu.free()

func test_esc_menu_initially_hidden():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	assert_false(menu.is_menu_visible())

# --- 2. show/hide ---

func test_show_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	assert_true(menu.is_menu_visible())

func test_hide_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.hide_menu()
	assert_false(menu.is_menu_visible())

func test_show_menu_resets_to_main_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)

# --- 3. Main menu items ---

func test_main_menu_has_five_items():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	assert_eq(menu.get_main_menu().size(), 5)

func test_main_menu_disabled_indices():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	var main := menu.get_main_menu()
	assert_false(main.is_disabled(0), "パーティ should be enabled")
	assert_false(main.is_disabled(1), "ゲームを保存 should be enabled")
	assert_false(main.is_disabled(2), "ゲームをロード should be enabled")
	assert_true(main.is_disabled(3), "設定 should be disabled")
	assert_false(main.is_disabled(4), "終了 should be enabled")

# --- 4. Menu selection: パーティ ---

func test_select_party_switches_to_party_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # index 0 = パーティ
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)

# --- 5. Menu selection: 終了 ---

func test_select_quit_switches_to_quit_dialog():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.get_main_menu().selected_index = 4  # 終了
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.QUIT_DIALOG)

# --- 6. Quit dialog ---

func test_quit_dialog_confirm_emits_signal():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.get_main_menu().selected_index = 4
	menu.select_current_item()  # → quit dialog
	watch_signals(menu)
	menu.get_quit_menu().selected_index = 0  # はい
	menu.select_current_item()
	assert_signal_emitted(menu, "quit_to_title")

func test_quit_dialog_cancel_returns_to_main():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.get_main_menu().selected_index = 4
	menu.select_current_item()  # → quit dialog
	menu.get_quit_menu().selected_index = 1  # いいえ
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)

# --- 7. Party menu ---

func test_party_menu_has_three_items():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	assert_eq(menu.get_party_menu().size(), 3)

func test_party_menu_all_enabled():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	var party := menu.get_party_menu()
	assert_false(party.is_disabled(0), "ステータス should be enabled")
	assert_false(party.is_disabled(1), "アイテム should be enabled")
	assert_false(party.is_disabled(2), "装備 should be enabled")

# --- 8. Navigation: ESC to go back ---

func test_esc_from_party_menu_returns_to_main():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)

func test_esc_from_main_menu_hides_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.go_back()
	assert_false(menu.is_menu_visible())

func test_esc_from_quit_dialog_returns_to_main():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.get_main_menu().selected_index = 4
	menu.select_current_item()  # → quit dialog
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)

# --- 9. Party status view ---

func test_select_status_switches_to_status_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # index 0 = ステータス
	assert_eq(menu.get_current_view(), EscMenu.View.STATUS)

func test_esc_from_status_returns_to_party_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)


# --- items-and-economy: item view / equipment view ---

func test_select_item_opens_items_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS)


func test_esc_from_items_returns_to_party_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)


func test_select_equipment_opens_character_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.EQUIPMENT_CHARACTER)


func test_equipment_character_to_slot_via_select():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.EQUIPMENT_SLOT)


func test_esc_from_equipment_slot_returns_to_character():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	menu.select_current_item()  # char → slot
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.EQUIPMENT_CHARACTER)


func test_esc_from_equipment_character_returns_to_party():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)

# --- 10. Input handling ---

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func test_handle_input_down_moves_cursor():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.handle_input(_make_key_event(KEY_DOWN))
	# Should move to index 1 (ゲームを保存, now enabled)
	assert_eq(menu.get_main_menu().selected_index, 1)

func test_handle_input_enter_selects():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.handle_input(_make_key_event(KEY_ENTER))
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)

func test_handle_input_escape_goes_back():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.handle_input(_make_key_event(KEY_ESCAPE))
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)
