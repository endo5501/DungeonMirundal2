extends GutTest

# Test the return logic (model-level detection, not UI)

func _make_map_with_start_at(start_pos: Vector2i) -> WizMap:
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	# Clear existing START, set new one
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				wiz_map.cell(x, y).tile = TileType.FLOOR
	wiz_map.cell(start_pos.x, start_pos.y).tile = TileType.START
	return wiz_map

func test_player_on_start_tile_detected():
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	assert_eq(wiz_map.cell(ps.position.x, ps.position.y).tile, TileType.START)

func test_player_not_on_start_tile():
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	assert_ne(wiz_map.cell(ps.position.x, ps.position.y).tile, TileType.START)

func test_dungeon_screen_has_return_signal():
	var screen := DungeonScreen.new()
	assert_true(screen.has_signal("return_to_town"))

func test_is_on_start_tile_returns_true():
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	assert_true(screen.is_on_start_tile())

func test_is_on_start_tile_returns_false():
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	screen.setup(wiz_map, ps)
	assert_false(screen.is_on_start_tile())
