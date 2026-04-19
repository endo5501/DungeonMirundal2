## ADDED Requirements

### Requirement: DungeonData provides reset_to_start method

`DungeonData` SHALL provide a `reset_to_start()` method that replaces its `player_state` with a new `PlayerState` positioned on the START tile of the dungeon's `wiz_map` and facing `Direction.NORTH`. The method SHALL NOT modify `wiz_map`, `explored_map`, `seed_value`, `map_size`, or `dungeon_name`. The method SHALL locate the START tile by the same rule used during initial creation (`_find_start`), and SHALL be idempotent (calling it repeatedly SHALL yield the same `player_state`).

#### Scenario: reset_to_start returns player to START tile
- **WHEN** a `DungeonData` has `player_state.position` somewhere other than the START tile and `reset_to_start()` is called
- **THEN** `player_state.position` SHALL equal the coordinates of the START tile and `player_state.facing` SHALL equal `Direction.NORTH`

#### Scenario: reset_to_start preserves exploration data
- **WHEN** `reset_to_start()` is called on a `DungeonData` whose `explored_map` contains visited cells
- **THEN** `explored_map` SHALL remain unchanged (same visited set, same to_dict() output)

#### Scenario: reset_to_start preserves dungeon identity
- **WHEN** `reset_to_start()` is called
- **THEN** `dungeon_name`, `seed_value`, `map_size`, and `wiz_map` SHALL NOT change

#### Scenario: reset_to_start is idempotent
- **WHEN** `reset_to_start()` is called twice in succession on the same `DungeonData`
- **THEN** `player_state.position` and `player_state.facing` after the second call SHALL be identical to those after the first call
