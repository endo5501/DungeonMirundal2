## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Shipped monsters reference generated battle art
The system SHALL include generated battle image assets for the six shipped monster ids and SHALL wire each corresponding `data/monsters/*.tres` resource to its image through `MonsterData.battle_texture`.

The committed monster image assets SHALL live under `assets/images/monsters/` using `<monster_id>.png` filenames for `slime`, `goblin`, `bat`, `skeleton`, `ghost`, and `dragon`.

#### Scenario: Existing shipped monsters have battle textures
- **WHEN** `DataLoader.load_all_monsters()` is invoked
- **THEN** the returned MonsterData for `&"slime"`, `&"goblin"`, `&"bat"`, `&"skeleton"`, `&"ghost"`, and `&"dragon"` SHALL each have a non-null `battle_texture`

#### Scenario: Monster art files follow the stable path convention
- **WHEN** the shipped monster art assets are inspected
- **THEN** the files SHALL exist at `assets/images/monsters/slime.png`, `assets/images/monsters/goblin.png`, `assets/images/monsters/bat.png`, `assets/images/monsters/skeleton.png`, `assets/images/monsters/ghost.png`, and `assets/images/monsters/dragon.png`
