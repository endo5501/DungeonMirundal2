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

### Requirement: MonsterData declares row position and attack range

The system SHALL extend `MonsterData` with two new exported fields:

- `@export var default_row: Row = Row.FRONT` — the row in which an instance of this monster is initially placed when an encounter spawns. The `Row` enum SHALL have values `FRONT` and `BACK`.
- `@export var attack_range: WeaponRange = WeaponRange.MELEE` — the attack reach of this monster. SHALL share the `WeaponRange` enum (`MELEE`, `RANGED`) with `WeaponData` so that combat reachability code is type-agnostic between party and monster attackers.

Both fields SHALL be readable on every `MonsterData` instance, including instances loaded from `.tres` files that predate this change.

#### Scenario: Slime is FRONT/MELEE by default
- **WHEN** a `MonsterData` is constructed without explicitly setting `default_row` or `attack_range`
- **THEN** `default_row` SHALL equal `Row.FRONT` and `attack_range` SHALL equal `WeaponRange.MELEE`

#### Scenario: Witch monster declares BACK/RANGED
- **WHEN** a `MonsterData` is constructed with `default_row = Row.BACK` and `attack_range = WeaponRange.RANGED`
- **THEN** both fields SHALL be readable as configured

#### Scenario: Pre-migration MonsterData tres loads with FRONT/MELEE fallback
- **WHEN** `DataLoader.load_all_monsters()` reads an existing `MonsterData` `.tres` file that does not include the new `default_row` or `attack_range` properties
- **THEN** the loaded `MonsterData` SHALL have `default_row == Row.FRONT` and `attack_range == WeaponRange.MELEE`, and SHALL NOT raise a load error

### Requirement: Row enum is shared across spawn and combat code

The system SHALL declare the `Row` enum (with values `FRONT` and `BACK`) in a single location reachable by both monster spawn logic (encounter generation) and combat actor logic (PartyCombatant / MonsterCombatant row tracking). Party rows and monster rows SHALL use the same enum so that combat reachability code can compare them without conversion.

#### Scenario: Single Row enum used by party and monster code
- **WHEN** code references `Row.FRONT` from party-formation, monster-data, combat-actor, or combat-engine paths
- **THEN** all references SHALL resolve to the same enum constant

### Requirement: MonsterData declares MP range and known spells

The system SHALL extend `MonsterData` with three new exported fields:

- `@export var max_mp_min: int = 0` — minimum rolled MP for an instance of this monster. SHALL satisfy `max_mp_min >= 0`.
- `@export var max_mp_max: int = 0` — maximum rolled MP for an instance. SHALL satisfy `max_mp_min <= max_mp_max`.
- `@export var known_spells: Array[StringName] = []` — list of `SpellData.id` values this monster's AI may consider casting. Order is irrelevant. Duplicates SHALL be allowed but produce no benefit.

All three fields SHALL be readable on every `MonsterData` instance, including instances loaded from `.tres` files authored before this change. Pre-migration `.tres` files SHALL load with `max_mp_min == 0`, `max_mp_max == 0`, and `known_spells == []` as fallbacks, and SHALL NOT raise a load error.

#### Scenario: Defaults when fields are unset
- **WHEN** a `MonsterData` is constructed without explicitly setting MP or spell fields
- **THEN** `max_mp_min == 0`, `max_mp_max == 0`, and `known_spells == []`

#### Scenario: MP range is valid when min <= max
- **WHEN** a `MonsterData` has `max_mp_min = 4` and `max_mp_max = 10`
- **THEN** validation SHALL accept it

#### Scenario: Invalid MP range is rejected
- **WHEN** a `MonsterData` has `max_mp_min = 10` and `max_mp_max = 4`
- **THEN** validation SHALL report an error and the monster SHALL NOT be usable

#### Scenario: Negative MP is rejected
- **WHEN** a `MonsterData` has `max_mp_min = -1`
- **THEN** validation SHALL report an error

#### Scenario: Pre-migration MonsterData tres loads with default MP and spells
- **WHEN** `DataLoader.load_all_monsters()` reads an existing `MonsterData` `.tres` file (e.g., `slime.tres`) that does not include the new MP or `known_spells` properties
- **THEN** the loaded `MonsterData` SHALL have `max_mp_min == 0`, `max_mp_max == 0`, `known_spells == []`, and SHALL NOT raise a load error

