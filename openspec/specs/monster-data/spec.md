## Purpose
モンスター（MonsterData）リソースの定義と各種バランス数値を規定する。HP・攻撃力・防御力・経験値・ドロップテーブル・出現階層などの項目を対象とする。
## Requirements
### Requirement: MonsterData defines a monster template
The system SHALL provide a `MonsterData` Custom Resource that defines a monster template with identifier, display name, stat ranges, reward values, and an optional battle visual.

`MonsterData` SHALL expose the following fields: `monster_id: StringName`, `monster_name: String`, `max_hp_min: int`, `max_hp_max: int`, `attack: int`, `defense: int`, `agility: int`, `experience: int`, `gold_min: int`, `gold_max: int`, `battle_texture: Texture2D`.

The `gold_min` and `gold_max` fields represent the inclusive range of gold awarded when a single instance of this monster dies. The range SHALL satisfy `0 <= gold_min <= gold_max`.

`battle_texture` SHALL be optional. Missing battle art SHALL NOT make otherwise valid MonsterData unusable, because combat rendering provides a fallback visual.

#### Scenario: MonsterData carries required fields
- **WHEN** a MonsterData resource is created with `monster_id`, `monster_name`, `max_hp_min`, `max_hp_max`, `attack`, `defense`, `agility`, `experience`, `gold_min`, `gold_max`, and `battle_texture`
- **THEN** every field SHALL be readable and typed consistently with its declaration

#### Scenario: Battle texture is optional
- **WHEN** a MonsterData resource has `battle_texture == null`
- **THEN** validation SHALL still accept the monster when all non-visual fields are valid

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

### Requirement: MonsterData carries a resists dictionary

The system SHALL extend `MonsterData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values. Negative values are allowed.

Representative monster `.tres` files SHALL declare resists consistent with their thematic role (full list authored at implementation time; the following are mandatory examples):

| Monster | resists (minimum required keys) |
|---------|---------------------------------|
| slime | `{ &"poison": 1.0, &"sleep": 0.30 }` |
| skeleton | `{ &"poison": 1.0, &"sleep": 1.0, &"paralysis": 0.50 }` |
| ghost | `{ &"poison": 1.0, &"sleep": 1.0, &"blind": 1.0 }` |
| bat | `{ &"poison": 0.30, &"blind": 1.0 }` |
| dragon | `{ &"sleep": 0.50, &"paralysis": 0.30, &"confusion": 0.50 }` |

Other monsters MAY declare `resists = {}` if no thematic resistance applies.

#### Scenario: Slime is fully poison-immune
- **WHEN** `slime.tres` is loaded
- **THEN** `resists.get(&"poison")` SHALL be `1.0`

#### Scenario: Skeleton is immune to poison and sleep
- **WHEN** `skeleton.tres` is loaded
- **THEN** `resists.get(&"poison")` SHALL be `1.0` AND `resists.get(&"sleep")` SHALL be `1.0`

#### Scenario: Ghost is immune to physical-flavored statuses
- **WHEN** `ghost.tres` is loaded
- **THEN** `resists.get(&"poison")` AND `resists.get(&"sleep")` AND `resists.get(&"blind")` SHALL all equal `1.0`

#### Scenario: Bat resists blind fully and poison partially
- **WHEN** `bat.tres` is loaded
- **THEN** `resists.get(&"blind")` SHALL be `1.0` AND `resists.get(&"poison")` SHALL be approximately `0.30`

#### Scenario: Dragon resists multiple mind-affecting statuses
- **WHEN** `dragon.tres` is loaded
- **THEN** `resists` SHALL contain at least `&"sleep"`, `&"paralysis"`, `&"confusion"` with positive values

### Requirement: Shipped monsters reference generated battle art
The system SHALL include generated battle image assets for the six shipped monster ids and SHALL wire each corresponding `data/monsters/*.tres` resource to its image through `MonsterData.battle_texture`.

The committed monster image assets SHALL live under `assets/images/monsters/` using `<monster_id>.png` filenames for `slime`, `goblin`, `bat`, `skeleton`, `ghost`, and `dragon`.

#### Scenario: Existing shipped monsters have battle textures
- **WHEN** `DataLoader.load_all_monsters()` is invoked
- **THEN** the returned MonsterData for `&"slime"`, `&"goblin"`, `&"bat"`, `&"skeleton"`, `&"ghost"`, and `&"dragon"` SHALL each have a non-null `battle_texture`

#### Scenario: Monster art files follow the stable path convention
- **WHEN** the shipped monster art assets are inspected
- **THEN** the files SHALL exist at `assets/images/monsters/slime.png`, `assets/images/monsters/goblin.png`, `assets/images/monsters/bat.png`, `assets/images/monsters/skeleton.png`, `assets/images/monsters/ghost.png`, and `assets/images/monsters/dragon.png`

