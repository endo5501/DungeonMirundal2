extends Control

func _ready() -> void:
	var wiz_map := WizMap.new(16)
	wiz_map.generate(42)

	var start_pos := _find_start(wiz_map)
	var player_state := PlayerState.new(start_pos, Direction.NORTH)

	var screen := DungeonScreen.new()
	add_child(screen)
	screen.setup(wiz_map, player_state)

func _find_start(wiz_map: WizMap) -> Vector2i:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				return Vector2i(x, y)
	return Vector2i(0, 0)