### Requirement: Monster instance rolls per-encounter MP

The system SHALL, when constructing a `Monster` instance from a `MonsterData` plus a `RandomNumberGenerator`, roll `max_mp` within the data's declared range using `rng.randi_range(data.max_mp_min, data.max_mp_max)` and initialize `current_mp = max_mp`.

When `data.max_mp_min == 0 AND data.max_mp_max == 0`, the rolled `max_mp` SHALL be `0` and `current_mp` SHALL be `0` (no rng call required, but a call with `randi_range(0, 0)` returning `0` is also acceptable).

#### Scenario: Rolled MP is within declared range
- **WHEN** a `Monster` is instantiated from `MonsterData` with `max_mp_min = 4, max_mp_max = 10` using a seeded RNG
- **THEN** the resulting `max_mp` SHALL satisfy `4 <= max_mp <= 10`

#### Scenario: Current MP starts at max
- **WHEN** a `Monster` is instantiated with rolled `max_mp == 7`
- **THEN** `current_mp` SHALL equal `7`

#### Scenario: Zero-MP monster has zero MP
- **WHEN** a `Monster` is instantiated from a `MonsterData` with `max_mp_min == 0 AND max_mp_max == 0`
- **THEN** the resulting `max_mp == 0` AND `current_mp == 0`

#### Scenario: Identical seed produces identical MP
- **WHEN** two `Monster` instances are created from the same `MonsterData` using RNGs seeded with the same value
- **THEN** both SHALL have equal `max_mp`

### Requirement: New spell-casting monsters are shipped as .tres files

The system SHALL ship six new `MonsterData` `.tres` files under `data/monsters/` for the following monster ids: `witch`, `dark_priest`, `imp`, `lich`, `goblin_shaman`, `wraith`. Each SHALL declare reasonable stat ranges, a non-empty `known_spells` array, and `default_row` / `attack_range` consistent with its archetype.

The exact tuning values are an implementation concern (see `tasks.md`); this spec fixes only the structural commitments:

| id | default_row | attack_range | known_spells (minimum required) |
|---|---|---|---|
| `witch` | `Row.BACK` | `WeaponRange.RANGED` | contains `&"fire"`, `&"frost"`, `&"katino"` |
| `dark_priest` | `Row.BACK` | `WeaponRange.MELEE` | contains `&"heal"`, `&"holy"`, `&"badi"` |
| `imp` | `Row.FRONT` | `WeaponRange.MELEE` | contains `&"dazil"`, `&"poison_dart"` |
| `lich` | `Row.BACK` | `WeaponRange.RANGED` | contains `&"flame"`, `&"blizzard"`, `&"madalto"` |
| `goblin_shaman` | `Row.BACK` | `WeaponRange.MELEE` | contains `&"heal"`, `&"manifo"` |
| `wraith` | `Row.BACK` | `WeaponRange.RANGED` | contains `&"poison_dart"`, `&"dazil"` |

