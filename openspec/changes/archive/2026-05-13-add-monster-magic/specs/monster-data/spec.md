## ADDED Requirements

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
