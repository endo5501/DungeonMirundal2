extends GutTest

# DungeonScreen ESC key behavior: ESC should only close return dialog,
# not consume ESC when no dialog is showing (so it propagates to main.gd)

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
	# ESC when no dialog should NOT be consumed by DungeonScreen
	# (i.e., _showing_return_dialog is false, ESC match is removed)
	assert_false(screen._showing_return_dialog)
	# The ESC key should not trigger any dialog
	# We verify by checking the dialog is still not showing after ESC
	var event := _make_key_event(KEY_ESCAPE)
	screen._unhandled_input(event)
	assert_false(screen._showing_return_dialog)

func test_esc_closes_return_dialog():
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map_with_start_at(Vector2i(3, 3))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	# Dialog should have been shown by moving onto start tile
	# But setup doesn't trigger it, so we manually show it
	screen._show_return_dialog()
	assert_true(screen._showing_return_dialog)
	# ESC should close the dialog
	var event := _make_key_event(KEY_ESCAPE)
	screen._unhandled_input(event)
	assert_false(screen._showing_return_dialog)
