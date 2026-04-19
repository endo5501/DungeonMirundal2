extends GutTest


func _make_potion() -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "ポーション"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = 20
	it.effect = e
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


func _make_emergency() -> Item:
	var it := Item.new()
	it.item_id = &"emergency_escape_scroll"
	it.item_name = "緊急脱出の巻物"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	it.effect = EscapeToTownEffect.new()
	var cc: Array[ContextCondition] = [InDungeonOnly.new()]
	it.context_conditions = cc
	return it


func _make_sword() -> Item:
	var it := Item.new()
	it.item_id = &"long_sword"
	it.item_name = "Long Sword"
	it.category = Item.ItemCategory.WEAPON
	it.equip_slot = Item.EquipSlot.WEAPON
	return it


func test_selector_excludes_non_consumable():
	var sel := CombatItemSelector.new()
	add_child_autofree(sel)
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_make_sword(), true))
	sel.show_with(inv, ItemUseContext.make(true, true))
	assert_true(sel.is_empty())


func test_selector_includes_consumables():
	var sel := CombatItemSelector.new()
	add_child_autofree(sel)
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_make_potion(), true))
	inv.add(ItemInstance.new(_make_sword(), true))
	sel.show_with(inv, ItemUseContext.make(true, true))
	var entries := sel.get_entries()
	assert_eq(entries.size(), 1)
	assert_true(entries[0].usable)


func test_selector_marks_escape_scroll_as_not_usable_in_combat():
	var sel := CombatItemSelector.new()
	add_child_autofree(sel)
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_make_escape_scroll(), true))
	sel.show_with(inv, ItemUseContext.make(true, true))
	var entries := sel.get_entries()
	assert_eq(entries.size(), 1)
	assert_false(entries[0].usable)
	assert_true(entries[0].reason.length() > 0)


func test_selector_marks_emergency_scroll_as_usable_in_combat():
	var sel := CombatItemSelector.new()
	add_child_autofree(sel)
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_make_emergency(), true))
	sel.show_with(inv, ItemUseContext.make(true, true))
	var entries := sel.get_entries()
	assert_eq(entries.size(), 1)
	assert_true(entries[0].usable)


func test_empty_inventory_is_empty():
	var sel := CombatItemSelector.new()
	add_child_autofree(sel)
	sel.show_with(Inventory.new(), ItemUseContext.make(true, true))
	assert_true(sel.is_empty())
