## Purpose
戦闘時に参照される装備ステータスの供給インターフェース（EquipmentProvider）を規定する。本番・テスト双方で差し替え可能な形で、装備由来のステータス補正を一貫して提供する。

## Requirements

### Requirement: EquipmentProvider is the single interface for derived combat stats
The system SHALL define an `EquipmentProvider` (RefCounted) interface with three methods — `get_attack(character) -> int`, `get_defense(character) -> int`, and `get_agility(character) -> int` — so that every combat calculation for a party member goes through a single, swappable source of truth.

#### Scenario: Interface shape is fixed
- **WHEN** any EquipmentProvider implementation is created
- **THEN** it SHALL expose those exactly three methods with matching signatures

#### Scenario: PartyCombatant routes through EquipmentProvider
- **WHEN** `PartyCombatant.get_attack()` is invoked
- **THEN** the implementation SHALL delegate to `equipment_provider.get_attack(character)` and return its value verbatim

### Requirement: DummyEquipmentProvider computes stats from base stats plus per-job fixed bonuses
The system SHALL provide a `DummyEquipmentProvider` that computes:
- `get_attack(character) = base_stats[&"STR"] / 2 + weapon_bonus[character.job]`
- `get_defense(character) = base_stats[&"VIT"] / 3 + armor_bonus[character.job]`
- `get_agility(character) = base_stats[&"AGI"]`
where `weapon_bonus` and `armor_bonus` are job-keyed lookup tables baked into the provider.

#### Scenario: Fighter attack uses weapon bonus
- **WHEN** a Fighter Character has `base_stats[&"STR"] = 14` and `weapon_bonus[Fighter] = 5`
- **THEN** `get_attack(character)` SHALL return `14 / 2 + 5 == 12`

#### Scenario: Priest defense uses armor bonus
- **WHEN** a Priest Character has `base_stats[&"VIT"] = 12` and `armor_bonus[Priest] = 3`
- **THEN** `get_defense(character)` SHALL return `12 / 3 + 3 == 7`

#### Scenario: Agility does not use equipment bonus
- **WHEN** any Character is queried for `get_agility`
- **THEN** the returned value SHALL equal `base_stats[&"AGI"]` with no job- or equipment-dependent adjustment

### Requirement: DummyEquipmentProvider defines bonuses for all eight jobs
The system SHALL provide `weapon_bonus` and `armor_bonus` entries for every job defined by `job-data` (Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja), so that no combat lookup for any Character results in a missing-key error.

#### Scenario: Every job has weapon_bonus
- **WHEN** `get_attack(character)` is invoked for a Character of any of the eight jobs
- **THEN** it SHALL return a value SHALL NOT raise a missing-key error

#### Scenario: Every job has armor_bonus
- **WHEN** `get_defense(character)` is invoked for a Character of any of the eight jobs
- **THEN** it SHALL return a value and SHALL NOT raise a missing-key error

### Requirement: EquipmentProvider is injected, not globally looked up
The system SHALL require `EquipmentProvider` to be passed as a constructor (or factory) argument to `PartyCombatant`, so that tests can substitute a test-only stub and items-and-economy can substitute an `InventoryEquipmentProvider` without modifying combat code.

#### Scenario: Test can substitute a stub EquipmentProvider
- **WHEN** a test instantiates a PartyCombatant with a test stub whose `get_attack` returns a fixed value `42`
- **THEN** `PartyCombatant.get_attack()` SHALL return `42`

#### Scenario: Combat-engine does not import EquipmentProvider
- **WHEN** the combat engine resolves damage or computes turn order
- **THEN** it SHALL NOT reference `DummyEquipmentProvider` or any concrete EquipmentProvider type; it SHALL only call `CombatActor.get_attack()` / `get_defense()` / `get_agility()`

### Requirement: InventoryEquipmentProvider computes stats from equipped items plus base stats
The system SHALL provide an `InventoryEquipmentProvider` (extends `EquipmentProvider`) that produces combat-derived stats by reading the character's six-slot `Equipment` and summing per-item bonuses onto a base-stat contribution:
- `get_attack(character)  = base_stats[&"STR"] / 2 + Σ (equipped.item.attack_bonus)`
- `get_defense(character) = base_stats[&"VIT"] / 3 + Σ (equipped.item.defense_bonus)`
- `get_agility(character) = base_stats[&"AGI"]    + Σ (equipped.item.agility_bonus)`

The Σ SHALL iterate over every non-null `ItemInstance` returned by `character.equipment.all_equipped()`. The provider SHALL NOT consult `ItemInstance.identified` in the MVP; identified and unidentified items contribute stats identically.

#### Scenario: Attack sums weapon bonus onto STR contribution
- **WHEN** a Fighter Character has `base_stats[&"STR"] = 14` and equips a weapon with `attack_bonus = 6` and no other items with attack bonuses
- **THEN** `get_attack(character)` SHALL return `14 / 2 + 6 == 13`

#### Scenario: Defense sums armor and shield bonuses onto VIT contribution
- **WHEN** a Fighter Character has `base_stats[&"VIT"] = 12` and equips armor with `defense_bonus = 4` and a shield with `defense_bonus = 2`
- **THEN** `get_defense(character)` SHALL return `12 / 3 + 4 + 2 == 10`

