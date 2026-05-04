extends GutTest

# Tests for STAIRS_DOWN / STAIRS_UP dialog and floor transitions.

func _make_two_floor_dungeon_with_stair_at(stair_pos: Vector2i, stair_type: int) -> DungeonData:
	var dd := DungeonData.create("階段テスト", 42, 8, 2)
	# Force a known stair location on floor 0 by clearing existing stairs and
	# placing a new one at stair_pos with neighbors walkable.
	for floor_index in range(dd.floors.size()):
		var wm := dd.floors[floor_index].wiz_map
		for y in range(wm.map_size):
			for x in range(wm.map_size):
				if wm.cell(x, y).tile == TileType.STAIRS_DOWN or wm.cell(x, y).tile == TileType.STAIRS_UP:
					wm.cell(x, y).tile = TileType.FLOOR
	# Floor 0: keep original START, set our test STAIRS_DOWN
	# Floor 1: set our test STAIRS_UP and a STAIRS_DOWN was originally absent (last role) -> keep GOAL? Actually 2-floor: floor[0]=FIRST, floor[1]=LAST so no STAIRS_DOWN on floor[1]
	if stair_type == TileType.STAIRS_DOWN:
		dd.floors[0].wiz_map.cell(stair_pos.x, stair_pos.y).tile = TileType.STAIRS_DOWN
		# Place STAIRS_UP on floor 1
		dd.floors[1].wiz_map.cell(2, 2).tile = TileType.STAIRS_UP
	else:
		# stair_type == STAIRS_UP — caller wants player to start on floor 1
		dd.floors[1].wiz_map.cell(stair_pos.x, stair_pos.y).tile = TileType.STAIRS_UP
		# Place STAIRS_DOWN on floor 0
		dd.floors[0].wiz_map.cell(2, 2).tile = TileType.STAIRS_DOWN
	return dd

# --- Dialog appears on stair tile ---

func test_descend_dialog_shown_when_player_steps_on_stairs_down():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	assert_true(screen.is_showing_return_dialog())
	assert_eq(screen.get_pending_dialog_message(), "下の階に降りますか?")

func test_ascend_dialog_shown_when_player_steps_on_stairs_up():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(5, 5), TileType.STAIRS_UP)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(5, 5)
	dd.player_state.current_floor = 1
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	assert_true(screen.is_showing_return_dialog())
	assert_eq(screen.get_pending_dialog_message(), "上の階に戻りますか?")

# --- Confirming descend transitions to next floor ---

func test_confirm_descend_increments_current_floor():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	dd.player_state.facing = Direction.EAST
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	assert_eq(dd.player_state.current_floor, 1)

func test_confirm_descend_places_player_on_next_floor_stairs_up():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	var new_wm := dd.floors[1].wiz_map
	var pos := dd.player_state.position
	assert_eq(new_wm.cell(pos.x, pos.y).tile, TileType.STAIRS_UP,
		"player must land on STAIRS_UP of next floor")

func test_confirm_descend_preserves_facing():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	dd.player_state.facing = Direction.EAST
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	assert_eq(dd.player_state.facing, Direction.EAST)

# --- Confirming ascend transitions to previous floor ---

func test_confirm_ascend_decrements_current_floor():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(5, 5), TileType.STAIRS_UP)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(5, 5)
	dd.player_state.current_floor = 1
	dd.player_state.facing = Direction.SOUTH
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	assert_eq(dd.player_state.current_floor, 0)

func test_confirm_ascend_places_player_on_prev_floor_stairs_down():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(5, 5), TileType.STAIRS_UP)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(5, 5)
	dd.player_state.current_floor = 1
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	var prev_wm := dd.floors[0].wiz_map
	var pos := dd.player_state.position
	assert_eq(prev_wm.cell(pos.x, pos.y).tile, TileType.STAIRS_DOWN,
		"player must land on STAIRS_DOWN of previous floor")

func test_confirm_ascend_preserves_facing():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(5, 5), TileType.STAIRS_UP)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(5, 5)
	dd.player_state.current_floor = 1
	dd.player_state.facing = Direction.SOUTH
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.confirm_pending_dialog()
	assert_eq(dd.player_state.facing, Direction.SOUTH)

# --- Encounter has priority over stair dialog ---

func test_stair_dialog_suppressed_when_encounter_active():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.set_encounter_active(true)
	screen.check_stair_or_start_tile()
	assert_false(screen.is_showing_return_dialog(),
		"stair dialog must be suppressed while encounter is active")

func test_stair_dialog_appears_after_encounter_resolves():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	# Simulate encounter active during step, then resolved
	screen.set_encounter_active(true)
	screen.check_stair_or_start_tile()
	assert_false(screen.is_showing_return_dialog())
	screen.set_encounter_active(false)
	screen.check_stair_or_start_tile()
	assert_true(screen.is_showing_return_dialog(),
		"stair dialog must appear after encounter resolves if still on stair")

# --- step_taken NOT emitted on floor transition ---

func test_floor_transition_does_not_emit_step_taken():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	watch_signals(screen)
	screen.confirm_pending_dialog()
	assert_signal_not_emitted(screen, "step_taken",
		"step_taken must NOT be emitted on stair-based floor transition")

# --- floor_changed signal ---

func test_floor_changed_emitted_on_descend():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	watch_signals(screen)
	screen.confirm_pending_dialog()
	assert_signal_emitted_with_parameters(screen, "floor_changed", [1])

func test_floor_changed_emitted_on_ascend():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(5, 5), TileType.STAIRS_UP)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(5, 5)
	dd.player_state.current_floor = 1
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	watch_signals(screen)
	screen.confirm_pending_dialog()
	assert_signal_emitted_with_parameters(screen, "floor_changed", [0])

# --- Cancel ---

func test_cancel_descend_keeps_current_floor():
	var dd := _make_two_floor_dungeon_with_stair_at(Vector2i(4, 4), TileType.STAIRS_DOWN)
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	dd.player_state.position = Vector2i(4, 4)
	dd.player_state.current_floor = 0
	screen.setup_from_data(dd)
	screen.check_stair_or_start_tile()
	screen.cancel_pending_dialog()
	assert_eq(dd.player_state.current_floor, 0)
	assert_eq(dd.player_state.position, Vector2i(4, 4))
