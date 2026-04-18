## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: All shipped MonsterData .tres files specify a gold range
The system SHALL ensure every `.tres` file under `data/monsters/` sets `gold_min` and `gold_max` to non-negative integers with `gold_min <= gold_max`.

#### Scenario: Existing slime/goblin/bat files have gold ranges
- **WHEN** `DataLoader.load_all_monsters()` is invoked on the shipped data directory
- **THEN** every returned MonsterData SHALL have `gold_min >= 0` and `gold_max >= gold_min`
