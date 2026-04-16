extends GutTest

const MainScript = preload("res://src/main.gd")
const TEST_SAVE_DIR := "user://test_saves/"

var _save_manager: SaveManager

func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	GameState.new_game()
	GameState.save_manager = _save_manager

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

func _setup_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

func test_load_game_town_shows_town_screen():
	_setup_character()
	GameState.game_location = "town"
	_save_manager.save(1)
	GameState.new_game()
	var main := MainScript.new()
	add_child_autofree(main)
	main._load_game(1)
	assert_is(main._current_screen, TownScreen)

func test_load_game_dungeon_shows_dungeon_screen():
	_setup_character()
	GameState.dungeon_registry.create("テストダンジョン", DungeonRegistry.SIZE_SMALL)
	GameState.game_location = "dungeon"
	GameState.current_dungeon_index = 0
	_save_manager.save(1)
	GameState.new_game()
	var main := MainScript.new()
	add_child_autofree(main)
	main._load_game(1)
	assert_is(main._current_screen, DungeonScreen)

func test_load_game_restores_guild():
	_setup_character()
	_save_manager.save(1)
	GameState.new_game()
	var main := MainScript.new()
	add_child_autofree(main)
	main._load_game(1)
	assert_eq(GameState.guild.get_all_characters().size(), 1)
	assert_eq(GameState.guild.get_all_characters()[0].character_name, "Hero")
