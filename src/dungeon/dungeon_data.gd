class_name DungeonData
extends RefCounted

var dungeon_name: String
var seed_value: int
var map_size: int
var wiz_map: WizMap
var explored_map: ExploredMap
var player_state: PlayerState

static func create(p_name: String, p_seed: int, p_size: int) -> DungeonData:
	var dd := DungeonData.new()
	dd.dungeon_name = p_name
	dd.seed_value = p_seed
	dd.map_size = p_size
	dd.wiz_map = WizMap.new(p_size)
	dd.wiz_map.generate(p_seed)
	dd.explored_map = ExploredMap.new()
	dd.player_state = PlayerState.new(_find_start(dd.wiz_map), Direction.NORTH)
	return dd

static func _find_start(wiz_map: WizMap) -> Vector2i:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				return Vector2i(x, y)
	return Vector2i(0, 0)

func get_exploration_rate() -> float:
	var total := map_size * map_size
	if total == 0:
		return 0.0
	return float(explored_map.get_visited_cells().size()) / float(total)
