## ADDED Requirements

### Requirement: EncounterCoordinator selects table by current floor
The system SHALL update `EncounterCoordinator`'s active `EncounterTableData` to match the player's current floor (`player_state.current_floor + 1`, 1-based to align with `EncounterTableData.floor`) whenever the player enters a dungeon or transitions to a different floor.

#### Scenario: Initial table corresponds to floor 1
- **WHEN** the player enters a multi-floor dungeon and starts on floor 0 (1-based: floor 1)
- **THEN** EncounterCoordinator SHALL have its table set to the EncounterTableData with `floor == 1`

#### Scenario: Table switches when descending
- **WHEN** the player descends from floor 0 to floor 1 (1-based: floor 2) via STAIRS_DOWN
- **THEN** EncounterCoordinator SHALL have its table set to the EncounterTableData with `floor == 2`

#### Scenario: Table switches when ascending
- **WHEN** the player ascends from floor 2 (1-based: floor 3) to floor 1 (1-based: floor 2)
- **THEN** EncounterCoordinator SHALL have its table set to the EncounterTableData with `floor == 2`

### Requirement: Missing encounter tables fall back to the deepest available
When the system requests a table for floor N but no `EncounterTableData` with `floor == N` is registered, the system SHALL fall back to the registered table with the largest `floor` value that is less than or equal to N. If no such table exists (no tables registered at all), the encounter system SHALL be disabled and `push_warning` SHALL describe the missing data.

#### Scenario: Fallback to deepest registered table
- **WHEN** tables for floors 1, 2, and 3 are registered and the player enters floor 5
- **THEN** EncounterCoordinator SHALL use the floor 3 table and SHALL emit a push_warning identifying the missing floor 5 table

#### Scenario: No tables registered disables encounters
- **WHEN** no EncounterTableData is registered and the player enters any floor
- **THEN** EncounterCoordinator SHALL NOT trigger encounters and SHALL emit a push_warning
