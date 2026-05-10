## ADDED Requirements

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
