class_name DungeonData
extends RefCounted

const SEED_OFFSET_PER_FLOOR := 0x9E3779B1  # Fractional bits of the golden ratio

var dungeon_name: String
var floors: Array[FloorData]
var player_state: PlayerState

static func create(p_name: String, base_seed: int, p_size: int, floor_count: int = 1) -> DungeonData:
	assert(floor_count >= 1, "floor_count must be >= 1, got %d" % floor_count)
	var dd := DungeonData.new()
	dd.dungeon_name = p_name
	dd.floors = []
	for i in range(floor_count):
		var floor_seed := derive_floor_seed(base_seed, i)
		var role := FloorRole.for_index(i, floor_count)
		dd.floors.append(FloorData.create(floor_seed, p_size, role))
	dd.player_state = PlayerState.new(find_start(dd.floors[0].wiz_map), Direction.NORTH)
	dd.player_state.current_floor = 0
	return dd

static func create_with_floor_sizes(p_name: String, base_seed: int, floor_sizes: Array) -> DungeonData:
	assert(floor_sizes.size() >= 1, "floor_sizes must contain at least one entry")
	var dd := DungeonData.new()
	dd.dungeon_name = p_name
	dd.floors = []
	var count := floor_sizes.size()
	for i in range(count):
		var floor_seed := derive_floor_seed(base_seed, i)
		var role := FloorRole.for_index(i, count)
		dd.floors.append(FloorData.create(floor_seed, int(floor_sizes[i]), role))
	dd.player_state = PlayerState.new(find_start(dd.floors[0].wiz_map), Direction.NORTH)
	dd.player_state.current_floor = 0
	return dd

static func derive_floor_seed(base_seed: int, floor_index: int) -> int:
	# Each floor's seed is derived deterministically from the base seed so the
	# whole dungeon can be regenerated from base_seed alone.
	return base_seed + floor_index * SEED_OFFSET_PER_FLOOR

static func find_start(wiz_map: WizMap) -> Vector2i:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				return Vector2i(x, y)
	return Vector2i(0, 0)

static func find_tile(wiz_map: WizMap, tile: int) -> Vector2i:
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == tile:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func current_floor_data() -> FloorData:
	return floors[player_state.current_floor]

func current_wiz_map() -> WizMap:
	return current_floor_data().wiz_map

func current_explored_map() -> ExploredMap:
	return current_floor_data().explored_map

func reset_to_start() -> void:
	var ps := PlayerState.new(find_start(floors[0].wiz_map), Direction.NORTH)
	ps.current_floor = 0
	player_state = ps

func to_dict() -> Dictionary:
	var floor_dicts: Array = []
	for fd in floors:
		floor_dicts.append(fd.to_dict())
	return {
		"dungeon_name": dungeon_name,
		"floors": floor_dicts,
		"player_state": player_state.to_dict(),
	}

static func from_dict(data: Dictionary) -> DungeonData:
	var dd := DungeonData.new()
	dd.dungeon_name = data.get("dungeon_name", "")
	var raw_floors: Array = data.get("floors", [])
	var count := raw_floors.size()
	dd.floors = []
	for i in range(count):
		var role := FloorRole.for_index(i, count)
		dd.floors.append(FloorData.from_dict(raw_floors[i], role))
	dd.player_state = PlayerState.from_dict(data.get("player_state", {"position": [0, 0], "facing": 0, "current_floor": 0}))
	return dd

func get_exploration_rate() -> float:
	var total := 0
	var visited := 0
	for fd in floors:
		total += fd.map_size * fd.map_size
		visited += fd.explored_map.get_visited_count()
	if total == 0:
		return 0.0
	return float(visited) / float(total)
