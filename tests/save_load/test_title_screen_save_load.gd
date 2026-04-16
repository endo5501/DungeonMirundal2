extends GutTest

const MainScript = preload("res://src/main.gd")
const TEST_SAVE_DIR := "user://test_saves_title/"

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
	if dir and dir.dir_exists("test_saves_title"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_title")

func _setup_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

# --- Disabled state based on saves ---

func test_no_saves_disables_continue_and_load():
	var screen := TitleScreen.new()
	screen.setup_save_state(_save_manager)
	add_child_autofree(screen)
	assert_true(screen.is_item_disabled(1), "前回から should be disabled")
	assert_true(screen.is_item_disabled(2), "ロード should be disabled")

func test_with_saves_enables_continue_and_load():
	_setup_character()
	_save_manager.save(1)
	var screen := TitleScreen.new()
	screen.setup_save_state(_save_manager)
	add_child_autofree(screen)
	assert_false(screen.is_item_disabled(1), "前回から should be enabled")
	assert_false(screen.is_item_disabled(2), "ロード should be enabled")

func test_with_saves_but_no_last_slot_disables_continue():
	_setup_character()
	_save_manager.save(1)
	# Remove last_slot.txt but keep save file
	DirAccess.remove_absolute(TEST_SAVE_DIR + "last_slot.txt")
	var screen := TitleScreen.new()
	screen.setup_save_state(_save_manager)
	add_child_autofree(screen)
	assert_true(screen.is_item_disabled(1), "前回から should be disabled")
	assert_false(screen.is_item_disabled(2), "ロード should be enabled")

# --- Main.gd integration ---

func test_main_continue_game_loads_last_save():
	_setup_character()
	GameState.game_location = "town"
	_save_manager.save(1)
	GameState.new_game()
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_continue_game()
	assert_is(main._current_screen, TownScreen)
	assert_eq(GameState.guild.get_all_characters()[0].character_name, "Hero")

func test_main_load_game_shows_load_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_load_from_title()
	assert_is(main._current_screen, LoadScreen)

func test_main_load_back_from_title_returns_to_title():
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_load_from_title()
	main._on_load_title_back()
	assert_is(main._current_screen, TitleScreen)
