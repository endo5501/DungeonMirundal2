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
