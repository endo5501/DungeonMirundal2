## ADDED Requirements

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