Each `.tres` SHALL satisfy `max_mp_min >= max(spell.mp_cost for spell in known_spells)` so that the monster can cast at least one of its spells on full MP. `max_mp_max` SHALL allow casting roughly 2–3 spells per encounter (i.e., at least 2x the cheapest known spell's `mp_cost`).

#### Scenario: All six new monster files exist
- **WHEN** the `data/monsters/` directory is scanned after this change
- **THEN** the following `.tres` files SHALL exist: `witch.tres`, `dark_priest.tres`, `imp.tres`, `lich.tres`, `goblin_shaman.tres`, `wraith.tres`

#### Scenario: witch loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"witch")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.BACK`, `attack_range == WeaponRange.RANGED`, and `known_spells` SHALL contain `&"fire"`, `&"frost"`, `&"katino"`

#### Scenario: dark_priest loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"dark_priest")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.BACK`, `attack_range == WeaponRange.MELEE`, and `known_spells` SHALL contain `&"heal"`, `&"holy"`, `&"badi"`

#### Scenario: imp loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"imp")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.FRONT`, `attack_range == WeaponRange.MELEE`, and `known_spells` SHALL contain `&"dazil"`, `&"poison_dart"`

#### Scenario: lich loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"lich")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.BACK`, `attack_range == WeaponRange.RANGED`, and `known_spells` SHALL contain `&"flame"`, `&"blizzard"`, `&"madalto"`

#### Scenario: goblin_shaman loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"goblin_shaman")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.BACK`, `attack_range == WeaponRange.MELEE`, and `known_spells` SHALL contain `&"heal"`, `&"manifo"`

#### Scenario: wraith loads with expected row/range/spells
- **WHEN** `MonsterRepository.find(&"wraith")` is called
- **THEN** the returned `MonsterData` SHALL have `default_row == Row.BACK`, `attack_range == WeaponRange.RANGED`, and `known_spells` SHALL contain `&"poison_dart"`, `&"dazil"`

#### Scenario: New monsters have enough MP to cast at least one spell
- **WHEN** any new monster (witch / dark_priest / imp / lich / goblin_shaman / wraith) is loaded
- **THEN** `max_mp_min >= min(spell.mp_cost for spell in known_spells_resolved)` where `known_spells_resolved` is the array of `SpellData` resolved through `SpellRepository`

### Requirement: New monsters declare thematic resists

The system SHALL declare `resists` on each new monster consistent with its archetype. The minimum required mappings are:

| Monster | resists (minimum required keys) |
|---------|---------------------------------|
| `witch` | `{ &"sleep": 0.30 }` |
| `dark_priest` | `{ &"poison": 1.0, &"sleep": 1.0 }` (undead) |
| `imp` | `{}` (no thematic resist) |
| `lich` | `{ &"poison": 1.0, &"sleep": 1.0, &"paralysis": 0.50 }` (undead) |
| `goblin_shaman` | `{ &"sleep": 0.20 }` |
| `wraith` | `{ &"poison": 1.0, &"sleep": 1.0, &"blind": 1.0 }` (ethereal undead) |

Other resist keys MAY be added at implementation time without violating this requirement.

#### Scenario: dark_priest is poison/sleep immune
- **WHEN** `dark_priest.tres` is loaded
- **THEN** `resists.get(&"poison")` SHALL be `1.0` AND `resists.get(&"sleep")` SHALL be `1.0`

#### Scenario: lich resists multiple mind-affecting statuses
- **WHEN** `lich.tres` is loaded
- **THEN** `resists` SHALL contain at least `&"poison": 1.0`, `&"sleep": 1.0`, and `&"paralysis": 0.50` (or stronger)

#### Scenario: wraith is immune to poison/sleep/blind
- **WHEN** `wraith.tres` is loaded
- **THEN** `resists.get(&"poison")` AND `resists.get(&"sleep")` AND `resists.get(&"blind")` SHALL all equal `1.0`

### Requirement: New monsters reference battle texture assets at the conventional path

The system SHALL ship a battle-texture asset for each new monster at `assets/images/monsters/<monster_id>.png` and SHALL wire each new `.tres`'s `battle_texture` to that asset. The shipped image MAY be a placeholder (transparent PNG, reuse of an existing asset, or simple silhouette); production art is out of scope for this change.

#### Scenario: Each new monster has a battle texture file
- **WHEN** the `assets/images/monsters/` directory is inspected
- **THEN** the files `witch.png`, `dark_priest.png`, `imp.png`, `lich.png`, `goblin_shaman.png`, `wraith.png` SHALL exist

#### Scenario: Each new MonsterData references its battle texture
- **WHEN** `MonsterRepository.find(<new_id>)` is called for any of the six new ids
- **THEN** the returned `MonsterData.battle_texture` SHALL NOT be `null`

### Requirement: MonsterData declares a tier

The system SHALL extend `MonsterData` with `@export var tier: int = 1`. The field represents the monster's strength layer used for encounter generation, where `1` denotes the weakest layer and `5` denotes the strongest. Validation SHALL require `1 <= tier <= 5`.

The field SHALL be readable on every `MonsterData` instance, including instances loaded from `.tres` files that predate this change. Pre-migration `.tres` files SHALL load with `tier == 1` as a fallback and SHALL NOT raise a load error.

#### Scenario: Default tier is 1

- **WHEN** a `MonsterData` is constructed without explicitly setting `tier`
- **THEN** `tier` SHALL equal `1`

#### Scenario: Tier in valid range is accepted

- **WHEN** a `MonsterData` has `tier = 3`
- **THEN** validation SHALL accept it

#### Scenario: Tier below 1 is rejected

- **WHEN** a `MonsterData` has `tier = 0`
- **THEN** validation SHALL report an error and the monster SHALL NOT be usable

#### Scenario: Tier above 5 is rejected

- **WHEN** a `MonsterData` has `tier = 6`
- **THEN** validation SHALL report an error and the monster SHALL NOT be usable

#### Scenario: Pre-migration MonsterData tres loads with tier 1 fallback

- **WHEN** `DataLoader.load_all_monsters()` reads an existing `MonsterData` `.tres` file that does not include the new `tier` property
- **THEN** the loaded `MonsterData` SHALL have `tier == 1` and SHALL NOT raise a load error

### Requirement: All shipped MonsterData .tres files specify a tier

The system SHALL ensure every `.tres` file under `data/monsters/` sets an explicit `tier` value in the range `[1, 5]`. The shipped tier assignments SHALL be:

| Monster | tier |
|---------|------|
| `slime` | 1 |
| `bat` | 1 |
| `goblin` | 2 |
| `skeleton` | 2 |
| `ghost` | 3 |
| `imp` | 3 |
| `goblin_shaman` | 3 |
| `witch` | 4 |
| `dark_priest` | 4 |
| `wraith` | 4 |
| `lich` | 5 |
| `dragon` | 5 |

Each tier from 1 through 5 SHALL contain at least one shipped monster so that encounter tables can safely assign any tier weight.

#### Scenario: Every shipped monster has a tier between 1 and 5

- **WHEN** `DataLoader.load_all_monsters()` is invoked on the shipped data directory
- **THEN** every returned `MonsterData` SHALL have `1 <= tier <= 5`

#### Scenario: Slime is tier 1

- **WHEN** `MonsterRepository.find(&"slime")` is called
- **THEN** the returned `MonsterData.tier` SHALL equal `1`

#### Scenario: Skeleton is tier 2

- **WHEN** `MonsterRepository.find(&"skeleton")` is called
- **THEN** the returned `MonsterData.tier` SHALL equal `2`

#### Scenario: Ghost is tier 3

- **WHEN** `MonsterRepository.find(&"ghost")` is called
- **THEN** the returned `MonsterData.tier` SHALL equal `3`

#### Scenario: Witch is tier 4

- **WHEN** `MonsterRepository.find(&"witch")` is called
- **THEN** the returned `MonsterData.tier` SHALL equal `4`

#### Scenario: Dragon is tier 5

- **WHEN** `MonsterRepository.find(&"dragon")` is called
- **THEN** the returned `MonsterData.tier` SHALL equal `5`

#### Scenario: Every tier has at least one shipped monster

- **WHEN** the shipped monster set is loaded
- **THEN** for each tier `t` in `[1, 2, 3, 4, 5]`, there SHALL exist at least one `MonsterData` with `tier == t`

### Requirement: MonsterRepository provides lookup by tier

The system SHALL extend `MonsterRepository` with a method `find_by_tier(tier: int) -> Array[MonsterData]` that returns all registered `MonsterData` instances whose `tier` field equals the given value. The order of returned elements is unspecified but SHALL be deterministic for a given repository state so that seeded RNGs produce reproducible encounters.

When no registered monster matches the given tier, `find_by_tier` SHALL return an empty array (not `null`) and SHALL NOT emit a warning (callers handle the empty case).

#### Scenario: find_by_tier returns matching monsters

- **WHEN** `MonsterRepository.find_by_tier(2)` is called on the shipped repository
- **THEN** the returned array SHALL contain the `MonsterData` for `&"goblin"` and `&"skeleton"`

#### Scenario: find_by_tier with unmatched tier returns empty array

- **WHEN** `MonsterRepository.find_by_tier(99)` is called
- **THEN** the returned array SHALL be empty AND SHALL NOT be `null`

#### Scenario: find_by_tier is deterministic across calls

- **WHEN** `MonsterRepository.find_by_tier(3)` is called twice on the same repository state
- **THEN** both calls SHALL return arrays in the same order

