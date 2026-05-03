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


func _expected_slot_for_category(category: int) -> int:
	match category:
		Item.ItemCategory.WEAPON: return Item.EquipSlot.WEAPON
		Item.ItemCategory.ARMOR: return Item.EquipSlot.ARMOR
		Item.ItemCategory.HELMET: return Item.EquipSlot.HELMET
		Item.ItemCategory.SHIELD: return Item.EquipSlot.SHIELD
		Item.ItemCategory.GAUNTLET: return Item.EquipSlot.GAUNTLET
		Item.ItemCategory.ACCESSORY: return Item.EquipSlot.ACCESSORY
		Item.ItemCategory.CONSUMABLE: return Item.EquipSlot.NONE
		Item.ItemCategory.OTHER: return Item.EquipSlot.NONE
	return -1


func test_all_shipped_items_have_consistent_category_and_equip_slot():
	var repo := DataLoader.new().load_all_items()
	var items := repo.all()
	assert_gt(items.size(), 0, "expected at least one .tres item to be loaded")
	for item in items:
		var expected: int = _expected_slot_for_category(item.category)
		assert_ne(expected, -1,
			"item %s has unrecognized category %d" % [item.item_id, item.category])
		assert_eq(item.equip_slot, expected,
			"item %s: category=%d expects equip_slot=%d but got %d"
				% [item.item_id, item.category, expected, item.equip_slot])
