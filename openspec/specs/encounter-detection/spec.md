## Purpose
ダンジョン歩行中のエンカウント判定ルールを規定する。歩数カウント、ランダムシード、フロアごとの出現テーブル、セーフゾーン設定など確率制御の要素を対象とする。
## Requirements
### Requirement: EncounterTableData defines per-floor encounter rules
The system SHALL provide an `EncounterTableData` Custom Resource that declares, for a given floor, an encounter probability per step and a weighted list of encounter patterns.

#### Scenario: Table exposes floor and probability
- **WHEN** an EncounterTableData has `floor = 1` and `probability_per_step = 0.1`
- **THEN** both fields SHALL be readable

#### Scenario: Table contains weighted entries
- **WHEN** an EncounterTableData has `entries` of size 3 with weights `[2, 1, 1]`
- **THEN** total weight SHALL be 4 and entries SHALL be enumerable in declaration order

### Requirement: EncounterPattern defines a reusable monster group
The system SHALL provide an `EncounterPattern` resource that declares one or more `MonsterGroupSpec` entries, each specifying a `monster_id` and a count range `[count_min, count_max]`.

#### Scenario: Pattern with mixed monster groups
- **WHEN** an EncounterPattern has two groups: `(&"slime", 2..4)` and `(&"goblin", 1..1)`
- **THEN** expanding the pattern SHALL produce 3 to 5 monsters total

### Requirement: EncounterManager detects encounters deterministically
The system SHALL provide an `EncounterManager` that, given the current step count, a `RandomNumberGenerator`, and the active `EncounterTableData`, decides whether an encounter occurs at the current step.

#### Scenario: Encounter triggers when random roll below probability
- **WHEN** EncounterManager is queried with an RNG seeded to produce a roll of 0.05 and a table with `probability_per_step = 0.1`
- **THEN** `should_trigger` SHALL return `true`

#### Scenario: Encounter does not trigger when roll above probability
- **WHEN** EncounterManager is queried with an RNG seeded to produce a roll of 0.95 and a table with `probability_per_step = 0.1`
- **THEN** `should_trigger` SHALL return `false`

#### Scenario: Identical seed produces identical trigger sequence
- **WHEN** two EncounterManager instances using identical seeds are queried with the same table for 100 consecutive steps
- **THEN** both SHALL return identical `should_trigger` sequences

### Requirement: EncounterManager enforces post-encounter cooldown
The system SHALL ensure that after an encounter occurs, no new encounter SHALL be triggered for a configurable number of subsequent steps.

#### Scenario: Cooldown prevents immediate re-trigger
- **WHEN** an encounter has just occurred and the cooldown is 3 steps
- **THEN** the next 3 `should_trigger` calls SHALL return `false` regardless of the RNG roll

#### Scenario: Cooldown expires and detection resumes
- **WHEN** the configured cooldown steps have elapsed since the last encounter
- **THEN** `should_trigger` SHALL evaluate normally against the probability

### Requirement: EncounterManager generates a MonsterParty on encounter
The system SHALL provide a `MonsterParty` (RefCounted) that is produced by `EncounterManager.generate()` by selecting a weighted `EncounterPattern` from the current floor's table and instantiating monsters per the pattern.

#### Scenario: Generated party respects pattern counts
- **WHEN** EncounterManager generates an encounter using an EncounterPattern with `(&"slime", 2..4)`
- **THEN** the resulting MonsterParty SHALL contain between 2 and 4 Monster instances whose source is the slime MonsterData

#### Scenario: Pattern selection respects weights deterministically
- **WHEN** an RNG is seeded so that the first weighted pick falls in the range of the second entry in a table of weights `[1, 2, 1]`
- **THEN** `generate` SHALL select the second EncounterPattern

#### Scenario: Missing monster_id is reported
- **WHEN** an EncounterPattern references a `monster_id` that is not in the MonsterRepository
- **THEN** `generate` SHALL emit an error and SHALL NOT return a malformed MonsterParty

### Requirement: EncounterCoordinator のデフォルト Overlay は SimpleEncounterOverlay
SHALL: `EncounterCoordinator._ready` で `_overlay == null` の場合、`SimpleEncounterOverlay.new()` を instantiate して `add_child` する。`set_overlay(other_overlay)` が外部から呼ばれた後はその Overlay を優先する。

#### Scenario: デフォルト Overlay が SimpleEncounterOverlay
- **WHEN** `EncounterCoordinator.new()` を `_ready` で起動し、`set_overlay` を呼ばないままエンカウンタを起こす
- **THEN** `SimpleEncounterOverlay` が動作し、`encounter_resolved` シグナル経由でフローが進む

#### Scenario: 外部 Overlay が優先される
- **WHEN** `set_overlay(combat_overlay)` を呼んだ後にエンカウンタを起こす
- **THEN** SimpleEncounterOverlay ではなく combat_overlay が `start_encounter` される

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