#### Scenario: Agility sums equipment contributions onto AGI
- **WHEN** a Character has `base_stats[&"AGI"] = 9` and equips an accessory with `agility_bonus = 2`
- **THEN** `get_agility(character)` SHALL return `9 + 2 == 11`

#### Scenario: Character with no equipment returns base-only values
- **WHEN** a Character has all six equip slots empty
- **THEN** `get_attack / get_defense / get_agility` SHALL return `base_stats[STR]/2`, `base_stats[VIT]/3`, `base_stats[AGI]` respectively (equipment sum == 0)

#### Scenario: Identified and unidentified items contribute equally in MVP
- **WHEN** two ItemInstance wrapping the same `Item` differ only in `identified` (one `true`, one `false`) and one of them is equipped
- **THEN** `get_attack / get_defense / get_agility` SHALL return the same value regardless of which ItemInstance is equipped

### Requirement: InventoryEquipmentProvider is used in production and DummyEquipmentProvider is test-only
The system SHALL, in production wiring (`main.gd` / `CombatOverlay` construction path), inject an `InventoryEquipmentProvider` (not `DummyEquipmentProvider`) into every `PartyCombatant`. `DummyEquipmentProvider` SHALL remain in the codebase only for unit tests that need a stable, equipment-independent stub.

#### Scenario: Production wiring uses InventoryEquipmentProvider
- **WHEN** the game is running a real encounter (not a test)
- **THEN** each PartyCombatant's `equipment_provider` SHALL be an `InventoryEquipmentProvider`

#### Scenario: DummyEquipmentProvider remains available for tests
- **WHEN** a unit test instantiates a PartyCombatant with `DummyEquipmentProvider`
- **THEN** the existing DummyEquipmentProvider behavior (STR/2 + weapon_bonus, VIT/3 + armor_bonus, AGI) SHALL continue to function

### Requirement: EquipmentProvider exposes get_weapon_range with MELEE fallback

The system SHALL extend the `EquipmentProvider` interface with a fourth method `get_weapon_range(character) -> WeaponRange` so that combat reachability code can resolve the equipped weapon's attack reach through the same swappable provider used for derived stats.

The method SHALL return `WeaponRange.MELEE` whenever a weapon is absent or its `weapon_data` is null, so that combat code never sees a "missing range" failure mode.

#### Scenario: Interface shape is extended
- **WHEN** any `EquipmentProvider` implementation is created
- **THEN** it SHALL expose `get_weapon_range(character) -> WeaponRange` in addition to the pre-existing `get_attack` / `get_defense` / `get_agility`

#### Scenario: Fist (no weapon equipped) is MELEE
- **WHEN** `get_weapon_range(character)` is called for a Character whose `Equipment.WEAPON` slot is empty
- **THEN** the result SHALL be `WeaponRange.MELEE`

#### Scenario: Equipped weapon with explicit RANGED weapon_data is RANGED
- **WHEN** `get_weapon_range(character)` is called for a Character whose `Equipment.WEAPON` slot holds an `ItemInstance` whose `item.weapon_data.weapon_range == RANGED`
- **THEN** the result SHALL be `WeaponRange.RANGED`

#### Scenario: Equipped weapon with null weapon_data falls back to MELEE
- **WHEN** `get_weapon_range(character)` is called for a Character whose equipped WEAPON `Item` has `weapon_data == null`
- **THEN** the result SHALL be `WeaponRange.MELEE`

### Requirement: InventoryEquipmentProvider implements get_weapon_range from the equipped WEAPON slot

`InventoryEquipmentProvider.get_weapon_range(character)` SHALL:

1. Read the `ItemInstance` (if any) at `character.equipment.get_equipped(Item.EquipSlot.WEAPON)`.
2. If the slot is empty, return `WeaponRange.MELEE`.
3. If the slot holds an `ItemInstance` whose `item.weapon_data` is non-null, return `item.weapon_data.weapon_range`.
4. Otherwise (weapon present but `weapon_data == null`), return `WeaponRange.MELEE`.

The method SHALL NOT consult `ItemInstance.identified` (consistent with the existing rule that identified and unidentified items contribute stats identically in the MVP).

#### Scenario: Production wiring resolves equipped bow as RANGED
- **WHEN** a Character equips a bow `Item` whose `weapon_data.weapon_range == RANGED` and `InventoryEquipmentProvider.get_weapon_range(character)` is called
- **THEN** the result SHALL be `WeaponRange.RANGED`

#### Scenario: Identified flag does not affect weapon range
- **WHEN** the same Item resource is wrapped by two `ItemInstance` (one identified, one not) and either is equipped to the WEAPON slot
- **THEN** `get_weapon_range(character)` SHALL return the same value for both

### Requirement: DummyEquipmentProvider returns MELEE for tests

`DummyEquipmentProvider.get_weapon_range(character) -> WeaponRange` SHALL always return `WeaponRange.MELEE`, so that the test-only stub remains stable and equipment-independent.

#### Scenario: Dummy provider returns MELEE for any character
- **WHEN** `DummyEquipmentProvider.get_weapon_range(character)` is called for any Character
- **THEN** the result SHALL be `WeaponRange.MELEE`

