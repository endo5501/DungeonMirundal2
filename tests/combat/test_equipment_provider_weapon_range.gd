extends GutTest


var _loader: DataLoader
var _human: RaceData
var _fighter_job: JobData


func before_each():
	_loader = DataLoader.new()
	for race in _loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in _loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job


func _make_character() -> Character:
	var ch := Character.new()
	ch.character_name = "A"
	ch.race = _human
	ch.job = _fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 30
	ch.current_hp = 30
	return ch


func test_base_provider_returns_melee():
	var p := EquipmentProvider.new()
	assert_eq(p.get_weapon_range(_make_character()), WeaponRange.MELEE)


func test_dummy_provider_returns_melee():
	var p := DummyEquipmentProvider.new()
	assert_eq(p.get_weapon_range(_make_character()), WeaponRange.MELEE)


func test_inventory_provider_returns_melee_when_no_weapon():
	var p := InventoryEquipmentProvider.new()
	var ch := _make_character()
	# Empty equipment
	assert_eq(p.get_weapon_range(ch), WeaponRange.MELEE)


func test_inventory_provider_returns_melee_when_weapon_data_null():
	var p := InventoryEquipmentProvider.new()
	var ch := _make_character()
	var item := Item.new()
	item.item_id = &"plain"
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	item.allowed_jobs = [&"Fighter"]
	# weapon_data deliberately null
	var inst := ItemInstance.new(item, true)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	assert_eq(p.get_weapon_range(ch), WeaponRange.MELEE)


func test_inventory_provider_returns_ranged_with_ranged_weapon_data():
	var p := InventoryEquipmentProvider.new()
	var ch := _make_character()
	var item := Item.new()
	item.item_id = &"bow"
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	item.allowed_jobs = [&"Fighter"]
	var wd := WeaponData.new()
	wd.weapon_range = WeaponRange.RANGED
	item.weapon_data = wd
	var inst := ItemInstance.new(item, true)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	assert_eq(p.get_weapon_range(ch), WeaponRange.RANGED)


func test_inventory_provider_returns_melee_with_explicit_melee_weapon_data():
	var p := InventoryEquipmentProvider.new()
	var ch := _make_character()
	var item := Item.new()
	item.item_id = &"sword"
	item.category = Item.ItemCategory.WEAPON
	item.equip_slot = Item.EquipSlot.WEAPON
	item.allowed_jobs = [&"Fighter"]
	var wd := WeaponData.new()
	wd.weapon_range = WeaponRange.MELEE
	item.weapon_data = wd
	var inst := ItemInstance.new(item, true)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	assert_eq(p.get_weapon_range(ch), WeaponRange.MELEE)


func test_inventory_provider_returns_melee_for_null_character():
	var p := InventoryEquipmentProvider.new()
	assert_eq(p.get_weapon_range(null), WeaponRange.MELEE)
