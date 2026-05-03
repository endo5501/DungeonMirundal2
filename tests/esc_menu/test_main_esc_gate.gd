extends GutTest

const MainScript = preload("res://src/main.gd")


func before_each():
	GameState.new_game()


func _setup_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)


func test_returns_false_on_title_screen():
	var main := MainScript.new()
	add_child_autofree(main)
	assert_is(main._current_screen, TitleScreen)
	assert_false(main._should_open_esc_menu(),
		"ESC menu should be suppressed on TitleScreen")


func test_returns_false_when_esc_menu_visible():
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	main._esc_menu.show_menu()
	assert_true(main._esc_menu.is_menu_visible())
	assert_false(main._should_open_esc_menu(),
		"ESC menu should not be re-opened while already visible")


func test_returns_false_when_encounter_active():
	_setup_character()
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	main._encounter_coordinator._overlay._is_active = true
	assert_false(main._should_open_esc_menu(),
		"ESC menu should be suppressed during an active encounter")


func test_returns_true_in_town_when_idle():
	var main := MainScript.new()
	add_child_autofree(main)
	main._show_town_screen()
	assert_true(main._should_open_esc_menu(),
		"ESC menu should open when in town and no other gates are active")
