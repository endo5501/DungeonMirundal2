extends GutTest


# --- helpers ---

func _make_potion() -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "ポーション"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = 20
	it.effect = e
	var tc: Array[TargetCondition] = [AliveOnly.new()]
	it.target_conditions = tc
	return it


func _make_escape_scroll() -> Item:
	var it := Item.new()
	it.item_id = &"escape_scroll"
	it.item_name = "脱出の巻物"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	it.effect = EscapeToTownEffect.new()
	var cc: Array[ContextCondition] = [InDungeonOnly.new(), NotInCombatOnly.new()]
	it.context_conditions = cc
	return it


func _make_sword() -> Item:
	var it := Item.new()
	it.item_id = &"long_sword"
	it.item_name = "Long Sword"
	it.category = Item.ItemCategory.WEAPON
	it.equip_slot = Item.EquipSlot.WEAPON
	return it


func _make_character(p_name: String = "Aragorn", hp: int = 10, max_hp: int = 40) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = load("res://data/races/human.tres") as RaceData
	ch.job = load("res://data/jobs/fighter.tres") as JobData
	ch.base_stats = {&"STR": 10, &"INT": 10, &"PIE": 10, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = hp
	ch.max_hp = max_hp
	ch.current_mp = 0
	ch.max_mp = 0
	return ch


func _make_ctx(in_combat: bool = false, in_dungeon: bool = true) -> ItemUseContext:
	return ItemUseContext.make(in_dungeon, in_combat, [])


func _inv_with(items: Array) -> Inventory:
	var inv := Inventory.new()
	for it in items:
		inv.add(ItemInstance.new(it, true))
	return inv


func _make_flow_with(items: Array, party: Array, in_combat: bool = false, in_dungeon: bool = true) -> ItemUseFlow:
	var flow := ItemUseFlow.new()
	add_child_autofree(flow)
	var inv := _inv_with(items)
	var typed_party: Array[Character] = []
	for ch in party:
		typed_party.append(ch)
	flow.setup(_make_ctx(in_combat, in_dungeon), inv, typed_party)
	return flow


func _accept() -> InputEventAction:
	return TestHelpers.make_action_event(&"ui_accept")


func _cancel() -> InputEventAction:
	return TestHelpers.make_action_event(&"ui_cancel")


func _down() -> InputEventAction:
	return TestHelpers.make_action_event(&"ui_down")


# --- 1.1 init ---

func test_setup_initializes_to_select_item():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)


# --- 1.2 item select → SELECT_TARGET ---

func test_item_select_with_target_conditions_advances_to_select_target():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	flow.handle_input(_accept())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_TARGET)


func test_item_select_without_target_conditions_advances_to_confirm():
	var flow := _make_flow_with([_make_escape_scroll()], [_make_character()])
	flow.handle_input(_accept())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.CONFIRM)


# --- 1.3 target select → CONFIRM ---

func test_target_select_advances_to_confirm():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM
	assert_eq(flow._sub_view, ItemUseFlow.SubView.CONFIRM)


# --- 1.4 yes confirm → effect → RESULT ---

func test_confirm_yes_applies_effect_and_advances_to_result():
	var ch := _make_character("Aragorn", 10, 40)
	var flow := _make_flow_with([_make_potion()], [ch])
	var inst: ItemInstance = flow._inventory.list()[0]
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM
	flow.handle_input(_accept())  # → RESULT (yes is default)
	assert_eq(flow._sub_view, ItemUseFlow.SubView.RESULT)
	assert_eq(ch.current_hp, 30)
	assert_false(flow._inventory.contains(inst))


func test_confirm_no_returns_to_select_item():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM (yes default)
	flow.handle_input(_down())    # → いいえ
	flow.handle_input(_accept())  # confirm "no"
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)


# --- 1.5 RESULT → flow_completed ---

func test_result_ui_accept_emits_flow_completed():
	var flow := _make_flow_with([_make_potion()], [_make_character("A", 10, 40)])
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM
	flow.handle_input(_accept())  # RESULT
	watch_signals(flow)
	flow.handle_input(_accept())
	assert_signal_emitted(flow, "flow_completed")


func test_result_ui_cancel_emits_flow_completed():
	var flow := _make_flow_with([_make_potion()], [_make_character("A", 10, 40)])
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM
	flow.handle_input(_accept())  # RESULT
	watch_signals(flow)
	flow.handle_input(_cancel())
	assert_signal_emitted(flow, "flow_completed")


func test_escape_scroll_success_emits_town_return():
	var flow := _make_flow_with([_make_escape_scroll()], [_make_character()])
	watch_signals(flow)
	flow.handle_input(_accept())  # CONFIRM (no targets)
	flow.handle_input(_accept())  # → RESULT (yes default)
	# Result should be RESULT, and town_return_requested should fire on success
	assert_signal_emitted(flow, "town_return_requested")


# --- 1.6 ui_cancel transitions ---

func test_cancel_from_select_item_emits_empty_flow_completed():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	watch_signals(flow)
	flow.handle_input(_cancel())
	assert_signal_emitted_with_parameters(flow, "flow_completed", [""])


func test_cancel_from_select_target_returns_to_select_item():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	flow.handle_input(_accept())  # → SELECT_TARGET
	flow.handle_input(_cancel())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)


func test_cancel_from_confirm_with_targets_returns_to_select_target():
	var flow := _make_flow_with([_make_potion()], [_make_character()])
	flow.handle_input(_accept())  # SELECT_TARGET
	flow.handle_input(_accept())  # CONFIRM
	flow.handle_input(_cancel())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_TARGET)


func test_cancel_from_confirm_without_targets_returns_to_select_item():
	var flow := _make_flow_with([_make_escape_scroll()], [_make_character()])
	flow.handle_input(_accept())  # CONFIRM (no targets)
	flow.handle_input(_cancel())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)


# --- 1.7 ItemUseContext filter ---

func test_context_failure_item_does_not_advance_on_accept():
	# Escape scroll requires not-in-combat. With in_combat=true, accept should be a no-op.
	var flow := _make_flow_with([_make_escape_scroll()], [_make_character()], true, true)
	flow.handle_input(_accept())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)


func test_non_consumable_item_does_not_advance_on_accept():
	var flow := _make_flow_with([_make_sword()], [_make_character()])
	flow.handle_input(_accept())
	assert_eq(flow._sub_view, ItemUseFlow.SubView.SELECT_ITEM)
