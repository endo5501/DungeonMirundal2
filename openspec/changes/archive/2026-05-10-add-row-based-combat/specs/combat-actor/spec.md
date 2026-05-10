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

### Requirement: MonsterCombatant exposes an original_row sourced from MonsterData

The system SHALL expose `MonsterCombatant.original_row: Row` whose value is sourced from `monster.data.default_row` (the implementation MAY store the row as a field initialized at construction OR derive it dynamically from the wrapped data; both are acceptable as long as the observed value matches `monster.data.default_row` while the data is reachable).

When the wrapped `monster` or `monster.data` is `null`, `original_row` SHALL fall back to `Row.FRONT` so engine code can rely on a non-null value.

`original_row` SHALL reflect the spawn-time value of `MonsterData.default_row` for the duration of a battle. (No code path mutates `MonsterData.default_row` during battle.)

#### Scenario: MonsterCombatant adopts MonsterData.default_row
- **WHEN** a `MonsterCombatant` is constructed wrapping a `Monster` whose `MonsterData.default_row == Row.BACK`
- **THEN** the resulting `MonsterCombatant.original_row` SHALL equal `Row.BACK`

#### Scenario: MonsterCombatant fallback is FRONT when data is missing
- **WHEN** a `MonsterCombatant` is constructed without a wrapped monster (or with a monster whose `data` is null)
- **THEN** `original_row` SHALL equal `Row.FRONT`
