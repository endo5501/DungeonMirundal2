## MODIFIED Requirements

### Requirement: CombatActor provides a uniform combat-participant interface

The system SHALL provide a `CombatActor` (RefCounted) abstract type that exposes a unified interface for any battle participant (party member or monster), so that combat logic can treat both kinds identically. The interface SHALL include MP fields and a `spend_mp` method so that magic casting can be expressed at the abstract level.

#### Scenario: CombatActor exposes required fields and methods

- **WHEN** any concrete CombatActor subclass is instantiated
- **THEN** it SHALL expose `actor_name: String`, `current_hp: int`, `max_hp: int`, `current_mp: int`, `max_mp: int`, `get_attack() -> int`, `get_defense() -> int`, `get_agility() -> int`, `is_alive() -> bool`, `take_damage(amount: int)`, and `spend_mp(amount: int) -> bool`.

#### Scenario: is_alive reflects current_hp
- **WHEN** a CombatActor has `current_hp = 0`
- **THEN** `is_alive()` SHALL return `false`
- **WHEN** a CombatActor has `current_hp > 0`
- **THEN** `is_alive()` SHALL return `true`

#### Scenario: take_damage reduces current_hp and clamps at zero
- **WHEN** `take_damage(amount)` is called with `amount >= 0` on a CombatActor with `current_hp > 0`
- **THEN** `current_hp` SHALL decrease by exactly `amount` but SHALL NOT go below `0`

#### Scenario: spend_mp succeeds when sufficient MP exists
- **WHEN** `spend_mp(2)` is called on a CombatActor with `current_mp = 5`
- **THEN** the call SHALL return `true` and `current_mp` SHALL become `3`

#### Scenario: spend_mp fails when insufficient MP exists
- **WHEN** `spend_mp(3)` is called on a CombatActor with `current_mp = 2`
- **THEN** the call SHALL return `false` and `current_mp` SHALL remain `2`

#### Scenario: spend_mp with zero amount returns true and is a no-op
- **WHEN** `spend_mp(0)` is called on any CombatActor
- **THEN** the call SHALL return `true` and `current_mp` SHALL remain unchanged

### Requirement: PartyCombatant wraps a Character and writes back directly

The system SHALL provide a `PartyCombatant` (extends CombatActor) that holds a reference to a `Character` and an `EquipmentProvider`, and SHALL proxy HP and MP reads and writes through the wrapped Character so no write-back step is required after combat.

#### Scenario: HP changes propagate to Character
- **WHEN** `take_damage(5)` is called on a PartyCombatant wrapping a Character with `current_hp = 20`
- **THEN** the wrapped Character's `current_hp` SHALL become `15`

#### Scenario: MP changes propagate to Character
- **WHEN** `spend_mp(2)` is called on a PartyCombatant wrapping a Character with `current_mp = 5`
- **THEN** `spend_mp` SHALL return `true` and the wrapped Character's `current_mp` SHALL become `3`

#### Scenario: PartyCombatant max_mp comes from Character
- **WHEN** a PartyCombatant wraps a Character with `max_mp = 8`
- **THEN** the PartyCombatant's `max_mp` SHALL equal `8`

#### Scenario: Derived stats come from EquipmentProvider
- **WHEN** `get_attack()` is called on a PartyCombatant
- **THEN** the returned value SHALL equal `equipment_provider.get_attack(character)`
- **WHEN** `get_defense()` / `get_agility()` are called
- **THEN** the returned values SHALL equal the corresponding `equipment_provider` lookups

#### Scenario: actor_name comes from Character
- **WHEN** a PartyCombatant wraps a Character with `character_name = "Fighter"`
- **THEN** `actor_name` SHALL equal `"Fighter"`

### Requirement: MonsterCombatant wraps a Monster and its MonsterData

The system SHALL provide a `MonsterCombatant` (extends CombatActor) that holds a reference to a `Monster` and SHALL source derived stats from the underlying `MonsterData`. In v1, monsters SHALL NOT cast spells; their MP fields SHALL be zero and `spend_mp` SHALL always return `false` for any positive amount.

#### Scenario: HP proxies to Monster instance
- **WHEN** `take_damage(3)` is called on a MonsterCombatant whose Monster has `current_hp = 10`
- **THEN** the wrapped Monster's `current_hp` SHALL become `7`

#### Scenario: Derived stats come from MonsterData
- **WHEN** `get_attack()`, `get_defense()`, and `get_agility()` are called on a MonsterCombatant whose `MonsterData` declares `attack = 4`, `defense = 2`, `agility = 6`
- **THEN** the returned values SHALL be `4`, `2`, and `6` respectively

#### Scenario: actor_name comes from MonsterData
- **WHEN** a MonsterCombatant wraps a Monster whose `MonsterData.monster_name` is `"スライム"`
- **THEN** `actor_name` SHALL equal `"スライム"`

#### Scenario: MonsterCombatant has zero MP in v1
- **WHEN** a MonsterCombatant is instantiated
- **THEN** `current_mp` and `max_mp` SHALL both be `0`

#### Scenario: MonsterCombatant.spend_mp rejects positive amounts
- **WHEN** `spend_mp(1)` is called on a MonsterCombatant
- **THEN** the call SHALL return `false`
