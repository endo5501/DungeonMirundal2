## ADDED Requirements

### Requirement: WeaponData defines weapon-specific attributes as a sub-resource

The system SHALL provide a `WeaponData` Custom Resource (`class_name WeaponData extends Resource`) that holds weapon-specific attributes layered on top of the generic `Item` template. `WeaponData` SHALL expose at minimum `weapon_range: WeaponRange` (enum: `MELEE`, `RANGED`).

The `WeaponRange` enum SHALL be declared so that combat code (engine, AI, equipment provider) can share a single nominal type with `MonsterData.attack_range`.

#### Scenario: WeaponData carries weapon_range
- **WHEN** a `WeaponData` resource is created with `weapon_range = WeaponRange.RANGED`
- **THEN** the field SHALL be readable as `WeaponRange.RANGED`

#### Scenario: WeaponRange enum has MELEE and RANGED values
- **WHEN** code references `WeaponRange.MELEE` and `WeaponRange.RANGED`
- **THEN** both values SHALL resolve to distinct enum constants

### Requirement: Item exposes optional weapon_data for WEAPON category items

The system SHALL extend `Item` with `@export var weapon_data: WeaponData = null`. The field SHALL be readable on every `Item` instance regardless of category.

For `Item.category == ItemCategory.WEAPON`:
- `weapon_data` MAY be `null` (treated as MELEE fallback by combat code).
- `weapon_data` MAY be a non-null `WeaponData` describing the weapon's attack range.

For non-WEAPON categories (ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, CONSUMABLE, OTHER):
- `weapon_data` SHALL conventionally be `null`. Combat code SHALL NOT consult `weapon_data` for non-WEAPON items.

#### Scenario: WEAPON Item with explicit RANGED weapon_data
- **WHEN** a WEAPON `Item` is created with `weapon_data = WeaponData.new()` whose `weapon_range = WeaponRange.RANGED`
- **THEN** `item.weapon_data.weapon_range` SHALL equal `WeaponRange.RANGED`

#### Scenario: WEAPON Item without weapon_data is null
- **WHEN** a WEAPON `Item` is created without setting `weapon_data`
- **THEN** `item.weapon_data` SHALL be `null` (combat code applies MELEE fallback)

#### Scenario: Non-WEAPON Item has null weapon_data by convention
- **WHEN** an ARMOR or CONSUMABLE `Item` is created
- **THEN** `item.weapon_data` SHALL be `null`

### Requirement: Existing WEAPON .tres files remain valid without weapon_data

The system SHALL ensure that all existing `data/items/*.tres` files with `category == WEAPON` remain loadable and usable in combat even if their on-disk resource does not declare `weapon_data`. Loading SHALL produce `weapon_data = null` and combat SHALL treat such weapons as MELEE.

#### Scenario: Pre-migration WEAPON tres loads with null weapon_data
- **WHEN** `DataLoader.load_all_items()` reads an existing WEAPON `.tres` file that does not include the `weapon_data` property
- **THEN** the loaded `Item` SHALL have `weapon_data == null` and SHALL NOT raise a load error

#### Scenario: Combat code treats null weapon_data as MELEE
- **WHEN** combat queries the weapon range of an actor whose equipped WEAPON `Item` has `weapon_data == null`
- **THEN** the resolved weapon range SHALL be `WeaponRange.MELEE`
