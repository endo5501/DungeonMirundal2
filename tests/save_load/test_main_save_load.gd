extends GutTest

const MainScript = preload("res://src/main.gd")
const TEST_SAVE_DIR := "user://test_saves_main/"

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
	if dir and dir.dir_exists("test_saves_main"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_main")

func _setup_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

func test_main_connects_esc_menu_save():
	var main := MainScript.new()
	add_child_autofree(main)
	assert_true(main._esc_menu.save_requested.get_connections().size() > 0)

func test_main_connects_esc_menu_load():
	var main := MainScript.new()
	add_child_autofree(main)
	assert_true(main._esc_menu.load_requested.get_connections().size() > 0)

func test_main_save_requested_shows_save_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	main._on_save_requested()
	assert_is(main._current_screen, SaveScreen)

func test_main_load_requested_shows_load_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	main._on_load_requested()
	assert_is(main._current_screen, LoadScreen)

func test_main_load_from_load_screen_restores_town():
	_setup_character()
	GameState.game_location = "town"
	_save_manager.save(1)
	GameState.new_game()
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	main._on_load_slot_selected(1)
	assert_is(main._current_screen, TownScreen)
	assert_eq(GameState.guild.get_all_characters()[0].character_name, "Hero")

func test_main_load_failure_keeps_load_screen_with_error_label():
	# Trigger a failure by selecting a non-existent slot. main should leave
	# LoadScreen visible and surface the failure on the screen's status label.
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_load_requested()
	assert_is(main._current_screen, LoadScreen)
	main._on_load_slot_selected(999)
	assert_is(main._current_screen, LoadScreen, "LoadScreen should stay open after failure")
	var screen: LoadScreen = main._current_screen
	assert_eq(screen.get_status_text(), "セーブファイルが見つかりません")
	assert_push_error("file not found")
