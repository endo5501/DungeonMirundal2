## Purpose
DungeonData と DungeonRegistry による複数ダンジョンの保持と参照を規定する。生成・選択・削除・探索状態の記録と、GameState との統合を対象とする。

## Requirements

### Requirement: DungeonData holds single dungeon state
DungeonData SHALL hold dungeon_name (String), seed (int), map_size (int), wiz_map (WizMap), explored_map (ExploredMap), and player_state (PlayerState) for a single dungeon.

#### Scenario: DungeonData stores all dungeon state
- **WHEN** a DungeonData is created with name "暗黒の迷宮", seed 42, size 16
- **THEN** dungeon_name SHALL be "暗黒の迷宮", seed SHALL be 42, map_size SHALL be 16, wiz_map SHALL be a generated WizMap, explored_map SHALL be empty, and player_state SHALL be at the START tile facing NORTH

### Requirement: DungeonData calculates exploration rate
DungeonData SHALL provide a `get_exploration_rate()` method that returns the ratio of visited cells to total cells as a float between 0.0 and 1.0.

#### Scenario: Empty exploration
- **WHEN** no cells have been visited
- **THEN** get_exploration_rate() SHALL return 0.0

#### Scenario: Partial exploration
- **WHEN** 64 of 256 cells (16x16 map) have been visited
- **THEN** get_exploration_rate() SHALL return 0.25

### Requirement: DungeonRegistry manages multiple dungeons
DungeonRegistry SHALL hold an array of DungeonData and provide methods to create, remove, get, and list dungeons.

#### Scenario: Initially empty
- **WHEN** a new DungeonRegistry is created
- **THEN** size() SHALL return 0 and get_all() SHALL return an empty array

#### Scenario: Create adds a dungeon
- **WHEN** create() is called with name "迷宮" and size_category MEDIUM
- **THEN** size() SHALL return 1 and get_all() SHALL contain the new DungeonData

#### Scenario: Remove deletes a dungeon
- **WHEN** a DungeonRegistry has 2 dungeons and remove(0) is called
- **THEN** size() SHALL return 1

#### Scenario: Get retrieves by index
- **WHEN** a DungeonRegistry has 3 dungeons
- **THEN** get(1) SHALL return the second DungeonData

### Requirement: DungeonRegistry creates dungeons with size categories
DungeonRegistry.create() SHALL accept a size_category parameter: SMALL (0) generates map_size 8-12, MEDIUM (1) generates 13-20, LARGE (2) generates 21-30. The actual size within the range SHALL be randomly determined.

#### Scenario: Small dungeon size range
- **WHEN** create() is called with size_category SMALL
- **THEN** the created DungeonData's map_size SHALL be between 8 and 12 inclusive

#### Scenario: Medium dungeon size range
- **WHEN** create() is called with size_category MEDIUM
- **THEN** the created DungeonData's map_size SHALL be between 13 and 20 inclusive

#### Scenario: Large dungeon size range
- **WHEN** create() is called with size_category LARGE
- **THEN** the created DungeonData's map_size SHALL be between 21 and 30 inclusive

### Requirement: DungeonNameGenerator produces random Japanese names
DungeonNameGenerator SHALL generate names by combining a random adjective and a random noun from predefined Japanese word lists.

#### Scenario: Generated name format
- **WHEN** generate() is called
- **THEN** the result SHALL be a non-empty String composed of an adjective followed by a noun (e.g. "忘却の地下墓地")

#### Scenario: Names have variety
- **WHEN** generate() is called 10 times
- **THEN** at least 2 distinct names SHALL be produced
