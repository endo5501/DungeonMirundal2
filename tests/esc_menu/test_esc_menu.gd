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


# --- items-and-economy: equipment candidate fixes ---

func _setup_guild_with_two_fighters_and_weapons() -> Array:
	# Returns [fighter_a, fighter_b, sword_a_instance, sword_b_instance]
	if GameState.item_repository == null:
		GameState.item_repository = DataLoader.new().load_all_items()
	GameState.new_game()
	var repo := GameState.item_repository
	var inv := GameState.inventory
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var alloc := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var fa := Character.create("Alice", human, fighter, alloc)
	var fb := Character.create("Bob", human, fighter, alloc)
	GameState.guild.register(fa)
	GameState.guild.register(fb)
	GameState.guild.assign_to_party(fa, 0, 0)
	GameState.guild.assign_to_party(fb, 0, 1)
	var long_sword := repo.find(&"long_sword")
	var a_inst := ItemInstance.new(long_sword, true)
	var b_inst := ItemInstance.new(long_sword, true)
	inv.add(a_inst)
	inv.add(b_inst)
	fa.equipment.equip(Equipment.EquipSlot.WEAPON, a_inst, fa)
	fb.equipment.equip(Equipment.EquipSlot.WEAPON, b_inst, fb)
	return [fa, fb, a_inst, b_inst]


func _open_equipment_candidate_for(menu: EscMenu, character_index: int, slot_index: int) -> void:
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_EQUIPMENT
	menu.select_current_item()  # → equipment character
	menu._equipment_character_index = character_index
	menu.select_current_item()  # → slot
	menu._equipment_slot_index = slot_index
	menu.select_current_item()  # → candidate


func test_candidate_cursor_can_reach_last_item():
	var setup := _setup_guild_with_two_fighters_and_weapons()
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_equipment_candidate_for(menu, 0, 0)  # Alice, weapon
	var candidates_count: int = menu.get_equipment_candidates().size()
	# Navigate down `candidates_count` times — we should land on the last real candidate
	for i in range(candidates_count):
		menu._cursor_move_in_view(1)
	# After moving `candidates_count` times from index 0 ([はずす]),
	# we should be at index == candidates_count (the last candidate row)
	assert_eq(menu._equipment_candidate_index, candidates_count)


func test_candidate_cursor_wraps_through_unequip_entry():
	var setup := _setup_guild_with_two_fighters_and_weapons()
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_equipment_candidate_for(menu, 0, 0)
	var rows: int = menu.get_equipment_candidates().size() + 1
	# Wrapping: moving down `rows` times returns to 0
	for i in range(rows):
		menu._cursor_move_in_view(1)
	assert_eq(menu._equipment_candidate_index, 0)


func test_equip_from_other_character_unequips_them():
	var setup := _setup_guild_with_two_fighters_and_weapons()
	var alice: Character = setup[0]
	var bob: Character = setup[1]
	var b_inst: ItemInstance = setup[3]
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_equipment_candidate_for(menu, 0, 0)  # Alice, weapon

	# Find Bob's sword (b_inst) in Alice's candidate list
	var candidates := menu.get_equipment_candidates()
	var target_idx := -1
	for i in range(candidates.size()):
		if candidates[i] == b_inst:
			target_idx = i
			break
	assert_gte(target_idx, 0, "bob's sword should appear in candidates")

	menu._equipment_candidate_index = target_idx + 1  # +1 for [はずす]
	menu._confirm_equipment_candidate()

	# Alice now holds Bob's instance, Bob's weapon slot is empty
	assert_eq(alice.equipment.get_equipped(Equipment.EquipSlot.WEAPON), b_inst)
	assert_null(bob.equipment.get_equipped(Equipment.EquipSlot.WEAPON))

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
