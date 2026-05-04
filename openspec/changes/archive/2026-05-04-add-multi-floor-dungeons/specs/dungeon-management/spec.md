## ADDED Requirements

### Requirement: FloorData holds single floor state
`FloorData` SHALL hold `seed_value` (int), `map_size` (int), `wiz_map` (WizMap), and `explored_map` (ExploredMap) for a single dungeon floor. `FloorData` SHALL NOT contain a `PlayerState` (player position is held at the DungeonData level).

#### Scenario: FloorData stores all floor state
- **WHEN** a FloorData is created with seed 42 and size 16
- **THEN** seed_value SHALL be 42, map_size SHALL be 16, wiz_map SHALL be a generated WizMap, and explored_map SHALL be empty

#### Scenario: FloorData has no PlayerState field
- **WHEN** examining a FloorData instance
- **THEN** it SHALL NOT expose a player_state field

### Requirement: PlayerState holds current floor index
`PlayerState` SHALL include a `current_floor` (int, 0-based) field that identifies which floor of the parent DungeonData the player is currently on.

#### Scenario: Initial current_floor is 0
- **WHEN** a PlayerState is created without specifying current_floor
- **THEN** current_floor SHALL default to 0

#### Scenario: current_floor is independently readable
- **WHEN** PlayerState has current_floor=2
- **THEN** querying current_floor SHALL return 2

### Requirement: DungeonData provides current_floor accessors
`DungeonData` SHALL provide convenience methods that return the current floor's `WizMap` and `ExploredMap` based on `player_state.current_floor`.

#### Scenario: current_wiz_map returns the floor at current_floor
- **WHEN** player_state.current_floor == 1 and floors.size() == 3
- **THEN** DungeonData.current_wiz_map() SHALL return floors[1].wiz_map

#### Scenario: current_explored_map returns the floor at current_floor
- **WHEN** player_state.current_floor == 0
- **THEN** DungeonData.current_explored_map() SHALL return floors[0].explored_map

## MODIFIED Requirements

### Requirement: DungeonData holds single dungeon state
DungeonData SHALL hold `dungeon_name` (String), `floors` (Array[FloorData]), and `player_state` (PlayerState) for a multi-floor dungeon. `floors` SHALL contain at least one element. `player_state.current_floor` SHALL be a valid index into `floors`.

#### Scenario: DungeonData stores all dungeon state
- **WHEN** a DungeonData is created with name "暗黒の迷宮", base_seed 42, size_category MEDIUM, floor_count 3
- **THEN** dungeon_name SHALL be "暗黒の迷宮", floors SHALL contain 3 FloorData entries, each floor SHALL have a generated WizMap and an empty ExploredMap, and player_state SHALL be at the START tile of floors[0] facing NORTH with current_floor=0

#### Scenario: floors array is non-empty
- **WHEN** any valid DungeonData is created
- **THEN** floors.size() SHALL be at least 1

### Requirement: DungeonData calculates exploration rate
DungeonData SHALL provide a `get_exploration_rate()` method that returns the ratio of total visited cells across ALL floors to total cells across ALL floors, as a float between 0.0 and 1.0.

#### Scenario: Empty exploration
- **WHEN** no cells have been visited on any floor
- **THEN** get_exploration_rate() SHALL return 0.0

#### Scenario: Partial exploration across multiple floors
- **WHEN** floors[0] is 16x16 with 64 cells visited and floors[1] is 16x16 with 0 cells visited
- **THEN** get_exploration_rate() SHALL return 64 / 512 = 0.125

#### Scenario: Single-floor exploration matches legacy behavior
- **WHEN** floors.size() == 1, map_size 16, and 64 cells visited
- **THEN** get_exploration_rate() SHALL return 0.25 (same result as the legacy single-floor formula)

### Requirement: DungeonRegistry creates dungeons with size categories
DungeonRegistry.create() SHALL accept a `size_category` parameter: SMALL (0) generates each floor's map_size in the range 8-12, MEDIUM (1) generates 13-20, LARGE (2) generates 21-30. The number of floors SHALL also be determined by size_category: SMALL produces 2-4 floors, MEDIUM produces 4-7 floors, LARGE produces 8-12 floors. Both the floor count and per-floor map_size SHALL be randomly determined within their ranges. Each floor SHALL have an independently derived seed value derived deterministically from the dungeon's base_seed.

#### Scenario: Small dungeon floor count and size range
- **WHEN** create() is called with size_category SMALL
- **THEN** the created DungeonData's floors.size() SHALL be between 2 and 4 inclusive
- **THEN** each floor's map_size SHALL be between 8 and 12 inclusive

#### Scenario: Medium dungeon floor count and size range
- **WHEN** create() is called with size_category MEDIUM
- **THEN** the created DungeonData's floors.size() SHALL be between 4 and 7 inclusive
- **THEN** each floor's map_size SHALL be between 13 and 20 inclusive

#### Scenario: Large dungeon floor count and size range
- **WHEN** create() is called with size_category LARGE
- **THEN** the created DungeonData's floors.size() SHALL be between 8 and 12 inclusive
- **THEN** each floor's map_size SHALL be between 21 and 30 inclusive

#### Scenario: Each floor has a deterministically derived seed
- **WHEN** create() is called twice with identical inputs (same name, same size_category, same RNG seed)
- **THEN** the two resulting DungeonData instances SHALL have identical floor counts and identical per-floor seeds

### Requirement: DungeonData provides reset_to_start method

`DungeonData` SHALL provide a `reset_to_start()` method that replaces its `player_state` with a new `PlayerState` positioned on the START tile of `floors[0].wiz_map`, facing `Direction.NORTH`, with `current_floor = 0`. The method SHALL NOT modify any `FloorData` (including `wiz_map`, `explored_map`, `seed_value`, and `map_size`) and SHALL NOT modify `dungeon_name`. The method SHALL locate the START tile by the same rule used during initial creation, and SHALL be idempotent (calling it repeatedly SHALL yield the same `player_state`).

#### Scenario: reset_to_start returns player to floor 0 START tile
- **WHEN** a `DungeonData` has `player_state.position` somewhere other than the floor 0 START tile (possibly with current_floor > 0) and `reset_to_start()` is called
- **THEN** `player_state.position` SHALL equal the coordinates of `floors[0]`'s START tile, `player_state.facing` SHALL equal `Direction.NORTH`, and `player_state.current_floor` SHALL equal 0

#### Scenario: reset_to_start preserves exploration data on all floors
- **WHEN** `reset_to_start()` is called on a `DungeonData` whose floors[0].explored_map and floors[1].explored_map both contain visited cells
- **THEN** every floor's `explored_map` SHALL remain unchanged

#### Scenario: reset_to_start preserves dungeon identity
- **WHEN** `reset_to_start()` is called
- **THEN** `dungeon_name` SHALL NOT change and the floors array (including each floor's seed_value, map_size, and wiz_map) SHALL NOT change

#### Scenario: reset_to_start is idempotent
- **WHEN** `reset_to_start()` is called twice in succession on the same `DungeonData`
- **THEN** `player_state.position`, `player_state.facing`, and `player_state.current_floor` after the second call SHALL be identical to those after the first call
