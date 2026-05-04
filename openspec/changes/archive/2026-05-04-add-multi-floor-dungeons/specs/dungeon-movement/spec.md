## ADDED Requirements

### Requirement: DungeonScreen tracks current floor's wiz_map and explored_map
`DungeonScreen` SHALL operate on the current floor's `WizMap` and `ExploredMap` as determined by `player_state.current_floor`. When the player transitions to a different floor, `DungeonScreen` SHALL switch its rendering, minimap, and input handling to the new floor's data.

#### Scenario: Movement uses the current floor's wiz_map
- **WHEN** player_state.current_floor == 1 and the player presses move_forward
- **THEN** the move SHALL be evaluated against floors[1].wiz_map and the player position SHALL update only if floors[1].wiz_map permits the move

#### Scenario: Minimap reflects the current floor only
- **WHEN** the player is on floor 1 and the minimap is rendered
- **THEN** the minimap SHALL display floors[1] data only (cells, walls, doors, explored regions)

#### Scenario: explored_map updates target the current floor
- **WHEN** player_state.current_floor == 2 and a step reveals new cells
- **THEN** floors[2].explored_map SHALL be updated and floors[0]/floors[1].explored_map SHALL NOT change

### Requirement: Stair tiles do not block movement
The walkability of `STAIRS_DOWN` and `STAIRS_UP` tiles SHALL be determined solely by their cell edges (WALL / OPEN / DOOR), exactly as `FLOOR` tiles are. Stair tiles SHALL NOT have intrinsic movement restrictions.

#### Scenario: Player walks onto STAIRS_DOWN through an OPEN edge
- **WHEN** the player faces a STAIRS_DOWN tile through an edge of type OPEN
- **THEN** move_forward SHALL succeed and the player SHALL be on the STAIRS_DOWN tile (the floor transition SHALL be handled by the dungeon-return capability)

#### Scenario: Player cannot walk onto STAIRS_UP through a WALL edge
- **WHEN** the player faces a STAIRS_UP tile through an edge of type WALL
- **THEN** move_forward SHALL be rejected
