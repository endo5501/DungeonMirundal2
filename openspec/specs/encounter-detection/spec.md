## Purpose
ダンジョン歩行中のエンカウント判定ルールを規定する。歩数カウント、ランダムシード、フロアごとの出現テーブル、セーフゾーン設定など確率制御の要素を対象とする。
## Requirements
### Requirement: EncounterTableData defines per-floor encounter rules

The system SHALL provide an `EncounterTableData` Custom Resource that declares, for a given floor, an encounter probability per step and a weighted distribution of monster tiers used to generate encounters.

`EncounterTableData` SHALL expose the following fields:

- `@export var floor: int = 1` — 1-based floor number this table applies to. SHALL satisfy `floor >= 1`.
- `@export var probability_per_step: float = 0.1` — per-step encounter probability. SHALL satisfy `0.0 <= probability_per_step <= 1.0`.
- `@export var tier_weights: Dictionary = {}` — maps `tier` (integer in `[1, 5]`) to `weight` (positive integer). At least one entry SHALL have a positive weight. Keys outside `[1, 5]` SHALL be rejected by validation. Negative or zero weights for an explicitly listed tier SHALL be rejected.
- `@export var species_count_min: int = 1` — minimum number of distinct species slots drawn per encounter. SHALL satisfy `species_count_min >= 1`.
- `@export var species_count_max: int = 2` — maximum number of distinct species slots drawn per encounter. SHALL satisfy `species_count_min <= species_count_max`.
- `@export var count_per_species_min: int = 1` — minimum count of individuals spawned per species slot. SHALL satisfy `count_per_species_min >= 1`.
- `@export var count_per_species_max: int = 4` — maximum count of individuals spawned per species slot. SHALL satisfy `count_per_species_min <= count_per_species_max`.

When `tier_weights` contains a key stored as a string (because Godot dictionary serialization can coerce integer keys), validation SHALL accept the value provided that the string parses as an integer in `[1, 5]`. Runtime lookup logic SHALL normalize keys to `int`.

#### Scenario: Table exposes floor and probability
- **WHEN** an EncounterTableData has `floor = 1` and `probability_per_step = 0.1`
- **THEN** both fields SHALL be readable

#### Scenario: Table accepts valid tier weights
- **WHEN** an EncounterTableData has `tier_weights = {1: 6, 2: 1}`
- **THEN** validation SHALL accept it

#### Scenario: Empty tier_weights is rejected
- **WHEN** an EncounterTableData has `tier_weights = {}`
- **THEN** validation SHALL report an error

#### Scenario: All-zero tier_weights is rejected
- **WHEN** an EncounterTableData has `tier_weights = {1: 0, 2: 0}`
- **THEN** validation SHALL report an error

#### Scenario: Out-of-range tier key is rejected
- **WHEN** an EncounterTableData has `tier_weights = {6: 1}` (tier 6 is outside [1, 5])
- **THEN** validation SHALL report an error

#### Scenario: Probability out of range is rejected
- **WHEN** an EncounterTableData has `probability_per_step = 1.5`
- **THEN** validation SHALL report an error

#### Scenario: Inverted species_count is rejected
- **WHEN** an EncounterTableData has `species_count_min = 3` and `species_count_max = 1`
- **THEN** validation SHALL report an error

#### Scenario: Inverted count_per_species is rejected
- **WHEN** an EncounterTableData has `count_per_species_min = 5` and `count_per_species_max = 2`
- **THEN** validation SHALL report an error

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

The system SHALL provide a `MonsterParty` (RefCounted) that is produced by `EncounterManager.generate(rng)` using the current floor's `EncounterTableData` and the supplied `RandomNumberGenerator`.

The generation algorithm SHALL be:

1. Roll `n_species` uniformly in `[table.species_count_min, table.species_count_max]`.
2. For each of the `n_species` species slots:
   a. Pick a `tier` by weighted random selection from `table.tier_weights` (weight is the integer value).
   b. Resolve candidates via `MonsterRepository.find_by_tier(tier)`. If empty, emit a `push_warning` naming the tier and SHALL skip this slot.
   c. Pick a single `MonsterData` uniformly at random from the candidates.
   d. Roll `count` uniformly in `[table.count_per_species_min, table.count_per_species_max]`.
   e. Spawn `count` `Monster` instances from the chosen `MonsterData` and append them to the party, subject to the row bucket cap (see the row truncation requirement).

