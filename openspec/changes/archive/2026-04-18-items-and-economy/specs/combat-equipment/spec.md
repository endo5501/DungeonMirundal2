## ADDED Requirements

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
