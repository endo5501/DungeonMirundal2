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


# --- 10. Items flow delegation ---

func _open_party_menu(menu: EscMenu) -> void:
	menu.show_menu()
	menu.select_current_item()  # → party menu


func test_select_items_switches_to_items_flow_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS_FLOW)


func test_select_items_makes_item_use_flow_visible():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()
	assert_true(menu._item_use_flow.visible)


func test_item_use_flow_completed_returns_to_party_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()  # → ITEMS_FLOW
	menu._item_use_flow.flow_completed.emit("")
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)
	assert_false(menu._item_use_flow.visible)


func test_item_use_flow_town_return_emits_return_to_town():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()  # → ITEMS_FLOW
	menu._item_use_flow.town_return_requested.emit()
	assert_signal_emitted(menu, "return_to_town_requested")
	assert_false(menu.is_menu_visible())


# --- 11. Equipment flow delegation ---

func test_select_equipment_switches_to_equipment_flow_view():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.EQUIPMENT_FLOW)


func test_select_equipment_makes_equipment_flow_visible():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()
	assert_true(menu._equipment_flow.visible)


func test_equipment_flow_completed_returns_to_party_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()  # → EQUIPMENT_FLOW
	menu._equipment_flow.flow_completed.emit()
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)
	assert_false(menu._equipment_flow.visible)


# --- 11b. Flow Controls do not consume input while EscMenu is hidden ---
# Regression: CanvasLayer.visible does not propagate to Control children's
# `visible` property. Without explicit reset, ItemUseFlow / EquipmentFlow
# would keep `visible = true` (default) even when the EscMenu CanvasLayer
# is hidden — their _unhandled_input would then steal keys from screens
# like TitleScreen.

func test_flows_hidden_when_menu_initially_hidden():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	assert_false(menu.is_menu_visible())
	assert_false(menu._item_use_flow.visible)
	assert_false(menu._equipment_flow.visible)


func test_flows_hidden_after_hide_menu_from_items_flow():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()  # → ITEMS_FLOW (flow visible)
	assert_true(menu._item_use_flow.visible)
	menu.hide_menu()
	assert_false(menu.is_menu_visible())
	assert_false(menu._item_use_flow.visible)


func test_flows_hidden_after_hide_menu_from_equipment_flow():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()  # → EQUIPMENT_FLOW (flow visible)
	assert_true(menu._equipment_flow.visible)
	menu.hide_menu()
	assert_false(menu.is_menu_visible())
	assert_false(menu._equipment_flow.visible)


# --- 12. Input handling ---

func test_handle_input_down_moves_cursor():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.handle_input(TestHelpers.make_action_event(&"ui_down"))
	# Should move to index 1 (ゲームを保存, now enabled)
	assert_eq(menu.get_main_menu().selected_index, 1)

func test_handle_input_enter_selects():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_eq(menu.get_current_view(), EscMenu.View.PARTY_MENU)

func test_handle_input_escape_goes_back():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.handle_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_eq(menu.get_current_view(), EscMenu.View.MAIN_MENU)


# --- 13. Input is delegated to flow when in flow view ---

func test_handle_input_ignored_in_items_flow():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()  # → ITEMS_FLOW
	# handle_input on the menu should NOT route to its own go_back/select_current_item;
	# the ItemUseFlow handles input via its own _unhandled_input.
	var handled: bool = menu.handle_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_false(handled)
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS_FLOW)


func test_handle_input_ignored_in_equipment_flow():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_party_menu(menu)
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()  # → EQUIPMENT_FLOW
	var handled: bool = menu.handle_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_false(handled)
	assert_eq(menu.get_current_view(), EscMenu.View.EQUIPMENT_FLOW)
