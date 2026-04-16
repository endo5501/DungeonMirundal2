extends GutTest

func test_game_state_has_game_location():
	GameState.new_game()
	assert_eq(GameState.game_location, "town")

func test_game_state_has_current_dungeon_index():
	GameState.new_game()
	assert_eq(GameState.current_dungeon_index, -1)

func test_new_game_resets_game_location():
	GameState.new_game()
	GameState.game_location = "dungeon"
	GameState.new_game()
	assert_eq(GameState.game_location, "town")

func test_new_game_resets_current_dungeon_index():
	GameState.new_game()
	GameState.current_dungeon_index = 2
	GameState.new_game()
	assert_eq(GameState.current_dungeon_index, -1)
