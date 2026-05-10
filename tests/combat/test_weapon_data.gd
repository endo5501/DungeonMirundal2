extends GutTest


func test_weapon_data_default_range_is_melee():
	var wd := WeaponData.new()
	assert_eq(wd.weapon_range, WeaponRange.MELEE)


func test_weapon_data_can_be_set_to_ranged():
	var wd := WeaponData.new()
	wd.weapon_range = WeaponRange.RANGED
	assert_eq(wd.weapon_range, WeaponRange.RANGED)


func test_item_default_weapon_data_is_null():
	var item := Item.new()
	assert_null(item.weapon_data)


func test_item_can_carry_weapon_data():
	var item := Item.new()
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	var wd := WeaponData.new()
	wd.weapon_range = WeaponRange.RANGED
	item.weapon_data = wd
	assert_eq(item.weapon_data.weapon_range, WeaponRange.RANGED)


func test_existing_weapon_tres_loads_with_null_weapon_data():
	# Ensures pre-migration WEAPON .tres files (long_sword, mace, etc.) still
	# load and produce a usable Item without weapon_data set.
	var loader := DataLoader.new()
	var repo := loader.load_all_items()
	var sword: Item = repo.find(&"long_sword")
	assert_not_null(sword, "long_sword should be in repository")
	assert_null(sword.weapon_data, "weapon_data should be null pre-migration")
