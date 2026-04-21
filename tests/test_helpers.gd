class_name TestHelpers
extends RefCounted


static func make_key_event(keycode: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


# Build a deterministic 8x8 WizMap with the START tile placed at start_pos.
# Used by tests that need a reproducible map without running the full dungeon
# creation pipeline.
static func make_test_map(start_pos: Vector2i = Vector2i(7, 7)) -> WizMap:
	var wm := WizMap.new(8)
	wm.generate(42)
	for y in range(wm.map_size):
		for x in range(wm.map_size):
			if wm.cell(x, y).tile == TileType.START:
				wm.cell(x, y).tile = TileType.FLOOR
	wm.cell(start_pos.x, start_pos.y).tile = TileType.START
	return wm
