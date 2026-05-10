## ADDED Requirements

### Requirement: EncounterPattern expansion assigns each spawned monster to a row bucket

When the encounter generator expands an `EncounterPattern` into concrete `MonsterCombatant` instances, each spawned individual SHALL be placed into either a FRONT bucket or a BACK bucket based on `MonsterData.default_row` (looked up via `MonsterRepository.find(monster_id)`).

The resulting `monster_party` SHALL preserve row information by initializing each `MonsterCombatant.original_row` from `monster_data.default_row` at spawn time.

#### Scenario: FRONT-default monster is placed in FRONT bucket
- **WHEN** a `MonsterGroupSpec` for a `monster_id` whose `MonsterData.default_row == FRONT` is expanded into 3 individuals
- **THEN** each of the 3 spawned `MonsterCombatant` SHALL have `original_row == Row.FRONT`

#### Scenario: BACK-default monster is placed in BACK bucket
- **WHEN** a `MonsterGroupSpec` for a `monster_id` whose `MonsterData.default_row == BACK` is expanded into 2 individuals
- **THEN** each of the 2 spawned `MonsterCombatant` SHALL have `original_row == Row.BACK`

### Requirement: Encounter expansion truncates row buckets at 5 individuals

The encounter generator SHALL enforce a hard upper bound of 5 monster instances per row bucket (FRONT max 5, BACK max 5). When expanding an `EncounterPattern` would produce more than 5 monsters in either bucket, the excess SHALL be discarded (not spawned) before the `monster_party` is constructed.

The truncation SHALL prefer earlier-listed `MonsterGroupSpec` entries: monsters that would have been the (N+1)th and beyond in the same bucket SHALL be dropped, where N is the bucket cap (5).

When truncation occurs, the encounter generator SHALL emit a `push_warning` (or equivalent log) naming the dropped monster_id and the bucket that overflowed, so that data designers can adjust the offending `EncounterPattern` definition. Truncation SHALL NOT abort encounter generation.

#### Scenario: 7 FRONT monsters truncate to 5
- **WHEN** an `EncounterPattern` expansion would produce 7 FRONT-bucket individuals (e.g., a single MonsterGroupSpec with `count_max == 7`)
- **THEN** the resulting `monster_party` SHALL contain exactly 5 FRONT-row `MonsterCombatant` instances and 0 from this overflow

#### Scenario: Mixed-row pattern within bounds is unchanged
- **WHEN** an `EncounterPattern` expansion produces 3 FRONT and 2 BACK individuals (both within their respective caps)
- **THEN** the resulting `monster_party` SHALL contain all 5 spawned `MonsterCombatant` instances

#### Scenario: Truncation order favors earlier groups
- **WHEN** an `EncounterPattern` declares two FRONT-default groups (`slime` first with count 3, `goblin` second with count 4 = 7 total FRONT)
- **THEN** the resulting bucket SHALL contain all 3 slimes and only 2 goblins (the last 2 goblins SHALL be dropped)

#### Scenario: Truncation emits a warning
- **WHEN** truncation drops at least one monster instance during pattern expansion
- **THEN** a `push_warning` (or equivalent log) SHALL be emitted naming the dropped `monster_id` and the bucket (`FRONT` or `BACK`) that overflowed

#### Scenario: Truncation does not abort spawning
- **WHEN** truncation drops monster instances
- **THEN** the encounter generator SHALL still return a valid `monster_party` containing the surviving instances; no exception SHALL be raised
