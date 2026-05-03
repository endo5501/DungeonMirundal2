extends GutTest

const TEST_SAVE_DIR := "user://test_saves/"

var _save_manager: SaveManager

func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	GameState.new_game()

func after_each():
	_clean_test_dir()

func _clean_test_dir():
	var dir := DirAccess.open("user://")
	if dir and dir.dir_exists("test_saves"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves")

func _setup_game_with_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

# --- save() tests ---

func test_save_returns_true_on_success():
	_setup_game_with_character()
	var ok: bool = _save_manager.save(1)
	assert_true(ok)

func test_save_creates_file():
	_setup_game_with_character()
	_save_manager.save(1)
	assert_true(FileAccess.file_exists(TEST_SAVE_DIR + "save_001.json"))

func test_save_creates_directory_if_missing():
	_clean_test_dir()
	_save_manager.save(1)
	assert_true(DirAccess.dir_exists_absolute(TEST_SAVE_DIR))

func test_save_updates_last_slot():
	_save_manager.save(3)
	assert_true(FileAccess.file_exists(TEST_SAVE_DIR + "last_slot.txt"))
	var f := FileAccess.open(TEST_SAVE_DIR + "last_slot.txt", FileAccess.READ)
	assert_eq(f.get_as_text().strip_edges(), "3")

func test_save_includes_version():
	_setup_game_with_character()
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_eq(data["version"], 1)

func test_save_includes_game_location():
	GameState.game_location = "dungeon"
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_eq(data["game_location"], "dungeon")

func test_save_includes_current_dungeon_index():
	GameState.current_dungeon_index = 2
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_eq(data["current_dungeon_index"], 2)

func test_save_includes_last_saved():
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_true(data.has("last_saved"))
	assert_true(data["last_saved"] is String)

func test_save_includes_guild():
	_setup_game_with_character()
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_true(data.has("guild"))
	assert_eq(data["guild"]["characters"].size(), 1)

func test_save_includes_dungeons():
	GameState.dungeon_registry.create("テストダンジョン", DungeonRegistry.SIZE_SMALL)
	_save_manager.save(1)
	var data := _read_save_json(1)
	assert_true(data.has("dungeons"))
	assert_eq(data["dungeons"].size(), 1)

# --- load() tests ---

func test_load_result_enum_has_expected_values():
	# Ensure the public enum surface is stable for callers.
	assert_eq(SaveManager.LoadResult.OK, 0)
	assert_true(SaveManager.LoadResult.has("FILE_NOT_FOUND"))
	assert_true(SaveManager.LoadResult.has("PARSE_ERROR"))
	assert_true(SaveManager.LoadResult.has("VERSION_TOO_NEW"))
	assert_true(SaveManager.LoadResult.has("RESTORE_FAILED"))

func test_load_restores_guild():
	_setup_game_with_character()
	_save_manager.save(1)
	GameState.new_game()
	assert_eq(GameState.guild.get_all_characters().size(), 0)
	var result: int = _save_manager.load(1)
	assert_eq(result, SaveManager.LoadResult.OK)
	assert_eq(GameState.guild.get_all_characters().size(), 1)
	assert_eq(GameState.guild.get_all_characters()[0].character_name, "Hero")

func test_load_restores_game_location():
	GameState.game_location = "dungeon"
	_save_manager.save(1)
	GameState.new_game()
	_save_manager.load(1)
	assert_eq(GameState.game_location, "dungeon")

func test_load_restores_current_dungeon_index():
	GameState.current_dungeon_index = 2
	_save_manager.save(1)
	GameState.new_game()
	_save_manager.load(1)
	assert_eq(GameState.current_dungeon_index, 2)

func test_load_restores_dungeon_registry():
	GameState.dungeon_registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	_save_manager.save(1)
	GameState.new_game()
	_save_manager.load(1)
	assert_eq(GameState.dungeon_registry.size(), 1)
	assert_eq(GameState.dungeon_registry.get_dungeon(0).dungeon_name, "迷宮")

func test_load_nonexistent_returns_file_not_found():
	var result: int = _save_manager.load(999)
	assert_eq(result, SaveManager.LoadResult.FILE_NOT_FOUND)

func test_load_returns_parse_error_on_corrupt_json():
	_save_manager._ensure_dir()
	var path := TEST_SAVE_DIR + "save_001.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not valid json")
	f.close()
	var result: int = _save_manager.load(1)
	assert_eq(result, SaveManager.LoadResult.PARSE_ERROR)

