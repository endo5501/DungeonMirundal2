class_name TestHelpers
extends RefCounted


# Lightweight Character with no race/job/stats — sufficient for HUD and
# party-binding tests that only care about the fields the panel reads.
static func make_test_character(
	p_name: String,
	hp: int = 10,
	statuses: Array[StringName] = [],
) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.max_hp = 10
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	ch.persistent_statuses = statuses
	return ch


static func get_party_hud() -> Node:
	return Engine.get_main_loop().root.get_node("/root/PartyHud")


static func make_key_event(keycode: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


static func make_action_event(action: StringName, pressed: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
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
	var wm := WizMap.new(8)
	var pos := start
	for _i in range(length):
		var next := pos + Direction.offset(dir)
		if not wm.in_bounds(next.x, next.y):
			break
		wm.set_edge(pos.x, pos.y, dir, EdgeType.OPEN)
		pos = next
	wm.cell(start.x, start.y).tile = TileType.START
	return wm


# Build an 8x8 WizMap with START at `start`. WizMap.new() initialises every
# edge to WALL, so move_forward already fails in every direction.
static func make_blocked_fixture(start: Vector2i) -> WizMap:
	var wm := WizMap.new(8)
	wm.cell(start.x, start.y).tile = TileType.START
	return wm


# Build an 8x8 WizMap so that, from the cell adjacent to `start` opposite
# `dir`, walking forward in `dir` lands on the START tile.
# Example: start=(4,4), dir=NORTH → cell (4,5) opens NORTH onto (4,4).
static func make_neighbor_to_start_fixture(start: Vector2i, dir: int) -> WizMap:
	var wm := WizMap.new(8)
	var neighbor := start - Direction.offset(dir)
	wm.set_edge(neighbor.x, neighbor.y, dir, EdgeType.OPEN)
	wm.cell(start.x, start.y).tile = TileType.START
	return wm


static func make_monster_data(
	id: StringName,
	name: String = "",
	tier: int = 1,
	hp_min: int = 5,
	hp_max: int = 5,
	default_row: int = Row.FRONT,
	attack_range: int = WeaponRange.MELEE,
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = name if name != "" else String(id)
	data.max_hp_min = hp_min
	data.max_hp_max = hp_max
	data.attack = 1
	data.defense = 1
	data.agility = 1
	data.experience = 1
	data.gold_min = 0
	data.gold_max = 0
	data.default_row = default_row
	data.attack_range = attack_range
	data.tier = tier
	return data


static func make_encounter_table(
	floor: int = 1,
	probability_per_step: float = 0.1,
	tier_weights: Dictionary = {1: 1},
	species_count_min: int = 1,
	species_count_max: int = 1,
	count_per_species_min: int = 1,
	count_per_species_max: int = 1,
) -> EncounterTableData:
	var table := EncounterTableData.new()
	table.floor = floor
	table.probability_per_step = probability_per_step
	table.tier_weights = tier_weights
	table.species_count_min = species_count_min
	table.species_count_max = species_count_max
	table.count_per_species_min = count_per_species_min
	table.count_per_species_max = count_per_species_max
	return table
