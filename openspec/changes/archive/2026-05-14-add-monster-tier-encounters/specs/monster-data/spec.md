## ADDED Requirements

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
