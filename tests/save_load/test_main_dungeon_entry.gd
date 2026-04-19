extends GutTest

const MainScript = preload("res://src/main.gd")
const TEST_SAVE_DIR := "user://test_saves_main_dungeon_entry/"

var _save_manager: SaveManager

func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	GameState.new_game()
	GameState.save_manager = _save_manager
	_setup_character()

func after_each():
	_clean_test_dir()

func _clean_test_dir():
	var dir := DirAccess.open("user://")
	if dir and dir.dir_exists("test_saves_main_dungeon_entry"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_main_dungeon_entry")

func _setup_character():
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	var ch := Character.create("Hero", race, job, allocation)
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

func _find_non_start_floor(dd: DungeonData) -> Vector2i:
	for y in range(dd.wiz_map.map_size):
		for x in range(dd.wiz_map.map_size):
			if dd.wiz_map.cell(x, y).tile != TileType.START:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_on_enter_dungeon_resets_player_state_to_start_tile():
	var dd := GameState.dungeon_registry.create("ResetTest", 0)
	var non_start := _find_non_start_floor(dd)
	dd.player_state.position = non_start
	dd.player_state.facing = Direction.SOUTH
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_enter_dungeon(0)
	var start_pos := DungeonData.find_start(dd.wiz_map)
	assert_eq(dd.player_state.position, start_pos,
		"player position should be reset to START tile")
	assert_eq(dd.player_state.facing, Direction.NORTH,
		"player facing should be reset to NORTH")

func test_on_enter_dungeon_preserves_exploration_data():
	# Pick two cells far from START so they won't be marked by the initial
	# dungeon-screen view when we enter.
	var dd := GameState.dungeon_registry.create("ExplorationTest", 0)
	var far_a := Vector2i(dd.wiz_map.map_size - 1, dd.wiz_map.map_size - 1)
	var far_b := Vector2i(dd.wiz_map.map_size - 2, dd.wiz_map.map_size - 1)
	dd.explored_map.mark_visited(far_a)
	dd.explored_map.mark_visited(far_b)
	var main := MainScript.new()
	add_child_autofree(main)
	main._on_enter_dungeon(0)
	assert_true(dd.explored_map.is_visited(far_a),
		"previously visited cell should remain visited after re-entry")
	assert_true(dd.explored_map.is_visited(far_b),
		"previously visited cell should remain visited after re-entry")

func test_load_path_does_not_reset_player_state():
	var dd := GameState.dungeon_registry.create("LoadTest", 0)
	var non_start := _find_non_start_floor(dd)
	dd.player_state.position = non_start
	dd.player_state.facing = Direction.EAST
	GameState.game_location = GameState.LOCATION_DUNGEON
	GameState.current_dungeon_index = 0
	_save_manager.save(1)
	GameState.new_game()
	GameState.save_manager = _save_manager
	_setup_character()
	var main := MainScript.new()
	add_child_autofree(main)
	main._load_game(1)
	var restored_dd := GameState.dungeon_registry.get_dungeon(0)
	assert_eq(restored_dd.player_state.position, non_start,
		"load path should preserve saved position (no reset)")
	assert_eq(restored_dd.player_state.facing, Direction.EAST,
		"load path should preserve saved facing (no reset)")
