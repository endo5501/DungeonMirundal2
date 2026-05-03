extends GutTest


var _fighter: Character
var _mage: Character
var _repo: ItemRepository
var _inventory: Inventory


func _make_item(id: StringName, slot: Item.EquipSlot, allowed: Array) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	# Map slot to category for consistency
	match slot:
		Item.EquipSlot.WEAPON: item.category = Item.ItemCategory.WEAPON
		Item.EquipSlot.ARMOR: item.category = Item.ItemCategory.ARMOR
		Item.EquipSlot.HELMET: item.category = Item.ItemCategory.HELMET
		Item.EquipSlot.SHIELD: item.category = Item.ItemCategory.SHIELD
		Item.EquipSlot.GAUNTLET: item.category = Item.ItemCategory.GAUNTLET
		Item.EquipSlot.ACCESSORY: item.category = Item.ItemCategory.ACCESSORY
		_: item.category = Item.ItemCategory.OTHER
	item.equip_slot = slot
	var typed: Array[StringName] = []
	for name in allowed:
		typed.append(StringName(name))
	item.allowed_jobs = typed
	return item


func _make_character(job_name: String) -> Character:
	# Minimal Character construction using an in-memory JobData stub.
	# We only need character.job.job_name for Equipment tests.
	var job := JobData.new()
	job.job_name = job_name
	var ch := Character.new()
	ch.character_name = "Test" + job_name
	ch.job = job
	return ch


func before_each():
	_fighter = _make_character("Fighter")
	_mage = _make_character("Mage")
	var sword := _make_item(&"long_sword", Item.EquipSlot.WEAPON, ["Fighter"])
	var staff := _make_item(&"staff", Item.EquipSlot.WEAPON, ["Mage"])
	var armor := _make_item(&"leather_armor", Item.EquipSlot.ARMOR, ["Fighter"])
	var robe := _make_item(&"robe", Item.EquipSlot.ARMOR, ["Mage"])
	var helm := _make_item(&"leather_helmet", Item.EquipSlot.HELMET, ["Fighter", "Mage"])
	var shield := _make_item(&"wooden_shield", Item.EquipSlot.SHIELD, ["Fighter"])
	var gaunt := _make_item(&"leather_gauntlet", Item.EquipSlot.GAUNTLET, ["Fighter"])
	var ring := _make_item(&"ring_of_protection", Item.EquipSlot.ACCESSORY, ["Fighter", "Mage"])
	_repo = ItemRepository.from_array([sword, staff, armor, robe, helm, shield, gaunt, ring])
	_inventory = Inventory.new()
	for item in _repo.all():
		_inventory.add(ItemInstance.new(item, true))


func _inst_by_id(id: StringName) -> ItemInstance:
	for inst in _inventory.list():
		if inst.item.item_id == id:
			return inst
	return null


# --- 3.1: 6 slots, initial null ---

func test_new_equipment_has_all_six_slots_empty():
	var eq := Equipment.new()
	for slot in [
		Item.EquipSlot.WEAPON,
		Item.EquipSlot.ARMOR,
		Item.EquipSlot.HELMET,
		Item.EquipSlot.SHIELD,
		Item.EquipSlot.GAUNTLET,
		Item.EquipSlot.ACCESSORY,
	]:
		assert_null(eq.get_equipped(slot))


func test_all_equipped_on_empty_is_empty():
	var eq := Equipment.new()
	assert_eq(eq.all_equipped().size(), 0)


# --- 3.3: equip rules ---

func test_equip_succeeds_when_slot_and_job_match():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var result := eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	assert_true(result.success)
	assert_null(result.previous)
	assert_eq(eq.get_equipped(Item.EquipSlot.WEAPON), sword)


func test_equip_returns_previous_on_replace():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var another := ItemInstance.new(sword.item, true)
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	var result := eq.equip(Item.EquipSlot.WEAPON, another, _fighter)
	assert_true(result.success)
	assert_eq(result.previous, sword)
	assert_eq(eq.get_equipped(Item.EquipSlot.WEAPON), another)