Identical seeds SHALL produce identical generated parties (deterministic generation).

When `table == null` or `table.tier_weights` is empty, `generate` SHALL return an empty `MonsterParty`.

#### Scenario: Generated party respects species count range
- **WHEN** EncounterManager generates an encounter with `species_count_min = 1`, `species_count_max = 1`, `tier_weights = {1: 1}` and a repository containing only `slime` at tier 1
- **THEN** the resulting MonsterParty SHALL contain Monster instances whose source is `slime` MonsterData

#### Scenario: Generated party respects per-species count range
- **WHEN** EncounterManager generates with `species_count_min = 1`, `species_count_max = 1`, `count_per_species_min = 2`, `count_per_species_max = 4`, and a tier resolving to a single monster
- **THEN** the resulting MonsterParty SHALL contain between 2 and 4 Monster instances of that species

#### Scenario: Tier selection respects weights deterministically
- **WHEN** an RNG is seeded so that the weighted pick over `tier_weights = {1: 1, 2: 2, 3: 1}` selects tier 2
- **THEN** `generate` SHALL choose a monster from tier 2 candidates only

#### Scenario: Identical seed produces identical party
- **WHEN** two EncounterManager instances using identical seeds are queried with the same table
- **THEN** both SHALL return identical generated parties (same species, same counts, same ordering)

#### Scenario: Empty candidate tier emits warning and skips slot
- **WHEN** `generate` picks a tier whose `find_by_tier` returns an empty array
- **THEN** `push_warning` SHALL be emitted naming the empty tier AND the slot SHALL contribute zero monsters AND generation SHALL continue for remaining slots

#### Scenario: Null table returns empty party
- **WHEN** `generate` is called without setting a table
- **THEN** the returned MonsterParty SHALL be empty

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

### Requirement: Encounter expansion truncates row buckets at 5 individuals

The encounter generator SHALL enforce a hard upper bound of 5 monster instances per row bucket (FRONT max 5, BACK max 5). When `EncounterManager.generate` would spawn more than 5 monsters in either bucket, the excess SHALL be discarded (not spawned) before the `monster_party` is constructed.

The truncation SHALL prefer earlier-spawned individuals: monsters that would have been the (N+1)th and beyond in the same bucket SHALL be dropped, where N is the bucket cap (5). Spawn order within a single `generate()` call is defined by the iteration order over species slots, and within each slot the natural order of count incrementation.

When truncation occurs, the encounter generator SHALL emit a `push_warning` (or equivalent log) naming the dropped monster_id and the bucket that overflowed, so that data designers can adjust the offending table configuration. Truncation SHALL NOT abort encounter generation.

#### Scenario: 7 FRONT monsters truncate to 5
- **WHEN** `generate` would produce 7 FRONT-bucket individuals (e.g., a single species slot with count 7 from a FRONT-default monster)
- **THEN** the resulting `monster_party` SHALL contain exactly 5 FRONT-row Monster instances and 0 from this overflow

#### Scenario: Mixed-row spawn within bounds is unchanged
- **WHEN** `generate` produces 3 FRONT-default and 2 BACK-default individuals (both within their respective caps)
- **THEN** the resulting `monster_party` SHALL contain all 5 spawned Monster instances

#### Scenario: Truncation order favors earlier species slots
- **WHEN** `generate` selects two FRONT-default species in order: `slime` with count 3 first, then `goblin` with count 4 (= 7 total FRONT)
- **THEN** the resulting bucket SHALL contain all 3 slimes and only 2 goblins (the last 2 goblins SHALL be dropped)

#### Scenario: Truncation emits a warning
- **WHEN** truncation drops at least one monster instance during generation
- **THEN** a `push_warning` (or equivalent log) SHALL be emitted naming the dropped `monster_id` and the bucket (`FRONT` or `BACK`) that overflowed

#### Scenario: Truncation does not abort spawning
- **WHEN** truncation drops monster instances
- **THEN** the encounter generator SHALL still return a valid `monster_party` containing the surviving instances; no exception SHALL be raised

