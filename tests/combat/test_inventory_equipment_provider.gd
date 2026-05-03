extends GutTest


var _fighter_race: RaceData
var _fighter_job: JobData
var _mage_job: JobData


func before_each():
	_fighter_race = load("res://data/races/human.tres") as RaceData
	_fighter_job = load("res://data/jobs/fighter.tres") as JobData
	_mage_job = load("res://data/jobs/mage.tres") as JobData


func _make_fighter(str_val: int = 14, vit_val: int = 12, agi_val: int = 9) -> Character:
	var ch := Character.new()
	ch.character_name = "F"
	ch.race = _fighter_race
	ch.job = _fighter_job
	ch.level = 1
	ch.base_stats = {
		&"STR": str_val, &"INT": 8, &"PIE": 8,
		&"VIT": vit_val, &"AGI": agi_val, &"LUC": 8,
	}
	ch.current_hp = 20
	ch.max_hp = 20
	return ch


func _make_item(id: StringName, slot: Item.EquipSlot, atk: int, def_val: int, agi: int, allowed: Array) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	match slot:
		Item.EquipSlot.WEAPON: item.category = Item.ItemCategory.WEAPON
		Item.EquipSlot.ARMOR: item.category = Item.ItemCategory.ARMOR
		Item.EquipSlot.SHIELD: item.category = Item.ItemCategory.SHIELD
		Item.EquipSlot.ACCESSORY: item.category = Item.ItemCategory.ACCESSORY
	item.equip_slot = slot
	item.attack_bonus = atk
	item.defense_bonus = def_val
	item.agility_bonus = agi
	var typed: Array[StringName] = []
	for name in allowed:
		typed.append(StringName(name))
	item.allowed_jobs = typed
	return item


# --- Base-only (no equipment) ---

func test_no_equipment_returns_base_stats_only():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	assert_eq(provider.get_attack(ch), 14 / 2)
	assert_eq(provider.get_defense(ch), 12 / 3)
	assert_eq(provider.get_agility(ch), 9)


# --- Single equipment ---

func test_single_weapon_adds_attack_bonus():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	var sword := _make_item(&"sword", Item.EquipSlot.WEAPON, 6, 0, 0, ["Fighter"])
	var inst := ItemInstance.new(sword, true)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	assert_eq(provider.get_attack(ch), 14 / 2 + 6)


func test_single_armor_adds_defense_bonus():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	var armor := _make_item(&"armor", Item.EquipSlot.ARMOR, 0, 3, 0, ["Fighter"])
	var inst := ItemInstance.new(armor, true)
	ch.equipment.equip(Item.EquipSlot.ARMOR, inst, ch)
	assert_eq(provider.get_defense(ch), 12 / 3 + 3)


func test_accessory_adds_agility_bonus():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	var ring := _make_item(&"ring", Item.EquipSlot.ACCESSORY, 0, 0, 2, ["Fighter"])
	var inst := ItemInstance.new(ring, true)
	ch.equipment.equip(Item.EquipSlot.ACCESSORY, inst, ch)
	assert_eq(provider.get_agility(ch), 9 + 2)


# --- Multiple equipment ---

func test_multiple_defense_items_sum():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	var armor := _make_item(&"armor", Item.EquipSlot.ARMOR, 0, 4, 0, ["Fighter"])
	var shield := _make_item(&"shield", Item.EquipSlot.SHIELD, 0, 2, 0, ["Fighter"])
	ch.equipment.equip(Item.EquipSlot.ARMOR, ItemInstance.new(armor, true), ch)
	ch.equipment.equip(Item.EquipSlot.SHIELD, ItemInstance.new(shield, true), ch)
	assert_eq(provider.get_defense(ch), 12 / 3 + 4 + 2)


# --- Identified vs unidentified ---

func test_identified_and_unidentified_give_same_stats():
	var provider := InventoryEquipmentProvider.new()
	var ch := _make_fighter(14, 12, 9)
	var sword := _make_item(&"sword", Item.EquipSlot.WEAPON, 5, 0, 0, ["Fighter"])

	ch.equipment.equip(Item.EquipSlot.WEAPON, ItemInstance.new(sword, true), ch)
	var atk_identified := provider.get_attack(ch)

	ch.equipment.unequip(Item.EquipSlot.WEAPON)
	ch.equipment.equip(Item.EquipSlot.WEAPON, ItemInstance.new(sword, false), ch)
	var atk_unidentified := provider.get_attack(ch)

	assert_eq(atk_identified, atk_unidentified)


# --- Null / defensive ---

func test_null_character_returns_zero():
	var provider := InventoryEquipmentProvider.new()
	assert_eq(provider.get_attack(null), 0)
	assert_eq(provider.get_defense(null), 0)
	assert_eq(provider.get_agility(null), 0)
