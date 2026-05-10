## ADDED Requirements

### Requirement: PartyCombatant carries an original_row from PartyData

The system SHALL extend `PartyCombatant` with `original_row: Row` (default `Row.FRONT`). When `CombatOverlay.start_encounter` constructs a `PartyCombatant` for each living party member, it SHALL pass the row in which that member sits within `PartyData` (FRONT or BACK).

The `original_row` SHALL NOT be mutated during a battle. Row promotion (BACK → effective FRONT) is computed dynamically by `TurnEngine`; the actor's `original_row` field stays fixed.

#### Scenario: PartyCombatant constructed from a FRONT-row character
- **WHEN** `CombatOverlay.start_encounter` wraps a Character that occupies a slot in `PartyData.front_row`
- **THEN** the resulting `PartyCombatant` SHALL have `original_row == Row.FRONT`

#### Scenario: PartyCombatant constructed from a BACK-row character
- **WHEN** `CombatOverlay.start_encounter` wraps a Character that occupies a slot in `PartyData.back_row`
- **THEN** the resulting `PartyCombatant` SHALL have `original_row == Row.BACK`

#### Scenario: original_row defaults to FRONT for legacy callers
- **WHEN** test code or legacy production code constructs a `PartyCombatant` without specifying a row
- **THEN** `original_row` SHALL default to `Row.FRONT`

### Requirement: MonsterCombatant carries an original_row sourced from MonsterData

The system SHALL extend `MonsterCombatant` with `original_row: Row`. When the encounter generator spawns a monster instance, the spawner SHALL initialize `original_row` from `monster.data.default_row`.

The `original_row` SHALL NOT be mutated during a battle.

#### Scenario: MonsterCombatant adopts MonsterData.default_row at spawn
- **WHEN** the encounter generator spawns a `MonsterCombatant` from a `MonsterData` whose `default_row == Row.BACK`
- **THEN** the resulting `MonsterCombatant` SHALL have `original_row == Row.BACK`

#### Scenario: MonsterCombatant default fallback is FRONT
- **WHEN** test code constructs a `MonsterCombatant` without specifying a row
- **THEN** `original_row` SHALL default to `Row.FRONT`
