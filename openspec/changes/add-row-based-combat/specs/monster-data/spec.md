## ADDED Requirements

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
