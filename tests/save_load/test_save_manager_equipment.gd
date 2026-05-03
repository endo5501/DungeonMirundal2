extends GutTest

const TEST_SAVE_DIR := "user://test_saves_eq/"

var _save_manager: SaveManager


func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	if GameState.item_repository == null:
		GameState.item_repository = DataLoader.new().load_all_items()
	GameState.new_game()


func after_each():
	_clean_test_dir()


func _clean_test_dir():
	var root := DirAccess.open("user://")
	if root and root.dir_exists("test_saves_eq"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var f := saves_dir.get_next()
			while f != "":
				saves_dir.remove(f)
				f = saves_dir.get_next()
			saves_dir.list_dir_end()
		root.remove("test_saves_eq")


func _register_fighter_with_loadout() -> Character:
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	InitialEquipment.grant(ch, GameState.inventory, GameState.item_repository)
	return ch


func _read_json(slot: int) -> Dictionary:
	var f := FileAccess.open(TEST_SAVE_DIR + "save_%03d.json" % slot, FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()
	return json.data


# --- Equipment save/load ---

func test_save_writes_equipment_slot_indices():
	var _hero := _register_fighter_with_loadout()
	_save_manager.save(1)
	var d := _read_json(1)
	var chars: Array = d["guild"]["characters"]
	assert_eq(chars.size(), 1)
	var equipment: Dictionary = chars[0]["equipment"]
	# Slot "weapon" and "armor" should be integer indices pointing into inventory.items
	assert_typeof(equipment["weapon"], TYPE_FLOAT)  # JSON int decodes to float in Godot
	assert_typeof(equipment["armor"], TYPE_FLOAT)
	assert_eq(equipment["helmet"], null)


func test_load_restores_equipment_references_to_inventory_instances():
	var hero := _register_fighter_with_loadout()
	# Snapshot equipped item ids
	var weapon_id := hero.equipment.get_equipped(Item.EquipSlot.WEAPON).item.item_id
	var armor_id := hero.equipment.get_equipped(Item.EquipSlot.ARMOR).item.item_id
	_save_manager.save(1)
	GameState.new_game()
	_save_manager.load(1)
	var restored_ch: Character = GameState.guild.get_all_characters()[0]
	var restored_weapon := restored_ch.equipment.get_equipped(Item.EquipSlot.WEAPON)
	var restored_armor := restored_ch.equipment.get_equipped(Item.EquipSlot.ARMOR)
	assert_not_null(restored_weapon)
	assert_not_null(restored_armor)
	assert_eq(restored_weapon.item.item_id, weapon_id)
	assert_eq(restored_armor.item.item_id, armor_id)
	# The equipped instance SHOULD be the same object reference as in the inventory
	assert_true(GameState.inventory.contains(restored_weapon))
	assert_true(GameState.inventory.contains(restored_armor))


func test_load_legacy_save_without_equipment_key_yields_empty_slots():
	# Save a character and strip its equipment dict manually
	_register_fighter_with_loadout()
	_save_manager.save(1)
	# Mutate save file on disk to remove "equipment" from the character
	var d := _read_json(1)
	var chars: Array = d["guild"]["characters"]
	for ch in chars:
		ch.erase("equipment")
	d["inventory"] = {"gold": 0, "items": []}  # no items to resolve
	var f := FileAccess.open(TEST_SAVE_DIR + "save_001.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	GameState.new_game()
	assert_eq(_save_manager.load(1), SaveManager.LoadResult.OK)
	var ch: Character = GameState.guild.get_all_characters()[0]
	assert_eq(ch.equipment.all_equipped().size(), 0)