func test_equip_fails_on_slot_mismatch():
	var eq := Equipment.new()
	var armor := _inst_by_id(&"leather_armor")
	var result := eq.equip(Item.EquipSlot.WEAPON, armor, _fighter)
	assert_false(result.success)
	assert_eq(result.reason, Equipment.FailReason.SLOT_MISMATCH)
	assert_null(eq.get_equipped(Item.EquipSlot.WEAPON))


func test_equip_fails_on_job_not_allowed():
	var eq := Equipment.new()
	var staff := _inst_by_id(&"staff")
	var result := eq.equip(Item.EquipSlot.WEAPON, staff, _fighter)
	assert_false(result.success)
	assert_eq(result.reason, Equipment.FailReason.JOB_NOT_ALLOWED)
	assert_null(eq.get_equipped(Item.EquipSlot.WEAPON))


func test_unequip_returns_previous_and_clears():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	var prev := eq.unequip(Item.EquipSlot.WEAPON)
	assert_eq(prev, sword)
	assert_null(eq.get_equipped(Item.EquipSlot.WEAPON))


func test_unequip_empty_returns_null():
	var eq := Equipment.new()
	assert_null(eq.unequip(Item.EquipSlot.WEAPON))


func test_all_equipped_returns_non_null_slots():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var armor := _inst_by_id(&"leather_armor")
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	eq.equip(Item.EquipSlot.ARMOR, armor, _fighter)
	var all := eq.all_equipped()
	assert_eq(all.size(), 2)
	assert_true(all.has(sword))
	assert_true(all.has(armor))


# --- 3.5: serialization ---

func test_to_dict_uses_inventory_indices():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var armor := _inst_by_id(&"leather_armor")
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	eq.equip(Item.EquipSlot.ARMOR, armor, _fighter)
	var d := eq.to_dict(_inventory)
	assert_eq(d.get("weapon"), _inventory.index_of(sword))
	assert_eq(d.get("armor"), _inventory.index_of(armor))
	assert_eq(d.get("helmet"), null)


func test_from_dict_restores_slot_references():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var armor := _inst_by_id(&"leather_armor")
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	eq.equip(Item.EquipSlot.ARMOR, armor, _fighter)
	var restored := Equipment.from_dict(eq.to_dict(_inventory), _inventory)
	assert_eq(restored.get_equipped(Item.EquipSlot.WEAPON), sword)
	assert_eq(restored.get_equipped(Item.EquipSlot.ARMOR), armor)
	assert_null(restored.get_equipped(Item.EquipSlot.HELMET))


func test_from_dict_missing_key_returns_empty_equipment():
	var eq := Equipment.from_dict({}, _inventory)
	for slot in [
		Item.EquipSlot.WEAPON,
		Item.EquipSlot.ARMOR,
		Item.EquipSlot.HELMET,
		Item.EquipSlot.SHIELD,
		Item.EquipSlot.GAUNTLET,
		Item.EquipSlot.ACCESSORY,
	]:
		assert_null(eq.get_equipped(slot))


func test_equipping_keeps_instance_in_inventory():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	eq.equip(Item.EquipSlot.WEAPON, sword, _fighter)
	assert_true(_inventory.contains(sword))


# --- Task 2.2: equip(NONE, ...) is rejected as SLOT_MISMATCH ---

func test_equip_with_none_slot_returns_slot_mismatch():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var result := eq.equip(Item.EquipSlot.NONE, sword, _fighter)
	assert_false(result.success)
	assert_eq(result.reason, Equipment.FailReason.SLOT_MISMATCH)


# --- Task 2.3: item.equip_slot can be passed directly to equip ---

func test_equip_accepts_item_equip_slot_directly():
	var eq := Equipment.new()
	var sword := _inst_by_id(&"long_sword")
	var result := eq.equip(sword.item.equip_slot, sword, _fighter)
	assert_true(result.success)
	assert_eq(eq.get_equipped(Item.EquipSlot.WEAPON), sword)