func test_load_returns_version_too_new_when_version_exceeds_current():
	_save_manager._ensure_dir()
	var path := TEST_SAVE_DIR + "save_001.json"
	var data := {
		"version": SaveManager.CURRENT_VERSION + 1,
		"last_saved": "future",
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var result: int = _save_manager.load(1)
	assert_eq(result, SaveManager.LoadResult.VERSION_TOO_NEW)

# --- list_saves() tests ---

func test_list_saves_empty():
	var saves := _save_manager.list_saves()
	assert_eq(saves.size(), 0)

func test_list_saves_returns_metadata():
	_setup_game_with_character()
	GameState.game_location = "town"
	_save_manager.save(1)
	var saves := _save_manager.list_saves()
	assert_eq(saves.size(), 1)
	assert_eq(saves[0]["slot_number"], 1)
	assert_true(saves[0].has("last_saved"))
	assert_eq(saves[0]["game_location"], "town")
	assert_true(saves[0].has("party_name"))
	assert_true(saves[0].has("max_level"))

func test_list_saves_metadata_party_info():
	_setup_game_with_character()
	GameState.guild.party_name = "勇者の一行"
	_save_manager.save(1)
	var saves := _save_manager.list_saves()
	assert_eq(saves[0]["party_name"], "勇者の一行")
	assert_eq(saves[0]["max_level"], 1)

func test_list_saves_metadata_dungeon_info():
	_setup_game_with_character()
	GameState.dungeon_registry.create("暗黒の迷宮", DungeonRegistry.SIZE_SMALL)
	GameState.game_location = "dungeon"
	GameState.current_dungeon_index = 0
	_save_manager.save(1)
	var saves := _save_manager.list_saves()
	assert_eq(saves[0]["dungeon_name"], "暗黒の迷宮")

func test_list_saves_sorted_newest_first():
	_save_manager.save(1)
	_save_manager.save(2)
	var saves := _save_manager.list_saves()
	assert_eq(saves.size(), 2)
	# slot 2 should be newer, so first
	assert_eq(saves[0]["slot_number"], 2)
	assert_eq(saves[1]["slot_number"], 1)

# --- get_last_slot() tests ---

func test_get_last_slot_no_file():
	assert_eq(_save_manager.get_last_slot(), -1)

func test_get_last_slot_after_save():
	_save_manager.save(3)
	assert_eq(_save_manager.get_last_slot(), 3)

func test_get_last_slot_file_deleted():
	_save_manager.save(5)
	# Delete the save file but keep last_slot.txt
	DirAccess.remove_absolute(TEST_SAVE_DIR + "save_005.json")
	assert_eq(_save_manager.get_last_slot(), -1)

# --- get_next_slot_number() tests ---

func test_get_next_slot_number_empty():
	assert_eq(_save_manager.get_next_slot_number(), 1)

func test_get_next_slot_number_after_saves():
	_save_manager.save(1)
	_save_manager.save(2)
	assert_eq(_save_manager.get_next_slot_number(), 3)

# --- has_saves() tests ---

func test_has_saves_false():
	assert_false(_save_manager.has_saves())

func test_has_saves_true():
	_save_manager.save(1)
	assert_true(_save_manager.has_saves())

# --- delete_save() tests ---

func test_delete_save():
	_save_manager.save(2)
	assert_true(FileAccess.file_exists(TEST_SAVE_DIR + "save_002.json"))
	_save_manager.delete_save(2)
	assert_false(FileAccess.file_exists(TEST_SAVE_DIR + "save_002.json"))

# --- Helper ---

func _read_save_json(slot: int) -> Dictionary:
	var path := TEST_SAVE_DIR + "save_%03d.json" % slot
	var f := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	return json.data
