## ADDED Requirements

### Requirement: MonsterData defines a monster template
The system SHALL provide a `MonsterData` Custom Resource that defines a monster template with identifier, display name, stat ranges, and reward values.

`MonsterData` SHALL expose the following fields: `monster_id: StringName`, `monster_name: String`, `max_hp_min: int`, `max_hp_max: int`, `attack: int`, `defense: int`, `agility: int`, `experience: int`, `gold_min: int`, `gold_max: int`.

The `gold_min` and `gold_max` fields represent the inclusive range of gold awarded when a single instance of this monster dies. The range SHALL satisfy `0 <= gold_min <= gold_max`.

#### Scenario: MonsterData carries required fields
- **WHEN** a MonsterData resource is created with `monster_id`, `monster_name`, `max_hp_min`, `max_hp_max`, `attack`, `defense`, `agility`, `experience`, `gold_min`, `gold_max`
- **THEN** every field SHALL be readable and typed consistently with its declaration

#### Scenario: HP range is valid
- **WHEN** a MonsterData has `max_hp_min = 5` and `max_hp_max = 10`
- **THEN** validation SHALL accept it as a valid range with `max_hp_min <= max_hp_max`

#### Scenario: Invalid HP range is rejected
- **WHEN** a MonsterData has `max_hp_min = 10` and `max_hp_max = 5`
- **THEN** validation SHALL report an error and the monster SHALL NOT be usable

#### Scenario: Gold range is valid
- **WHEN** a MonsterData has `gold_min = 5` and `gold_max = 15`
- **THEN** validation SHALL accept it as a valid range

#### Scenario: Invalid gold range is rejected
- **WHEN** a MonsterData has `gold_min = 20` and `gold_max = 5`
- **THEN** validation SHALL report an error and the monster SHALL NOT be usable

#### Scenario: Zero gold range is valid
- **WHEN** a MonsterData has `gold_min = 0` and `gold_max = 0`
- **THEN** validation SHALL accept it (used for monsters that drop no gold)

### Requirement: MonsterRepository loads and provides monsters by id
The system SHALL provide a `MonsterRepository` that loads all MonsterData resources at startup and exposes lookup by `monster_id` via `find(monster_id)`.

#### Scenario: Lookup existing monster
- **WHEN** a MonsterRepository is populated with a MonsterData whose `monster_id` is `&"slime"`
- **THEN** `find(&"slime")` SHALL return that MonsterData

#### Scenario: Lookup missing monster
- **WHEN** a MonsterRepository is queried for `monster_id` `&"nonexistent"`
- **THEN** `find(&"nonexistent")` SHALL return `null`

#### Scenario: Bulk load from data directory
- **WHEN** `DataLoader.load_all_monsters()` is invoked
- **THEN** every `.tres` file under `data/monsters/` SHALL be loaded into the MonsterRepository

### Requirement: Monster instance derives per-encounter values
The system SHALL provide a `Monster` instance type (RefCounted) that is created from a MonsterData plus a RandomNumberGenerator, producing a rolled `max_hp` within the declared range and initializing `current_hp = max_hp`.

#### Scenario: Rolled HP is within declared range
- **WHEN** a Monster is instantiated from MonsterData with `max_hp_min = 5` and `max_hp_max = 10` using a seeded RNG
- **THEN** the resulting `max_hp` SHALL satisfy `5 <= max_hp <= 10`

#### Scenario: Current HP starts at max
- **WHEN** a Monster instance is created
- **THEN** `current_hp` SHALL equal `max_hp`

#### Scenario: Identical seed produces identical HP
- **WHEN** two Monster instances are created from the same MonsterData using RNGs seeded with the same value
- **THEN** both SHALL have equal `max_hp`

### Requirement: All shipped MonsterData .tres files specify a gold range
The system SHALL ensure every `.tres` file under `data/monsters/` sets `gold_min` and `gold_max` to non-negative integers with `gold_min <= gold_max`.

#### Scenario: Existing slime/goblin/bat files have gold ranges
- **WHEN** `DataLoader.load_all_monsters()` is invoked on the shipped data directory
- **THEN** every returned MonsterData SHALL have `gold_min >= 0` and `gold_max >= gold_min`
