extends GutTest

# DungeonScreen ESC key behavior:
# - Dialog showing: ConfirmDialog handles the cancel internally (dialog closes,
#   cancelled signal fires). DungeonScreen's _unhandled_input early-returns
#   without consuming the event since ConfirmDialog owns input while visible.
# - No dialog: ESC is NOT consumed (propagates to main.gd for ESC menu)

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _make_map_with_start_at(start_pos: Vector2i) -> WizMap:
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				wiz_map.cell(x, y).tile = TileType.FLOOR
	wiz_map.cell(start_pos.x, start_pos.y).tile = TileType.START
	return wiz_map

func test_esc_not_consumed_when_no_dialog():
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	screen.setup(wiz_map, ps)
	assert_false(screen.is_showing_return_dialog())
	# ESC when no dialog must not raise the dialog
	var event := _make_key_event(KEY_ESCAPE)
	screen._unhandled_input(event)
	assert_false(screen.is_showing_return_dialog())

func test_esc_closes_return_dialog():
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	# Trigger the dialog via the public path
	screen.check_start_tile_return()
	assert_true(screen.is_showing_return_dialog())
	# ConfirmDialog owns its input handling
	var event := _make_key_event(KEY_ESCAPE)
	screen._return_dialog._unhandled_input(event)
	assert_false(screen.is_showing_return_dialog())
