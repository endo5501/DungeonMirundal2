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


# Build an 8x8 WizMap with START at `start` and a corridor opened in `dir`
# direction for `length` cells. All other edges remain WALL, so callers can
# rely on (start + dir * k) being walkable for k in [1, length] and any other
# direction being blocked.
static func make_corridor_fixture(start: Vector2i, dir: int, length: int = 3) -> WizMap:
	# Stub: not yet implemented.
	return WizMap.new(8)


# Build an 8x8 WizMap with START at `start` and every edge around `start`
# explicitly walled, so move_forward fails in every direction from `start`.
static func make_blocked_fixture(start: Vector2i) -> WizMap:
	# Stub: not yet implemented.
	return WizMap.new(8)


# Build an 8x8 WizMap so that, from the cell adjacent to `start` opposite
# `dir`, walking forward in `dir` lands on the START tile.
# Example: start=(4,4), dir=NORTH → cell (4,5) opens NORTH onto (4,4).
static func make_neighbor_to_start_fixture(start: Vector2i, dir: int) -> WizMap:
	# Stub: not yet implemented.
	return WizMap.new(8)
