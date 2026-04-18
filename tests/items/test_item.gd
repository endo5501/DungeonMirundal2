extends GutTest


func _make_item() -> Item:
	var item := Item.new()
	item.item_id = &"long_sword"
	item.item_name = "Long Sword"
	item.unidentified_name = "剣?"
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	item.allowed_jobs = [&"Fighter", &"Samurai", &"Lord"]
	item.attack_bonus = 6
	item.defense_bonus = 0
	item.agility_bonus = 0
	item.price = 150
	return item


func test_item_is_resource():
	var item := Item.new()
	assert_is(item, Resource)


func test_item_exposes_required_fields():
	var item := _make_item()
	assert_eq(item.item_id, &"long_sword")
	assert_eq(item.item_name, "Long Sword")
	assert_eq(item.unidentified_name, "剣?")
	assert_eq(item.category, Item.ItemCategory.WEAPON)
	assert_eq(item.equip_slot, Item.EquipSlot.WEAPON)
	assert_eq(item.allowed_jobs, [&"Fighter", &"Samurai", &"Lord"])
	assert_eq(item.attack_bonus, 6)
	assert_eq(item.defense_bonus, 0)
	assert_eq(item.agility_bonus, 0)
	assert_eq(item.price, 150)


func test_item_category_enum_has_expected_values():
	assert_true(Item.ItemCategory.WEAPON != Item.ItemCategory.OTHER)
	assert_true(Item.ItemCategory.ARMOR != Item.ItemCategory.WEAPON)
	# Enumerate expected categories
	var values := [
		Item.ItemCategory.WEAPON,
		Item.ItemCategory.ARMOR,
		Item.ItemCategory.HELMET,
		Item.ItemCategory.SHIELD,
		Item.ItemCategory.GAUNTLET,
		Item.ItemCategory.ACCESSORY,
		Item.ItemCategory.OTHER,
	]
	# All values must be distinct
	var seen := {}
	for v in values:
		assert_false(seen.has(v))
		seen[v] = true


func test_equip_slot_enum_includes_none():
	# EquipSlot.NONE exists and is distinct from WEAPON
	assert_true(Item.EquipSlot.NONE != Item.EquipSlot.WEAPON)


# --- Task 1.3: category/equip_slot consistency ---

func test_weapon_category_maps_to_weapon_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	assert_true(item.is_slot_consistent())


func test_armor_category_maps_to_armor_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.ARMOR
	item.equip_slot = Item.EquipSlot.ARMOR
	assert_true(item.is_slot_consistent())


func test_helmet_category_maps_to_helmet_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.HELMET
	item.equip_slot = Item.EquipSlot.HELMET
	assert_true(item.is_slot_consistent())


func test_shield_category_maps_to_shield_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.SHIELD
	item.equip_slot = Item.EquipSlot.SHIELD
	assert_true(item.is_slot_consistent())


func test_gauntlet_category_maps_to_gauntlet_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.GAUNTLET
	item.equip_slot = Item.EquipSlot.GAUNTLET
	assert_true(item.is_slot_consistent())


func test_accessory_category_maps_to_accessory_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.ACCESSORY
	item.equip_slot = Item.EquipSlot.ACCESSORY
	assert_true(item.is_slot_consistent())


func test_other_category_uses_none_slot():
	var item := Item.new()
	item.category = Item.ItemCategory.OTHER
	item.equip_slot = Item.EquipSlot.NONE
	assert_true(item.is_slot_consistent())


func test_mismatched_category_and_slot_is_inconsistent():
	var item := Item.new()
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.ARMOR  # mismatched
	assert_false(item.is_slot_consistent())
