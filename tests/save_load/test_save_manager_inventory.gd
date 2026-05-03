extends GutTest

const TEST_SAVE_DIR := "user://test_saves_inv/"

var _save_manager: SaveManager


func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	# Ensure item_repository is populated in the autoload for load() to use
	if GameState.item_repository == null:
		GameState.item_repository = DataLoader.new().load_all_items()
	GameState.new_game()


func after_each():
	_clean_test_dir()


func _clean_test_dir():
	var root := DirAccess.open("user://")
	if root and root.dir_exists("test_saves_inv"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var f := saves_dir.get_next()
			while f != "":
				saves_dir.remove(f)
				f = saves_dir.get_next()
			saves_dir.list_dir_end()
		root.remove("test_saves_inv")


func _read_json(slot: int) -> Dictionary:
	var f := FileAccess.open(TEST_SAVE_DIR + "save_%03d.json" % slot, FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()
	return json.data


# --- Inventory save/load ---

func test_save_writes_inventory_gold():
	GameState.inventory.gold = 750
	_save_manager.save(1)
	var d := _read_json(1)
	assert_eq(int(d["inventory"]["gold"]), 750)


func test_save_writes_items_in_order():
	var repo := GameState.item_repository
	var a := repo.find(&"long_sword")
	var b := repo.find(&"leather_armor")
	var c := repo.find(&"robe")
	GameState.inventory.add(ItemInstance.new(a, true))
	GameState.inventory.add(ItemInstance.new(b, true))
	GameState.inventory.add(ItemInstance.new(c, true))
	_save_manager.save(1)
	var d := _read_json(1)
	var items: Array = d["inventory"]["items"]
	assert_eq(items.size(), 3)
	assert_eq(String(items[0]["item_id"]), "long_sword")
	assert_eq(String(items[1]["item_id"]), "leather_armor")
	assert_eq(String(items[2]["item_id"]), "robe")


func test_load_restores_inventory_gold():
	GameState.inventory.gold = 750
	_save_manager.save(1)
	GameState.new_game()  # wipe state
	assert_eq(_save_manager.load(1), SaveManager.LoadResult.OK)
	assert_eq(GameState.inventory.gold, 750)


func test_load_restores_inventory_items_in_order():
	var repo := GameState.item_repository
	GameState.inventory.add(ItemInstance.new(repo.find(&"long_sword"), true))
	GameState.inventory.add(ItemInstance.new(repo.find(&"leather_armor"), true))
	GameState.inventory.add(ItemInstance.new(repo.find(&"robe"), true))
	_save_manager.save(1)
	GameState.new_game()
	_save_manager.load(1)
	var listed := GameState.inventory.list()
	assert_eq(listed.size(), 3)
	assert_eq(listed[0].item.item_id, &"long_sword")
	assert_eq(listed[1].item.item_id, &"leather_armor")
	assert_eq(listed[2].item.item_id, &"robe")


func test_load_legacy_save_without_inventory_key_defaults_empty():
	# Write a save file manually that lacks the "inventory" key
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var legacy := {
		"version": 1,
		"last_saved": "",
		"game_location": "town",
		"current_dungeon_index": -1,
		"guild": {"characters": [], "front_row": [null, null, null], "back_row": [null, null, null], "party_name": ""},
		"dungeons": [],
	}
	var f := FileAccess.open(TEST_SAVE_DIR + "save_001.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy, "\t"))
	f.close()
	assert_eq(_save_manager.load(1), SaveManager.LoadResult.OK)
	assert_eq(GameState.inventory.gold, 0)
	assert_eq(GameState.inventory.list().size(), 0)
